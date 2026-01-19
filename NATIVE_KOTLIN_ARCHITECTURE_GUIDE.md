# Native Kotlin Architecture Guide - HFC App HC20 Integration

**Date:** January 18, 2026  
**Purpose:** Complete guide for using NativeHC20Service as the single source of truth for HC20 device monitoring

---

## Table of Contents

1. [Current Architecture Analysis](#current-architecture-analysis)
2. [Key Questions & Answers](#key-questions--answers)
3. [Recommended Architecture](#recommended-architecture)
4. [Implementation Guide](#implementation-guide)
5. [Components to Remove](#components-to-remove)
6. [Benefits & Trade-offs](#benefits--trade-offs)

---

## Current Architecture Analysis

### Current State (Duplicate Services Issue)

```
┌─────────────────────────────────────────────────┐
│         WHEN APP IS OPEN (Foreground)           │
├─────────────────────────────────────────────────┤
│  Flutter SDK (Dart)                             │
│  ✓ Connects to HC20 via BLE                     │
│  ✓ Receives realtime data                       │
│  ✓ Sends webhooks every 120s                    │
│  ✓ Updates UI with live data                    │
│                                                  │
│  NativeHC20Service (Kotlin)                     │
│  ✓ ALSO connects to HC20 via BLE               │
│  ✓ ALSO receives realtime data                  │
│  ✓ ALSO sends webhooks every 120s               │
│  ✓ Running in background simultaneously         │
│                                                  │
│  ❌ PROBLEM: Duplicate webhooks!                │
│  ❌ PROBLEM: Two BLE connections to same device │
│  ❌ PROBLEM: Wasted battery & resources         │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│        WHEN APP IS CLOSED (Background)          │
├─────────────────────────────────────────────────┤
│  Flutter Engine: DEAD ❌                        │
│  (Dies when app is swiped away)                 │
│                                                  │
│  NativeHC20Service (Kotlin)                     │
│  ✓ Still running (ForegroundService)            │
│  ✓ Connects to HC20 via BLE                     │
│  ✓ Sends webhooks every 120s                    │
│  ✓ Auto-reconnects when needed                  │
│  ✓ Survives app swipe ✓                         │
└─────────────────────────────────────────────────┘
```

---

## Key Questions & Answers

### Q1: Can Native Kotlin webhook kill or stop Flutter webhook data send?

**Answer: NO - They operate INDEPENDENTLY and both run simultaneously**

#### How They Work:

**Flutter Webhooks (when app is OPEN):**
- Location: `lib/main.dart` → `_startRealtimeDataStream()` → `_sendDataToWebhook()`
- Trigger: Timer every **120 seconds** via `_dataRefreshTimer`
- Data flow: HC20 SDK (Dart) → Parse data → Send to webhook
- Lifespan: **Stops when app is swiped away** (Flutter engine dies)

**Native Kotlin Webhooks (when app is CLOSED):**
- Location: `android/app/src/main/kotlin/com/example/hfc_app/NativeHC20Service.kt`
- Trigger: Timer every **120 seconds** (`WEBHOOK_INTERVAL_MS = 120000L`)
- Data flow: Native BLE → Native parser → Send to webhook
- Lifespan: **Survives app swipe** (ForegroundService + WakeLock)

#### Current Issue: BOTH running simultaneously when app is open!

**Consequences:**
- ❌ **Duplicate webhooks** sent to same URL every 2 minutes
- ❌ Unnecessary battery drain (two BLE connections)
- ❌ Backend receives 2 webhooks for same data
- ❌ Confusion in logs and data analysis

**Solution Options:**

**Option 1: Native checks if app is in foreground**
```kotlin
// In NativeHC20Service.kt
private fun isAppInForeground(): Boolean {
    val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    val appProcesses = activityManager.runningAppProcesses ?: return false
    
    return appProcesses.any { 
        it.processName == packageName && 
        it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND 
    }
}

private fun sendWebhook(trigger: String = "periodic") {
    if (isAppInForeground()) {
        Log.d(TAG, "⏭️ App in foreground - skipping Native webhook to avoid duplicates")
        return
    }
    // ... continue with webhook
}
```

**Option 2: Always use Native service (RECOMMENDED ✅)**
- Remove Flutter webhook sending completely
- Native service is ONLY webhook sender
- Consistent data source
- No gaps when switching between states

---

### Q2: Is Native Kotlin service enough to process data either app open or closed?

**Answer: YES ✅ - Native Kotlin service is FULLY INDEPENDENT and handles everything**

#### What NativeHC20Service Does:

✅ **Scans for HC20 devices**
- Continuous scanning every 30s when disconnected
- See: `HC20NativeBleManager.kt` → `startScan()`

✅ **Connects via native BLE**
- Uses Android `BluetoothGatt` directly
- No Flutter dependency
- Service UUID: `FFF0`, Notify Char: `FFF1`, Write Char: `FFF2`

✅ **Parses HC20 protocol frames**
- Native Kotlin parser in `HC20Protocol.kt`
- Extracts: `heart_rate`, `spo2`, `bp`, `temperature`, `battery`, `steps`, `hrv`, `hrv2`, etc.
- Frame format: Header `0x68`, Function `0x05→0x85`, JSON payload, Tail `0x16`

✅ **Sends webhooks**
- Every 2 minutes (120,000ms)
- Uses OkHttp (native HTTP client)
- Matches Flutter webhook format exactly
- Endpoint: `https://api.hireforcare.com/webhook/hc20-data`

✅ **Auto-reconnects**
- Health check every 60s
- Detects stale data (>45s old)
- Forces disconnect → reconnect to restore BLE notifications
- Infinite retry attempts
- Continuous scanning when disconnected

✅ **Survives app lifecycle events**
- ForegroundService with persistent notification
- `PARTIAL_WAKE_LOCK` keeps CPU running for BLE
- Works when screen is OFF
- Works when app is CLOSED/SWIPED
- Immune to Doze mode (foreground service exemption)

✅ **No Flutter dependency**
- Pure Kotlin + Android SDK APIs
- Runs independently of Flutter engine state

#### Current Implementation Status:

**Files:**
- ✅ `NativeHC20Service.kt` - Main service (721 lines)
- ✅ `HC20NativeBleManager.kt` - BLE operations (670 lines)
- ✅ `HC20Protocol.kt` - Frame parser (510 lines)
- ✅ `ForegroundService.kt` - Starts Native service on swipe (697 lines)

**However, current implementation has OVERLAP:**
- When app is OPEN: Flutter also connects to device
- When app is OPEN: Both Flutter + Native send webhooks
- **Solution:** Use Native service exclusively OR detect app state

---

### Q3: If Native Kotlin is enough, what components are NOT required?

#### ❌ CAN BE REMOVED (Redundant Components):

**1. HeadlessFlutterService** ❌
- **Location:** `android/app/src/main/kotlin/com/example/hfc_app/HeadlessFlutterService.kt`
- **Purpose:** Runs Flutter engine in background (doesn't survive swipe)
- **Status:** Already removed from `ForegroundService.kt`
- **Reason:** Native Kotlin replaces this completely. Flutter engine ALWAYS dies on swipe.

**2. MainEngineKeepAliveService** ❌
- **Location:** `lib/services/main_engine_keepalive_service.dart`
- **Purpose:** Tries to keep Flutter engine alive in background
- **Why it fails:** Android OS kills Flutter engine when app is swiped, regardless of this service
- **Reason:** Native Kotlin handles background operation without Flutter

**3. AppKeepaliveService** ❌
- **Location:** `lib/services/app_keepalive_service.dart`
- **Purpose:** Uses AlarmManager to restart app every 10 minutes
- **Reason:** Not needed - ForegroundService already keeps service alive 24/7

**4. BackgroundSyncService** ❌
- **Location:** `lib/services/background_sync_service.dart`
- **Purpose:** Uses WorkManager for background tasks
- **Reason:** Native service handles all background work directly

**5. BackgroundIsolateService** ❌
- **Location:** `lib/services/background_isolate_service.dart`
- **Purpose:** Dart isolate for background processing
- **Reason:** Native service runs independently, doesn't need Dart isolates

**6. AppRestartWorker** ❌ (Optional)
- **Location:** `android/app/src/main/kotlin/com/example/hfc_app/AppRestartWorker.kt`
- **Purpose:** WorkManager to restart app UI every 15 minutes
- **Decision:** 
  - REMOVE if you don't need app UI to auto-reopen
  - KEEP if you want periodic UI updates for user

**7. OverlayLauncher** ❌ (Optional)
- **Location:** `android/app/src/main/kotlin/com/example/hfc_app/OverlayLauncher.kt`
- **Purpose:** Display overlay when screen is ON to restart app
- **Decision:** REMOVE if background monitoring alone is sufficient

**8. Flutter Webhook Code in main.dart** ❌
- **Location:** `lib/main.dart` → `_startRealtimeDataStream()` → `_sendDataToWebhook()`
- **Lines:** ~1450-2300
- **Reason:** Native service sends webhooks, no need for Flutter to also send

#### ✅ MUST KEEP (Essential Components):

**1. NativeHC20Service** ✅ **CRITICAL**
- **Location:** `android/app/src/main/kotlin/com/example/hfc_app/NativeHC20Service.kt`
- **Purpose:** Main background service that survives app swipe
- **Reason:** This IS the solution - handles everything

**2. HC20NativeBleManager** ✅ **CRITICAL**
- **Location:** `android/app/src/main/kotlin/com/example/hfc_app/HC20NativeBleManager.kt`
- **Purpose:** Native BLE operations (scan, connect, notifications)
- **Reason:** Handles device communication

**3. HC20Protocol** ✅ **CRITICAL**
- **Location:** `android/app/src/main/kotlin/com/example/hfc_app/HC20Protocol.kt`
- **Purpose:** Parses HC20 frame format and extracts health data
- **Reason:** Protocol implementation for data extraction

**4. ForegroundService** ✅ **KEEP** (Modified)
- **Location:** `android/app/src/main/kotlin/com/example/hfc_app/ForegroundService.kt`
- **Purpose:** Starts NativeHC20Service when app is swiped away
- **Reason:** Bridge between app lifecycle and native service

**5. Flutter App UI** ✅ **KEEP** (Minimal)
- **Location:** `lib/main.dart`, `lib/pages/login_page.dart`
- **Purpose:** User interface for initial device setup
- **Reason:** Users need UI to:
  - Login with phone number
  - Scan and select HC20 device
  - View service status (optional)

---

## Recommended Architecture

### Single Native Service Architecture (OPTIMAL ✅)

```
┌─────────────────────────────────────────────────────────┐
│  MINIMAL FLUTTER UI (One-Time Setup Only)              │
│  ------------------------------------------------       │
│  1. Login Page (get user phone)                        │
│  2. Device Selection Page (scan & select HC20)         │
│  3. [Save deviceId + phone to SharedPreferences]       │
│  4. START NativeHC20Service                            │
│  5. [Optional] Show "Service Running" status page      │
│                                                         │
│  ✓ NO Flutter BLE connection                           │
│  ✓ NO Flutter webhook sending                          │
│  ✓ Flutter just configures & starts Native service     │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  NATIVE HC20 SERVICE (Runs Forever)                    │
│  ------------------------------------------------       │
│  1. Read deviceId + phone from SharedPreferences       │
│  2. Scan for device (every 30s until found)            │
│  3. Auto-connect via native BLE                        │
│  4. Parse HC20 frames (native Kotlin)                  │
│  5. Send webhooks (every 2 min)                        │
│  6. Auto-reconnect (infinite)                          │
│  7. Health check (every 60s)                           │
│                                                         │
│  ✓ Works when app OPEN                                 │
│  ✓ Works when app CLOSED                               │
│  ✓ Works when screen OFF                               │
│  ✓ Survives app swipe                                  │
│  ✓ No Flutter dependency                               │
│  ✓ Single source of truth                              │
└─────────────────────────────────────────────────────────┘
```

### Data Flow:

```
User Opens App (First Time)
    ↓
Login Page → Enter Phone Number
    ↓
Device Selection Page → Scan for HC20
    ↓
User Selects Device → Save to SharedPreferences
    ↓
Start NativeHC20Service via MethodChannel
    ↓
Service Reads deviceId + phone from SharedPreferences
    ↓
Service Scans for Device (every 30s)
    ↓
Service Auto-Connects via BLE
    ↓
Service Receives Notifications (0x85 frames)
    ↓
Service Parses JSON Payload
    ↓
Service Sends Webhook (every 2 min)
    ↓
[User Can Close App - Service Continues]
    ↓
Service Monitors Health (every 60s)
    ↓
If Stale Data (>45s) → Disconnect → Reconnect
    ↓
Loop Forever ♾️
```

---

## Implementation Guide

### Step 1: Create Minimal Flutter UI for Device Setup

Create: `lib/pages/device_setup_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hc20/hc20.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceSetupPage extends StatefulWidget {
  final String userPhone;
  
  const DeviceSetupPage({required this.userPhone, super.key});

  @override
  State<DeviceSetupPage> createState() => _DeviceSetupPageState();
}

class _DeviceSetupPageState extends State<DeviceSetupPage> {
  static const platform = MethodChannel('com.hfc.app/native_service');
  
  Hc20Client? _client;
  List<Hc20Device> _devices = [];
  bool _isScanning = false;
  bool _serviceStarted = false;

  @override
  void initState() {
    super.initState();
    _checkExistingSetup();
  }

  Future<void> _checkExistingSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDeviceId = prefs.getString('flutter.last_connected_device_id');
    
    if (savedDeviceId != null) {
      // Device already configured - start service directly
      await _startNativeService(savedDeviceId);
      setState(() => _serviceStarted = true);
    }
  }

  Future<void> _scanDevices() async {
    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    _client = Hc20Client();
    
    try {
      await for (final device in _client!.scan(timeout: Duration(seconds: 10))) {
        if (!_devices.any((d) => d.id == device.id)) {
          setState(() => _devices.add(device));
        }
      }
    } catch (e) {
      print('Scan error: $e');
    }

    setState(() => _isScanning = false);
  }

  Future<void> _selectDevice(Hc20Device device) async {
    // Save device info to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flutter.last_connected_device_id', device.id);
    await prefs.setString('flutter.user_phone', widget.userPhone);
    
    // Start Native service
    await _startNativeService(device.id);
    
    setState(() => _serviceStarted = true);
  }

  Future<void> _startNativeService(String deviceId) async {
    try {
      await platform.invokeMethod('startNativeService', {
        'deviceId': deviceId,
        'userPhone': widget.userPhone,
      });
      
      print('✅ Native HC20 Service started!');
    } catch (e) {
      print('❌ Failed to start native service: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_serviceStarted) {
      return Scaffold(
        appBar: AppBar(
          title: Text('HC20 Monitor'),
          backgroundColor: Colors.green,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 100),
              SizedBox(height: 30),
              Text(
                '✓ Service Running',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 15),
              Text(
                'HC20 monitoring is active in background',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 50),
              Container(
                padding: EdgeInsets.all(20),
                margin: EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    Text(
                      '📱 You can close the app now',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'The service will continue monitoring HC20 device and sending data to the server.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 50),
              ElevatedButton.icon(
                onPressed: () => setState(() => _serviceStarted = false),
                icon: Icon(Icons.settings),
                label: Text('Change Device'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Select HC20 Device'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Scan for your HC20 wearable device',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanDevices,
                  icon: Icon(_isScanning ? Icons.hourglass_empty : Icons.bluetooth_searching),
                  label: Text(_isScanning ? 'Scanning...' : 'Start Scanning'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
              ],
            ),
          ),
          Divider(),
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth_disabled, size: 60, color: Colors.grey),
                        SizedBox(height: 15),
                        Text(
                          'No devices found',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap "Start Scanning" to search',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.watch, color: Colors.white),
                          ),
                          title: Text(
                            device.name,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(device.id),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () => _selectDevice(device),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }
}
```

### Step 2: Update MainActivity.kt with MethodChannel

Add to `android/app/src/main/kotlin/com/example/hfc_app/MainActivity.kt`:

```kotlin
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    
    // Add MethodChannel for Native Service control
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hfc.app/native_service")
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "startNativeService" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val userPhone = call.argument<String>("userPhone")
                    
                    if (deviceId != null && userPhone != null) {
                        // Save to SharedPreferences
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        prefs.edit().apply {
                            putString("flutter.last_connected_device_id", deviceId)
                            putString("flutter.user_phone", userPhone)
                            apply()
                        }
                        
                        // Start native service
                        NativeHC20Service.start(applicationContext, deviceId, userPhone)
                        
                        Log.d(TAG, "✅ Native service started: device=$deviceId, phone=$userPhone")
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Device ID and phone required", null)
                    }
                }
                
                "stopNativeService" -> {
                    NativeHC20Service.stop(applicationContext)
                    Log.d(TAG, "🛑 Native service stopped")
                    result.success(true)
                }
                
                "isServiceRunning" -> {
                    val running = NativeHC20Service.isRunning()
                    result.success(running)
                }
                
                else -> result.notImplemented()
            }
        }
}
```

### Step 3: Simplify main.dart

Update `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/device_setup_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // REMOVED: All background services (not needed anymore)
  // - MainEngineKeepAliveService ❌
  // - AppKeepaliveService ❌
  // - BackgroundSyncService ❌
  // - WorkManager ❌
  // - AlarmManager ❌
  
  final authService = AuthService();
  
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
      title: 'HFC App - HC20 Setup',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Consumer<AuthService>(
        builder: (context, authService, child) {
          if (!authService.isAuthenticated) {
            return const LoginPage();
          }
          // After login, go directly to device setup page
          return DeviceSetupPage(
            userPhone: authService.currentUser!.phone,
          );
        },
      ),
    );
  }
}
```

### Step 4: Update NativeHC20Service (Always Run)

Modify `android/app/src/main/kotlin/com/example/hfc_app/NativeHC20Service.kt`:

```kotlin
/**
 * Send webhook to backend
 * ALWAYS sends - this is the SINGLE SOURCE OF TRUTH
 * No need to check if app is in foreground (consistent behavior)
 */
private fun sendWebhook(trigger: String = "periodic") {
    // Don't check if app is in foreground - always send
    // This ensures consistent data source regardless of app state
    
    if (userPhone == null) {
        Log.w(TAG, "⚠️ No user phone configured, skipping webhook")
        return
    }
    
    // ... rest of webhook code (unchanged)
}
```

### Step 5: Update ForegroundService

Ensure `ForegroundService.kt` starts NativeHC20Service on app swipe:

```kotlin
override fun onTaskRemoved(rootIntent: Intent?) {
    super.onTaskRemoved(rootIntent)
    
    // Get saved device info
    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    val deviceId = prefs.getString("flutter.last_connected_device_id", null)
    val userPhone = prefs.getString("flutter.user_phone", null)
    
    if (deviceId != null && userPhone != null) {
        // Start Native HC20 Service
        NativeHC20Service.start(applicationContext, deviceId, userPhone)
        Log.d(TAG, "✅ Native HC20 Service started after app swipe")
    } else {
        Log.w(TAG, "⚠️ No device configured, cannot start native service")
    }
    
    // Stop this foreground service (Native service takes over)
    stopSelf()
}
```

---

## Components to Remove

### Files to Delete:

```bash
# Dart/Flutter services (not needed)
rm lib/services/main_engine_keepalive_service.dart
rm lib/services/app_keepalive_service.dart
rm lib/services/background_sync_service.dart
rm lib/services/background_isolate_service.dart

# Kotlin services (redundant)
rm android/app/src/main/kotlin/com/example/hfc_app/HeadlessFlutterService.kt

# Optional (if you don't want auto-restart UI)
rm android/app/src/main/kotlin/com/example/hfc_app/AppRestartWorker.kt
rm android/app/src/main/kotlin/com/example/hfc_app/OverlayLauncher.kt
```

### Code to Remove from main.dart:

```dart
// DELETE these lines from main() function:

// ❌ Remove Main Engine Keep-Alive
await MainEngineKeepAliveService.initialize();

// ❌ Remove Exact Alarm Permission check
await _checkExactAlarmPermission();

// ❌ Remove AlarmManager initialization
await AppKeepaliveService.initialize();
await AppKeepaliveService.startPeriodicKeepalive();

// ❌ Remove WorkManager initialization
await BackgroundSyncService.initialize();

// ❌ Remove Alarm scheduling test
await _testAlarmScheduling();

// ❌ Remove App active marker
await AppKeepaliveService.markAppActive();
```

### Code to Remove from HC20HomePage (main.dart):

Remove or comment out the Flutter HC20 connection and webhook code:

```dart
// Lines ~1450-2300 in main.dart

// ❌ Remove _startRealtimeDataStream() - Native service handles this
// ❌ Remove _sendDataToWebhook() - Native service sends webhooks
// ❌ Remove _dataRefreshTimer - Native service has its own timer
// ❌ Remove Flutter BLE connection code
```

---

## Benefits & Trade-offs

### ✅ Advantages:

1. **No Duplicate Webhooks**
   - Only Native service sends data
   - Consistent data source
   - Clean backend logs

2. **Minimal Flutter Code**
   - Simple UI for device setup
   - No complex background logic
   - Easier to maintain

3. **No Background Service Complexity**
   - No WorkManager
   - No AlarmManager
   - No HeadlessFlutter
   - No isolates

4. **Consistent Behavior**
   - Same code path whether app open or closed
   - Predictable data flow
   - Easier debugging

5. **Better Battery Efficiency**
   - Single BLE connection
   - Single webhook sender
   - No Flutter engine overhead in background

6. **Easier Debugging**
   - All logic in one place (Native service)
   - Single source of logs
   - Clear data flow

7. **User-Friendly**
   - Simple one-time setup
   - App can be closed after setup
   - No confusing UI states

8. **Survives All Android Restrictions**
   - Doze mode: ✓ (ForegroundService exempt)
   - App swipe: ✓ (Service continues)
   - Battery optimization: ✓ (WakeLock)
   - Screen off: ✓ (WakeLock)

### ⚠️ Trade-offs:

1. **No Real-Time UI Updates**
   - User won't see live heart rate in Flutter app
   - **Solution:** Add optional "Status Page" that queries service state via MethodChannel
   - **Query Example:**
     ```kotlin
     "getCurrentData" -> {
         val data = lastRealtimeData
         val json = mapOf(
             "heartRate" to data?.heartRate,
             "spo2" to data?.spo2,
             "connected" to bleManager.isConnected()
         )
         result.success(json)
     }
     ```

2. **First Connection Needs UI**
   - User must open app once to select device
   - **Solution:** This is normal - all apps need initial setup
   - Only required once (device info saved)

3. **Can't Use Flutter HC20 SDK Features**
   - SDK has advanced features (HRV fetch, temperature history, etc.)
   - **Solution:** Add these to Native Kotlin if needed
   - Or: Create hybrid approach (Native for realtime, Flutter for advanced features)

4. **No Flutter Widget Tests for Data Flow**
   - Data logic is in Kotlin, not testable with Flutter tests
   - **Solution:** Write Android instrumentation tests for Native service

---

## User Experience Flow

### First Time Setup:
```
1. User opens app
   ↓
2. Login with phone number
   ↓
3. Device Setup Page → Tap "Start Scanning"
   ↓
4. Select HC20 device from list
   ↓
5. App shows "✓ Service Running"
   ↓
6. User closes app (Native service continues)
```

### After Setup (Forever):
```
1. Native service runs 24/7 in background
   ↓
2. Auto-connects to saved device
   ↓
3. Sends webhooks every 2 minutes
   ↓
4. Auto-reconnects if disconnected
   ↓
5. Works with app closed
   ↓
6. No user interaction needed
```

### If User Wants to View Live Data (Optional):
```
1. Open app
   ↓
2. See "Service Running ✓" status
   ↓
3. [Optional] Add "View Live Data" button
   ↓
4. Query Native service via MethodChannel
   ↓
5. Display current values in UI
   ↓
6. (Don't create second BLE connection!)
```

---

## Testing Checklist

### ✅ Test Scenarios:

- [ ] **First install:** User can login and select device
- [ ] **Device selection:** Scanner finds HC20 devices
- [ ] **Service start:** Native service starts successfully
- [ ] **App open:** Webhooks sent every 2 minutes
- [ ] **App swipe:** Service continues, webhooks keep sending
- [ ] **Screen off:** Service continues
- [ ] **Device disconnect:** Auto-reconnect works
- [ ] **Device off/on:** Service reconnects automatically
- [ ] **Phone restart:** Service auto-starts (if configured)
- [ ] **No duplicates:** Only one webhook per 2-minute interval
- [ ] **Battery optimization:** Service survives Doze mode
- [ ] **Change device:** User can select different device

---

## Troubleshooting

### Issue: Service not starting after app swipe
**Solution:**
1. Check `ForegroundService.onTaskRemoved()` is starting `NativeHC20Service`
2. Verify device info saved in SharedPreferences
3. Check logcat for errors: `adb logcat | grep NativeHC20`

### Issue: No webhooks being sent
**Solution:**
1. Check network connectivity
2. Verify webhook URL is correct
3. Check service is running: `adb shell dumpsys activity services | grep NativeHC20`
4. Check logcat: `adb logcat | grep "Webhook"`

### Issue: Device not connecting
**Solution:**
1. Verify BLE permissions granted
2. Check Bluetooth is enabled
3. Check device is in range
4. Check logcat: `adb logcat | grep HC20NativeBLE`

### Issue: Duplicate webhooks
**Solution:**
1. Ensure Flutter webhook code is removed/disabled
2. Verify only Native service is sending
3. Check webhook logs for source (should only see "NATIVE_KOTLIN_SERVICE")

---

## Summary

**Current State:**
- ❌ Duplicate services running simultaneously
- ❌ Duplicate webhooks when app is open
- ❌ Complex background service architecture
- ❌ Flutter engine dies on app swipe

**Recommended State:**
- ✅ Single Native service handles everything
- ✅ Minimal Flutter UI for device setup only
- ✅ No duplicate webhooks (single source of truth)
- ✅ Simple architecture (easier to maintain)
- ✅ Works 24/7 (app open or closed)
- ✅ Auto-reconnects (infinite retry)
- ✅ Survives all Android restrictions

**Key Decision:**
**Use Native Kotlin service as the ONLY data sender, with minimal Flutter UI for initial device setup.**

---

**Date Created:** January 18, 2026  
**Last Updated:** January 18, 2026  
**Version:** 1.0  
**Status:** Ready for Implementation
