package com.example.hfc_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

class AppLauncherService : Service() {
    companion object {
        private const val TAG = "AppLauncherService"
        private const val CHANNEL_ID = "app_launcher_channel"
        private const val NOTIFICATION_ID = 9998
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "AppLauncherService created")
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "🎯 onStartCommand - launching app NOW")
        
        val deviceId = intent?.getStringExtra("device_id")
        val launchReason = intent?.getStringExtra("launch_reason") ?: "unknown"
        
        Log.d(TAG, "   Reason: $launchReason, Device: $deviceId")
        
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
        
        // Step 2: Create intent to launch MainActivity
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
        
        // Step 3: Create pending intent for full-screen intent
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Step 4: Build notification with full-screen intent (KEY!)
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
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
        
        // Step 5: Start foreground AND show notification
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        Log.d(TAG, "   ✅ Started as foreground service with full-screen intent")
        
        // Step 6: Also show notification via NotificationManager (triggers full-screen intent!)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(9999, notification)
        Log.d(TAG, "   ✅ Full-screen notification posted")
        
        // Step 7: Try direct launch as backup
        try {
            startActivity(fullScreenIntent)
            Log.d(TAG, "   ✅ Direct startActivity called (backup)")
        } catch (e: Exception) {
            Log.d(TAG, "   ⚠️  Direct launch failed (expected on Android 10+): ${e.message}")
        }
        
        // Step 8: Release wake lock after delay
        android.os.Handler(mainLooper).postDelayed({
            try {
                if (wakeLock.isHeld) {
                    wakeLock.release()
                    Log.d(TAG, "   ✅ Wake lock released")
                }
            } catch (e: Exception) {
                Log.e(TAG, "   ⚠️  Error releasing wake lock: ${e.message}")
            }
        }, 3000)
        
        // Step 9: Stop service after launching
        android.os.Handler(mainLooper).postDelayed({ 
            Log.d(TAG, "   🛑 Stopping AppLauncherService")
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }, 5000)
        
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
            Log.d(TAG, "Notification channel created")
        }
    }
}
