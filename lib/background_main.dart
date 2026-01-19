import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hc20/hc20.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Background Main Entry Point
/// This runs in a headless Flutter engine (no UI) when app is closed
/// 
/// HOW IT WORKS:
/// 1. Native ForegroundService starts a headless Flutter engine
/// 2. Engine calls this entry point
/// 3. This code connects to HC20 device using the SDK
/// 4. Sends webhook data every 2 minutes
/// 5. Runs until service is stopped
@pragma('vm:entry-point')
void backgroundMain() async {
  print('🚀 [BACKGROUND] Headless Flutter Engine starting...');
  
  // Initialize Flutter bindings for headless mode
  WidgetsFlutterBinding.ensureInitialized();
  
  // Send immediate startup diagnostic webhook
  _sendDiagnosticWebhook('HEADLESS_STARTUP', {'stage': 'entry_point_called'});
  
  // Create the background service
  final service = BackgroundHC20Service();
  await service.initialize();
}

/// Send a quick diagnostic webhook to track startup progress
Future<void> _sendDiagnosticWebhook(String stage, Map<String, dynamic> data) async {
  try {
    final payload = {
      'source': 'HEADLESS_DIAGNOSTIC',
      'stage': stage,
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
    };
    
    await http.post(
      Uri.parse('https://api.hireforcare.com/webhook/hc20-data'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    print('📊 [DIAG] Sent diagnostic: $stage');
  } catch (e) {
    print('⚠️ [DIAG] Failed to send diagnostic: $e');
  }
}

/// Background HC20 Service
/// Runs HC20 SDK and sends webhooks when app UI is closed
class BackgroundHC20Service {
  static const _channel = MethodChannel('com.example.hfc_app/headless');
  static const _webhookUrl = 'https://api.hireforcare.com/webhook/hc20-data';
  
  String? _deviceId;
  String? _userPhone;
  Hc20Client? _hc20Client;
  Timer? _webhookTimer;
  Timer? _keepAliveTimer;
  StreamSubscription? _connectionSub;
  StreamSubscription? _dataSub;
  
  // Latest health data
  int? _heartRate;
  int? _spo2;
  double? _temperature;
  int? _batteryLevel;
  int? _bpSystolic;
  int? _bpDiastolic;
  int? _steps;
  bool _isConnected = false;
  DateTime? _lastDataTime;
  Hc20Device? _connectedDevice;
  
  /// Instance method for diagnostic webhook
  Future<void> _sendDiagnosticWebhookInstance(String stage, Map<String, dynamic> data) async {
    try {
      final payload = {
        'source': 'HEADLESS_DIAGNOSTIC',
        'stage': stage,
        'timestamp': DateTime.now().toIso8601String(),
        'phone': _userPhone,
        'deviceId': _deviceId,
        'data': data,
      };
      
      await http.post(
        Uri.parse(_webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      print('📊 [DIAG-INSTANCE] Sent: $stage');
    } catch (e) {
      print('⚠️ [DIAG-INSTANCE] Failed: $e');
    }
  }
  
  /// Initialize the background service
  Future<void> initialize() async {
    print('📦 [BACKGROUND] Initializing BackgroundHC20Service...');
    _showNotification('Background Service', 'Starting HeadlessFlutter HC20 service...');
    
    await _sendDiagnosticWebhookInstance('INIT_START', {});
    
    try {
      // Load saved device info from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString('last_connected_device_id');
      _userPhone = prefs.getString('user_phone');
      
      // Also try to get device name
      final deviceName = prefs.getString('last_connected_device_name') ?? 'HC20';
      
      print('   Device ID: $_deviceId');
      print('   Device Name: $deviceName');
      print('   User Phone: $_userPhone');
      
      await _sendDiagnosticWebhookInstance('PREFS_LOADED', {
        'deviceId': _deviceId,
        'deviceName': deviceName,
        'userPhone': _userPhone,
      });
      
      if (_deviceId == null || _deviceId!.isEmpty) {
        print('❌ [BACKGROUND] No device ID found!');
        _showNotification('HC20 Error', 'No device ID found. Open app and connect device first.', isError: true);
        await _sendDiagnosticWebhookInstance('NO_DEVICE_ID', {});
        _startWebhookTimer(); // Still start webhook to report status
        return;
      }
      
      // Setup method channel to receive commands from native
      _setupMethodChannel();
      
      // Start the HC20 connection with retry logic
      if (_deviceId != null && _deviceId!.isNotEmpty) {
        // CRITICAL: We need to SCAN first to find the device via BLE
        // The HC20 SDK requires a device from scan, not just a device ID
        print('🔍 [BACKGROUND] Will scan for device with ID: $_deviceId');
        _showNotification('Scanning', 'Looking for HC20 device...');
        
        // Initialize HC20 client first
        await _initializeHC20Client();
        
        if (_hc20Client == null) {
          print('❌ [BACKGROUND] Failed to create HC20 client');
          _showNotification('HC20 Error', 'Failed to initialize HC20 SDK', isError: true);
          await _sendDiagnosticWebhookInstance('CLIENT_INIT_FAILED', {});
          _startWebhookTimer();
          return;
        }
        
        await _sendDiagnosticWebhookInstance('CLIENT_INITIALIZED', {'hasClient': true});
        
        // Scan for the device
        bool found = await _scanAndFindDevice(_deviceId!, deviceName);
        
        await _sendDiagnosticWebhookInstance('SCAN_COMPLETED', {
          'deviceFound': found,
          'hasConnectedDevice': _connectedDevice != null,
        });
        
        if (found && _connectedDevice != null) {
          // Now connect to the found device
          int attempts = 0;
          const maxAttempts = 3;
          
          while (attempts < maxAttempts && !_isConnected) {
            attempts++;
            print('🔄 [BACKGROUND] Connection attempt $attempts/$maxAttempts');
            
            try {
              await _connectToFoundDevice();
              if (_isConnected) {
                print('✅ [BACKGROUND] Connected on attempt $attempts');
                await _sendDiagnosticWebhookInstance('CONNECTED', {'attempt': attempts});
                break;
              }
            } catch (e) {
              print('⚠️ [BACKGROUND] Attempt $attempts failed: $e');
              await _sendDiagnosticWebhookInstance('CONNECT_ATTEMPT_FAILED', {
                'attempt': attempts,
                'error': e.toString(),
              });
            }
            
            if (!_isConnected && attempts < maxAttempts) {
              print('   Waiting 5s before retry...');
              await Future.delayed(const Duration(seconds: 5));
            }
          }
          
          if (!_isConnected) {
            print('❌ [BACKGROUND] Failed to connect after $maxAttempts attempts');
            await _sendDiagnosticWebhookInstance('ALL_ATTEMPTS_FAILED', {'maxAttempts': maxAttempts});
            _log('Background HC20 connection failed after $maxAttempts attempts');
            _showNotification('Connection Failed', 'Could not connect to HC20 after $maxAttempts attempts', isError: true);
          }
        } else {
          print('❌ [BACKGROUND] Device not found via scan');
          _log('Device not found: $_deviceId');
          _showNotification('Device Not Found', 'HC20 device not in range or powered off', isError: true);
        }
      } else {
        print('⚠️ [BACKGROUND] No device ID - waiting for native to provide it');
      }
      
      // Start periodic webhook sender (will report status even without connection)
      _startWebhookTimer();
      
      // Start keep-alive timer (logs every minute to show we're running)
      _startKeepAliveTimer();
      
      print('✅ [BACKGROUND] BackgroundHC20Service initialized');
      _log('Background service started - connected: $_isConnected');
      
    } catch (e) {
      print('❌ [BACKGROUND] Initialization failed: $e');
      _log('Background service initialization failed: $e');
      
      // Still start webhook timer to report status
      _startWebhookTimer();
    }
  }
  
  /// Show notification (visible even when app is closed)
  Future<void> _showNotification(String title, String message, {bool isError = false}) async {
    print('🔔 [BACKGROUND] NOTIFICATION: $title - $message');
    try {
      await _channel.invokeMethod('showNotification', {
        'title': title,
        'message': message,
        'isError': isError,
      });
    } catch (e) {
      print('⚠️ [BACKGROUND] Failed to show notification: $e');
    }
  }
  
  /// Setup method channel to receive data from native
  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'initialize':
          // Receive device info from native service
          final args = call.arguments as Map<dynamic, dynamic>;
          final deviceMac = args['deviceMac'] as String?;
          _userPhone ??= args['userPhone'] as String?;
          print('📱 [BACKGROUND] Received from native: device=$deviceMac phone=$_userPhone');
          
          // If we got a MAC address, try to find matching device ID
          // (HC20 SDK uses device ID from BLE scan, not MAC directly)
          
          return true;
          
        case 'stop':
          print('🛑 [BACKGROUND] Received stop command');
          await _cleanup();
          return true;
          
        default:
          return null;
      }
    });
  }
  
  /// Initialize HC20 Client with OAuth credentials
  Future<void> _initializeHC20Client() async {
    print('📋 [BACKGROUND] Initializing HC20 Client...');
    await _sendDiagnosticWebhookInstance('HC20_CLIENT_CREATING', {});
    
    const clientId = '0f3a3a9d342cd0b17859';
    const clientSecret = 'ac8c34f2c30466954c4da4c995885107fabc33d8';
    
    try {
      _hc20Client = await Hc20Client.create(
        config: Hc20Config(
          clientId: clientId,
          clientSecret: clientSecret,
        ),
      );
      print('✅ [BACKGROUND] HC20 Client created successfully');
      _log('HC20 Client created');
      await _sendDiagnosticWebhookInstance('HC20_CLIENT_CREATED', {'success': true});
    } catch (e, stackTrace) {
      print('❌ [BACKGROUND] Failed to create HC20 client: $e');
      print('   Stack: $stackTrace');
      _log('CRITICAL: Hc20Client.create() failed: $e');
      await _sendDiagnosticWebhookInstance('HC20_CLIENT_FAILED', {
        'error': e.toString(),
        'stackTrace': stackTrace.toString().substring(0, 500),
      });
      _hc20Client = null;
    }
  }
  
  /// Scan for HC20 device by ID
  /// Returns true if device was found
  Future<bool> _scanAndFindDevice(String targetDeviceId, String deviceName) async {
    if (_hc20Client == null) {
      print('❌ [BACKGROUND] Cannot scan - no client');
      await _sendDiagnosticWebhookInstance('SCAN_NO_CLIENT', {});
      return false;
    }
    
    print('🔍 [BACKGROUND] Scanning for device: $targetDeviceId');
    _showNotification('Scanning', 'Looking for HC20 device...');
    
    await _sendDiagnosticWebhookInstance('SCAN_STARTING', {
      'targetDeviceId': targetDeviceId,
      'deviceName': deviceName,
    });
    
    bool found = false;
    List<String> devicesFound = [];
    
    try {
      // Scan for 30 seconds max
      await for (final device in _hc20Client!.scan().timeout(
        const Duration(seconds: 30),
        onTimeout: (sink) {
          print('⏱️ [BACKGROUND] Scan timeout after 30s');
          sink.close();
        },
      )) {
        print('   Found device: ${device.name} (${device.id})');
        devicesFound.add('${device.name}:${device.id}');
        
        // Check if this is the device we're looking for
        if (device.id == targetDeviceId) {
          print('✅ [BACKGROUND] TARGET DEVICE FOUND!');
          print('   Name: ${device.name}');
          print('   ID: ${device.id}');
          _connectedDevice = device;
          found = true;
          await _sendDiagnosticWebhookInstance('SCAN_FOUND_TARGET', {
            'deviceName': device.name,
            'deviceId': device.id,
            'totalDevicesScanned': devicesFound.length,
          });
          break; // Stop scanning once we find our device
        }
      }
    } catch (e, stackTrace) {
      print('⚠️ [BACKGROUND] Scan error: $e');
      print('   Stack: $stackTrace');
      _log('Scan error: $e');
      await _sendDiagnosticWebhookInstance('SCAN_ERROR', {
        'error': e.toString(),
        'devicesFoundBeforeError': devicesFound,
      });
    }
    
    if (found) {
      print('✅ [BACKGROUND] Device found and ready for connection');
      _showNotification('Device Found', 'HC20 found, connecting...');
    } else {
      print('❌ [BACKGROUND] Device not found in scan');
      await _sendDiagnosticWebhookInstance('SCAN_NOT_FOUND', {
        'devicesFound': devicesFound,
        'targetDeviceId': targetDeviceId,
      });
      // Try creating device directly as fallback (may work if BLE cache has it)
      print('⚠️ [BACKGROUND] Trying fallback: creating device from saved ID');
      await _sendDiagnosticWebhookInstance('SCAN_FALLBACK_CREATING', {
        'targetDeviceId': targetDeviceId,
        'deviceName': deviceName,
      });
      _connectedDevice = Hc20Device(targetDeviceId, deviceName);
      found = true; // Try anyway
    }
    
    return found;
  }
  
  /// Connect to the found device
  Future<void> _connectToFoundDevice() async {
    if (_connectedDevice == null) {
      print('❌ [BACKGROUND] Cannot connect - no device');
      _log('ERROR: No device to connect');
      return;
    }
    
    if (_hc20Client == null) {
      print('❌ [BACKGROUND] Cannot connect - no client');
      _log('ERROR: No HC20 client');
      return;
    }
    
    print('🔌 [BACKGROUND] Connecting to HC20: ${_connectedDevice!.id}');
    print('   Device name: ${_connectedDevice!.name}');
    _log('Attempting HC20 connection to ${_connectedDevice!.id}');
    _showNotification('Connecting', 'Connecting to ${_connectedDevice!.name}...');
    
    try {
      // Listen to connection state changes
      _connectionSub = _hc20Client!.connectionState.listen((update) {
        print('🔌 [BACKGROUND] Connection state: ${update.state}');
        _isConnected = update.state == Hc20ConnectionState.connected ||
                       update.state == Hc20ConnectionState.reconnected;
        
        if (!_isConnected) {
          // Connection manager handles auto-reconnect
          print('   Auto-reconnect is enabled, SDK will handle reconnection');
        }
      });
      
      // Connect to device with detailed logging
      print('🔗 [BACKGROUND] Calling _hc20Client.connect()...');
      _log('Connecting to HC20 device...');
      
      try {
        await _hc20Client!.connect(_connectedDevice!);
        print('✅ [BACKGROUND] HC20 connected successfully!');
        _isConnected = true;
        _log('HC20 connected in background');
        _showNotification('HC20 Connected', 'Device connected successfully, receiving data...');
      } catch (e, stackTrace) {
        print('❌ [BACKGROUND] CRITICAL: _hc20Client.connect() failed!');
        print('   Error: $e');
        print('   Stack: $stackTrace');
        _log('CRITICAL: connect() failed: $e');
        _showNotification('HC20 Connection Failed', 'Failed to connect: ${e.toString().substring(0, 100)}', isError: true);
        throw Exception('HC20 connect failed: $e');
      }
      
      // Start listening for data
      print('👂 [BACKGROUND] Starting data listening...');
      try {
        await _startDataListening();
        print('✅ [BACKGROUND] Data listening started');
      } catch (e, stackTrace) {
        print('❌ [BACKGROUND] CRITICAL: _startDataListening() failed!');
        print('   Error: $e');
        print('   Stack: $stackTrace');
        _log('CRITICAL: Data listening failed: $e');
        _showNotification('HC20 Data Error', 'Failed to start receiving data: $e', isError: true);
      }
      
    } catch (e, stackTrace) {
      print('❌ [BACKGROUND] HC20 connection error: $e');
      print('   Stack trace: $stackTrace');
      _log('HC20 error: $e');
      _showNotification('HC20 Error', 'Connection error: ${e.toString().substring(0, 100)}', isError: true);
      
      // SDK has auto-reconnect built in, so we just log the error
      // ConnectionManager will attempt periodic reconnection
      // But we want to see the specific error to diagnose BLE issues
    }
  }
  
  /// Start listening for health data from HC20
  Future<void> _startDataListening() async {
    if (_hc20Client == null || _connectedDevice == null) {
      print('⚠️ [BACKGROUND] Cannot start data listening - client or device is null');
      _log('Cannot start data listening: client=${_hc20Client != null} device=${_connectedDevice != null}');
      return;
    }
    
    print('👂 [BACKGROUND] Starting data listening...');
    
    try {
      // Enable sensors to start receiving data (correct API)
      print('🔧 [BACKGROUND] Calling setSensorState()...');
      _log('Enabling HC20 sensors...');
      
      try {
        await _hc20Client!.setSensorState(_connectedDevice!);
        print('✅ [BACKGROUND] Sensors enabled');
        _log('HC20 sensors enabled successfully');
      } catch (e, stackTrace) {
        print('❌ [BACKGROUND] CRITICAL: setSensorState() failed!');
        print('   Error: $e');
        print('   Stack: $stackTrace');
        _log('CRITICAL: setSensorState() failed: $e');
        rethrow;
      }
      
      // Listen for realtime health data using realtimeV2 stream (correct API)
      print('📡 [BACKGROUND] Setting up realtimeV2 stream listener...');
      _log('Setting up data stream...');
      
      _dataSub = _hc20Client!.realtimeV2(_connectedDevice!).listen(
        (data) {
        print('📊 [BACKGROUND] Health data received');
        
        // Update local cache from Hc20RealtimeV2 data
        if (data.heart != null) _heartRate = data.heart;
        if (data.spo2 != null) _spo2 = data.spo2;
        if (data.battery != null) _batteryLevel = data.battery?.percent;
        
        // Temperature is in [hand, env, body] × 100 format
        if (data.temperature != null && data.temperature!.length >= 3) {
          _temperature = data.temperature![2] / 100.0; // Body temp
        }
        
        // Blood pressure is [systolic, diastolic]
        if (data.bp != null && data.bp!.length >= 2) {
          _bpSystolic = data.bp![0];
          _bpDiastolic = data.bp![1];
        }
        
        // Steps from basicData [steps, calories, distance]
        if (data.basicData != null && data.basicData!.isNotEmpty) {
          _steps = data.basicData![0];
        }
        
        _lastDataTime = DateTime.now();
        
        print('   HR: $_heartRate | SpO2: $_spo2 | Temp: $_temperature');
        
        // Show notification only on first successful data received
        if (_heartRate != null && _lastDataTime != null) {
          final age = DateTime.now().difference(_lastDataTime!).inSeconds;
          if (age < 5) { // Only show if this is fresh first data
            _showNotification('HC20 Live Data', 'Receiving health data: HR=$_heartRate, SpO2=$_spo2');
          }
        }
        
        // Notify native about the data
        _channel.invokeMethod('onDataReceived', {
          'heartRate': _heartRate,
          'spo2': _spo2,
          'temperature': _temperature,
          'batteryLevel': _batteryLevel,
        });
      },
        onError: (error, stackTrace) {
          print('❌ [BACKGROUND] STREAM ERROR: $error');
          print('   Stack: $stackTrace');
          _log('Data stream error: $error');
          _showNotification('HC20 Stream Error', 'Data stream error: $error', isError: true);
        },
        onDone: () {
          print('⚠️ [BACKGROUND] Data stream closed');
          _log('Data stream closed');
        },
      );
      
      print('✅ [BACKGROUND] Data listening stream subscribed');
      _log('Data listening started successfully');
      
    } catch (e, stackTrace) {
      print('❌ [BACKGROUND] Error starting data listener: $e');
      print('   Stack: $stackTrace');
      _log('Data listener error: $e');
    }
  }
  
  /// Start periodic webhook timer (every 2 minutes)
  void _startWebhookTimer() {
    print('⏰ [BACKGROUND] Starting webhook timer (2-min interval)');
    
    _webhookTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _sendWebhook();
    });
    
    // Also send one immediately
    Future.delayed(const Duration(seconds: 10), () => _sendWebhook());
  }
  
  /// Start keep-alive timer (logs every minute)
  void _startKeepAliveTimer() {
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final now = DateTime.now();
      final dataAge = _lastDataTime != null 
          ? now.difference(_lastDataTime!).inSeconds 
          : -1;
      
      print('💓 [BACKGROUND] Keep-alive: ${now.toIso8601String()}');
      print('   Connected: $_isConnected');
      print('   Last data: ${dataAge >= 0 ? "${dataAge}s ago" : "never"}');
      print('   HR: $_heartRate | SpO2: $_spo2');
    });
  }
  
  /// Send webhook with current health data
  Future<void> _sendWebhook() async {
    print('\n📤 [BACKGROUND-WEBHOOK] Sending webhook...');
    
    try {
      final now = DateTime.now();
      final dataAge = _lastDataTime != null 
          ? now.difference(_lastDataTime!).inSeconds 
          : -1;
      
      final payload = {
        'phone': _userPhone ?? 'unknown',
        'deviceId': _deviceId ?? 'unknown',
        'timestamp': now.millisecondsSinceEpoch,
        'timestampReadable': now.toIso8601String(),
        'source': 'HEADLESS_FLUTTER_DART',
        'method': 'background_hc20_service',
        'interval': '2_minutes',
        'isConnected': _isConnected,
        'hasClient': _hc20Client != null,
        'hasDevice': _connectedDevice != null,
        'dataAgeSeconds': dataAge,
        'lastDataTimeReadable': _lastDataTime?.toIso8601String(),
        'heartRate': _heartRate,
        'spo2': _spo2,
        'temperature': _temperature,
        'batteryLevel': _batteryLevel,
        'bloodPressureSystolic': _bpSystolic,
        'bloodPressureDiastolic': _bpDiastolic,
        'steps': _steps,
        'message': _isConnected 
            ? 'Background HC20 connection active - live data flowing'
            : 'HeadlessFlutter running - HC20 NOT connected (scan/connect may have failed)',
        'debug': {
          'deviceIdLoaded': _deviceId,
          'userPhoneLoaded': _userPhone,
          'clientCreated': _hc20Client != null,
          'deviceFound': _connectedDevice != null,
          'isConnectedFlag': _isConnected,
          'heartRateReceived': _heartRate != null,
        }
      };
      
      print('📋 [BACKGROUND-WEBHOOK] Payload debug:');
      print('   deviceId: $_deviceId');
      print('   isConnected: $_isConnected');
      print('   hasClient: ${_hc20Client != null}');
      print('   hasDevice: ${_connectedDevice != null}');
      print('   heartRate: $_heartRate');
      
      final response = await http.post(
        Uri.parse(_webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      
      print('✅ [BACKGROUND-WEBHOOK] Response: ${response.statusCode}');
      print('   Data: HR=$_heartRate SpO2=$_spo2 Connected=$_isConnected');
      
      // Notify native
      _channel.invokeMethod('onWebhookSent', {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
      });
      
    } catch (e, stackTrace) {
      print('❌ [BACKGROUND-WEBHOOK] Failed: $e');
      print('   Stack: $stackTrace');
      _channel.invokeMethod('onWebhookSent', {
        'success': false,
        'error': e.toString(),
      });
    }
  }
  
  /// Log a message to native
  void _log(String message) {
    try {
      _channel.invokeMethod('log', {'message': message});
    } catch (e) {
      print('⚠️ [BACKGROUND] Failed to log to native: $e');
    }
  }
  
  /// Cleanup resources
  Future<void> _cleanup() async {
    print('🧹 [BACKGROUND] Cleaning up...');
    
    _webhookTimer?.cancel();
    _keepAliveTimer?.cancel();
    _connectionSub?.cancel();
    _dataSub?.cancel();
    
    try {
      if (_connectedDevice != null && _hc20Client != null) {
        await _hc20Client!.disableSensorState(_connectedDevice!);
        await _hc20Client!.disconnect(_connectedDevice!);
      }
    } catch (e) {
      print('⚠️ [BACKGROUND] Error disconnecting HC20: $e');
    }
    
    _hc20Client = null;
    _isConnected = false;
    
    print('✅ [BACKGROUND] Cleanup complete');
  }
}
