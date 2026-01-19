# Native App Launch Implementation Guide
## Complete Flutter → Kotlin Integration for Background App Relaunch

## 🎯 Problem Statement

When your Flutter app is swiped away and screen is OFF, you need to relaunch it automatically. The Flutter Dart code in `app_keepalive_service.dart` calls native Android methods, but those native methods must be properly implemented in Kotlin.

This guide shows the **COMPLETE** implementation of the native Android side.

---

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  FLUTTER DART SIDE (lib/services/app_keepalive_service.dart)│
└─────────────────────────────────────────────────────────────┘
                           │
                           │ MethodChannel
                           │ 'com.example.hfc_app/app_launcher'
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  KOTLIN NATIVE SIDE (MainActivity.kt / AppLauncher.kt)      │
│                                                              │
│  1. Receives 'scheduleKeepaliveRestart' call                │
│  2. Schedules AlarmManager alarm                            │
│  3. Alarm triggers AppRestartReceiver                       │
│  4. AppRestartReceiver launches AppLauncherService          │
│  5. AppLauncherService uses full-screen intent              │
│  6. MainActivity opens on lock screen                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔗 Part 1: MethodChannel Setup (Flutter → Kotlin Bridge)

### Step 1.1: Flutter Side (Already in your app_keepalive_service.dart)

```dart
static const MethodChannel _channel = MethodChannel('com.example.hfc_app/app_launcher');

static Future<void> _scheduleNativeRestartAlarm() async {
  try {
    // This calls native Kotlin code
    await _channel.invokeMethod('scheduleKeepaliveRestart', {
      'delaySeconds': 300,        // 5 minutes
      'scheduledBy': 'keepalive_service',
    });
    print('✅ Native restart alarm scheduled');
  } catch (e) {
    print('⚠️ Failed to schedule: $e');
  }
}
```

### Step 1.2: Kotlin Side - MethodChannel Handler (AppLauncher.kt)

**Location:** Create or edit `android/app/src/main/kotlin/com/example/hfc_app/AppLauncher.kt`

```kotlin
package com.example.hfc_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * AppLauncher - Handles MethodChannel calls from Flutter to schedule alarms
 * and launch the app from background
 */
object AppLauncher {
    private const val TAG = "AppLauncher"
    private const val CHANNEL = "com.example.hfc_app/app_launcher"
    private const val KEEPALIVE_REQUEST_CODE = 12346
    private const val WORKMANAGER_REQUEST_CODE = 12347
    
    /**
     * Setup MethodChannel to receive calls from Flutter
     * Call this from MainActivity.configureFlutterEngine()
     */
    fun setupChannel(flutterEngine: FlutterEngine, context: Context) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleKeepaliveRestart" -> {
                        val delaySeconds = call.argument<Int>("delaySeconds") ?: 300
                        val scheduledBy = call.argument<String>("scheduledBy") ?: "keepalive_service"
                        
                        Log.d(TAG, "📞 Received scheduleKeepaliveRestart from Flutter")
                        Log.d(TAG, "   Delay: $delaySeconds sec")
                        Log.d(TAG, "   Scheduled by: $scheduledBy")
                        
                        scheduleKeepaliveRestart(context, delaySeconds, scheduledBy)
                        result.success(true)
                    }
                    "launchApp" -> {
                        Log.d(TAG, "📞 Received launchApp from Flutter")
                        launchApp(context)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        
        Log.d(TAG, "✅ MethodChannel '$CHANNEL' setup complete")
    }
    
    /**
     * Schedule an alarm that will trigger AppRestartReceiver
     * This is called FROM Flutter via MethodChannel
     */
    fun scheduleKeepaliveRestart(context: Context, delaySeconds: Int, scheduledBy: String) {
        try {
            Log.d(TAG, "🔔 Scheduling restart alarm...")
            
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // ⭐ CRITICAL: Check permission on Android 12+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (!alarmManager.canScheduleExactAlarms()) {
                    Log.e(TAG, "❌ Cannot schedule - SCHEDULE_EXACT_ALARM permission denied!")
                    Log.e(TAG, "   User must enable 'Alarms & reminders' in Settings")
                    return
                }
            }
            
            // Create intent for AppRestartReceiver
            val intent = Intent(context, AppRestartReceiver::class.java).apply {
                action = "com.example.hfc_app.RESTART_APP"
                putExtra("scheduled_by", scheduledBy)
                putExtra("scheduled_at", System.currentTimeMillis())
            }
            
            // Use different request codes so alarms don't overwrite each other
            val requestCode = when (scheduledBy) {
                "workmanager" -> WORKMANAGER_REQUEST_CODE
                else -> KEEPALIVE_REQUEST_CODE
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Calculate trigger time
            val triggerAtMillis = SystemClock.elapsedRealtime() + (delaySeconds * 1000L)
            
            // ⭐ CRITICAL: Use setExactAndAllowWhileIdle (works in Doze mode)
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,  // Wakes device
                triggerAtMillis,
                pendingIntent
            )
            
            Log.d(TAG, "✅ Alarm scheduled successfully")
            Log.d(TAG, "   Will trigger in $delaySeconds seconds")
            Log.d(TAG, "   Request code: $requestCode")
            Log.d(TAG, "   Scheduled by: $scheduledBy")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to schedule alarm: ${e.message}", e)
        }
    }
    
    /**
     * Launch the app immediately (for testing or direct calls)
     */
    fun launchApp(context: Context) {
        Log.d(TAG, "🚀 Launching app NOW...")
        
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                       Intent.FLAG_ACTIVITY_CLEAR_TOP or
                       Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("launched_from_background", true)
                putExtra("launch_reason", "direct_call")
            }
            
            context.startActivity(intent)
            Log.d(TAG, "✅ App launch initiated")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to launch: ${e.message}")
        }
    }
}
```

---

## 🔔 Part 2: BroadcastReceiver (Receives Alarm Triggers)

### Step 2.1: Create AppRestartReceiver.kt

**Location:** `android/app/src/main/kotlin/com/example/hfc_app/AppRestartReceiver.kt`

```kotlin
package com.example.hfc_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log

/**
 * AppRestartReceiver - Receives alarms from AlarmManager
 * Triggered every 5 minutes to check if app needs restart
 */
class AppRestartReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "AppRestartReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.d(TAG, "🔔 ALARM TRIGGERED!")
        Log.d(TAG, "   Time: ${java.util.Date()}")
        Log.d(TAG, "   Action: ${intent.action}")
        
        when (intent.action) {
            "com.example.hfc_app.RESTART_APP" -> {
                handleRestartAlarm(context, intent)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                handleBootCompleted(context)
            }
            else -> {
                Log.w(TAG, "⚠️ Unknown action: ${intent.action}")
            }
        }
        
        Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    /**
     * Handle restart alarm
     */
    private fun handleRestartAlarm(context: Context, intent: Intent) {
        val scheduledBy = intent.getStringExtra("scheduled_by") ?: "unknown"
        Log.d(TAG, "📊 Scheduled by: $scheduledBy")
        
        // Check screen state
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val isScreenOn = powerManager.isInteractive
        Log.d(TAG, "📱 Screen state: ${if (isScreenOn) "ON ☀️" else "OFF 🌙"}")
        
        if (isScreenOn) {
            // Screen is ON - just ensure service is running
            Log.d(TAG, "🔆 Screen is ON - ensuring ForegroundService only")
            startForegroundServiceWithDevice(context)
        } else {
            // Screen is OFF - launch app via full-screen intent
            Log.d(TAG, "🌙 Screen is OFF - launching app via AppLauncherService")
            AppLauncherService.start(context)
        }
        
        // ⭐⭐⭐ CRITICAL: Reschedule the next alarm
        Log.d(TAG, "🔄 Rescheduling next alarm...")
        
        val delaySeconds = when (scheduledBy) {
            "keepalive_service" -> 300   // 5 minutes
            "workmanager" -> 480          // 8 minutes
            else -> 300                   // Default 5 minutes
        }
        
        AppLauncher.scheduleKeepaliveRestart(context, delaySeconds, scheduledBy)
        Log.d(TAG, "✅ Next alarm scheduled for $delaySeconds seconds")
    }
    
    /**
     * Handle device boot
     */
    private fun handleBootCompleted(context: Context) {
        Log.d(TAG, "📱 Device rebooted - starting services...")
        
        // Start ForegroundService
        startForegroundServiceWithDevice(context)
        
        // Reschedule alarms
        AppLauncher.scheduleKeepaliveRestart(context, 300, "keepalive_service")
        
        Log.d(TAG, "✅ Services restarted after boot")
    }
    
    /**
     * Start ForegroundService with saved device info
     */
    private fun startForegroundServiceWithDevice(context: Context) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val deviceId = prefs.getString("flutter.last_connected_device_id", null)
        val userPhone = prefs.getString("flutter.user_phone", null)
        
        if (deviceId != null) {
            val serviceIntent = Intent(context, ForegroundService::class.java).apply {
                action = "START_SERVICE"
                putExtra("device_address", deviceId)
                putExtra("user_phone", userPhone)
            }
            
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            Log.d(TAG, "✅ ForegroundService started with device: $deviceId")
        } else {
            Log.d(TAG, "⚠️ No saved device ID - cannot start ForegroundService")
        }
    }
}
```

---

## 🚀 Part 3: AppLauncherService (Launches App with Full-Screen Intent)

### Step 3.1: Create AppLauncherService.kt

**Location:** `android/app/src/main/kotlin/com/example/hfc_app/AppLauncherService.kt`

```kotlin
package com.example.hfc_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * AppLauncherService - Foreground service that launches MainActivity
 * Uses full-screen intent to bypass Android 10+ restrictions
 */
class AppLauncherService : Service() {
    
    companion object {
        private const val TAG = "AppLauncherService"
        private const val NOTIFICATION_ID = 9998
        private const val CHANNEL_ID = "app_launcher_service"
        
        /**
         * Start this service to launch the app
         */
        fun start(context: Context) {
            Log.d(TAG, "🚀 Starting AppLauncherService...")
            val intent = Intent(context, AppLauncherService::class.java)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "📦 Service created")
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.d(TAG, "🎯 LAUNCHING APP NOW!")
        Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Start as foreground service immediately
        val notification = createNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        Log.d(TAG, "✅ Started as foreground service")
        
        // Acquire wake lock to turn on screen
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or
            PowerManager.ACQUIRE_CAUSES_WAKEUP or
            PowerManager.ON_AFTER_RELEASE,
            "hfc_app:launcher_wakelock"
        )
        wakeLock.acquire(10000) // 10 seconds
        Log.d(TAG, "✅ Wake lock acquired - screen will turn on")
        
        // Launch app using full-screen intent
        launchViaFullScreenIntent()
        
        // Also try direct launch as backup
        try {
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("launched_from_background", true)
                putExtra("launch_reason", "app_launcher_service")
                putExtra("launch_time", System.currentTimeMillis())
            }
            
            startActivity(launchIntent)
            Log.d(TAG, "✅ Direct startActivity called (backup)")
            
        } catch (e: Exception) {
            Log.d(TAG, "⚠️ Direct launch failed: ${e.message}")
        }
        
        // Clean up after 5 seconds
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                if (wakeLock.isHeld) {
                    wakeLock.release()
                    Log.d(TAG, "✅ Wake lock released")
                }
                
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                Log.d(TAG, "🛑 Service stopped")
                
            } catch (e: Exception) {
                Log.e(TAG, "⚠️ Error cleaning up: ${e.message}")
            }
        }, 5000)
        
        return START_NOT_STICKY
    }
    
    /**
     * Launch app using full-screen intent (works when screen is OFF)
     */
    private fun launchViaFullScreenIntent() {
        Log.d(TAG, "📱 Creating full-screen intent...")
        
        try {
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("launched_from_background", true)
                putExtra("launch_reason", "full_screen_intent")
            }
            
            val pendingIntent = PendingIntent.getActivity(
                this,
                System.currentTimeMillis().toInt(),
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // ⭐⭐⭐ THE KEY: Full-screen intent notification
            val fullScreenNotification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("🔄 HFC App Restarting")
                .setContentText("Reconnecting to HC20 device...")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)  // ⭐ Treat like phone call
                .setFullScreenIntent(pendingIntent, true)        // ⭐⭐⭐ THIS IS THE KEY!
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .build()
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.notify(9999, fullScreenNotification)
            
            Log.d(TAG, "✅ Full-screen intent notification posted!")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Full-screen intent failed: ${e.message}")
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Launcher",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Used to launch app from background"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("HFC App")
            .setContentText("Reconnecting...")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
    }
}
```

---

## 📱 Part 4: MainActivity Integration

### Step 4.1: Setup MethodChannel in MainActivity.kt

**Add this to your MainActivity.kt:**

```kotlin
package com.example.hfc_app

import android.os.Bundle
import android.view.WindowManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // ⭐ CRITICAL: Lock screen configuration
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
        
        // Keep screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Check if launched from background
        val launchedFromBackground = intent?.getBooleanExtra("launched_from_background", false) ?: false
        if (launchedFromBackground) {
            println("🚀🚀🚀 APP LAUNCHED FROM BACKGROUND! 🚀🚀🚀")
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // ⭐⭐⭐ CRITICAL: Setup MethodChannel for AppLauncher
        AppLauncher.setupChannel(flutterEngine, applicationContext)
        println("✅ AppLauncher MethodChannel configured")
    }
}
```

---

## 📜 Part 5: AndroidManifest.xml Configuration

### Step 5.1: Add ALL Required Permissions

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- ⭐ CRITICAL PERMISSIONS -->
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.USE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.INTERNET" />
    
    <application ...>
        
        <!-- ⭐ MainActivity with lock screen attributes -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:showOnLockScreen="true"
            android:showWhenLocked="true"
            android:turnScreenOn="true"
            ...>
        </activity>
        
        <!-- ⭐ AppLauncherService -->
        <service
            android:name=".AppLauncherService"
            android:enabled="true"
            android:exported="false"
            android:foregroundServiceType="dataSync" />
        
        <!-- ⭐ AppRestartReceiver -->
        <receiver
            android:name=".AppRestartReceiver"
            android:enabled="true"
            android:exported="false">
            <intent-filter>
                <action android:name="com.example.hfc_app.RESTART_APP" />
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>
        
        <!-- Your ForegroundService -->
        <service
            android:name=".ForegroundService"
            android:enabled="true"
            android:exported="false"
            android:foregroundServiceType="dataSync"
            android:stopWithTask="false" />
        
    </application>
</manifest>
```

---

## 🧪 Part 6: Testing & Verification

### Test 1: Verify MethodChannel Communication

Add this to your Flutter code:

```dart
// Test if native scheduling works
try {
  await _channel.invokeMethod('scheduleKeepaliveRestart', {
    'delaySeconds': 60,  // 1 minute for testing
    'scheduledBy': 'test',
  });
  print('✅ Native alarm scheduled successfully!');
} catch (e) {
  print('❌ Failed to schedule: $e');
}
```

Check logcat:
```bash
adb logcat | grep "AppLauncher"
```

You should see:
```
📞 Received scheduleKeepaliveRestart from Flutter
✅ Alarm scheduled successfully
```

### Test 2: Verify Alarm is Scheduled

```bash
adb shell dumpsys alarm | grep "hfc_app"
```

Should show scheduled alarm with trigger time.

### Test 3: Test App Launch After Swipe Away

1. Open app
2. Lock phone (screen OFF)
3. Swipe app away from recent apps
4. Wait 5-6 minutes
5. **Expected:** App launches on lock screen

### Test 4: Check Logs

```bash
adb logcat -c  # Clear logs
adb logcat | grep -E "AppLauncher|AppRestartReceiver|AppLauncherService"
```

You should see:
```
🔔 ALARM TRIGGERED!
🌙 Screen is OFF - launching app
🚀 Starting AppLauncherService...
✅ Full-screen intent notification posted!
✅ Next alarm scheduled
```

---

## 🐛 Common Issues & Solutions

### Issue 1: "Permission denied" for SCHEDULE_EXACT_ALARM

**Solution:** Add runtime permission check in MainActivity:

```kotlin
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
    val alarmManager = getSystemService(AlarmManager::class.java)
    if (!alarmManager.canScheduleExactAlarms()) {
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
        intent.data = Uri.parse("package:$packageName")
        startActivity(intent)
    }
}
```

### Issue 2: App doesn't launch on lock screen

**Solution:** Verify MainActivity attributes in AndroidManifest:
- `showOnLockScreen="true"`
- `showWhenLocked="true"`
- `turnScreenOn="true"`

Also add window flags in onCreate().

### Issue 3: Alarm only fires once

**Solution:** Make sure AppRestartReceiver calls `AppLauncher.scheduleKeepaliveRestart()` to reschedule!

### Issue 4: MethodChannel not found

**Solution:** Ensure `AppLauncher.setupChannel()` is called in `MainActivity.configureFlutterEngine()`.

---

## 📋 Implementation Checklist

Use this to verify everything is implemented:

### Flutter Side:
- [ ] `app_keepalive_service.dart` exists with MethodChannel calls
- [ ] Channel name is `'com.example.hfc_app/app_launcher'`
- [ ] Calls `scheduleKeepaliveRestart` with correct parameters

### Kotlin Side:
- [ ] `AppLauncher.kt` created with `setupChannel()` method
- [ ] `AppRestartReceiver.kt` created with `onReceive()` method
- [ ] `AppLauncherService.kt` created with full-screen intent logic
- [ ] `MainActivity.kt` calls `AppLauncher.setupChannel()` in `configureFlutterEngine()`
- [ ] MainActivity has lock screen window flags in `onCreate()`

### AndroidManifest.xml:
- [ ] All permissions added (SCHEDULE_EXACT_ALARM, USE_FULL_SCREEN_INTENT, etc.)
- [ ] MainActivity has `showOnLockScreen="true"`, `showWhenLocked="true"`, `turnScreenOn="true"`
- [ ] AppLauncherService declared with `foregroundServiceType="dataSync"`
- [ ] AppRestartReceiver declared with intent-filter for `RESTART_APP` action

### Runtime Permissions:
- [ ] SCHEDULE_EXACT_ALARM checked and requested (Android 12+)
- [ ] USE_FULL_SCREEN_INTENT checked and requested (Android 14+)
- [ ] Battery optimization disabled
- [ ] Overlay permission granted (for screen-ON restart)

---

## 🎯 Complete File Structure

After implementation, you should have:

```
android/app/src/main/kotlin/com/example/hfc_app/
├── MainActivity.kt              (Modified - added MethodChannel setup)
├── AppLauncher.kt              (New - MethodChannel handler)
├── AppRestartReceiver.kt       (New - Receives alarms)
├── AppLauncherService.kt       (New - Launches app)
└── ForegroundService.kt        (Existing - Your HC20 service)

android/app/src/main/AndroidManifest.xml  (Modified - added permissions & components)

lib/services/
└── app_keepalive_service.dart  (Existing - Your Flutter code)
```

---

## 🔄 Complete Flow Diagram

```
1. App Starts
   ↓
2. Flutter calls AppKeepaliveService.startPeriodicKeepalive()
   ↓
3. Dart calls _scheduleNativeRestartAlarm()
   ↓
4. MethodChannel sends 'scheduleKeepaliveRestart' to Kotlin
   ↓
5. AppLauncher.kt receives call
   ↓
6. AppLauncher schedules AlarmManager alarm
   ↓
[5 minutes pass]
   ↓
7. AlarmManager triggers AppRestartReceiver
   ↓
8. AppRestartReceiver checks screen state
   ↓
9. If screen OFF → calls AppLauncherService.start()
   ↓
10. AppLauncherService creates full-screen intent notification
   ↓
11. Android shows notification on lock screen
   ↓
12. MainActivity opens!
   ↓
13. AppRestartReceiver reschedules next alarm
   ↓
[Loop continues forever]
```

---

## 📱 Device-Specific Notes

### Xiaomi/MIUI:
After implementation, user must:
1. Enable "Autostart" permission
2. Disable battery optimization
3. Enable "Display popup windows while running in background"

### Samsung:
After implementation, user must:
1. Add app to "Never sleeping apps"
2. Disable "Put app to sleep"

### Huawei:
After implementation, user must:
1. Enable "Manual launch"
2. Allow "Autolaunch"

---

**Implementation Time:** ~30-60 minutes  
**Difficulty:** Medium  
**Required Knowledge:** Kotlin, Android Services, AlarmManager, MethodChannel  
**Last Updated:** January 19, 2026
