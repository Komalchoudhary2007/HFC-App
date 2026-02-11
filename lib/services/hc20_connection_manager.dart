/// HC20 Connection Manager
///
/// Consolidates all HC20 BLE connection operations into a single service.
/// Handles: scanning, connecting, disconnecting, cleanup, and auto-reconnect.
///
/// ✅ Manages pure BLE operations
/// ⚠️ Callbacks handle app-specific logic (time sync, API, UI updates)
///
/// Migration from main.dart methods:
/// - _startScanning() → startScanning()
/// - _connectToDevice() → connectToDevice()
/// - _disconnect() → disconnect()
/// - _handleDisconnection() → handleDisconnection()
/// - _deepCleanupForReconnect() → deepCleanupForReconnect()
/// - _cleanup() → cleanup() (internal)
/// - _scanForSavedDevice() → scanForSavedDevice()
/// - _checkBluetoothEnabled() → checkBluetoothEnabled()
/// - _saveDeviceForAutoReconnect() → saveDeviceForAutoReconnect()
/// - _initializeHC20Client() → initializeClient()

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hc20/hc20.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';
import 'background_sync_service.dart';
import 'background_service_manager.dart';

/// Connection state enum
enum HC20ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Disconnect reasons for better error handling
enum HC20DisconnectReason {
  manual, // User manually disconnected
  deviceNotFound, // Device out of range
  bluetoothOff, // Bluetooth disabled
  gattError, // GATT/BLE error
  timeout, // Connection timeout
  maxRetriesReached, // Max reconnection attempts
  noInternet, // Network connectivity issue
}

/// Connection callbacks for app-specific logic
/// These callbacks allow main.dart to handle orchestration while manager handles BLE
class HC20ConnectionCallbacks {
  /// Called after successful BLE connection (before time sync)
  final Future<void> Function(Hc20Device device)? onConnected;

  /// Called to perform time synchronization with HC20 device
  final Future<void> Function(Hc20Device device, Hc20Client client)? onTimeSync;

  /// Called to associate device with user account (API call)
  final Future<void> Function(Hc20Device device)? onDeviceAssociation;

  /// Called to initialize sync scheduler after connection
  final Future<void> Function()? onInitializeScheduler;

  /// Called to start background services (native BLE, WorkManager)
  final Future<void> Function(Hc20Device device, String? userPhone)?
      onStartBackgroundServices;

  /// Called when disconnection occurs (for notifications, cleanup)
  final Future<void> Function(HC20DisconnectReason reason)? onDisconnected;

  /// Called when connection state changes (for UI updates)
  final void Function(HC20ConnectionState state, String message)?
      onStateChanged;

  /// Called when device is discovered during scanning
  final void Function(List<Hc20Device> devices)? onDevicesDiscovered;

  /// Called when device is forgotten (for resetting sync timestamps)
  final Future<void> Function()? onDeviceForgotten;

  HC20ConnectionCallbacks({
    this.onConnected,
    this.onTimeSync,
    this.onDeviceAssociation,
    this.onInitializeScheduler,
    this.onStartBackgroundServices,
    this.onDisconnected,
    this.onStateChanged,
    this.onDevicesDiscovered,
    this.onDeviceForgotten,
  });
}

/// HC20 Connection Manager Service
///
/// This service manages all BLE connection operations for HC20 devices.
/// It consolidates connection logic from main.dart into a reusable service.
class HC20ConnectionManager extends ChangeNotifier {
  // ==================== BLE State ====================
  Hc20Client? _client;
  Hc20Device? _connectedDevice;
  HC20ConnectionState _connectionState = HC20ConnectionState.disconnected;
  String _statusMessage = 'Not connected';

  // ==================== Reconnection State ====================
  bool _isReconnecting = false;
  bool _isAutoReconnecting = false;
  bool _isCleaningUpConnection = false;
  bool _isScanning = false;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 3;

  // ==================== Saved Device ====================
  String? _savedDeviceId;

  // ==================== Scanning ====================
  StreamSubscription? _scanSubscription;
  List<Hc20Device> _discoveredDevices = [];

  // ==================== Callbacks ====================
  HC20ConnectionCallbacks? _callbacks;

  // ==================== Background Service Flag ====================
  final bool _bgPluginEnabled = false; // Disabled on MIUI

  // ==================== Getters ====================
  Hc20Client? get client => _client;
  Hc20Device? get connectedDevice => _connectedDevice;
  HC20ConnectionState get connectionState => _connectionState;
  String get statusMessage => _statusMessage;
  bool get isConnected => _connectionState == HC20ConnectionState.connected;
  bool get isReconnecting => _isReconnecting;
  bool get isAutoReconnecting => _isAutoReconnecting;
  bool get isScanning => _isScanning;
  bool get isCleaningUp => _isCleaningUpConnection;
  String? get savedDeviceId => _savedDeviceId;
  List<Hc20Device> get discoveredDevices => _discoveredDevices;
  int get reconnectAttempts => _reconnectAttempts;

  // ==================== Initialize ====================

  /// Initialize HC20 client with OAuth credentials
  /// Call this once when the app starts or when user wants to connect
  Future<bool> initializeClient({
    String clientId = '0f3a3a9d342cd0b17859',
    String clientSecret = 'ac8c34f2c30466954c4da4c995885107fabc33d8',
  }) async {
    try {
      print('🔧 [Manager] Initializing HC20 client...');
      _updateState(
          HC20ConnectionState.connecting, 'Initializing HC20 client...');

      // Request Bluetooth permissions
      await _requestPermissions();

      // Create HC20 client with OAuth credentials
      _client = await Hc20Client.create(
        config: Hc20Config(
          clientId: clientId,
          clientSecret: clientSecret,
        ),
      );

      _updateState(HC20ConnectionState.disconnected,
          'HC20 client initialized. Ready to scan!');
      print('✅ [Manager] HC20 client initialized successfully');
      return true;
    } catch (e) {
      print('❌ [Manager] HC20 client initialization error: $e');
      _updateState(HC20ConnectionState.error,
          'Error: Invalid OAuth credentials. Contact dev team.');
      _client = null;
      return false;
    }
  }

  /// Request required Bluetooth permissions
  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ];

    for (final permission in permissions) {
      final status = await permission.request();
      if (status != PermissionStatus.granted) {
        print('⚠️ [Manager] Permission ${permission.toString()} not granted');
      }
    }
  }

  /// Set callbacks for app-specific logic
  void setCallbacks(HC20ConnectionCallbacks callbacks) {
    _callbacks = callbacks;
    print('✅ [Manager] Callbacks configured');
  }

  /// Load saved device ID from storage
  Future<void> loadSavedDevice() async {
    try {
      final deviceId = await StorageService().getSavedDeviceId();
      if (deviceId != null && deviceId.isNotEmpty) {
        _savedDeviceId = deviceId;
        print('💾 [Manager] Loaded saved device: $_savedDeviceId');
        notifyListeners();
      }
    } catch (e) {
      print('⚠️ [Manager] Error loading saved device: $e');
    }
  }

  /// Save device ID for auto-reconnect
  Future<void> saveDeviceForAutoReconnect(String deviceId) async {
    try {
      await StorageService().saveDeviceId(deviceId);
      _savedDeviceId = deviceId;
      print('💾 [Manager] Device ID saved: $deviceId');
      notifyListeners();
    } catch (e) {
      print('⚠️ [Manager] Error saving device ID: $e');
    }
  }

  /// Forget saved device (unpair for connecting new device)
  Future<void> forgetDevice() async {
    try {
      // First disconnect if currently connected
      if (_connectedDevice != null) {
        print('🔌 [Manager] Disconnecting before forgetting device...');
        await disconnect();
      }

      // Clear from storage (also clears sync timestamps)
      await StorageService().clearDeviceData();

      // Clear local state
      _savedDeviceId = null;
      _connectedDevice = null;
      _connectionState = HC20ConnectionState.disconnected;
      _statusMessage = 'Device forgotten. Ready to connect new device.';

      // Notify callback to reset sync timestamps in UI
      await _callbacks?.onDeviceForgotten?.call();

      print('🗑️ [Manager] Device forgotten successfully');
      notifyListeners();
    } catch (e) {
      print('⚠️ [Manager] Error forgetting device: $e');
    }
  }

  // ==================== Scanning ====================

  /// Start manual BLE scan for HC20 devices
  /// Returns list of discovered devices
  Future<void> startScanning({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_client == null) {
      final success = await initializeClient();
      if (!success) {
        _updateState(HC20ConnectionState.error,
            'Failed to initialize. Check OAuth credentials.');
        return;
      }
    }

    print('🔍 [Manager] Starting BLE scan (${timeout.inSeconds}s timeout)...');
    _updateState(
        HC20ConnectionState.connecting, 'Scanning for HC20 devices...');

    _isScanning = true;
    _discoveredDevices.clear();
    notifyListeners();

    // Cancel any existing scan
    await _scanSubscription?.cancel();

    _scanSubscription = _client!.scan().listen(
      (device) {
        if (!_discoveredDevices.any((d) => d.id == device.id)) {
          _discoveredDevices.add(device);
          print('   Found: ${device.name} (${device.id})');
          _updateState(HC20ConnectionState.connecting,
              'Found ${_discoveredDevices.length} device(s)');
          _callbacks?.onDevicesDiscovered?.call(_discoveredDevices);
        }
      },
      onError: (error) {
        print('❌ [Manager] Scan error: $error');
        _isScanning = false;
        _updateState(HC20ConnectionState.error, 'Scan error: $error');
      },
    );

    // Auto-stop scanning after timeout
    Future.delayed(timeout, () {
      if (_isScanning) {
        stopScanning();
        print(
            '⏱️ [Manager] Scan timeout - found ${_discoveredDevices.length} devices');
        _updateState(HC20ConnectionState.disconnected,
            'Scan completed. Found ${_discoveredDevices.length} device(s)');
      }
    });
  }

  /// Stop ongoing BLE scan
  void stopScanning() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    notifyListeners();
  }

  /// Scan specifically for saved device (for auto-reconnect)
  Future<Hc20Device?> scanForSavedDevice({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_savedDeviceId == null || _savedDeviceId!.isEmpty) {
      print('⚠️ [Manager] No saved device to scan for');
      return null;
    }

    if (isConnected || _isReconnecting || _isCleaningUpConnection) {
      print(
          '⚠️ [Manager] Cannot scan - busy (connected: $isConnected, reconnecting: $_isReconnecting)');
      return null;
    }

    print('🔍 [Manager] Scanning for saved device: $_savedDeviceId');
    _isAutoReconnecting = true;
    _updateState(HC20ConnectionState.reconnecting, 'Looking for device...');

    if (_client == null) {
      await initializeClient();
    }

    if (_client == null) {
      _isAutoReconnecting = false;
      return null;
    }

    final completer = Completer<Hc20Device?>();
    _discoveredDevices.clear();

    await _scanSubscription?.cancel();

    _scanSubscription = _client!.scan().listen(
      (device) {
        if (device.id == _savedDeviceId) {
          print('✅ [Manager] Found saved device: ${device.name}');
          _scanSubscription?.cancel();
          if (!completer.isCompleted) {
            completer.complete(device);
          }
        }
      },
      onError: (error) {
        print('❌ [Manager] Scan error: $error');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    // Timeout handling
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        _scanSubscription?.cancel();
        print('⏱️ [Manager] Saved device not found within timeout');
        completer.complete(null);
      }
    });

    final device = await completer.future;
    _isAutoReconnecting = false;

    if (device != null) {
      // Auto-connect to found device
      await connectToDevice(device);
    } else {
      _updateState(
          HC20ConnectionState.disconnected, 'Device not found. Will retry...');
    }

    return device;
  }

  /// Check if Bluetooth is enabled
  Future<bool> checkBluetoothEnabled() async {
    try {
      const platform = MethodChannel('com.hfc.app/background');
      final isEnabled =
          await platform.invokeMethod<bool>('isBluetoothEnabled') ?? true;
      return isEnabled;
    } catch (e) {
      print('⚠️ [Manager] Error checking Bluetooth: $e');
      return true; // Assume enabled if check fails
    }
  }

  // ==================== Connection ====================

  /// Connect to HC20 device with full lifecycle
  /// Handles: BLE connection + callbacks for time sync + API registration
  Future<bool> connectToDevice(Hc20Device device, {String? userPhone}) async {
    if (_client == null) {
      final success = await initializeClient();
      if (!success) return false;
    }

    try {
      print('🔌 [Manager] Connecting to ${device.name}...');
      _updateState(
          HC20ConnectionState.connecting, 'Connecting to ${device.name}...');

      // Cancel any ongoing scan
      stopScanning();

      // ===== 1. BLE Connection =====
      await _client!.connect(device).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('❌ [Manager] Connection timed out after 30 seconds');
          throw TimeoutException(
              'Connection timeout - device may be out of range');
        },
      );
      print('✅ [Manager] BLE connection established');

      // ===== 2. Read Device Info =====
      String deviceDisplayName = device.name;
      String deviceVersion = 'unknown';
      try {
        final info = await _client!.readDeviceInfo(device).timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('Device info timeout'),
            );
        deviceDisplayName = info.name;
        deviceVersion = info.version;
      } on TimeoutException {
        print('⚠️ [Manager] Using device.name as fallback: $deviceDisplayName');
      }

      // ===== 3. Time Synchronization (via callback) =====
      _updateState(
          HC20ConnectionState.connecting, 'Syncing time with device...');
      if (_callbacks?.onTimeSync != null) {
        await _callbacks!.onTimeSync!(device, _client!);
      } else {
        // Default time sync if no callback
        await _performDefaultTimeSync(device);
      }

      // ===== 4. Set User Parameters =====
      await _client!.setParameters(device, {
        'user_info': {
          'name': 'HFC User',
          'gender': 1,
          'height': 175,
          'weight': 70,
        },
      });

      // ===== 5. Update Connected State =====
      _connectedDevice = device;
      _connectionState = HC20ConnectionState.connected;
      _reconnectAttempts = 0;
      _isReconnecting = false;
      _isAutoReconnecting = false;
      _updateState(
        HC20ConnectionState.connected,
        'Connected to $deviceDisplayName v$deviceVersion',
      );

      print('✅ [Manager] Device connected successfully');

      // ===== 6. Callback: onConnected =====
      await _callbacks?.onConnected?.call(device);

      // ===== 7. Device Association (via callback) =====
      await _callbacks?.onDeviceAssociation?.call(device);

      // ===== 8. Initialize Scheduler (via callback) =====
      await _callbacks?.onInitializeScheduler?.call();

      // ===== 9. Save Device for Auto-Reconnect =====
      await saveDeviceForAutoReconnect(device.id);

      // ===== 10. Save Connection State to SharedPreferences =====
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('device_connected', true);
      await prefs.setString('saved_device_id', device.id);
      await prefs.setString('last_connected_device_id', device.id);
      await prefs.setString('last_connected_device_name', device.name);

      // ===== 11. Start Background Services (via callback) =====
      await _callbacks?.onStartBackgroundServices?.call(device, userPhone);

      // ===== 12. Start WorkManager for Background Sync =====
      await BackgroundSyncService.startPeriodicSync();
      print('✅ [Manager] WorkManager periodic sync started');

      print('✅ [Manager] Connection complete!');
      return true;
    } catch (e) {
      print('❌ [Manager] Connection error: $e');

      String errorMessage;
      bool isGattError = false;

      if (e.toString().contains('timeout') || e is TimeoutException) {
        errorMessage = 'Connection timeout - device may be out of range';
      } else if (e.toString().contains('service_discovery_failure') ||
          e.toString().contains('NoSuchElementException') ||
          e.toString().contains('status 8')) {
        errorMessage =
            'Connection failed: BLE resources need cleanup. Retrying...';
        isGattError = true;
        print(
            '🔧 [Manager] GATT/RxJava error detected - will perform deep cleanup');
      } else if (e.toString().contains('Invalid OAuth') ||
          e.toString().contains('401') ||
          e.toString().contains('authentication')) {
        errorMessage = 'Authentication failed: Invalid OAuth credentials.';
      } else {
        errorMessage = 'Connection failed: $e';
      }

      _updateState(HC20ConnectionState.error, errorMessage);

      // Handle GATT errors with deep cleanup
      if (isGattError && !_isCleaningUpConnection) {
        print('🔧 [Manager] Scheduling deep cleanup for GATT error...');
        Future.delayed(const Duration(seconds: 1), () {
          if (!isConnected && !_isCleaningUpConnection) {
            deepCleanupForReconnect();
          }
        });
      }

      return false;
    }
  }

  /// Default time sync implementation (used if no callback provided)
  Future<void> _performDefaultTimeSync(Hc20Device device) async {
    try {
      final now = DateTime.now();
      final offsetMinutes = now.timeZoneOffset.inMinutes;
      final offsetHours = offsetMinutes ~/ 60;
      final remainingMinutes = offsetMinutes % 60;
      final adjustedTimestamp =
          (now.millisecondsSinceEpoch ~/ 1000) + (remainingMinutes * 60);

      print('⏰ [Manager] Syncing time with device...');
      await _client!.setTime(
        device,
        timestamp: adjustedTimestamp,
        timezone: offsetHours,
      );
      print('✓ [Manager] Time synced successfully');
    } catch (e) {
      print('⚠️ [Manager] Time sync error: $e - continuing anyway');
    }
  }

  /// Public method to sync time with connected device
  Future<bool> syncTime() async {
    if (_connectedDevice == null || _client == null) {
      print('⚠️ [Manager] Cannot sync time - no device connected');
      return false;
    }
    try {
      await _performDefaultTimeSync(_connectedDevice!);
      return true;
    } catch (e) {
      print('❌ [Manager] Time sync failed: $e');
      return false;
    }
  }

  // ==================== Disconnection ====================

  /// Handle unexpected disconnection with auto-reconnect logic
  Future<void> handleDisconnection({
    HC20DisconnectReason reason = HC20DisconnectReason.deviceNotFound,
  }) async {
    if (_isReconnecting) {
      print('⏳ [Manager] Already attempting reconnection...');
      return;
    }

    print('⚠️ [Manager] Handling disconnection (reason: $reason)');

    // Check Bluetooth state
    final isBluetoothOn = await checkBluetoothEnabled();
    if (!isBluetoothOn) {
      reason = HC20DisconnectReason.bluetoothOff;
    }

    // Update SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('device_connected', false);

    // Notify callback
    await _callbacks?.onDisconnected?.call(reason);

    // Check max attempts
    if (_reconnectAttempts >= maxReconnectAttempts) {
      print('❌ [Manager] Max reconnection attempts reached');
      _updateState(
        HC20ConnectionState.disconnected,
        'Device out of range. Use manual reconnect.',
      );

      _reconnectAttempts = 0;
      _isReconnecting = false;
      _isCleaningUpConnection = false;

      await _callbacks?.onDisconnected
          ?.call(HC20DisconnectReason.maxRetriesReached);
      return;
    }

    // Start reconnection
    _isReconnecting = true;
    _reconnectAttempts++;

    print(
        '🔄 [Manager] Reconnection attempt $_reconnectAttempts/$maxReconnectAttempts');
    _updateState(
      HC20ConnectionState.reconnecting,
      'Reconnecting... (Attempt $_reconnectAttempts/$maxReconnectAttempts)',
    );

    // Deep cleanup before reconnect
    await deepCleanupForReconnect();

    // Verify client was re-initialized
    if (_client == null) {
      print('❌ [Manager] Client not available after cleanup');
      _updateState(HC20ConnectionState.error,
          'Failed to reinitialize. Please reconnect manually.');
      _isReconnecting = false;
      return;
    }

    // Attempt reconnect
    if (_connectedDevice != null) {
      try {
        print(
            '🔄 [Manager] Attempting reconnection to ${_connectedDevice!.name}...');
        final success = await connectToDevice(_connectedDevice!);
        if (success) {
          print('✅ [Manager] Reconnection successful!');
          _isReconnecting = false;
          _reconnectAttempts = 0;
        }
      } catch (e) {
        print('❌ [Manager] Reconnection failed: $e');
        _isReconnecting = false;

        // Retry after delay
        if (_reconnectAttempts < maxReconnectAttempts) {
          await Future.delayed(const Duration(seconds: 3));
          handleDisconnection(reason: reason);
        } else {
          _updateState(
            HC20ConnectionState.disconnected,
            'Reconnection failed. Use manual reconnect.',
          );
          _reconnectAttempts = 0;
          await _callbacks?.onDisconnected
              ?.call(HC20DisconnectReason.maxRetriesReached);
        }
      }
    } else {
      print('❌ [Manager] No device to reconnect to');
      _updateState(HC20ConnectionState.disconnected, 'No device to reconnect');
      _isReconnecting = false;
    }
  }

  /// Manual disconnect from device
  Future<void> disconnect() async {
    if (_client == null || _connectedDevice == null) {
      print('ℹ️ [Manager] No active connection to disconnect');
      return;
    }

    try {
      print('🔌 [Manager] Disconnecting from device...');
      _updateState(HC20ConnectionState.disconnected, 'Disconnecting...');

      // Stop native BLE service
      try {
        const platform = MethodChannel('com.hfc.app/background');
        await platform.invokeMethod('stopNativeBleService');
        print('✅ [Manager] Native BLE service stopped');
      } catch (e) {
        print('⚠️ [Manager] Could not stop native BLE service: $e');
      }

      // Stop background service
      try {
        const platform = MethodChannel('com.hfc.app/background');
        await platform.invokeMethod('disableBackgroundExecution');
        print('✅ [Manager] Background service stopped');
      } catch (e) {
        print('⚠️ [Manager] Could not stop background service: $e');
      }

      // Stop flutter_background_service keepalive (if enabled)
      if (_bgPluginEnabled) {
        try {
          await BackgroundServiceManager.instance.stop();
        } catch (e) {
          print('⚠️ [Manager] Could not stop BackgroundServiceManager: $e');
        }
      }

      // Disconnect from device
      await _client!.disconnect(_connectedDevice!);

      // Clean up
      cleanup();

      // Update state
      _connectedDevice = null;
      _updateState(HC20ConnectionState.disconnected, 'Disconnected');

      // Update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('device_connected', false);

      // Notify callback
      await _callbacks?.onDisconnected?.call(HC20DisconnectReason.manual);

      print('✅ [Manager] Disconnected successfully');
    } catch (e) {
      print('❌ [Manager] Disconnect error: $e');
      _updateState(HC20ConnectionState.error, 'Disconnect error: $e');
    }
  }

  // ==================== Cleanup ====================

  /// Basic cleanup (cancel subscriptions)
  void cleanup() {
    print('🧹 [Manager] Cleaning up subscriptions...');
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    print('✅ [Manager] Cleanup complete');
  }

  /// Deep cleanup - disposes client to release GATT resources
  /// Prevents "service_discovery_failure: NoSuchElementException"
  Future<void> deepCleanupForReconnect() async {
    if (_isCleaningUpConnection) {
      print('⏳ [Manager] Already cleaning up, skipping...');
      return;
    }

    _isCleaningUpConnection = true;
    print('🧹 [Manager] Starting deep cleanup for reconnect...');
    notifyListeners();

    try {
      // 1. Cancel subscriptions
      cleanup();

      // 2. Disconnect if still connected
      if (_client != null && _connectedDevice != null) {
        try {
          print('🔌 [Manager] Disconnecting from device...');
          await _client!.disconnect(_connectedDevice!);
          print('✅ [Manager] Device disconnected');
        } catch (e) {
          print(
              '⚠️ [Manager] Disconnect error (expected if already disconnected): $e');
        }
      }

      // 3. Clear device reference
      if (_connectedDevice != null) {
        print('🗑️ [Manager] Clearing device reference to prevent stale state');
        _connectedDevice = null;
      }

      // 4. Dispose client (critical for GATT cleanup)
      if (_client != null) {
        print('🗑️ [Manager] Disposing HC20 client...');
        _client = null;
        print('✅ [Manager] HC20 client disposed');
      }

      // 5. Wait for BLE stack reset
      print('⏳ [Manager] Waiting 5 seconds for BLE stack to reset...');
      await Future.delayed(const Duration(seconds: 5));

      // 6. Re-initialize client
      print('🔄 [Manager] Re-initializing HC20 client...');
      await initializeClient();

      if (_client == null) {
        print('❌ [Manager] Failed to re-initialize HC20 client');
      } else {
        print('✅ [Manager] HC20 client re-initialized successfully');
      }

      print('✅ [Manager] Deep cleanup complete');
    } finally {
      _isCleaningUpConnection = false;
      notifyListeners();
    }
  }

  /// Reset reconnection counter (useful for manual reconnect)
  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
    notifyListeners();
  }

  // ==================== State Management ====================

  /// Update state and notify listeners
  void _updateState(HC20ConnectionState state, String message) {
    _connectionState = state;
    _statusMessage = message;
    _callbacks?.onStateChanged?.call(state, message);
    notifyListeners();
  }

  @override
  void dispose() {
    cleanup();
    super.dispose();
  }
}
