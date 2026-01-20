import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hc20/hc20.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'pages/all_data_page.dart';
import 'pages/test_notification_page.dart';
import 'pages/simple_test_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'services/background_sync_service.dart';
import 'services/app_keepalive_service.dart';
import 'services/main_engine_keepalive_service.dart';
import 'services/background_service_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Main Engine Keep-Alive service (THE KEY for background HC20!)
  await MainEngineKeepAliveService.initialize();
  
  // Check and request SCHEDULE_EXACT_ALARM permission (Android 12+)
  await _checkExactAlarmPermission();
  
  // Initialize AlarmManager for most reliable keepalive (5-min interval)
  await AppKeepaliveService.initialize();
  await AppKeepaliveService.startPeriodicKeepalive();
  print('✅ AlarmManager initialized - app will auto-restart every 5 min if closed');
  
  // Initialize WorkManager for background tasks (15-min interval)
  await BackgroundSyncService.initialize();
  print('✅ WorkManager initialized - secondary keepalive mechanism');
  
  // Test that alarms are actually scheduled
  await _testAlarmScheduling();
  
  // Mark app as active
  await AppKeepaliveService.markAppActive();
  
  // Initialize the AuthService and wait for auth check
  final authService = AuthService();
  await Future.delayed(const Duration(seconds: 1));
  
  runApp(
    ChangeNotifierProvider.value(
      value: authService,
      child: const MyApp(),
    ),
  );
}

/// Check and request SCHEDULE_EXACT_ALARM permission on Android 12+
Future<void> _checkExactAlarmPermission() async {
  if (!Platform.isAndroid) return;
  
  const channel = MethodChannel('com.hfc.app/background');
  try {
    final bool canSchedule = await channel.invokeMethod('checkExactAlarmPermission');
    
    if (!canSchedule) {
      print('⚠️⚠️⚠️ CRITICAL: SCHEDULE_EXACT_ALARM permission NOT granted!');
      print('   Alarms will NOT work without this permission on Android 12+');
      print('   Requesting permission from user...');
      
      // Request permission (opens Settings)
      await channel.invokeMethod('requestExactAlarmPermission');
      
      // Wait a bit and check again
      await Future.delayed(const Duration(seconds: 2));
      final bool recheckCanSchedule = await channel.invokeMethod('checkExactAlarmPermission');
      
      if (recheckCanSchedule) {
        print('✅ SCHEDULE_EXACT_ALARM permission granted!');
      } else {
        print('⚠️ SCHEDULE_EXACT_ALARM permission still not granted');
        print('   Please enable "Alarms & reminders" in app settings');
      }
    } else {
      print('✅ SCHEDULE_EXACT_ALARM permission already granted');
    }
  } catch (e) {
    print('⚠️ Failed to check exact alarm permission: $e');
  }
}

/// Test that alarms are actually scheduled
Future<void> _testAlarmScheduling() async {
  if (!Platform.isAndroid) return;
  
  const channel = MethodChannel('com.hfc.app/background');
  try {
    final Map<dynamic, dynamic> result = await channel.invokeMethod('testAlarmScheduling');
    
    print('🧪 Alarm Scheduling Test:');
    print('   Keepalive alarm (5 min): ${result['keepaliveExists'] ? "✅ SCHEDULED" : "❌ NOT FOUND"}');
    print('   WorkManager alarm (8 min): ${result['workExists'] ? "✅ SCHEDULED" : "❌ NOT FOUND"}');
    print('   Can schedule exact alarms: ${result['canScheduleExact'] ? "✅ YES" : "❌ NO"}');
    
    if (!result['keepaliveExists'] || !result['workExists']) {
      print('⚠️⚠️⚠️ WARNING: Some alarms are not scheduled!');
      print('   This means auto-restart will NOT work when app is closed');
    }
    
    if (result['canScheduleExact'] == false) {
      print('⚠️⚠️⚠️ WARNING: Cannot schedule exact alarms!');
      print('   Please grant "Alarms & reminders" permission in app settings');
    }
  } catch (e) {
    print('⚠️ Failed to test alarm scheduling: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HFC App - HC20 Integration',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Use Consumer to listen to auth state changes
      home: Consumer<AuthService>(
        builder: (context, authService, child) {
          // Show login page if not authenticated
          if (!authService.isAuthenticated) {
            return const LoginPage();
          }
          // Show HC20 home page if authenticated
          return const HC20HomePage(title: 'HFC App - HC20 Wearable');
        },
      ),
    );
  }
}

class HC20HomePage extends StatefulWidget {
  const HC20HomePage({super.key, required this.title});

  final String title;

  @override
  State<HC20HomePage> createState() => _HC20HomePageState();
}

// Connection state enum for better UI representation
enum ConnectionState { disconnected, connecting, connected, reconnecting, error }

// Connection event for history tracking
class ConnectionEvent {
  final DateTime timestamp;
  final String event; // 'connected', 'disconnected', 'reconnected'
  final String? reason;
  final String? deviceId;
  
  ConnectionEvent({
    required this.timestamp,
    required this.event,
    this.reason,
    this.deviceId,
  });
  
  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _HC20HomePageState extends State<HC20HomePage> with WidgetsBindingObserver {
  Hc20Client? _client;
  Hc20Device? _connectedDevice;
  bool _isScanning = false;
  bool _isConnected = false;
  ConnectionState _connectionState = ConnectionState.disconnected;
  List<Hc20Device> _discoveredDevices = [];
  String _statusMessage = 'Click "Start Scanning" to search for HC20 devices';
  
  // Bluetooth and Internet status
  bool _isBluetoothOn = true;
  bool _isInternetConnected = true;
  StreamSubscription? _bluetoothStateSubscription;
  
  // Webhook configuration
  late final Dio _dio;
  static const String _webhookUrl = 'https://api.hireforcare.com/webhook/hc20-data';
  int _webhookSuccessCount = 0;
  int _webhookErrorCount = 0;
  
  // Time sync info
  String _lastTimeSyncStatus = 'Not synced yet';
  DateTime? _lastTimeSyncTime;
  String _lastWebhookStatus = '';
  String _lastWebhookError = '';
  DateTime? _lastWebhookTime;
  
  // Real-time data
  int? _heartRate;
  int? _spo2;
  List<int>? _bloodPressure;
  double? _temperature;
  int? _batteryLevel;
  int? _steps;
  bool _stressAlertPending = false;  // Flag to send stress alert on next data
  StreamSubscription? _realtimeSubscription;
  Timer? _dataRefreshTimer;
  Timer? _connectionMonitor;
  Timer? _hrvRefreshTimer;  // Timer for 6-hour HRV refresh
  Timer? _hrv2RefreshTimer;  // Timer for 6-hour HRV2 refresh
  Timer? _rriRefreshTimer;  // Timer for 6-hour RRI refresh
  Timer? _temperatureRefreshTimer;  // Timer for 6-hour Temperature refresh
  Timer? _autoReconnectScanner;  // Timer for auto-reconnect scanning
  DateTime? _lastDataReceived;
  
  // Auto-reconnect state
  String? _savedDeviceId;  // Saved device ID for auto-reconnect
  bool _isAutoReconnecting = false;
  int _consecutiveFailedScans = 0;  // Track consecutive failed scans for device not found notification
  DateTime? _lastHrvRefresh;  // Track last HRV refresh time
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  bool _isBatteryOptimizationDisabled = false; // Track battery optimization status
  
  // API service for device association
  final ApiService _apiService = ApiService();
  bool _isDeviceAssociated = false;
  
  // Connection history and analytics
  List<ConnectionEvent> _connectionHistory = [];
  int _totalDisconnects = 0;
  int _totalReconnects = 0;
  DateTime? _lastDisconnectTime;
  Duration? _longestDisconnectDuration;
  Map<String, int> _disconnectReasons = {};
  bool _showConnectionHistory = false;
  
  // Low battery warning
  bool _isLowBattery = false;
  bool _lowBatteryAlertSent = false;
  
  // Internet monitoring timer
  Timer? _internetMonitorTimer;
  
  // Local notifications
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;
  // Feature-flag to control plugin-based background service (disabled on MIUI)
  final bool _bgPluginEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeDio();
    _initializeNotifications();
    if (_bgPluginEnabled) {
      BackgroundServiceManager.instance.initialize();
    }
    _enableBackgroundExecution();
    _checkAndShowBatteryOptimizationDialog();
    _checkBluetoothAndInternetStatus();
    _startBluetoothAndInternetMonitoring();
    _loadSavedDevice();
    // Note: HC20 client will be initialized when user clicks scan button
  }
  
  // Load saved device ID for auto-reconnect
  Future<void> _loadSavedDevice() async {
    try {
      final deviceId = await StorageService().getSavedDeviceId();
      if (deviceId != null && deviceId.isNotEmpty) {
        setState(() {
          _savedDeviceId = deviceId;
        });
        print('🔄 Auto-reconnect enabled for device: $deviceId');
        print('   Will automatically connect when device is nearby');
        
        // Start auto-reconnect scanner
        _startAutoReconnectScanner();
      } else {
        print('ℹ️  No saved device found - auto-reconnect disabled');
      }
    } catch (e) {
      print('⚠️ Error loading saved device: $e');
    }
  }
  
  // Initialize local notifications
  Future<void> _initializeNotifications() async {
    try {
      // Android initialization settings
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print('📱 Notification tapped: ${response.payload}');
        },
      );
      
      // Request Android 13+ notification permission
      if (Platform.isAndroid) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      
      setState(() {
        _notificationsInitialized = true;
      });
      
      print('✅ Notifications initialized');
    } catch (e) {
      print('⚠️ Error initializing notifications: $e');
    }
  }
  
  // Show device disconnection notification
  Future<void> _showDisconnectNotification(String reason) async {
    if (!_notificationsInitialized) return;
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'device_alerts',
      'Device Alerts',
      channelDescription: 'Notifications for device connection issues',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFF6B6B),
      playSound: true,
      enableVibration: true,
      autoCancel: true,  // Allow tap to dismiss (like internet notification)
      ongoing: false,  // CRITICAL: Allow swipe to dismiss (like internet notification)
      styleInformation: BigTextStyleInformation(''),
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    String title = '⚠️ Device Disconnected';
    String body = '';
    
    if (reason.contains('Bluetooth')) {
      title = '📱 Bluetooth Issue';
      body = 'Please turn on Bluetooth to reconnect your HC20 device';
    } else if (reason.contains('Out of range') || reason.contains('out of range')) {
      title = '📍 Device Out of Range';
      body = 'Move closer to your HC20 device to restore connection';
    } else if (reason.contains('powered off') || reason.contains('Device powered off')) {
      title = '🔋 Device Powered Off';
      body = 'Please turn on your HC20 device to continue monitoring';
    } else if (reason.contains('Max reconnection')) {
      title = '🔄 Connection Failed';
      body = 'Unable to reconnect automatically. Please reconnect manually.';
    } else {
      body = 'Your HC20 device has been disconnected. Tap to reconnect.';
    }
    
    await _notificationsPlugin.show(
      1,
      title,
      body,
      notificationDetails,
      payload: 'disconnect:$reason',
    );
    
    print('📬 Disconnect notification shown: $title - $body');
  }
  
  // Show network/internet issue notification
  Future<void> _showNetworkIssueNotification() async {
    if (!_notificationsInitialized) return;
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'network_alerts',
      'Network Alerts',
      channelDescription: 'Notifications for internet connection issues',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFFA500),
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notificationsPlugin.show(
      2,
      '🌐 No Internet Connection',
      'Unable to monitor your health data. Please check your WiFi or mobile data connection.',
      notificationDetails,
      payload: 'network_issue',
    );
    
    print('📬 Network issue notification shown');
  }
  
  // Show low battery notification when device battery is below 20%
  Future<void> _showLowBatteryNotification(int batteryLevel) async {
    if (!_notificationsInitialized) return;
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'battery_alerts',
      'Battery Alerts',
      channelDescription: 'Notifications for low device battery',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFF6B6B),
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notificationsPlugin.show(
      4, // Unique ID for low battery notification
      '🔋 Low Battery Warning',
      'HC20 device battery is at $batteryLevel%. Please charge your device soon.',
      notificationDetails,
      payload: 'low_battery:$batteryLevel',
    );
    
    print('📬 Low battery notification shown: $batteryLevel%');
  }
  
  // Show device not found notification (after Bluetooth scan)
  Future<void> _showDeviceNotFoundNotification() async {
    print('📬 _showDeviceNotFoundNotification called');
    print('   _notificationsInitialized: $_notificationsInitialized');
    
    if (!_notificationsInitialized) {
      print('⚠️ Notifications not initialized yet, cannot show device not found notification');
      return;
    }
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'device_alerts',
      'Device Alerts',
      channelDescription: 'Notifications for device connection issues',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFFA500),
      playSound: true,
      enableVibration: true,
      autoCancel: true,  // Allow swipe to dismiss
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notificationsPlugin.show(
      5, // Unique ID for device not found notification
      '📡 Device Not Found',
      'HC20 device not found nearby. Make sure the device is powered on and within range.',
      notificationDetails,
      payload: 'device_not_found',
    );
    
    print('📬 Device not found notification shown');
  }
  
  // Show internet restored notification
  Future<void> _showInternetRestoredNotification() async {
    print('📬 _showInternetRestoredNotification called');
    print('   _notificationsInitialized: $_notificationsInitialized');
    
    if (!_notificationsInitialized) {
      print('⚠️ Notifications not initialized yet, cannot show internet restored notification');
      return;
    }
    
    // Cancel the network issue notification first
    print('   Cancelling network issue notification (ID 2)...');
    await _notificationsPlugin.cancel(2);
    print('   Network issue notification cancelled');
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'network_alerts',
      'Network Alerts',
      channelDescription: 'Notifications for internet connection status',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4CAF50),
      playSound: false,
      enableVibration: false,
      autoCancel: true,  // Allow swipe to dismiss
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notificationsPlugin.show(
      6, // Unique ID for internet restored notification
      '✅ Internet Restored',
      'Internet connection is back. Data sync will resume.',
      notificationDetails,
      payload: 'internet_restored',
    );
    
    print('📬 Internet restored notification shown');
  }
  
  // Show connection restored notification
  Future<void> _showConnectionRestoredNotification() async {
    print('📬 _showConnectionRestoredNotification called');
    print('   _notificationsInitialized: $_notificationsInitialized');
    
    if (!_notificationsInitialized) {
      print('⚠️ Notifications not initialized yet, cannot show connection restored notification');
      return;
    }
    
    // Cancel disconnect notifications first
    print('   Cancelling disconnect notifications (ID 1, 5)...');
    await _notificationsPlugin.cancel(1);  // Cancel disconnect notification
    await _notificationsPlugin.cancel(5);  // Cancel device not found notification
    print('   Disconnect notifications cancelled');
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'device_alerts',
      'Device Alerts',
      channelDescription: 'Notifications for device connection issues',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4CAF50),
      playSound: false,
      enableVibration: false,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notificationsPlugin.show(
      3,
      '✅ Device Connected',
      'Your HC20 device is now connected and monitoring',
      notificationDetails,
      payload: 'connected',
    );
    
    print('📬 Connection restored notification shown');
  }
  
  // Cancel all notifications
  Future<void> _cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
  
  // Keep app alive in background using platform channel
  Future<void> _enableBackgroundExecution() async {
    try {
      const platform = MethodChannel('com.hfc.app/background');
      await platform.invokeMethod('enableBackgroundExecution');
      print('✅ Background execution enabled');
    } catch (e) {
      print('⚠️ Could not enable background execution: $e');
    }
  }
  
  // Check and show battery optimization permission dialog
  Future<void> _checkAndShowBatteryOptimizationDialog() async {
    try {
      const platform = MethodChannel('com.hfc.app/background');
      
      // Check if already disabled
      final isDisabled = await platform.invokeMethod('isBatteryOptimizationDisabled');
      
      setState(() {
        _isBatteryOptimizationDisabled = isDisabled;
      });
      
      if (isDisabled) {
        print('✅ Battery optimization already disabled');
        setState(() {
          _statusMessage = '✅ Ready to scan for devices';
        });
      } else {
        print('⚠️ Battery optimization is enabled - showing permission dialog...');
        setState(() {
          _statusMessage = '⚠️ Battery optimization permission required';
        });
        
        // Show custom permission dialog
        Future.delayed(Duration(milliseconds: 500), () {
          _showBatteryOptimizationPermissionDialog();
        });
      }
    } catch (e) {
      print('⚠️ Could not check battery optimization: $e');
    }
  }
  
  // Show custom permission dialog
  void _showBatteryOptimizationPermissionDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.battery_alert, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Allow Battery Optimization',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This app needs unrestricted battery access to work properly in background.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'What happens next:',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Tap "Allow" button below\n2. Find "HFC App" in the list\n3. Select "No Restriction" or "Allow"',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade900, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _requestBatteryOptimizationExemption();
                },
                icon: Icon(Icons.battery_charging_full, size: 24),
                label: Text('Allow Battery Access', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // Request exemption from battery optimization
  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      const platform = MethodChannel('com.hfc.app/background');
      
      print('🔋 Opening battery optimization settings...');
      await platform.invokeMethod('requestBatteryOptimizationExemption');
      
      setState(() {
        _statusMessage = 'Please disable battery optimization for this app';
      });
      
      // Check again after 3 seconds to see if user made changes
      await Future.delayed(Duration(seconds: 3));
      await _checkBatteryOptimizationStatus();
    } catch (e) {
      print('⚠️ Could not request battery optimization exemption: $e');
    }
  }
  
  // Check battery optimization status
  Future<void> _checkBatteryOptimizationStatus() async {
    try {
      const platform = MethodChannel('com.hfc.app/background');
      final isDisabled = await platform.invokeMethod('isBatteryOptimizationDisabled');
      
      setState(() {
        _isBatteryOptimizationDisabled = isDisabled;
        if (isDisabled) {
          _statusMessage = '✅ Ready to scan for devices';
        } else {
          _statusMessage = '⚠️ Battery optimization must be disabled. Tap "Disable Battery Optimization" button.';
        }
      });
      
      print(_isBatteryOptimizationDisabled ? '✅ Battery optimization disabled' : '⚠️ Battery optimization still enabled');
    } catch (e) {
      print('⚠️ Could not check battery optimization status: $e');
    }
  }
  
  // Check Bluetooth and Internet status
  Future<void> _checkBluetoothAndInternetStatus() async {
    try {
      // Check Bluetooth status using permission_handler
      final bluetoothStatus = await Permission.bluetooth.serviceStatus;
      final isBluetoothEnabled = bluetoothStatus.isEnabled;
      
      // Check Internet connectivity with multiple endpoints for reliability
      bool hasInternet = await _checkInternetConnectivity();
      
      // Track previous states to detect changes
      final wasBluetoothOn = _isBluetoothOn;
      final wasInternetConnected = _isInternetConnected;
      
      setState(() {
        _isBluetoothOn = isBluetoothEnabled;
        _isInternetConnected = hasInternet;
      });
      
      print('📱 Bluetooth: ${_isBluetoothOn ? "ON" : "OFF"} | Internet: ${_isInternetConnected ? "Connected" : "Disconnected"}');
      
      // Show notification when internet goes down
      if (wasInternetConnected && !_isInternetConnected) {
        print('🔴 Internet disconnected - showing notification');
        _showNetworkIssueNotification();
      }
      
      // If Bluetooth is off and device is connected, handle disconnection
      if (!_isBluetoothOn && _isConnected) {
        print('❌ Bluetooth turned OFF while connected - handling disconnection');
        _showDisconnectNotification('Bluetooth Disconnect');
        setState(() {
          _isConnected = false;
          _connectionState = ConnectionState.error;
          _statusMessage = 'Bluetooth turned off';
        });
        _handleDisconnection();
      }
    } catch (e) {
      print('⚠️ Error checking Bluetooth/Internet status: $e');
    }
  }
  
  // Start continuous Bluetooth and Internet monitoring
  void _startBluetoothAndInternetMonitoring() {
    // Cancel existing timer if any
    _internetMonitorTimer?.cancel();
    
    // Check every 15 seconds and store the timer
    _internetMonitorTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkBluetoothAndInternetStatus();
      // Also mark app as active for keepalive services
      AppKeepaliveService.markAppActive();
    });
    
    // Also check immediately
    _checkBluetoothAndInternetStatus();
    AppKeepaliveService.markAppActive();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeSubscription?.cancel();
    _dataRefreshTimer?.cancel();
    _connectionMonitor?.cancel();
    _hrvRefreshTimer?.cancel();
    _hrv2RefreshTimer?.cancel();
    _rriRefreshTimer?.cancel();
    _temperatureRefreshTimer?.cancel();
    _internetMonitorTimer?.cancel();
    _autoReconnectScanner?.cancel();
    _bluetoothStateSubscription?.cancel();
    _disableBackgroundExecution();
    super.dispose();
  }
  
  Future<void> _disableBackgroundExecution() async {
    try {
      const platform = MethodChannel('com.hfc.app/background');
      await platform.invokeMethod('disableBackgroundExecution');
      print('✅ Background execution disabled');
    } catch (e) {
      print('⚠️ Could not disable background execution: $e');
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('📱 App lifecycle state changed: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        print('✅ App resumed - foreground mode');
        
        // Stop keep-alive mode when app comes to foreground
        _stopMainEngineKeepAlive();
        
        // Recheck battery optimization status when app resumes
        _checkBatteryOptimizationStatus();
        
        // Show dialog again if still not disabled
        Future.delayed(Duration(seconds: 1), () {
          if (!_isBatteryOptimizationDisabled && mounted) {
            _showBatteryOptimizationPermissionDialog();
          }
        });
        break;
        
      case AppLifecycleState.paused:
        print('⏸️ App paused - entering background mode');
        
        // Start keep-alive mode to keep HC20 connection alive!
        _startMainEngineKeepAlive();
        break;
        
      case AppLifecycleState.inactive:
        print('💤 App inactive');
        break;
        
      case AppLifecycleState.detached:
        print('🔌 App detached - but ForegroundService keeps us alive!');
        // Note: In main engine mode, the app process stays alive
        // because ForegroundService prevents Android from killing it
        break;
        
      case AppLifecycleState.hidden:
        print('🙈 App hidden');
        // Also start keep-alive when hidden (Android 14+ uses this)
        _startMainEngineKeepAlive();
        break;
    }
  }
  
  /// Start main engine keep-alive mode
  /// This keeps the Flutter engine running in background with HC20 connection alive
  Future<void> _startMainEngineKeepAlive() async {
    // Only start keep-alive if connected to a device
    if (!_isConnected || _connectedDevice == null) {
      print('ℹ️ [KeepAlive] Not connected to device - skipping keep-alive');
      return;
    }
    
    print('🚀 [KeepAlive] Starting main engine keep-alive mode...');
    print('   Device: ${_connectedDevice!.id}');
    print('   Current data: HR=$_heartRate, SpO2=$_spo2, Temp=$_temperature');
    
    // Get user phone from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final userPhone = prefs.getString('user_phone');
    
    try {
      final success = await MainEngineKeepAliveService.startKeepAlive(
        deviceId: _connectedDevice!.id,
        userPhone: userPhone,
        currentHeartRate: _heartRate,
        currentSpO2: _spo2,
        currentTemperature: _temperature,
        batteryLevel: _batteryLevel,
      );
      
      if (success) {
        print('✅ [KeepAlive] Main engine keep-alive ACTIVE!');
        print('   HC20 connection will stay alive in background');
        print('   Webhooks will continue sending');
      } else {
        print('⚠️ [KeepAlive] Failed to start keep-alive mode');
      }
    } catch (e) {
      print('❌ [KeepAlive] Error starting keep-alive: $e');
    }
  }
  
  /// Stop main engine keep-alive mode
  Future<void> _stopMainEngineKeepAlive() async {
    if (!MainEngineKeepAliveService.isKeepAliveActive) {
      return; // Already stopped
    }
    
    print('🛑 [KeepAlive] Stopping main engine keep-alive mode...');
    
    try {
      await MainEngineKeepAliveService.stopKeepAlive();
      print('✅ [KeepAlive] Keep-alive stopped - app in foreground');
    } catch (e) {
      print('⚠️ [KeepAlive] Error stopping keep-alive: $e');
    }
  }
  
  void _initializeDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    // Add logging interceptor for debugging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
      logPrint: (obj) => print('🌐 Dio Log: $obj'),
    ));
  }

  Future<void> _initializeHC20Client() async {
    try {
      setState(() {
        _statusMessage = 'Initializing HC20 client...';
      });

      // Request Bluetooth permissions
      await _requestPermissions();

      // Create HC20 client with OAuth credentials
      _client = await Hc20Client.create(
        config: Hc20Config(
          clientId: '0f3a3a9d342cd0b17859',
          clientSecret: 'ac8c34f2c30466954c4da4c995885107fabc33d8',
        ),
      );

      setState(() {
        _statusMessage = 'HC20 client initialized. Ready to scan!';
      });
      
      print('✓ HC20 client initialized successfully');
    } catch (e) {
      print('❌ HC20 client initialization error: $e');
      setState(() {
        _statusMessage = 'Error: Invalid OAuth credentials. Contact dev team for clientId/clientSecret.';
      });
      _client = null;  // Ensure client is null on error
    }
  }

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
        setState(() {
          _statusMessage = 'Permission ${permission.toString()} not granted';
        });
      }
    }
  }

  void _startScanning() async {
    // Check battery optimization first
    if (!_isBatteryOptimizationDisabled) {
      await _checkBatteryOptimizationStatus();
      
      if (!_isBatteryOptimizationDisabled) {
        setState(() {
          _statusMessage = '❌ Cannot scan: Battery optimization must be disabled first!';
        });
        
        // Show dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('⚠️ Battery Optimization Required'),
              content: Text(
                'This app requires unrestricted battery access to maintain continuous Bluetooth connection and data sync in background.\n\n'
                'Please disable battery optimization to continue.'
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _requestBatteryOptimizationExemption();
                  },
                  child: Text('Disable Battery Optimization'),
                ),
              ],
            );
          },
        );
        return;
      }
    }
    
    // Initialize client if not already done
    if (_client == null) {
      await _initializeHC20Client();
      if (_client == null) {
        setState(() {
          _statusMessage = 'Failed to initialize. Check OAuth credentials.';
        });
        return;
      }
    }

    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
      _statusMessage = 'Scanning for HC20 devices...';
    });

    _client!.scan().listen(
      (device) {
        if (!_discoveredDevices.any((d) => d.id == device.id)) {
          setState(() {
            _discoveredDevices.add(device);
            _statusMessage = 'Found ${_discoveredDevices.length} device(s)';
          });
        }
      },
      onError: (error) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Scan error: $error';
        });
      },
    );

    // Auto-stop scanning after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (_isScanning) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Scan completed. Found ${_discoveredDevices.length} device(s)';
        });
      }
    });
  }

  Future<void> _connectToDevice(Hc20Device device) async {
    if (_client == null) return;

    try {
      setState(() {
        _statusMessage = 'Connecting to ${device.name}...';
      });

      print('🔌 Attempting to connect to device: ${device.name}');
      print('⚠️  Note: Connection may fail if OAuth credentials are invalid');
      print('⚠️  HC20 SDK automatically enables raw data upload to cloud on connect');
      
      // Connect to device
      // Note: This automatically starts RawManager and uploads to Nitto cloud
      // Requires valid clientId/clientSecret in Hc20Client.create()
      await _client!.connect(device);
      
      // Read device info
      final info = await _client!.readDeviceInfo(device);
      
      // Sync time with mobile device (required by HC20 SDK)
      setState(() {
        _statusMessage = 'Syncing time with device...';
      });
      
      try {
        final now = DateTime.now();
        // The device expects timezone offset in hours as an integer
        // For timezones with 30-minute offsets (e.g., UTC+5:30), we need to pass it as a decimal
        // But since the API expects int, we'll convert the entire offset to the nearest hour
        // and adjust the timestamp to compensate for the 30-minute difference
        final offsetMinutes = now.timeZoneOffset.inMinutes;
        final offsetHours = offsetMinutes ~/ 60; // Integer hours part
        final remainingMinutes = offsetMinutes % 60; // Remaining minutes (0, 30, or 45)
        
        // Adjust timestamp to compensate for non-hour timezone offsets
        // If timezone is UTC+5:30, we pass timezone=5 but adjust timestamp by +30 minutes
        final adjustedTimestamp = (now.millisecondsSinceEpoch ~/ 1000) + (remainingMinutes * 60);
        
        print('⏰ Syncing time with device...');
        print('   Mobile time: ${now.toIso8601String()}');
        print('   Base timestamp: ${now.millisecondsSinceEpoch ~/ 1000}');
        print('   Adjusted timestamp: $adjustedTimestamp (compensating for $remainingMinutes min offset)');
        print('   Timezone: UTC+${offsetMinutes / 60.0} (sending as $offsetHours hours)');
        
        await _client!.setTime(
          device,
          timestamp: adjustedTimestamp,
          timezone: offsetHours,
        );
        
        print('✓ Time synced successfully');
        
        // Verify time was set correctly
        final deviceTime = await _client!.getTime(device);
        print('✓ Device time verification:');
        print('   Device timestamp: ${deviceTime.timestamp}');
        print('   Device timezone: UTC+${deviceTime.timezone}');
        final timeDiff = (now.millisecondsSinceEpoch ~/ 1000) - deviceTime.timestamp;
        print('   Time difference: ${timeDiff.abs()} seconds');
        
        // Update sync status
        _lastTimeSyncTime = DateTime.now();
        
        if (timeDiff.abs() > 60) {
          print('⚠️  Warning: Time difference is more than 60 seconds!');
          _lastTimeSyncStatus = '⚠️ Synced with ${timeDiff.abs()}s diff';
          setState(() {
            _statusMessage = '⚠️ Time sync issue: ${timeDiff.abs()}s difference!';
          });
          // Wait a bit so user can see the warning
          await Future.delayed(Duration(seconds: 2));
        } else {
          _lastTimeSyncStatus = '✅ Synced (${timeDiff.abs()}s diff)';
          setState(() {
            _statusMessage = 'Time synced! Diff: ${timeDiff.abs()}s';
          });
        }
      } catch (timeError) {
        print('❌ Time sync error: $timeError');
        print('⚠️  Continuing without time sync - device may have incorrect time');
        
        _lastTimeSyncStatus = '❌ Failed: $timeError';
        _lastTimeSyncTime = DateTime.now();
        
        setState(() {
          _statusMessage = '❌ Time sync failed: $timeError';
        });
        
        // Show error for 2 seconds before continuing
        await Future.delayed(Duration(seconds: 2));
        // Continue with connection even if time sync fails
      }

      // Set user parameters
      await _client!.setParameters(device, {
        'user_info': {
          'name': 'HFC User',
          'gender': 1,
          'height': 175,
          'weight': 70,
        },
      });

      setState(() {
        _connectedDevice = device;
        _isConnected = true;
        _connectionState = ConnectionState.connected;
        _statusMessage = 'Connected to ${info.name} v${info.version}';
      });
      
      // Track connection event
      _addConnectionEvent(
        event: _connectionHistory.isEmpty ? 'connected' : 'reconnected',
        deviceId: device.id,
      );
      if (_connectionHistory.length > 1) {
        _totalReconnects++;
      }

      // Associate device with user account
      await _associateDeviceWithUser(device);

      // Start listening to real-time data
      _startRealtimeDataStream(device);
      
      // Start connection monitoring
      _startConnectionMonitoring();
      
      // Start HRV auto-refresh (6 hours)
      _startHrvAutoRefresh();
      
      // Start HRV2 auto-refresh (6 hours)
      _startHrv2AutoRefresh();
      
      // Start RRI auto-refresh (6 hours)
      _startRriAutoRefresh();
      
      // Start Temperature auto-refresh (6 hours)
      _startTemperatureAutoRefresh();

      // Start background keepalive service (flutter_background_service) — disabled
      if (_bgPluginEnabled) {
        try {
          await BackgroundServiceManager.instance.start();
          print('✅ BackgroundServiceManager started');
        } catch (e) {
          print('⚠️ BackgroundServiceManager failed to start: $e');
        }
      }
      
      // Background execution enabled via foreground service + wake lock
      print('✓ Data streaming started - webhooks will continue in background');
      
      // Save device ID for auto-reconnect
      await _saveDeviceForAutoReconnect(device.id);
      
      // Save connection state for background services
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('device_connected', true);
      await prefs.setString('saved_device_id', device.id);
      await prefs.setString('last_connected_device_id', device.id);
      await prefs.setString('last_connected_device_name', device.name);
      
      // Get user phone for background webhooks
      final authService = Provider.of<AuthService>(context, listen: false);
      String? userPhone;
      if (authService.currentUser != null) {
        userPhone = authService.currentUser!.phone;
        await prefs.setString('user_phone', userPhone);
      }
      
      // Start native BLE service for continuous background connection
      print('🚀 Starting native BLE service...');
      try {
        const platform = MethodChannel('com.hfc.app/background');
        await platform.invokeMethod('startNativeBleService', {
          'deviceAddress': device.id,
          'userPhone': userPhone ?? 'unknown',
        });
        print('✅ Native BLE service started - will maintain connection even when app closed');
      } catch (e) {
        print('⚠️ Failed to start native BLE service: $e');
      }
      
      // 🚀🚀🚀 NEW: Start NativeHC20Service (Pure Kotlin BLE) 🚀🚀🚀
      // This is the ONLY approach that works when app is swiped away!
      // NativeHC20Service uses native Kotlin BLE, NOT Flutter, so it continues
      // even when Flutter engine dies.
      print('🚀🚀🚀 Starting NativeHC20Service (Pure Kotlin BLE) for background HC20...');
      try {
        const platform = MethodChannel('com.hfc.app/background');
        await platform.invokeMethod('startNativeHC20Service', {
          'deviceId': device.id,
          'userPhone': userPhone ?? 'unknown',
        });
        print('✅✅✅ NativeHC20Service started - WILL SURVIVE APP SWIPE!');
        print('   This service uses native Kotlin BLE, not Flutter.');
        print('   It will continue sending webhooks even when app is killed.');
      } catch (e) {
        print('⚠️ Failed to start NativeHC20Service: $e');
      }
      
      // Start WorkManager for guaranteed background sync (even when app is killed)
      await BackgroundSyncService.startPeriodicSync();
      print('✅ WorkManager periodic sync started - ensures webhooks continue even if app is closed');
      
      // Reset reconnection counter on successful connection
      _reconnectAttempts = 0;
      _isReconnecting = false;
      
      // Show connection success notification
      _showConnectionRestoredNotification();

    } catch (e) {
      print('❌ Connection error: $e');
      
      String errorMessage;
      if (e.toString().contains('service_discovery_failure') || 
          e.toString().contains('status 8')) {
        // Status 8 = GATT_CONN_TIMEOUT or disconnected during service discovery
        // This often happens when raw data upload fails due to invalid OAuth credentials
        errorMessage = 'Connection failed: Device disconnected during setup.\n\n'
            'Common causes:\n'
            '• Invalid OAuth credentials (clientId/clientSecret)\n'
            '• HC20 SDK requires cloud access on connect\n'
            '• Network connectivity issues\n'
            '• Device out of range\n\n'
            'Contact dev team for valid OAuth credentials.';
      } else if (e.toString().contains('Invalid OAuth') || 
                 e.toString().contains('401') ||
                 e.toString().contains('authentication')) {
        errorMessage = 'Authentication failed: Invalid OAuth credentials.\n\n'
            'The HC20 SDK requires valid clientId and clientSecret\n'
            'for cloud data upload. Contact dev team for credentials.';
      } else {
        errorMessage = 'Connection failed: $e';
      }
      
      setState(() {
        _statusMessage = errorMessage;
      });
    }
  }

  Future<void> _associateDeviceWithUser(Hc20Device device) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user == null) {
        print('⚠️ No user logged in, skipping device association');
        return;
      }
      
      print('🔗 Associating device ${device.id} with user ${user.id}');
      
      setState(() {
        _statusMessage = 'Linking device to your account...';
      });
      
      final response = await _apiService.associateDevice(
        device.id,
        user.id,
        deviceName: device.name,
      );
      
      if (response['success'] == true) {
        print('✅ Device associated successfully!');
        print('   Updated ${response['updatedRecords']} records');
        
        setState(() {
          _isDeviceAssociated = true;
          _statusMessage = 'Device linked! Updated ${response['updatedRecords']} health records';
        });
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Device linked to ${user.name}\'s account'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        print('⚠️ Device association failed: ${response['error']}');
        // Don't show warning in status - user will see it's not linked in UI
        // Avoid overwriting connection success message with warning
        print('⚠️ Device not linked - user can link later');
      }
    } catch (e) {
      print('❌ Error associating device: $e');
      // Don't show warning for network errors - this would confuse users
      // The device is still connected and working, just association failed
      print('⚠️ Device association network error - will retry later');
    }
  }


  void _startRealtimeDataStream(Hc20Device device) {
    // Cancel any existing subscription first (but keep the timer running!)
    _realtimeSubscription?.cancel();
    
    // Cancel existing timer before creating new one to avoid duplicates
    if (_dataRefreshTimer != null) {
      print('⚠️ Cancelling existing webhook timer before creating new one');
      _dataRefreshTimer?.cancel();
    }
    
    print('\n🚀 ========================================');
    print('🚀 Starting real-time data stream for device: ${device.name}');
    print('🚀 Device ID: ${device.id}');
    print('🚀 Webhook URL: $_webhookUrl');
    print('🚀 Data refresh: Every 120 seconds (2 minutes) - TESTING MODE');
    print('🚀 ========================================\n');
    
    // Subscribe and KEEP the subscription reference
    _realtimeSubscription = _client!.realtimeV2(device).listen(
      (data) async {
        final timestamp = DateTime.now().toIso8601String();
        _lastDataReceived = DateTime.now(); // Update last data timestamp
        
        print('\n📊 [$timestamp] Received real-time data:');
        print('   Heart: ${data.heart}, SpO2: ${data.spo2}, BP: ${data.bp}');
        print('   Temp: ${data.temperature}, Battery: ${data.battery?.percent}%');
        print('   Steps: ${data.basicData?[0] ?? "N/A"}');
        
        setState(() {
          if (data.heart != null) _heartRate = data.heart;
          if (data.spo2 != null) _spo2 = data.spo2;
          if (data.bp != null) _bloodPressure = data.bp;
          if (data.temperature != null && data.temperature!.isNotEmpty) {
            _temperature = data.temperature![0] / 100.0;
          }
          if (data.battery != null) {
            _batteryLevel = data.battery!.percent;
            
            // Check for low battery warning (20% threshold)
            if (_batteryLevel! <= 20 && !_isLowBattery) {
              _isLowBattery = true;
              _lowBatteryAlertSent = false;
              print('⚠️ LOW DEVICE BATTERY DETECTED: ${_batteryLevel}%');
              // Show low battery notification on mobile
              _showLowBatteryNotification(_batteryLevel!);
            } else if (_batteryLevel! > 20 && _isLowBattery) {
              _isLowBattery = false;
              _lowBatteryAlertSent = false;
            }
          }
          
          if (data.basicData != null && data.basicData!.isNotEmpty) {
            _steps = data.basicData![0];
          }
        });
        
        // NOTE: No caching needed - Native BLE service sends live data
        // WorkManager is disabled for data sending
        
        // Check if stress alert is pending
        if (_stressAlertPending) {
          print('🚨 Stress alert flag detected - sending STRESS webhook with fresh data');
          _stressAlertPending = false;
          _sendDataToWebhook(device, data, isStressAlert: true);
          setState(() {
            _statusMessage = 'Stress alert sent with fresh data!';
          });
        } else if (_isLowBattery && !_lowBatteryAlertSent) {
          // Send low battery alert for device
          print('🔋 Low device battery detected - sending LOW BATTERY webhook');
          _lowBatteryAlertSent = true;
          _sendDataToWebhook(device, data, isLowBattery: true);
          setState(() {
            _statusMessage = 'Low battery alert sent! Device: $_batteryLevel%';
          });
        } else if (!_isLowBattery && _lowBatteryAlertSent) {
          // Reset flag when battery is OK
          _lowBatteryAlertSent = false;
        } else {
          // Send regular webhook (non-blocking)
          print('📤 Sending regular webhook at $_webhookUrl...');
          _sendDataToWebhook(device, data);
        }
        
        // Update native service with live data for background sync
        _updateNativeServiceData(device, data);
        
        // Update keep-alive notification with latest health data
        // This ensures the notification shows current values even in background
        if (MainEngineKeepAliveService.isKeepAliveActive) {
          MainEngineKeepAliveService.updateHealthData(
            heartRate: _heartRate,
            spo2: _spo2,
            temperature: _temperature,
            batteryLevel: _batteryLevel,
            steps: _steps,
            bloodPressure: _bloodPressure,
          );
        }
      },
      onError: (error) {
        print('\n❌ ========================================');
        print('❌ Real-time stream error: $error');
        print('❌ Device may have disconnected or gone out of range');
        print('❌ ========================================\n');
        
        // FIX GAP #2: Update _isConnected flag immediately
        setState(() {
          _isConnected = false;
          _connectionState = ConnectionState.error;
          _statusMessage = 'Connection lost: $error';
        });
        
        // Handle disconnection
        if (error.toString().contains('disconnected') || 
            error.toString().contains('connection') ||
            error.toString().contains('GATT')) {
          print('🔄 Device disconnected - attempting reconnection...');
          _handleDisconnection();
        }
      },
      onDone: () {
        print('\n✅ ========================================');
        print('✅ Real-time stream completed/closed');
        print('✅ ========================================\n');
      },
    );
    
    print('✓ Real-time stream subscription created and stored in _realtimeSubscription');
    print('✓ Creating webhook timer (triggers every 300 seconds = 5 minutes)...');
    
    // Set up periodic timer to trigger data refresh every 120 seconds (2 minutes) - TESTING MODE
    // ALWAYS sends webhooks - connected sends real data, disconnected sends null values
    // Backend can identify disconnect by null values and timestamp
    _dataRefreshTimer = Timer.periodic(const Duration(seconds: 300), (timer) async {
      try {
        print('\n⏰ ========================================');
        print('⏰ [Timer] 10-minute webhook timer triggered');
        print('⏰ Status: ${_isConnected ? "CONNECTED" : "DISCONNECTED"}');
        print('⏰ ========================================');
        
        if (_isConnected && _connectedDevice != null) {
          print('   ✅ Device connected - requesting fresh data from device...');
          // Create a temporary subscription to trigger new data request
          // This will trigger the realtime stream, which sends webhook with actual device data
          try {
            _client!.realtimeV2(device).listen(
              (data) {
                print('   ✅ Fresh data received, webhook will be sent automatically');
              }, 
              onError: (e) {
                print('   ⚠️ Error requesting fresh data: $e');
              }
            );
          } catch (e) {
            print('   ⚠️ Error creating realtimeV2 subscription: $e');
          }
        } else {
          print('   ⚠️ Device DISCONNECTED - sending NULL webhook with disconnect reason...');
          // Check if it's network or device disconnect
          try {
            final authService = Provider.of<AuthService>(context, listen: false);
            final user = authService.currentUser;
            
            if (user != null) {
              // Try to determine disconnect reason
              bool isNetworkIssue = await _checkNetworkConnectivity();
              String disconnectReason = isNetworkIssue ? 'Network Disconnect' : 'Device Disconnect';
              print('   📤 Sending disconnect webhook: $disconnectReason');
              await _sendDisconnectWebhook(user.phone, reason: disconnectReason);
              print('   ✅ Disconnect webhook sent successfully');
            } else {
              print('   ⚠️ No user found, cannot send disconnect webhook');
            }
          } catch (e) {
            print('   ❌ Error sending disconnect webhook: $e');
          }
        }
        print('⏰ Timer execution completed\n');
      } catch (e) {
        print('   ❌ CRITICAL ERROR in timer callback: $e');
        print('   Stack trace: ${StackTrace.current}');
      }
    });
    
    print('✓ Webhook timer active - triggers every 120 seconds (2 minutes) - TESTING MODE');
    print('✓ Connected: sends device data | Disconnected: sends null values with error type');
    print('✓ Backend identifies disconnects by null values and error message\n');
  }
  
  void _startHrvAutoRefresh() {
    // Cancel any existing HRV timer
    _hrvRefreshTimer?.cancel();
    
    print('\n📊 ========================================');
    print('📊 Starting HRV auto-refresh');
    print('📊 Refresh interval: Every 6 hours (21600 seconds)');
    print('📊 Works in: Foreground AND Background');
    print('📊 ========================================\n');
    
    // Set up periodic timer for 6-hour HRV data fetch
    _hrvRefreshTimer = Timer.periodic(const Duration(hours: 6), (timer) async {
      if (_isConnected && _connectedDevice != null && _client != null) {
        print('\n⏰ [HRV Auto-Refresh] 6-hour timer triggered');
        print('   Current time: ${DateTime.now().toIso8601String()}');
        
        await _fetchHrvData();
      } else {
        print('⚠️  [HRV Auto-Refresh] Device not connected, skipping refresh');
      }
    });
    
    // Also do an immediate first fetch
    print('🚀 [HRV Auto-Refresh] Doing immediate first HRV fetch...');
    _fetchHrvData();
    
    print('✓ HRV auto-refresh started - will run every 6 hours\n');
  }
  
  void _startHrv2AutoRefresh() {
    // Cancel any existing HRV2 timer
    _hrv2RefreshTimer?.cancel();
    
    print('\n📊 ========================================');
    print('📊 Starting HRV2 auto-refresh');
    print('📊 Refresh interval: Every 6 hours (21600 seconds)');
    print('📊 Works in: Foreground AND Background');
    print('📊 ========================================\n');
    
    // Set up periodic timer for 6-hour HRV2 data fetch
    _hrv2RefreshTimer = Timer.periodic(const Duration(hours: 6), (timer) async {
      if (_isConnected && _connectedDevice != null && _client != null) {
        print('\n⏰ [HRV2 Auto-Refresh] 6-hour timer triggered');
        print('   Current time: ${DateTime.now().toIso8601String()}');
        
        await _fetchHrv2Data();
      } else {
        print('⚠️  [HRV2 Auto-Refresh] Device not connected, skipping refresh');
      }
    });
    
    // Also do an immediate first fetch
    print('🚀 [HRV2 Auto-Refresh] Doing immediate first HRV2 fetch...');
    _fetchHrv2Data();
    
    print('✓ HRV2 auto-refresh started - will run every 6 hours\n');
  }
  
  void _startRriAutoRefresh() {
    // Cancel any existing RRI timer
    _rriRefreshTimer?.cancel();
    
    print('\n📊 ========================================');
    print('📊 Starting RRI auto-refresh');
    print('📊 Refresh interval: Every 6 hours (21600 seconds)');
    print('📊 Works in: Foreground AND Background');
    print('📊 ========================================\n');
    
    // Set up periodic timer for 6-hour RRI data fetch
    _rriRefreshTimer = Timer.periodic(const Duration(hours: 6), (timer) async {
      if (_isConnected && _connectedDevice != null && _client != null) {
        print('\n⏰ [RRI Auto-Refresh] 6-hour timer triggered');
        print('   Current time: ${DateTime.now().toIso8601String()}');
        
        await _fetchRriData();
      } else {
        print('⚠️  [RRI Auto-Refresh] Device not connected, skipping refresh');
      }
    });
    
    // Also do an immediate first fetch
    print('🚀 [RRI Auto-Refresh] Doing immediate first RRI fetch...');
    _fetchRriData();
    
    print('✓ RRI auto-refresh started - will run every 6 hours\n');
  }
  
  void _startTemperatureAutoRefresh() {
    // Cancel any existing Temperature timer
    _temperatureRefreshTimer?.cancel();
    
    print('\n📊 ========================================');
    print('📊 Starting Temperature auto-refresh');
    print('📊 Refresh interval: Every 6 hours (21600 seconds)');
    print('📊 Works in: Foreground AND Background');
    print('📊 ========================================\n');
    
    // Set up periodic timer for 6-hour Temperature data fetch
    _temperatureRefreshTimer = Timer.periodic(const Duration(hours: 6), (timer) async {
      if (_isConnected && _connectedDevice != null && _client != null) {
        print('\n⏰ [Temperature Auto-Refresh] 6-hour timer triggered');
        print('   Current time: ${DateTime.now().toIso8601String()}');
        
        await _fetchTemperatureData();
      } else {
        print('⚠️  [Temperature Auto-Refresh] Device not connected, skipping refresh');
      }
    });
    
    // Also do an immediate first fetch
    print('🚀 [Temperature Auto-Refresh] Doing immediate first Temperature fetch...');
    _fetchTemperatureData();
    
    print('✓ Temperature auto-refresh started - will run every 6 hours\n');
  }
  
  Future<void> _fetchHrvData() async {
    if (_client == null || _connectedDevice == null) {
      print('⚠️  [HRV Fetch] No device connected');
      return;
    }
    
    try {
      final now = DateTime.now();
      final yy = now.year % 100;
      final mm = now.month;
      final dd = now.day;
      final dateStr = '${now.year}-${mm.toString().padLeft(2, '0')}-${dd.toString().padLeft(2, '0')}';
      
      print('\n📊 ========================================');
      print('📊 Fetching HRV data for $dateStr');
      print('📊 Device: ${_connectedDevice!.name}');
      print('📊 Note: SDK automatically uploads to Nitto cloud');
      print('📊 ========================================');
      
      // Fetch HRV data from device
      // This automatically triggers upload to Nitto cloud server
      final hrvRows = await _client!.getAllDayHrvRows(
        _connectedDevice!,
        yy: yy,
        mm: mm,
        dd: dd,
      );
      
      print('✅ HRV data fetched: ${hrvRows.length} records');
      print('✅ Data automatically uploaded to Nitto cloud by SDK');
      
      setState(() {
        _lastHrvRefresh = DateTime.now();
      });
      
      print('✅ HRV refresh completed successfully\n');
    } catch (e) {
      print('❌ Error fetching HRV data: $e');
      
      // Handle specific error codes
      if (e.toString().contains('0xE2') || e.toString().contains('0xe2')) {
        print('ℹ️  Device reported no HRV data available');
      }
    }
  }

  // Convert HRV2 rows from SDK format to webhook JSON format
  List<Map<String, dynamic>> _convertHrv2RowsToJson(List<dynamic> hrv2Rows) {
    return hrv2Rows.map((row) {
      final values = row.values ?? {};

      DateTime? parsedDateTime;
      try {
        parsedDateTime = DateTime.parse(row.dateTime);
      } catch (_) {
        parsedDateTime = DateTime.now();
      }

      return {
        'dateTime': row.dateTime,
        'mental_stress': values['mentalStress'],
        'fatigue_level': values['fatigue'],
        'stress_resistance': values['stressResistance'],
        'regulation_ability': values['regulationAbility'],
        'valid': row.valid,
      };
    }).toList();
  }

  // Send HRV2 history data to webhook (automatic 6-hour or manual trigger)
  Future<void> _sendHrv2ToWebhook(List<dynamic> hrv2Rows, String dateStr, {bool isAutomatic = false}) async {
    if (_connectedDevice == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    final now = DateTime.now();

    final hrv2JsonList = _convertHrv2RowsToJson(hrv2Rows);

    final payload = {
      'dataType': 'history',
      'historyType': 'hrv2',
      'source': isAutomatic ? 'auto_6hour_refresh' : 'manual_send',
      'timestamp': now.toIso8601String(),
      'device': {
        'id': _connectedDevice!.id,
        'name': _connectedDevice!.name,
      },
      'history_data': {
        'hrv2': hrv2JsonList,
        'phone': user?.phone ?? 'unknown',
        'date': dateStr,
        'recordCounts': {
          'hrv2': hrv2JsonList.length,
        }
      },
      'recordCounts': {
        'hrv2': hrv2JsonList.length,
      }
    };

    print('\n📤 ========================================');
    print('📤 Sending HRV2 ${isAutomatic ? '(AUTO 6-hour)' : '(MANUAL)'} to webhook');
    print('📤 URL: $_webhookUrl');
    print('📤 Records: ${hrv2JsonList.length}');
    print('📤 Phone: ${user?.phone ?? 'unknown'}');
    print('📤 Source: ${isAutomatic ? 'Automatic 6-hour refresh' : 'Manual send button'}');
    print('📤 ========================================\n');

    try {
      final response = await _dio.post(
        _webhookUrl,
        data: payload,
      );

      _webhookSuccessCount++;
      _lastWebhookStatus = '✓ HRV2 history sent (${response.statusCode})';
      _lastWebhookTime = DateTime.now();

      print('✅ HRV2 webhook response: ${response.statusCode}');
      print('✅ Backend received ${hrv2JsonList.length} HRV2 records');
      print('✅ Response: ${response.data}');
    } catch (e) {
      _webhookErrorCount++;
      _lastWebhookStatus = '✗ HRV2 history failed';
      _lastWebhookError = e.toString();
      _lastWebhookTime = DateTime.now();

      print('❌ Error sending HRV2 to webhook: $e');
      rethrow;
    }
  }
  
  Future<void> _fetchHrv2Data() async {
    if (_client == null || _connectedDevice == null) {
      print('⚠️  [HRV2 Fetch] No device connected');
      return;
    }
    
    try {
      final now = DateTime.now();
      final yy = now.year % 100;
      final mm = now.month;
      final dd = now.day;
      final dateStr = '${now.year}-${mm.toString().padLeft(2, '0')}-${dd.toString().padLeft(2, '0')}';
      
      print('\n📊 ========================================');
      print('📊 Fetching HRV2 data for $dateStr');
      print('📊 Device: ${_connectedDevice!.name}');
      print('📊 Note: SDK automatically uploads to Nitto cloud');
      print('📊 ========================================');
      
      // Fetch HRV2 data from device
      // This automatically triggers upload to Nitto cloud server
      final hrv2Rows = await _client!.getAllDayHrv2Rows(
        _connectedDevice!,
        yy: yy,
        mm: mm,
        dd: dd,
      );
      
      print('✅ HRV2 data fetched: ${hrv2Rows.length} records');
      print('✅ Data automatically uploaded to Nitto cloud by SDK');

      if (hrv2Rows.isNotEmpty) {
        print('📤 Also sending HRV2 to webhook...');
        await _sendHrv2ToWebhook(hrv2Rows, dateStr, isAutomatic: true);
      } else {
        print('⚠️  No HRV2 records to send to webhook');
      }
      
      print('✅ HRV2 refresh completed successfully\n');
    } catch (e) {
      print('❌ Error fetching HRV2 data: $e');
      
      // Handle specific error codes
      if (e.toString().contains('0xE2') || e.toString().contains('0xe2')) {
        print('ℹ️  Device reported no HRV2 data available');
      }
    }
  }
  
  Future<void> _fetchRriData() async {
    if (_client == null || _connectedDevice == null) {
      print('⚠️  [RRI Fetch] No device connected');
      return;
    }
    
    try {
      final now = DateTime.now();
      final yy = now.year % 100;
      final mm = now.month;
      final dd = now.day;
      final dateStr = '${now.year}-${mm.toString().padLeft(2, '0')}-${dd.toString().padLeft(2, '0')}';
      
      print('\n📊 ========================================');
      print('📊 Fetching RRI data for $dateStr');
      print('📊 Device: ${_connectedDevice!.name}');
      print('📊 Note: SDK automatically uploads to Nitto cloud');
      print('📊 ========================================');
      
      // Fetch RRI data from device
      // This automatically triggers upload to Nitto cloud server
      final rriRows = await _client!.getAllDayRriRows(
        _connectedDevice!,
        yy: yy,
        mm: mm,
        dd: dd,
      );
      
      print('✅ RRI data fetched: ${rriRows.length} records');
      print('✅ Data automatically uploaded to Nitto cloud by SDK');
      
      print('✅ RRI refresh completed successfully\n');
    } catch (e) {
      print('❌ Error fetching RRI data: $e');
      
      // Handle specific error codes
      if (e.toString().contains('0xE2') || e.toString().contains('0xe2')) {
        print('ℹ️  Device reported no RRI data available');
      }
    }
  }
  
  Future<void> _fetchTemperatureData() async {
    if (_client == null || _connectedDevice == null) {
      print('⚠️  [Temperature Fetch] No device connected');
      return;
    }
    
    try {
      final now = DateTime.now();
      final yy = now.year % 100;
      final mm = now.month;
      final dd = now.day;
      final dateStr = '${now.year}-${mm.toString().padLeft(2, '0')}-${dd.toString().padLeft(2, '0')}';
      
      print('\n📊 ========================================');
      print('📊 Fetching Temperature data for $dateStr');
      print('📊 Device: ${_connectedDevice!.name}');
      print('📊 Note: SDK automatically uploads to Nitto cloud');
      print('📊 ========================================');
      
      // Fetch Temperature data from device
      // This automatically triggers upload to Nitto cloud server
      final temperatureRows = await _client!.getAllDayTemperatureRows(
        _connectedDevice!,
        yy: yy,
        mm: mm,
        dd: dd,
      );
      
      print('✅ Temperature data fetched: ${temperatureRows.length} records');
      print('✅ Data automatically uploaded to Nitto cloud by SDK');
      
      print('✅ Temperature refresh completed successfully\n');
    } catch (e) {
      print('❌ Error fetching Temperature data: $e');
      
      // Handle specific error codes
      if (e.toString().contains('0xE2') || e.toString().contains('0xe2')) {
        print('ℹ️  Device reported no Temperature data available');
      }
    }
  }
  
  void _startConnectionMonitoring() {
    print('🔍 Starting connection monitoring (checking every 30 seconds)...');
    print('🔍 Disconnect detection: 300s (5 min) = 2.5x webhook interval');
    print('🔍 Active connection ping + timestamp check for reliability\n');
    
    _connectionMonitor?.cancel();
    _connectionMonitor = Timer.periodic(const Duration(seconds: 30), (timer) async {
      // FIX GAP #7: Keep monitoring even when disconnected to facilitate auto-reconnect
      if (_connectedDevice == null) {
        print('⚠️ [Monitor] No device configured, stopping monitor');
        timer.cancel();
        return;
      }
      
      // Skip active checks if not connected (let auto-reconnect handle it)
      if (!_isConnected) {
        print('🔍 [Monitor] Device disconnected, auto-reconnect will handle');
        return;
      }
      
      // FIX GAP #3: Active connection check - ping device to verify connection
      try {
        if (_client != null && _connectedDevice != null) {
          print('🔍 [Monitor] Pinging device to verify connection...');
          
          // Try to read battery info as a lightweight connection check
          final batteryFuture = _client!.readDeviceInfo(_connectedDevice!).timeout(
            const Duration(seconds: 5),
          );
          
          await batteryFuture;
          print('✅ [Monitor] Connection alive - device responding');
        }
      } catch (e) {
        print('❌ [Monitor] Active connection check FAILED: $e');
        print('❌ [Monitor] Device not responding - likely disconnected');
        
        setState(() {
          _isConnected = false;
          _connectionState = ConnectionState.error;
          _statusMessage = 'Device not responding';
        });
        
        _handleDisconnection();
        return;
      }
      
      // FIX GAP #1: Backup timestamp check - reduced from 720s to 300s (5 minutes)
      final now = DateTime.now();
      if (_lastDataReceived != null) {
        final timeSinceLastData = now.difference(_lastDataReceived!).inSeconds;
        print('🔍 [Monitor] Last data received: ${timeSinceLastData}s ago');
        
        // Disconnect after 300 seconds (5 minutes = 2.5x the 2-minute webhook interval)
        // This allows for 1 missed webhook (240s) plus buffer
        if (timeSinceLastData > 300) {
          print('❌ [Monitor] No data for ${timeSinceLastData}s (>${300}s threshold)');
          print('❌ [Monitor] Device disconnected - triggering reconnection');
          
          setState(() {
            _isConnected = false;
            _connectionState = ConnectionState.error;
            _statusMessage = 'No data received for 5 minutes';
          });
          
          _handleDisconnection();
        } else if (timeSinceLastData > 240) {
          print('⏰ [Monitor] Data delayed (${timeSinceLastData}s), but within tolerance');
          setState(() {
            _statusMessage = 'Data delayed (${timeSinceLastData}s)...';
          });
        }
      }
    });
  }
  
  void _handleDisconnection() async {
    if (_isReconnecting) {
      print('⏳ Already attempting reconnection...');
      return;
    }
    
    // Update connection state for WorkManager
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('device_connected', false);
    print('⚠️ Device disconnected - WorkManager will continue sending disconnect webhooks');
    
    // Show disconnect notification on first disconnect attempt
    if (_reconnectAttempts == 0) {
      _showDisconnectNotification('Device disconnected - attempting to reconnect');
    }
    
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('❌ Max reconnection attempts reached. Please reconnect manually.');
      
      // Track disconnect event
      _addConnectionEvent(
        event: 'disconnected',
        reason: 'Max reconnection attempts reached',
        deviceId: _connectedDevice?.id,
      );
      _totalDisconnects++;
      
      // Show notification
      _showDisconnectNotification('Max reconnection attempts reached');
      
      setState(() {
        _statusMessage = 'Device disconnected. Please reconnect manually.';
        _isConnected = false;
        _connectionState = ConnectionState.error;
      });
      _cleanup();
      return;
    }
    
    _isReconnecting = true;
    _reconnectAttempts++;
    
    print('🔄 Reconnection attempt $_reconnectAttempts/$_maxReconnectAttempts...');
    
    setState(() {
      _connectionState = ConnectionState.reconnecting;
      _statusMessage = 'Reconnecting... (Attempt $_reconnectAttempts/$_maxReconnectAttempts)';
    });
    
    // Cleanup old connections
    _cleanup();
    
    // Wait a bit before reconnecting
    await Future.delayed(Duration(seconds: 2));
    
    if (_connectedDevice != null && _client != null) {
      try {
        print('🔄 Attempting to reconnect to ${_connectedDevice!.name}...');
        await _connectToDevice(_connectedDevice!);
        print('✅ Reconnection successful!');
      } catch (e) {
        print('❌ Reconnection failed: $e');
        setState(() {
          _statusMessage = 'Reconnection failed. Retrying...';
        });
        
        // Try again after delay
        await Future.delayed(Duration(seconds: 3));
        if (_reconnectAttempts < _maxReconnectAttempts) {
          _isReconnecting = false;
          _handleDisconnection();
        }
      }
    }
    
    _isReconnecting = false;
  }
  
  void _cleanup() {
    print('🧹 Cleaning up connections...');
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    // DON'T cancel _dataRefreshTimer - it should keep running to send null values!
    // _dataRefreshTimer?.cancel();
    // _dataRefreshTimer = null;
    _connectionMonitor?.cancel();
    _connectionMonitor = null;
    _hrvRefreshTimer?.cancel();
    _hrvRefreshTimer = null;
    _hrv2RefreshTimer?.cancel();
    _hrv2RefreshTimer = null;
    _rriRefreshTimer?.cancel();
    _rriRefreshTimer = null;
    _temperatureRefreshTimer?.cancel();
    _temperatureRefreshTimer = null;
  }
  
  void _sendStressWebhook() {
    if (_connectedDevice == null || !_isConnected || _client == null) {
      print('⚠️ Cannot send stress webhook - no device connected');
      setState(() {
        _statusMessage = 'No device connected';
      });
      return;
    }
    
    print('\n🚨 ========================================');
    print('🚨 STRESS BUTTON PRESSED');
    print('🚨 Requesting IMMEDIATE fresh data from device...');
    print('🚨 ========================================\n');
    
    setState(() {
      _stressAlertPending = true;
      _statusMessage = 'Requesting fresh data...';
    });
    
    // Trigger immediate data request by creating a brief subscription
    // This will cause the device to send fresh data immediately
    // The main subscription listener will catch it and send stress webhook
    _client!.realtimeV2(_connectedDevice!).listen((_) {}, onError: (_) {}).cancel();
  }
  
  Future<void> _sendDataToWebhook(Hc20Device device, Hc20RealtimeV2 data, {bool isStressAlert = false, bool isLowBattery = false}) async {
    try {
      final now = DateTime.now();
      
      // Check internet status right before sending (more accurate)
      final currentInternetStatus = await _checkInternetConnectivity();
      
      // Prepare comprehensive payload with all available data
      final payload = {
        'isStressAlert': isStressAlert,
        'timestamp': now.toIso8601String(), // Send local timestamp with timezone (e.g., 2025-12-30T08:00:00.000+05:30)
        
        // Status fields
        'status': 'Connected',
        'bluetoothStatus': _isBluetoothOn ? 'Connected' : 'Disconnected',
        'internetStatus': currentInternetStatus ? 'Connected' : 'Disconnected',
        'dataType': 'live',  // vs 'history' or 'disconnect'
        
        // Device battery information
        'deviceBatteryLevel': _batteryLevel,
        'isDeviceLowBattery': isLowBattery || _isLowBattery,
        
        'device': {
          'id': device.id,
          'name': device.name,
        },
        'realtime_data': {
          // Vital signs
          'heart_rate': data.heart,
          'rri': data.rri,
          'spo2': data.spo2,
          'blood_pressure': data.bp != null ? {
            'systolic': data.bp!.length > 0 ? data.bp![0] : null,
            'diastolic': data.bp!.length > 1 ? data.bp![1] : null,
          } : null,
          
          // Temperature (divided by 100 as per HC20 spec)
          'temperature': data.temperature?.map((t) => t / 100.0).toList(),
          
          // Battery
          'battery': data.battery != null ? {
            'percent': data.battery!.percent,
            'charge': data.battery!.charge,
          } : null,
          
          // Basic data (steps, calories, distance)
          'basic_data': data.basicData,
          
          // Barometric pressure
          'barometric_pressure': data.baro,
          
          // Wear status
          'wear_status': data.wear,
          
          // Sleep (raw array: status, deep, light, rem, sober)
          'sleep': data.sleep,
          
          // GNSS/GPS (raw array: onoff, sigqual, timestamp, lat, lon, alt)
          'gnss': data.gnss,
          
          // HRV (raw array: SDNN, TP, LF, HF, VLF - values x1000)
          'hrv_raw': data.hrv,
          'hrv_metrics': data.hrvMetrics != null ? {
            'sdnn': data.hrvMetrics!.sdnn,
            'tp': data.hrvMetrics!.tp,
            'lf': data.hrvMetrics!.lf,
            'hf': data.hrvMetrics!.hf,
            'vlf': data.hrvMetrics!.vlf,
          } : null,
          
          // HRV2 (raw array: mental_stress, fatigue, stress_resistance, regulation_ability)
          'hrv2_raw': data.hrv2,
          'hrv2_metrics': data.hrv2Metrics != null ? {
            'mental_stress': data.hrv2Metrics!.mentStress,
            'fatigue_level': data.hrv2Metrics!.fatigueLevel,
            'stress_resistance': data.hrv2Metrics!.stressResistance,
            'regulation_ability': data.hrv2Metrics!.regulationAbility,
          } : null,
        },
      };
      
      // Send POST request to webhook (with timeout)
      final response = await _dio.post(
        _webhookUrl,
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      
      // Update success status
      setState(() {
        _webhookSuccessCount++;
        _lastWebhookStatus = isStressAlert ? '✓ Stress Alert Sent (${response.statusCode})' : '✓ Sent (${response.statusCode})';
        _lastWebhookError = '';
        _lastWebhookTime = DateTime.now();
      });
      print('\n✅ ========================================');
      if (isStressAlert) print('✅ 🚨 STRESS ALERT WEBHOOK');
      print('✅ Webhook SUCCESS!');
      print('✅ Status Code: ${response.statusCode}');
      print('✅ Success Count: $_webhookSuccessCount');
      print('✅ Response: ${response.data}');
      print('✅ ========================================\n');
    } on DioException catch (e) {
      // Handle Dio-specific errors with detailed information
      String errorDetail = '';
      if (e.type == DioExceptionType.connectionTimeout) {
        errorDetail = 'Timeout: Backend took >5s to respond';
      } else if (e.type == DioExceptionType.sendTimeout) {
        errorDetail = 'Send timeout: Data send took >5s';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorDetail = 'Receive timeout: No response in 5s';
      } else if (e.type == DioExceptionType.badResponse) {
        errorDetail = 'HTTP ${e.response?.statusCode}: ${e.response?.statusMessage ?? "Bad response"}\nData: ${e.response?.data}';
      } else if (e.type == DioExceptionType.connectionError) {
        errorDetail = 'Network error: ${e.message ?? "Can\'t reach api.hireforcare.com"}\nCheck: WiFi/Mobile data enabled?';
      } else if (e.type == DioExceptionType.badCertificate) {
        errorDetail = 'SSL/Certificate error: ${e.message}';
      } else if (e.type == DioExceptionType.cancel) {
        errorDetail = 'Request cancelled';
      } else {
        errorDetail = 'Error: ${e.type.toString()}\n${e.message ?? "Unknown"}';
      }
      
      setState(() {
        _webhookErrorCount++;
        _lastWebhookStatus = '✗ Failed';
        _lastWebhookError = errorDetail;
        _lastWebhookTime = DateTime.now();
      });
      print('\n❌ ========================================');
      print('❌ Webhook DioException!');
      print('❌ Error Type: ${e.type}');
      print('❌ Error Count: $_webhookErrorCount');
      print('❌ Detail: $errorDetail');
      print('❌ Full error: $e');
      if (e.response != null) {
        print('❌ Response data: ${e.response?.data}');
      }
      print('❌ ========================================\n');
    } catch (e) {
      // Handle any other errors
      setState(() {
        _webhookErrorCount++;
        _lastWebhookStatus = '✗ Failed';
        _lastWebhookError = e.toString();
        _lastWebhookTime = DateTime.now();
      });
      print('⚠ Webhook error: $e');
    }
  }

  Future<void> _sendDisconnectWebhook(String phone, {String reason = 'Device Disconnect'}) async {
    try {
      // Check internet status right before sending (more accurate)
      final currentInternetStatus = await _checkInternetConnectivity();
      
      final response = await _dio.post(
        _webhookUrl,
        data: {
          'phone': phone,
          'deviceId': _connectedDevice?.id ?? _savedDeviceId ?? 'unknown',
          'isDisconnected': true,  // CRITICAL FLAG for backend to identify disconnect events
          'disconnectReason': reason,  // Specific reason (Bluetooth off, out of range, etc.)
          'heartRate': null,
          'spo2': null,
          'bloodPressure': null,
          'temperature': null,
          'batteryLevel': null,
          'steps': null,
          'status': 'DISCONNECTED',  // Explicit status
          'message': reason,
          'errorType': reason,
          'timestamp': DateTime.now().toIso8601String(),
          'bluetoothStatus': _isBluetoothOn ? 'ON' : 'OFF',
          'internetStatus': currentInternetStatus ? 'Connected' : 'Disconnected',
        },
      );
      
      if (response.statusCode == 200) {
        print('✅ Disconnect webhook sent with null values: $reason');
      } else {
        print('❌ Webhook failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Webhook error: $e');
    }
  }

  // Check network connectivity with multiple endpoints for reliability
  Future<bool> _checkNetworkConnectivity() async {
    return await _checkInternetConnectivity();
  }
  
  // Improved internet connectivity check with multiple fallback endpoints
  Future<bool> _checkInternetConnectivity() async {
    // List of endpoints to try (in order)
    final endpoints = [
      'https://api.hireforcare.com/health',
      'https://www.google.com',
      'https://dns.google',
    ];
    
    for (final endpoint in endpoints) {
      try {
        final result = await _dio.get(
          endpoint,
          options: Options(
            receiveTimeout: const Duration(seconds: 3),
            sendTimeout: const Duration(seconds: 3),
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        if (result.statusCode != null && result.statusCode! < 500) {
          print('✅ Internet check passed via $endpoint');
          return true;
        }
      } catch (e) {
        print('⚠️ Internet check failed for $endpoint: $e');
        continue; // Try next endpoint
      }
    }
    
    // All endpoints failed
    print('❌ All internet connectivity checks failed');
    return false;
  }

  // Save device ID for auto-reconnect
  Future<void> _saveDeviceForAutoReconnect(String deviceId) async {
    try {
      await StorageService().saveDeviceId(deviceId);
      setState(() {
        _savedDeviceId = deviceId;
      });
      print('💾 Device ID saved for auto-reconnect: $deviceId');
      print('   Device will auto-connect when nearby');
      
      // Start auto-reconnect scanner if not already running
      if (_autoReconnectScanner == null || !_autoReconnectScanner!.isActive) {
        _startAutoReconnectScanner();
      }
    } catch (e) {
      print('⚠️ Error saving device ID: $e');
    }
  }

  // Add connection event to history
  void _addConnectionEvent({
    required String event,
    String? reason,
    String? deviceId,
  }) {
    final newEvent = ConnectionEvent(
      timestamp: DateTime.now(),
      event: event,
      reason: reason,
      deviceId: deviceId,
    );
    
    setState(() {
      _connectionHistory.insert(0, newEvent);
      
      // Keep only last 50 events
      if (_connectionHistory.length > 50) {
        _connectionHistory = _connectionHistory.sublist(0, 50);
      }
      
      // Track disconnect patterns
      if (event == 'disconnected' && reason != null) {
        _disconnectReasons[reason] = (_disconnectReasons[reason] ?? 0) + 1;
        _lastDisconnectTime = DateTime.now();
      }
    });
    
    print('📊 [History] Event logged: $event ${reason != null ? "($reason)" : ""}');
  }
  
  // Calculate disconnect analytics
  Map<String, dynamic> _getDisconnectAnalytics() {
    final disconnects = _connectionHistory.where((e) => e.event == 'disconnected').toList();
    
    if (disconnects.isEmpty) {
      return {
        'totalDisconnects': 0,
        'avgDisconnectDuration': Duration.zero,
        'mostCommonReason': 'N/A',
      };
    }
    
    // Calculate average disconnect duration
    Duration totalDuration = Duration.zero;
    int durationCount = 0;
    
    for (int i = 0; i < disconnects.length; i++) {
      final disconnect = disconnects[i];
      // Find next reconnect event
      final reconnectIndex = _connectionHistory.indexOf(disconnect) - 1;
      if (reconnectIndex >= 0 && _connectionHistory[reconnectIndex].event == 'reconnected') {
        final duration = _connectionHistory[reconnectIndex].timestamp.difference(disconnect.timestamp);
        totalDuration += duration;
        durationCount++;
        
        // Track longest disconnect
        if (_longestDisconnectDuration == null || duration > _longestDisconnectDuration!) {
          _longestDisconnectDuration = duration;
        }
      }
    }
    
    final avgDuration = durationCount > 0
        ? totalDuration ~/ durationCount
        : Duration.zero;
    
    // Find most common reason
    String mostCommonReason = 'Unknown';
    int maxCount = 0;
    _disconnectReasons.forEach((reason, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommonReason = reason;
      }
    });
    
    return {
      'totalDisconnects': _totalDisconnects,
      'totalReconnects': _totalReconnects,
      'avgDisconnectDuration': avgDuration,
      'longestDisconnect': _longestDisconnectDuration ?? Duration.zero,
      'mostCommonReason': mostCommonReason,
      'reasonCounts': _disconnectReasons,
    };
  }
  
  // Manual reconnect button handler
  Future<void> _manualReconnect() async {
    if (_savedDeviceId == null || _savedDeviceId!.isEmpty) {
      setState(() {
        _statusMessage = '⚠️ No saved device. Please scan and connect first.';
      });
      return;
    }
    
    if (_isConnected) {
      setState(() {
        _statusMessage = 'Already connected to device';
      });
      return;
    }
    
    if (_isAutoReconnecting || _isReconnecting) {
      setState(() {
        _statusMessage = 'Reconnection already in progress...';
      });
      return;
    }
    
    print('🔄 Manual reconnect triggered by user');
    setState(() {
      _connectionState = ConnectionState.connecting;
      _statusMessage = 'Manual reconnect: Scanning for device...';
      _reconnectAttempts = 0; // Reset attempts for manual reconnect
    });
    
    await _scanForSavedDevice();
  }
  
  // Start background scanner for auto-reconnect
  void _startAutoReconnectScanner() {
    if (_savedDeviceId == null || _savedDeviceId!.isEmpty) {
      print('ℹ️  No saved device - auto-reconnect scanner not started');
      return;
    }

    // Cancel any existing scanner
    _autoReconnectScanner?.cancel();

    print('\n🔍 ========================================');
    print('🔍 Starting Auto-Reconnect Scanner');
    print('🔍 Target Device: $_savedDeviceId');
    print('🔍 Scan interval: Every 30 seconds');
    print('🔍 Auto-connects when device is nearby');
    print('🔍 ========================================\n');

    // Scan every 30 seconds for the saved device
    _autoReconnectScanner = Timer.periodic(const Duration(seconds: 30), (timer) async {
      // Only scan if not already connected and not currently reconnecting
      if (_isConnected || _isAutoReconnecting || _isScanning) {
        return;
      }

      print('⏰ [Auto-Reconnect] Scanning for saved device...');
      await _scanForSavedDevice();
    });

    // Do immediate first scan
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isConnected && !_isAutoReconnecting) {
        _scanForSavedDevice();
      }
    });
  }

  // Scan for the saved device and auto-connect if found
  Future<void> _scanForSavedDevice() async {
    if (_savedDeviceId == null || _isConnected || _isAutoReconnecting) {
      return;
    }

    // Initialize client if needed
    if (_client == null) {
      await _initializeHC20Client();
      if (_client == null) {
        print('⚠️ [Auto-Reconnect] Failed to initialize HC20 client');
        return;
      }
    }

    setState(() {
      _isAutoReconnecting = true;
    });

    print('🔍 [Auto-Reconnect] Scanning for device: $_savedDeviceId');

    try {
      Hc20Device? foundDevice;
      
      // Listen for scanned devices
      final subscription = _client!.scan().listen(
        (device) {
          if (device.id == _savedDeviceId && foundDevice == null) {
            foundDevice = device;
            print('✅ [Auto-Reconnect] Found saved device: ${device.name} ($_savedDeviceId)');
          }
        },
        onError: (error) {
          print('⚠️ [Auto-Reconnect] Scan error: $error');
        },
      );

      // Wait 10 seconds for scan
      await Future.delayed(const Duration(seconds: 10));
      subscription.cancel();

      // If device found, connect to it
      if (foundDevice != null) {
        _consecutiveFailedScans = 0;  // Reset counter on successful find
        print('🔌 [Auto-Reconnect] Connecting to saved device...');
        setState(() {
          _statusMessage = '🔄 Auto-connecting to ${foundDevice!.name}...';
        });
        await _connectToDevice(foundDevice!);
      } else {
        _consecutiveFailedScans++;
        print('ℹ️  [Auto-Reconnect] Saved device not found nearby (attempt $_consecutiveFailedScans)');
        
        // Show notification after 3 consecutive failed scans (about 1.5 minutes)
        if (_consecutiveFailedScans == 3) {
          _showDeviceNotFoundNotification();
        }
      }
    } catch (e) {
      print('⚠️ [Auto-Reconnect] Error: $e');
    } finally {
      setState(() {
        _isAutoReconnecting = false;
      });
    }
  }

  Future<void> _sendTestNotification() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      setState(() {
        _statusMessage = 'Error: Please login first';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Please login first to send notifications'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    if (_connectedDevice == null) {
      setState(() {
        _statusMessage = 'Error: Please connect to a device first';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Please connect to a device first'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    setState(() {
      _statusMessage = 'Sending test notification...';
    });
    
    try {
      print('📱 ========================================');
      print('📱 Sending test disconnect notification');
      print('📱 User: ${user.name}');
      print('📱 Phone: ${user.phone}');
      print('📱 Device: ${_connectedDevice!.name} (${_connectedDevice!.id})');
      print('📱 ========================================');
      
      final response = await _apiService.sendDisconnectNotification(
        phone: user.phone,
        deviceId: _connectedDevice!.id,
        deviceName: _connectedDevice!.name,
      );
      
      if (response['success'] == true) {
        setState(() {
          _statusMessage = '✅ Test notification sent to ${user.phone}!';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ WhatsApp notification sent to ${user.phone}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        print('✅ Notification sent successfully');
      } else {
        final errorMsg = response['error'] ?? 'Unknown error';
        
        setState(() {
          _statusMessage = '❌ Failed: $errorMsg';
        });
        
        if (mounted) {
          // Check if it's an auth error
          if (errorMsg.toLowerCase().contains('auth') || 
              errorMsg.toLowerCase().contains('token') ||
              errorMsg.toLowerCase().contains('login')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('❌ Authentication Error'),
                    SizedBox(height: 4),
                    Text('Please LOGOUT and LOGIN again', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Your session may have expired', style: TextStyle(fontSize: 12)),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'LOGOUT',
                  textColor: Colors.white,
                  onPressed: () async {
                    await authService.logout();
                  },
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Failed: $errorMsg'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        
        print('❌ Notification failed: ${response['error']}');
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error sending notification: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      print('❌ Error: $e');
    }
  }

  Future<void> _testWebhook() async {
    setState(() {
      _statusMessage = 'Testing webhook connection...';
    });
    
    try {
      final now = DateTime.now();
      
      final testPayload = {
        'test': true,
        'timestamp': now.toIso8601String(), // Send local timestamp with timezone
        'message': 'Test connection from HFC App',
        'device': {'id': 'test-device', 'name': 'Test Device'},
      };
      
      print('🧪 Testing webhook: $_webhookUrl');
      print('   Payload: $testPayload');
      
      final response = await _dio.post(
        _webhookUrl,
        data: testPayload,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      
      setState(() {
        _webhookSuccessCount++;
        _lastWebhookStatus = '✓ Test OK (${response.statusCode})';
        _lastWebhookError = '';
        _lastWebhookTime = DateTime.now();
        _statusMessage = 'Webhook test successful!';
      });
      print('✓ Test successful: ${response.statusCode}');
      print('   Response: ${response.data}');
    } on DioException catch (e) {
      String errorDetail = 'Type: ${e.type}\nMessage: ${e.message}\nURL: $_webhookUrl';
      if (e.response != null) {
        errorDetail += '\nHTTP ${e.response!.statusCode}: ${e.response!.data}';
      }
      
      setState(() {
        _webhookErrorCount++;
        _lastWebhookStatus = '✗ Test Failed';
        _lastWebhookError = errorDetail;
        _lastWebhookTime = DateTime.now();
        _statusMessage = 'Webhook test failed!';
      });
      print('✗ Test failed: $errorDetail');
    } catch (e) {
      setState(() {
        _webhookErrorCount++;
        _lastWebhookStatus = '✗ Test Failed';
        _lastWebhookError = e.toString();
        _lastWebhookTime = DateTime.now();
        _statusMessage = 'Webhook test error!';
      });
      print('✗ Test error: $e');
    }
  }

  // Update native service with live health data
  Future<void> _updateNativeServiceData(Hc20Device device, Hc20RealtimeV2 data) async {
    try {
      const platform = MethodChannel('com.hfc.app/background');
      await platform.invokeMethod('updateHealthData', {
        'deviceId': device.id,
        'heartRate': data.heart,
        'spo2': data.spo2,
        'temperature': data.temperature != null && data.temperature!.length > 2 ? data.temperature![2] : null,
        'batteryLevel': data.battery?.percent,
        'bloodPressureSystolic': data.bp != null && data.bp!.length > 0 ? data.bp![0] : null,
        'bloodPressureDiastolic': data.bp != null && data.bp!.length > 1 ? data.bp![1] : null,
        'steps': data.basicData != null && data.basicData!.length > 0 ? data.basicData![0] : null,
      });
    } catch (e) {
      // Silently fail - native service may not be running
    }
  }
  
  Future<void> _disconnect() async {
    if (_client == null || _connectedDevice == null) return;

    try {
      print('ℹ️ Disconnecting from device...');
      
      // Stop native BLE service
      try {
        const platform = MethodChannel('com.hfc.app/background');
        await platform.invokeMethod('stopNativeBleService');
        print('✅ Native BLE service stopped');
      } catch (e) {
        print('⚠️ Could not stop native BLE service: $e');
      }
      
      // Stop background service
      try {
        const platform = MethodChannel('com.hfc.app/background');
        await platform.invokeMethod('disableBackgroundExecution');
        print('✅ Background service stopped');
      } catch (e) {
        print('⚠️ Could not stop background service: $e');
      }

      // Stop flutter_background_service keepalive (disabled)
      if (_bgPluginEnabled) {
        try {
          await BackgroundServiceManager.instance.stop();
        } catch (e) {
          print('⚠️ Could not stop BackgroundServiceManager: $e');
        }
      }

      await _client!.disconnect(_connectedDevice!);
      
      setState(() {
        _connectionState = ConnectionState.disconnected;
        _statusMessage = 'Disconnected';
        _reconnectAttempts = 0;
        _isReconnecting = false;
        _lastDataReceived = null;
        // Clear real-time data
        _heartRate = null;
        _spo2 = null;
        _bloodPressure = null;
        _temperature = null;
        _batteryLevel = null;
        _steps = null;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Disconnect error: $e';
      });
    }
  }

  Future<void> _getHistoryData() async {
    if (_client == null || _connectedDevice == null) return;

    try {
      setState(() {
        _statusMessage = 'Fetching history data...';
      });

      final now = DateTime.now();
      
      // Get today's summary
      final summaryRows = await _client!.getAllDaySummaryRows(
        _connectedDevice!,
        yy: now.year % 100,
        mm: now.month,
        dd: now.day,
      );

      // Get heart rate data
      final heartRows = await _client!.getAllDayHeartRows(
        _connectedDevice!,
        yy: now.year % 100,
        mm: now.month,
        dd: now.day,
      );

      // Get HRV data (includes auto cloud upload)
      final hrvRows = await _client!.getAllDayHrvRows(
        _connectedDevice!,
        yy: now.year % 100,
        mm: now.month,
        dd: now.day,
      );

      setState(() {
        _statusMessage = 'History: ${summaryRows.length} summary, ${heartRows.length} heart, ${hrvRows.length} HRV records';
      });

      // Show results in a dialog
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Historical Data Retrieved'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: ListBody(
                  children: [
                    Text('📊 Summary Records: ${summaryRows.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (summaryRows.isNotEmpty) ...[
                      ...summaryRows.take(3).map((row) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(row.toString().length > 50 ? '${row.toString().substring(0, 50)}...' : row.toString(), 
                          style: const TextStyle(fontSize: 12)),
                      )),
                      if (summaryRows.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 4),
                          child: Text('...and ${summaryRows.length - 3} more', 
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ),
                    ],
                    const SizedBox(height: 8),
                    Text('❤️ Heart Rate Records: ${heartRows.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (heartRows.isNotEmpty) ...[
                      ...heartRows.take(3).map((row) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(row.toString().length > 50 ? '${row.toString().substring(0, 50)}...' : row.toString(), 
                          style: const TextStyle(fontSize: 12)),
                      )),
                      if (heartRows.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 4),
                          child: Text('...and ${heartRows.length - 3} more', 
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ),
                    ],
                    const SizedBox(height: 8),
                    Text('📈 HRV Records: ${hrvRows.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (hrvRows.isNotEmpty) ...[
                      ...hrvRows.take(3).map((row) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(row.toString().length > 50 ? '${row.toString().substring(0, 50)}...' : row.toString(), 
                          style: const TextStyle(fontSize: 12)),
                      )),
                      if (hrvRows.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 4),
                          child: Text('...and ${hrvRows.length - 3} more', 
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ),
                    ],
                    const SizedBox(height: 12),
                    const Text('💾 Data has been uploaded to cloud',
                      style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

    } catch (e) {
      setState(() {
        _statusMessage = 'History fetch error: $e';
      });
      
      // Show error dialog
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to fetch historical data:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  // Send history data to webhook
  Future<void> _sendHistoryDataToWebhook() async {
    if (_client == null || _connectedDevice == null) return;

    try {
      setState(() {
        _statusMessage = 'Fetching and sending HRV2 history to webhook...';
      });

      final now = DateTime.now();
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Fetch HRV2 history for today
      final hrv2Rows = await _client!.getAllDayHrv2Rows(
        _connectedDevice!,
        yy: now.year % 100,
        mm: now.month,
        dd: now.day,
      );

      if (hrv2Rows.isEmpty) {
        setState(() {
          _statusMessage = 'No HRV2 records available to send';
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️  No HRV2 records to send'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      await _sendHrv2ToWebhook(hrv2Rows, dateStr, isAutomatic: false);

      setState(() {
        _statusMessage = 'HRV2 history sent to webhook (${hrv2Rows.length} records)';
      });

      print('✅ HRV2 history data sent to webhook successfully');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ HRV2 history sent to webhook (${hrv2Rows.length} records)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

    } catch (e) {
      setState(() {
        _webhookErrorCount++;
        _lastWebhookStatus = '✗ HRV2 history failed';
        _lastWebhookError = e.toString();
        _lastWebhookTime = DateTime.now();
        _statusMessage = 'Failed to send HRV2 history: $e';
      });

      print('❌ Error sending HRV2 history data to webhook: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to send HRV2 history data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🏠🏠🏠 HC20HomePage build() called - user should see giant orange button! 🏠🏠🏠');
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    print('👤 User logged in: ${user != null} - Name: ${user?.name ?? "NOT LOGGED IN"}');
    
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.medical_services, size: 48, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'HFC App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user != null)
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            // Test Notification Menu Item - BRIGHT ORANGE
            Container(
              color: Colors.orange.shade100,
              child: ListTile(
                leading: const Icon(Icons.notifications_active, color: Colors.orange, size: 32),
                title: const Text(
                  'Test WhatsApp Notification',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: const Text('Send test disconnect alert'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TestNotificationPage(
                        deviceId: _connectedDevice?.id,
                        deviceName: _connectedDevice?.name,
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(thickness: 2),
            // Debug Info Section - Auth Token Status
            Container(
              color: Colors.blue.shade50,
              padding: const EdgeInsets.all(12),
              child: FutureBuilder<String?>(
                future: StorageService().getToken(),
                builder: (context, snapshot) {
                  final hasToken = snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasToken ? Icons.check_circle : Icons.error,
                            color: hasToken ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Auth Status',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (hasToken) ...[
                        Text(
                          '✅ Token Saved',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Token: ${snapshot.data!.substring(0, min(20, snapshot.data!.length))}...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Length: ${snapshot.data!.length} chars',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                          ),
                        ),
                      ] else ...[
                        Text(
                          '❌ No Token Found',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Please logout and login again',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const Divider(thickness: 2),
            // Device ID Status
            Container(
              color: Colors.green.shade50,
              padding: const EdgeInsets.all(12),
              child: FutureBuilder<String?>(
                future: StorageService().getSavedDeviceId(),
                builder: (context, snapshot) {
                  final hasDeviceId = snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasDeviceId ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                            color: hasDeviceId ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Saved Device',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (hasDeviceId) ...[
                        Text(
                          '✅ Device ID Saved',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${snapshot.data}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Auto-reconnect: Enabled',
                          style: TextStyle(
                            color: Colors.green.shade600,
                            fontSize: 10,
                          ),
                        ),
                      ] else ...[
                        Text(
                          '⚠️ No Device Saved',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Connect to a device first',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const Divider(thickness: 2),
            if (user != null)
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout'),
                onTap: () async {
                  Navigator.pop(context);
                  if (_isConnected) {
                    await _disconnect();
                  }
                  final authService = Provider.of<AuthService>(context, listen: false);
                  await authService.logout();
                },
              ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          // User info and logout button
          if (user != null)
            PopupMenuButton<String>(
              icon: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  user.name[0].toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              tooltip: user.name,
              onSelected: (value) async {
                if (value == 'logout') {
                  // Disconnect device first if connected
                  if (_isConnected) {
                    await _disconnect();
                  }
                  
                  // Show confirmation dialog
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    await authService.logout();
                  }
                } else if (value == 'profile') {
                  // Refresh profile
                  await authService.refreshProfile();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile refreshed')),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (user.email != null)
                        Text(
                          user.email!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Refresh Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    // Login status indicator
                    if (user != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Account Connected',
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // User and Device Info
                            Row(
                              children: [
                                // User Icon and Name
                                Icon(Icons.person, color: Colors.green.shade700, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  user.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                                // Divider
                                if (_savedDeviceId != null) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('|', style: TextStyle(color: Colors.grey.shade400)),
                                  ),
                                  // Device Icon and ID
                                  Icon(Icons.watch, color: Colors.blue.shade700, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _savedDeviceId!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'Courier',
                                        color: Colors.blue.shade900,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Status message with context
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _connectionState == ConnectionState.connected
                            ? Colors.green.shade50
                            : _connectionState == ConnectionState.reconnecting
                            ? Colors.orange.shade50
                            : _connectionState == ConnectionState.error
                            ? Colors.red.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _connectionState == ConnectionState.connected
                              ? Colors.green
                              : _connectionState == ConnectionState.reconnecting
                              ? Colors.orange
                              : _connectionState == ConnectionState.error
                              ? Colors.red
                              : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _connectionState == ConnectionState.connected
                              ? Colors.green.shade900
                              : _connectionState == ConnectionState.reconnecting
                              ? Colors.orange.shade900
                              : _connectionState == ConnectionState.error
                              ? Colors.red.shade900
                              : Colors.grey.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Connection status with icon
                    Row(
                      children: [
                        Icon(
                          _connectionState == ConnectionState.connected
                              ? Icons.bluetooth_connected
                              : _connectionState == ConnectionState.reconnecting
                              ? Icons.bluetooth_searching
                              : _connectionState == ConnectionState.connecting
                              ? Icons.bluetooth_searching
                              : Icons.bluetooth_disabled,
                          color: _connectionState == ConnectionState.connected
                              ? Colors.green
                              : _connectionState == ConnectionState.reconnecting
                              ? Colors.orange
                              : _connectionState == ConnectionState.connecting
                              ? Colors.blue
                              : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _connectionState == ConnectionState.connected
                                    ? '🟢 Connected'
                                    : _connectionState == ConnectionState.reconnecting
                                    ? '🟠 Reconnecting...'
                                    : _connectionState == ConnectionState.connecting
                                    ? '🔵 Connecting...'
                                    : _connectionState == ConnectionState.error
                                    ? '🔴 Connection Error'
                                    : '⚪ Disconnected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _connectionState == ConnectionState.connected
                                      ? Colors.green.shade700
                                      : _connectionState == ConnectionState.reconnecting
                                      ? Colors.orange.shade700
                                      : _connectionState == ConnectionState.error
                                      ? Colors.red.shade700
                                      : Colors.grey.shade700,
                                ),
                              ),
                              if (_isConnected && _lastDataReceived != null)
                                Text(
                                  'Last data: ${DateTime.now().difference(_lastDataReceived!).inSeconds}s ago',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Bluetooth and Internet Status
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _isBluetoothOn ? Colors.blue.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isBluetoothOn ? Colors.blue : Colors.red,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isBluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled,
                                  color: _isBluetoothOn ? Colors.blue : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _isBluetoothOn ? 'Bluetooth ON' : 'Bluetooth OFF',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _isBluetoothOn ? Colors.blue.shade900 : Colors.red.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _isInternetConnected ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isInternetConnected ? Colors.green : Colors.orange,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isInternetConnected ? Icons.wifi : Icons.wifi_off,
                                  color: _isInternetConnected ? Colors.green : Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _isInternetConnected ? 'Internet OK' : 'No Internet',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _isInternetConnected ? Colors.green.shade900 : Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isConnected && _isDeviceAssociated) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.link,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Device linked to your account',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Low Battery Warning (if battery <= 20%)
            if (_isLowBattery && _batteryLevel != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.battery_alert, color: Colors.red, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔋 Low Battery Warning!',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Device battery at $_batteryLevel%. Please charge your HC20 device soon.',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Manual Reconnect Button
            if (!_isConnected && _savedDeviceId != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Device Disconnected',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Tap below to manually reconnect',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isAutoReconnecting || _isReconnecting
                          ? null
                          : _manualReconnect,
                      icon: Icon(Icons.sync),
                      label: Text(
                        _isAutoReconnecting || _isReconnecting
                            ? 'Reconnecting...'
                            : 'Manual Reconnect',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade700,
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Battery Optimization Warning (if not disabled)
            if (!_isBatteryOptimizationDisabled) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.battery_alert, color: Colors.orange, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '⚠️ Battery Optimization Enabled',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'App requires unrestricted battery access for 24/7 monitoring',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _requestBatteryOptimizationExemption,
                      icon: Icon(Icons.settings_power),
                      label: Text('Disable Battery Optimization'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Cloud Sync Status Banner (Prominent)
            if (_isConnected) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Animated cloud icon
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(seconds: 2),
                      builder: (context, double value, child) {
                        return Transform.translate(
                          offset: Offset(0, -4 * (0.5 - (value - 0.5).abs())),
                          child: Icon(
                            Icons.cloud_upload,
                            color: Colors.white,
                            size: 32,
                          ),
                        );
                      },
                      onEnd: () {
                        // Restart animation
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '☁️ CLOUD SYNC ACTIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Data uploading to cloud: $_webhookSuccessCount successful',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          if (_lastWebhookTime != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Last sync: ${_lastWebhookTime!.hour}:${_lastWebhookTime!.minute.toString().padLeft(2, '0')}:${_lastWebhookTime!.second.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Success indicator with pulse animation
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_webhookSuccessCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Control buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isScanning || _isConnected ? null : _startScanning,
                    child: Text(_isScanning ? 'Scanning...' : 'Scan Devices'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected ? _disconnect : null,
                    child: const Text('Disconnect'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected ? _getHistoryData : null,
                    child: const Text('Get History'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected ? _sendHistoryDataToWebhook : null,
                    icon: const Icon(Icons.cloud_upload, size: 18),
                    label: const Text('Send History'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AllDataPage(
                                  client: _client!,
                                  device: _connectedDevice!,
                                ),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.view_list),
                    label: const Text('View All Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Webhook status section
            if (_isConnected) ...[
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time Sync Status
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.purple.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Time Sync Status',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.purple.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(_lastTimeSyncStatus, 
                              style: TextStyle(
                                color: _lastTimeSyncStatus.startsWith('✅') 
                                  ? Colors.green 
                                  : _lastTimeSyncStatus.startsWith('⚠️')
                                    ? Colors.orange
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              )),
                          ),
                          if (_lastTimeSyncTime != null) ...[
                            Text(
                              '${_lastTimeSyncTime!.hour}:${_lastTimeSyncTime!.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // HRV Auto-Refresh Status
                      Row(
                        children: [
                          Icon(Icons.auto_graph, color: Colors.purple.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'HRV Auto-Refresh',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.purple.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Every 6 hours → Nitto Cloud',
                                  style: TextStyle(
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_lastHrvRefresh != null)
                                  Text(
                                    'Last: ${_lastHrvRefresh!.hour}:${_lastHrvRefresh!.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  )
                                else
                                  const Text(
                                    'Waiting for first fetch...',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, size: 16, color: Colors.purple.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Active',
                                  style: TextStyle(
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Backend Webhook Status
                      Row(
                        children: [
                          Icon(Icons.cloud_upload, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Backend Webhook Status',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('✅ Success: $_webhookSuccessCount', 
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('❌ Errors: $_webhookErrorCount',
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_lastWebhookStatus, 
                                style: TextStyle(
                                  color: _lastWebhookStatus.startsWith('✓') ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                )),
                              if (_lastWebhookTime != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${_lastWebhookTime!.hour}:${_lastWebhookTime!.minute.toString().padLeft(2, '0')}:${_lastWebhookTime!.second.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.link, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _webhookUrl,
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_lastWebhookError.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Last Error:',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _lastWebhookError,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _testWebhook,
                          icon: const Icon(Icons.wifi_tethering, size: 18),
                          label: const Text('Test Webhook Connection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _sendStressWebhook,
                          icon: const Icon(Icons.warning_amber_rounded, size: 20),
                          label: const Text('I\'m Feeling Stress'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Real-time data section
            if (_isConnected) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Real-time Data',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _buildDataRow('Heart Rate', _heartRate?.toString(), 'bpm'),
                      _buildDataRow('SpO2', _spo2?.toString(), '%'),
                      _buildDataRow('Blood Pressure', 
                          _bloodPressure != null ? '${_bloodPressure![0]}/${_bloodPressure![1]}' : null, 
                          'mmHg'),
                      _buildDataRow('Temperature', _temperature?.toStringAsFixed(1), '°C'),
                      _buildDataRow('Steps', _steps?.toString(), ''),
                      _buildDataRow('Battery', _batteryLevel?.toString(), '%'),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Discovered devices
            if (_discoveredDevices.isNotEmpty) ...[
              Text(
                'Discovered Devices',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _discoveredDevices.length,
                itemBuilder: (context, index) {
                  final device = _discoveredDevices[index];
                  return Card(
                    child: ListTile(
                      title: Text(device.name),
                      subtitle: Text(device.id),
                      trailing: ElevatedButton(
                        onPressed: _isConnected ? null : () => _connectToDevice(device),
                        child: const Text('Connect'),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String? value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value != null ? '$value $unit' : 'N/A',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: value != null ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnalyticTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
