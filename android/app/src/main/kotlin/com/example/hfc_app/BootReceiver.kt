package com.example.hfc_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            
            Log.d("HFC_BootReceiver", "🔄 Device booted - starting HFC services")
            println("🔄 [BootReceiver] Device booted - starting services")
            
            // Check if device was previously connected
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val wasConnected = prefs.getBoolean("flutter.device_connected", false)
            val deviceId = prefs.getString("flutter.saved_device_id", null)
            
            if (wasConnected && deviceId != null) {
                Log.d("HFC_BootReceiver", "✅ Device was connected ($deviceId) - restarting services")
                
                // Restart foreground service
                val serviceIntent = Intent(context, ForegroundService::class.java)
                serviceIntent.action = ForegroundService.ACTION_START_SERVICE
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                
                println("✅ [BootReceiver] ForegroundService restarted")
                
                // Schedule sync alarms
                SyncAlarmReceiver.scheduleSync(context)
                println("✅ [BootReceiver] Sync alarms scheduled")
                
                // Launch app to restore BLE connection (delayed to allow system to stabilize)
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(launchIntent)
                    
                    Log.d("HFC_BootReceiver", "✅ App launched for BLE reconnection")
                    println("✅ [BootReceiver] App launched for BLE reconnection")
                }, 5000) // Wait 5 seconds for system to stabilize
            } else {
                Log.d("HFC_BootReceiver", "ℹ️ No previous connection - waiting for user to connect")
                println("ℹ️ [BootReceiver] No previous connection - waiting for user to connect")
            }
        }
    }
}

