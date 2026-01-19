# AlarmManager App UI Relaunch Implementation Guide

## Overview

This document describes how to implement **automatic app relaunch when screen is OFF** using Android's AlarmManager. This is the **only reliable method** that works for keeping HC20 SDK running in the background on Android.

## Why This Approach Works

When an Android app is swiped away from recent apps:
1. The main Flutter engine is **KILLED** by Android
2. ForegroundService can keep the native process alive, but Flutter code stops
3. HeadlessFlutter cannot reliably connect to HC20 because BLE operations fail in headless mode

**The Solution:** When screen is OFF, Android allows apps to be launched via AlarmManager + Full-Screen Intent. This relaunches the **full app UI with the main Flutter engine**, allowing HC20 SDK to reconnect.

---

## Implementation Files

### 1. AndroidManifest.xml Permissions

```xml
<!-- Required for AlarmManager exact alarms (Android 12+) -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />

<!-- Required for screen-off app launch -->
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- Foreground service for keeping process alive -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />

<!-- Boot receiver for auto-restart after phone restart -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

### 2. Register Components in AndroidManifest.xml

```xml
<application ...>
    
    <!-- Foreground Service -->
    <service
        android:name=".ForegroundService"
        android:enabled="true"
        android:exported="false"
        android:foregroundServiceType="dataSync"
        android:stopWithTask="false" />
    
    <!-- App Launcher Service (for full-screen intent) -->
    <service
        android:name=".AppLauncherService"
        android:enabled="true"
        android:exported="false"
        android:foregroundServiceType="dataSync" />
    
    <!-- Alarm Receiver -->
    <receiver
        android:name=".AppRestartReceiver"
        android:enabled="true"
        android:exported="false">
        <intent-filter>
            <action android:name="com.example.hfc_app.RESTART_APP" />
        </intent-filter>
    </receiver>
    
    <!-- Boot Receiver -->
    <receiver
        android:name=".BootReceiver"
        android:enabled="true"
        android:exported="true"
        android:permission="android.permission.RECEIVE_BOOT_COMPLETED">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED" />
        </intent-filter>
    </receiver>
    
</application>
```

---

### 3. AppRestartReceiver.kt

```kotlin
package com.example.hfc_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log

class AppRestartReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AppRestartReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "⏰ Alarm received - checking if app needs restart...")
        
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val deviceId = prefs.getString("flutter.last_connected_device_id", null)
        
        if (deviceId == null) {
            Log.d(TAG, "   No device configured - skipping restart")
            return
        }
        
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val isScreenOn = powerManager.isInteractive
        
        if (!isScreenOn) {
            // Screen is OFF - launch the app UI!
            Log.d(TAG, "🚀 Screen is OFF - launching app via full-screen intent...")
            launchAppWhenScreenOff(context, deviceId)
        } else {
            // Screen is ON - just ensure ForegroundService is running
            startForegroundService(context, deviceId)
        }
        
        // Reschedule the next alarm
        AppKeepaliveScheduler.scheduleAlarm(context, 5 * 60 * 1000L)
    }
    
    private fun launchAppWhenScreenOff(context: Context, deviceId: String) {
        val serviceIntent = Intent(context, AppLauncherService::class.java).apply {
            putExtra("device_id", deviceId)
            putExtra("launch_reason", "alarm_screen_off")
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
    
    private fun startForegroundService(context: Context, deviceId: String) {
        val serviceIntent = Intent(context, ForegroundService::class.java).apply {
            action = ForegroundService.ACTION_START_SERVICE
            putExtra(ForegroundService.EXTRA_DEVICE_ADDRESS, deviceId)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
```

---

### 4. AppLauncherService.kt (KEY FILE - Uses Full-Screen Intent)

```kotlin
package com.example.hfc_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class AppLauncherService : Service() {
    companion object {
        private const val CHANNEL_ID = "app_launcher_channel"
        private const val NOTIFICATION_ID = 9998
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val deviceId = intent?.getStringExtra("device_id")
        val launchReason = intent?.getStringExtra("launch_reason") ?: "unknown"
        
        // Create intent to launch MainActivity
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("launched_from_background", true)
            putExtra("launch_reason", launchReason)
            putExtra("device_id", deviceId)
        }
        
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, 0, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // THE KEY: Full-Screen Intent launches app when screen is OFF
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("HC20 Reconnecting...")
            .setContentText("Reopening app to restore device connection")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPendingIntent, true) // THIS IS THE KEY!
            .setAutoCancel(true)
            .build()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        
        // Stop service after the app is launched
        android.os.Handler(mainLooper).postDelayed({ stopSelf() }, 3000)
        
        return START_NOT_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "App Launcher", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
```

---

### 5. AppKeepaliveScheduler.kt

```kotlin
package com.example.hfc_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object AppKeepaliveScheduler {
    private const val REQUEST_CODE = 12346
    
    fun scheduleAlarm(context: Context, delayMs: Long = 5 * 60 * 1000L) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(context, AppRestartReceiver::class.java).apply {
            action = "com.example.hfc_app.RESTART_APP"
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context, REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val triggerTime = System.currentTimeMillis() + delayMs
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            }
        } else {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
        }
    }
}
```

---

### 6. MainActivity.kt - Handle Background Launch

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    
    // Allow app to show over lock screen
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
        setShowWhenLocked(true)
        setTurnScreenOn(true)
    } else {
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
    }
    
    // Keep screen on while app is open
    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    
    // Schedule keepalive alarm
    AppKeepaliveScheduler.scheduleAlarm(applicationContext, 5 * 60 * 1000L)
}
```

---

## Flow Diagram

```
User swipes away app
        ↓
ForegroundService.onTaskRemoved() called
        ↓
AlarmManager schedules alarm for 5 minutes
        ↓
[5 minutes later - screen is OFF]
        ↓
AppRestartReceiver.onReceive() triggered
        ↓
Screen OFF? → YES → AppLauncherService starts
                    ↓
                   Full-Screen Intent launches MainActivity
                    ↓
                   Flutter engine starts → HC20 SDK reconnects
                    ↓
                   Live data flows again! ✅
```

---

## Important Notes

1. **Only works when screen is OFF** - Android blocks full-screen intents when screen is ON
2. **Requires SCHEDULE_EXACT_ALARM permission** on Android 12+
3. **Xiaomi/MIUI devices** - May require "Autostart" permission in Settings
4. **Battery optimization** - Must be disabled for the app