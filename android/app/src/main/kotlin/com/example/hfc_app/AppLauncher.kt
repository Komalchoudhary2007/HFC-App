package com.example.hfc_app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Enhanced utility class to launch the Flutter app from background services
 * Uses Full-Screen Intent to bypass Android 10+ background activity restrictions
 * Provides multiple methods: Intent, AlarmManager, MethodChannel
 * Ensures app stays alive for HC20 device connection
 */
object AppLauncher {
    private const val TAG = "AppLauncher"
    private const val CHANNEL = "com.example.hfc_app/app_launcher"
    private const val RESTART_REQUEST_CODE = 12345
    private const val NOTIFICATION_CHANNEL_ID = "hfc_app_restart"
    private const val NOTIFICATION_ID = 9999
    private const val KEEPALIVE_REQUEST_CODE = 12346
    private const val WORKMANAGER_REQUEST_CODE = 12347
    
    /**
     * Setup MethodChannel to handle calls from Flutter/Background services
     * Requires the application context to be passed
     */
    fun setupChannel(flutterEngine: FlutterEngine, context: Context) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchApp" -> {
                    Log.d(TAG, "🚀 Received launchApp request via MethodChannel")
                    launchApp(context)
                    result.success(true)
                }
                "scheduleAppRestart" -> {
                    val delaySeconds = call.argument<Int>("delaySeconds") ?: 5
                    Log.d(TAG, "⏰ Scheduling app restart in $delaySeconds seconds")
                    scheduleAppRestart(context, delaySeconds)
                    result.success(true)
                }
                "scheduleKeepaliveRestart" -> {
                    val delaySeconds = call.argument<Int>("delaySeconds") ?: 2
                    val scheduledBy = call.argument<String>("scheduledBy") ?: "keepalive_service"
                    Log.d(TAG, "⏰ Scheduling keepalive restart in $delaySeconds seconds (by: $scheduledBy)")
                    scheduleKeepaliveRestart(context, delaySeconds, scheduledBy)
                    result.success(true)
                }
                "cancelScheduledRestart" -> {
                    Log.d(TAG, "❌ Cancelling scheduled restart")
                    cancelScheduledRestart(context)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        Log.d(TAG, "✅ AppLauncher MethodChannel setup complete")
    }
    
    /**
     * Create notification channel for app restart notifications
     */
    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "App Restart",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Used to restart app for HC20 connection"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    /**
     * Launch or bring the Flutter app to foreground
     * Uses multiple strategies to bypass Android 10+ background restrictions:
     * 1. Full-screen intent (like phone calls) - highest priority
     * 2. Wake lock to turn on screen
     * 3. Direct activity launch as fallback
     */
    fun launchApp(context: Context) {
        Log.d(TAG, "🚀🚀🚀 LAUNCHING APP FROM BACKGROUND 🚀🚀🚀")
        Log.d(TAG, "   Android Version: ${Build.VERSION.SDK_INT}")
        
        try {
            // Step 1: Acquire wake lock to turn on screen
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or 
                PowerManager.ACQUIRE_CAUSES_WAKEUP or 
                PowerManager.ON_AFTER_RELEASE,
                "hfc_app:restart_wakelock"
            )
            wakeLock.acquire(10000) // 10 seconds
            Log.d(TAG, "   ✅ Wake lock acquired - screen should turn on")
            
            // Step 2: Create notification channel
            createNotificationChannel(context)
            
            // Step 3: Create intent for MainActivity
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                       Intent.FLAG_ACTIVITY_CLEAR_TOP or
                       Intent.FLAG_ACTIVITY_SINGLE_TOP or
                       Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                putExtra("launched_from_background", true)
                putExtra("launch_reason", "alarm_manager_restart")
                putExtra("launch_time", System.currentTimeMillis())
            }
            
            // Step 4: Create pending intent for full-screen intent
            val fullScreenPendingIntent = PendingIntent.getActivity(
                context,
                RESTART_REQUEST_CODE + 100,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Step 5: Build notification with full-screen intent
            // This is the KEY - full-screen intents can launch activities from background!
            val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("🔄 HFC App Restarting")
                .setContentText("Reconnecting to HC20 device...")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL) // Treat like a call for high priority
                .setFullScreenIntent(fullScreenPendingIntent, true) // THIS IS THE KEY!
                .setContentIntent(fullScreenPendingIntent)
                .setAutoCancel(true)
                .setOngoing(false)
                .build()
            
            // Step 6: Show the notification - this triggers full-screen intent
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, notification)
            Log.d(TAG, "   ✅ Full-screen notification posted")
            
            // Step 7: Also try direct launch (works on older Android or with special permissions)
            try {
                context.startActivity(launchIntent)
                Log.d(TAG, "   ✅ Direct startActivity called")
            } catch (e: Exception) {
                Log.d(TAG, "   ⚠️ Direct startActivity failed (expected on Android 10+): ${e.message}")
            }
            
            // Step 8: Release wake lock after a delay
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                try {
                    if (wakeLock.isHeld) {
                        wakeLock.release()
                        Log.d(TAG, "   ✅ Wake lock released")
                    }
                    // Also dismiss notification after app should be open
                    notificationManager.cancel(NOTIFICATION_ID)
                } catch (e: Exception) {
                    Log.e(TAG, "   ⚠️ Error releasing wake lock: ${e.message}")
                }
            }, 5000) // 5 seconds
            
            Log.d(TAG, "✅✅✅ APP LAUNCH SEQUENCE COMPLETE ✅✅✅")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌❌❌ FAILED TO LAUNCH APP: ${e.message}", e)
        }
    }
    
    /**
     * Schedule app restart using AlarmManager (most reliable method)
     * Works even if app is killed or device is rebooted
     */
    fun scheduleAppRestart(context: Context, delaySeconds: Int) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            val intent = Intent(context, AppRestartReceiver::class.java).apply {
                action = "com.example.hfc_app.RESTART_APP"
                putExtra("scheduled_by", "app_launcher")
                putExtra("scheduled_at", System.currentTimeMillis())
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                RESTART_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Calculate trigger time
            val triggerAtMillis = SystemClock.elapsedRealtime() + (delaySeconds * 1000L)
            
            // Use setExactAndAllowWhileIdle for most reliable delivery
            // This works even in Doze mode
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
            
            Log.d(TAG, "✅ App restart scheduled in $delaySeconds seconds")
            Log.d(TAG, "   Will trigger even in Doze mode")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to schedule app restart: ${e.message}")
        }
    }
    
    /**
     * Cancel any scheduled app restart
     */
    fun cancelScheduledRestart(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AppRestartReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                RESTART_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
                Log.d(TAG, "✅ Scheduled restart cancelled")
            } else {
                Log.d(TAG, "ℹ️ No scheduled restart to cancel")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to cancel restart: ${e.message}")
        }
    }
    
    /**
     * Schedule app restart using broadcast (works from alarm isolate)
     * This creates an alarm that sends a broadcast to AppRestartReceiver
     */
    fun scheduleKeepaliveRestart(context: Context, delaySeconds: Int, scheduledBy: String = "keepalive_service") {
        try {
            Log.d(TAG, "🔔 Scheduling restart via broadcast in $delaySeconds seconds (by: $scheduledBy)")
            
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // Create intent for broadcast receiver
            val intent = Intent(context, AppRestartReceiver::class.java).apply {
                action = "com.example.hfc_app.RESTART_APP"
                putExtra("scheduled_by", scheduledBy)
            }
            
            // Use distinct request codes so keepalive and workmanager alarms do NOT overwrite each other
            val requestCode = when (scheduledBy) {
                "workmanager" -> WORKMANAGER_REQUEST_CODE
                else -> KEEPALIVE_REQUEST_CODE
            }

            // Create PendingIntent for broadcast
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Calculate trigger time
            val triggerAtMillis = SystemClock.elapsedRealtime() + (delaySeconds * 1000L)
            
            // Schedule exact alarm that works in Doze mode
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
            
            Log.d(TAG, "✅ Keepalive restart scheduled via broadcast")
            Log.d(TAG, "   Delay: $delaySeconds seconds")
            Log.d(TAG, "   Will work from alarm isolate")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to schedule keepalive restart: ${e.message}")
        }
    }
    
    /**
     * Check if the app's main activity is currently running
     */
    fun isAppRunning(context: Context): Boolean {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val runningTasks = activityManager.getRunningTasks(1)
        
        return if (runningTasks.isNotEmpty()) {
            val topActivity = runningTasks[0].topActivity
            topActivity?.packageName == context.packageName
        } else {
            false
        }
    }
}
