import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hc20/hc20.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Background service that runs in a separate isolate to maintain HC20 connection
/// even when the app UI is closed. This INDEPENDENTLY connects to HC20.
/// Works completely independently - continues when main app is closed!
class BackgroundIsolateService {
  static const String _notificationChannelId = 'hfc_background_service';
  static const String _notificationChannelName = 'HFC Background Service';
  static const int _notificationId = 888;
  
  /// Initialize and start the background service
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    
    // Configure notification channel for foreground service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: 'This notification keeps the HC20 device connected in background',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Configure the background service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'HFC Background Service',
        initialNotificationContent: 'Connecting to HC20 device...',
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    
    await service.startService();
  }

  /// Stop the background service
  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  /// Update device info from UI (when user selects device)
  static Future<void> updateDeviceInfo(String deviceId, String deviceName, String? userPhone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', deviceId);
    await prefs.setString('device_name', deviceName);
    if (userPhone != null) {
      await prefs.setString('user_phone', userPhone);
    }
    
    final service = FlutterBackgroundService();
    service.invoke('updateDevice', {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'userPhone': userPhone ?? 'unknown',
    });
  }

  /// Update webhook URL from UI
  static Future<void> updateWebhookUrl(String webhookUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webhook_url', webhookUrl);
    
    final service = FlutterBackgroundService();
    service.invoke('updateWebhook', {
      'webhookUrl': webhookUrl,
    });
  }

  /// Send health data to background service for webhook transmission
  /// NOTE: This is used by main app, but background service ALSO connects independently
  static Future<void> sendHealthData(Map<String, dynamic> healthData) async {
    final service = FlutterBackgroundService();
    service.invoke('healthData', healthData);
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  /// Main background service entry point - runs in separate isolate
  /// This is the critical method that keeps running even when app UI is closed
  @pragma('vm:entry-point')
  static Future<void> onStart(ServiceInstance service) async {
    print('[Background-Service] ========================================');
    print('[Background-Service] 🚀 BACKGROUND SERVICE STARTED');
    print('[Background-Service] ========================================');
    
    try {
      DartPluginRegistrant.ensureInitialized();
      print('[Background-Service] ✅ DartPluginRegistrant initialized');
    } catch (e) {
      print('[Background-Service] ❌ DartPluginRegistrant error: $e');
    }

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
      
      print('[Background-Service] ✅ Android service configured');
    }

    service.on('stopService').listen((event) {
      print('[Background-Service] 🛑 Stop service requested');
      service.stopSelf();
    });
    
    // Handle request to launch the Flutter app
    service.on('launchApp').listen((event) async {
      print('[Background-Service] 🚀 Received launchApp request');
    });

    print('[Background-Service] 🔧 Initializing HC20 worker...');
    
    // Update notification immediately to show we're starting
    if (service is AndroidServiceInstance) {
      (service as AndroidServiceInstance).setForegroundNotificationInfo(
        title: 'HFC Background [STEP 1]',
        content: '⏳ Creating worker instance...',
      );
    }

    try {
      // Initialize the HC20 background worker
      print('[Background-Service] Creating _HC20BackgroundWorker instance...');
      final worker = _HC20BackgroundWorker(service);
      print('[Background-Service] ✅ Worker instance created');
      
      if (service is AndroidServiceInstance) {
        (service as AndroidServiceInstance).setForegroundNotificationInfo(
          title: 'HFC Background [STEP 2]',
          content: '⏳ Calling worker.initialize()...',
        );
      }
      
      print('[Background-Service] About to call worker.initialize()...');
      await worker.initialize();
      print('[Background-Service] ✅ Worker initialized');
      
      if (service is AndroidServiceInstance) {
        (service as AndroidServiceInstance).setForegroundNotificationInfo(
          title: 'HFC Background [STEP 3]',
          content: '⏳ Calling worker.start()...',
        );
      }
      
      print('[Background-Service] About to call worker.start()...');
      await worker.start();
      print('[Background-Service] ✅ Worker started successfully');
      
      if (service is AndroidServiceInstance) {
        (service as AndroidServiceInstance).setForegroundNotificationInfo(
          title: 'HFC Background [RUNNING]',
          content: '✅ All timers active - webhooks every 3min',
        );
      }
      
    } catch (e, stackTrace) {
      print('[Background-Service] ❌❌❌ CRITICAL ERROR IN WORKER ❌❌❌');
      print('[Background-Service] Error: $e');
      print('[Background-Service] Stack trace: $stackTrace');
      
      // Show detailed error in notification
      final errorMsg = e.toString();
      if (service is AndroidServiceInstance) {
        (service as AndroidServiceInstance).setForegroundNotificationInfo(
          title: '❌ Background Service CRASHED',
          content: errorMsg.length > 80 ? '${errorMsg.substring(0, 80)}...' : errorMsg,
        );
      }
    }
  }
}

/// Worker class that INDEPENDENTLY connects to HC20 and streams data
/// This runs in a separate isolate and continues even when main app is closed
class _HC20BackgroundWorker {
  final ServiceInstance service;
  Hc20Client? _hc20Client;
  Hc20Device? _connectedDevice;
  String? _deviceId;
  String? _deviceName;
  String? _webhookUrl;
  String? _userPhone;
  Timer? _webhookTimer;
  Timer? _reconnectTimer;
  Map<String, dynamic>? _latestData;
  bool _isConnected = false;
  String? _lastError;
  int _webhooksSent = 0;
  int _reconnectAttempts = 0;
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _connectionSubscription;
  
  _HC20BackgroundWorker(this.service);

  Future<void> initialize() async {
    print('[Background-Isolate] ========================================');
    print('[Background-Isolate] 🔧 INITIALIZING WORKER');
    print('[Background-Isolate] ========================================');
    
    try {
      // Load saved configuration
      print('[Background-Isolate] Step 1: Loading SharedPreferences...');
      _updateNotification('⏳ INIT Step 1: Loading config...');
      
      final prefs = await SharedPreferences.getInstance();
      print('[Background-Isolate] ✅ SharedPreferences loaded');
      _updateNotification('✅ INIT Step 1: Config loaded');
      await Future.delayed(Duration(milliseconds: 500));
      
      print('[Background-Isolate] Step 2: Reading configuration values...');
      _updateNotification('⏳ INIT Step 2: Reading values...');
      
      _deviceId = prefs.getString('device_id');
      _deviceName = prefs.getString('device_name');
      _webhookUrl = prefs.getString('webhook_url');
      _userPhone = prefs.getString('user_phone');
      
      print('[Background-Isolate] ========================================');
      print('[Background-Isolate] 📋 CONFIGURATION:');
      print('[Background-Isolate]    Device ID: $_deviceId');
      print('[Background-Isolate]    Device Name: $_deviceName');
      print('[Background-Isolate]    Webhook URL: $_webhookUrl');
      print('[Background-Isolate]    User Phone: $_userPhone');
      print('[Background-Isolate] ========================================');
      
      if (_deviceId == null || _deviceId!.isEmpty) {
        _updateNotification('⚠️ NO DEVICE - Open app & select HC20 device');
      } else if (_webhookUrl == null || _webhookUrl!.isEmpty) {
        _updateNotification('⚠️ NO WEBHOOK - Open app & set webhook URL');
      } else {
        final webhookPreview = _webhookUrl!.length > 20 ? '${_webhookUrl!.substring(0, 20)}...' : _webhookUrl!;
        _updateNotification('✅ Config: Device=$_deviceName | Webhook=$webhookPreview');
      }
      
      await Future.delayed(Duration(milliseconds: 500));
      
    } catch (e, stackTrace) {
      print('[Background-Isolate] ❌ INITIALIZATION ERROR: $e');
      print('[Background-Isolate] Stack: $stackTrace');
      final errorMsg = e.toString();
      _updateNotification('❌ INIT FAILED: ${errorMsg.length > 60 ? errorMsg.substring(0, 60) + "..." : errorMsg}');
      rethrow;
    }
    
    print('[Background-Isolate] Step 3: Setting up event listeners...');
    _updateNotification('⏳ INIT Step 3: Event listeners...');
    
    // Listen for updates from UI
    service.on('updateDevice').listen((event) async {
      print('[Background-Isolate] 📥 Received updateDevice event');
      _deviceId = event?['deviceId'];
      _deviceName = event?['deviceName'];
      _userPhone = event?['userPhone'];
      print('[Background-Isolate] Device updated: $_deviceName ($_deviceId)');
      
      // Reconnect to new device
      await _disconnect();
      await _connectToDevice();
    });

    service.on('updateWebhook').listen((event) {
      print('[Background-Isolate] 📥 Received updateWebhook event');
      _webhookUrl = event?['webhookUrl'];
      print('[Background-Isolate] Webhook updated: $_webhookUrl');
    });
    
    print('[Background-Isolate] ✅ Initialization complete');
    _updateNotification('✅ INIT Complete - Ready to start');
    await Future.delayed(Duration(milliseconds: 500));
  }

  Future<void> start() async {
    print('[Background-Isolate] ========================================');
    print('[Background-Isolate] 🚀 STARTING WORKER');
    print('[Background-Isolate] ⚠️ WARNING: HC20 SDK may not work in isolate!');
    print('[Background-Isolate] ========================================');
    
    // Show informational notification about limitations
    _showErrorNotification(
      'Background Service Started',
      '⚠️ Note: Background HC20 connection may fail due to SDK limitations. AlarmManager will auto-restart app every 15 minutes to maintain connection.',
    );
    
    try {
      // Always send webhooks (even when disconnected) - every 3 minutes
      print('[Background-Isolate] START Step 1: Setting up webhook timer (180s)...');
      _updateNotification('⏳ START Step 1: Creating webhook timer...');
      
      _webhookTimer = Timer.periodic(Duration(seconds: 180), (_) async {
        print('[Background-Isolate] ⏰ Webhook timer FIRED');
        _updateNotification('⏰ Webhook timer triggered - sending...');
        
        // Check if app might be closed (no connection for extended period)
        if (!_isConnected && _reconnectAttempts >= 5) {
          print('[Background-Isolate] 🚀 App may be closed - attempting auto-launch...');
          await _launchFlutterApp();
        }
        
        await _sendWebhook(); // Send webhook regardless of connection status
      });
      
      print('[Background-Isolate] ✅ Webhook timer configured');
      _updateNotification('✅ START Step 1: Webhook timer ACTIVE (every 3min)');
      await Future.delayed(Duration(seconds: 2)); // Let user see this!
      
      // Setup reconnection check (every 30 seconds)
      print('[Background-Isolate] START Step 2: Setting up reconnect timer (30s)...');
      _updateNotification('⏳ START Step 2: Creating reconnect timer...');
      
      _reconnectTimer = Timer.periodic(Duration(seconds: 30), (_) async {
        print('[Background-Isolate] ⏰ Reconnect timer FIRED');
        if (!_isConnected && _deviceId != null) {
          _reconnectAttempts++;
          print('[Background-Isolate] Reconnection attempt #$_reconnectAttempts...');
          _updateNotification('⟳ Auto-reconnect #$_reconnectAttempts...');
          await _connectToDevice();
          
          // Every 5 failed attempts (2.5 minutes), try to launch app
          if (_reconnectAttempts > 0 && _reconnectAttempts % 5 == 0) {
            print('[Background-Isolate] 🚀 5+ failures - AUTO-LAUNCHING APP (attempt $_reconnectAttempts)');
            await _launchFlutterApp();
          }
        } else if (_isConnected) {
          // Reset counter when connected
          if (_reconnectAttempts > 0) {
            print('[Background-Isolate] ✅ Connected - resetting reconnect counter');
            _reconnectAttempts = 0;
          }
        }
      });
      
      print('[Background-Isolate] ✅ Reconnect timer configured');
      _updateNotification('✅ START Step 2: Reconnect timer ACTIVE (every 30s)');
      await Future.delayed(Duration(seconds: 2)); // Let user see this!
      
      // Initial connection attempt
      print('[Background-Isolate] START Step 3: Initial HC20 connection attempt...');
      _updateNotification('⏳ START Step 3: Connecting to HC20...');
      
      await _connectToDevice();
      
      print('[Background-Isolate] ========================================');
      print('[Background-Isolate] ✅ WORKER STARTED SUCCESSFULLY');
      print('[Background-Isolate] ✅ Webhooks will fire every 3 minutes');
      print('[Background-Isolate] ✅ Reconnect checks every 30 seconds');
      print('[Background-Isolate] ========================================');
      _updateNotification('✅ RUNNING: Webhooks(3min) + Reconnect(30s) active');
      
    } catch (e, stackTrace) {
      print('[Background-Isolate] ❌❌❌ START ERROR ❌❌❌');
      print('[Background-Isolate] Error: $e');
      print('[Background-Isolate] Stack: $stackTrace');
      final errorMsg = e.toString();
      _updateNotification('❌ START FAILED: ${errorMsg.length > 60 ? errorMsg.substring(0, 60) + "..." : errorMsg}');
      rethrow;
    }
  }

  Future<void> _connectToDevice() async {
    print('[Background-Isolate] ========================================');
    print('[Background-Isolate] 🔌 _connectToDevice() CALLED');
    print('[Background-Isolate] ========================================');
    
    if (_deviceId == null || _deviceId!.isEmpty) {
      print('[Background-Isolate] ❌ No device ID configured');
      _updateNotification('⚠️ No device configured - tap to open app');
      _showErrorNotification(
        'Configuration Required',
        'No HC20 device selected. Please open the app and select a device.',
      );
      _lastError = 'No device ID configured';
      return;
    }

    try {
      print('[Background-Isolate] Step 1/5: Initializing HC20 Client...');
      _updateNotification('🔧 Step 1/5: Initializing HC20 SDK...');
      _lastError = null;
      
      print('[Background-Isolate] ⚠️ CRITICAL: About to call Hc20Client.create()');
      print('[Background-Isolate] ⚠️ This may FAIL in background isolate context!');
      _updateNotification('⚠️ CRITICAL: Calling Hc20Client.create()...');
      
      // Initialize HC20 client with OAuth credentials
      // THIS IS THE LIKELY FAILURE POINT - HC20 SDK may not work in isolate!
      _hc20Client = await Hc20Client.create(
        config: Hc20Config(
          clientId: '0f3a3a9d342cd0b17859',
          clientSecret: 'ac8c34f2c30466954c4da4c995885107fabc33d8',
        ),
      ).timeout(Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('HC20Client.create() timed out after 10 seconds');
      });
      
      print('[Background-Isolate] ✅✅✅ HC20 Client initialized successfully!');
      _updateNotification('✅ GOOD: HC20Client created! Now scanning...');
      await Future.delayed(Duration(seconds: 1));
      
      print('[Background-Isolate] Step 2/5: Scanning for device: $_deviceId');
      _updateNotification('🔍 Step 2/5: scan() for $_deviceName...');
      
      // Scan for the specific device
      bool deviceFound = false;
      int devicesScanned = 0;
      
      print('[Background-Isolate] ⚠️ About to call _hc20Client.scan()');
      final scanStream = _hc20Client!.scan();
      
      await for (final device in scanStream.timeout(Duration(seconds: 30))) {
        devicesScanned++;
        print('[Background-Isolate] Found device #$devicesScanned: ${device.id} (${device.name})');
        _updateNotification('🔍 Step 2/5: Found $devicesScanned devices...');
        
        if (device.id == _deviceId) {
          print('[Background-Isolate] ✅ Target device found!');
          print('[Background-Isolate] Step 3/5: Connecting to device...');
          deviceFound = true;
          _connectedDevice = device;
          _updateNotification('🔌 Step 3/5: Connecting to $_deviceName...');
          
          // Setup connection state listener
          _connectionSubscription = _hc20Client!.connectionState.listen((update) {
            print('[Background-Isolate] Connection state: ${update.state}');
            _isConnected = update.state == Hc20ConnectionState.connected;
            
            if (_isConnected) {
              _updateNotification('✅ Connected to $_deviceName');
              _lastError = null;
            } else {
              _updateNotification('⚠️ Disconnected - will retry');
              _lastError = 'Connection lost';
            }
          });

          // Connect to device
          print('[Background-Isolate] ⚠️ About to call _hc20Client.connect()');
          await _hc20Client!.connect(device);
          print('[Background-Isolate] ✅ Connected!');
          print('[Background-Isolate] Step 4/5: Starting data stream...');
          _updateNotification('📊 Step 4/5: Starting data stream...');
          
          // Start real-time data stream
          print('[Background-Isolate] ⚠️ About to call _hc20Client.realtimeV2()');
          _realtimeSubscription = _hc20Client!.realtimeV2(device).listen(
            (data) {
              print('[Background-Isolate] ✅ LIVE DATA: HR=${data.heart}, SPO2=${data.spo2}');
              
              _latestData = {
                'heart_rate': data.heart,
                'spo2': data.spo2,
                'blood_pressure': data.bp != null && data.bp!.length >= 2 
                    ? '${data.bp![0]}/${data.bp![1]}' 
                    : 'N/A',
                'rri': data.rri,
                'temperature': data.temperature?.isNotEmpty == true 
                    ? data.temperature![0] 
                    : null,
                'timestamp': DateTime.now().toIso8601String(),
                'data_age_seconds': 0,
              };
              
              _isConnected = true;
              _lastError = null;
              _updateNotification('✅ LIVE: HR=${data.heart}, SpO2=${data.spo2}%');
            },
            onError: (error) {
              print('[Background-Isolate] ❌ Stream error: $error');
              _lastError = 'Stream error: $error';
              _updateNotification('❌ Stream error - will retry');
              _isConnected = false;
            },
          );
          
          _updateNotification('✅ Step 5/5: Connected to $_deviceName');
          print('[Background-Isolate] ========================================');
          print('[Background-Isolate] ✅✅✅ ALL CONNECTION STEPS COMPLETED');
          print('[Background-Isolate] ========================================');
          break;
        }
      }
      
      if (!deviceFound) {
        print('[Background-Isolate] ⚠️ Device not found after scanning $devicesScanned devices');
        _lastError = 'Device $_deviceName not found in scan';
        if (devicesScanned == 0) {
          _updateNotification('❌ NO DEVICES FOUND - Check: BT on? Device on? In range?');
          _showErrorNotification(
            'No Devices Found',
            'Could not find any HC20 devices. Make sure Bluetooth is on and device is powered on nearby.',
          );
        } else {
          _updateNotification('❌ $_deviceName NOT FOUND - Scanned $devicesScanned devices');
          _showErrorNotification(
            'Device Not Found',
            'Could not find $_deviceName. Found $devicesScanned other devices. Make sure device is powered on.',
          );
        }
        _isConnected = false;
      }
      
    } on TimeoutException catch (e) {
      print('[Background-Isolate] ❌ TIMEOUT: $e');
      _lastError = 'Timeout: $e';
      if (e.message?.contains('create') ?? false) {
        _updateNotification('❌ TIMEOUT at Hc20Client.create() - SDK incompatible!');
        _showErrorNotification(
          'HC20 SDK Incompatible',
          'HC20 SDK cannot work in background isolate. The app needs to stay open for HC20 connection. Auto-restart enabled every 15 minutes.',
        );
      } else {
        _updateNotification('⏱️ TIMEOUT: ${e.message ?? "Unknown"} - Retry in 30s');
      }
    } catch (e, stackTrace) {
      final errorMsg = e.toString();
      print('[Background-Isolate] ❌❌❌ CONNECTION ERROR ❌❌❌');
      print('[Background-Isolate] Error: $errorMsg');
      print('[Background-Isolate] Stack trace: $stackTrace');
      _lastError = errorMsg;
      
      if (errorMsg.contains('TimeoutException')) {
        _updateNotification('⏱️ Scan timeout - will retry in 30s');
      } else if (errorMsg.contains('Bluetooth')) {
        _updateNotification('⚠️ Bluetooth issue - turn on BT & tap to open app');
      } else if (errorMsg.contains('MissingPluginException')) {
        _updateNotification('❌ PLUGIN MISSING - HC20 SDK cannot work in isolate!');
        _showErrorNotification(
          'Background Service Failed',
          'HC20 SDK requires Flutter engine context. Background isolate incompatible. App will auto-restart every 15 minutes to maintain connection.',
        );
      } else if (errorMsg.contains('PlatformException')) {
        _updateNotification('❌ PLATFORM ERROR - BLE unavailable in isolate');
        _showErrorNotification(
          'BLE Not Available',
          'Bluetooth plugins don\'t work in background isolate. App must stay open for HC20 connection.',
        );
      } else if (errorMsg.contains('StateError')) {
        _updateNotification('❌ STATE ERROR - Isolate context invalid');
        _showErrorNotification(
          'Isolate Error',
          'Background isolate cannot access platform services. App needs to run in foreground.',
        );
      } else {
        final shortMsg = errorMsg.length > 50 ? errorMsg.substring(0, 50) + "..." : errorMsg;
        _updateNotification('❌ ERROR: $shortMsg');
      }
      
      _isConnected = false;
    }
  }

  Future<void> _disconnect() async {
    try {
      await _realtimeSubscription?.cancel();
      await _connectionSubscription?.cancel();
      if (_hc20Client != null && _connectedDevice != null) {
        await _hc20Client!.disconnect(_connectedDevice!);
      }
      _hc20Client = null;
      _connectedDevice = null;
      _isConnected = false;
      print('[Background-Isolate] Disconnected');
    } catch (e) {
      print('[Background-Isolate] Disconnect error: $e');
    }
  }

  Future<void> _sendWebhook() async {
    if (_webhookUrl == null) {
      print('[Background-Isolate] ⚠️ Webhook skipped - URL not configured');
      _updateNotification('⚠️ Webhook URL not set - tap to open app');
      return;
    }

    try {
      final now = DateTime.now();
      final dataTimestamp = _latestData?['timestamp'] as String?;
      final dataAge = dataTimestamp != null 
          ? now.difference(DateTime.parse(dataTimestamp)).inSeconds 
          : 999;
      
      _webhooksSent++;
      
      print('[Background-Isolate] 📤 Sending webhook #$_webhooksSent (3-min interval)');
      print('[Background-Isolate]    Connection: ${_isConnected ? "CONNECTED" : "DISCONNECTED"}');
      print('[Background-Isolate]    Has data: ${_latestData != null}');
      print('[Background-Isolate]    Data age: ${dataAge}s');
      print('[Background-Isolate]    Last error: $_lastError');
      
      final response = await http.post(
        Uri.parse(_webhookUrl!),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': _deviceId,
          'device_name': _deviceName,
          'user_phone': _userPhone ?? 'unknown',
          'data': _latestData ?? {'note': 'No data received yet'},
          'source': 'BACKGROUND_ISOLATE',
          'method': 'flutter_background_service_INDEPENDENT',
          'interval': '3_minutes',
          
          // STATUS FLAGS - Always included
          'status': {
            'is_connected': _isConnected,
            'has_realtime_data': _latestData != null,
            'last_error': _lastError,
            'reconnect_attempts': _reconnectAttempts,
            'webhooks_sent': _webhooksSent,
            'service_status': _isConnected ? 'OPERATIONAL' : 'DISCONNECTED',
          },
          
          'data_freshness': {
            'age_seconds': dataAge,
            'is_fresh': dataAge < 30,
            'last_update': dataTimestamp,
            'has_data': _latestData != null,
          },
          
          'sent_at': now.toIso8601String(),
          'note': _isConnected 
              ? 'Background service operational with live data' 
              : 'Background service running but device disconnected: $_lastError',
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('[Background-Isolate] ✅ Webhook #$_webhooksSent sent successfully');
        _updateNotification('✅ Webhook #$_webhooksSent sent | ${_isConnected ? "Connected" : "Disconnected"}');
      } else {
        print('[Background-Isolate] ❌ Webhook failed: ${response.statusCode}');
        _updateNotification('❌ Webhook failed: ${response.statusCode}');
        _showErrorNotification(
          'Webhook Failed',
          'Server returned ${response.statusCode}. Data not sent.',
        );
      }
    } catch (e) {
      final errorShort = e.toString().length > 60 ? e.toString().substring(0, 60) + '...' : e.toString();
      print('[Background-Isolate] ❌ Webhook error: $e');
      _updateNotification('❌ Webhook error - check network');
      _showErrorNotification(
        'Webhook Error',
        'Failed to send data: $errorShort',
      );
    }
  }

  /// Show a separate error notification (not the foreground service notification)
  /// This creates a dismissible notification that user can tap
  void _showErrorNotification(String title, String message) {
    try {
      // Create a high-priority notification for errors
      final FlutterLocalNotificationsPlugin notificationsPlugin = 
          FlutterLocalNotificationsPlugin();
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'hfc_errors',
        'HFC Errors',
        channelDescription: 'Error notifications from HFC background service',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      
      const NotificationDetails details = NotificationDetails(android: androidDetails);
      
      // Use timestamp as notification ID to avoid overwriting previous errors
      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      notificationsPlugin.show(
        notificationId,
        title,
        message,
        details,
      );
      
      print('[Background-Isolate] 📱 Error notification shown: $title');
    } catch (e) {
      print('[Background-Isolate] ⚠️ Failed to show error notification: $e');
    }
  }
  
  void _updateNotification(String content) {
    if (service is AndroidServiceInstance) {
      (service as AndroidServiceInstance).setForegroundNotificationInfo(
        title: 'HFC Background (INDEPENDENT)',
        content: content,
      );
    }
  }
  
  /// Request to open/restart the main app
  /// This helps if user accidentally closed the app
  void _requestOpenApp() {
    try {
      service.invoke('openApp');
      print('[Background-Isolate] Requested to open main app');
    } catch (e) {
      print('[Background-Isolate] Failed to request app open: $e');
    }
  }

  Future<void> dispose() async {
    _webhookTimer?.cancel();
    _reconnectTimer?.cancel();
    await _disconnect();
  }
  
  /// Launch the Flutter app (bring to foreground or restart if closed)
  /// Uses native Android AppLauncher via MethodChannel
  Future<void> _launchFlutterApp() async {
    try {
      print('[Background-Isolate] 🚀 Attempting to LAUNCH Flutter app...');
      _updateNotification('🚀 LAUNCHING APP...');
      
      // Method 1: Try MethodChannel to native AppLauncher
      try {
        const MethodChannel channel = MethodChannel('com.example.hfc_app/app_launcher');
        await channel.invokeMethod('launchApp');
        print('[Background-Isolate] ✅ App launch via MethodChannel successful');
        _updateNotification('✅ App launched successfully');
        return;
      } catch (e) {
        print('[Background-Isolate] ❌ MethodChannel launch failed: $e');
      }
      
      // Method 2: Try service invoke (flutter_background_service mechanism)
      try {
        service.invoke('launchApp');
        print('[Background-Isolate] ✅ App launch via service.invoke sent');
        _updateNotification('🚀 App launch requested - waiting...');
        return;
      } catch (e) {
        print('[Background-Isolate] ❌ service.invoke launch failed: $e');
      }
      
      // Fallback: Show high-priority notification for user to tap
      _updateNotification('⚠️ TAP HERE TO OPEN APP & RECONNECT');
      print('[Background-Isolate] ⚠️ Auto-launch failed - showing tap notification');
      
    } catch (e) {
      print('[Background-Isolate] ❌ Failed to launch app: $e');
      _updateNotification('❌ Launch failed - TAP to open manually');
    }
  }
}

