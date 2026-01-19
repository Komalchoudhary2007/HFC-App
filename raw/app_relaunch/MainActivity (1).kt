package com.example.hfc_app

import android.app.AlertDialog
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.hfc.app/background"
    
    companion object {
        private const val TAG = "MainActivity"
    }
    
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "MainActivity created")
        
        // Handle background launch from AlarmManager
        val launchReason = intent?.getStringExtra("launch_reason")
        val deviceId = intent?.getStringExtra("device_id")
        val launchedFromBackground = intent?.getBooleanExtra("launched_from_background", false) ?: false
        
        if (launchedFromBackground) {
            Log.d(TAG, "🚀 App launched from background - Reason: $launchReason, Device: $deviceId")
        }
        
        // ⚠️ CRITICAL: Always configure lock screen display (not just when launched from background)
        // This ensures app can show on lock screen whenever needed
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        
        // Schedule keepalive alarm
        AppKeepaliveScheduler.scheduleAlarm(applicationContext, 5 * 60 * 1000L)
        
        // ⭐ Check and request critical permissions
        checkAndRequestPermissions()
    }
    
    /**
     * Check and request all required permissions for relaunch functionality
     */
    private fun checkAndRequestPermissions() {
        val issues = mutableListOf<String>()
        
        // Check exact alarm permission (Android 12+)
        if (!checkExactAlarmPermission()) {
            Log.w(TAG, "⚠️  SCHEDULE_EXACT_ALARM permission not granted")
            issues.add("Exact alarms")
        } else {
            Log.d(TAG, "✅ SCHEDULE_EXACT_ALARM permission granted")
        }
        
        // Check full-screen intent permission (Android 14+)
        if (!checkFullScreenIntentPermission()) {
            Log.w(TAG, "⚠️  USE_FULL_SCREEN_INTENT permission not granted (Android 14+)")
            issues.add("Full screen intent")
        } else {
            Log.d(TAG, "✅ USE_FULL_SCREEN_INTENT permission granted")
        }
        
        // Check battery optimization
        if (!isBatteryOptimizationDisabled()) {
            Log.w(TAG, "⚠️  Battery optimization is enabled - app may be killed")
            issues.add("Battery optimization")
        } else {
            Log.d(TAG, "✅ Battery optimization disabled")
        }
        
        // Show dialog if any permissions are missing
        if (issues.isNotEmpty()) {
            val message = buildString {
                append("To keep the app running and reliably restart when screen is off:\n\n")
                issues.forEachIndexed { index, issue ->
                    append("${index + 1}. Enable '$issue'")
                    append(" permission in Settings")
                    if (index < issues.size - 1) append("\n")
                }
                append("\n\nThis is required for HC20 device connection to stay active.")
            }
            
            AlertDialog.Builder(this)
                .setTitle("Enable Required Permissions")
                .setMessage(message)
                .setPositiveButton("Open Settings") { _, _ ->
                    Log.d(TAG, "Opening app settings to enable permissions")
                    openAppSettings()
                }
                .setNegativeButton("Later") { dialog, _ ->
                    dialog.dismiss()
                    Log.d(TAG, "User deferred permission setup")
                }
                .setCancelable(false)
                .show()
        }
    }
    
    /**
     * Check if exact alarm permission is granted (Android 12+)
     */
    private fun checkExactAlarmPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(ALARM_SERVICE) as android.app.AlarmManager
            val canSchedule = alarmManager.canScheduleExactAlarms()
            Log.d(TAG, "Exact alarm permission check (Android 12+): $canSchedule")
            return canSchedule
        }
        return true // Older Android doesn't require this
    }
    
    /**
     * Check if full-screen intent permission is granted (Android 14+)
     */
    private fun checkFullScreenIntentPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // API 34
            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
            val canUse = notificationManager.canUseFullScreenIntent()
            Log.d(TAG, "Full-screen intent permission check (Android 14+): $canUse")
            return canUse
        }
        return true // Older Android doesn't require this
    }
    
    /**
     * Check if battery optimization is disabled
     */
    private fun isBatteryOptimizationDisabled(): Boolean {
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        val isIgnored = powerManager.isIgnoringBatteryOptimizations(packageName)
        Log.d(TAG, "Battery optimization check: ${if (isIgnored) "DISABLED (good)" else "ENABLED (bad)"}")
        return isIgnored
    }
    
    /**
     * Open app settings to enable permissions
     */
    private fun openAppSettings() {
        try {
            // Try to open Alarms & reminders settings (Android 12+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    val intent = Intent("android.settings.REQUEST_SCHEDULE_EXACT_ALARM")
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                    return
                } catch (e: Exception) {
                    Log.d(TAG, "Could not open exact alarm settings: ${e.message}")
                }
            }
            
            // Fallback: Open app details settings
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
            Toast.makeText(this, "Enable all permissions for HC20 connection", Toast.LENGTH_LONG).show()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open settings: ${e.message}")
            Toast.makeText(this, "Please enable permissions in Settings", Toast.LENGTH_LONG).show()
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Main background channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableBackgroundExecution" -> {
                    enableBackgroundExecution()
                    result.success(true)
                }
                "disableBackgroundExecution" -> {
                    disableBackgroundExecution()
                    result.success(true)
                }
                "requestBatteryOptimizationExemption" -> {
                    requestBatteryOptimizationExemption()
                    result.success(true)
                }
                "isBatteryOptimizationDisabled" -> {
                    val isDisabled = isBatteryOptimizationDisabled()
                    result.success(isDisabled)
                }
                else -> result.notImplemented()
            }
        }
        
        // App launcher channel (for keepalive service)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.hfc_app/app_launcher").setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleKeepaliveRestart" -> {
                    try {
                        val delaySeconds = (call.argument<Number>("delaySeconds") as? Number)?.toLong() ?: 300L
                        val scheduledBy = call.argument<String>("scheduledBy") ?: "unknown"
                        Log.d(TAG, "📅 Scheduling keepalive restart: ${delaySeconds}s (by: $scheduledBy)")
                        
                        AppKeepaliveScheduler.scheduleAlarm(
                            applicationContext,
                            delaySeconds * 1000L
                        )
                        result.success(mapOf(
                            "success" to true,
                            "message" to "Alarm scheduled for $delaySeconds seconds",
                            "scheduledBy" to scheduledBy
                        ))
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Error scheduling keepalive: ${e.message}")
                        result.error("SCHEDULE_ERROR", e.message, null)
                    }
                }
                "launchApp" -> {
                    try {
                        Log.d(TAG, "🚀 Launch app requested via MethodChannel")
                        val launchIntent = Intent(this, MainActivity::class.java)
                        launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        launchIntent.putExtra("launched_from_background", true)
                        launchIntent.putExtra("launch_reason", "keepalive_service")
                        startActivity(launchIntent)
                        result.success(mapOf("success" to true, "message" to "App launch initiated"))
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Error launching app: ${e.message}")
                        result.error("LAUNCH_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun enableBackgroundExecution() {
        // Keep screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Start foreground service
        val serviceIntent = Intent(this, ForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        
        // Schedule keepalive alarm
        AppKeepaliveScheduler.scheduleAlarm(this, 5 * 60 * 1000L)
    }
    
    private fun disableBackgroundExecution() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Stop foreground service
        val serviceIntent = Intent(this, ForegroundService::class.java)
        stopService(serviceIntent)
    }
    
    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            val packageName = packageName
            
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
        }
    }
    
    override fun onDestroy() {
        disableBackgroundExecution()
        // Note: We don't cancel the alarm here since the app might be killed by Android
        super.onDestroy()
    }
}
