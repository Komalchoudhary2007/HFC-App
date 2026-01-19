# AlarmManager & WorkManager Debug Guide
**Date:** January 17, 2026  
**Issue:** App restart alarms not triggering when app is closed

## Problem Summary

Both AlarmManager (5 min) and WorkManager (8 min) should relaunch the app when closed, but they're not working.

## Code Flow Analysis

### ✅ **1. Initialization (When App Starts)**

**Location:** `lib/main.dart` lines 16-24

```dart
void main() async {
  // Initialize AlarmManager
  await AppKeepaliveService.initialize();
  await AppKeepaliveService.startPeriodicKeepalive();
  
  // Initialize WorkManager  
  await BackgroundSyncService.initialize();
  await BackgroundSyncService.startPeriodicSync(); // ← This should schedule BOTH alarms
}
```

**What happens:**
1. `AppKeepaliveService.startPeriodicKeepalive()` calls `_scheduleNativeRestartAlarm()`
2. `BackgroundSyncService.startPeriodicSync()` calls `_scheduleNativeWorkManagerRestart()`

### ✅ **2. Schedule Native Alarms (Dart → Native)**

**Keepalive Service** (`lib/services/app_keepalive_service.dart` line 64-73):
```dart
_channel.invokeMethod('scheduleKeepaliveRestart', {
  'delaySeconds': 300,  // 5 minutes
  'scheduledBy': 'keepalive_service',
});
```

**WorkManager Service** (`lib/services/background_sync_service.dart` line 109-118):
```dart
_channel.invokeMethod('scheduleKeepaliveRestart', {
  'delaySeconds': 480,  // 8 minutes
  'scheduledBy': 'workmanager',
});
```

### ✅ **3. Native Side Receives Call (Kotlin)**

**Location:** `android/app/src/main/kotlin/com/example/hfc_app/MainActivity.kt`

```kotlin
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    AppLauncher.setupChannel(flutterEngine, applicationContext)
}
```

**Location:** `android/app/src/main/kotlin/com/example/hfc_app/AppLauncher.kt` line 40-48

```kotlin
"scheduleKeepaliveRestart" -> {
    val delaySeconds = call.argument<Int>("delaySeconds") ?: 2
    val scheduledBy = call.argument<String>("scheduledBy") ?: "keepalive_service"
    scheduleKeepaliveRestart(context, delaySeconds, scheduledBy)
    result.success(true)
}
```

### ✅ **4. Schedule AlarmManager (Native)**

**Location:** `android/app/src/main/kotlin/com/example/hfc_app/AppLauncher.kt` line 159-206

```kotlin
fun scheduleKeepaliveRestart(context: Context, delaySeconds: Int, scheduledBy: String) {
    // Create distinct request code for each scheduler
    val requestCode = when (scheduledBy) {
        "workmanager" -> WORKMANAGER_REQUEST_CODE  // 12347
        else -> KEEPALIVE_REQUEST_CODE              // 12346
    }
    
    // Create broadcast intent
    val intent = Intent(context, AppRestartReceiver::class.java).apply {
        action = "com.example.hfc_app.RESTART_APP"
        putExtra("scheduled_by", scheduledBy)
    }
    
    // Create PendingIntent
    val pendingIntent = PendingIntent.getBroadcast(
        context, requestCode, intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    
    // Schedule alarm
    alarmManager.setExactAndAllowWhileIdle(
        AlarmManager.ELAPSED_REALTIME_WAKEUP,
        triggerAtMillis,
        pendingIntent
    )
}
```

**Result:** Two alarms scheduled with distinct request codes
- Alarm 1: request code 12346, fires in 5 min, scheduledBy="keepalive_service"
- Alarm 2: request code 12347, fires in 8 min, scheduledBy="workmanager"

### ✅ **5. Alarm Fires → Receiver Triggered**

**Location:** `android/app/src/main/kotlin/com/example/hfc_app/AppRestartReceiver.kt`

```kotlin
override fun onReceive(context: Context, intent: Intent) {
    when (intent.action) {
        "com.example.hfc_app.RESTART_APP" -> {
            // 1. Launch the app
            AppLauncher.launchApp(context)
            
            // 2. Reschedule the alarm (self-perpetuating)
            val scheduledBy = intent.getStringExtra("scheduled_by")
            when (scheduledBy) {
                "keepalive_service" -> 
                    AppLauncher.scheduleKeepaliveRestart(context, 300, "keepalive_service")
                "workmanager" -> 
                    AppLauncher.scheduleKeepaliveRestart(context, 480, "workmanager")
            }
        }
    }
}
```

### ✅ **6. AndroidManifest Registration**

**Location:** `android/app/src/main/AndroidManifest.xml` line 74-80

```xml
<receiver
    android:name=".AppRestartReceiver"
    android:enabled="true"
    android:exported="false">
    <intent-filter>
        <action android:name="com.example.hfc_app.RESTART_APP" />
        <action android:name="android.intent.action.BOOT_COMPLETED" />
    </intent-filter>
</receiver>
```

## ✅ Code Status: LOOKS CORRECT!

All the code looks properly implemented. The issue might be:

1. **Permissions not granted at runtime**
2. **Battery optimization blocking alarms**
3. **Alarm not actually being scheduled** (no error but silent fail)
4. **Receiver not registered properly** (needs app rebuild)

## Testing Plan

### **Test 1: Verify Alarms Are Scheduled**

Add this test method to MainActivity:

```kotlin
// In MainActivity.kt - add to configureFlutterEngine
"testAlarmScheduling" -> {
    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    
    // Test keepalive alarm
    val keepaliveIntent = Intent(context, AppRestartReceiver::class.java).apply {
        action = "com.example.hfc_app.RESTART_APP"
    }
    val keepalivePending = PendingIntent.getBroadcast(
        context, 12346, keepaliveIntent,
        PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
    )
    
    // Test workmanager alarm  
    val workIntent = Intent(context, AppRestartReceiver::class.java).apply {
        action = "com.example.hfc_app.RESTART_APP"
    }
    val workPending = PendingIntent.getBroadcast(
        context, 12347, workIntent,
        PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
    )
    
    val keepaliveExists = keepalivePending != null
    val workExists = workPending != null
    
    Log.d("AlarmTest", "Keepalive alarm exists: $keepaliveExists")
    Log.d("AlarmTest", "WorkManager alarm exists: $workExists")
    
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val canSchedule = alarmManager.canScheduleExactAlarms()
        Log.d("AlarmTest", "Can schedule exact alarms: $canSchedule")
        result.success(mapOf(
            "keepaliveExists" to keepaliveExists,
            "workExists" to workExists,
            "canScheduleExact" to canSchedule
        ))
    } else {
        result.success(mapOf(
            "keepaliveExists" to keepaliveExists,
            "workExists" to workExists,
            "canScheduleExact" to true
        ))
    }
}
```

### **Test 2: Manual Trigger (Short Delay)**

Add this to test if receiver works:

```kotlin
"testImmediateRestart" -> {
    // Schedule alarm for 10 seconds from now
    AppLauncher.scheduleKeepaliveRestart(context, 10, "test_immediate")
    result.success(true)
}
```

### **Test 3: Check Permissions (Android 12+)**

For Android 12+, `SCHEDULE_EXACT_ALARM` permission is required:

```kotlin
"checkExactAlarmPermission" -> {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val canSchedule = alarmManager.canScheduleExactAlarms()
        result.success(canSchedule)
    } else {
        result.success(true) // Not needed on older versions
    }
}

"requestExactAlarmPermission" -> {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
        context.startActivity(intent)
        result.success(true)
    } else {
        result.success(true)
    }
}
```

## Likely Root Causes

### **1. Android 12+ Exact Alarm Permission** ⚠️

On Android 12 (API 31) and higher, you need:
- Permission in manifest: `<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />` ✅ (Already added)
- **User must grant permission** via Settings

**Fix:** Add permission request on app start:

```dart
// In lib/main.dart after AlarmManager init
if (Platform.isAndroid) {
  try {
    // Check if we can schedule exact alarms
    final canSchedule = await _channel.invokeMethod('checkExactAlarmPermission');
    if (!canSchedule) {
      print('⚠️ SCHEDULE_EXACT_ALARM permission not granted!');
      print('   Requesting permission...');
      await _channel.invokeMethod('requestExactAlarmPermission');
    }
  } catch (e) {
    print('⚠️ Failed to check exact alarm permission: $e');
  }
}
```

### **2. Battery Optimization Blocking Alarms** ⚠️

Even with alarms scheduled, battery optimization can prevent them from firing.

**Check status:**
```kotlin
val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
val isIgnoring = pm.isIgnoringBatteryOptimizations(context.packageName)
```

**Request exemption** (already in code, but verify it's being called):
```dart
await _channel.invokeMethod('requestBatteryOptimizationExemption');
```

### **3. Doze Mode Restrictions** ⚠️

`setExactAndAllowWhileIdle()` is being used ✅, which should work in Doze mode.

However, there are limits:
- **Can only fire ~9 alarms per 15 minutes** in Doze mode
- If scheduling 2 alarms (5 min + 8 min), should be fine

### **4. App Not Rebuilt After Native Changes** ⚠️

If you modified `AppRestartReceiver.kt` or `AppLauncher.kt` and didn't rebuild, changes won't take effect.

**Solution:** Build fresh APK with the fixes I just made.

## Required Actions

1. **Build new APK** with the fixed `AppRestartReceiver.kt`
2. **Add permission check** for `SCHEDULE_EXACT_ALARM` on Android 12+
3. **Add test methods** to verify alarms are scheduled
4. **Check battery optimization** status
5. **Test on real device** (not emulator)

## Quick Test Script

After installing new APK:

1. Open app
2. Connect to HC20 device
3. Check logs for:
   ```
   ✅ Native restart alarm scheduled (5-min interval, self-perpetuating)
   ✅ WorkManager native restart alarm scheduled (8-min interval)
   ```
4. Close app (swipe away from recent apps)
5. Wait 5 minutes
6. Check if app relaunches automatically
7. Check logs for:
   ```
   🔔 AlarmManager triggered app restart
   🚀 Launching app from AlarmManager...
   🔄 Rescheduling next keepalive restart (5 min)...
   ```

## Expected Log Output

### When app starts:
```
[AppKeepalive] ✅ AlarmManager initialized
[AppKeepalive] ✅ Periodic keepalive started (10-min interval)
[AppKeepalive]    Native restart alarm: 5-min interval
[BackgroundSync] ✅ WorkManager initialized
[BackgroundSync] ✅ Periodic background sync started (every 15 min)
[BackgroundSync]    Native restart alarm: 8-min interval
[AppLauncher] ⏰ Scheduling keepalive restart in 300 seconds (by: keepalive_service)
[AppLauncher] ✅ Keepalive restart scheduled via broadcast
[AppLauncher] ⏰ Scheduling keepalive restart in 480 seconds (by: workmanager)
[AppLauncher] ✅ Keepalive restart scheduled via broadcast
```

### After 5 minutes (app closed):
```
[AppRestartReceiver] 🔔 AlarmManager triggered app restart
[AppRestartReceiver]    Action: com.example.hfc_app.RESTART_APP
[AppRestartReceiver]    Scheduled by: keepalive_service
[AppRestartReceiver] 🚀 Launching app from AlarmManager...
[AppLauncher] 🚀 Launching Flutter app from background...
[AppLauncher] ✅ App launch intent sent successfully
[AppRestartReceiver] 📊 Reschedule request from: keepalive_service
[AppRestartReceiver] 🔄 Rescheduling next keepalive restart (5 min)...
[AppLauncher] 🔔 Scheduling restart via broadcast in 300 seconds (by: keepalive_service)
[AppLauncher] ✅ Keepalive restart scheduled via broadcast
[AppRestartReceiver] ✅ Reschedule complete for: keepalive_service
```

### After 8 minutes (app closed):
```
[AppRestartReceiver] 🔔 AlarmManager triggered app restart
[AppRestartReceiver]    Action: com.example.hfc_app.RESTART_APP
[AppRestartReceiver]    Scheduled by: workmanager
[AppRestartReceiver] 🚀 Launching app from AlarmManager...
[AppLauncher] 🚀 Launching Flutter app from background...
[AppLauncher] ✅ App launch intent sent successfully
[AppRestartReceiver] 📊 Reschedule request from: workmanager
[AppRestartReceiver] 🔄 Rescheduling next workmanager restart (8 min)...
[AppLauncher] 🔔 Scheduling restart via broadcast in 480 seconds (by: workmanager)
[AppLauncher] ✅ Keepalive restart scheduled via broadcast
[AppRestartReceiver] ✅ Reschedule complete for: workmanager
```

## Debug Commands (ADB)

View alarm logs:
```bash
adb logcat | grep -E "AppLauncher|AppRestartReceiver|AppKeepalive|BackgroundSync"
```

Check if alarms are scheduled:
```bash
adb shell dumpsys alarm | grep hfc_app
```

Check battery optimization status:
```bash
adb shell dumpsys deviceidle whitelist | grep hfc_app
```

Trigger alarm manually (for testing):
```bash
adb shell am broadcast -a com.example.hfc_app.RESTART_APP -n com.example.hfc_app/.AppRestartReceiver
```

## Next Steps

1. ✅ Fixed `AppRestartReceiver.kt` to properly pass `scheduledBy` parameter
2. ⏳ Build new APK with fixed code
3. ⏳ Add exact alarm permission check/request
4. ⏳ Test on real device
5. ⏳ Monitor logs to confirm alarms fire

Run: `bash quick_build_fast.sh` to build the fixed APK.
