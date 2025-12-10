# Mobile App Implementation Guide

Step-by-step guide to implement the HFC mobile app with backend integration.

---

## Step 1: Project Dependencies Setup

### Update pubspec.yaml

Add these dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # HC20 SDK
  hc20:
    path: ./hc20
  
  # State Management
  provider: ^6.1.1
  
  # Networking
  dio: ^5.4.0
  
  # Local Storage
  sqflite: ^2.3.0
  shared_preferences: ^2.2.2
  
  # Background Services
  workmanager: ^0.5.2
  
  # Permissions
  permission_handler: ^11.3.1
  
  # Push Notifications
  firebase_core: ^2.24.2
  firebase_messaging: ^14.7.10
  
  # UI Components
  fl_chart: ^0.66.0
  intl: ^0.19.0
  cached_network_image: ^3.3.1
  
  # Utilities
  uuid: ^4.3.3
  path_provider: ^2.1.2
  connectivity_plus: ^5.0.2
```

Run: `flutter pub get`

---

## Step 2: Configuration Files

### Create lib/config/api_config.dart

```dart
class ApiConfig {
  // API Base URL - Change for production
  static const String baseUrl = 'https://api.hireforcare.com/api/v1';
  
  // Timeout configurations
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profile = '/auth/profile';
  
  static const String pairDevice = '/devices/pair';
  static const String myDevices = '/devices/my-devices';
  
  static const String uploadVitals = '/vitals/realtime';
  static const String uploadHrv = '/vitals/hrv';
  static const String uploadHrv2 = '/vitals/hrv2';
  static const String uploadSleep = '/vitals/sleep';
  
  static const String activeAlerts = '/alerts/active';
  static const String alertHistory = '/alerts/history';
  static String respondToAlert(String alertId) => '/alerts/$alertId/respond';
  static String breathingComplete(String alertId) => '/alerts/$alertId/breathing-complete';
  static String bookSession(String alertId) => '/alerts/$alertId/book-session';
}
```

### Create lib/config/nitto_config.dart

```dart
class NittoConfig {
  // Get these from Nitto team
  static const String clientId = 'YOUR_CLIENT_ID_HERE';
  static const String clientSecret = 'YOUR_CLIENT_SECRET_HERE';
}
```

---

## Step 3: Data Models

### Create lib/models/user.dart

```dart
class User {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? groupType;
  final bool baselineComplete;
  final double? baselineHrvThreshold;
  
  User({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.groupType,
    this.baselineComplete = false,
    this.baselineHrvThreshold,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'],
      email: json['email'],
      name: json['name'],
      phone: json['phone'],
      groupType: json['group_type'],
      baselineComplete: json['baseline_complete'] ?? false,
      baselineHrvThreshold: json['baseline_hrv_threshold']?.toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'group_type': groupType,
      'baseline_complete': baselineComplete,
      'baseline_hrv_threshold': baselineHrvThreshold,
    };
  }
}
```

### Create lib/models/vital_reading.dart

```dart
class VitalReading {
  final String? id;
  final DateTime timestamp;
  final int? heartRate;
  final int? spo2;
  final int? systolicBp;
  final int? diastolicBp;
  final double? skinTemp;
  final int? steps;
  final int? batteryLevel;
  final bool synced;
  
  VitalReading({
    this.id,
    required this.timestamp,
    this.heartRate,
    this.spo2,
    this.systolicBp,
    this.diastolicBp,
    this.skinTemp,
    this.steps,
    this.batteryLevel,
    this.synced = false,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'heart_rate': heartRate,
      'spo2': spo2,
      'systolic_bp': systolicBp,
      'diastolic_bp': diastolicBp,
      'skin_temp': skinTemp,
      'steps': steps,
      'battery_level': batteryLevel,
    };
  }
  
  Map<String, dynamic> toLocalDb() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'heart_rate': heartRate,
      'spo2': spo2,
      'systolic_bp': systolicBp,
      'diastolic_bp': diastolicBp,
      'skin_temp': skinTemp,
      'steps': steps,
      'battery_level': batteryLevel,
      'synced': synced ? 1 : 0,
    };
  }
  
  factory VitalReading.fromLocalDb(Map<String, dynamic> map) {
    return VitalReading(
      id: map['id'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      heartRate: map['heart_rate'],
      spo2: map['spo2'],
      systolicBp: map['systolic_bp'],
      diastolicBp: map['diastolic_bp'],
      skinTemp: map['skin_temp'],
      steps: map['steps'],
      batteryLevel: map['battery_level'],
      synced: map['synced'] == 1,
    );
  }
}
```

### Create lib/models/stress_alert.dart

```dart
class StressAlert {
  final String alertId;
  final DateTime triggeredAt;
  final int stressLevel;
  final int? durationMinutes;
  final String alertType;
  final String status;
  final String? message;
  final String? recommendedAction;
  
  StressAlert({
    required this.alertId,
    required this.triggeredAt,
    required this.stressLevel,
    this.durationMinutes,
    required this.alertType,
    required this.status,
    this.message,
    this.recommendedAction,
  });
  
  factory StressAlert.fromJson(Map<String, dynamic> json) {
    return StressAlert(
      alertId: json['alert_id'],
      triggeredAt: DateTime.parse(json['triggered_at']),
      stressLevel: json['stress_level'],
      durationMinutes: json['duration_minutes'],
      alertType: json['alert_type'],
      status: json['status'],
      message: json['message'],
      recommendedAction: json['recommended_action'],
    );
  }
}
```

---

## Step 4: Local Database Service

### Create lib/services/local_storage_service.dart

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/vital_reading.dart';

class LocalStorageService {
  static Database? _database;
  static final LocalStorageService _instance = LocalStorageService._internal();
  
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'hfc_local.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create vitals table
        await db.execute('''
          CREATE TABLE vitals (
            id TEXT PRIMARY KEY,
            timestamp INTEGER NOT NULL,
            heart_rate INTEGER,
            spo2 INTEGER,
            systolic_bp INTEGER,
            diastolic_bp INTEGER,
            skin_temp REAL,
            steps INTEGER,
            battery_level INTEGER,
            synced INTEGER DEFAULT 0
          )
        ''');
        
        // Create HRV table
        await db.execute('''
          CREATE TABLE hrv_data (
            id TEXT PRIMARY KEY,
            timestamp INTEGER NOT NULL,
            sdnn REAL,
            tp REAL,
            lf REAL,
            hf REAL,
            vlf REAL,
            lf_hf_ratio REAL,
            synced INTEGER DEFAULT 0
          )
        ''');
        
        // Create indexes
        await db.execute('CREATE INDEX idx_vitals_synced ON vitals(synced)');
        await db.execute('CREATE INDEX idx_hrv_synced ON hrv_data(synced)');
      },
    );
  }
  
  // Save vital reading
  Future<void> saveVital(VitalReading vital) async {
    final db = await database;
    await db.insert(
      'vitals',
      vital.toLocalDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // Get unsynced vitals
  Future<List<VitalReading>> getUnsyncedVitals({int limit = 100}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'vitals',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    
    return List.generate(maps.length, (i) => VitalReading.fromLocalDb(maps[i]));
  }
  
  // Mark vitals as synced
  Future<void> markVitalsAsSynced(List<String> ids) async {
    final db = await database;
    await db.update(
      'vitals',
      {'synced': 1},
      where: 'id IN (${ids.map((_) => '?').join(',')})',
      whereArgs: ids,
    );
  }
  
  // Clean old synced data (keep last 7 days)
  Future<void> cleanOldData() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));
    
    await db.delete(
      'vitals',
      where: 'synced = 1 AND timestamp < ?',
      whereArgs: [sevenDaysAgo.millisecondsSinceEpoch],
    );
  }
}
```

---

## Step 5: API Service

### Create lib/services/api_service.dart

```dart
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/vital_reading.dart';
import '../models/stress_alert.dart';
import 'auth_service.dart';

class ApiService {
  final Dio _dio;
  final AuthService _authService;
  
  ApiService(this._authService)
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
        )) {
    _setupInterceptors();
  }
  
  void _setupInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add auth token
        final token = await _authService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try to refresh token
          final refreshed = await _authService.refreshToken();
          if (refreshed) {
            // Retry original request
            return handler.resolve(await _retry(error.requestOptions));
          }
        }
        return handler.next(error);
      },
    ));
  }
  
  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
  
  // Upload vitals
  Future<bool> uploadVitals(String deviceMac, List<VitalReading> readings) async {
    try {
      final response = await _dio.post(
        ApiConfig.uploadVitals,
        data: {
          'device_mac': deviceMac,
          'readings': readings.map((r) => r.toJson()).toList(),
        },
      );
      return response.data['success'] == true;
    } on DioException catch (e) {
      print('Error uploading vitals: ${e.message}');
      return false;
    }
  }
  
  // Upload HRV data
  Future<Map<String, dynamic>?> uploadHrvData(
    String deviceMac,
    List<Map<String, dynamic>> readings,
  ) async {
    try {
      final response = await _dio.post(
        ApiConfig.uploadHrv,
        data: {
          'device_mac': deviceMac,
          'readings': readings,
        },
      );
      
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } on DioException catch (e) {
      print('Error uploading HRV: ${e.message}');
      return null;
    }
  }
  
  // Get active alerts
  Future<List<StressAlert>> getActiveAlerts() async {
    try {
      final response = await _dio.get(ApiConfig.activeAlerts);
      
      if (response.data['success'] == true) {
        final alerts = response.data['data'] as List;
        return alerts.map((json) => StressAlert.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      print('Error fetching alerts: ${e.message}');
      return [];
    }
  }
  
  // Respond to alert
  Future<Map<String, dynamic>?> respondToAlert(
    String alertId,
    String action,
    {int? vasRating, String? notes}
  ) async {
    try {
      final response = await _dio.post(
        ApiConfig.respondToAlert(alertId),
        data: {
          'action': action,
          if (vasRating != null) 'vas_rating': vasRating,
          if (notes != null) 'notes': notes,
        },
      );
      
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } on DioException catch (e) {
      print('Error responding to alert: ${e.message}');
      return null;
    }
  }
  
  // Mark breathing complete
  Future<bool> markBreathingComplete(
    String alertId,
    int durationSeconds,
    int postVas,
  ) async {
    try {
      final response = await _dio.post(
        ApiConfig.breathingComplete(alertId),
        data: {
          'completed': true,
          'duration_seconds': durationSeconds,
          'post_exercise_vas': postVas,
        },
      );
      return response.data['success'] == true;
    } on DioException catch (e) {
      print('Error marking breathing complete: ${e.message}');
      return false;
    }
  }
}
```

---

## Step 6: Background Sync Service

### Create lib/services/data_sync_service.dart

```dart
import 'dart:async';
import 'package:workmanager/workmanager.dart';
import 'local_storage_service.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'device_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('[Background] Starting data sync...');
      
      final localStorage = LocalStorageService();
      final authService = AuthService();
      final apiService = ApiService(authService);
      final deviceService = DeviceService();
      
      // Get device MAC
      final deviceMac = await deviceService.getStoredDeviceMac();
      if (deviceMac == null) {
        print('[Background] No device MAC found');
        return false;
      }
      
      // Get unsynced vitals
      final unsyncedVitals = await localStorage.getUnsyncedVitals(limit: 50);
      print('[Background] Found ${unsyncedVitals.length} unsynced vitals');
      
      if (unsyncedVitals.isNotEmpty) {
        final success = await apiService.uploadVitals(deviceMac, unsyncedVitals);
        
        if (success) {
          await localStorage.markVitalsAsSynced(
            unsyncedVitals.map((v) => v.id!).toList(),
          );
          print('[Background] Successfully synced ${unsyncedVitals.length} vitals');
        }
      }
      
      // Clean old data
      await localStorage.cleanOldData();
      
      return true;
    } catch (e) {
      print('[Background] Sync error: $e');
      return false;
    }
  });
}

class DataSyncService {
  static const String syncTaskName = 'com.hfc.data_sync';
  
  static void initialize() {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    
    // Register periodic sync (every 15 minutes)
    Workmanager().registerPeriodicTask(
      syncTaskName,
      syncTaskName,
      frequency: Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: Duration(minutes: 1),
    );
  }
  
  static Future<void> syncNow() async {
    await Workmanager().registerOneOffTask(
      'sync_now_${DateTime.now().millisecondsSinceEpoch}',
      syncTaskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
```

---

## Step 7: Device Service Integration

### Create lib/services/device_service.dart

```dart
import 'dart:async';
import 'package:hc20/hc20.dart';
import 'package:uuid/uuid.dart';
import '../config/nitto_config.dart';
import '../models/vital_reading.dart';
import 'local_storage_service.dart';
import 'api_service.dart';

class DeviceService {
  Hc20Client? _client;
  Hc20Device? _connectedDevice;
  StreamSubscription? _realtimeSubscription;
  
  final LocalStorageService _localStorage = LocalStorageService();
  final ApiService _apiService;
  
  DeviceService(this._apiService);
  
  // Initialize HC20 client
  Future<void> initialize() async {
    _client = await Hc20Client.create(
      config: Hc20Config(
        clientId: NittoConfig.clientId,
        clientSecret: NittoConfig.clientSecret,
      ),
    );
  }
  
  // Scan for devices
  Stream<Hc20Device> scan() {
    if (_client == null) throw Exception('Client not initialized');
    return _client!.scan();
  }
  
  // Connect to device
  Future<bool> connect(Hc20Device device) async {
    try {
      if (_client == null) throw Exception('Client not initialized');
      
      await _client!.connect(device);
      _connectedDevice = device;
      
      // Set time
      final now = DateTime.now();
      await _client!.setTime(
        device,
        timestamp: now.millisecondsSinceEpoch ~/ 1000,
        timezone: 5, // IST = UTC+5:30, use 5 or 6
      );
      
      // Start realtime stream
      _startRealtimeStream(device);
      
      return true;
    } catch (e) {
      print('Connection error: $e');
      return false;
    }
  }
  
  // Start realtime data stream
  void _startRealtimeStream(Hc20Device device) {
    _realtimeSubscription = _client!.realtimeV2(device).listen(
      (data) async {
        // Convert to VitalReading
        final vital = VitalReading(
          id: Uuid().v4(),
          timestamp: DateTime.now(),
          heartRate: data.heart,
          spo2: data.spo2,
          systolicBp: data.bp?[0],
          diastolicBp: data.bp?[1],
          skinTemp: data.temperature != null && data.temperature!.isNotEmpty
              ? data.temperature![0] / 100.0
              : null,
          steps: data.basicData?[0],
          batteryLevel: data.battery?.percent,
        );
        
        // Save to local DB
        await _localStorage.saveVital(vital);
        
        // Try to sync immediately if connected
        _trySyncVitals();
      },
      onError: (error) {
        print('Realtime stream error: $error');
      },
    );
  }
  
  // Try to sync vitals
  Future<void> _trySyncVitals() async {
    final deviceMac = await getStoredDeviceMac();
    if (deviceMac == null) return;
    
    final unsynced = await _localStorage.getUnsyncedVitals(limit: 20);
    if (unsynced.isEmpty) return;
    
    final success = await _apiService.uploadVitals(deviceMac, unsynced);
    if (success) {
      await _localStorage.markVitalsAsSynced(
        unsynced.map((v) => v.id!).toList(),
      );
    }
  }
  
  // Disconnect
  Future<void> disconnect() async {
    if (_client != null && _connectedDevice != null) {
      await _realtimeSubscription?.cancel();
      await _client!.disconnect(_connectedDevice!);
      _connectedDevice = null;
    }
  }
  
  // Get stored device MAC
  Future<String?> getStoredDeviceMac() async {
    // Implement using SharedPreferences
    return null; // Placeholder
  }
}
```

---

## Step 8: Main App Entry Point

### Update lib/main.dart

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/data_sync_service.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/device_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize background sync
  DataSyncService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ProxyProvider<AuthService, ApiService>(
          update: (_, auth, __) => ApiService(auth),
        ),
        ProxyProvider<ApiService, DeviceService>(
          update: (_, api, __) => DeviceService(api),
        ),
      ],
      child: MaterialApp(
        title: 'HFC Wellness',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return FutureBuilder<bool>(
      future: authService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.data == true) {
          return DashboardScreen();
        }
        
        return LoginScreen();
      },
    );
  }
}
```

---

## Step 9: Push Notifications Setup

### Firebase Configuration

1. Add Firebase to your Flutter project
2. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
3. Configure Firebase Cloud Messaging

### Create lib/services/notification_service.dart

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  Future<void> initialize() async {
    // Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Get FCM token
    final token = await _fcm.getToken();
    print('FCM Token: $token');
    // Send this token to your backend
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
  }
  
  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message: ${message.notification?.title}');
    
    // Show local notification
    _showLocalNotification(
      message.notification?.title ?? 'Alert',
      message.notification?.body ?? '',
      message.data,
    );
  }
  
  void _handleBackgroundMessage(RemoteMessage message) {
    print('Background message opened: ${message.notification?.title}');
    // Navigate to appropriate screen based on message.data
  }
  
  Future<void> _showLocalNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'stress_alerts',
      'Stress Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const iosDetails = DarwinNotificationDetails();
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      0,
      title,
      body,
      details,
      payload: data['alert_id'],
    );
  }
}
```

---

## Step 10: Testing Checklist

### Device Connection Testing
```dart
// Test device connection
await deviceService.initialize();
await deviceService.connect(device);
// Verify realtime data is flowing
```

### Data Upload Testing
```dart
// Test manual data upload
final vitals = [/* sample readings */];
final success = await apiService.uploadVitals(deviceMac, vitals);
assert(success == true);
```

### Background Sync Testing
```dart
// Trigger background sync
await DataSyncService.syncNow();
// Check if data was synced
final remaining = await localStorage.getUnsyncedVitals();
assert(remaining.isEmpty);
```

---

## Step 11: Build & Deploy

### Android Build
```bash
flutter build apk --release
# Or
flutter build appbundle --release
```

### iOS Build
```bash
flutter build ios --release
```

### Testing on Real Device
```bash
flutter run --release
```

---

## Common Issues & Solutions

**Issue**: Background sync not working  
**Solution**: Ensure Workmanager is properly initialized and Android permissions are granted

**Issue**: API calls failing with 401  
**Solution**: Check if token is expired, implement proper token refresh

**Issue**: Device disconnects frequently  
**Solution**: Implement auto-reconnect logic in DeviceService

**Issue**: High battery drain  
**Solution**: Reduce data upload frequency, use batch uploads

---

## Performance Optimization Tips

1. **Batch API Requests**: Send 20-50 vitals at once instead of individually
2. **Local Caching**: Store last 7 days locally, upload incrementally
3. **Compress Data**: Consider gzip compression for large HRV/RRI uploads
4. **Background Limits**: Don't sync more than every 15 minutes
5. **Connection Pooling**: Reuse HTTP connections in Dio

---

This completes the mobile app implementation guide. Follow these steps sequentially for best results.
