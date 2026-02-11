import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:hc20/hc20.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'pages/all_data_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'services/background_sync_service.dart';
import 'services/app_keepalive_service.dart';
import 'services/main_engine_keepalive_service.dart';
import 'services/background_service_manager.dart';
import 'services/hc20_service.dart';
import 'services/health_data_service.dart';
import 'services/device_status_service.dart';
import 'services/settings_service.dart';
import 'services/hc20_data_service.dart';
import 'services/hc20_connection_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/widgets/bottom_navigation_bar.dart';
import 'widgets/hc20_status_widgets.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/vitals_screen.dart';
import 'ui/screens/clinical_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/profile_screen.dart';
import 'ui/screens/connectivity_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MainEngineKeepAliveService
      .initialize(); // Main Engine Keep-Alive (key for background HC20)
  await _checkExactAlarmPermission(); // Check SCHEDULE_EXACT_ALARM (Android 12+)
  await AppKeepaliveService.initialize(); // AlarmManager for reliable keepalive
  await AppKeepaliveService.startPeriodicKeepalive();
  // Save sync intervals to SharedPreferences so native Android code can read them
  await AppKeepaliveService.saveIntervalsToNative(
    realtimeInterval: SyncScheduler.realtimeInterval,
    reconnectInterval: SyncScheduler.reconnectInterval,
  );
  print(
      '✅ AlarmManager initialized - app will auto-restart every 5 min if closed');
  await BackgroundSyncService.initialize(); // WorkManager for background tasks
  print('✅ WorkManager initialized - secondary keepalive mechanism');
  await _testAlarmScheduling();
  await AppKeepaliveService.markAppActive();

  final authService = AuthService();
  final hc20Service = HC20Service();
  await Future.delayed(const Duration(seconds: 1));

  // Initialize data management services
  print('🔧 Initializing data management services...');
  final healthDataService = HealthDataService();
  final deviceStatusService = DeviceStatusService();
  final settingsService = SettingsService();
  final hc20DataService = HC20DataService();
  final hc20ConnectionManager = HC20ConnectionManager();

  // Load persisted data
  await healthDataService.loadFromStorage();
  await deviceStatusService.loadFromStorage();
  await settingsService.loadFromStorage();
  await hc20DataService.loadSyncTimestamps();
  await hc20ConnectionManager.loadSavedDevice();
  print('✅ Data management services initialized and loaded from storage');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: hc20Service),
        ChangeNotifierProvider.value(value: healthDataService),
        ChangeNotifierProvider.value(value: deviceStatusService),
        ChangeNotifierProvider.value(value: settingsService),
        ChangeNotifierProvider.value(value: hc20DataService),
        ChangeNotifierProvider.value(value: hc20ConnectionManager),
      ],
      child: const MyApp(),
    ),
  );
}

/// Check and request SCHEDULE_EXACT_ALARM permission on Android 12+
Future<void> _checkExactAlarmPermission() async {
  if (!Platform.isAndroid) return;
  const channel = MethodChannel('com.hfc.app/background');
  try {
    final bool canSchedule =
        await channel.invokeMethod('checkExactAlarmPermission');
    if (!canSchedule) {
      print('⚠️ CRITICAL: SCHEDULE_EXACT_ALARM permission NOT granted!');
      print('   Requesting permission from user...');
      await channel.invokeMethod('requestExactAlarmPermission');
      await Future.delayed(const Duration(seconds: 2));
      final bool recheckCanSchedule =
          await channel.invokeMethod('checkExactAlarmPermission');
      if (recheckCanSchedule) {
        print('✅ SCHEDULE_EXACT_ALARM permission granted!');
      } else {
        print('⚠️ SCHEDULE_EXACT_ALARM permission still not granted');
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
    final Map<dynamic, dynamic> result =
        await channel.invokeMethod('testAlarmScheduling');
    print('🧪 Alarm Scheduling Test:');
    print(
        '   Keepalive alarm: ${result['keepaliveExists'] ? "✅ SCHEDULED" : "❌ NOT FOUND"}');
    print(
        '   WorkManager alarm: ${result['workExists'] ? "✅ SCHEDULED" : "❌ NOT FOUND"}');
    print(
        '   Can schedule exact: ${result['canScheduleExact'] ? "✅ YES" : "❌ NO"}');
    if (!result['keepaliveExists'] || !result['workExists']) {
      print('⚠️ WARNING: Some alarms are not scheduled!');
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
          useMaterial3: true),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/clinical': (context) => const ClinicalScreen(),
        '/vitals': (context) => const VitalsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/connectivity': (context) => const ConnectivityScreen(),
      },
      home: Consumer<AuthService>(
        builder: (context, authService, child) {
          if (!authService.isAuthenticated) return const LoginPage();
          return const MainScaffold();
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

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error
} // Connection state enum

class ConnectionEvent {
  // Connection event for history tracking
  final DateTime timestamp;
  final String event;
  final String? reason;
  final String? deviceId;
  ConnectionEvent(
      {required this.timestamp,
      required this.event,
      this.reason,
      this.deviceId});
  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

enum DisconnectReason {
  bluetoothIssue,
  deviceNotFound,
  noInternet,
  lowBattery
} // Disconnect notification reasons

String getDisconnectMessage(DisconnectReason reason) {
  switch (reason) {
    case DisconnectReason.bluetoothIssue:
      return 'Bluetooth Issue: Please enable Bluetooth and grant permissions';
    case DisconnectReason.deviceNotFound:
      return 'Device Not Found: HC20 is out of range or powered off';
    case DisconnectReason.noInternet:
      return 'No Internet Connection: Unable to sync data to server';
    case DisconnectReason.lowBattery:
      return 'Low Battery Warning: HC20 battery is below 20%';
  }
}

// Unified timer system that replaces 8 separate timers with single 1-minute ticker
class SyncScheduler {
  Timer? _masterTimer;
  int _tickCount = 0;
  final DateTime? Function() getLastRealtimeSync;
  final DateTime? Function() getLastHistorySync;

  // Configurable sync intervals (in minutes) - AGGRESSIVE SYNC for testing
  static const int realtimeInterval = 15;
  static const int historyInterval = 60;
  static const int reconnectInterval = 5;

  final Function onRealtimeSync;
  final Function onHistorySync;
  final Function onReconnectScan;

  SyncScheduler({
    required this.onRealtimeSync,
    required this.onHistorySync,
    required this.onReconnectScan,
    required this.getLastRealtimeSync,
    required this.getLastHistorySync,
  });

  void start() {
    _masterTimer?.cancel();
    final lastRealtimeSync = getLastRealtimeSync();
    if (lastRealtimeSync != null) {
      final minutesSinceLastSync =
          DateTime.now().difference(lastRealtimeSync).inMinutes;
      _tickCount = minutesSinceLastSync;
      print(
          '🔄 [Scheduler] Restored _tickCount to: $_tickCount, next sync in: ${realtimeInterval - (minutesSinceLastSync % realtimeInterval)} min');
    } else {
      _tickCount = 0;
      print('🆕 [Scheduler] First sync ever - starting _tickCount from 0');
    }
    print(
        '⏰ Starting Scheduler - Realtime: ${realtimeInterval}min, History: ${historyInterval}min, Reconnect: ${reconnectInterval}min');
    _masterTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _tickCount++;
      if (kDebugMode) print('⏰ [Scheduler] Tick #$_tickCount');
      if (_tickCount % realtimeInterval == 0) {
        print('📊 Realtime sync triggered');
        onRealtimeSync();
      }
      if (_tickCount % historyInterval == 0) {
        print('📚 History sync triggered');
        onHistorySync();
      }
      if (_tickCount % reconnectInterval == 0) onReconnectScan();
    });
    print('✅ Unified Sync Scheduler started');
  }

  void stop() {
    _masterTimer?.cancel();
    _masterTimer = null;
    _tickCount = 0;
    print('🛑 Scheduler stopped');
  }

  void reset() {
    _tickCount = 0;
    print('🔄 Scheduler tick counter reset');
  }

  int get tickCount => _tickCount;
  bool get isRunning => _masterTimer != null && _masterTimer!.isActive;
}

class _HC20HomePageState extends State<HC20HomePage>
    with WidgetsBindingObserver {
  Hc20Client? _client;
  Hc20Device? _connectedDevice;
  bool _isScanning = false;
  bool _isConnected = false;
  ConnectionState _connectionState = ConnectionState.disconnected;
  List<Hc20Device> _discoveredDevices = [];
  String _statusMessage = 'Click "Start Scanning" to search for HC20 devices';
  bool _isBluetoothOn = true;
  StreamSubscription? _bluetoothStateSubscription;
  String _lastTimeSyncStatus = 'Not synced yet';
  DateTime? _lastTimeSyncTime;
  int? _heartRate;
  int? _spo2;
  List<int>? _bloodPressure;
  double? _temperature;
  int? _batteryLevel;
  StreamSubscription? _realtimeSubscription;
  DateTime? _lastDataReceived;
  SyncScheduler? _syncScheduler;
  DateTime? _lastRealtimeSync;
  DateTime? _lastHistorySync;
  DateTime? _lastHistorySyncDate;
  String? _savedDeviceId;
  bool _isAutoReconnecting = false;
  DateTime? _lastHrvRefresh;
  bool _isReconnecting = false;
  bool _isBatteryOptimizationDisabled = false;
  final ApiService _apiService = ApiService();
  bool _isDeviceAssociated = false;
  List<ConnectionEvent> _connectionHistory = [];
  Map<String, int> _disconnectReasons = {};
  bool _isLowBattery = false;
  bool _lowBatteryAlertSent = false;
  Timer? _internetMonitorTimer;
  Timer? _autoReconnectScanner;
  String? _deviceManufacturer;
  String? _deviceModel;
  String? _deviceOsVersion;
  String? _deviceId;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;
  final bool _bgPluginEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Defer heavy initialization to avoid blocking main thread (fixes "App Not Responding")
    Future.microtask(() async {
      // Load timestamps first (fast, from memory)
      _loadSyncTimestamps();

      // Initialize notifications (can be async)
      _initializeNotifications();

      // Load device info (I/O operation)
      _loadDeviceInfo();

      // Background services (only if enabled)
      if (_bgPluginEnabled) BackgroundServiceManager.instance.initialize();

      // These can run in parallel
      await Future.wait([
        _enableBackgroundExecution(),
        _checkAndShowBatteryOptimizationDialog(),
        _checkBluetoothState(),
      ]);

      // Load saved device last (may trigger connection)
      _loadSavedDevice();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final hc20Service = Provider.of<HC20Service>(context, listen: false);
        hc20Service.onRequestDataSync =
            ({bool forceRefresh = false, bool isStressAlert = false}) async {
          await _handleRealtimeSync(
              forceRefresh: forceRefresh, isStressAlert: isStressAlert);
        };
        print('✅ [Init] HC20Service callback registered');
      } catch (e) {
        print('⚠️ [Init] Could not register HC20Service callback: $e');
      }

      try {
        final connectionManager =
            Provider.of<HC20ConnectionManager>(context, listen: false);
        connectionManager.setCallbacks(HC20ConnectionCallbacks(
          onStateChanged: (state, message) {
            setState(() {
              _statusMessage = message;
              if (state == HC20ConnectionState.connected) {
                _isConnected = true;
                _isReconnecting = false;
              } else if (state == HC20ConnectionState.disconnected ||
                  state == HC20ConnectionState.error) _isConnected = false;
              _isScanning = connectionManager.isScanning;
            });
          },
          onDevicesDiscovered: (devices) {
            setState(() {
              _discoveredDevices = devices;
            });
          },
          onConnected: (device) async {
            setState(() {
              _connectedDevice = device;
              _isConnected = true;
              _isReconnecting = false;
              _connectionState = ConnectionState.connected;
            });
            print('✅ [Callback] Device connected: ${device.id}');
            _client ??= connectionManager.client;
            try {
              final hc20Service =
                  Provider.of<HC20Service>(context, listen: false);
              hc20Service.updateConnectionState(
                  connected: true,
                  device: device,
                  client: connectionManager.client);
            } catch (e) {
              print('⚠️ Could not update HC20Service: $e');
            }
            _addConnectionEvent(
                event: _connectionHistory.isEmpty ? 'connected' : 'reconnected',
                deviceId: device.id);
            if (_syncScheduler == null) {
              print('🔧 [Callback] Initializing new sync scheduler...');
              _initializeSyncScheduler();
            }
            await _performInitialSyncsIfNeeded();
            if (_syncScheduler != null && !_syncScheduler!.isRunning) {
              _syncScheduler?.start();
              print('✅ [Callback] Unified sync scheduler started');
            }
            final authService =
                Provider.of<AuthService>(context, listen: false);
            await _startNativeBackgroundServices(
                device, authService.currentUser?.phone);
            _showConnectionRestoredNotification();
          },
          onDeviceAssociation: (device) async {
            await _associateDeviceWithUser(device);
          },
          onInitializeScheduler: () async {
            // Only initialize if not already running (onConnected handles the start)
            if (_syncScheduler == null) {
              print(
                  '🔧 [Callback] onInitializeScheduler - creating new scheduler');
              _initializeSyncScheduler();
            } else {
              print(
                  '✅ [Callback] onInitializeScheduler - scheduler already exists, skipping');
            }
          },
          onDisconnected: (reason) async {
            setState(() {
              _isConnected = false;
              _connectedDevice = null;
            });
            if (reason == HC20DisconnectReason.manual) return;
            DisconnectReason mappedReason;
            switch (reason) {
              case HC20DisconnectReason.bluetoothOff:
              case HC20DisconnectReason.gattError:
                mappedReason = DisconnectReason.bluetoothIssue;
                break;
              case HC20DisconnectReason.maxRetriesReached:
              case HC20DisconnectReason.timeout:
              case HC20DisconnectReason.deviceNotFound:
                mappedReason = DisconnectReason.deviceNotFound;
                break;
              case HC20DisconnectReason.noInternet:
                mappedReason = DisconnectReason.noInternet;
                break;
              default:
                mappedReason = DisconnectReason.deviceNotFound;
            }
            _showDisconnectNotification(mappedReason);
          },
          onDeviceForgotten: () async {
            // Reset sync timestamps when device is forgotten
            setState(() {
              _lastRealtimeSync = null;
              _lastHistorySync = null;
              _lastHistorySyncDate = null;
              _savedDeviceId = null;
            });
            print('🗑️ [Callback] Sync timestamps reset after device forgotten');
          },
        ));
        print('✅ [Init] HC20ConnectionManager callbacks configured');
      } catch (e) {
        print(
            '⚠️ [Init] Could not configure HC20ConnectionManager callbacks: $e');
      }
    });
  }

  Future<void> _loadSavedDevice() async {
    try {
      final deviceId = await StorageService().getSavedDeviceId();
      if (deviceId != null && deviceId.isNotEmpty) {
        setState(() {
          _savedDeviceId = deviceId;
        });
        print(
            '🔄 [Startup] Saved device found: $deviceId, starting auto-reconnect...');
        _startAutoReconnectScanner();
      } else {
        print('ℹ️ [Startup] No saved device - first time setup required');
      }
    } catch (e) {
      print('⚠️ [Startup] Error loading saved device: $e');
    }
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        setState(() {
          _deviceManufacturer = androidInfo.manufacturer;
          _deviceModel = androidInfo.model;
          _deviceOsVersion = 'Android ${androidInfo.version.release}';
          _deviceId = androidInfo.id;
        });
        print(
            '📱 Device: ${androidInfo.manufacturer} ${androidInfo.model}, Android ${androidInfo.version.release}');
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        setState(() {
          _deviceManufacturer = 'Apple';
          _deviceModel = iosInfo.utsname.machine;
          _deviceOsVersion = 'iOS ${iosInfo.systemVersion}';
          _deviceId = iosInfo.identifierForVendor ?? 'unknown';
        });
        print(
            '📱 Device: Apple ${iosInfo.utsname.machine}, iOS ${iosInfo.systemVersion}');
      }
    } catch (e) {
      print('⚠️ Error loading device info: $e');
      setState(() {
        _deviceManufacturer = 'Unknown';
        _deviceModel = 'Unknown';
        _deviceOsVersion = Platform.isAndroid ? 'Android' : 'iOS';
        _deviceId = 'unknown';
      });
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true);
      const initSettings =
          InitializationSettings(android: androidSettings, iOS: iosSettings);
      await _notificationsPlugin.initialize(initSettings,
          onDidReceiveNotificationResponse: (response) {
        print('📱 Notification tapped: ${response.payload}');
      });
      if (Platform.isAndroid) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
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

  Future<void> _showDisconnectNotification(DisconnectReason reason) async {
    if (!_notificationsInitialized) return;
    final message = getDisconnectMessage(reason);
    print('🔔 [Notification] $message');
    final now = DateTime.now();
    final lastNotificationKey = 'last_notification_${reason.name}';
    final prefs = await SharedPreferences.getInstance();
    final lastNotificationStr = prefs.getString(lastNotificationKey);
    if (lastNotificationStr != null) {
      final lastNotification = DateTime.parse(lastNotificationStr);
      if (now.difference(lastNotification).inMinutes < 5) {
        print('⏭️ [Notification] Skipping - spam prevention');
        return;
      }
    }
    await prefs.setString(lastNotificationKey, now.toIso8601String());
    const androidDetails = AndroidNotificationDetails(
        'device_alerts', 'Device Alerts',
        channelDescription: 'Notifications for device connection issues',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFFF6B6B),
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(''));
    const iosDetails = DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true);
    const notificationDetails =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _notificationsPlugin.show(reason.index + 1000,
        'HC20 Connection Alert', message, notificationDetails,
        payload: reason.name);
    print('📬 Disconnect notification shown: $message');

    setState(() {
      _statusMessage = message;
    });
  }

  Future<void> _showLowBatteryNotification(int batteryLevel) async {
    if (!_notificationsInitialized) return;
    const androidDetails = AndroidNotificationDetails(
        'battery_alerts', 'Battery Alerts',
        channelDescription: 'Notifications for low device battery',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFFF6B6B),
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(''));
    const iosDetails = DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true);
    const notificationDetails =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _notificationsPlugin.show(
        4,
        '🔋 Low Battery Warning',
        'HC20 device battery is at $batteryLevel%. Please charge your device soon.',
        notificationDetails,
        payload: 'low_battery:$batteryLevel');
    print('📬 Low battery notification shown: $batteryLevel%');
  }

  Future<void> _showConnectionRestoredNotification() async {
    if (!_notificationsInitialized) return;
    await _cancelAllNotifications();
    await Future.delayed(const Duration(milliseconds: 100));
    print('📬 All notifications cancelled on connection restored');
  }

  Future<void> _cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> _enableBackgroundExecution() async {
    try {
      const platform = MethodChannel('com.hfc.app/background');
      await platform.invokeMethod('enableBackgroundExecution');
      print('✅ Background execution enabled');
    } catch (e) {
      print('⚠️ Could not enable background execution: $e');
    }
  }

  Future<void> _checkAndShowBatteryOptimizationDialog() async {
    try {
      const platform = MethodChannel('com.hfc.app/background');
      final isDisabled =
          await platform.invokeMethod('isBatteryOptimizationDisabled');
      setState(() {
        _isBatteryOptimizationDisabled = isDisabled;
      });
      if (isDisabled) {
        print('✅ Battery optimization already disabled');
        setState(() {
          _statusMessage = '✅ Ready to scan for devices';
        });
      } else {
        print(
            '⚠️ Battery optimization is enabled - showing permission dialog...');
        setState(() {
          _statusMessage = '⚠️ Battery optimization permission required';
        });

        Future.delayed(Duration(milliseconds: 500), () {
          _showBatteryOptimizationPermissionDialog();
        });
      }
    } catch (e) {
      print('⚠️ Could not check battery optimization: $e');
    }
  }

  void _showBatteryOptimizationPermissionDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(children: [
            Icon(Icons.battery_alert, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
                child: Text('Allow Battery Optimization',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ]),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'This app needs unrestricted battery access to work properly in background.',
                    style: TextStyle(fontSize: 15, height: 1.4)),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue.shade700, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                              child: Text('What happens next:',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900))),
                        ]),
                        SizedBox(height: 8),
                        Text(
                            '1. Tap "Allow" button below\n2. Find "HFC App" in the list\n3. Select "No Restriction" or "Allow"',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade900,
                                height: 1.5)),
                      ]),
                ),
              ]),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _requestBatteryOptimizationExemption();
                },
                icon: Icon(Icons.battery_charging_full, size: 24),
                label: Text('Allow Battery Access',
                    style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      const platform = MethodChannel('com.hfc.app/background');
      print('🔋 Opening battery optimization settings...');
      await platform.invokeMethod('requestBatteryOptimizationExemption');
      setState(() {
        _statusMessage = 'Please disable battery optimization for this app';
      });
      await Future.delayed(Duration(seconds: 3));
      await _checkBatteryOptimizationStatus();
    } catch (e) {
      print('⚠️ Could not request battery optimization exemption: $e');
    }
  }

  Future<void> _checkBatteryOptimizationStatus() async {
    try {
      const platform = MethodChannel('com.hfc.app/background');
      final isDisabled =
          await platform.invokeMethod('isBatteryOptimizationDisabled');
      setState(() {
        _isBatteryOptimizationDisabled = isDisabled;
        _statusMessage = isDisabled
            ? '✅ Ready to scan for devices'
            : '⚠️ Battery optimization must be disabled. Tap "Disable Battery Optimization" button.';
      });
      print(_isBatteryOptimizationDisabled
          ? '✅ Battery optimization disabled'
          : '⚠️ Battery optimization still enabled');
    } catch (e) {
      print('⚠️ Could not check battery optimization status: $e');
    }
  }

  Future<void> _checkBluetoothState() async {
    try {
      final bluetoothStatus = await Permission.bluetooth.serviceStatus;
      final wasBluetoothOn = _isBluetoothOn;
      final currentBluetoothState = bluetoothStatus.isEnabled;
      if (wasBluetoothOn != currentBluetoothState) {
        setState(() {
          _isBluetoothOn = currentBluetoothState;
        });
        print('📱 Bluetooth: ${_isBluetoothOn ? "ON" : "OFF"} (state changed)');
      } else {
        _isBluetoothOn = currentBluetoothState;
      }
      if (wasBluetoothOn && !_isBluetoothOn) {
        print('🔴 Bluetooth turned OFF - showing notification');
        _showDisconnectNotification(DisconnectReason.bluetoothIssue);
        if (_isConnected) {
          print('❌ Bluetooth OFF while connected - handling disconnection');
          setState(() {
            _isConnected = false;
            _connectionState = ConnectionState.error;
            _statusMessage = 'Bluetooth turned off';
          });
          await _handleDisconnection();
        }
      }
      if (!wasBluetoothOn && _isBluetoothOn) {
        print('✅ Bluetooth turned ON - cancelling notification');
        await _notificationsPlugin.cancel(1);
        print('🔄 Bluetooth restored');
      }
    } catch (e) {
      print('⚠️ Error checking Bluetooth status: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveSyncTimestamps();
    _syncScheduler?.stop();
    print('🛑 [Disconnect] Stopping sync scheduler by dispose');
    _realtimeSubscription?.cancel();
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
        _stopMainEngineKeepAlive();
        if (_isConnected &&
            _syncScheduler != null &&
            !_syncScheduler!.isRunning) {
          print('▶️ Resuming unified scheduler - app in foreground');
          _syncScheduler?.start();
        }
        _checkBatteryOptimizationStatus();
        if (!_isConnected &&
            _savedDeviceId != null &&
            _savedDeviceId!.isNotEmpty) {
          print(
              '🔍 [Resume] Device disconnected, ensuring auto-reconnect scanner is active...');
          _isReconnecting = false;
          _isAutoReconnecting = false;
          final connectionManager =
              Provider.of<HC20ConnectionManager>(context, listen: false);
          if (!connectionManager.isCleaningUp) _startAutoReconnectScanner();
        }

        Future.delayed(Duration(seconds: 1), () {
          if (!_isBatteryOptimizationDisabled && mounted)
            _showBatteryOptimizationPermissionDialog();
        });
        break;
      case AppLifecycleState.paused:
        print('⏸️ App paused - entering background mode');
        print('ℹ️ Scheduler continues in background via keep-alive');
        _startMainEngineKeepAlive(); // Only call here, not in hidden state
        break;
      case AppLifecycleState.inactive:
        print('💤 App inactive');
        break;
      case AppLifecycleState.detached:
        print('🔌 App detached - ForegroundService keeps us alive!');
        print('ℹ️ Scheduler protected by ForegroundService');
        break;
      case AppLifecycleState.hidden:
        print('🙈 App hidden');
        // Don't call _startMainEngineKeepAlive() here - it will be called in paused state
        break;
    }
  }

  Future<void> _startMainEngineKeepAlive() async {
    if (!_isConnected || _connectedDevice == null) {
      print('ℹ️ [KeepAlive] Not connected to device - skipping');
      return;
    }
    print('🚀 [KeepAlive] Starting main engine keep-alive mode...');
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
      if (success)
        print('✅ [KeepAlive] Main engine keep-alive ACTIVE!');
      else
        print('⚠️ [KeepAlive] Failed to start keep-alive mode');
    } catch (e) {
      print('❌ [KeepAlive] Error starting keep-alive: $e');
    }
  }

  Future<void> _stopMainEngineKeepAlive() async {
    if (!MainEngineKeepAliveService.isKeepAliveActive) return;
    print('🛑 [KeepAlive] Stopping main engine keep-alive mode...');
    try {
      await MainEngineKeepAliveService.stopKeepAlive();
      print('✅ [KeepAlive] Keep-alive stopped - app in foreground');
    } catch (e) {
      print('⚠️ [KeepAlive] Error stopping keep-alive: $e');
    }
  }

  Future<void> _saveSyncTimestamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastRealtimeSync != null)
        await prefs.setString(
            'last_realtime_sync', _lastRealtimeSync!.toIso8601String());
      if (_lastHistorySync != null)
        await prefs.setString(
            'last_history_sync', _lastHistorySync!.toIso8601String());
      if (_lastHistorySyncDate != null)
        await prefs.setString(
            'last_history_sync_date', _lastHistorySyncDate!.toIso8601String());
      if (_lastDataReceived != null)
        await prefs.setString(
            'last_data_received', _lastDataReceived!.toIso8601String());
      if (_heartRate != null) await prefs.setInt('heart_rate', _heartRate!);
      if (_spo2 != null) await prefs.setInt('spo2', _spo2!);
      if (_bloodPressure != null)
        await prefs.setString('blood_pressure', _bloodPressure!.join(','));
      if (_temperature != null)
        await prefs.setDouble('temperature', _temperature!);
      if (_batteryLevel != null)
        await prefs.setInt('battery_level', _batteryLevel!);

      if (kDebugMode)
        print(
            '💾 [Persistence] Sync timestamps saved - realtime: $_lastRealtimeSync, history: $_lastHistorySync');
    } catch (e) {
      print('❌ [Persistence] Error saving timestamps: $e');
    }
  }

  Future<void> _loadSyncTimestamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final realtimeStr = prefs.getString('last_realtime_sync');
      _lastRealtimeSync = realtimeStr != null ? DateTime.parse(realtimeStr) : null;
      final historyStr = prefs.getString('last_history_sync');
      _lastHistorySync = historyStr != null ? DateTime.parse(historyStr) : null;
      final historySyncDateStr = prefs.getString('last_history_sync_date');
      _lastHistorySyncDate = historySyncDateStr != null ? DateTime.parse(historySyncDateStr) : null;
      final dataReceivedStr = prefs.getString('last_data_received');
      if (dataReceivedStr != null)
        _lastDataReceived = DateTime.parse(dataReceivedStr);
      _heartRate = prefs.getInt('heart_rate');
      _spo2 = prefs.getInt('spo2');
      final bpStr = prefs.getString('blood_pressure');
      if (bpStr != null && bpStr.isNotEmpty)
        _bloodPressure = bpStr.split(',').map((e) => int.parse(e)).toList();
      _temperature = prefs.getDouble('temperature');
      _batteryLevel = prefs.getInt('battery_level');
      if (kDebugMode)
        print(
            '📂 [Persistence] Loaded - realtime: $_lastRealtimeSync, history: $_lastHistorySync');
      setState(() {});
    } catch (e) {
      print('❌ [Persistence] Error loading timestamps: $e');
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  void _initializeSyncScheduler() {
    // Don't reinitialize if already running
    if (_syncScheduler != null && _syncScheduler!.isRunning) {
      print('✅ Sync scheduler already running, skipping reinitialization');
      return;
    }
    _syncScheduler?.stop();
    print('🔧 [Scheduler] Creating new sync scheduler...');
    _syncScheduler = SyncScheduler(
      onRealtimeSync: _handleRealtimeSync,
      onHistorySync: _handleHistorySync,
      onReconnectScan: _handleReconnectScan,
      getLastRealtimeSync: () => _lastRealtimeSync,
      getLastHistorySync: () => _lastHistorySync,
    );
    print('✅ Sync scheduler initialized (not started yet)');
  }

  Future<void> _handleRealtimeSync(
      {bool forceRefresh = false, bool isStressAlert = false}) async {
    if (!_isConnected || _connectedDevice == null) {
      print('⏭️ [RealtimeSync] Skipping - device not connected');
      if (_lastDataReceived != null && !forceRefresh) {
        final timeSinceLastData = DateTime.now().difference(_lastDataReceived!);
        if (timeSinceLastData.inMinutes >= SyncScheduler.realtimeInterval) {
          print(
              '⚠️ [RealtimeSync] No data for ${SyncScheduler.realtimeInterval} minutes - starting reconnection');
          await _handleDisconnection();
        }
      }
      return;
    }
    if (!forceRefresh && !isStressAlert && _lastRealtimeSync != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastRealtimeSync!);
      if (timeSinceLastSync.inMinutes < SyncScheduler.realtimeInterval - 1) {
        print(
            '⏭️ [RealtimeSync] Skipping - last sync was ${timeSinceLastSync.inMinutes}m ago');
        return;
      }
    }
    try {
      final syncType = isStressAlert
          ? 'STRESS ALERT'
          : (forceRefresh ? 'MANUAL REFRESH' : 'AUTO SYNC');
      print(
          '📊 [RealtimeSync] $syncType - Fetching fresh vitals from device...');
      final fetchStartTime = DateTime.now();
      final realtimeData =
          await _client!.realtimeV2(_connectedDevice!).first.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏰ [RealtimeSync] Timeout');
          throw TimeoutException('Realtime data fetch timeout');
        },
      );
      print(
          '✅ [RealtimeSync] Fresh data received in ${DateTime.now().difference(fetchStartTime).inSeconds}s');
      _lastDataReceived = DateTime.now();

      // Extract vitals from realtimeData
      int? heartRate = realtimeData.heart != null && realtimeData.heart! > 0
          ? realtimeData.heart
          : null;
      int? spo2 = realtimeData.spo2 != null && realtimeData.spo2! > 0
          ? realtimeData.spo2
          : null;
      List<int>? bloodPressure = (realtimeData.bp != null &&
              realtimeData.bp!.isNotEmpty &&
              realtimeData.bp![0] > 0)
          ? realtimeData.bp
          : null;
      double? temperature = (realtimeData.temperature != null &&
              realtimeData.temperature!.isNotEmpty)
          ? realtimeData.temperature![0] / 100.0
          : null;
      int? batteryLevel = realtimeData.battery?.percent;
      int? steps =
          (realtimeData.basicData != null && realtimeData.basicData!.isNotEmpty)
              ? realtimeData.basicData![0]
              : null;
      int? calories =
          (realtimeData.basicData != null && realtimeData.basicData!.length > 1)
              ? realtimeData.basicData![1]
              : null;
      int? distance =
          (realtimeData.basicData != null && realtimeData.basicData!.length > 2)
              ? realtimeData.basicData![2]
              : null;
      int? rri = realtimeData.rri;
      int? barometricPressure = realtimeData.baro;
      int? wearStatus = realtimeData.wear;
      List<int>? sleepData = realtimeData.sleep;
      List<double>? temperatureArray;
      if (realtimeData.temperature != null &&
          realtimeData.temperature!.length >= 3) {
        temperatureArray = [
          realtimeData.temperature![0] / 100.0,
          realtimeData.temperature![1] / 100.0,
          realtimeData.temperature![2] / 100.0
        ];
      }
      int? mentalStress = realtimeData.hrv2Metrics?.mentStress;
      int? fatigueLevel = realtimeData.hrv2Metrics?.fatigueLevel;
      int? stressResistance = realtimeData.hrv2Metrics?.stressResistance;
      int? regulationAbility = realtimeData.hrv2Metrics?.regulationAbility;
      int? sdnn = realtimeData.hrvMetrics?.sdnn;
      int? totalPower = realtimeData.hrvMetrics?.tp;
      int? lowFrequency = realtimeData.hrvMetrics?.lf;
      int? highFrequency = realtimeData.hrvMetrics?.hf;
      int? veryLowFrequency = realtimeData.hrvMetrics?.vlf;

      // 1. Update HealthDataService
      final healthService =
          Provider.of<HealthDataService>(context, listen: false);
      healthService.updateRealtimeData(
        heartRate: heartRate,
        spo2: spo2,
        bloodPressure: bloodPressure,
        temperature: temperature,
        temperatureArray: temperatureArray,
        batteryLevel: batteryLevel,
        steps: steps,
        calories: calories,
        distance: distance,
        rri: rri,
        barometricPressure: barometricPressure,
        wearStatus: wearStatus,
        sleepData: sleepData,
        mentalStress: mentalStress,
        fatigueLevel: fatigueLevel,
        stressResistance: stressResistance,
        regulationAbility: regulationAbility,
        sdnn: sdnn,
        totalPower: totalPower,
        lowFrequency: lowFrequency,
        highFrequency: highFrequency,
        veryLowFrequency: veryLowFrequency,
      );

      // 2. Update DeviceStatusService
      final deviceStatusService =
          Provider.of<DeviceStatusService>(context, listen: false);
      deviceStatusService.updateConnectionState(
          connected: true,
          deviceId: _connectedDevice!.id,
          deviceName: _connectedDevice!.name,
          batteryLevel: batteryLevel);
      deviceStatusService.updateRealtimeSyncTime(DateTime.now());

      // 3. Update HC20Service
      try {
        final hc20Service = Provider.of<HC20Service>(context, listen: false);
        hc20Service.updateRealtimeData(
            heartRate: heartRate,
            spo2: spo2,
            bloodPressure: bloodPressure != null
                ? '${bloodPressure[0]}/${bloodPressure[1]}'
                : null,
            temperature: temperature,
            batteryLevel: batteryLevel,
            steps: steps);
      } catch (e) {
        print('⚠️ Could not update HC20Service: $e');
      }

      // 4. Send to webhook
      await _sendDataToWebhook(_connectedDevice!, realtimeData,
          isStressAlert: isStressAlert);
      _lastRealtimeSync = DateTime.now();
      await _saveSyncTimestamps();

      // Update local UI state
      setState(() {
        if (heartRate != null) _heartRate = heartRate;
        if (spo2 != null) _spo2 = spo2;
        if (bloodPressure != null) _bloodPressure = bloodPressure;
        if (temperature != null) _temperature = temperature;
        if (batteryLevel != null) _batteryLevel = batteryLevel;
      });

      if (batteryLevel != null && batteryLevel < 20 && !_lowBatteryAlertSent) {
        _showLowBatteryNotification(batteryLevel);
        _lowBatteryAlertSent = true;
      }
      print('✅ [RealtimeSync] Complete - All services updated');

      // Schedule next alarm dynamically: lastRealtimeSync + realtimeInterval + 1 min
      print('📅 [RealtimeSync] ========== SCHEDULING NEXT ALARM ==========');
      print(
          '📅 [RealtimeSync] Device CONNECTED - scheduling after_realtime_sync');
      print(
          '📅 [RealtimeSync] realtimeInterval: ${SyncScheduler.realtimeInterval} min');
      print(
          '📅 [RealtimeSync] Alarm delay: ${SyncScheduler.realtimeInterval + 1} min');
      await AppKeepaliveService.scheduleNextAlarm(
        delayMinutes: SyncScheduler.realtimeInterval + 1,
        reason: 'after_realtime_sync',
      );
      print('📅 [RealtimeSync] ==========================================');
    } catch (e) {
      print('❌ [RealtimeSync] Error: $e');
      await _handleDisconnection();
    }
  }

  Future<void> _handleHistorySync() async {
    if (!_isConnected || _connectedDevice == null) {
      print('⏭️ [HistorySync] Skipping - device not connected');
      return;
    }
    // Check if enough time has passed since last history sync
    if (_lastHistorySync != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastHistorySync!);
      if (timeSinceLastSync.inMinutes < SyncScheduler.historyInterval - 1) {
        print(
            '⏭️ [HistorySync] Skipping - last sync was ${timeSinceLastSync.inMinutes}m ago (need ${SyncScheduler.historyInterval}m)');
        return;
      }
    }
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      List<DateTime> datesToFetch = [];
      if (_lastHistorySyncDate == null) {
        datesToFetch.add(today);
        print('📚 [HistorySync] First sync ever - fetching today only');
      } else {
        final daysSinceLastSync =
            today.difference(_lastHistorySyncDate!).inDays;

        if (daysSinceLastSync == 0) {
          datesToFetch.add(today);
          print('📚 [HistorySync] Same day - fetching today');
        } else if (daysSinceLastSync > 0) {
          print(
              '📚 [HistorySync] Found $daysSinceLastSync days of missing data - backfilling...');
          final daysToBackfill = daysSinceLastSync > 7 ? 7 : daysSinceLastSync;
          for (int i = 1; i <= daysToBackfill; i++) {
            datesToFetch.add(_lastHistorySyncDate!.add(Duration(days: i)));
          }
          print('📚 [HistorySync] Will fetch ${datesToFetch.length} days');
        } else {
          print('⚠️ [HistorySync] Clock anomaly - fetching today only');
          datesToFetch.add(today);
        }
      }

      int totalRowsFetched = 0;
      for (var dateToFetch in datesToFetch) {
        print(
            '📅 [HistorySync] Fetching data for ${dateToFetch.year}/${dateToFetch.month}/${dateToFetch.day}...');
        final yy = dateToFetch.year % 100;
        final mm = dateToFetch.month;
        final dd = dateToFetch.day;
        try {
          final results = await Future.wait([
            _client!
                .getAllDayHrv2Rows(_connectedDevice!, yy: yy, mm: mm, dd: dd),
            _client!
                .getAllDayHrvRows(_connectedDevice!, yy: yy, mm: mm, dd: dd),
            _client!.getAllDayBpRows(_connectedDevice!, yy: yy, mm: mm, dd: dd),
            _client!
                .getAllDaySpo2Rows(_connectedDevice!, yy: yy, mm: mm, dd: dd),
            _client!
                .getAllDayStepsRows(_connectedDevice!, yy: yy, mm: mm, dd: dd),
            _client!.getAllDaySleepRows(_connectedDevice!,
                yy: yy, mm: mm, dd: dd, includeSummary: true),
            _client!.getAllDayCaloriesRows(_connectedDevice!,
                yy: yy, mm: mm, dd: dd),
            _client!.getAllDaySummaryRows(_connectedDevice!,
                yy: yy, mm: mm, dd: dd),
          ], eagerError: false);
          final dayTotal =
              results.fold<int>(0, (sum, list) => sum + list.length);
          totalRowsFetched += dayTotal;
          print(
              '✅ [HistorySync] ${dateToFetch.year}/${dateToFetch.month}/${dateToFetch.day} - $dayTotal rows');
          await _sendHistoryToWebhook(
            hrv2Rows: results[0],
            hrvRows: results[1],
            bpRows: results[2],
            spo2Rows: results[3],
            stepsRows: results[4],
            sleepRows: results[5],
            caloriesRows: results[6],
            summaryRows: results[7],
            dateStr:
                '${dateToFetch.year}-${dateToFetch.month.toString().padLeft(2, '0')}-${dateToFetch.day.toString().padLeft(2, '0')}',
            isAutomatic: true,
          );
          if (dateToFetch != datesToFetch.last)
            await Future.delayed(Duration(seconds: 2));
        } catch (e) {
          print(
              '❌ [HistorySync] Error fetching ${dateToFetch.year}/${dateToFetch.month}/${dateToFetch.day}: $e');
        }
      }

      _lastHistorySyncDate = today;
      _lastHistorySync = DateTime.now();
      await _saveSyncTimestamps();
      print(
          '✅ [HistorySync] Complete! Fetched $totalRowsFetched rows across ${datesToFetch.length} days');
      print('   Last sync date: ${_lastHistorySyncDate!.toIso8601String()}');
    } catch (e) {
      print('❌ [HistorySync] Fatal error: $e');
    }
  }

  void _handleReconnectScan() {
    final connectionManager =
        Provider.of<HC20ConnectionManager>(context, listen: false);
    if (_isConnected ||
        _savedDeviceId == null ||
        connectionManager.isCleaningUp) return;
    if (kDebugMode)
      print('🔍 [ReconnectScan] Attempting to reconnect to saved device...');
    _scanForSavedDevice();
  }

  void _startScanning() async {
    if (!_isBatteryOptimizationDisabled) {
      await _checkBatteryOptimizationStatus();
      if (!_isBatteryOptimizationDisabled) {
        setState(() {
          _statusMessage =
              '❌ Cannot scan: Battery optimization must be disabled first!';
        });
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('⚠️ Battery Optimization Required'),
              content: Text(
                  'This app requires unrestricted battery access to maintain continuous Bluetooth connection.\n\nPlease disable battery optimization to continue.'),
              actions: [
                TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _requestBatteryOptimizationExemption();
                    },
                    child: Text('Disable Battery Optimization'))
              ],
            );
          },
        );
        return;
      }
    }
    final connectionManager =
        Provider.of<HC20ConnectionManager>(context, listen: false);
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
      _statusMessage = 'Scanning for HC20 devices...';
    });
    
    // Show scanning SnackBar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Searching for HC20 devices...',
                  style: TextStyle(fontFamily: 'poppins', fontWeight: FontWeight.w500),
                ),
              ),
              Icon(Icons.bluetooth_searching, color: Colors.white),
            ],
          ),
          backgroundColor: const Color(0xFF532A7B),
          duration: const Duration(seconds: 30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
    
    await connectionManager.startScanning();
    _client ??= connectionManager.client;
  }

  Future<void> _connectToDevice(Hc20Device device) async {
    final connectionManager =
        Provider.of<HC20ConnectionManager>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final userPhone = authService.currentUser?.phone;
    _client ??= connectionManager.client;
    
    // Show connecting SnackBar
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Connecting to ${device.name}...',
                  style: const TextStyle(
                    fontFamily: 'poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.bluetooth_connected, color: Colors.white),
            ],
          ),
          backgroundColor: const Color(0xFF532A7B),
          duration: const Duration(seconds: 30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
    
    final success =
        await connectionManager.connectToDevice(device, userPhone: userPhone);
    
    // Hide connecting SnackBar
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    
    if (success) {
      // Show success SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 16),
                Text(
                  'Connected to ${device.name}',
                  style: const TextStyle(
                    fontFamily: 'poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1DB50F),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      
      setState(() {
        _connectedDevice = connectionManager.connectedDevice;
        _isConnected = true;
        _connectionState = ConnectionState.connected;
      });
      try {
        final hc20Service = Provider.of<HC20Service>(context, listen: false);
        hc20Service.updateConnectionState(
            connected: true, device: device, client: connectionManager.client);
      } catch (e) {
        print('⚠️ Could not update HC20Service: $e');
      }
      _addConnectionEvent(
          event: _connectionHistory.isEmpty ? 'connected' : 'reconnected',
          deviceId: device.id);
      if (_syncScheduler == null) {
        print('🔧 [Connect] Initializing new sync scheduler...');
        _initializeSyncScheduler();
      }
      await _performInitialSyncsIfNeeded();
      if (_syncScheduler != null && !_syncScheduler!.isRunning) {
        _syncScheduler?.start();
        print('✅ Unified sync scheduler started');
      }
      await _startNativeBackgroundServices(device, userPhone);
      _showConnectionRestoredNotification();
    } else {
      // Show failure SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Connection failed. Please try again.',
                    style: TextStyle(
                      fontFamily: 'poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF5F5A),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _performInitialSyncsIfNeeded() async {
    if (_lastRealtimeSync != null) {
      final timeSinceRealtimeSync =
          DateTime.now().difference(_lastRealtimeSync!);
      if (timeSinceRealtimeSync.inMinutes >= SyncScheduler.realtimeInterval) {
        print('⚡ [Connect] Realtime sync overdue - syncing NOW');
        await _handleRealtimeSync();
      }
    } else {
      print('⚡ [Connect] First connection - syncing realtime data NOW');
      _lastRealtimeSync = DateTime.now();
      await _handleRealtimeSync();
    }

    // Check history sync
    if (_lastHistorySync != null) {
      final timeSinceHistorySync = DateTime.now().difference(_lastHistorySync!);
      if (timeSinceHistorySync.inMinutes >= SyncScheduler.historyInterval) {
        print('⚡ [Connect] History sync overdue - syncing NOW');
        await _handleHistorySync();
      }
    } else {
      print('⚡ [Connect] First connection - syncing history data NOW');
      _lastHistorySyncDate = DateTime.now();
      await _handleHistorySync();
    }
  }

  Future<void> _startNativeBackgroundServices(
      Hc20Device device, String? userPhone) async {
    try {
      const platform = MethodChannel('com.hfc.app/background');
      await platform.invokeMethod('startNativeBleService',
          {'deviceAddress': device.id, 'userPhone': userPhone ?? 'unknown'});
      print('✅ Native BLE service started');
    } catch (e) {
      print('⚠️ Failed to start native BLE service: $e');
    }
    // Note: NativeHC20Service removed - ForegroundService already handles webhook functionality
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
      final response = await _apiService.associateDevice(device.id, user.id,
          deviceName: device.name);
      if (response['success'] == true) {
        print(
            '✅ Device associated successfully! Updated ${response['updatedRecords']} records');
        setState(() {
          _isDeviceAssociated = true;
          _statusMessage =
              'Device linked! Updated ${response['updatedRecords']} health records';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('✅ Device linked to ${user.name}\'s account'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3)));
        }
      } else {
        print(
            '⚠️ Device association failed: ${response['error']} - user can link later');
      }
    } catch (e) {
      print('❌ Error associating device: $e - will retry later');
    }
  }

  // PHASE 7: Old 6-hour timer methods removed - replaced by unified scheduler (_handleHistorySync handles all 8 history types)

  Future<void> _sendHistoryToWebhook({
    required List<dynamic> hrv2Rows,
    required List<dynamic> hrvRows,
    required List<dynamic> bpRows,
    required List<dynamic> spo2Rows,
    required List<dynamic> stepsRows,
    required List<dynamic> summaryRows,
    required List<dynamic> caloriesRows,
    required List<dynamic> sleepRows,
    required String dateStr,
    bool isAutomatic = false,
  }) async {
    if (_connectedDevice == null) return;
    final dataService = Provider.of<HC20DataService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    try {
      await dataService.sendHistoryDataToWebhook(
        deviceId: _connectedDevice!.id,
        deviceName: _connectedDevice!.name,
        dateStr: dateStr,
        userPhone: user?.phone,
        userId: user?.id,
        userName: user?.name,
        deviceManufacturer: _deviceManufacturer,
        deviceModel: _deviceModel,
        deviceOsVersion: _deviceOsVersion,
        mobileDeviceId: _deviceId,
        isAutomatic: isAutomatic,
        hrv2Rows: hrv2Rows,
        hrvRows: hrvRows,
        bpRows: bpRows,
        spo2Rows: spo2Rows,
        stepsRows: stepsRows,
        summaryRows: summaryRows,
        caloriesRows: caloriesRows,
        sleepRows: sleepRows,
      );
      print(
          '✅ History webhook sent successfully via HC20DataService (${isAutomatic ? 'auto' : 'manual'})');
    } catch (e) {
      print('❌ Error sending history to webhook: $e');
      rethrow;
    }
  }

  Future<void> _handleDisconnection() async {
    final connectionManager =
        Provider.of<HC20ConnectionManager>(context, listen: false);
    await _saveSyncTimestamps();
    setState(() {
      _isConnected = false;
      _connectionState = ConnectionState.reconnecting;
      _statusMessage = 'Connection lost. Attempting to reconnect...';
    });
    try {
      final hc20Service = Provider.of<HC20Service>(context, listen: false);
      hc20Service.updateConnectionState(connected: false);
    } catch (e) {
      print('⚠️ Could not update HC20Service: $e');
    }
    try {
      final deviceStatusService =
          Provider.of<DeviceStatusService>(context, listen: false);
      deviceStatusService.updateConnectionState(
          connected: false,
          deviceId: _connectedDevice?.id,
          deviceName: _connectedDevice?.name,
          batteryLevel: _batteryLevel);
    } catch (e) {
      print('⚠️ Could not update DeviceStatusService: $e');
    }
    await connectionManager.handleDisconnection();
    setState(() {
      _isConnected = connectionManager.isConnected;
      _isReconnecting = connectionManager.isReconnecting;
      _statusMessage = connectionManager.statusMessage;
      if (connectionManager.isConnected)
        _connectionState = ConnectionState.connected;
      else if (connectionManager.isReconnecting)
        _connectionState = ConnectionState.reconnecting;
      else
        _connectionState = ConnectionState.disconnected;
    });
  }

  void _sendStressWebhook() {
    if (_connectedDevice == null || !_isConnected || _client == null) {
      print('⚠️ Cannot send stress webhook - no device connected');
      setState(() {
        _statusMessage = 'No device connected';
      });
      return;
    }
    print(
        '\n🚨 STRESS BUTTON PRESSED - Requesting IMMEDIATE fresh data from device...\n');
    setState(() {
      _statusMessage = 'Requesting fresh data...';
    });
    _client!
        .realtimeV2(_connectedDevice!)
        .listen((_) {}, onError: (_) {})
        .cancel();
  }

  Future<void> _sendDataToWebhook(Hc20Device device, Hc20RealtimeV2 data,
      {bool isStressAlert = false}) async {
    try {
      final dataService = Provider.of<HC20DataService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      final hasInternet = await _checkInternetConnection();
      final success = await dataService.sendRealtimeDataToWebhook(
        device,
        data,
        isStressAlert: isStressAlert,
        userPhone: user?.phone,
        userId: user?.id,
        userName: user?.name,
        deviceManufacturer: _deviceManufacturer,
        deviceModel: _deviceModel,
        deviceOsVersion: _deviceOsVersion,
        mobileDeviceId: _deviceId,
        isBluetoothOn: _isBluetoothOn,
        hasInternet: hasInternet,
        isLowBattery: _isLowBattery,
      );
      if (success) {
        print('✅ Webhook sent successfully via HC20DataService');
      } else {
        print('❌ Webhook failed via HC20DataService');
        if (!hasInternet)
          _showDisconnectNotification(DisconnectReason.noInternet);
      }
    } catch (e) {
      print('❌ Error in _sendDataToWebhook: $e');
    }
  }

  String _formatTimeWithRelative(DateTime timestamp) {
    // Format: "10:10 AM (2m ago)"
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    final absoluteTime = '$hour:$minute $period';
    String relativeTime;
    if (diff.inSeconds < 60)
      relativeTime = '${diff.inSeconds}s ago';
    else if (diff.inMinutes < 60)
      relativeTime = '${diff.inMinutes}m ago';
    else if (diff.inHours < 24)
      relativeTime = '${diff.inHours}h ago';
    else
      relativeTime = '${diff.inDays}d ago';
    return '$absoluteTime ($relativeTime)';
  }

  String _formatNextSyncTime({required bool isRealtime}) {
    // Format: "10:13 AM (in 3m)" or "Syncing soon..."
    final lastSync = isRealtime ? _lastRealtimeSync : _lastHistorySync;
    final interval = isRealtime
        ? SyncScheduler.realtimeInterval
        : SyncScheduler.historyInterval;
    if (lastSync == null) return 'Pending first sync';
    final nextSync = lastSync.add(Duration(minutes: interval));
    final now = DateTime.now();
    final diff = nextSync.difference(now);
    if (diff.isNegative)
      return _isConnected
          ? 'Syncing soon...'
          : 'Overdue - will sync on connect';
    final hour = nextSync.hour % 12 == 0 ? 12 : nextSync.hour % 12;
    final minute = nextSync.minute.toString().padLeft(2, '0');
    final period = nextSync.hour >= 12 ? 'PM' : 'AM';
    final absoluteTime = '$hour:$minute $period';
    String relativeTime;
    if (diff.inSeconds < 60)
      relativeTime = 'in ${diff.inSeconds}s';
    else if (diff.inMinutes < 60)
      relativeTime = 'in ${diff.inMinutes}m';
    else
      relativeTime = 'in ${diff.inHours}h ${diff.inMinutes % 60}m';
    return '$absoluteTime ($relativeTime)';
  }

  Widget _buildSyncStatusRow(String label, String timeSince, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800)),
        const SizedBox(width: 8),
        Text(timeSince,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ]),
    );
  }

  void _addConnectionEvent(
      {required String event, String? reason, String? deviceId}) {
    final newEvent = ConnectionEvent(
        timestamp: DateTime.now(),
        event: event,
        reason: reason,
        deviceId: deviceId);
    setState(() {
      _connectionHistory.insert(0, newEvent);
      if (_connectionHistory.length > 50)
        _connectionHistory = _connectionHistory.sublist(0, 50);
      if (event == 'disconnected' && reason != null)
        _disconnectReasons[reason] = (_disconnectReasons[reason] ?? 0) + 1;
    });
    print(
        '📊 [History] Event logged: $event ${reason != null ? "($reason)" : ""}');
  }

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
    final connectionManager =
        Provider.of<HC20ConnectionManager>(context, listen: false);
    connectionManager.resetReconnectAttempts();
    setState(() {
      _connectionState = ConnectionState.connecting;
      _statusMessage = 'Manual reconnect: Scanning for device...';
    });
    await _scanForSavedDevice();
  }

  Future<void> _manualCloudSync() async {
    if (!_isConnected || _connectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ No device connected'),
          backgroundColor: Colors.orange));
      return;
    }
    print('☁️ [ManualSync] User triggered Cloud Sync');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: const [
          SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Syncing history data...')
        ]),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 30)));
    try {
      // Force history sync without checking last sync time
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yy = today.year % 100;
      final mm = today.month;
      final dd = today.day;
      final results = await Future.wait([
        _client!.getAllDayHrv2Rows(_connectedDevice!, yy: yy, mm: mm, dd: dd),
        _client!.getAllDayHrvRows(_connectedDevice!, yy: yy, mm: mm, dd: dd),
        _client!.getAllDayBpRows(_connectedDevice!, yy: yy, mm: mm, dd: dd),
        _client!.getAllDaySpo2Rows(_connectedDevice!, yy: yy, mm: mm, dd: dd),
        _client!.getAllDayStepsRows(_connectedDevice!, yy: yy, mm: mm, dd: dd),
        _client!.getAllDaySleepRows(_connectedDevice!,
            yy: yy, mm: mm, dd: dd, includeSummary: true),
        _client!
            .getAllDayCaloriesRows(_connectedDevice!, yy: yy, mm: mm, dd: dd),
        _client!
            .getAllDaySummaryRows(_connectedDevice!, yy: yy, mm: mm, dd: dd),
      ], eagerError: false);
      final totalRows = results.fold<int>(0, (sum, list) => sum + list.length);
      await _sendHistoryToWebhook(
        hrv2Rows: results[0],
        hrvRows: results[1],
        bpRows: results[2],
        spo2Rows: results[3],
        stepsRows: results[4],
        sleepRows: results[5],
        caloriesRows: results[6],
        summaryRows: results[7],
        dateStr:
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
        isAutomatic: false,
      );
      _lastHistorySync = DateTime.now();
      _lastHistorySyncDate = today;
      await _saveSyncTimestamps();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Cloud Sync Complete! $totalRows records uploaded'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3)));
      }
      print('✅ [ManualSync] Cloud Sync complete - $totalRows rows');
    } catch (e) {
      print('❌ [ManualSync] Cloud Sync failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ Cloud Sync Failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4)));
      }
    }
  }

  Future<void> _manualClockSync() async {
    if (!_isConnected || _connectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ No device connected'),
          backgroundColor: Colors.orange));
      return;
    }
    print('⏰ [ManualSync] User triggered Clock Sync');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: const [
          SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Syncing clock with device...')
        ]),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 10)));
    try {
      final connectionManager =
          Provider.of<HC20ConnectionManager>(context, listen: false);
      final success = await connectionManager.syncTime();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (success) {
          setState(() {
            _lastTimeSyncStatus = '✅ Time synced successfully';
            _lastTimeSyncTime = DateTime.now();
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Clock Sync Complete!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('❌ Clock Sync Failed'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3)));
        }
      }
      print('✅ [ManualSync] Clock Sync ${success ? "complete" : "failed"}');
    } catch (e) {
      print('❌ [ManualSync] Clock Sync failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ Clock Sync Failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4)));
      }
    }
  }

  void _startAutoReconnectScanner() {
    if (_savedDeviceId == null || _savedDeviceId!.isEmpty) {
      print('ℹ️  [Auto-Reconnect] No saved device - scheduler not needed');
      return;
    }
    if (_syncScheduler == null || !_syncScheduler!.isRunning) {
      print(
          '🔧 [Auto-Reconnect] Initializing scheduler for reconnect scans...');
      _initializeSyncScheduler();
      _syncScheduler?.start();
      print(
          '✅ [Auto-Reconnect] Scheduler started - will scan every ${SyncScheduler.reconnectInterval} minutes');
    } else {
      print(
          '✅ [Auto-Reconnect] Scheduler already running - reconnect scans active');
    }
    Future.delayed(const Duration(seconds: 2), () {
      final connectionManager =
          Provider.of<HC20ConnectionManager>(context, listen: false);
      if (!_isConnected &&
          !_isAutoReconnecting &&
          !_isReconnecting &&
          !connectionManager.isCleaningUp) {
        print(
            '🔍 [Auto-Reconnect] Starting immediate scan for saved device...');
        _scanForSavedDevice();
      }
    });
  }

  Future<void> _scanForSavedDevice() async {
    final connectionManager =
        Provider.of<HC20ConnectionManager>(context, listen: false);
    if (connectionManager.isCleaningUp ||
        connectionManager.isConnected ||
        connectionManager.isReconnecting) {
      print('⚠️ [Auto-Reconnect] Skipping scan - manager busy');
      return;
    }
    setState(() {
      _isReconnecting = true;
      _statusMessage = 'Scanning for saved device...';
    });
    final device = await connectionManager.scanForSavedDevice();
    if (device == null && mounted) {
      setState(() {
        _isReconnecting = false;
        _statusMessage = 'Device not found. Will retry...';
      });

      // Schedule next alarm dynamically: now + reconnectInterval + 1 min
      print('📅 [Reconnect] ========== SCHEDULING NEXT ALARM ==========');
      print(
          '📅 [Reconnect] Device DISCONNECTED - scheduling after_reconnect_fail');
      print(
          '📅 [Reconnect] reconnectInterval: ${SyncScheduler.reconnectInterval} min');
      print(
          '📅 [Reconnect] Alarm delay: ${SyncScheduler.reconnectInterval + 1} min');
      await AppKeepaliveService.scheduleNextAlarm(
        delayMinutes: SyncScheduler.reconnectInterval + 1,
        reason: 'after_reconnect_fail',
      );
      print('📅 [Reconnect] ==========================================');
    }
  }

  Future<void> _disconnect() async {
    final connectionManager =
        Provider.of<HC20ConnectionManager>(context, listen: false);
    await connectionManager.disconnect();
    setState(() {
      _isConnected = false;
      _connectionState = ConnectionState.disconnected;
      _statusMessage = 'Disconnected';
      _isReconnecting = false;
      _lastDataReceived = null;
      _heartRate = null;
      _spo2 = null;
      _bloodPressure = null;
      _temperature = null;
      _batteryLevel = null;
      // NOTE: _savedDeviceId is preserved intentionally
      // This allows manual reconnect button to show after disconnect
    });
    try {
      final hc20Service = Provider.of<HC20Service>(context, listen: false);
      hc20Service.updateConnectionState(connected: false);
      print('✅ [_disconnect] HC20Service updated: disconnected');
    } catch (e) {
      print('⚠️ Could not update HC20Service: $e');
    }
    try {
      final deviceStatusService =
          Provider.of<DeviceStatusService>(context, listen: false);
      deviceStatusService.updateConnectionState(
          connected: false,
          deviceId: _connectedDevice?.id,
          deviceName: _connectedDevice?.name,
          batteryLevel: null);
      print('✅ [_disconnect] DeviceStatusService updated: disconnected');
    } catch (e) {
      print('⚠️ Could not update DeviceStatusService: $e');
    }
    print('✅ [_disconnect] Disconnect complete');
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    if (kDebugMode)
      print('🏠 HC20HomePage build() - user: ${user?.name ?? "NOT LOGGED IN"}');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TODO: Status card section hidden for now - uncomment when needed
          // Card(
          //   child: Padding(
          //     padding: const EdgeInsets.all(16.0),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Text('Status', style: Theme.of(context).textTheme.titleMedium),
          //         const SizedBox(height: 8),
          //         if (user != null) ...[
          //           Container(
          //             padding: const EdgeInsets.all(8),
          //             decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green, width: 2)),
          //             child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          //               Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 20), const SizedBox(width: 8),
          //                 Text('Account Connected', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 14))]),
          //               const SizedBox(height: 8),
          //                 Row(children: [
          //                   Icon(Icons.person, color: Colors.green.shade700, size: 18), const SizedBox(width: 6),
          //                   Text(user.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green.shade900)),
          //                   if (_savedDeviceId != null) ...[
          //                     Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('|', style: TextStyle(color: Colors.grey.shade400))),
          //                     Icon(Icons.watch, color: Colors.blue.shade700, size: 18), const SizedBox(width: 6),
          //                     Expanded(child: Text(_savedDeviceId!, style: TextStyle(fontSize: 11, fontFamily: 'Courier', color: Colors.blue.shade900), overflow: TextOverflow.ellipsis)),
          //                   ],
          //                 ]),
          //               ],
          //             ),
          //           ),
          //           const SizedBox(height: 8),
          //         ],
          //         Container(
          //           padding: const EdgeInsets.all(12),
          //           decoration: BoxDecoration(
          //             color: _connectionState == ConnectionState.connected ? Colors.green.shade50 : _connectionState == ConnectionState.reconnecting ? Colors.orange.shade50 : _connectionState == ConnectionState.error ? Colors.red.shade50 : Colors.grey.shade50,
          //             borderRadius: BorderRadius.circular(8),
          //             border: Border.all(color: _connectionState == ConnectionState.connected ? Colors.green : _connectionState == ConnectionState.reconnecting ? Colors.orange : _connectionState == ConnectionState.error ? Colors.red : Colors.grey, width: 2),
          //           ),
          //           child: Text(_statusMessage, style: TextStyle(
          //             color: _connectionState == ConnectionState.connected ? Colors.green.shade900 : _connectionState == ConnectionState.reconnecting ? Colors.orange.shade900 : _connectionState == ConnectionState.error ? Colors.red.shade900 : Colors.grey.shade900,
          //             fontWeight: FontWeight.w500)),
          //         ),
          //         const SizedBox(height: 12),
          //         Row(children: [
          //           Icon(
          //             _connectionState == ConnectionState.connected ? Icons.bluetooth_connected : _connectionState == ConnectionState.reconnecting ? Icons.bluetooth_searching : _connectionState == ConnectionState.connecting ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
          //             color: _connectionState == ConnectionState.connected ? Colors.green : _connectionState == ConnectionState.reconnecting ? Colors.orange : _connectionState == ConnectionState.connecting ? Colors.blue : Colors.grey,
          //             size: 28,
          //           ),
          //           const SizedBox(width: 8),
          //           Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          //             Text(
          //               _connectionState == ConnectionState.connected ? '🟢 Connected' : _connectionState == ConnectionState.reconnecting ? '🟠 Reconnecting...' : _connectionState == ConnectionState.connecting ? '🔵 Connecting...' : _connectionState == ConnectionState.error ? '🔴 Connection Error' : '⚪ Disconnected',
          //               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _connectionState == ConnectionState.connected ? Colors.green.shade700 : _connectionState == ConnectionState.reconnecting ? Colors.orange.shade700 : _connectionState == ConnectionState.error ? Colors.red.shade700 : Colors.grey.shade700)),
          //             if (_isConnected && _lastDataReceived != null)
          //               Text('Last data: ${DateTime.now().difference(_lastDataReceived!).inSeconds}s ago', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          //           ])),
          //         ]),
          //         if (_isConnected && _isDeviceAssociated) ...[
          //           const SizedBox(height: 8),
          //           Row(children: [Icon(Icons.link, color: Colors.green, size: 20), const SizedBox(width: 8),
          //             Text('Device linked to your account', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500))]),
          //         ],
          //       ],
          //     ),
          //   ),
          // ),
          // const SizedBox(height: 16),
          if (_isLowBattery && _batteryLevel != null) ...[
            LowBatteryWarning(batteryLevel: _batteryLevel!),
            const SizedBox(height: 16)
          ],
          // Hero Section - shown when no device is set up yet
          if (!_isConnected && _savedDeviceId == null) ...[
            HeroSection(
              onSetupDevice: _startScanning,
              discoveredDevices: _discoveredDevices,
              isScanning: _isScanning,
              onConnectDevice: _connectToDevice,
            ),
            const SizedBox(height: 16)
          ],
          if (!_isConnected && _savedDeviceId != null) ...[
            ManualReconnectButton(
                onPressed: _manualReconnect, 
                isReconnecting: _isReconnecting,
                minutesUntilAutoReconnect: _syncScheduler != null && _syncScheduler!.isRunning
                    ? SyncScheduler.reconnectInterval - (_syncScheduler!.tickCount % SyncScheduler.reconnectInterval)
                    : SyncScheduler.reconnectInterval),
            const SizedBox(height: 8)
          ],
          if (!_isBatteryOptimizationDisabled) ...[
            BatteryOptimizationWarning(
                isDisabled: _isBatteryOptimizationDisabled,
                onDisable: _requestBatteryOptimizationExemption),
            const SizedBox(height: 16)
          ],
          if (_isConnected) ...[
            Consumer<HC20DataService>(builder: (context, dataService, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF532A7B),
                      Color(0xFF7B4BA8),
                      Color(0xFF9B6BC8)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF532A7B).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10)),
                    BoxShadow(
                        color: const Color(0xFF532A7B).withOpacity(0.2),
                        blurRadius: 40,
                        offset: const Offset(0, 20)),
                  ],
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned(
                        right: -20,
                        top: -20,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.08)),
                        )),
                    Positioned(
                        right: 40,
                        bottom: -30,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05)),
                        )),
                    Positioned(
                        left: -15,
                        bottom: -15,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.06)),
                        )),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Animated cloud icon with glow effect
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: 1),
                                duration: const Duration(seconds: 2),
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(
                                        0, -6 * (0.5 - (value - 0.5).abs())),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                              color:
                                                  Colors.white.withOpacity(0.3),
                                              blurRadius: 15,
                                              spreadRadius: 2)
                                        ],
                                      ),
                                      child: const Icon(
                                          Icons.cloud_sync_rounded,
                                          color: Colors.white,
                                          size: 32),
                                    ),
                                  );
                                },
                                onEnd: () {
                                  if (mounted) setState(() {});
                                },
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('Cloud Sync',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 22,
                                                letterSpacing: 0.5)),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1DB50F)
                                                .withOpacity(0.9),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.circle,
                                                  color: Colors.white, size: 8),
                                              SizedBox(width: 5),
                                              Text('ACTIVE',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                      letterSpacing: 1)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Your health data is syncing securely',
                                        style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Stats row
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                  width: 1),
                            ),
                            child: Row(
                              children: [
                                // Success count
                                Expanded(
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                            '${dataService.webhookSuccessCount}',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 22)),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle_rounded,
                                              color:
                                                  Colors.greenAccent.shade200,
                                              size: 14),
                                          const SizedBox(width: 4),
                                          Text('Syncs',
                                              style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Divider
                                Container(
                                    width: 1,
                                    height: 50,
                                    color: Colors.white.withOpacity(0.2)),
                                // Last sync time
                                Expanded(
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.schedule_rounded,
                                            color:
                                                Colors.white.withOpacity(0.9),
                                            size: 22),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        dataService.lastWebhookTime != null
                                            ? '${dataService.lastWebhookTime!.hour}:${dataService.lastWebhookTime!.minute.toString().padLeft(2, '0')}'
                                            : '--:--',
                                        style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.9),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                // Divider
                                Container(
                                    width: 1,
                                    height: 50,
                                    color: Colors.white.withOpacity(0.2)),
                                // Battery status
                                Expanded(
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _batteryLevel != null &&
                                                  _batteryLevel! > 80
                                              ? Icons.battery_full_rounded
                                              : _batteryLevel != null &&
                                                      _batteryLevel! > 50
                                                  ? Icons.battery_5_bar_rounded
                                                  : _batteryLevel != null &&
                                                          _batteryLevel! > 20
                                                      ? Icons
                                                          .battery_3_bar_rounded
                                                      : Icons
                                                          .battery_1_bar_rounded,
                                          color: _batteryLevel != null &&
                                                  _batteryLevel! <= 20
                                              ? Colors.red.shade300
                                              : Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _batteryLevel != null
                                            ? '$_batteryLevel%'
                                            : '--%',
                                        style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.9),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.sync, color: Colors.purple.shade700, size: 18),
                const SizedBox(width: 6),
                Text('Sync Status',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade900))
              ]),
              const SizedBox(height: 8),
              if (_lastRealtimeSync != null)
                _buildSyncStatusRow('📊 Realtime',
                    _formatTimeWithRelative(_lastRealtimeSync!), Colors.blue),
              if (_lastHistorySync != null)
                _buildSyncStatusRow('📚 History',
                    _formatTimeWithRelative(_lastHistorySync!), Colors.green),
              if (_lastRealtimeSync == null && _lastHistorySync == null)
                Text('No sync data yet - waiting for first connection',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic)),
              if (_syncScheduler != null) ...[
                const SizedBox(height: 8),
                Divider(color: Colors.purple.shade300, height: 1),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(
                      _syncScheduler!.isRunning
                          ? Icons.play_circle
                          : Icons.pause_circle,
                      size: 16,
                      color: _syncScheduler!.isRunning
                          ? Colors.green
                          : Colors.orange),
                  const SizedBox(width: 6),
                  Text(
                      _syncScheduler!.isRunning
                          ? 'Scheduler Active'
                          : 'Scheduler Paused',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _syncScheduler!.isRunning
                              ? Colors.green.shade800
                              : Colors.orange.shade800)),
                ]),
                if (_syncScheduler!.isRunning && _lastRealtimeSync != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.schedule,
                        size: 14, color: Colors.purple.shade600),
                    const SizedBox(width: 6),
                    Text('Next sync: ',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade700)),
                    Expanded(
                        child: Text(_formatNextSyncTime(isRealtime: true),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _formatNextSyncTime(isRealtime: true)
                                        .contains('Overdue')
                                    ? Colors.orange.shade700
                                    : _formatNextSyncTime(isRealtime: true)
                                            .contains('Syncing')
                                        ? Colors.green.shade700
                                        : Colors.purple.shade700))),
                  ]),
                ],
              ],
            ]),
          ),
          const SizedBox(height: 16),
          AccountDeviceSection(
            accountName: user?.name ?? 'Not logged in',
            deviceName: _connectedDevice?.name ?? 'HC20 Wearable',
            deviceId: _savedDeviceId,
            isLinked: _isDeviceAssociated,
          ),
          const SizedBox(height: 16),
          // Modern Action Buttons
          Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: _isScanning || _isConnected
                      ? LinearGradient(
                          colors: [Colors.grey.shade300, Colors.grey.shade200])
                      : const LinearGradient(
                          colors: [Color(0xFF532A7B), Color(0xFF7B4BA8)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isScanning || _isConnected
                      ? []
                      : [
                          BoxShadow(
                              color: const Color(0xFF532A7B).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4)),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isScanning || _isConnected ? null : _startScanning,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isScanning
                                ? Icons.bluetooth_searching
                                : Icons.search_rounded,
                            color: _isScanning || _isConnected
                                ? Colors.grey.shade500
                                : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isScanning ? 'Scanning...' : 'Scan Devices',
                            style: TextStyle(
                              color: _isScanning || _isConnected
                                  ? Colors.grey.shade500
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _isConnected ? Colors.white : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isConnected
                        ? Colors.red
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isConnected ? _disconnect : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.link_off_rounded,
                            color: _isConnected
                                ? Colors.red
                                : Colors.grey.shade400,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Disconnect',
                            style: TextStyle(
                              color: _isConnected
                                  ? Colors.red
                                  : Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Cloud Sync & Clock Sync buttons
          Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: _isConnected
                      ? const LinearGradient(
                          colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)])
                      : LinearGradient(
                          colors: [Colors.grey.shade300, Colors.grey.shade200]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isConnected
                      ? [
                          BoxShadow(
                              color: const Color(0xFF1E88E5).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4)),
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isConnected ? _manualCloudSync : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_sync_rounded,
                              color: _isConnected
                                  ? Colors.white
                                  : Colors.grey.shade500,
                              size: 20),
                          const SizedBox(width: 8),
                          Text('Cloud Sync',
                              style: TextStyle(
                                  color: _isConnected
                                      ? Colors.white
                                      : Colors.grey.shade500,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: _isConnected
                      ? const LinearGradient(
                          colors: [Color(0xFF43A047), Color(0xFF66BB6A)])
                      : LinearGradient(
                          colors: [Colors.grey.shade300, Colors.grey.shade200]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isConnected
                      ? [
                          BoxShadow(
                              color: const Color(0xFF43A047).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4)),
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isConnected ? _manualClockSync : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.schedule_rounded,
                              color: _isConnected
                                  ? Colors.white
                                  : Colors.grey.shade500,
                              size: 20),
                          const SizedBox(width: 8),
                          Text('Clock Sync',
                              style: TextStyle(
                                  color: _isConnected
                                      ? Colors.white
                                      : Colors.grey.shade500,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              gradient: _isConnected
                  ? LinearGradient(colors: [
                      Colors.deepPurple.shade600,
                      Colors.deepPurple.shade400
                    ])
                  : LinearGradient(
                      colors: [Colors.grey.shade300, Colors.grey.shade200]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: _isConnected
                  ? [
                      BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4)),
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isConnected
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AllDataPage(
                                client: _client!, device: _connectedDevice!)))
                    : null,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics_rounded,
                        color:
                            _isConnected ? Colors.white : Colors.grey.shade500,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'View All Health Data',
                        style: TextStyle(
                          color: _isConnected
                              ? Colors.white
                              : Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: _isConnected
                            ? Colors.white.withOpacity(0.7)
                            : Colors.grey.shade400,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // TODO: Time Sync Status section hidden for now - uncomment when needed
          // if (_isConnected) ...[
          //   Card(
          //     color: Colors.blue.shade50,
          //     child: Padding(
          //       padding: const EdgeInsets.all(16.0),
          //       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          //         Row(children: [Icon(Icons.access_time, color: Colors.purple.shade700), const SizedBox(width: 8),
          //           Text('Time Sync Status', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.purple.shade900, fontWeight: FontWeight.bold))]),
          //         const SizedBox(height: 12),
          //         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          //           Expanded(child: Text(_lastTimeSyncStatus, style: TextStyle(
          //             color: _lastTimeSyncStatus.startsWith('✅') ? Colors.green : _lastTimeSyncStatus.startsWith('⚠️') ? Colors.orange : Colors.red, fontWeight: FontWeight.bold))),
          //           if (_lastTimeSyncTime != null) Text('${_lastTimeSyncTime!.hour}:${_lastTimeSyncTime!.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          //         ]),
          //         const SizedBox(height: 20),
          //         Row(children: [Icon(Icons.auto_graph, color: Colors.purple.shade700), const SizedBox(width: 8),
          //           Text('HRV Auto-Refresh', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.purple.shade900, fontWeight: FontWeight.bold))]),
          //         const SizedBox(height: 12),
          //         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          //           Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          //             Text('Every 6 hours → Nitto Cloud', style: TextStyle(color: Colors.purple.shade700, fontWeight: FontWeight.w600)),
          //             if (_lastHrvRefresh != null) Text('Last: ${_lastHrvRefresh!.hour}:${_lastHrvRefresh!.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12, color: Colors.grey))
          //             else const Text('Waiting for first fetch...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          //           ])),
          //           Container(
          //             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //             decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(12)),
          //             child: Row(children: [Icon(Icons.check_circle, size: 16, color: Colors.purple.shade700), const SizedBox(width: 4),
          //               Text('Active', style: TextStyle(color: Colors.purple.shade700, fontWeight: FontWeight.bold, fontSize: 12))]),
          //           )]),
          //         const SizedBox(height: 20),
          //         Consumer<HC20DataService>(builder: (context, dataService, child) {
          //           return Column(children: [
          //             Row(children: [Icon(Icons.cloud_upload, color: Colors.blue.shade700), const SizedBox(width: 8),
          //               Text('Backend Webhook Status', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.blue.shade900, fontWeight: FontWeight.bold))]),
          //             const SizedBox(height: 12),
          //             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          //               Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          //                 Text('✅ Success: ${dataService.webhookSuccessCount}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          //                 const SizedBox(height: 4),
          //                 Text('❌ Errors: ${dataService.webhookErrorCount}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          //               ]),
          //               Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          //                 Text(dataService.lastWebhookStatus, style: TextStyle(color: dataService.lastWebhookStatus.startsWith('✓') ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
          //                 if (dataService.lastWebhookTime != null) ...[const SizedBox(height: 4),
          //                   Text('${dataService.lastWebhookTime!.hour}:${dataService.lastWebhookTime!.minute.toString().padLeft(2, '0')}:${dataService.lastWebhookTime!.second.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12, color: Colors.grey))],
          //               ]),
          //             ]),
          //             const SizedBox(height: 8),
          //             Container(
          //               padding: const EdgeInsets.all(8),
          //               decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
          //               child: Row(children: [Icon(Icons.link, size: 16, color: Colors.grey.shade600), const SizedBox(width: 8),
          //                 Expanded(child: Text('https://api.hireforcare.com/webhook/hc20-data', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis))]),
          //             ),
          //             if (dataService.lastWebhookError.isNotEmpty) ...[
          //               const SizedBox(height: 8),
          //               Container(
          //                 padding: const EdgeInsets.all(10),
          //                 decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade200)),
          //                 child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          //                   Icon(Icons.error_outline, size: 18, color: Colors.red.shade700), const SizedBox(width: 8),
          //                   Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          //                     Text('Last Error:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
          //                     const SizedBox(height: 4),
          //                     Text(dataService.lastWebhookError, style: TextStyle(fontSize: 11, color: Colors.red.shade800)),
          //                   ])),
          //                 ]),
          //               ),
          //             ],
          //           ]);
          //         }),
          //         const SizedBox(height: 12),
          //         SizedBox(width: double.infinity, child: ElevatedButton.icon(
          //           onPressed: _sendStressWebhook,
          //           icon: const Icon(Icons.warning_amber_rounded, size: 20), label: const Text('I\'m Feeling Stress'),
          //           style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white,
          //             padding: const EdgeInsets.symmetric(vertical: 14), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
          //       ]),
          //     ),
          //   ),
          //   const SizedBox(height: 16),
          // ],
          if (_discoveredDevices.isNotEmpty) ...[
            Text('Discovered Devices',
                style: Theme.of(context).textTheme.titleMedium),
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
                            onPressed: _isConnected
                                ? null
                                : () => _connectToDevice(device),
                            child: const Text('Connect'))));
              },
            ),
          ],
        ],
      ),
    );
  }
}
