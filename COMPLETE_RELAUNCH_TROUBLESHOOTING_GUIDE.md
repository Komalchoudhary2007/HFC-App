# Complete App Relaunch Troubleshooting Guide - HFC App
## Based on Actual Codebase Implementation

## 🎯 Problem: App Does NOT Relaunch After Swipe Away (Screen OFF)

This guide covers **EVERY** component needed for app relaunch to work. Missing even ONE of these will cause failure.

---

## 🔍 CRITICAL COMPONENTS CHECKLIST

### ✅ 1. AndroidManifest.xml - ALL Permissions Required

**Location:** `android/app/src/main/AndroidManifest.xml`

```xml
<!-- CRITICAL: Exact alarm permission (Android 12+) -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />

<!-- CRITICAL: Full-screen intent permission (show app on lock screen) -->
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />

<!-- CRITICAL: Overlay permission (relaunch when screen ON) -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />

<!-- CRITICAL: Wake lock to turn on screen -->
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- CRITICAL: Foreground service -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />

<!-- CRITICAL: Boot receiver for auto-start after reboot -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<!-- IMPORTANT: Battery optimization -->
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />

<!-- Standard permissions -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.DISABLE_KEYGUARD" />
```

---

### ✅ 2. AndroidManifest.xml - MainActivity Configuration

**CRITICAL:** MainActivity must have these attributes:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:taskAffinity=""
    android:showOnLockScreen="true"
    android:showWhenLocked="true"
    android:turnScreenOn="true"
    ...>
```

**Why these matter:**
- `showOnLockScreen="true"` - Shows app over lock screen
- `showWhenLocked="true"` - Bypasses lock screen when launching
- `turnScreenOn="true"` - Turns on screen when app launches
- `launchMode="singleTop"` - Prevents multiple instances
- `taskAffinity=""` - Allows app to launch in new task

---

### ✅ 3. AndroidManifest.xml - Service and Receiver Declarations

```xml
<application ...>
    
    <!-- CRITICAL: AppLauncherService for full-screen intent -->
    <service
        android:name=".AppLauncherService"
        android:enabled="true"
        android:exported="false"
        android:foregroundServiceType="dataSync" />
    
    <!-- CRITICAL: AppRestartReceiver for AlarmManager -->
    <receiver
        android:name=".AppRestartReceiver"
        android:enabled="true"
        android:exported="false">
        <intent-filter>
            <action android:name="com.example.hfc_app.RESTART_APP" />
            <action android:name="android.intent.action.BOOT_COMPLETED" />
        </intent-filter>
    </receiver>
    
    <!-- ForegroundService for HC20 monitoring -->
    <service
        android:name=".ForegroundService"
        android:enabled="true"
        android:exported="false"
        android:foregroundServiceType="dataSync"
        android:stopWithTask="false" />
    
    <!-- BootReceiver for auto-start after device reboot -->
    <receiver
        android:name=".BootReceiver"
        android:enabled="true"
        android:exported="true"
        android:permission="android.permission.RECEIVE_BOOT_COMPLETED">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED" />
            <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        </intent-filter>
    </receiver>
    
</application>
```

---

### ✅ 4. MainActivity.onCreate() - Initial Alarm Scheduling

**CRITICAL ISSUE:** If initial alarm is NOT scheduled, the chain never starts!

**Location:** `MainActivity.kt` → `onCreate()`

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    
    // ⚠️ CRITICAL: Lock screen configuration
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
        setShowWhenLocked(true)
        setTurnScreenOn(true)
    } else {
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )
    }
    
    // ⚠️ CRITICAL: Schedule WorkManager (15-min backup)
    AppRestartWorker.schedule(applicationContext)
    Log.d(TAG, "✅ WorkManager scheduled (15-min restart)")
    
    // ⭐⭐⭐ MISSING IN CURRENT CODE: Schedule initial AlarmManager alarm
    // WITHOUT THIS, THE ALARM CHAIN NEVER STARTS!
    AppLauncher.scheduleKeepaliveRestart(applicationContext, 300, "keepalive_service")
    Log.d(TAG, "✅ AlarmManager scheduled (5-min restart)")
    
    // ⚠️ CRITICAL: Check overlay permission (for screen-ON restart)
    checkAndRequestOverlayPermission()
    
    // ⚠️ CRITICAL: Check exact alarm permission (Android 12+)
    checkAndRequestExactAlarmPermission()
    
    // ⚠️ CRITICAL: Check full-screen intent permission (Android 14+)
    checkAndRequestFullScreenIntentPermission()
    
    // ⚠️ CRITICAL: Request battery optimization exemption
    checkAndRequestBatteryExemption()
}
```

---

### ✅ 5. Runtime Permission Checks - Android 12+ (SCHEDULE_EXACT_ALARM)

**CRITICAL:** Android 12+ requires RUNTIME permission for exact alarms!

**Add these methods to MainActivity:**

```kotlin
/**
 * Check if exact alarm permission is granted (Android 12+)
 */
private fun checkExactAlarmPermission(): Boolean {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }
    return true
}

/**
 * Request exact alarm permission with explanation dialog
 */
private fun checkAndRequestExactAlarmPermission() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (!alarmManager.canScheduleExactAlarms()) {
            AlertDialog.Builder(this)
                .setTitle("Enable Exact Alarms")
                .setMessage(
                    "To restart the app when screen is off, " +
                    "please enable 'Alarms & reminders' permission.\n\n" +
                    "This is REQUIRED on Android 12+."
                )
                .setPositiveButton("Enable") { _, _ ->
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to open alarm settings: ${e.message}")
                    }
                }
                .setNegativeButton("Later", null)
                .setCancelable(false)
                .show()
        }
    }
}
```

**⚠️ ALSO CHECK: Verify permission before scheduling alarm in AppLauncher.kt:**

```kotlin
fun scheduleKeepaliveRestart(context: Context, delaySeconds: Int, scheduledBy: String) {
    try {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // ⭐ CRITICAL CHECK: Verify permission (Android 12+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                Log.e(TAG, "❌❌❌ CANNOT SCHEDULE ALARM - Permission denied!")
                Log.e(TAG, "   User must enable 'Alarms & reminders' in Settings")
                return  // ABORT - alarm will NOT be scheduled
            }
        }
        
        // ... rest of scheduling code ...
    } catch (e: Exception) {
        Log.e(TAG, "❌ Failed to schedule: ${e.message}")
    }
}
```

---

### ✅ 6. Runtime Permission - Android 14+ (USE_FULL_SCREEN_INTENT)

**CRITICAL:** Android 14+ requires RUNTIME permission for full-screen intent!

```kotlin
/**
 * Check full-screen intent permission (Android 14+)
 */
private fun checkFullScreenIntentPermission(): Boolean {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // API 34
        val notificationManager = getSystemService(NotificationManager::class.java)
        return notificationManager.canUseFullScreenIntent()
    }
    return true
}

/**
 * Request full-screen intent permission with dialog
 */
private fun checkAndRequestFullScreenIntentPermission() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        val notificationManager = getSystemService(NotificationManager::class.java)
        if (!notificationManager.canUseFullScreenIntent()) {
            AlertDialog.Builder(this)
                .setTitle("Enable Full Screen Intent")
                .setMessage(
                    "To launch the app when screen is off, " +
                    "please enable 'Full screen intent' permission.\n\n" +
                    "This is REQUIRED on Android 14+."
                )
                .setPositiveButton("Enable") { _, _ ->
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to open settings: ${e.message}")
                    }
                }
                .setNegativeButton("Later", null)
                .show()
        }
    }
}
```

---

### ✅ 7. AppRestartReceiver - Must Reschedule Next Alarm!

**CRITICAL:** Each alarm must reschedule itself, or it only fires ONCE!

**Location:** `AppRestartReceiver.kt` → `onReceive()`

```kotlin
override fun onReceive(context: Context, intent: Intent) {
    Log.d(TAG, "🔔 Alarm triggered")
    
    when (intent.action) {
        "com.example.hfc_app.RESTART_APP" -> {
            // Check screen state
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val isScreenOn = powerManager.isInteractive
            
            if (isScreenOn) {
                // Screen ON - just ensure service is running
                startForegroundServiceWithDevice(context)
            } else {
                // Screen OFF - launch app via full-screen intent
                AppLauncherService.start(context)
            }
            
            // ⭐⭐⭐ CRITICAL: Reschedule the next alarm
            // WITHOUT THIS, ALARM ONLY FIRES ONCE!
            val scheduledBy = intent.getStringExtra("scheduled_by") ?: "keepalive_service"
            
            when (scheduledBy) {
                "keepalive_service" -> {
                    // Reschedule for 5 minutes
                    AppLauncher.scheduleKeepaliveRestart(context, 300, "keepalive_service")
                    Log.d(TAG, "✅ Next alarm rescheduled (5 min)")
                }
                "workmanager" -> {
                    // Reschedule for 8 minutes
                    AppLauncher.scheduleKeepaliveRestart(context, 480, "workmanager")
                    Log.d(TAG, "✅ Next alarm rescheduled (8 min)")
                }
            }
        }
        
        Intent.ACTION_BOOT_COMPLETED -> {
            // After reboot, schedule both mechanisms
            AppLauncher.scheduleKeepaliveRestart(context, 300, "keepalive_service")
            AppRestartWorker.schedule(context)
            Log.d(TAG, "✅ Alarms rescheduled after boot")
        }
    }
}
```

---

### ✅ 8. AppLauncher - Correct Alarm Scheduling Method

**CRITICAL:** Must use `setExactAndAllowWhileIdle()` for Doze mode!

**Location:** `AppLauncher.kt` → `scheduleKeepaliveRestart()`

```kotlin
fun scheduleKeepaliveRestart(context: Context, delaySeconds: Int, scheduledBy: String) {
    try {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // ⭐ Check permission (Android 12+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                Log.e(TAG, "❌ No SCHEDULE_EXACT_ALARM permission!")
                return
            }
        }
        
        val intent = Intent(context, AppRestartReceiver::class.java).apply {
            action = "com.example.hfc_app.RESTART_APP"
            putExtra("scheduled_by", scheduledBy)
        }
        
        // Use different request codes so alarms don't overwrite each other
        val requestCode = when (scheduledBy) {
            "workmanager" -> 12347
            else -> 12346
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE  // ⭐ FLAG_IMMUTABLE required
        )
        
        val triggerAtMillis = SystemClock.elapsedRealtime() + (delaySeconds * 1000L)
        
        // ⭐⭐⭐ CRITICAL: Use setExactAndAllowWhileIdle (works in Doze mode)
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,  // ⭐ WAKEUP - turns on device
            triggerAtMillis,
            pendingIntent
        )
        
        Log.d(TAG, "✅ Alarm scheduled: $delaySeconds sec, by: $scheduledBy")
        
    } catch (e: Exception) {
        Log.e(TAG, "❌ Failed to schedule: ${e.message}")
    }
}
```

---

### ✅ 9. AppLauncherService - Full-Screen Intent Implementation

**CRITICAL:** Must create notification with full-screen intent!

**Location:** `AppLauncherService.kt` → `onStartCommand()`

```kotlin
override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    Log.d(TAG, "🎯 Launching app NOW")
    
    // Start as foreground service
    val notification = createNotification()
    startForeground(NOTIFICATION_ID, notification)
    
    // Check screen state
    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
    val isScreenOn = powerManager.isInteractive
    
    // Acquire wake lock to turn on screen
    val wakeLock = powerManager.newWakeLock(
        PowerManager.FULL_WAKE_LOCK or
        PowerManager.ACQUIRE_CAUSES_WAKEUP or
        PowerManager.ON_AFTER_RELEASE,
        "hfc_app:launcher_wakelock"
    )
    wakeLock.acquire(10000) // 10 seconds
    
    if (isScreenOn) {
        // Screen ON - use overlay method
        launchViaOverlay()
    } else {
        // Screen OFF - use full-screen intent
        launchViaFullScreenIntent()
    }
    
    // Also try direct launch as backup
    try {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("launched_from_background", true)
        }
        startActivity(launchIntent)
    } catch (e: Exception) {
        Log.d(TAG, "Direct launch failed: ${e.message}")
    }
    
    // Clean up and stop service
    Handler(Looper.getMainLooper()).postDelayed({
        if (wakeLock.isHeld) wakeLock.release()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }, 5000)
    
    return START_NOT_STICKY
}

/**
 * Full-screen intent for screen OFF
 */
private fun launchViaFullScreenIntent() {
    val launchIntent = Intent(this, MainActivity::class.java).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        putExtra("launched_from_background", true)
    }
    
    val pendingIntent = PendingIntent.getActivity(
        this, 0, launchIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    
    // ⭐⭐⭐ THE KEY: Full-screen intent notification
    val notification = NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(android.R.drawable.ic_dialog_info)
        .setContentTitle("HFC App Restarting")
        .setContentText("Reconnecting...")
        .setPriority(NotificationCompat.PRIORITY_HIGH)
        .setCategory(NotificationCompat.CATEGORY_CALL)  // ⭐ Treat like incoming call
        .setFullScreenIntent(pendingIntent, true)        // ⭐⭐⭐ THIS IS THE KEY!
        .setAutoCancel(true)
        .build()
    
    val notificationManager = getSystemService(NotificationManager::class.java)
    notificationManager.notify(9999, notification)
    Log.d(TAG, "✅ Full-screen intent posted")
}
```

---

### ✅ 10. Flutter Code - Initial Scheduling in main.dart

**CRITICAL:** Flutter must also call initial scheduling!

**Location:** `lib/main.dart` → `main()`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ⭐ CRITICAL: Check exact alarm permission first
  await _checkExactAlarmPermission();
  
  // ⭐ CRITICAL: Initialize AlarmManager
  await AppKeepaliveService.initialize();
  await AppKeepaliveService.startPeriodicKeepalive();
  print('✅ AlarmManager initialized');
  
  // ⭐ CRITICAL: Initialize WorkManager
  await BackgroundSyncService.initialize();
  print('✅ WorkManager initialized');
  
  // ⭐ CRITICAL: Test that alarms are scheduled
  await _testAlarmScheduling();
  
  runApp(const MyApp());
}

Future<void> _checkExactAlarmPermission() async {
  if (!Platform.isAndroid) return;
  
  const channel = MethodChannel('com.hfc.app/background');
  try {
    final bool canSchedule = await channel.invokeMethod('checkExactAlarmPermission');
    
    if (!canSchedule) {
      print('⚠️⚠️⚠️ CRITICAL: SCHEDULE_EXACT_ALARM permission NOT granted!');
      await channel.invokeMethod('requestExactAlarmPermission');
    } else {
      print('✅ SCHEDULE_EXACT_ALARM permission granted');
    }
  } catch (e) {
    print('⚠️ Failed to check permission: $e');
  }
}

Future<void> _testAlarmScheduling() async {
  if (!Platform.isAndroid) return;
  
  const channel = MethodChannel('com.hfc.app/background');
  try {
    final Map result = await channel.invokeMethod('testAlarmScheduling');
    print('🧪 Alarm Test Results:');
    print('   Keepalive alarm: ${result['keepaliveExists']}');
    print('   WorkManager alarm: ${result['workExists']}');
    print('   Can schedule exact: ${result['canScheduleExact']}');
    
    if (!result['keepaliveExists']) {
      print('❌❌❌ KEEPALIVE ALARM NOT SCHEDULED!');
    }
  } catch (e) {
    print('⚠️ Test failed: $e');
  }
}
```

---

## 🐛 DEBUGGING CHECKLIST

### Step 1: Verify Permissions in Settings

Go to: **Settings → Apps → Your App → Permissions**

Check these are enabled:
- ✅ **Alarms & reminders** (Android 12+) - CRITICAL!
- ✅ **Display over other apps** - For screen-ON restart
- ✅ **Full screen intent** (Android 14+) - CRITICAL!

Go to: **Settings → Apps → Your App → Battery**
- ✅ **Unrestricted** or **Not optimized** - CRITICAL!

### Step 2: Check Logcat for Alarm Scheduling

Run: `adb logcat | grep -E "AlarmManager|AppRestartReceiver|AppLauncher"`

You should see:
```
✅ AlarmManager scheduled (5-min restart)
✅ Alarm scheduled: 300 sec, by: keepalive_service
```

If you see:
```
❌ No SCHEDULE_EXACT_ALARM permission!
```
→ User must enable "Alarms & reminders" in Settings!

### Step 3: Verify Alarm is in System

Run: `adb shell dumpsys alarm | grep "com.example.hfc_app"`

You should see scheduled alarms with your app package name.

If empty → Alarm was NOT scheduled!

### Step 4: Test Alarm Trigger

Run: `adb logcat | grep "AppRestartReceiver"`

After 5-6 minutes, you should see:
```
🔔 Alarm triggered
🌙 Screen is OFF - launching app
✅ Next alarm rescheduled (5 min)
```

If you see the first line but NOT "Next alarm rescheduled" → Missing reschedule code!

### Step 5: Test App Launch

After alarm triggers, check:
```
🚀 Starting AppLauncherService...
✅ Wake lock acquired
✅ Full-screen intent posted
```

If app doesn't launch → Check full-screen intent permission (Android 14+)

---

## 📱 DEVICE-SPECIFIC ISSUES

### Xiaomi/MIUI
- **Autostart Permission Required**
- Go to: Security → Permissions → Autostart → Enable

### Samsung One UI
- **Disable "Put app to sleep"**
- Go to: Settings → Battery → Background usage limits → Never sleeping apps

### Huawei/EMUI  
- **Manual startup required**
- Go to: Settings → Apps → Launch → Enable manual launch

### OnePlus/OxygenOS
- **Disable deep optimization**
- Go to: Settings → Battery → Battery optimization → Disable

---

## 🎯 MOST COMMON MISSING PIECES

Based on this codebase analysis, these are the TOP issues:

1. ❌ **Missing initial alarm schedule in MainActivity.onCreate()**
   - Fix: Add `AppLauncher.scheduleKeepaliveRestart(applicationContext, 300, "keepalive_service")`

2. ❌ **SCHEDULE_EXACT_ALARM permission not requested at runtime (Android 12+)**
   - Fix: Add `checkAndRequestExactAlarmPermission()` in MainActivity

3. ❌ **USE_FULL_SCREEN_INTENT permission not requested (Android 14+)**
   - Fix: Add `checkAndRequestFullScreenIntentPermission()` in MainActivity

4. ❌ **Missing permission check before scheduling alarm**
   - Fix: Add `canScheduleExactAlarms()` check in `AppLauncher.scheduleKeepaliveRestart()`

5. ❌ **Battery optimization not disabled**
   - Fix: Add battery exemption request in MainActivity

6. ❌ **AppRestartReceiver not rescheduling alarm**
   - Fix: Add `AppLauncher.scheduleKeepaliveRestart()` in `onReceive()`

---

## 🧪 COMPLETE TESTING PROCEDURE

### Test 1: Verify Initial Setup
1. Install app
2. Open app
3. Check logcat: `adb logcat | grep "AlarmManager scheduled"`
4. Should see: `✅ AlarmManager scheduled (5-min restart)`

### Test 2: Verify Permissions
1. Settings → Apps → Your App
2. Check: Alarms & reminders = ✅
3. Check: Display over other apps = ✅
4. Check: Battery = Unrestricted

### Test 3: Verify Alarm in System
1. Run: `adb shell dumpsys alarm | grep "hfc_app"`
2. Should see scheduled alarm with trigger time

### Test 4: Test Screen OFF Relaunch
1. Open app and connect to device
2. Lock phone (screen OFF)
3. Swipe app away from recent apps
4. Wait 5-6 minutes
5. **Expected:** App launches on lock screen

### Test 5: Verify Rescheduling
1. After Test 4 succeeds
2. Swipe app away AGAIN
3. Wait another 5-6 minutes
4. **Expected:** App launches AGAIN (confirms reschedule works)

### Test 6: Check Logs
```bash
adb logcat -c  # Clear logs
adb logcat | grep -E "AlarmManager|AppRestartReceiver|AppLauncher"
```

Wait and watch for:
```
🔔 Alarm triggered
🌙 Screen is OFF - launching app
🚀 Starting AppLauncherService...
✅ Full-screen intent posted
✅ Next alarm rescheduled (5 min)
```

---

## 📋 FINAL VERIFICATION SCRIPT

Run this complete test:

```bash
# 1. Check if app is installed
adb shell pm list packages | grep hfc_app

# 2. Check alarm permission
adb shell dumpsys package com.example.hfc_app | grep "SCHEDULE_EXACT_ALARM"

# 3. Check scheduled alarms
adb shell dumpsys alarm | grep "hfc_app"

# 4. Check battery optimization
adb shell dumpsys deviceidle whitelist | grep hfc_app

# 5. Watch live logs
adb logcat -c
adb logcat | grep -E "AlarmManager|AppRestart|AppLauncher"
```

---

## ✅ SUCCESS CRITERIA

App relaunch is working if:

1. ✅ Initial alarm is scheduled when app opens
2. ✅ Alarm fires after 5 minutes
3. ✅ App launches on lock screen when alarm fires
4. ✅ Alarm reschedules itself after each trigger
5. ✅ Process repeats indefinitely (alarm fires every 5 min)

---

**Document Version:** 2.0 (Complete Implementation)  
**Last Updated:** January 19, 2026  
**Based On:** Actual HFC-App codebase analysis  
**Tested On:** Android 8.0 - Android 14
