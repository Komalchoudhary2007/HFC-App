package com.example.hfc_app

import android.content.Context
import android.os.PowerManager
import android.util.Log
import androidx.work.*
import java.util.concurrent.TimeUnit

/**
 * Native Android WorkManager Worker that runs every 15 minutes
 * 
 * WHY NATIVE WORKMANAGER:
 * - Flutter's workmanager plugin runs callbacks in Dart isolate
 * - Dart isolate CANNOT use MethodChannel to launch app
 * - Native WorkManager runs Kotlin code directly
 * - Native code CAN start foreground service → launch activity
 * 
 * SMART SCREEN-AWARE BEHAVIOR:
 * - Screen OFF: Use AppLauncherService with full-screen intent (opens app UI)
 * - Screen ON: Just ensure ForegroundService is running (no annoying notification)
 * 
 * FLOW:
 * 1. WorkManager triggers this Worker every 15 minutes
 * 2. Worker checks if app was recently active
 * 3. If not active for 5+ minutes:
 *    - Screen OFF → AppLauncherService (full-screen intent)
 *    - Screen ON → ForegroundService only (no UI)
 */
class AppRestartWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {
    
    companion object {
        private const val TAG = "AppRestartWorker"
        private const val UNIQUE_WORK_NAME = "hfc_app_restart_worker"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        
        /**
         * Schedule the worker to run every 15 minutes
         * Call this from MainActivity when app starts
         */
        fun schedule(context: Context) {
            Log.d(TAG, "📅 Scheduling AppRestartWorker (every 15 min)...")
            
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.NOT_REQUIRED) // Run even without network
                .setRequiresBatteryNotLow(false) // Run even on low battery
                .setRequiresCharging(false)
                .build()
            
            val workRequest = PeriodicWorkRequestBuilder<AppRestartWorker>(
                15, TimeUnit.MINUTES // Minimum interval on Android
            )
                .setConstraints(constraints)
                .setInitialDelay(1, TimeUnit.MINUTES) // First run after 1 minute
                .addTag("hfc_restart")
                .build()
            
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                UNIQUE_WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP, // Keep existing if already scheduled
                workRequest
            )
            
            Log.d(TAG, "✅ AppRestartWorker scheduled successfully")
            Log.d(TAG, "   Interval: 15 minutes")
            Log.d(TAG, "   Initial delay: 1 minute")
            Log.d(TAG, "   Will start foreground service to launch app")
        }
        
        /**
         * Cancel the worker
         */
        fun cancel(context: Context) {
            Log.d(TAG, "❌ Cancelling AppRestartWorker...")
            WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_WORK_NAME)
        }
    }
    
    override fun doWork(): Result {
        Log.d(TAG, "")
        Log.d(TAG, "���🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧")
        Log.d(TAG, "🔧 WORKMANAGER TRIGGERED - Source: WORKMANAGER (15-min backup)")
        Log.d(TAG, "🔧 Time: ${java.text.SimpleDateFormat("HH:mm:ss").format(java.util.Date())}")
        Log.d(TAG, "🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧🔧")
        
        try {
            // Check if app was recently active
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            
            // SharedPreferences from Flutter have "flutter." prefix
            val lastActive = prefs.getLong("flutter.last_active_timestamp", 0L)
            val now = System.currentTimeMillis()
            val minutesSinceActive = if (lastActive > 0L) (now - lastActive) / 60000 else 999L
            
            Log.d(TAG, "   Last active: $lastActive")
            Log.d(TAG, "   Minutes since active: $minutesSinceActive")
            
            // If app hasn't been active for 5+ minutes, assume it's closed
            if (minutesSinceActive >= 5 || lastActive == 0L) {
                Log.d(TAG, "   ⚠️ App appears CLOSED or never active")
                
                // Check screen state
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                val isScreenOn = powerManager.isInteractive
                Log.d(TAG, "   📱 Screen state: ${if (isScreenOn) "ON" else "OFF"}")
                
                if (isScreenOn) {
                    // Screen is ON - just ensure ForegroundService is running
                    // No "HFC App Restarting" notification, no UI launch attempt
                    Log.d(TAG, "   🔆 Screen is ON - ensuring ForegroundService only (no UI)...")
                    
                    val deviceId = prefs.getString("flutter.last_connected_device_id", null)
                    val userPhone = prefs.getString("flutter.user_phone", null)
                    
                    if (deviceId != null) {
                        val serviceIntent = android.content.Intent(context, ForegroundService::class.java).apply {
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
                } else {
                    // Screen is OFF - use full-screen intent to open app UI
                    Log.d(TAG, "   🌙 Screen is OFF - launching app via AppLauncherService...")
                    AppLauncherService.start(context, "workmanager_15min")
                }
                
                // Log this event
                prefs.edit()
                    .putLong("flutter.last_workmanager_restart", now)
                    .putInt("flutter.workmanager_restart_count", 
                        prefs.getInt("flutter.workmanager_restart_count", 0) + 1)
                    .apply()
                
            } else {
                Log.d(TAG, "   ✅ App is active (last active $minutesSinceActive min ago) - no action needed")
            }
            
            return Result.success()
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in doWork: ${e.message}", e)
            return Result.retry()
        }
    }
}
