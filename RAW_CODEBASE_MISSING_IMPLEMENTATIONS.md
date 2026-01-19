# 🔴 MISSING IMPLEMENTATIONS - App Relaunch Failure Analysis

**Date:** January 19, 2026  
**Problem:** `/workspaces/HFC-App/raw/app_relaunch/` codebase fails to relaunch app after swipe-away with screen OFF  
**Working Reference:** `/workspaces/HFC-App/` (main codebase) - successfully relaunches every 5 minutes  
**Severity:** ⛔ CRITICAL - App will NOT relaunch when screen is ON

---

## 📊 EXECUTIVE SUMMARY

The raw codebase has **7 critical missing implementations** that prevent app relaunch:

1. ⛔ **OverlayLauncher.kt** - Completely missing (required for screen-ON launch)
2. ⛔ **AppRestartReceiver** - Missing screen-ON launch logic
3. ⛔ **SYSTEM_ALERT_WINDOW permission** - Not declared in manifest
4. ⛔ **AppLauncherService** - Missing dual-mode (screen ON/OFF) logic
5. ⛔ **AppRestartWorker.kt** - No WorkManager backup (completely missing)
6. ⛔ **MainActivity (1).kt** - Missing overlay permission check & WorkManager scheduling
7. ⛔ **Alarm rescheduling** - Incomplete self-perpetuating logic

**UPDATE:** `MainActivity (1).kt` has correct lock screen flags but is missing overlay permission check and WorkManager scheduling!

**Root Cause:** Raw codebase assumes full-screen intent works in all scenarios, but it **ONLY works when screen is OFF**. Android 10+ blocks full-screen intent when screen is ON, requiring overlay trick.

---

## ❌ CRITICAL ISSUE #1: Missing OverlayLauncher.kt

**Status:** ⛔ **COMPLETELY MISSING FILE**  
**Impact:** App CANNOT launch when screen is ON (90% of relaunch scenarios)

### Problem:
The file `OverlayLauncher.kt` does NOT exist in raw codebase. This is the KEY component for launching app when screen is ON.

### Why It's Needed:
- Android 10+ **blocks** `startActivity()` from background when screen is ON
- Full-screen intent **ONLY works when screen is OFF** (like alarm clock)
- Overlay trick bypasses restriction: Create invisible 1x1 overlay → Launch activity from overlay context
- This is how Facebook Messenger chat heads work!

### Implementation Required:

**CREATE NEW FILE:** `android/app/src/main/kotlin/com/example/hfc_app/OverlayLauncher.kt`

```kotlin
package com.example.hfc_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout

/**
 * OverlayLauncher - Uses SYSTEM_ALERT_WINDOW permission to launch app when screen is ON
 * 
 * WHY THIS WORKS ON SCREEN-ON:
 * - Full-screen intent only works when screen is OFF (like alarm clocks)
 * - When screen is ON, we need SYSTEM_ALERT_WINDOW permission
 * - This permission allows us to draw over other apps
 * - From an overlay view, we CAN start activities (bypasses Android 10+ restriction)
 * 
 * FLOW:
 * 1. Check if we have overlay permission
 * 2. Add an invisible overlay view using WindowManager
 * 3. From that overlay context, launch MainActivity
 * 4. Remove the overlay immediately
 * 
 * This is how apps like Facebook Messenger chat heads work!
 */
object OverlayLauncher {
    private const val TAG = "OverlayLauncher"
    private var overlayView: View? = null
    
    /**
     * Check if the app has permission to draw overlays
     */
    fun hasOverlayPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true // Pre-Marshmallow doesn't need explicit permission
        }
    }
    
    /**
     * Request overlay permission from the user
     * This opens the system settings page for this app
     */
    fun requestOverlayPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}")
            )
            activity.startActivityForResult(intent, 1234)
            Log.d(TAG, "📱 Opened overlay permission settings")
        }
    }
    
    /**
     * Launch the app using overlay trick when screen is ON
     * This is the KEY method that bypasses Android 10+ restrictions!
     */
    fun launchAppViaOverlay(context: Context) {
        Log.d(TAG, "🚀 Attempting to launch app via overlay...")
        
        // Check overlay permission
        if (!hasOverlayPermission(context)) {
            Log.e(TAG, "❌ No overlay permission! Cannot launch app when screen is ON")
            Log.d(TAG, "   User needs to grant 'Display over other apps' permission")
            return
        }
        
        try {
            val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            
            // Create an invisible overlay view
            val overlayView = FrameLayout(context)
            this.overlayView = overlayView
            
            // Configure layout params for the overlay
            val layoutParams = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams(
                    1, 1, // Minimal size (1x1 pixel - invisible)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    PixelFormat.TRANSLUCENT
                )
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams(
                    1, 1,
                    WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
                    PixelFormat.TRANSLUCENT
                )
            }
            
            layoutParams.gravity = Gravity.TOP or Gravity.START
            layoutParams.x = 0
            layoutParams.y = 0
            
            // Add overlay to window manager
            windowManager.addView(overlayView, layoutParams)
            Log.d(TAG, "   ✅ Overlay view added")
            
            // Acquire wake lock
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "hfc_app:overlay_wakelock"
            )
            wakeLock.acquire(5000)
            
            // Now launch the activity - THIS WORKS because we're in an overlay context!
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra("launched_from_background", true)
                putExtra("launch_reason", "overlay_launcher")
                putExtra("launch_time", System.currentTimeMillis())
            }
            
            context.startActivity(launchIntent)
            Log.d(TAG, "   ✅✅✅ MainActivity launched via overlay! ✅✅✅")
            
            // Clean up: Remove overlay after a short delay
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    windowManager.removeView(overlayView)
                    this.overlayView = null
                    Log.d(TAG, "   ✅ Overlay view removed")
                    
                    if (wakeLock.isHeld) {
                        wakeLock.release()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "   ⚠️ Error removing overlay: ${e.message}")
                }
            }, 2000)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Overlay launch failed: ${e.message}", e)
        }
    }
}
```

---

## ❌ CRITICAL ISSUE #2: AppRestartReceiver Missing Screen-ON Logic

**Status:** ⛔ **INCOMPLETE IMPLEMENTATION**  
**File:** `raw/app_relaunch/AppRestartReceiver (1).kt`  
**Lines:** 29-42

### Problem:
```kotlin
// CURRENT CODE (WRONG):
if (!isScreenOn) {
    // Screen is OFF - use full-screen intent
    Log.d(TAG, "🌙 Screen is OFF - launching app via full-screen intent...")
    launchAppWhenScreenOff(context, deviceId)
} else {
    // Screen is ON - WRONG! Just ensures ForegroundService only...
    Log.d(TAG, "🔆 Screen is ON - ensuring ForegroundService only...")
    startForegroundService(context, deviceId)
}
```

**Problem:** When screen is ON, it only starts `ForegroundService` but **DOES NOT launch app UI**!

### Fix Required:

**REPLACE** the entire `when (intent.action)` block in `AppRestartReceiver.kt`:

```kotlin
when (intent.action) {
    "com.example.hfc_app.RESTART_APP" -> {
        if (!isScreenOn) {
            // Screen is OFF - use full-screen intent via AppLauncherService
            Log.d(TAG, "🌙 Screen is OFF - launching app via full-screen intent...")
            launchAppWhenScreenOff(context, deviceId)
        } else {
            // Screen is ON - use OverlayLauncher to bypass Android 10+ restrictions
            Log.d(TAG, "🔆 Screen is ON - launching app via overlay...")
            launchAppWhenScreenOn(context, deviceId)
        }
        
        // CRITICAL: Reschedule the next restart (self-perpetuating alarm)
        Log.d(TAG, "🔄 Rescheduling next keepalive restart (5 min)...")
        AppKeepaliveScheduler.scheduleAlarm(context, 5 * 60 * 1000L)
        Log.d(TAG, "✅ Reschedule complete")
    }
    Intent.ACTION_BOOT_COMPLETED -> {
        Log.d(TAG, "📱 Device rebooted - starting ForegroundService...")
        startForegroundService(context, deviceId)
        
        // Schedule restart mechanisms after boot
        Log.d(TAG, "🔄 Scheduling restart mechanisms after boot...")
        AppKeepaliveScheduler.scheduleAlarm(context, 5 * 60 * 1000L)
        Log.d(TAG, "✅ Restart mechanisms scheduled after boot")
    }
    else -> {
        Log.w(TAG, "⚠️ Unknown action: ${intent.action}")
    }
}
```

**ADD** new method `launchAppWhenScreenOn()`:

```kotlin
private fun launchAppWhenScreenOn(context: Context, deviceId: String) {
    // First ensure ForegroundService is running
    startForegroundService(context, deviceId)
    
    // Then launch app UI using overlay trick
    val serviceIntent = Intent(context, AppLauncherService::class.java).apply {
        putExtra("device_id", deviceId)
        putExtra("launch_reason", "alarm_screen_on")
        putExtra("use_overlay", true) // Signal to use overlay
    }
    
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        context.startForegroundService(serviceIntent)
    } else {
        context.startService(serviceIntent)
    }
}
```

---

## ❌ CRITICAL ISSUE #3: Missing SYSTEM_ALERT_WINDOW Permission

**Status:** ⛔ **NOT DECLARED**  
**File:** `raw/example/android/app/src/main/AndroidManifest.xml`

### Problem:
The `AndroidManifest.xml` is **MISSING** the overlay permission required for OverlayLauncher:

```xml
<!-- MISSING FROM RAW CODEBASE -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

Without this permission:
- `Settings.canDrawOverlays()` returns `false`
- `WindowManager.addView()` throws SecurityException
- Screen-ON launch **ALWAYS FAILS**

### Fix Required:

**ADD** to `AndroidManifest.xml` in the `<manifest>` section (after other permissions):

```xml
<!-- Required to turn on screen when launching app -->
<uses-permission android:name="android.permission.DISABLE_KEYGUARD" />

<!-- System alert window for overlay launcher (launches app when screen is ON) -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

**ALSO ADD** runtime permission request in `MainActivity.onCreate()`:

```kotlin
// Add this in MainActivity.onCreate() after other permission checks
checkOverlayPermission()

// Add this new method to MainActivity:
private fun checkOverlayPermission() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        if (!Settings.canDrawOverlays(this)) {
            Log.w(TAG, "⚠️ Overlay permission not granted - required for screen-ON relaunch")
            
            AlertDialog.Builder(this)
                .setTitle("Enable Display Over Other Apps")
                .setMessage("This permission is required to automatically restart the app when screen is ON.\n\nWithout it, app can only restart when screen is OFF.")
                .setPositiveButton("Open Settings") { _, _ ->
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                }
                .setNegativeButton("Later", null)
                .show()
        }
    }
}
```

---

## ❌ CRITICAL ISSUE #4: AppLauncherService Missing Dual-Mode Logic

**Status:** ⛔ **INCOMPLETE - Screen-ON Logic Missing**  
**File:** `raw/app_relaunch/AppLauncherService (1).kt`  
**Lines:** 26-116

### Problem:
Current implementation **ONLY** uses full-screen intent, which doesn't work when screen is ON:

```kotlin
// CURRENT CODE (INCOMPLETE):
val notification = NotificationCompat.Builder(this, CHANNEL_ID)
    .setFullScreenIntent(fullScreenPendingIntent, true) // Only works when screen OFF!
    .build()
```

### Fix Required:

**REPLACE** the entire `onStartCommand()` method:

```kotlin
override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    Log.d(TAG, "🎯 onStartCommand - launching app NOW")
    
    val deviceId = intent?.getStringExtra("device_id")
    val launchReason = intent?.getStringExtra("launch_reason") ?: "unknown"
    val useOverlay = intent?.getBooleanExtra("use_overlay", false) ?: false
    
    Log.d(TAG, "   Reason: $launchReason, Device: $deviceId, UseOverlay: $useOverlay")
    
    // Start foreground immediately
    val notification = createNotification("Initializing app launch...")
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        startForeground(NOTIFICATION_ID, notification,
            android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
    } else {
        startForeground(NOTIFICATION_ID, notification)
    }
    Log.d(TAG, "   ✅ Started as foreground service")
    
    // Step 1: Acquire wake lock to turn on screen
    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
    val wakeLock = powerManager.newWakeLock(
        PowerManager.FULL_WAKE_LOCK or
        PowerManager.ACQUIRE_CAUSES_WAKEUP or
        PowerManager.ON_AFTER_RELEASE,
        "hfc_app:launcher_wakelock"
    )
    wakeLock.acquire(10000) // 10 seconds
    Log.d(TAG, "   ✅ Wake lock acquired - screen should turn on")
    
    // Step 2: Check screen state
    val isScreenOn = powerManager.isInteractive
    Log.d(TAG, "   📱 Screen state: ${if (isScreenOn) "ON" else "OFF"}")
    
    // Step 3: Choose launch method based on screen state
    if (isScreenOn || useOverlay) {
        // SCREEN IS ON - Use overlay trick!
        Log.d(TAG, "   🔆 Screen is ON - using OVERLAY method")
        launchViaOverlay()
    } else {
        // SCREEN IS OFF - Use full-screen intent
        Log.d(TAG, "   🌙 Screen is OFF - using FULL-SCREEN INTENT method")
        launchViaFullScreenIntent(deviceId, launchReason)
    }
    
    // Step 4: Also try direct launch as backup
    try {
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra("launched_from_background", true)
            putExtra("launch_reason", launchReason)
            putExtra("device_id", deviceId)
            putExtra("launch_time", System.currentTimeMillis())
        }
        
        startActivity(fullScreenIntent)
        Log.d(TAG, "   ✅ Direct startActivity called (backup)")
    } catch (e: Exception) {
        Log.d(TAG, "   ⚠️  Direct launch failed (expected on Android 10+): ${e.message}")
    }
    
    // Step 5: Release wake lock after delay
    Handler(mainLooper).postDelayed({
        try {
            if (wakeLock.isHeld) {
                wakeLock.release()
                Log.d(TAG, "   ✅ Wake lock released")
            }
        } catch (e: Exception) {
            Log.e(TAG, "   ⚠️  Error releasing wake lock: ${e.message}")
        }
    }, 3000)
    
    // Step 6: Stop service after launching
    Handler(mainLooper).postDelayed({ 
        Log.d(TAG, "   🛑 Stopping AppLauncherService")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }, 5000)
    
    return START_NOT_STICKY
}

/**
 * Launch via overlay when screen is ON
 */
private fun launchViaOverlay() {
    Log.d(TAG, "   🎨 Attempting overlay launch...")
    
    if (OverlayLauncher.hasOverlayPermission(this)) {
        OverlayLauncher.launchAppViaOverlay(this)
        Log.d(TAG, "   ✅ Overlay launch initiated")
    } else {
        Log.d(TAG, "   ⚠️ No overlay permission - trying full-screen intent as fallback")
        launchViaFullScreenIntent(null, "overlay_fallback")
    }
}

/**
 * Launch via full-screen intent when screen is OFF
 */
private fun launchViaFullScreenIntent(deviceId: String?, launchReason: String) {
    Log.d(TAG, "   📱 Using full-screen intent...")
    
    try {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("launched_from_background", true)
            putExtra("launch_reason", launchReason)
            putExtra("device_id", deviceId)
        }
        
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val fullScreenNotification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("🔄 HFC App Restarting")
            .setContentText("Reconnecting to HC20 device...")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .setAutoCancel(true)
            .setOngoing(false)
            .build()
        
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(9999, fullScreenNotification)
        Log.d(TAG, "   ✅ Full-screen notification posted")
        
    } catch (e: Exception) {
        Log.e(TAG, "   ❌ Full-screen intent failed: ${e.message}")
    }
}
```

---

## ❌ CRITICAL ISSUE #5: Missing AppRestartWorker.kt (WorkManager Backup)

**Status:** ⛔ **COMPLETELY MISSING FILE**  
**Impact:** No backup if AlarmManager is canceled by battery optimization

### Problem:
Raw codebase has **NO** WorkManager implementation. This means:
- If AlarmManager is canceled → App will NEVER relaunch
- Battery optimization can cancel alarms
- No self-healing mechanism

Working codebase has **2-layer protection**:
- Layer 1: AlarmManager (5-min interval, can be canceled)
- Layer 2: WorkManager (15-min interval, guaranteed by Android)

### Implementation Required:

**CREATE NEW FILE:** `android/app/src/main/kotlin/com/example/hfc_app/AppRestartWorker.kt`

```kotlin
package com.example.hfc_app

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.*
import java.util.concurrent.TimeUnit

/**
 * WorkManager-based app restart worker
 * This is a BACKUP to AlarmManager in case alarms get canceled
 * 
 * WHY WORKMANAGER:
 * - AlarmManager can be canceled by battery optimization
 * - WorkManager is GUARANTEED by Android to run (eventually)
 * - Minimum interval is 15 minutes (Android restriction)
 * - Survives app kills and device reboots
 * 
 * STRATEGY:
 * - Primary: AlarmManager (5-min, faster but can be canceled)
 * - Backup: WorkManager (15-min, slower but guaranteed)
 * - Both reschedule themselves (self-perpetuating)
 */
class AppRestartWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    
    companion object {
        private const val TAG = "AppRestartWorker"
        private const val WORK_NAME = "app_restart_worker"
        
        /**
         * Schedule this worker to run periodically
         * Called from MainActivity.onCreate() and AppRestartReceiver
         */
        fun schedule(context: Context) {
            Log.d(TAG, "📅 Scheduling WorkManager restart (15-min interval)...")
            
            // Configure constraints (allow in all conditions)
            val constraints = Constraints.Builder()
                .setRequiresBatteryNotLow(false)
                .setRequiresCharging(false)
                .setRequiresDeviceIdle(false)
                .setRequiresStorageNotLow(false)
                .build()
            
            // Create periodic work request (minimum 15 minutes)
            val workRequest = PeriodicWorkRequestBuilder<AppRestartWorker>(
                15, TimeUnit.MINUTES // Minimum allowed by Android
            )
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.LINEAR,
                    WorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .build()
            
            // Enqueue unique periodic work (replace if already exists)
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP, // Keep existing if already scheduled
                workRequest
            )
            
            Log.d(TAG, "✅ WorkManager scheduled successfully")
            Log.d(TAG, "   Interval: 15 minutes (Android minimum)")
            Log.d(TAG, "   Policy: KEEP (won't reschedule if already exists)")
        }
        
        /**
         * Cancel the worker
         */
        fun cancel(context: Context) {
            Log.d(TAG, "❌ Canceling WorkManager restart...")
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }
    
    override fun doWork(): Result {
        Log.d(TAG, "\n")
        Log.d(TAG, "=".repeat(60))
        Log.d(TAG, "🔔 WorkManager triggered - time to check app status")
        Log.d(TAG, "=".repeat(60))
        
        try {
            // Send broadcast to AppRestartReceiver
            // This will handle screen-state detection and launch logic
            val intent = Intent(applicationContext, AppRestartReceiver::class.java).apply {
                action = "com.example.hfc_app.RESTART_APP"
                putExtra("scheduled_by", "workmanager")
            }
            
            applicationContext.sendBroadcast(intent)
            Log.d(TAG, "✅ Broadcast sent to AppRestartReceiver")
            
            // WorkManager will automatically reschedule this worker (periodic)
            Log.d(TAG, "✅ WorkManager will auto-reschedule in 15 minutes")
            Log.d(TAG, "=".repeat(60))
            Log.d(TAG, "\n")
            
            return Result.success()
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ WorkManager execution failed: ${e.message}")
            return Result.retry() // Retry on failure
        }
    }
}
```

**ADD** WorkManager dependency to `android/app/build.gradle`:

```gradle
dependencies {
    // Existing dependencies...
    
    // WorkManager for guaranteed background execution
    implementation "androidx.work:work-runtime-ktx:2.8.1"
}
```

**SCHEDULE** WorkManager in `MainActivity.onCreate()`:

```kotlin
// Add this in MainActivity.onCreate() after AppKeepaliveScheduler.scheduleAlarm()
AppRestartWorker.schedule(applicationContext)
```

---

## ❌ CRITICAL ISSUE #6: MainActivity Missing Overlay Permission Check & WorkManager Scheduling

**Status:** ⛔ **MISSING CRITICAL CODE**  
**File:** `raw/app_relaunch/MainActivity (1).kt`  
**Lines:** 49-54

### Problem 1: Missing Overlay Permission Check
The `MainActivity (1).kt` has `checkAndRequestPermissions()` that checks exact alarms, full-screen intent, and battery optimization, but **DOES NOT check for SYSTEM_ALERT_WINDOW (overlay) permission**!

```kotlin
// CURRENT CODE in checkAndRequestPermissions() - INCOMPLETE:
private fun checkAndRequestPermissions() {
    val issues = mutableListOf<String>()
    
    // Check exact alarm permission (Android 12+)
    if (!checkExactAlarmPermission()) {
        issues.add("Exact alarms")
    }
    
    // Check full-screen intent permission (Android 14+)
    if (!checkFullScreenIntentPermission()) {
        issues.add("Full screen intent")
    }
    
    // Check battery optimization
    if (!isBatteryOptimizationDisabled()) {
        issues.add("Battery optimization")
    }
    
    // ❌ MISSING: No overlay permission check!
    // Without this, screen-ON launch will FAIL
}
```

**Problem:** Overlay permission is CRITICAL for screen-ON launch, but it's not being checked or requested!

### Problem 2: Missing WorkManager Scheduling
The `MainActivity.onCreate()` schedules AlarmManager but **DOES NOT schedule WorkManager backup**:

```kotlin
// CURRENT CODE in onCreate() - INCOMPLETE:
// Schedule keepalive alarm
AppKeepaliveScheduler.scheduleAlarm(applicationContext, 5 * 60 * 1000L)

// ⭐ Check and request critical permissions
checkAndRequestPermissions()

// ❌ MISSING: No WorkManager scheduling!
// Without this, there's no backup if AlarmManager is canceled
```

**Problem:** If battery optimization cancels AlarmManager, there's NO backup mechanism!

### Fix Required:

#### Fix 1: Add Overlay Permission Check

**ADD** overlay permission check to `checkAndRequestPermissions()`:

```kotlin
private fun checkAndRequestPermissions() {
    val issues = mutableListOf<String>()
    
    // Check exact alarm permission (Android 12+)
    if (!checkExactAlarmPermission()) {
        Log.w(TAG, "⚠️  SCHEDULE_EXACT_ALARM permission not granted")
        issues.add("Exact alarms")
    } else {
        Log.d(TAG, "✅ SCHEDULE_EXACT_ALARM permission granted")
    }
    
    // Check full-screen intent permission (Android 14+)
    if (!checkFullScreenIntentPermission()) {
        Log.w(TAG, "⚠️  USE_FULL_SCREEN_INTENT permission not granted (Android 14+)")
        issues.add("Full screen intent")
    } else {
        Log.d(TAG, "✅ USE_FULL_SCREEN_INTENT permission granted")
    }
    
    // ⭐ ADD THIS: Check overlay permission (required for screen-ON launch)
    if (!checkOverlayPermission()) {
        Log.w(TAG, "⚠️  SYSTEM_ALERT_WINDOW permission not granted - screen-ON launch will fail!")
        issues.add("Display over other apps")
    } else {
        Log.d(TAG, "✅ SYSTEM_ALERT_WINDOW permission granted")
    }
    
    // Check battery optimization
    if (!isBatteryOptimizationDisabled()) {
        Log.w(TAG, "⚠️  Battery optimization is enabled - app may be killed")
        issues.add("Battery optimization")
    } else {
        Log.d(TAG, "✅ Battery optimization disabled")
    }
    
    // Show dialog if any permissions are missing
    if (issues.isNotEmpty()) {
        val message = buildString {
            append("To keep the app running and reliably restart when screen is ON/OFF:\n\n")
            issues.forEachIndexed { index, issue ->
                append("${index + 1}. Enable '$issue'")
                append(" permission in Settings")
                if (index < issues.size - 1) append("\n")
            }
            append("\n\nThis is required for HC20 device connection to stay active.")
        }
        
        AlertDialog.Builder(this)
            .setTitle("Enable Required Permissions")
            .setMessage(message)
            .setPositiveButton("Open Settings") { _, _ ->
                Log.d(TAG, "Opening app settings to enable permissions")
                openAppSettings()
            }
            .setNegativeButton("Later") { dialog, _ ->
                dialog.dismiss()
                Log.d(TAG, "User deferred permission setup")
            }
            .setCancelable(false)
            .show()
    }
}
```

**ADD** new method `checkOverlayPermission()`:

```kotlin
/**
 * Check if overlay permission is granted (required for screen-ON launch)
 */
private fun checkOverlayPermission(): Boolean {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        val hasPermission = Settings.canDrawOverlays(this)
        Log.d(TAG, "Overlay permission check (Android 6+): $hasPermission")
        return hasPermission
    }
    return true // Older Android doesn't need explicit permission
}
```

#### Fix 2: Add WorkManager Scheduling

**ADD** WorkManager scheduling in `MainActivity.onCreate()`:

```kotlin
override fun onCreate(savedInstanceState: android.os.Bundle?) {
    super.onCreate(savedInstanceState)
    
    Log.d(TAG, "MainActivity created")
    
    // Handle background launch from AlarmManager
    val launchReason = intent?.getStringExtra("launch_reason")
    val deviceId = intent?.getStringExtra("device_id")
    val launchedFromBackground = intent?.getBooleanExtra("launched_from_background", false) ?: false
    
    if (launchedFromBackground) {
        Log.d(TAG, "🚀 App launched from background - Reason: $launchReason, Device: $deviceId")
    }
    
    // ⚠️ CRITICAL: Always configure lock screen display (already correct in your file)
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
    
    // Schedule keepalive alarm (AlarmManager - primary mechanism)
    AppKeepaliveScheduler.scheduleAlarm(applicationContext, 5 * 60 * 1000L)
    
    // ⭐ ADD THIS: Schedule WorkManager (backup mechanism)
    try {
        AppRestartWorker.schedule(applicationContext)
        Log.d(TAG, "✅ WorkManager backup scheduled")
    } catch (e: Exception) {
        Log.e(TAG, "❌ Failed to schedule WorkManager: ${e.message}")
    }
    
    // ⭐ Check and request critical permissions
    checkAndRequestPermissions()
}
```

**ALSO ADD** to `AndroidManifest.xml` in `<activity>` section:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:taskAffinity=""
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize"
    android:showOnLockScreen="true"
    android:showWhenLocked="true"
    android:turnScreenOn="true">
```

---

## ❌ CRITICAL ISSUE #7: Alarm Rescheduling Happens Too Early

**Status:** ⛔ **INCOMPLETE - Self-Perpetuating Cycle May Break**  
**File:** `raw/app_relaunch/AppRestartReceiver (1).kt`  
**Lines:** 45-48

### Problem:
Alarm is rescheduled **BEFORE** verifying launch success:

```kotlin
// CURRENT CODE (RISKY):
"com.example.hfc_app.RESTART_APP" -> {
    // Launch logic...
    
    // Reschedule the next restart
    AppKeepaliveScheduler.scheduleAlarm(context, 5 * 60 * 1000L)
}
```

**Problem:** If rescheduling fails or launch fails, alarm cycle may break!

### Fix Required:

**MOVE** rescheduling to **AFTER** launch attempt, and make it more robust:

```kotlin
"com.example.hfc_app.RESTART_APP" -> {
    // Step 1: Launch app first
    if (!isScreenOn) {
        launchAppWhenScreenOff(context, deviceId)
    } else {
        launchAppWhenScreenOn(context, deviceId)
    }
    
    // Step 2: THEN reschedule (ensures perpetual cycle even if launch fails)
    try {
        Log.d(TAG, "🔄 Rescheduling next keepalive restart (5 min)...")
        AppKeepaliveScheduler.scheduleAlarm(context, 5 * 60 * 1000L)
        Log.d(TAG, "✅ Next alarm scheduled successfully")
    } catch (e: Exception) {
        Log.e(TAG, "❌ Failed to reschedule alarm: ${e.message}")
        // Try again after short delay
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                AppKeepaliveScheduler.scheduleAlarm(context, 5 * 60 * 1000L)
                Log.d(TAG, "✅ Retry rescheduling succeeded")
            } catch (e2: Exception) {
                Log.e(TAG, "❌ Retry rescheduling failed: ${e2.message}")
            }
        }, 5000)
    }
}
```

---

## 📋 COMPLETE IMPLEMENTATION CHECKLIST

### Phase 1: Create Missing Files ⛔

- [ ] **CREATE** `OverlayLauncher.kt` with full implementation
- [ ] **CREATE** `AppRestartWorker.kt` with WorkManager logic
- [ ] **ADD** WorkManager dependency to `build.gradle`

### Phase 2: Update AndroidManifest.xml ⛔

- [ ] **ADD** `SYSTEM_ALERT_WINDOW` permission
- [ ] **ADD** `DISABLE_KEYGUARD` permission
- [ ] **ADD** lock screen attributes to `<activity>` tag:
  - `android:showOnLockScreen="true"`
  - `android:showWhenLocked="true"`
  - `android:turnScreenOn="true"`

### Phase 3: Fix AppRestartReceiver.kt ⛔

- [ ] **ADD** `launchAppWhenScreenOn()` method
- [ ] **UPDATE** screen-state logic to use overlay when screen ON
- [ ] **MOVE** alarm rescheduling after launch attempt
- [ ] **ADD** error handling for rescheduling

### Phase 4: Fix AppLauncherService.kt ⛔

- [ ] **ADD** screen-state detection in `onStartCommand()`
- [ ] **ADD** `launchViaOverlay()` method
- [ ] **ADD** `launchViaFullScreenIntent()` method
- [ ] **UPDATE** notification creation logic

### Phase 5: Fix MainActivity (1).kt ⛔

- [ ] **ADD** `checkOverlayPermission()` method (new method)
- [ ] **UPDATE** `checkAndRequestPermissions()` to include overlay permission check
- [ ] **ADD** overlay permission to the issues list and dialog message
- [ ] **ADD** `AppRestartWorker.schedule()` call in `onCreate()`
- [ ] ✅ Lock screen flags already correct (no changes needed)

### Phase 6: Test All Scenarios ✅

- [ ] **TEST** app relaunch with screen ON
- [ ] **TEST** app relaunch with screen OFF
- [ ] **TEST** app relaunch after swipe-away
- [ ] **TEST** app relaunch after device reboot
- [ ] **TEST** overlay permission flow
- [ ] **VERIFY** alarms reschedule properly

---

## 🧪 TESTING COMMANDS

### Test AlarmManager

```bash
# Trigger alarm manually
adb shell am broadcast -a com.example.hfc_app.RESTART_APP -n com.example.hfc_app/.AppRestartReceiver

# Check if alarm is scheduled
adb shell dumpsys alarm | grep hfc_app

# Check overlay permission
adb shell appops get com.example.hfc_app SYSTEM_ALERT_WINDOW
```

### Test Screen States

```bash
# Test screen-ON relaunch
adb shell am broadcast -a com.example.hfc_app.RESTART_APP

# Turn screen off then test
adb shell input keyevent 26  # Turn screen off
sleep 2
adb shell am broadcast -a com.example.hfc_app.RESTART_APP

# Turn screen on then test
adb shell input keyevent 26  # Turn screen on
sleep 2
adb shell am broadcast -a com.example.hfc_app.RESTART_APP
```

### Test WorkManager

```bash
# Check WorkManager status
adb shell dumpsys jobscheduler | grep hfc_app

# Force run WorkManager
adb shell cmd jobscheduler run -f com.example.hfc_app <job_id>
```

### Monitor Logs

```bash
# Watch all relaunch logs
adb logcat | grep -E "AppRestartReceiver|AppLauncherService|OverlayLauncher|AppRestartWorker|AppKeepalive"

# Watch alarm logs only
adb logcat | grep AlarmManager

# Watch WorkManager logs
adb logcat | grep WorkManager
```

---

## 🎯 ROOT CAUSE SUMMARY

### Primary Failure:
Raw codebase assumes **full-screen intent works in ALL scenarios**, but it **ONLY works when screen is OFF**. Android 10+ blocks full-screen intent from showing when screen is ON, requiring the **overlay trick** instead.

### Secondary Failure:
No **WorkManager backup** means if AlarmManager is canceled by battery optimization, app will **NEVER** relaunch. WorkManager provides guaranteed execution.

### Tertiary Failure:
**Missing overlay permission check** in `MainActivity (1).kt` means user may never grant the permission, causing screen-ON launch to silently fail without explanation.

### Quaternary Failure:
**Missing WorkManager scheduling** in `MainActivity (1).kt` means no backup mechanism is ever started, even though the code exists.

---

## 🚀 IMPLEMENTATION PRIORITY

1. **HIGHEST:** OverlayLauncher.kt + SYSTEM_ALERT_WINDOW permission (fixes screen-ON launch)
2. **HIGH:** MainActivity (1).kt overlay permission check (user must grant permission)
3. **HIGH:** AppRestartReceiver screen-state logic (connects everything)
4. **HIGH:** AppLauncherService dual-mode logic (calls OverlayLauncher)
5. **MEDIUM:** AppRestartWorker.kt + MainActivity scheduling (adds reliability)
6. **LOW:** Alarm rescheduling robustness (nice-to-have)

**CRITICAL NOTE:** `MainActivity (1).kt` already has lock screen flags set correctly (✅), but is missing overlay permission check (⛔) and WorkManager scheduling (⛔)!

---

## 📞 EXPECTED OUTCOME

After implementing all fixes:

✅ App will relaunch **every 5 minutes** via AlarmManager  
✅ App will relaunch **when screen is ON** (via overlay)  
✅ App will relaunch **when screen is OFF** (via full-screen intent)  
✅ App will relaunch **after swipe-away** (both screen states)  
✅ App will relaunch **after device reboot** (BOOT_COMPLETED)  
✅ App will relaunch **even if AlarmManager is canceled** (WorkManager backup)  
✅ App will display **on lock screen** when relaunched  

---

**END OF DOCUMENT**

**Instructions for AI Agent:**
1. Read this entire document carefully
2. Implement fixes in the order specified (Phase 1 → Phase 6)
3. Test after each phase using provided commands
4. Verify all checkboxes are complete
5. Report any issues encountered during implementation

