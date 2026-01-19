# Complete App Relaunch Features Inventory - HFC App Codebase
## Comprehensive Checklist of ALL Implemented Components

Use this document to compare with your other codebase and identify missing pieces.

---

## 📱 PART 1: ANDROID NATIVE FILES (Kotlin/Java)

### ✅ File 1: MainActivity.kt
**Location:** `android/app/src/main/kotlin/com/example/hfc_app/MainActivity.kt`

**Features Implemented:**

1. **Lock Screen Configuration in onCreate():**
   ```kotlin
   // Lines 30-45
   - setShowWhenLocked(true)
   - setTurnScreenOn(true)
   - FLAG_SHOW_WHEN_LOCKED
   - FLAG_TURN_SCREEN_ON
   - FLAG_DISMISS_KEYGUARD
   - FLAG_KEEP_SCREEN_ON
   ```

2. **Background Launch Detection:**
   ```kotlin
   // Lines 49-63
   - Check intent.getBooleanExtra("launched_from_background")
   - Log launch reason
   - Dismiss restart notifications (ID 9998, 9999)
   ```

3. **WorkManager Scheduling:**
   ```kotlin
   // Lines 67-68
   - AppRestartWorker.schedule(applicationContext)
   ```

4. **Overlay Permission Check:**
   ```kotlin
   // Lines 71-104
   - checkAndRequestOverlayPermission()
   - Dialog to explain overlay permission
   - OverlayLauncher.hasOverlayPermission()
   - OverlayLauncher.requestOverlayPermission()
   ```

5. **MethodChannel Setup:**
   ```kotlin
   // Lines 106-111
   - AppLauncher.setupChannel(flutterEngine, applicationContext)
   - Sets up 'com.example.hfc_app/app_launcher' channel
   ```

6. **Method Handlers:**
   ```kotlin
   // Lines 113-197
   - launchApp
   - enableBackgroundExecution
   - disableBackgroundExecution
   - startNativeBleService
   - stopNativeBleService
   - updateHealthData
   - requestBatteryOptimizationExemption
   - isBatteryOptimizationDisabled
   - checkExactAlarmPermission
   - requestExactAlarmPermission
   - testAlarmScheduling
   - hasOverlayPermission
   - requestOverlayPermission
   - startNativeHC20Service
   - stopNativeHC20Service
   - isNativeHC20ServiceRunning
   ```

7. **Battery Optimization Request:**
   ```kotlin
   // Lines 290-320
   - requestBatteryOptimizationExemption()
   - Checks isIgnoringBatteryOptimizations()
   - Opens Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
   - Shows autostart guidance after battery exemption
   ```

8. **Autostart Guidance (Device-Specific):**
   ```kotlin
   // Lines 322-409
   - showAutostartGuidanceIfNeeded()
   - Detects Xiaomi, OPPO, Vivo, Realme, OnePlus
   - Opens manufacturer-specific autostart settings
   - Saves preference to not show again
   ```

9. **Exact Alarm Permission Check:**
   ```kotlin
   // Lines 411-447
   - checkExactAlarmPermission()
   - alarmManager.canScheduleExactAlarms() (Android 12+)
   - requestExactAlarmPermission()
   - Opens Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM
   ```

10. **Alarm Test Functionality:**
    ```kotlin
    // Lines 449-495
    - testAlarmScheduling()
    - Checks if keepalive alarm exists (request code 12346)
    - Checks if workmanager alarm exists (request code 12347)
    - Returns Map with results
    ```

---

### ✅ File 2: AppLauncher.kt
**Location:** `android/app/src/main/kotlin/com/example/hfc_app/AppLauncher.kt`

**Features Implemented:**

1. **MethodChannel Setup:**
   ```kotlin
   // Lines 32-65
   - Channel name: 'com.example.hfc_app/app_launcher'
   - Handler for 'launchApp'
   - Handler for 'scheduleAppRestart'
   - Handler for 'scheduleKeepaliveRestart'
   - Handler for 'cancelScheduledRestart'
   ```

2. **Notification Channel Creation:**
   ```kotlin
   // Lines 70-87
   - Channel ID: "hfc_app_restart"
   - IMPORTANCE_HIGH
   - VISIBILITY_PUBLIC for lock screen
   ```

3. **launchApp() - Multi-Strategy Launch:**
   ```kotlin
   // Lines 95-191
   - Acquire FULL_WAKE_LOCK with ACQUIRE_CAUSES_WAKEUP
   - Create notification channel
   - Build MainActivity intent with flags:
     * FLAG_ACTIVITY_NEW_TASK
     * FLAG_ACTIVITY_CLEAR_TOP
     * FLAG_ACTIVITY_SINGLE_TOP
     * FLAG_ACTIVITY_REORDER_TO_FRONT
   - Create full-screen intent PendingIntent
   - Build notification with:
     * PRIORITY_HIGH
     * CATEGORY_CALL
     * setFullScreenIntent(pendingIntent, true)
   - Post notification (ID 9999)
   - Try direct startActivity as backup
   - Release wake lock after 5 seconds
   - Dismiss notification after 5 seconds
   ```

4. **scheduleAppRestart() - Basic Alarm:**
   ```kotlin
   // Lines 197-229
   - Creates Intent for AppRestartReceiver
   - Action: "com.example.hfc_app.RESTART_APP"
   - Uses RESTART_REQUEST_CODE (12345)
   - Uses setExactAndAllowWhileIdle()
   - ELAPSED_REALTIME_WAKEUP
   - FLAG_UPDATE_CURRENT | FLAG_IMMUTABLE
   ```

5. **cancelScheduledRestart():**
   ```kotlin
   // Lines 234-252
   - Uses FLAG_NO_CREATE to check if alarm exists
   - Cancels alarm if found
   ```

6. **scheduleKeepaliveRestart() - Self-Perpetuating Alarm:**
   ```kotlin
   // Lines 257-304
   - Creates Intent for AppRestartReceiver
   - Action: "com.example.hfc_app.RESTART_APP"
   - Uses different request codes:
     * KEEPALIVE_REQUEST_CODE (12346) for "keepalive_service"
     * WORKMANAGER_REQUEST_CODE (12347) for "workmanager"
   - Adds "scheduled_by" extra
   - Uses setExactAndAllowWhileIdle()
   - ELAPSED_REALTIME_WAKEUP
   - FLAG_UPDATE_CURRENT | FLAG_IMMUTABLE
   - Works in Doze mode
   ```

7. **isAppRunning() - Activity Detection:**
   ```kotlin
   // Lines 309-312
   - Checks ActivityManager.getRunningTasks()
   - Compares topActivity package name
   ```

---

### ✅ File 3: AppRestartReceiver.kt
**Location:** `android/app/src/main/kotlin/com/example/hfc_app/AppRestartReceiver.kt`

**Features Implemented:**

1. **BroadcastReceiver for Alarm Triggers:**
   ```kotlin
   // Lines 17-26
   - Receives "com.example.hfc_app.RESTART_APP"
   - Receives Intent.ACTION_BOOT_COMPLETED
   ```

2. **Screen State Detection:**
   ```kotlin
   // Lines 28-32
   - PowerManager.isInteractive
   - Different behavior for screen ON vs OFF
   ```

3. **Screen-ON Behavior:**
   ```kotlin
   // Lines 39-60
   - Reads device info from SharedPreferences:
     * flutter.last_connected_device_id
     * flutter.user_phone
   - Starts ForegroundService only (no UI launch)
   - Uses startForegroundService() on Android 8+
   ```

4. **Screen-OFF Behavior:**
   ```kotlin
   // Lines 64-67
   - Calls AppLauncherService.start(context)
   - Launches full-screen intent
   ```

5. **Alarm Rescheduling:**
   ```kotlin
   // Lines 71-95
   - Gets "scheduled_by" from intent extras
   - Reschedules based on source:
     * "keepalive_service" → 300 seconds (5 min)
     * "workmanager" → 480 seconds (8 min)
     * default → 300 seconds
   - Calls AppLauncher.scheduleKeepaliveRestart()
   - Creates self-perpetuating cycle
   ```

6. **Boot Completed Handler:**
   ```kotlin
   // Lines 99-110
   - Starts ForegroundService with saved device
   - Reschedules keepalive alarm (300 sec)
   - Schedules WorkManager
   ```

---

### ✅ File 4: AppLauncherService.kt
**Location:** `android/app/src/main/kotlin/com/example/hfc_app/AppLauncherService.kt`

**Features Implemented:**

1. **Static start() Method:**
   ```kotlin
   // Lines 43-50
   - Creates Intent for AppLauncherService
   - Uses startForegroundService() on Android 8+
   ```

2. **Foreground Service Startup:**
   ```kotlin
   // Lines 59-72
   - Creates notification
   - Calls startForeground() immediately
   - Uses FOREGROUND_SERVICE_TYPE_DATA_SYNC on Android 10+
   ```

3. **Screen State Detection:**
   ```kotlin
   // Lines 74-77
   - PowerManager.isInteractive
   ```

4. **Wake Lock Acquisition:**
   ```kotlin
   // Lines 79-88
   - FULL_WAKE_LOCK
   - ACQUIRE_CAUSES_WAKEUP
   - ON_AFTER_RELEASE
   - 10 second timeout
   ```

5. **Launch Method Selection:**
   ```kotlin
   // Lines 90-100
   - Screen ON → launchViaOverlay()
   - Screen OFF → launchViaFullScreenIntent()
   ```

6. **Direct Launch Backup:**
   ```kotlin
   // Lines 102-118
   - Creates Intent with:
     * FLAG_ACTIVITY_NEW_TASK
     * FLAG_ACTIVITY_CLEAR_TOP
     * FLAG_ACTIVITY_SINGLE_TOP
     * FLAG_ACTIVITY_REORDER_TO_FRONT
   - Adds "launched_from_background" extra
   - Tries startActivity() as backup
   ```

7. **Cleanup After Launch:**
   ```kotlin
   // Lines 120-131
   - Handler with 5-second delay
   - Releases wake lock
   - Stops foreground service
   - Stops self
   ```

8. **launchViaOverlay() - Screen ON:**
   ```kotlin
   // Lines 137-147
   - Checks OverlayLauncher.hasOverlayPermission()
   - Calls OverlayLauncher.launchAppViaOverlay()
   - Falls back to full-screen intent if no permission
   ```

9. **launchViaFullScreenIntent() - Screen OFF:**
   ```kotlin
   // Lines 152-188
   - Creates MainActivity intent
   - Creates PendingIntent with FLAG_IMMUTABLE
   - Builds notification with:
     * PRIORITY_HIGH
     * CATEGORY_CALL
     * setFullScreenIntent(pendingIntent, true)
   - Posts notification (ID 9999)
   ```

10. **Notification Channel & Notification:**
    ```kotlin
    // Lines 190-227
    - Creates "app_launcher_service" channel
    - IMPORTANCE_HIGH
    - Builds basic notification for foreground service
    ```

---

### ✅ File 5: AppRestartWorker.kt
**Location:** `android/app/src/main/kotlin/com/example/hfc_app/AppRestartWorker.kt`

**Features Implemented:**

1. **WorkManager Scheduling:**
   ```kotlin
   // Lines 39-67
   - Schedules PeriodicWorkRequest
   - 15-minute interval (Android minimum)
   - 1-minute initial delay
   - Constraints:
     * NetworkType.NOT_REQUIRED
     * Requires battery not low: false
     * Requires charging: false
   - ExistingPeriodicWorkPolicy.KEEP
   ```

2. **Activity Detection:**
   ```kotlin
   // Lines 83-90
   - Reads from SharedPreferences:
     * flutter.last_active_timestamp
   - Calculates minutes since active
   - Threshold: 5+ minutes = app closed
   ```

3. **Screen State Check:**
   ```kotlin
   // Lines 94-99
   - PowerManager.isInteractive
   ```

4. **Screen-ON Behavior:**
   ```kotlin
   // Lines 101-127
   - Reads device info from SharedPreferences
   - Starts ForegroundService only
   - No UI launch when screen is ON
   ```

5. **Screen-OFF Behavior:**
   ```kotlin
   // Lines 129-136
   - Calls AppLauncherService.start()
   - Launches full-screen intent
   ```

6. **Statistics Logging:**
   ```kotlin
   // Lines 138-142
   - Saves last_workmanager_restart timestamp
   - Increments workmanager_restart_count
   ```

---

### ✅ File 6: OverlayLauncher.kt
**Location:** `android/app/src/main/kotlin/com/example/hfc_app/OverlayLauncher.kt`

**Features Implemented:**

1. **Overlay Permission Check:**
   ```kotlin
   // Lines 33-39
   - Settings.canDrawOverlays() on Android 6+
   - Returns true on older versions
   ```

2. **Request Overlay Permission:**
   ```kotlin
   // Lines 45-53
   - Opens Settings.ACTION_MANAGE_OVERLAY_PERMISSION
   - Uses startActivityForResult with code 1234
   ```

3. **launchAppViaOverlay() - The Magic Trick:**
   ```kotlin
   // Lines 59-155
   - Checks overlay permission first
   - Gets WindowManager service
   - Creates invisible FrameLayout (1x1 pixel)
   - WindowManager.LayoutParams with:
     * TYPE_APPLICATION_OVERLAY (Android 8+)
     * TYPE_SYSTEM_ALERT (older Android)
     * FLAG_NOT_FOCUSABLE
     * FLAG_NOT_TOUCHABLE
     * FLAG_LAYOUT_NO_LIMITS
     * PixelFormat.TRANSLUCENT
   - Adds view to WindowManager
   - Acquires wake lock
   - Launches MainActivity from overlay context
   - This WORKS because overlay context bypasses Android 10+ restrictions!
   - Removes overlay after 1 second
   - Handler cleanup
   ```

4. **Overlay Cleanup:**
   ```kotlin
   // Lines 160-169
   - removeOverlay() method
   - Removes view from WindowManager
   - Nullifies overlayView reference
   ```

---

### ✅ File 7: ForegroundService.kt
**Location:** `android/app/src/main/kotlin/com/example/hfc_app/ForegroundService.kt`

**Features Implemented:**

1. **Foreground Service with Wake Lock:**
   ```kotlin
   // Lines 54-94
   - Creates notification channel
   - Starts foreground immediately
   - Acquires PARTIAL_WAKE_LOCK
   - Initializes BluetoothManager
   ```

2. **Action Handlers:**
   ```kotlin
   - ACTION_START_SERVICE
   - ACTION_STOP_SERVICE
   - ACTION_UPDATE_HEALTH_DATA
   - ACTION_START_MAIN_ENGINE_MODE
   - ACTION_STOP_MAIN_ENGINE_MODE
   - ACTION_UPDATE_MAIN_ENGINE_DATA
   ```

3. **onTaskRemoved() Override:**
   ```kotlin
   // Lines 650-699
   - Reschedules alarms when app is swiped away
   - Schedules WorkManager
   - Keeps service running with START_STICKY
   ```

---

## 📱 PART 2: FLUTTER/DART FILES

### ✅ File 1: lib/main.dart
**Location:** `lib/main.dart`

**Features Implemented:**

1. **main() Function Initialization:**
   ```dart
   // Lines 24-50
   - WidgetsFlutterBinding.ensureInitialized()
   - MainEngineKeepAliveService.initialize()
   - _checkExactAlarmPermission()
   - AppKeepaliveService.initialize()
   - AppKeepaliveService.startPeriodicKeepalive()
   - BackgroundSyncService.initialize()
   - _testAlarmScheduling()
   - AppKeepaliveService.markAppActive()
   ```

2. **_checkExactAlarmPermission():**
   ```dart
   // Lines 57-82
   - Calls 'checkExactAlarmPermission' via MethodChannel
   - Requests permission if not granted
   - Rechecks after request
   - Logs results
   ```

3. **_testAlarmScheduling():**
   ```dart
   // Lines 85-102
   - Calls 'testAlarmScheduling' via MethodChannel
   - Checks if keepalive alarm exists
   - Checks if workmanager alarm exists
   - Checks canScheduleExact permission
   - Logs all results
   ```

4. **HomeScreenState:**
   ```dart
   // Lines 864-869
   - initState() calls AppKeepaliveService.markAppActive()
   - dispose() calls AppKeepaliveService.markAppActive()
   - Keeps timestamp updated while app is active
   ```

---

### ✅ File 2: lib/services/app_keepalive_service.dart
**Location:** `lib/services/app_keepalive_service.dart`

**Features Implemented:**

1. **MethodChannel Declaration:**
   ```dart
   // Line 12
   - Channel: 'com.example.hfc_app/app_launcher'
   ```

2. **initialize():**
   ```dart
   // Lines 16-22
   - AndroidAlarmManager.initialize()
   ```

3. **startPeriodicKeepalive():**
   ```dart
   // Lines 30-53
   - Calls _scheduleNativeRestartAlarm()
   - Schedules AndroidAlarmManager.periodic():
     * Duration: 10 minutes
     * Alarm ID: 777
     * Callback: _keepaliveCallback
     * wakeup: true
     * exact: true
     * rescheduleOnReboot: true
   ```

4. **_scheduleNativeRestartAlarm():**
   ```dart
   // Lines 63-75
   - Calls native 'scheduleKeepaliveRestart' via MethodChannel
   - Parameters:
     * delaySeconds: 300 (5 minutes)
     * scheduledBy: 'keepalive_service'
   - This schedules the native alarm that triggers AppRestartReceiver
   ```

5. **stopPeriodicKeepalive():**
   ```dart
   // Lines 78-84
   - AndroidAlarmManager.cancel(_alarmId)
   ```

6. **_keepaliveCallback():**
   ```dart
   // Lines 90-133
   - Runs in isolate (every 10 minutes)
   - Reads last_active_timestamp
   - Calculates minutes since active
   - Detects if app is closed (3+ minutes inactive)
   - Logs detection to SharedPreferences
   - Updates last_keepalive_check
   - NOTE: Cannot launch app from isolate!
   ```

7. **markAppActive():**
   ```dart
   // Lines 188-195
   - Updates last_active_timestamp
   - Called from UI to mark app as active
   ```

8. **getStatistics():**
   ```dart
   // Lines 198-206
   - Returns Map with:
     * last_active
     * last_keepalive_check
     * last_launch_attempt
     * total_launch_attempts
   ```

---

### ✅ File 3: lib/services/background_sync_service.dart
**Location:** `lib/services/background_sync_service.dart`

**Features Implemented:**

1. **initialize():**
   ```dart
   // Lines 22-38
   - Workmanager().initialize()
   - Registers backgroundSyncTask callback
   ```

2. **schedulePeriodicSync():**
   ```dart
   // Lines 41-55
   - Workmanager().registerPeriodicTask()
   - Task ID: 'background_sync'
   - Frequency: 15 minutes
   - Constraints: requiresNetworkConnectivity: false
   ```

3. **backgroundSyncTask():**
   ```dart
   // Lines 61-140
   - Runs in isolate
   - Checks if app is active
   - Reads device info from SharedPreferences
   - Sends webhook if data available
   - Schedules native restart alarm
   - Returns Future<bool>
   ```

4. **_scheduleNativeRestartAlarm():**
   ```dart
   // Lines 109-120
   - Calls 'scheduleKeepaliveRestart' via MethodChannel
   - Parameters:
     * delaySeconds: 480 (8 minutes)
     * scheduledBy: 'workmanager'
   ```

---

### ✅ File 4: lib/services/main_engine_keepalive_service.dart
**Location:** `lib/services/main_engine_keepalive_service.dart`

**Features Implemented:**

1. **MethodChannel Setup:**
   ```dart
   // Lines 19-20
   - Channel: 'com.hfc.app/main_engine_keepalive'
   ```

2. **initialize():**
   ```dart
   // Lines 23-30
   - Sets up MethodChannel handler
   - Handles 'keepAlive' method
   ```

3. **startKeepAlive():**
   ```dart
   // Lines 33-54
   - Calls native 'startMainEngineMode'
   - Passes device and health data
   - Keeps main Flutter engine alive
   ```

4. **stopKeepAlive():**
   ```dart
   // Lines 57-64
   - Calls native 'stopMainEngineMode'
   ```

5. **updateHealthData():**
   ```dart
   // Lines 67-87
   - Calls native 'updateMainEngineData'
   - Updates heart rate, SpO2, temperature, battery
   ```

---

## 📜 PART 3: ANDROIDMANIFEST.XML

**Location:** `android/app/src/main/AndroidManifest.xml`

### ✅ Permissions Declared:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.DISABLE_KEYGUARD" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

### ✅ MainActivity Attributes:

```xml
<activity android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:taskAffinity=""
    android:showOnLockScreen="true"
    android:showWhenLocked="true"
    android:turnScreenOn="true"
    android:configChanges="..."
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">
```

### ✅ Services Declared:

```xml
<!-- ForegroundService -->
<service android:name=".ForegroundService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="dataSync"
    android:stopWithTask="false" />

<!-- AppLauncherService -->
<service android:name=".AppLauncherService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="dataSync" />

<!-- NativeHC20Service -->
<service android:name=".NativeHC20Service"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="dataSync"
    android:stopWithTask="false" />
```

### ✅ Receivers Declared:

```xml
<!-- BootReceiver -->
<receiver android:name=".BootReceiver"
    android:enabled="true"
    android:exported="true"
    android:permission="android.permission.RECEIVE_BOOT_COMPLETED">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
    </intent-filter>
</receiver>

<!-- SyncAlarmReceiver -->
<receiver android:name=".SyncAlarmReceiver"
    android:enabled="true"
    android:exported="false" />

<!-- AppRestartReceiver -->
<receiver android:name=".AppRestartReceiver"
    android:enabled="true"
    android:exported="false">
    <intent-filter>
        <action android:name="com.example.hfc_app.RESTART_APP" />
        <action android:name="android.intent.action.BOOT_COMPLETED" />
    </intent-filter>
</receiver>

<!-- android_alarm_manager_plus plugin receivers -->
<service android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmService"
    android:permission="android.permission.BIND_JOB_SERVICE"
    android:exported="false"/>
<receiver android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmBroadcastReceiver"
    android:exported="false"/>
<receiver android:name="dev.fluttercommunity.plus.androidalarmmanager.RebootBroadcastReceiver"
    android:enabled="false"
    android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
    </intent-filter>
</receiver>
```

---

## 📦 PART 4: DEPENDENCIES (pubspec.yaml & build.gradle)

### ✅ Flutter Dependencies (pubspec.yaml):

```yaml
dependencies:
  android_alarm_manager_plus: ^4.0.3
  flutter_local_notifications: ^18.0.1
  workmanager: ^0.5.2
  shared_preferences: ^2.3.3
  permission_handler: ^11.3.1
  flutter_background_service: ^5.0.10
```

### ✅ Android Dependencies (build.gradle):

```groovy
dependencies:
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
    implementation 'com.squareup.okhttp3:okhttp:4.12.0'
    implementation 'androidx.work:work-runtime-ktx:2.9.0'
}
```

---

## 🔄 PART 5: RELAUNCH MECHANISMS (Multiple Layers)

### ✅ Layer 1: Flutter android_alarm_manager_plus (10-min)
- **File:** `app_keepalive_service.dart`
- **Method:** `AndroidAlarmManager.periodic()`
- **Interval:** 10 minutes
- **Purpose:** Dart callback to detect app closure
- **Limitation:** Cannot launch app from isolate
- **Status:** Detection only

### ✅ Layer 2: Native AlarmManager via MethodChannel (5-min)
- **File:** `AppLauncher.kt` → `scheduleKeepaliveRestart()`
- **Trigger:** Called from Flutter via MethodChannel
- **Interval:** 5 minutes (300 seconds)
- **Receiver:** `AppRestartReceiver`
- **Action:** Launches app via `AppLauncherService`
- **Self-Perpetuating:** YES - reschedules itself
- **Status:** PRIMARY MECHANISM ⭐

### ✅ Layer 3: Native WorkManager (15-min)
- **File:** `AppRestartWorker.kt`
- **Trigger:** Scheduled from `MainActivity.onCreate()`
- **Interval:** 15 minutes
- **Purpose:** Backup mechanism if AlarmManager fails
- **Action:** Launches app via `AppLauncherService`
- **Status:** BACKUP MECHANISM

### ✅ Layer 4: OverlayLauncher (Screen-ON only)
- **File:** `OverlayLauncher.kt`
- **Trigger:** Called by `AppLauncherService` when screen is ON
- **Method:** Creates invisible overlay → launches from overlay context
- **Permission:** SYSTEM_ALERT_WINDOW required
- **Status:** SCREEN-ON ENHANCEMENT

### ✅ Layer 5: Full-Screen Intent (Screen-OFF only)
- **File:** `AppLauncherService.kt` → `launchViaFullScreenIntent()`
- **Trigger:** Called when screen is OFF
- **Method:** Notification with `setFullScreenIntent()`
- **Category:** CATEGORY_CALL (high priority)
- **Permission:** USE_FULL_SCREEN_INTENT required
- **Status:** SCREEN-OFF PRIMARY ⭐

---

## ⚙️ PART 6: RUNTIME PERMISSION REQUESTS

### ✅ Exact Alarm Permission (Android 12+):
- **Check:** `alarmManager.canScheduleExactAlarms()`
- **Request:** `Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM`
- **Location:** MainActivity lines 411-447
- **Also Checked In:** AppLauncher before scheduling

### ✅ Full-Screen Intent Permission (Android 14+):
- **Check:** `notificationManager.canUseFullScreenIntent()`
- **Request:** `Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`
- **Location:** Would need to be added (NOT IMPLEMENTED YET)

### ✅ Overlay Permission:
- **Check:** `Settings.canDrawOverlays()`
- **Request:** `Settings.ACTION_MANAGE_OVERLAY_PERMISSION`
- **Location:** MainActivity lines 75-104, OverlayLauncher lines 33-53

### ✅ Battery Optimization Exemption:
- **Check:** `powerManager.isIgnoringBatteryOptimizations()`
- **Request:** `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
- **Location:** MainActivity lines 290-320

### ✅ Autostart Permission (Device-Specific):
- **Manufacturers:** Xiaomi, OPPO, Vivo, Realme, OnePlus
- **Method:** Opens manufacturer-specific settings
- **Location:** MainActivity lines 322-409

---

## 🎯 PART 7: INITIALIZATION SEQUENCE

### ✅ App Launch Sequence:

1. **main() in lib/main.dart:**
   - MainEngineKeepAliveService.initialize()
   - Check exact alarm permission
   - AppKeepaliveService.initialize()
   - AppKeepaliveService.startPeriodicKeepalive()
   - BackgroundSyncService.initialize()
   - Test alarm scheduling

2. **MainActivity.onCreate():**
   - Configure lock screen flags
   - Schedule AppRestartWorker (15-min WorkManager)
   - Check and request overlay permission
   - Check and request exact alarm permission

3. **MainActivity.configureFlutterEngine():**
   - AppLauncher.setupChannel() - Sets up MethodChannel bridge

4. **AppKeepaliveService.startPeriodicKeepalive():**
   - Calls _scheduleNativeRestartAlarm() → MethodChannel call
   - Schedules AndroidAlarmManager.periodic (10-min Dart callback)

5. **Native AppLauncher.scheduleKeepaliveRestart():**
   - Schedules AlarmManager alarm (5-min)
   - Alarm will trigger AppRestartReceiver

---

## 📊 PART 8: DATA FLOW & COMMUNICATION

### ✅ Flutter → Kotlin Communication:

**MethodChannel:** `'com.example.hfc_app/app_launcher'`

**Methods Available:**
1. `scheduleKeepaliveRestart` - Schedule native alarm
2. `launchApp` - Launch app immediately
3. `scheduleAppRestart` - Schedule one-time restart
4. `cancelScheduledRestart` - Cancel scheduled alarm

**Usage in Flutter:**
```dart
await _channel.invokeMethod('scheduleKeepaliveRestart', {
  'delaySeconds': 300,
  'scheduledBy': 'keepalive_service',
});
```

### ✅ SharedPreferences Data Stored:

**Flutter Side (prefixed with "flutter."):**
- `flutter.last_connected_device_id` - HC20 device MAC address
- `flutter.user_phone` - User phone number
- `flutter.last_active_timestamp` - Last time UI was active
- `flutter.last_workmanager_restart` - Last WorkManager restart time
- `flutter.workmanager_restart_count` - Number of WorkManager restarts

**Kotlin Side (read by native code):**
- Same keys, read from `FlutterSharedPreferences`

### ✅ Intent Extras Used:

**AppRestartReceiver receives:**
- `scheduled_by` - Source of alarm (keepalive_service / workmanager)
- `scheduled_at` - Timestamp when alarm was scheduled

**MainActivity receives:**
- `launched_from_background` - Boolean flag
- `launch_reason` - String reason (alarm_manager_restart, etc.)
- `launch_time` - Timestamp of launch

---

## 🔍 PART 9: ALARM REQUEST CODES

### ✅ Request Code Map:

```kotlin
RESTART_REQUEST_CODE = 12345      // Basic restart alarm
KEEPALIVE_REQUEST_CODE = 12346    // Keepalive service alarm
WORKMANAGER_REQUEST_CODE = 12347  // WorkManager alarm
```

**Why Different Codes:**
- Prevents alarms from overwriting each other
- Allows multiple independent alarms
- Each alarm operates on its own schedule

---

## 📝 SUMMARY: WHAT TO COMPARE IN YOUR OTHER CODEBASE

### ✅ Essential Kotlin Files (Must Have):
1. ✅ MainActivity.kt - MethodChannel setup + permissions
2. ✅ AppLauncher.kt - Alarm scheduling + MethodChannel handler
3. ✅ AppRestartReceiver.kt - Receives alarms + reschedules
4. ✅ AppLauncherService.kt - Full-screen intent launch
5. ✅ OverlayLauncher.kt - Screen-ON launch trick
6. ✅ AppRestartWorker.kt - WorkManager backup

### ✅ Essential Flutter Files (Must Have):
1. ✅ main.dart - Initialization sequence
2. ✅ app_keepalive_service.dart - Flutter alarm + MethodChannel
3. ✅ background_sync_service.dart - WorkManager scheduling

### ✅ Essential Manifest Entries (Must Have):
1. ✅ 12 permissions declared
2. ✅ MainActivity with 3 lock screen attributes
3. ✅ 3 services declared (ForegroundService, AppLauncherService, NativeHC20Service)
4. ✅ 3 receivers declared (BootReceiver, AppRestartReceiver, SyncAlarmReceiver)

### ✅ Essential Initialization (Must Have):
1. ✅ MainActivity.onCreate() schedules WorkManager
2. ✅ MainActivity.onCreate() requests permissions
3. ✅ MainActivity.configureFlutterEngine() sets up MethodChannel
4. ✅ main.dart calls AppKeepaliveService.startPeriodicKeepalive()
5. ✅ AppKeepaliveService calls native scheduleKeepaliveRestart

### ✅ Critical Missing If Not Working:
- ⚠️ Initial alarm not scheduled in MainActivity.onCreate()
- ⚠️ AppRestartReceiver not rescheduling alarm
- ⚠️ SCHEDULE_EXACT_ALARM permission not granted
- ⚠️ Full-screen intent permission not granted (Android 14+)
- ⚠️ Battery optimization not disabled
- ⚠️ MethodChannel not set up correctly

---

## 🎯 QUICK COMPARISON CHECKLIST

Print this and check off each item in your other codebase:

### Kotlin Files:
- [ ] MainActivity.kt has MethodChannel setup (line ~110)
- [ ] MainActivity.kt has lock screen flags (line ~30-45)
- [ ] MainActivity.kt schedules WorkManager (line ~67)
- [ ] AppLauncher.kt exists with setupChannel()
- [ ] AppLauncher.kt has scheduleKeepaliveRestart()
- [ ] AppRestartReceiver.kt exists
- [ ] AppRestartReceiver.kt reschedules alarm in onReceive()
- [ ] AppLauncherService.kt exists
- [ ] AppLauncherService.kt uses full-screen intent
- [ ] OverlayLauncher.kt exists (optional but recommended)
- [ ] AppRestartWorker.kt exists

### Flutter Files:
- [ ] app_keepalive_service.dart exists
- [ ] app_keepalive_service.dart calls MethodChannel
- [ ] main.dart initializes AppKeepaliveService
- [ ] main.dart calls startPeriodicKeepalive()

### AndroidManifest.xml:
- [ ] SCHEDULE_EXACT_ALARM permission
- [ ] USE_FULL_SCREEN_INTENT permission
- [ ] SYSTEM_ALERT_WINDOW permission
- [ ] WAKE_LOCK permission
- [ ] MainActivity has showOnLockScreen="true"
- [ ] MainActivity has showWhenLocked="true"
- [ ] MainActivity has turnScreenOn="true"
- [ ] AppLauncherService declared
- [ ] AppRestartReceiver declared with RESTART_APP action

### Runtime Checks:
- [ ] Exact alarm permission requested
- [ ] Battery optimization exemption requested
- [ ] Overlay permission requested

---

**Document Version:** 1.0  
**Total Features Documented:** 150+  
**Last Updated:** January 19, 2026  
**Codebase:** HFC-App (Komalchoudhary2007)
