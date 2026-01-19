# AlarmManager App Relaunch - Troubleshooting & Fix Guide

## 🔍 Problem Statement

App does not automatically relaunch when mobile screen is OFF, even though AlarmManager-based relaunch system is implemented.

---

## ❌ Common Issues Found in Implementation

### Issue 1: Initial Alarm Never Scheduled ⚠️ **CRITICAL**

**Problem:**
- AlarmManager alarm is configured to reschedule itself after each trigger
- But if the FIRST alarm is never scheduled, the chain never starts
- The app initializes services but never calls the scheduling method

**Where to Check:**
Look in `MainActivity.kt` or main activity's `onCreate()` method:

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    
    // ❌ MISSING: Initial alarm scheduling
    // You might see WorkManager scheduled but NOT AlarmManager
    
    AppRestartWorker.schedule(applicationContext)  // ✅ This might be present
    // AppLauncher.scheduleKeepaliveRestart(...)    // ❌ This is MISSING!
}
```

**Fix Required:**
Add initial alarm scheduling in MainActivity onCreate:

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    
    // ... existing code ...
    
    // Schedule WorkManager (15-min backup)
    AppRestartWorker.schedule(applicationContext)
    Log.d(TAG, "✅ Native WorkManager scheduled (15-min restart)")
    
    // ⭐ ADD THIS: Schedule AlarmManager keepalive (5-min primary)
    AppLauncher.scheduleKeepaliveRestart(applicationContext, 300, "keepalive_service")
    Log.d(TAG, "✅ AlarmManager keepalive scheduled (5-min restart)")
}
```

---

### Issue 2: Missing Runtime Permission Checks (Android 12+) ⚠️ **CRITICAL**

**Problem:**
- Android 12+ (API 31+) requires runtime permission for `SCHEDULE_EXACT_ALARM`
- Manifest permission alone is NOT sufficient
- App must request permission and check if granted

**Where to Check:**
1. Search for `canScheduleExactAlarms()` in MainActivity - if not found, permission is NOT checked
2. Search for `ACTION_REQUEST_SCHEDULE_EXACT_ALARM` - if not found, permission is NOT requested

**Fix Required:**

**Step 1:** Add permission check methods to MainActivity:

```kotlin
/**
 * Check if exact alarm permission is granted (Android 12+)
 */
private fun checkExactAlarmPermission(): Boolean {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }
    return true // Older Android versions don't need this permission
}

/**
 * Request exact alarm permission (Android 12+)
 */
private fun requestExactAlarmPermission() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        try {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
            startActivity(intent)
            Toast.makeText(this, "Please enable 'Alarms & reminders' permission", Toast.LENGTH_LONG).show()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open exact alarm settings: ${e.message}")
            // Fallback to app settings
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } catch (ex: Exception) {
                Log.e(TAG, "Failed to open app settings: ${ex.message}")
            }
        }
    }
}
```

**Step 2:** Call permission check in onCreate():

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    
    // ... existing code ...
    
    // ⭐ ADD THIS: Check and request exact alarm permission
    if (!checkExactAlarmPermission()) {
        AlertDialog.Builder(this)
            .setTitle("Enable Exact Alarms")
            .setMessage(
                "To reliably restart the app when screen is off, " +
                "please enable 'Alarms & reminders' permission.\n\n" +
                "This ensures HC20 connection stays active."
            )
            .setPositiveButton("Enable") { _, _ ->
                requestExactAlarmPermission()
            }
            .setNegativeButton("Later") { dialog, _ ->
                dialog.dismiss()
                Log.d(TAG, "User declined exact alarm permission")
            }
            .setCancelable(false)
            .show()
    } else {
        Log.d(TAG, "✅ Exact alarm permission already granted")
    }
}
```

**Step 3:** Verify permission before scheduling alarm:

```kotlin
// In AppLauncher.kt or wherever alarms are scheduled
fun scheduleKeepaliveRestart(context: Context, delaySeconds: Int, scheduledBy: String) {
    try {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // ⭐ ADD THIS CHECK: Verify permission before scheduling
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                Log.e(TAG, "❌ Cannot schedule alarm - SCHEDULE_EXACT_ALARM permission not granted!")
                Log.e(TAG, "   User must enable 'Alarms & reminders' in Settings")
                return
            }
        }
        
        // ... rest of scheduling code ...
    } catch (e: Exception) {
        Log.e(TAG, "❌ Failed to schedule alarm: ${e.message}")
    }
}
```

---

### Issue 3: Missing USE_FULL_SCREEN_INTENT Runtime Permission (Android 14+) ⚠️ **IMPORTANT**

**Problem:**
- Android 14+ (API 34+) requires runtime permission for `USE_FULL_SCREEN_INTENT`
- Without this, full-screen intent won't show and app won't launch when screen is OFF
- Manifest permission alone is NOT sufficient on Android 14+

**Where to Check:**
Search for `canUseFullScreenIntent()` in MainActivity - if not found, this is missing.

**Fix Required:**

```kotlin
/**
 * Check if full screen intent permission is granted (Android 14+)
 */
private fun checkFullScreenIntentPermission(): Boolean {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // API 34
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return notificationManager.canUseFullScreenIntent()
    }
    return true // Older versions don't need runtime permission
}

/**
 * Request full screen intent permission (Android 14+)
 */
private fun requestFullScreenIntentPermission() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        try {
            val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
            Toast.makeText(this, "Please enable 'Full screen intent' permission", Toast.LENGTH_LONG).show()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open full screen intent settings: ${e.message}")
        }
    }
}

// Call in onCreate():
if (!checkFullScreenIntentPermission()) {
    AlertDialog.Builder(this)
        .setTitle("Enable Full Screen Intent")
        .setMessage(
            "To launch the app when screen is off, " +
            "please enable 'Full screen intent' permission."
        )
        .setPositiveButton("Enable") { _, _ ->
            requestFullScreenIntentPermission()
        }
        .setNegativeButton("Later", null)
        .show()
}
```

---

### Issue 4: Alarm Not Set with Correct Flags ⚠️ **MEDIUM**

**Problem:**
- AlarmManager on Android 12+ requires specific method calls
- Using wrong method causes alarm to not fire in Doze mode
- Must use `setExactAndAllowWhileIdle()` not `setExact()`

**Where to Check:**
Look in alarm scheduling code for:

```kotlin
// ❌ WRONG - Won't work in Doze mode:
alarmManager.setExact(...)
alarmManager.set(...)

// ✅ CORRECT - Works in Doze mode:
alarmManager.setExactAndAllowWhileIdle(...)
```

**Fix Required:**

```kotlin
fun scheduleKeepaliveRestart(context: Context, delaySeconds: Int, scheduledBy: String) {
    try {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // Create intent for broadcast receiver
        val intent = Intent(context, AppRestartReceiver::class.java).apply {
            action = "com.example.hfc_app.RESTART_APP"
            putExtra("scheduled_by", scheduledBy)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val triggerAtMillis = SystemClock.elapsedRealtime() + (delaySeconds * 1000L)
        
        // ⭐ USE THIS METHOD - Works in Doze mode
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,  // Wakes device
            triggerAtMillis,
            pendingIntent
        )
        
        Log.d(TAG, "✅ Alarm scheduled with setExactAndAllowWhileIdle")
    } catch (e: Exception) {
        Log.e(TAG, "❌ Failed to schedule alarm: ${e.message}")
    }
}
```

---

### Issue 5: BroadcastReceiver Not Rescheduling Alarm ⚠️ **CRITICAL**

**Problem:**
- Alarm fires once successfully
- But receiver forgets to schedule the NEXT alarm
- App launches once, but never again

**Where to Check:**
Look in `AppRestartReceiver.kt` `onReceive()` method:

```kotlin
override fun onReceive(context: Context, intent: Intent) {
    // Alarm triggered - launch app
    AppLauncherService.start(context)
    
    // ❌ MISSING: Reschedule next alarm!
    // Without this, alarm only fires ONCE
}
```

**Fix Required:**

```kotlin
override fun onReceive(context: Context, intent: Intent) {
    Log.d(TAG, "🔔 AlarmManager triggered - restarting app")
    
    // Check screen state
    val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    val isScreenOn = powerManager.isInteractive
    
    if (isScreenOn) {
        Log.d(TAG, "🔆 Screen is ON - ensuring service only")
        // Just ensure ForegroundService is running
        startForegroundServiceWithDevice(context)
    } else {
        Log.d(TAG, "🌙 Screen is OFF - launching app")
        // Launch app via full-screen intent
        AppLauncherService.start(context)
    }
    
    // ⭐ CRITICAL: Reschedule the next alarm
    val scheduledBy = intent.getStringExtra("scheduled_by") ?: "keepalive_service"
    AppLauncher.scheduleKeepaliveRestart(context, 300, scheduledBy) // 5 minutes
    Log.d(TAG, "✅ Next alarm rescheduled for 5 minutes")
}
```

---

### Issue 6: Battery Optimization Not Disabled ⚠️ **IMPORTANT**

**Problem:**
- Android kills apps that are battery optimized
- AlarmManager works but app gets killed immediately after launch
- User never disables battery optimization

**Where to Check:**
Search for `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` in code.

**Fix Required:**

```kotlin
/**
 * Check if battery optimization is disabled
 */
private fun isBatteryOptimizationDisabled(): Boolean {
    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
    return powerManager.isIgnoringBatteryOptimizations(packageName)
}

/**
 * Request to disable battery optimization
 */
private fun requestBatteryOptimizationExemption() {
    if (!isBatteryOptimizationDisabled()) {
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request battery optimization exemption: ${e.message}")
        }
    }
}

// Call in onCreate():
if (!isBatteryOptimizationDisabled()) {
    AlertDialog.Builder(this)
        .setTitle("Disable Battery Optimization")
        .setMessage(
            "To keep the app running in background, " +
            "please disable battery optimization for this app."
        )
        .setPositiveButton("Disable") { _, _ ->
            requestBatteryOptimizationExemption()
        }
        .setNegativeButton("Later", null)
        .show()
}
```

---

### Issue 7: Wrong PendingIntent Flags ⚠️ **MEDIUM**

**Problem:**
- Android 12+ requires `FLAG_IMMUTABLE` or `FLAG_MUTABLE` flag
- Using old flags causes SecurityException

**Fix Required:**

```kotlin
// ❌ WRONG - Crashes on Android 12+:
PendingIntent.getBroadcast(context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT)

// ✅ CORRECT - Works on all Android versions:
PendingIntent.getBroadcast(
    context, 
    requestCode, 
    intent,
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
)
```

---

## 📋 Complete Fix Checklist

Use this checklist to verify all fixes are applied:

### ✅ Manifest Permissions (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

### ✅ Manifest Components
```xml
<!-- AppRestartReceiver must be declared -->
<receiver
    android:name=".AppRestartReceiver"
    android:enabled="true"
    android:exported="false">
    <intent-filter>
        <action android:name="com.example.hfc_app.RESTART_APP" />
    </intent-filter>
</receiver>

<!-- AppLauncherService must be declared -->
<service
    android:name=".AppLauncherService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="dataSync" />
```

### ✅ MainActivity.onCreate() Must Include:
- [ ] Initial alarm scheduling: `AppLauncher.scheduleKeepaliveRestart()`
- [ ] Exact alarm permission check (Android 12+)
- [ ] Full-screen intent permission check (Android 14+)
- [ ] Battery optimization exemption request
- [ ] Overlay permission check (for screen-ON restart)

### ✅ AppRestartReceiver.onReceive() Must Include:
- [ ] Check screen state (ON vs OFF)
- [ ] Launch app via AppLauncherService (screen OFF)
- [ ] Start ForegroundService only (screen ON)
- [ ] **RESCHEDULE next alarm** (CRITICAL!)

### ✅ Alarm Scheduling Code Must Use:
- [ ] `setExactAndAllowWhileIdle()` not `setExact()`
- [ ] `AlarmManager.ELAPSED_REALTIME_WAKEUP` for wake capability
- [ ] `PendingIntent.FLAG_IMMUTABLE` flag
- [ ] Check `canScheduleExactAlarms()` before scheduling (Android 12+)

### ✅ AppLauncherService Must Include:
- [ ] Full-screen intent in notification
- [ ] Wake lock acquisition
- [ ] Category = CATEGORY_CALL
- [ ] Priority = PRIORITY_HIGH
- [ ] Start as foreground service

---

## 🧪 Testing Procedure

### Test 1: Initial Setup
1. Install app
2. Open app - should see permission dialogs
3. Grant all permissions:
   - Alarms & reminders
   - Display over other apps
   - Full screen intent (Android 14+)
   - Battery optimization disabled

### Test 2: Screen OFF Relaunch
1. Open app and connect to HC20 device
2. Lock phone (screen OFF)
3. Swipe app away from recent apps
4. Wait 5-6 minutes
5. **Expected:** App should auto-launch and show on lock screen

### Test 3: Verify Logs
Check logcat for these messages:
```
✅ AlarmManager keepalive scheduled (5-min restart)
🔔 AlarmManager triggered - restarting app
🌙 Screen is OFF - launching app
🚀 Starting AppLauncherService...
✅ Next alarm rescheduled for 5 minutes
```

### Test 4: Verify Alarm Persistence
1. Trigger relaunch once (Test 2)
2. Swipe app away again
3. Wait another 5-6 minutes
4. **Expected:** App relaunches AGAIN (confirms reschedule works)

---

## 🐛 Debugging Tips

### If alarm never fires:
1. Check: `adb shell dumpsys alarm | grep "com.example.hfc_app"`
   - Should show scheduled alarm
2. Check permission: Settings → Apps → Your App → Alarms & reminders
3. Check battery optimization: Settings → Apps → Your App → Battery → Unrestricted

### If alarm fires but app doesn't launch:
1. Check full-screen intent permission (Android 14+)
2. Check logcat for SecurityException
3. Verify AppLauncherService is declared in manifest
4. Check wake lock acquisition in logs

### If app launches once but never again:
1. Check AppRestartReceiver reschedules alarm
2. Verify `scheduleKeepaliveRestart()` is called in `onReceive()`
3. Check logcat for "Next alarm rescheduled" message

### If app crashes on Android 12+:
1. Check PendingIntent uses `FLAG_IMMUTABLE`
2. Verify exact alarm permission is granted
3. Check `canScheduleExactAlarms()` before scheduling

---

## 📱 Device-Specific Issues

### Xiaomi/MIUI:
- Requires "Autostart" permission in Security app
- Go to: Security → Permissions → Autostart → Enable for your app

### Samsung One UI:
- "Put app to sleep" must be disabled
- Go to: Settings → Battery → Background usage limits → Never sleeping apps

### Huawei/EMUI:
- Requires manual startup permission
- Go to: Settings → Apps → Launch → Enable manual launch

### OnePlus/OxygenOS:
- "Deep optimization" must be disabled
- Go to: Settings → Battery → Battery optimization → Disable

---

## 🎯 Priority Order for Fixes

**Fix in this order for fastest results:**

1. **CRITICAL:** Add initial alarm scheduling in MainActivity.onCreate()
2. **CRITICAL:** Add alarm rescheduling in AppRestartReceiver.onReceive()
3. **CRITICAL:** Request SCHEDULE_EXACT_ALARM permission (Android 12+)
4. **IMPORTANT:** Request battery optimization exemption
5. **IMPORTANT:** Request full-screen intent permission (Android 14+)
6. **MEDIUM:** Use correct alarm scheduling method (`setExactAndAllowWhileIdle`)
7. **MEDIUM:** Use correct PendingIntent flags (`FLAG_IMMUTABLE`)

Apply fixes in this order and test after each fix to identify which one resolves the issue.

---

## 📚 Additional Resources

- [Android AlarmManager Best Practices](https://developer.android.com/training/scheduling/alarms)
- [Full-Screen Intent Guide](https://developer.android.com/about/versions/14/changes/fgs-types-required#exemptions)
- [Schedule Exact Alarms](https://developer.android.com/about/versions/12/behavior-changes-12#exact-alarm-permission)
- [Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby)

---

**Document Version:** 1.0  
**Last Updated:** January 19, 2026  
**Applies To:** Android 8.0+ (API 26+)
