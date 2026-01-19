package com.example.hfc_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground Service that can launch MainActivity from background
 * 
 * ENHANCED for Screen-ON launching:
 * - When screen is OFF: Uses full-screen intent (works great)
 * - When screen is ON: Uses SYSTEM_ALERT_WINDOW overlay trick
 * 
 * WHY OVERLAY WORKS ON SCREEN-ON:
 * - Android 10+ blocks startActivity() from background
 * - BUT activities started from overlay windows ARE allowed
 * - This is how Facebook Messenger chat heads work!
 * 
 * FLOW:
 * 1. WorkManager/AlarmManager triggers → starts this service
 * 2. This service runs as foreground (shows notification)
 * 3. Check if screen is ON or OFF
 * 4. If OFF: Use full-screen intent (existing approach)
 * 5. If ON: Use overlay trick (new approach)
 * 6. MainActivity opens and this service stops itself
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
        Log.d(TAG, "🎯 onStartCommand - launching app NOW")
        
        // Step 1: Start as foreground service immediately (required on Android 8+)
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        Log.d(TAG, "   ✅ Started as foreground service")
        
        // Step 2: Check screen state
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val isScreenOn = powerManager.isInteractive
        Log.d(TAG, "   📱 Screen state: ${if (isScreenOn) "ON" else "OFF"}")
        
        // Step 3: Acquire wake lock to turn on screen
        val wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or
            PowerManager.ACQUIRE_CAUSES_WAKEUP or
            PowerManager.ON_AFTER_RELEASE,
            "hfc_app:launcher_wakelock"
        )
        wakeLock.acquire(10000) // 10 seconds
        Log.d(TAG, "   ✅ Wake lock acquired - screen should turn on")
        
        // Step 4: Choose launch method based on screen state
        if (isScreenOn) {
            // SCREEN IS ON - Use overlay trick!
            Log.d(TAG, "   🔆 Screen is ON - using OVERLAY method")
            launchViaOverlay()
        } else {
            // SCREEN IS OFF - Use full-screen intent
            Log.d(TAG, "   🌙 Screen is OFF - using FULL-SCREEN INTENT method")
            launchViaFullScreenIntent()
        }
        
        // Also try direct launch as backup
        try {
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra("launched_from_background", true)
                putExtra("launch_reason", "foreground_service_direct")
                putExtra("launch_time", System.currentTimeMillis())
            }
            
            startActivity(launchIntent)
            Log.d(TAG, "   ✅ Direct startActivity called (backup)")
            
        } catch (e: Exception) {
            Log.d(TAG, "   ⚠️ Direct launch failed (expected on Android 10+): ${e.message}")
        }
        
        // Step 5: Release wake lock after delay
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            try {
                if (wakeLock.isHeld) {
                    wakeLock.release()
                    Log.d(TAG, "   ✅ Wake lock released")
                }
            } catch (e: Exception) {
                Log.e(TAG, "   ⚠️ Error releasing wake lock: ${e.message}")
            }
        }, 3000)
        
        // Step 6: Stop this service after launching (don't need it anymore)
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            Log.d(TAG, "   🛑 Stopping AppLauncherService")
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }, 5000)
        
        return START_NOT_STICKY
    }
    
    /**
     * Launch via overlay when screen is ON
     * This uses SYSTEM_ALERT_WINDOW permission to bypass Android 10+ restrictions
     */
    private fun launchViaOverlay() {
        Log.d(TAG, "   🎨 Attempting overlay launch...")
        
        if (OverlayLauncher.hasOverlayPermission(this)) {
            OverlayLauncher.launchAppViaOverlay(this)
            Log.d(TAG, "   ✅ Overlay launch initiated")
        } else {
            Log.d(TAG, "   ⚠️ No overlay permission - trying full-screen intent as fallback")
            launchViaFullScreenIntent()
        }
    }
    
    /**
     * Launch via full-screen intent when screen is OFF
     * This works great when screen is off (like alarm clocks)
     */
    private fun launchViaFullScreenIntent() {
        Log.d(TAG, "   📱 Using full-screen intent...")
        
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
            
            val fullScreenNotification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("🔄 HFC App Restarting")
                .setContentText("Reconnecting to HC20 device...")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setFullScreenIntent(pendingIntent, true)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .build()
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.notify(9999, fullScreenNotification)
            Log.d(TAG, "   ✅ Full-screen intent notification posted")
            
        } catch (e: Exception) {
            Log.e(TAG, "   ❌ Full-screen intent failed: ${e.message}")
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
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("HFC App")
            .setContentText("Reconnecting to HC20 device...")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()
    }
}
