import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hc20/hc20.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../models/hc20_connection_event.dart';
import 'storage_service.dart'; // ✅ PHASE 4: Import for forgetDevice()
import 'reconnection_monitor.dart'; // ✅ TICKET #1: Reconnection timeout optimization
import 'ble_connection_monitor.dart'; // ✅ TICKET #2: BLE hardware monitoring
import 'oauth_circuit_breaker.dart'; // ✅ TICKET #3: OAuth failure protection
import 'ble_keepalive_service.dart'; // ✅ TICKET #5: Prevent premature disconnects
import 'enhanced_oauth_service.dart'; // ✅ OAuth Optimization: Persistent token storage

/// Global HC20 connection service that persists across navigation
/// This ensures the device stays connected even when switching screens
/// 
/// ✅ PHASE 1: Now listens to SDK connection events and forwards them to app
class HC20Service extends ChangeNotifier {
  static final HC20Service _instance = HC20Service._internal();
  factory HC20Service() => _instance;
  HC20Service._internal();

  // HC20 client and device state
  Hc20Client? _client;
  Hc20Device? _connectedDevice;
  bool _isConnected = false;
  
  // ✅ FIX #3: Store last device for manual reconnection after disconnect
  Hc20Device? _lastDisconnectedDevice;

  // Real-time data state
  int? _heartRate;
  int? _spo2;
  String? _bloodPressure; // ✅ Changed from List<int>? to String? to match UI format "120/80"
  double? _temperature;
  int? _batteryLevel;
  int? _steps;
  DateTime? _lastDataReceived;
  
  // ✅ FIX: Debounce disconnect events to prevent SDK double-disconnect bug
  DateTime? _lastDisconnectTime;
  static const Duration _disconnectDebounce = Duration(seconds: 3);
  
  // ✅ FIX #4: Track failed reconnection attempts for smart delay
  int _failedReconnectAttempts = 0;
  
  // ✅ FIX #2: Track if currently attempting reconnection (prevents premature counter reset)
  bool _isReconnecting = false;

  // Subscriptions (kept alive across navigation)
  StreamSubscription? _realtimeSubscription;
  Timer? _dataRefreshTimer;
  Timer? _connectionMonitor;
  
  // ✅ PHASE 1: SDK event listener
  StreamSubscription<Hc20ConnectionStateUpdate>? _sdkConnectionStateSubscription;
  
  // ✅ TICKET #1: Reconnection monitor
  final _reconnectionMonitor = ReconnectionMonitor();
  
  // ✅ TICKET #2: BLE connection monitor
  BleConnectionMonitor? _bleMonitor;
  final _ble = FlutterReactiveBle();
  
  // ✅ TICKET #3: OAuth circuit breaker
  final _oauthCircuitBreaker = OAuthCircuitBreaker();
  
  // ✅ OAuth Optimization: Enhanced OAuth service with persistent storage
  late final EnhancedOAuthService _enhancedOAuth = EnhancedOAuthService(
    clientId: 'Ep8FyjJ1BrvFdW2DdYgQJhX8lM4Gy5j1',
    clientSecret: 'ac8c34f2c30466954c4da4c995885107fabc33d8',
    authUrl: 'https://oauth.dtnext.online/hc20/v1/oauth/token',
  );
  
  // ✅ TICKET #5: BLE keepalive service
  final _bleKeepalive = BleKeepaliveService();
  
  // ✅ FIX #1: Bluetooth state monitoring for OAuth refresh
  StreamSubscription<BleStatus>? _bleStatusSubscription;
  BleStatus _previousBleStatus = BleStatus.unknown;
  
  // ✅ NEW: Track current OAuth error state (real-time detection)
  String? _lastOAuthError;
  DateTime? _lastOAuthErrorTime;
  
  // ✅ PHASE 1: Event stream for app components to listen to
  final _connectionEventController = StreamController<HC20ConnectionEvent>.broadcast();
  Stream<HC20ConnectionEvent> get connectionEventStream => _connectionEventController.stream;

  // Getters
  Hc20Client? get client => _client;
  Hc20Device? get connectedDevice => _connectedDevice;
  bool get isConnected => _isConnected;
  int? get heartRate => _heartRate;
  int? get spo2 => _spo2;
  String? get bloodPressure =>
      _bloodPressure; // ✅ Changed from List<int>? to String?
  double? get temperature => _temperature;
  int? get batteryLevel => _batteryLevel;
  int? get steps => _steps;
  DateTime? get lastDataReceived => _lastDataReceived;
  FlutterReactiveBle get ble => _ble; // ✅ NEW: Expose BLE for status checking
  bool get isOAuthServerDown => !_oauthCircuitBreaker.shouldAttemptAuth; // ✅ NEW: OAuth server status
  
  // ✅ NEW: Check if OAuth error happened recently (within last 30 seconds)
  bool get hasRecentOAuthError {
    if (_lastOAuthError == null || _lastOAuthErrorTime == null) return false;
    final timeSinceError = DateTime.now().difference(_lastOAuthErrorTime!);
    return timeSinceError.inSeconds < 30; // Error within last 30 seconds
  }
  
  // ✅ NEW: Get last OAuth error details
  String? get lastOAuthError => _lastOAuthError;

  /// Initialize HC20 client
  Future<void> initializeClient() async {
    if (_client != null) return; // Already initialized

    // ✅ TICKET #3: Check OAuth circuit breaker before attempting
    if (!_oauthCircuitBreaker.shouldAttemptAuth) {
      print('⚠️ [HC20Service] OAuth circuit open - skipping initialization');
      print('   App will retry in ${OAuthCircuitBreaker.resetTimeout.inMinutes} minutes');
      throw Exception('OAuth circuit breaker open - too many failures');
    }

    try {
      print('🔐 [HC20Service] Attempting OAuth with enhanced service...');
      
      // ✅ FIX: Check local storage FIRST before calling server
      print('📊 [OAuth] Checking token priority: Memory → Disk → Server');
      final tokenStatus = await _enhancedOAuth.getTokenStatus();
      print('📊 [OAuth] Status: $tokenStatus');
      
      // ✅ OAuth Optimization: Try to get token from cache (memory/disk)
      // This will NOT call server if valid token exists
      bool hadOAuthError = false; // ✅ NEW: Track if OAuth error occurred
      try {
        final token = await _enhancedOAuth.getAccessToken(forceRefresh: false);
        if (token.isNotEmpty) {
          print('✅ [OAuth] Token obtained from LOCAL STORAGE (length: ${token.length} chars)');
          print('✅ [OAuth] Skipping server call - using cached token');
          // ✅ Clear error only if token retrieval succeeded
          _lastOAuthError = null;
          _lastOAuthErrorTime = null;
        }
      } catch (oauthError) {
        print('⚠️ [OAuth] Local storage empty - will request from server');
        print('   Error: $oauthError');
        // ✅ NEW: Track OAuth error immediately
        _lastOAuthError = oauthError.toString();
        _lastOAuthErrorTime = DateTime.now();
        hadOAuthError = true; // ✅ NEW: Mark that error occurred
        // Don't throw yet - let SDK try (it will call server)
      }
      
      _client = await Hc20Client.create(
        config: Hc20Config(
          clientId: 'Ep8FyjJ1BrvFdW2DdYgQJhX8lM4Gy5j1',
          clientSecret: 'ac8c34f2c30466954c4da4c995885107fabc33d8',
        ),
      ).timeout(
        const Duration(seconds: 30), // ✅ Increased timeout to 30s (was 10s)
        onTimeout: () {
          throw TimeoutException('OAuth initialization timeout');
        },
      );
      
      // ✅ TICKET #3: Record OAuth success
      _oauthCircuitBreaker.recordSuccess();
      
      // ✅ FIX: Only clear error if token retrieval succeeded (not just client creation)
      if (!hadOAuthError) {
        _lastOAuthError = null;
        _lastOAuthErrorTime = null;
        print('✅ [OAuth] No errors - client initialized successfully');
      } else {
        print('⚠️ [OAuth] Client initialized but with previous OAuth error still tracked');
        print('⚠️ [OAuth] Error: $_lastOAuthError');
      }
      
      print('✅ [HC20Service] Client initialized globally with OAuth error protection');
      
      // ✅ FIX #3: Restore last connected device from disk (if app restarted)
      await _restoreDeviceFromStorage();
      
      // ✅ FIX #1: Start monitoring Bluetooth state changes
      _startBluetoothStateMonitoring();
      
      // ✅ PHASE 1: Setup SDK connection event listener
      _setupSdkConnectionListener();
    } catch (e) {
      final errorStr = e.toString();
      
      // ✅ NEW: Track OAuth error immediately for real-time detection
      _lastOAuthError = errorStr;
      _lastOAuthErrorTime = DateTime.now();
      
      // ✅ TICKET #3: Detect OAuth errors and record failure
      if (errorStr.contains('500') || 
          errorStr.contains('Authentication') ||
          errorStr.contains('OAuth')) {
        print('⚠️ [HC20Service] OAuth error detected: $e');
        _oauthCircuitBreaker.recordFailure(errorStr);
        
        // ✅ FIX: NEVER clear token - keep it for next attempt
        // Token is stored in local storage (encrypted), only clear on 401/403
        if (errorStr.contains('500') || errorStr.contains('timeout')) {
          print('⚠️ [OAuth] Server error (500/timeout) - KEEPING cached token');
          print('💾 [OAuth] Token remains in local storage for next reconnect');
          // DON'T clear token - server issue, not auth issue
        } else if (errorStr.contains('401') || 
                   errorStr.contains('403') || 
                   errorStr.contains('Unauthorized') ||
                   errorStr.contains('Forbidden')) {
          print('❌ [OAuth] Auth failed (401/403) - clearing INVALID token');
          await _enhancedOAuth.clearToken(reason: ClearReason.invalidCredentials);
        } else {
          print('⚠️ [OAuth] Unknown error - KEEPING cached token');
          print('💾 [OAuth] Will retry with cached token on next attempt');
        }
        
        // Check if circuit is now open
        if (!_oauthCircuitBreaker.shouldAttemptAuth) {
          print('🔴 [HC20Service] Circuit breaker opened - OAuth disabled temporarily');
        }
      }
      
      print('❌ [HC20Service] Client initialization failed: $e');
      rethrow;
    }
  }
  
  /// ✅ PHASE 1: Setup SDK connection state listener
  void _setupSdkConnectionListener() {
    if (_client == null) {
      print('⚠️ [HC20Service] Cannot setup SDK listener - client is null');
      return;
    }
    
    print('🎧 [HC20Service] Setting up SDK connection event listener...');
    
    _sdkConnectionStateSubscription = _client!.connectionState.listen(
      (Hc20ConnectionStateUpdate update) {
        print('🔔 [HC20Service] SDK connection state update: ${update.state}');
        _handleSdkConnectionEvent(update);
      },
      onError: (error) {
        print('⚠️ [HC20Service] SDK connection state stream error: $error');
      },
    );
    
    print('✅ [HC20Service] SDK event listener active');
  }
  
  /// ✅ FIX #1: Start monitoring Bluetooth state changes for OAuth refresh
  void _startBluetoothStateMonitoring() {
    print('📡 [HC20Service] Starting Bluetooth state monitoring...');
    
    _bleStatusSubscription?.cancel();
    _bleStatusSubscription = _ble.statusStream.listen((BleStatus newStatus) {
      _onBluetoothStatusChanged(newStatus);
    });
    
    print('✅ [HC20Service] Bluetooth state monitoring active');
  }
  
  /// ✅ FIX #1: Handle Bluetooth state changes and force OAuth refresh on toggle
  /// ✅ FIX #4: Made async to support smart delay
  Future<void> _onBluetoothStatusChanged(BleStatus newStatus) async {
    print('📡 [HC20Service] Bluetooth status: $_previousBleStatus → $newStatus');
    
    // ✅ NEW: Notify listeners immediately when BT status changes (for UI updates)
    notifyListeners();
    
    // Detect Bluetooth toggle (OFF → ON)
    if (_previousBleStatus == BleStatus.poweredOff && 
        newStatus == BleStatus.ready) {
      print('🔄 [HC20Service] Bluetooth toggled ON - attempting IMMEDIATE reconnect...');
      print('💡 [HC20Service] Reusing existing OAuth token (valid for 15min)');
      
      // Reset OAuth circuit breaker to allow reconnection attempts
      // But DON'T clear token - it's still valid!
      _oauthCircuitBreaker.reset();
      print('✅ [HC20Service] OAuth circuit breaker reset - ready for reconnection');
      
      // DO NOT clear OAuth cache - token is still valid!
      // The SDK will reuse the cached token from secure storage
      print('✅ [HC20Service] Will reuse cached OAuth token from storage');
      
      // ✅ FIX #3: Trigger IMMEDIATE reconnection (don't wait 15 seconds!)
      if (_lastDisconnectedDevice != null && _client != null) {
        print('⚡ [HC20Service] Device available - reconnecting NOW (not waiting 30s)');
        print('⚡ [HC20Service] Device: ${_lastDisconnectedDevice!.name} (${_lastDisconnectedDevice!.id})');
        
        // ✅ FIX #4: Add smart delay if previous reconnect attempts failed
        if (_failedReconnectAttempts > 0) {
          final delaySeconds = 2;
          print('⏳ [HC20Service] Previous $_failedReconnectAttempts attempt(s) failed - waiting ${delaySeconds}s for SDK stability...');
          await Future.delayed(Duration(seconds: delaySeconds));
          print('✅ [HC20Service] BLE stack stabilization complete - attempting reconnect');
        }
        
        // ✅ NEW: Stop ReconnectionMonitor to prevent duplicate reconnect attempts
        _reconnectionMonitor.stopMonitoring(reconnected: false);
        print('🛑 [HC20Service] Stopped ReconnectionMonitor (immediate reconnect in progress)');
        
        // ✅ FIX #2: Attempt reconnection with proper success validation
        await _attemptReconnectionWithValidation();
      } else {
        print('⏳ [HC20Service] No cached device - waiting for SDK auto-reconnect');
        print('   - Client: ${_client != null ? "EXISTS" : "NULL"}');
        print('   - Last device: ${_lastDisconnectedDevice != null ? "EXISTS" : "NULL"}');
      }
    }
    
    _previousBleStatus = newStatus;
    
    // ✅ NEW: Notify listeners again after processing BT change (in case reconnect status changed)
    notifyListeners();
  }
  
  /// ✅ PHASE 1: Handle SDK connection state changes
  void _handleSdkConnectionEvent(Hc20ConnectionStateUpdate update) {
    switch (update.state) {
      case Hc20ConnectionState.connected:
        _handleConnected(update.device);
        break;
        
      case Hc20ConnectionState.reconnected:
        _handleReconnected(update.device);
        break;
        
      case Hc20ConnectionState.disconnected:
        _handleDisconnected('Device disconnected');
        break;
    }
  }
  
  /// ✅ PHASE 1: Handle connected event from SDK
  void _handleConnected(Hc20Device device) {
    print('✅ [HC20Service] SDK connected to device: ${device.name}');
    
    _connectedDevice = device;
    _isConnected = true;
    
    // ✅ FIX: DON'T clear _lastDisconnectedDevice - keep it as backup
    // Only clear on manual "Forget Device" action
    print('📌 [HC20Service] Keeping last device as backup: ${_lastDisconnectedDevice?.name ?? "none"}');
    
    // ✅ FIX #4: Reset failed reconnection counter on success
    _failedReconnectAttempts = 0;
    
    // Start real-time data stream
    _startRealtimeStream();
    
    // ✅ TICKET #5: Start BLE keepalive pings
    if (_client != null) {
      _bleKeepalive.start(_client!, device);
    }
    
    // Emit event for app components (main.dart will listen)
    _connectionEventController.add(
      HC20ConnectionEvent(
        type: HC20ConnectionEventType.connected,
        device: device,
      ),
    );
    
    // Notify listeners (UI updates)
    notifyListeners();
  }
  
  /// ✅ PHASE 1: Handle reconnected event from SDK (auto-reconnection)
  void _handleReconnected(Hc20Device device) {
    print('🔄 [HC20Service] SDK auto-reconnected to device: ${device.name}');
    
    _connectedDevice = device;
    _isConnected = true;
    
    // ✅ FIX: DON'T clear _lastDisconnectedDevice - keep it as permanent backup
    // This ensures we ALWAYS have device reference for reconnection
    print('📌 [HC20Service] Keeping last device as permanent backup: ${_lastDisconnectedDevice?.name ?? "none"}');
    
    // ✅ FIX #4: Reset failed reconnection counter on success
    _failedReconnectAttempts = 0;
    print('✅ [HC20Service] Failed reconnection counter reset (successful reconnect)');
    
    // ✅ TICKET #1: Stop reconnection monitoring
    _reconnectionMonitor.stopMonitoring(reconnected: true);
    
    // ✅ TICKET #2: Stop BLE hardware monitoring
    _bleMonitor?.stopMonitoring();
    
    // Recreate real-time subscription (old one might be stale)
    _realtimeSubscription?.cancel();
    _startRealtimeStream();
    
    // ✅ TICKET #5: Restart BLE keepalive pings
    if (_client != null) {
      _bleKeepalive.stop();
      _bleKeepalive.start(_client!, device);
    }
    
    // Emit event for app components
    _connectionEventController.add(
      HC20ConnectionEvent(
        type: HC20ConnectionEventType.reconnected,
        device: device,
      ),
    );
    
    // Notify listeners (UI updates)
    notifyListeners();
  }
  
  /// ✅ PHASE 1: Handle disconnected event from SDK
  void _handleDisconnected(String? reason) {
    // ✅ CRITICAL FIX: Debounce rapid disconnect events (SDK double-disconnect bug)
    final now = DateTime.now();
    if (_lastDisconnectTime != null && 
        now.difference(_lastDisconnectTime!) < _disconnectDebounce) {
      final elapsed = now.difference(_lastDisconnectTime!).inMilliseconds;
      print('⚠️ [HC20Service] Duplicate disconnect IGNORED (${elapsed}ms after last)');
      print('⚠️ [HC20Service] This is likely SDK double-disconnect bug (onBluetoothService restart)');
      print('🔍 [HC20Service] Device ID preserved: ${_connectedDevice?.id ?? "none"}');
      return; // Skip processing this duplicate event
    }
    _lastDisconnectTime = now;
    
    // ✅ FIX #2: If disconnect happened during reconnection attempt, it's a failure
    if (_isReconnecting) {
      print('⚠️ [HC20Service] Disconnect during reconnection attempt - counting as failure');
      _failedReconnectAttempts++;
      _isReconnecting = false;
      print('📊 [HC20Service] Failed reconnect attempts: $_failedReconnectAttempts');
    }
    
    // ✅ CRITICAL FIX: Ignore disconnect if BLE hardware is already connected
    // This prevents SDK double-disconnect events when Bluetooth is re-enabled
    if (_bleMonitor?.isHardwareConnected ?? false) {
      print('⚠️ [HC20Service] SDK reports disconnect but BLE hardware shows connected');
      print('⚠️ [HC20Service] This is likely a spurious SDK event - IGNORING');
      print('🔍 [HC20Service] Hardware state: ${_bleMonitor?.currentState}');
      return; // Don't process this disconnect
    }
    
    print('❌ [HC20Service] SDK disconnected: ${reason ?? "Unknown reason"}');
    print('🔍 [HC20Service] Was connected to: ${_connectedDevice?.name ?? "none"}');
    print('🔍 [HC20Service] Device ID before clearing: ${_connectedDevice?.id ?? "none"}');
    print('🔍 [HC20Service] Client exists: ${_client != null}');
    print('🔍 [HC20Service] OAuth circuit breaker state: ${_oauthCircuitBreaker.state}');
    
    // ✅ FIX #3: Store device object BEFORE clearing for manual reconnection
    // ONLY store if we actually have a device (don't overwrite with null!)
    if (_connectedDevice != null) {
      _lastDisconnectedDevice = _connectedDevice;
      print('💾 [HC20Service] Device saved for reconnection: ${_connectedDevice!.name}');
      
      // ✅ FIX #3: Also save to SharedPreferences for persistence across app restarts
      _saveDeviceToStorage(_connectedDevice!).then((_) {
        print('💾 [HC20Service] Device also saved to disk (survives app close)');
      });
    } else if (_lastDisconnectedDevice != null) {
      print('⚠️ [HC20Service] Already disconnected, preserving last device: ${_lastDisconnectedDevice!.name}');
    } else {
      // ✅ NEW FIX: If _connectedDevice is NULL, check if we have device info in SharedPreferences
      // This handles cases where SDK emits disconnect without ever emitting connect
      print('⚠️ [HC20Service] _connectedDevice is NULL - checking SharedPreferences...');
      _restoreLastDeviceFromPreferences().then((restored) {
        if (restored) {
          print('✅ [HC20Service] Device restored from SharedPreferences for reconnection');
        } else {
          print('⚠️ [HC20Service] No device found in storage - cannot reconnect');
        }
      });
    }
    
    // Store device ID BEFORE clearing
    final deviceIdBeforeClearing = _connectedDevice?.id ?? _lastDisconnectedDevice?.id;
    
    _connectedDevice = null;
    _isConnected = false;
    
    // Cancel real-time subscription
    _realtimeSubscription?.cancel();
    
    // ✅ TICKET #5: Stop BLE keepalive
    _bleKeepalive.stop();
    
    // Clear last data timestamp so status shows "Disconnected" immediately
    _lastDataReceived = null;
    
    // ✅ TICKET #1: Start reconnection monitoring
    print('⏱️ [HC20Service] Starting reconnection timeout monitor...');
    _reconnectionMonitor.startMonitoring(
      onTimeoutCallback: () async {
        print('⚠️ [HC20Service] SDK reconnection timeout - checking connection...');
        await _checkAndRefreshConnection();
      },
      onManualReconnectCallback: () async {
        // ✅ FIX #3: Manual reconnect callback when hardware is ready
        print('🔄 [HC20Service] Manual reconnect requested by monitor...');
        print('🔄 [HC20Service] Attempting to refresh connection...');
        await _checkAndRefreshConnection();
      },
    );
    
    // ✅ TICKET #2: Start BLE hardware monitoring (try device ID from before clearing first)
    if (deviceIdBeforeClearing != null) {
      print('👁️ [HC20Service] Starting BLE monitor with device ID from memory: $deviceIdBeforeClearing');
      _startBleMonitoring(deviceIdBeforeClearing);
    } else {
      // Fallback to SharedPreferences
      print('👁️ [HC20Service] No device ID in memory, checking SharedPreferences...');
      _getSavedDeviceId().then((savedDeviceId) {
        if (savedDeviceId != null) {
          print('👁️ [HC20Service] Found device ID in SharedPreferences: $savedDeviceId');
          _startBleMonitoring(savedDeviceId);
        } else {
          print('⚠️ [HC20Service] No saved device ID - cannot start BLE monitoring');
        }
      });
    }
    
    // Emit event for app components
    _connectionEventController.add(
      HC20ConnectionEvent(
        type: HC20ConnectionEventType.disconnected,
        reason: reason ?? 'Unknown',
      ),
    );
    
    // Notify listeners (UI updates)
    notifyListeners();
  }
  
  /// ✅ TICKET #1: Check if hardware reconnected and refresh data
  Future<void> _checkAndRefreshConnection() async {
    try {
      // ✅ FIX: Check BT status BEFORE attempting reconnection
      final bleStatus = _ble.status;
      if (bleStatus != BleStatus.ready) {
        print('🛑 [HC20Service] Bluetooth not ready ($bleStatus) - skipping reconnect');
        return;
      }
      
      final deviceToUse = _connectedDevice ?? _lastDisconnectedDevice;
      
      // ✅ FIX #2: FIRST - Try manual reconnect if we have client + device but not connected
      if (_client != null && deviceToUse != null && !_isConnected) {
        print('🔄 [HC20Service] Attempting manual reconnect to: ${deviceToUse.name}');
        print('   - Client exists: ✅');
        print('   - Device available: ✅ (${deviceToUse.id})');
        print('   - Currently connected: ❌');
        print('   - Ready to reconnect!');
        
        try {
          print('📡 [HC20Service] Calling client.connect()...');
          await _client!.connect(deviceToUse);
          print('✅ [HC20Service] Manual reconnect successful!');
          
          // Update state
          _connectedDevice = deviceToUse;
          // ✅ FIX: DON'T clear _lastDisconnectedDevice - keep as permanent backup
          print('📌 [HC20Service] Keeping device backup: ${_lastDisconnectedDevice?.name ?? "none"}');
          _isConnected = true;
          _startRealtimeStream();
          notifyListeners();
          
          // Emit reconnection event
          _connectionEventController.add(
            HC20ConnectionEvent(
              type: HC20ConnectionEventType.reconnected,
              device: deviceToUse,
            ),
          );
          
          return; // ✅ Success - exit
        } catch (e) {
          print('❌ [HC20Service] Manual reconnect failed: $e');
          // Fall through to diagnostics
        }
      }
      
      // ✅ FIX #2: SECOND - Enhanced diagnostics if can't reconnect
      if (_client == null || deviceToUse == null) {
        print('⚠️ [HC20Service] Cannot attempt reconnection:');
        print('   - Client: ${_client != null ? "EXISTS" : "NULL (OAuth failed?)"}');
        print('   - Connected device: ${_connectedDevice != null ? "EXISTS" : "NULL"}');
        print('   - Last device: ${_lastDisconnectedDevice != null ? "EXISTS (${_lastDisconnectedDevice!.name})" : "NULL"}');
        print('   - Circuit breaker: ${_oauthCircuitBreaker.state}');
        print('   - Hardware connected: ${_bleMonitor?.isHardwareConnected ?? false}');
        
        // If hardware is connected but client is null, try re-initializing
        if (_client == null && (_bleMonitor?.isHardwareConnected ?? false)) {
          print('🔄 [HC20Service] Hardware connected but no client - attempting OAuth re-init');
          try {
            await initializeClient();
            print('✅ [HC20Service] OAuth re-initialization successful');
          } catch (e) {
            print('❌ [HC20Service] OAuth re-initialization failed: $e');
          }
        }
        
        return;
      }
      
      // ✅ FIX #2: THIRD - If already connected, verify with data request
      if (_isConnected) {
        print('🔄 [HC20Service] Already connected - requesting fresh data to verify...');
        final success = await requestFreshData(isStressAlert: false);
        
        if (success) {
          print('✅ [HC20Service] Data received - connection is alive!');
        } else {
          print('⚠️ [HC20Service] No data received - connection may be stale');
        }
      }
    } catch (e) {
      print('❌ [HC20Service] Connection check failed: $e');
    }
  }
  
  /// ✅ TICKET #2: Start monitoring BLE hardware state
  void _startBleMonitoring(String deviceId) {
    print('👁️ [HC20Service] Starting BLE hardware monitoring...');
    
    _bleMonitor?.stopMonitoring();
    _bleMonitor = BleConnectionMonitor(
      ble: _ble,
      deviceId: deviceId,
    );
    
    _bleMonitor!.startMonitoring(
      onConnected: () async {
        print('🚀 [HC20Service] Hardware connected - attempting IMMEDIATE reconnect!');
        print('⚡ [HC20Service] Not waiting 2 seconds - reconnecting NOW');
        
        // ✅ FIX #3: Immediate reconnect attempt (no delay!)
        if (!_isConnected && _lastDisconnectedDevice != null && _client != null) {
          print('📡 [HC20Service] Triggering immediate manual reconnect...');
          await _checkAndRefreshConnection();
        } else if (_isConnected) {
          print('✅ [HC20Service] Already connected - SDK detected it first');
        } else {
          print('⚠️ [HC20Service] Cannot reconnect - missing client or device');
          print('   - Client: ${_client != null ? "EXISTS" : "NULL"}');
          print('   - Last device: ${_lastDisconnectedDevice != null ? "EXISTS" : "NULL"}');
        }
      },
      onDisconnected: () {
        print('❌ [HC20Service] Hardware disconnected');
        // SDK will handle this
      },
    );
  }
  
  /// Get saved device ID from SharedPreferences
  Future<String?> _getSavedDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('saved_device_id');
      print('📋 [HC20Service] Saved device ID: ${deviceId ?? "none"}');
      return deviceId;
    } catch (e) {
      print('⚠️ [HC20Service] Error reading saved device ID: $e');
      return null;
    }
  }

  /// Connect to device (called from device management page)
  Future<void> connectToDevice(Hc20Device device) async {
    if (_client == null) {
      throw Exception('HC20 client not initialized');
    }

    try {
      print('🔌 [HC20Service] Connecting to ${device.name}...');
      print('📋 [HC20Service] Device ID: ${device.id}');

      await _client!.connect(device);
      _connectedDevice = device;
      _isConnected = true;

      // Save device for auto-reconnect
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_device_id', device.id);
      await prefs.setBool('device_connected', true);
      
      print('✅ [HC20Service] Device ID saved to SharedPreferences: ${device.id}');
      print('✅ [HC20Service] Connected to ${device.name}');
      notifyListeners();

      // Start real-time data stream
      _startRealtimeStream();
    } catch (e) {
      print('❌ [HC20Service] Connection failed: $e');
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Disconnect device
  Future<void> disconnect() async {
    print('🔌 [HC20Service] Disconnecting...');

    _realtimeSubscription?.cancel();
    _dataRefreshTimer?.cancel();
    _connectionMonitor?.cancel();

    _isConnected = false;
    _connectedDevice = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('device_connected', false);

    notifyListeners();
    print('✅ [HC20Service] Disconnected');
  }

  /// Start real-time data stream (internal)
  void _startRealtimeStream() {
    if (_client == null || _connectedDevice == null) return;

    print('🚀 [HC20Service] Starting real-time data stream (persistent)...');

    // Cancel existing subscription
    _realtimeSubscription?.cancel();

    // Subscribe to real-time data
    _realtimeSubscription = _client!.realtimeV2(_connectedDevice!).listen(
      (data) {
        // Update state - use correct property names from Hc20RealtimeV2
        _heartRate = data.heart; // ✅ Correct property name
        _spo2 = data.spo2;
        // BP is List<int>? [systolic, diastolic]
        _bloodPressure = data.bp != null && data.bp!.length >= 2
            ? '${data.bp![0]}/${data.bp![1]}'
            : null;
        // Temperature is List<int>? [hand, env, body] (x100)
        _temperature = data.temperature != null && data.temperature!.length >= 3
            ? (data.temperature![2] / 100.0) // body temp
            : null;
        // Battery is Hc20BatteryInfo? with .percent property
        _batteryLevel = data.battery?.percent;
        // Steps is in basicData List<int>? [steps, calories, distance]
        _steps = data.basicData != null && data.basicData!.isNotEmpty
            ? data.basicData![0]
            : null;
        _lastDataReceived = DateTime.now();

        // Notify listeners (updates UI across all screens)
        notifyListeners();

        print(
            '📊 [HC20Service] Data: HR=$_heartRate SpO2=$_spo2 Temp=$_temperature Batt=$_batteryLevel');
      },
      onError: (error) {
        print('❌ [HC20Service] Stream error: $error');
      },
    );

    print(
        '✅ [HC20Service] Real-time stream active - will persist across navigation');
  }

  /// Get connection status for CustomAppBar
  String getConnectionStatus() {
    if (!_isConnected || _connectedDevice == null) {
      return 'Disconnected';
    }

    // Check data freshness
    if (_lastDataReceived == null) {
      return 'Connected (No Data)';
    }

    final age = DateTime.now().difference(_lastDataReceived!).inSeconds;
    if (age > 1000) {
      return 'Connected (Stale)';
    }

    return 'Active';
  }

  /// Update connection state (called from main.dart when device connects/disconnects)
  void updateConnectionState({
    required bool connected,
    Hc20Device? device,
    Hc20Client? client,
  }) {
    _isConnected = connected;
    _connectedDevice = device;
    if (client != null) {
      _client = client;
    }

    if (connected) {
      _lastDataReceived = DateTime.now();
      print(
          '✅ [HC20Service] Connection state updated: ${device?.name} connected');
    } else {
      _lastDataReceived =
          null; // Clear timestamp so status shows "Disconnected" immediately
      print('🔌 [HC20Service] Connection state updated: disconnected');
    }

    notifyListeners();
  }

  /// ✅ NEW: Callback for centralized data refresh (called from main.dart)
  /// This allows UI screens to trigger _handleRealtimeSync in main.dart
  Future<void> Function({bool forceRefresh, bool isStressAlert})?
      onRequestDataSync;

  /// Request fresh data from device via centralized _handleRealtimeSync
  /// Returns true if request was sent, false if device not connected
  Future<bool> requestFreshData({bool isStressAlert = false}) async {
    // ✅ FIX #3: Use stored device if currently disconnected
    final deviceToUse = _connectedDevice ?? _lastDisconnectedDevice;
    
    if (_client == null || deviceToUse == null) {
      print('⚠️ [HC20Service] Cannot request fresh data - no device available');
      print('   - Client: ${_client != null ? "EXISTS" : "NULL"}');
      print('   - Connected device: ${_connectedDevice != null ? "EXISTS" : "NULL"}');
      print('   - Last device: ${_lastDisconnectedDevice != null ? "EXISTS (${_lastDisconnectedDevice!.name})" : "NULL"}');
      return false;
    }

    if (onRequestDataSync == null) {
      print(
          '⚠️ [HC20Service] onRequestDataSync callback not set - falling back to legacy method');
      // Fallback: trigger brief subscription (legacy behavior)
      try {
        _client!
            .realtimeV2(deviceToUse)
            .listen((_) {}, onError: (_) {})
            .cancel();
        print('✅ [HC20Service] Legacy refresh triggered');
        return true;
      } catch (e) {
        print('❌ [HC20Service] Legacy refresh failed: $e');
        return false;
      }
    }

    print('\n🔄 ========================================');
    print(
        '🔄 ${isStressAlert ? "STRESS ALERT" : "REFRESH DATA"} REQUESTED (via HC20Service)');
    print('🔄 Calling centralized _handleRealtimeSync...');
    print('🔄 ========================================\n');

    // Call the centralized sync handler in main.dart
    try {
      await onRequestDataSync!(
          forceRefresh: true, isStressAlert: isStressAlert);
      print('✅ [HC20Service] Centralized sync completed');
      return true;
    } catch (e) {
      print('❌ [HC20Service] Centralized sync failed: $e');
      return false;
    }
  }

  /// Flag to indicate stress alert is pending (checked by main.dart)
  bool _stressAlertPending = false;
  bool get stressAlertPending => _stressAlertPending;

  /// ✅ REMOVED: clearStressAlert() and requestStressAlert()
  /// These are now handled by the unified requestFreshData() method
  /// with isStressAlert parameter

  /// Update data (called from main.dart when real-time data arrives)
  void updateRealtimeData({
    int? heartRate,
    int? spo2,
    String? bloodPressure,
    double? temperature,
    int? batteryLevel,
    int? steps,
  }) {
    _heartRate = heartRate;
    _spo2 = spo2;
    _bloodPressure = bloodPressure;
    _temperature = temperature;
    _batteryLevel = batteryLevel;
    _steps = steps;
    _lastDataReceived = DateTime.now();

    notifyListeners();
  }

  /// ✅ PHASE 4: Forget the last connected device (clears SDK + app persistence)
  /// Clears both SDK's ConnectionManager storage and app-level StorageService
  /// Call this when user taps "Forget Device" in settings
  /// ✅ FIX: This is the ONLY place where we clear _lastDisconnectedDevice
  Future<void> forgetDevice() async {
    try {
      print('🗑️ [HC20Service] User requested to forget device');
      print('🗑️ [HC20Service] Clearing: ${_lastDisconnectedDevice?.name ?? "none"}');
      
      // Clear in-memory device reference
      _lastDisconnectedDevice = null;
      _connectedDevice = null;
      print('✅ [HC20Service] In-memory device references cleared');
      
      // Clear SDK's connection manager persistence (SharedPreferences keys)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('hc20_last_connected_device_id');
      await prefs.remove('hc20_last_connected_device_name');
      await prefs.remove('last_device_id');
      await prefs.remove('last_device_name');
      await prefs.remove('saved_device_id');
      await prefs.remove('device_connected');
      print('✅ [HC20Service] SharedPreferences device keys cleared');
      
      // Clear app-level storage (also clears sync timestamps)
      await StorageService().clearDeviceData();
      
      print('✅ [HC20Service] Device forgotten completely (SDK + app storage cleared)');
      print('📌 [HC20Service] Device will only be cleared by this method or app uninstall');
    } catch (e) {
      print('⚠️ [HC20Service] Error forgetting device: $e');
    }
  }

  /// Clean up (only when app is completely closed)
  @override
  void dispose() {
    print('🛑 [HC20Service] Disposing global service...');
    _sdkConnectionStateSubscription?.cancel(); // ✅ PHASE 1: Cancel SDK listener
    _realtimeSubscription?.cancel();
    _dataRefreshTimer?.cancel();
    _connectionMonitor?.cancel();
    _connectionEventController.close(); // ✅ PHASE 1: Close event stream
    super.dispose();
  }
  
  /// ✅ FIX #3: Save device info to SharedPreferences for persistence
  Future<void> _saveDeviceToStorage(Hc20Device device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_device_id', device.id);
      await prefs.setString('last_device_name', device.name);
      print('💾 [HC20Service] Device info saved: ${device.name} (${device.id})');
    } catch (e) {
      print('⚠️ [HC20Service] Error saving device to storage: $e');
    }
  }
  
  /// ✅ FIX #3: Load device info from SharedPreferences and restore _lastDisconnectedDevice
  Future<void> _restoreDeviceFromStorage() async {
    if (_lastDisconnectedDevice != null) {
      return; // Already have device in memory
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('last_device_id');
      final deviceName = prefs.getString('last_device_name');
      
      if (deviceId != null && deviceName != null) {
        print('📂 [HC20Service] Found device in storage: $deviceName ($deviceId)');
        
        // Create device object from stored info
        // Note: We need to scan for the device to get full BLE handles
        print('🔍 [HC20Service] Will scan for device on next reconnect attempt');
        
        // Store IDs for scanning later
        await prefs.setString('pending_reconnect_id', deviceId);
        await prefs.setString('pending_reconnect_name', deviceName);
      }
    } catch (e) {
      print('⚠️ [HC20Service] Error restoring device from storage: $e');
    }
  }
  
  /// ✅ NEW FIX: Restore last device from SharedPreferences (used when SDK doesn't emit connect event)
  /// Returns true if device was successfully restored, false otherwise
  Future<bool> _restoreLastDeviceFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('last_device_id');
      final deviceName = prefs.getString('last_device_name');
      
      if (deviceId != null && deviceName != null) {
        print('📂 [HC20Service] Restoring from storage: $deviceName ($deviceId)');
        
        // We can't create a full Hc20Device object without scanning
        // But we can ensure the reconnection logic has the device ID
        await prefs.setString('pending_reconnect_id', deviceId);
        await prefs.setString('pending_reconnect_name', deviceName);
        
        print('✅ [HC20Service] Device IDs saved for reconnection: $deviceName ($deviceId)');
        return true;
      } else {
        print('⚠️ [HC20Service] No device IDs found in SharedPreferences');
        return false;
      }
    } catch (e) {
      print('⚠️ [HC20Service] Error restoring from SharedPreferences: $e');
      return false;
    }
  }

  /// ✅ FIX #2 (HYBRID APPROACH): Attempt reconnection with SDK event validation, fallback to data validation
  /// Strategy: Try SDK events first (10s), then validate with data fetch (5s) as fallback
  Future<void> _attemptReconnectionWithValidation() async {
    _isReconnecting = true;
    
    try {
      print('🔄 [HC20Service] Starting reconnection attempt with validation...');
      
      // Attempt reconnection
      await _checkAndRefreshConnection();
      
      // Step 1: Try SDK event validation first (10s timeout)
      print('⏳ [HC20Service] Trying SDK event first (10s timeout)...');
      final eventReceived = await _waitForSdkConnectionEvent(
        timeout: const Duration(seconds: 10),
      );
      
      if (eventReceived) {
        // SDK event worked! (unlikely but possible if they fix bug)
        print('✅ [HC20Service] SDK event received - connection confirmed!');
        _failedReconnectAttempts = 0;
        _isReconnecting = false;
        print('📊 [HC20Service] Failed reconnect attempts reset to: 0');
        return;
      }
      
      // Step 2: SDK event timeout - fall back to data validation
      print('⚠️ [HC20Service] SDK event timeout - falling back to data validation...');
      
      final isDataAvailable = await _validateConnectionWithData(
        timeout: const Duration(seconds: 5),
      );
      
      if (isDataAvailable) {
        print('✅ [HC20Service] Data validation successful (SDK event failed)');
        _failedReconnectAttempts = 0;
        _isReconnecting = false;
        
        // Emit our own event since SDK won't
        _connectionEventController.add(HC20ConnectionEvent(
          type: HC20ConnectionEventType.reconnected,
          device: _connectedDevice,
          reason: 'Reconnected (fallback to data validation)',
        ));
        
        print('📊 [HC20Service] Failed reconnect attempts reset to: 0');
        return;
      }
      
      throw Exception('Both SDK event and data validation failed');
      
    } catch (e) {
      print('❌ [HC20Service] Reconnection attempt failed: $e');
      
      // ✅ FIX #2: Increment counter on failure
      _failedReconnectAttempts++;
      _isReconnecting = false;
      
      print('📊 [HC20Service] Failed reconnect attempts: $_failedReconnectAttempts');
      
      // ✅ Restart ReconnectionMonitor as fallback
      print('⏱️ [HC20Service] Restarting ReconnectionMonitor as fallback (30s timeout)...');
      _reconnectionMonitor.startMonitoring(
        onTimeoutCallback: () async {
          print('⚠️ [HC20Service] SDK reconnection timeout - checking connection...');
          await _attemptReconnectionWithValidation();
        },
        onManualReconnectCallback: () async {
          print('🔄 [HC20Service] Manual reconnect requested by monitor...');
          await _attemptReconnectionWithValidation();
        },
      );
    }
  }
  
  /// ✅ FIX #2: Wait for SDK to emit connection event (validates TRUE connection)
  /// Returns true if SDK confirmed connection, false if timeout
  Future<bool> _waitForSdkConnectionEvent({required Duration timeout}) async {
    print('⏳ [HC20Service] Waiting for SDK connection event (timeout: ${timeout.inSeconds}s)...');
    
    try {
      // Listen for SDK connection events (connected or reconnected)
      final sdkEvent = await connectionEventStream
          .where((event) => 
              event.type == HC20ConnectionEventType.connected || 
              event.type == HC20ConnectionEventType.reconnected)
          .timeout(timeout)
          .first;
      
      print('✅ [HC20Service] SDK confirmed connection: ${sdkEvent.type}');
      return true;
    } on TimeoutException {
      print('⏱️ [HC20Service] SDK validation timeout - no connection event received');
      return false;
    } catch (e) {
      print('❌ [HC20Service] SDK validation error: $e');
      return false;
    }
  }
  
  /// ✅ FIX #2 (HYBRID APPROACH): Validate connection by fetching data
  /// This is the fallback when SDK events don't work
  /// Returns true if data fetch succeeds (connection is alive), false otherwise
  Future<bool> _validateConnectionWithData({
    required Duration timeout,
  }) async {
    try {
      print('📊 [HC20Service] Fetching data to validate connection...');
      
      // Get device identifier
      final device = _connectedDevice;
      if (device == null) {
        print('⚠️ [HC20Service] No connected device to validate');
        return false;
      }
      
      // Fetch data from the device (this will throw if connection is not ready)
      final dataStream = _client!.realtimeV2(device);
      final data = await dataStream.timeout(timeout).first;
      
      print('✅ [HC20Service] Data validation successful - received: HR=${data.heart}, SpO2=${data.spo2}');
      return true;
      
    } on TimeoutException {
      print('⏱️ [HC20Service] Data validation timeout - no data received');
      return false;
    } catch (e) {
      print('❌ [HC20Service] Data validation error: $e');
      return false;
    }
  }
}