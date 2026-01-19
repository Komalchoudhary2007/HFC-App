package com.example.hfc_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

class ForegroundService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    
    companion object {
        private const val TAG = "ForegroundService"
        private const val CHANNEL_ID = "hfc_background"
        const val ACTION_START_SERVICE = "ACTION_START_SERVICE"
        const val EXTRA_DEVICE_ADDRESS = "DEVICE_ADDRESS"
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "ForegroundService created")
        createNotificationChannel()
        
        // Start foreground immediately
        val notification = createNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(1, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(1, notification)
        }
        
        // Acquire wake lock to keep CPU running
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "HFCApp::ServiceWakeLock"
        )
        wakeLock?.acquire()
        
        Log.d(TAG, "✅ ForegroundService started with wake lock")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Handle stop action from notification
        if (intent?.action == "STOP_SERVICE") {
            stopSelf()
            return START_NOT_STICKY
        }
        // Service is already in foreground from onCreate
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "🔄 App swiped away - scheduling alarm to restart...")
        // Schedule alarm to relaunch app when screen is OFF
        AppKeepaliveScheduler.scheduleAlarm(applicationContext, 5 * 60 * 1000L)
        super.onTaskRemoved(rootIntent)
    }
    
    override fun onDestroy() {
        Log.d(TAG, "ForegroundService destroyed")
        wakeLock?.release()
        super.onDestroy()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "HFC Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps webhook transmission active"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("HFC Health Monitoring")
            .setContentText("Monitoring your health in background")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(false)  // Allow user to swipe away the notification
            .setPriority(NotificationCompat.PRIORITY_MIN)  // Minimize visual impact
            .setShowWhen(false)  // Hide timestamp
            .build()
    }
}
