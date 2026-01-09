import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hc20/hc20.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'pages/all_data_page.dart';
import 'pages/test_notification_page.dart';
import 'pages/simple_test_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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

class _HC20HomePageState extends State<HC20HomePage> with WidgetsBindingObserver {
  Hc20Client? _client;
  Hc20Device? _connectedDevice;
  bool _isScanning = false;
  bool _isConnected = false;
  List<Hc20Device> _discoveredDevices = [];
  String _statusMessage = 'Click "Start Scanning" to search for HC20 devices';
  
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
  Timer? _autoReconnectScanner;  // Timer for auto-reconnect scanning
  DateTime? _lastDataReceived;
  
  // Auto-reconnect state
  String? _savedDeviceId;  // Saved device ID for auto-reconnect
  bool _isAutoReconnecting = false;
  DateTime? _lastHrvRefresh;  // Track last HRV refresh time
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  bool _isBatteryOptimizationDisabled = false; // Track battery optimization status
  
  // API service for device association
  final ApiService _apiService = ApiService();
  bool _isDeviceAssociated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeDio();
    _enableBackgroundExecution();
    _checkAndShowBatteryOptimizationDialog();
    _loadSavedDevice();  // Load saved device for auto-reconnect
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
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeSubscription?.cancel();
    _dataRefreshTimer?.cancel();
    _connectionMonitor?.cancel();
    _hrvRefreshTimer?.cancel();
    _autoReconnectScanner?.cancel();
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
        print('⏸️ App paused - background mode');
        print('🔄 Background service will maintain webhook transmission');
        break;
      case AppLifecycleState.inactive:
        print('💤 App inactive');
        break;
      case AppLifecycleState.detached:
        print('🔌 App detached');
        break;
      case AppLifecycleState.hidden:
        print('🙈 App hidden');
        break;
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
        _statusMessage = 'Connected to ${info.name} v${info.version}';
      });

      // Associate device with user account
      await _associateDeviceWithUser(device);

      // Start listening to real-time data
      _startRealtimeDataStream(device);
      
      // Start connection monitoring
      _startConnectionMonitoring();
      
      // Start HRV auto-refresh (6 hours)
      _startHrvAutoRefresh();
      
      // Background execution enabled via foreground service + wake lock
      print('✓ Data streaming started - webhooks will continue in background');
      
      // Save device ID for auto-reconnect
      await _saveDeviceForAutoReconnect(device.id);
      
      // Reset reconnection counter on successful connection
      _reconnectAttempts = 0;
      _isReconnecting = false;

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
        setState(() {
          _statusMessage = 'Warning: Device not linked to account';
        });
      }
    } catch (e) {
      print('❌ Error associating device: $e');
      setState(() {
        _statusMessage = 'Warning: Could not link device to account';
      });
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
    print('🚀 Data refresh: Every 120 seconds (2 minutes)');
    print('🚀 ========================================\n');
    
    // Subscribe and KEEP the subscription reference
    _realtimeSubscription = _client!.realtimeV2(device).listen(
      (data) {
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
          if (data.battery != null) _batteryLevel = data.battery!.percent;
          if (data.basicData != null && data.basicData!.isNotEmpty) {
            _steps = data.basicData![0];
          }
        });
        
        // Check if stress alert is pending
        if (_stressAlertPending) {
          print('🚨 Stress alert flag detected - sending STRESS webhook with fresh data');
          _stressAlertPending = false;
          _sendDataToWebhook(device, data, isStressAlert: true);
          setState(() {
            _statusMessage = 'Stress alert sent with fresh data!';
          });
        } else {
          // Send regular webhook (non-blocking)
          print('📤 Sending regular webhook at $_webhookUrl...');
          _sendDataToWebhook(device, data);
        }
      },
      onError: (error) {
        print('\n❌ ========================================');
        print('❌ Real-time stream error: $error');
        print('❌ Device may have disconnected or gone out of range');
        print('❌ ========================================\n');
        
        // Handle disconnection
        if (error.toString().contains('disconnected') || 
            error.toString().contains('connection') ||
            error.toString().contains('GATT')) {
          print('🔄 Device disconnected - attempting reconnection...');
          _handleDisconnection();
        }
        
        setState(() {
          _statusMessage = 'Connection lost: $error';
        });
      },
      onDone: () {
        print('\n✅ ========================================');
        print('✅ Real-time stream completed/closed');
        print('✅ ========================================\n');
      },
    );
    
    print('✓ Real-time stream subscription created and stored in _realtimeSubscription');
    print('✓ Creating webhook timer (triggers every 120 seconds)...');
    
    // Set up periodic timer to trigger data refresh every 120 seconds (2 minutes)
    // ALWAYS sends webhooks - connected sends real data, disconnected sends null values
    // Backend can identify disconnect by null values and timestamp
    _dataRefreshTimer = Timer.periodic(const Duration(seconds: 120), (timer) async {
      try {
        print('\n⏰ ========================================');
        print('⏰ [Timer] 2-minute webhook timer triggered');
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
    
    print('✓ Webhook timer active - triggers every 120 seconds (2 minutes)');
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
  
  void _startConnectionMonitoring() {
    print('🔍 Starting connection monitoring (checking every 30 seconds)...');
    
    _connectionMonitor?.cancel();
    _connectionMonitor = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isConnected || _connectedDevice == null) {
        print('⚠️ [Monitor] Not connected, stopping monitor');
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      if (_lastDataReceived != null) {
        final timeSinceLastData = now.difference(_lastDataReceived!).inSeconds;
        print('🔍 [Monitor] Last data received: ${timeSinceLastData}s ago');
        
        // If no data for 720 seconds (12 minutes), device might be disconnected
        // This is 120 seconds longer than the 10-minute data interval to allow for delays
        if (timeSinceLastData > 720) {
          print('⚠️ [Monitor] No data for ${timeSinceLastData}s - device may be disconnected');
          _handleDisconnection();
        } else if (timeSinceLastData > 660) {
          print('⏰ [Monitor] Data slightly delayed (${timeSinceLastData}s), but within tolerance');
        }
      }
    });
  }
  
  void _handleDisconnection() async {
    if (_isReconnecting) {
      print('⏳ Already attempting reconnection...');
      return;
    }
    
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('❌ Max reconnection attempts reached. Please reconnect manually.');
      setState(() {
        _statusMessage = 'Device disconnected. Please reconnect manually.';
        _isConnected = false;
      });
      _cleanup();
      return;
    }
    
    _isReconnecting = true;
    _reconnectAttempts++;
    
    print('🔄 Reconnection attempt $_reconnectAttempts/$_maxReconnectAttempts...');
    
    setState(() {
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
  
  Future<void> _sendDataToWebhook(Hc20Device device, Hc20RealtimeV2 data, {bool isStressAlert = false}) async {
    try {
      final now = DateTime.now();
      
      // Prepare comprehensive payload with all available data
      final payload = {
        'timestamp': now.toIso8601String(), // Send local timestamp with timezone (e.g., 2025-12-30T08:00:00.000+05:30)
        'stress_alert': isStressAlert,
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
      final response = await _dio.post(
        _webhookUrl,
        data: {
          'phone': phone,
          'deviceId': _connectedDevice?.id ?? _savedDeviceId ?? 'unknown',
          'heartRate': null,
          'spo2': null,
          'bloodPressure': null,
          'temperature': null,
          'batteryLevel': null,
          'steps': null,
          'status': null,
          'message': reason,
          'errorType': reason,
          'timestamp': DateTime.now().toIso8601String(),
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

  // Check network connectivity to determine disconnect reason
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await _dio.get(
        'https://api.hireforcare.com/health',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return result.statusCode != 200;
    } catch (e) {
      // Network error means network disconnect
      return true;
    }
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
        print('🔌 [Auto-Reconnect] Connecting to saved device...');
        setState(() {
          _statusMessage = '🔄 Auto-connecting to ${foundDevice!.name}...';
        });
        await _connectToDevice(foundDevice!);
      } else {
        print('ℹ️  [Auto-Reconnect] Saved device not found nearby');
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

  Future<void> _disconnect() async {
    if (_client == null || _connectedDevice == null) return;

    try {
      print('ℹ️ Disconnecting from device...');
      
      // Stop background service
      try {
        const platform = MethodChannel('com.hfc.app/background');
        await platform.invokeMethod('disableBackgroundExecution');
        print('✅ Background service stopped');
      } catch (e) {
        print('⚠️ Could not stop background service: $e');
      }
      
      // Cleanup all subscriptions and timers
      _cleanup();
      
      await _client!.disconnect(_connectedDevice!);
      setState(() {
        _connectedDevice = null;
        _isConnected = false;
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
      floatingActionButton: (user != null && _connectedDevice != null)
          ? FloatingActionButton.extended(
              onPressed: _sendTestNotification,
              backgroundColor: Colors.orange,
              icon: const Icon(Icons.send),
              label: const Text('Test Notify'),
              tooltip: 'Send Test WhatsApp Notification',
            )
          : null,
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
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '✓ Logged in as ${user.name} (Login saved)',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(_statusMessage),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          color: _isConnected ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(_isConnected ? 'Connected' : 'Disconnected'),
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
                    child: const Text('Get History Data'),
                  ),
                ),
                const SizedBox(width: 8),
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
}
