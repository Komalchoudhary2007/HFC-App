package com.example.hfc_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log

/**
 * BroadcastReceiver that handles app restart requests from AlarmManager
 * This is triggered when AlarmManager fires to restart the app
 * 
 * SMART SCREEN-AWARE BEHAVIOR:
 * - Screen OFF: Use AppLauncherService with full-screen intent (opens app UI)
 * - Screen ON: Just ensure ForegroundService is running (no annoying notification)
 */
class AppRestartReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "AppRestartReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "🔔 AlarmManager triggered service restart")
        Log.d(TAG, "   Action: ${intent.action}")
        Log.d(TAG, "   Scheduled by: ${intent.getStringExtra("scheduled_by")}")
        
        // Check screen state
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val isScreenOn = powerManager.isInteractive
        Log.d(TAG, "   📱 Screen state: ${if (isScreenOn) "ON" else "OFF"}")
        
        // Helper function to start ForegroundService with saved device info (for screen-ON)
        fun startForegroundServiceWithDevice() {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val deviceId = prefs.getString("flutter.last_connected_device_id", null)
            val userPhone = prefs.getString("flutter.user_phone", null)
            
            if (deviceId != null) {
                val serviceIntent = Intent(context, ForegroundService::class.java).apply {
                    action = ForegroundService.ACTION_START_SERVICE
                    putExtra(ForegroundService.EXTRA_DEVICE_ADDRESS, deviceId)
                    putExtra(ForegroundService.EXTRA_USER_PHONE, userPhone)
                }
                
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                
                Log.d(TAG, "   ✅ ForegroundService started with device: $deviceId")
            } else {
                Log.d(TAG, "   ⚠️ No saved device ID - cannot start ForegroundService")
            }
        }
        
        // Helper function to launch app via AppLauncherService (for screen-OFF)
        fun launchAppViaFullScreenIntent() {
            Log.d(TAG, "   🌙 Screen is OFF - using AppLauncherService for full-screen intent")
            AppLauncherService.start(context)
        }
        
        when (intent.action) {
            "com.example.hfc_app.RESTART_APP" -> {
                if (isScreenOn) {
                    // Screen is ON - just ensure ForegroundService is running
                    // No "HFC App Restarting" notification, no UI launch attempt
                    Log.d(TAG, "🔆 Screen is ON - ensuring ForegroundService only (no UI launch)...")
                    startForegroundServiceWithDevice()
                } else {
                    // Screen is OFF - use full-screen intent to open app UI
                    Log.d(TAG, "🌙 Screen is OFF - launching app via full-screen intent...")
                    launchAppViaFullScreenIntent()
                }
                
                // Reschedule the next restart based on which service scheduled it
                val scheduledBy = intent.getStringExtra("scheduled_by") ?: "keepalive_service"
                Log.d(TAG, "📊 Reschedule request from: $scheduledBy")
                
                when (scheduledBy) {
                    "keepalive_service" -> {
                        Log.d(TAG, "🔄 Rescheduling next keepalive restart (5 min)...")
                        AppLauncher.scheduleKeepaliveRestart(context, 300, "keepalive_service")
                    }
                    "workmanager" -> {
                        Log.d(TAG, "🔄 Rescheduling next workmanager restart (8 min)...")
                        AppLauncher.scheduleKeepaliveRestart(context, 480, "workmanager")
                    }
                    else -> {
                        Log.d(TAG, "🔄 Rescheduling with default (5 min) for unknown source: $scheduledBy")
                        AppLauncher.scheduleKeepaliveRestart(context, 300, "keepalive_service")
                    }
                }
                
                Log.d(TAG, "✅ Reschedule complete for: $scheduledBy")
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                Log.d(TAG, "📱 Device rebooted - starting ForegroundService...")
                
                // Start ForegroundService instead of trying to launch UI
                startForegroundServiceWithDevice()
                
                // Schedule both restart mechanisms after boot
                Log.d(TAG, "🔄 Scheduling restart mechanisms after boot...")
                AppLauncher.scheduleKeepaliveRestart(context, 300, "keepalive_service") // 5 minutes
                
                // Also schedule native WorkManager
                AppRestartWorker.schedule(context)
                
                Log.d(TAG, "✅ Restart mechanisms scheduled after boot")
            }
            else -> {
                Log.w(TAG, "⚠️ Unknown action: ${intent.action}")
            }
        }
    }
}
