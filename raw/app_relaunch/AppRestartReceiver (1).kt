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
        Log.d(TAG, "🔔 AlarmManager triggered service restart")
        Log.d(TAG, "   Action: ${intent.action}")
        
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val deviceId = prefs.getString("flutter.last_connected_device_id", null)
        
        // Check screen state
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val isScreenOn = powerManager.isInteractive
        Log.d(TAG, "   📱 Screen state: ${if (isScreenOn) "ON" else "OFF"}")
        
        if (deviceId == null) {
            Log.d(TAG, "   ⚠️  No saved device ID - cannot start service")
            // Still reschedule for later
            AppKeepaliveScheduler.scheduleAlarm(context, 5 * 60 * 1000L)
            return
        }
        
        when (intent.action) {
            "com.example.hfc_app.RESTART_APP" -> {
                if (!isScreenOn) {
                    // Screen is OFF - use full-screen intent to open app UI
                    Log.d(TAG, "🌙 Screen is OFF - launching app via full-screen intent...")
                    launchAppWhenScreenOff(context, deviceId)
                } else {
                    // Screen is ON - just ensure ForegroundService is running
                    Log.d(TAG, "🔆 Screen is ON - ensuring ForegroundService only...")
                    startForegroundService(context, deviceId)
                }
                
                // Reschedule the next restart
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
                Log.w(TAG, "⚠️  Unknown action: ${intent.action}")
            }
        }
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
