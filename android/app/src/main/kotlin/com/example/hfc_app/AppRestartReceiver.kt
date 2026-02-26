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
        val scheduledBy = intent.getStringExtra("scheduled_by") ?: "unknown"
        
        Log.d(TAG, "")
        Log.d(TAG, "⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰")
        Log.d(TAG, "⏰ ALARM FIRED - Source: $scheduledBy")
        Log.d(TAG, "⏰ Time: ${java.text.SimpleDateFormat("HH:mm:ss").format(java.util.Date())}")
        Log.d(TAG, "⏰ Action: ${intent.action}")
        Log.d(TAG, "⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰⏰")
        
        // Check screen state
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val isScreenOn = powerManager.isInteractive
        Log.d(TAG, "   📱 Screen state: ${if (isScreenOn) "ON" else "OFF"}")
        
        // ✅ Check if app is already active (via last_active_timestamp)
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val lastActiveTime = prefs.getLong("flutter.last_active_timestamp", 0)
        val timeSinceActive = System.currentTimeMillis() - lastActiveTime
        val minutesSinceActive = timeSinceActive / 1000 / 60
        val isAppActive = minutesSinceActive < 10  // App is active if last active within 10 minutes (matches WorkManager threshold)
        Log.d(TAG, "   📊 Last active: ${minutesSinceActive}m ago, isAppActive: $isAppActive")
        
        // Helper function to start ForegroundService with saved device info (for screen-ON or app-active)
        fun startForegroundServiceWithDevice() {
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
            AppLauncherService.start(context, "alarm_$scheduledBy")
        }
        
        when (intent.action) {
            "com.example.hfc_app.RESTART_APP" -> {
                // ✅ NEW: Check if app is already active FIRST (prevents unnecessary notification)
                if (isAppActive) {
                    // App is running in background - just ensure ForegroundService, NO notification
                    Log.d(TAG, "✅ App is ACTIVE (${minutesSinceActive}m ago) - no relaunch needed")
                    Log.d(TAG, "   Just ensuring ForegroundService is running...")
                    startForegroundServiceWithDevice()
                } else if (isScreenOn) {
                    // App NOT active, screen is ON - just ensure ForegroundService
                    Log.d(TAG, "🔆 Screen is ON, app not active - ensuring ForegroundService only...")
                    startForegroundServiceWithDevice()
                } else {
                    // App NOT active, screen is OFF - use full-screen intent to open app UI
                    Log.d(TAG, "🌙 Screen is OFF, app not active - launching via full-screen intent...")
                    launchAppViaFullScreenIntent()
                }
                
                // Reschedule the next restart based on which service scheduled it
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
                    "after_realtime_sync" -> {
                        // Read dynamic interval from SharedPreferences (set by Flutter)
                        val realtimeInterval = prefs.getLong("flutter.realtime_interval_minutes", 15L).toInt() // default 5 min
                        val delaySec = (realtimeInterval + 1) * 60
                        Log.d(TAG, "� ========== AFTER_REALTIME_SYNC RESCHEDULE ==========")
                        Log.d(TAG, "📊 Read realtimeInterval from SharedPrefs: $realtimeInterval min")
                        Log.d(TAG, "📊 Calculated delay: ($realtimeInterval + 1) * 60 = $delaySec sec")
                        Log.d(TAG, "📊 Next alarm in: ${realtimeInterval + 1} min")
                        Log.d(TAG, "�🔄 Rescheduling after realtime sync (${realtimeInterval + 1} min = $delaySec sec)...")
                        AppLauncher.scheduleKeepaliveRestart(context, delaySec, "after_realtime_sync")
                        Log.d(TAG, "📊 =====================================================")
                    }
                    "after_reconnect_fail" -> {
                        // Read dynamic interval from SharedPreferences (set by Flutter)
                        val reconnectInterval = prefs.getLong("flutter.reconnect_interval_minutes", 5L).toInt() // default 3 min
                        val delaySec = (reconnectInterval + 1) * 60
                        Log.d(TAG, "📊 ========== AFTER_RECONNECT_FAIL RESCHEDULE ==========")
                        Log.d(TAG, "📊 Read reconnectInterval from SharedPrefs: $reconnectInterval min")
                        Log.d(TAG, "📊 Calculated delay: ($reconnectInterval + 1) * 60 = $delaySec sec")
                        Log.d(TAG, "📊 Next alarm in: ${reconnectInterval + 1} min")
                        Log.d(TAG, "🔄 Rescheduling after reconnect fail (${reconnectInterval + 1} min = $delaySec sec)...")
                        AppLauncher.scheduleKeepaliveRestart(context, delaySec, "after_reconnect_fail")
                        Log.d(TAG, "📊 ======================================================")
                    }
                    else -> {
                        Log.d(TAG, "⚠️ ========== UNKNOWN SOURCE RESCHEDULE ==========")
                        Log.d(TAG, "⚠️ Unknown scheduledBy: $scheduledBy")
                        Log.d(TAG, "🔄 Rescheduling with default (5 min) for unknown source: $scheduledBy")
                        AppLauncher.scheduleKeepaliveRestart(context, 600, "keepalive_service")
                        Log.d(TAG, "⚠️ ================================================")
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
                // AppRestartWorker.schedule(context)
                
                Log.d(TAG, "✅ Restart mechanisms scheduled after boot")
            }
            else -> {
                Log.w(TAG, "⚠️ Unknown action: ${intent.action}")
            }
        }
    }
}
