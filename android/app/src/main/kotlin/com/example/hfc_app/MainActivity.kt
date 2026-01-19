package com.example.hfc_app

import android.app.AlertDialog
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
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
    private val KEEPALIVE_CHANNEL = "com.hfc.app/main_engine_keepalive"
    private val TAG = "MainActivity"
    
    // Keep-alive mode: when true, the main Flutter engine stays alive in background
    private var isKeepAliveMode = false
    private var keepAliveDeviceId: String? = null
    private var keepAliveUserPhone: String? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Allow app to show over lock screen when launched from background
        // This is CRITICAL for full-screen intent to work properly
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        
        // Keep screen on while app is open
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Check if launched from background service
        val launchedFromBackground = intent?.getBooleanExtra("launched_from_background", false) ?: false
        val launchReason = intent?.getStringExtra("launch_reason")
        
        if (launchedFromBackground) {
            Log.d(TAG, "🚀🚀🚀 APP LAUNCHED FROM BACKGROUND! 🚀🚀🚀")
            Log.d(TAG, "   Reason: $launchReason")
            Log.d(TAG, "   Time: ${System.currentTimeMillis()}")
            
            // Dismiss any restart notification
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.cancel(9999) // NOTIFICATION_ID from AppLauncher
            notificationManager.cancel(9998) // NOTIFICATION_ID from AppLauncherService
        }
        
        // Schedule native WorkManager to restart app every 15 minutes
        // This is the MOST RELIABLE method for auto-restarting closed app
        AppRestartWorker.schedule(applicationContext)
        Log.d(TAG, "✅ Native WorkManager scheduled (15-min restart)")
        
        // Check and request overlay permission (needed for screen-ON restart)
        checkAndRequestOverlayPermission()
    }
    
    /**
     * Check if overlay permission is granted, if not show dialog to request it
     * This is CRITICAL for auto-restart when screen is ON
     */
    private fun checkAndRequestOverlayPermission() {
        if (!OverlayLauncher.hasOverlayPermission(this)) {
            Log.d(TAG, "⚠️ Overlay permission not granted - requesting...")
            
            // Show explanation dialog first
            AlertDialog.Builder(this)
                .setTitle("Enable Auto-Restart")
                .setMessage(
                    "To automatically restart and reconnect to HC20 when the app is closed, " +
                    "please enable 'Display over other apps' permission.\n\n" +
                    "This allows the app to restart even when your screen is ON."
                )
                .setPositiveButton("Enable") { _, _ ->
                    OverlayLauncher.requestOverlayPermission(this)
                }
                .setNegativeButton("Later") { dialog, _ ->
                    dialog.dismiss()
                    Log.d(TAG, "   User declined overlay permission (will ask later)")
                }
                .setCancelable(false)
                .show()
        } else {
            Log.d(TAG, "✅ Overlay permission already granted")
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup AppLauncher MethodChannel for background services to trigger app launch
        AppLauncher.setupChannel(flutterEngine, applicationContext)
        Log.d(TAG, "✅ AppLauncher MethodChannel configured")
        
        // Setup Main Engine Keep-Alive channel
        setupKeepAliveChannel(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchApp" -> {
                    // Handle request from background isolate to launch/bring app to foreground
                    Log.d(TAG, "Received launchApp request from background service")
                    AppLauncher.launchApp(applicationContext)
                    result.success(true)
                }
                "enableBackgroundExecution" -> {
                    enableBackgroundExecution()
                    result.success(true)
                }
                "disableBackgroundExecution" -> {
                    disableBackgroundExecution()
                    result.success(true)
                }
                "startNativeBleService" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    val userPhone = call.argument<String>("userPhone")
                    startNativeBleService(deviceAddress, userPhone)
                    result.success(true)
                }
                "stopNativeBleService" -> {
                    stopNativeBleService()
                    result.success(true)
                }
                "updateHealthData" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val heartRate = call.argument<Int>("heartRate")
                    val spo2 = call.argument<Int>("spo2")
                    val temperature = call.argument<Double>("temperature")
                    val batteryLevel = call.argument<Int>("batteryLevel")
                    val bpSystolic = call.argument<Int>("bloodPressureSystolic")
                    val bpDiastolic = call.argument<Int>("bloodPressureDiastolic")
                    val steps = call.argument<Int>("steps")
                    updateNativeServiceHealthData(deviceId, heartRate, spo2, temperature, batteryLevel, bpSystolic, bpDiastolic, steps)
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
                "checkExactAlarmPermission" -> {
                    val canSchedule = checkExactAlarmPermission()
                    result.success(canSchedule)
                }
                "requestExactAlarmPermission" -> {
                    requestExactAlarmPermission()
                    result.success(true)
                }
                "testAlarmScheduling" -> {
                    val status = testAlarmScheduling()
                    result.success(status)
                }
                "hasOverlayPermission" -> {
                    val hasPermission = OverlayLauncher.hasOverlayPermission(applicationContext)
                    result.success(hasPermission)
                }
                "requestOverlayPermission" -> {
                    OverlayLauncher.requestOverlayPermission(this)
                    result.success(true)
                }
                // ==================== NATIVE HC20 SERVICE (Pure Kotlin BLE) ====================
                // This is the NEW approach that works when app is swiped away
                "startNativeHC20Service" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val userPhone = call.argument<String>("userPhone")
                    Log.d(TAG, "🚀 Starting NativeHC20Service (Pure Kotlin BLE)")
                    Log.d(TAG, "   Device: $deviceId")
                    Log.d(TAG, "   Phone: $userPhone")
                    NativeHC20Service.start(applicationContext, deviceId, userPhone)
                    result.success(true)
                }
                "stopNativeHC20Service" -> {
                    Log.d(TAG, "🛑 Stopping NativeHC20Service")
                    NativeHC20Service.stop(applicationContext)
                    result.success(true)
                }
                "isNativeHC20ServiceRunning" -> {
                    val running = NativeHC20Service.isRunning()
                    Log.d(TAG, "📋 NativeHC20Service running: $running")
                    result.success(running)
                }
                // ==================== END NATIVE HC20 SERVICE ====================
                else -> result.notImplemented()
            }
        }
    }
    
    private fun startNativeBleService(deviceAddress: String?, userPhone: String?) {
        if (deviceAddress == null || userPhone == null) {
            println("❌ Missing device address or phone number")
            return
        }
        
        println("🚀 Starting native BLE service for device: $deviceAddress")
        
        val serviceIntent = Intent(this, ForegroundService::class.java).apply {
            action = ForegroundService.ACTION_START_SERVICE
            putExtra(ForegroundService.EXTRA_DEVICE_ADDRESS, deviceAddress)
            putExtra(ForegroundService.EXTRA_USER_PHONE, userPhone)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        
        // Schedule periodic sync alarms as backup
        SyncAlarmReceiver.scheduleSync(this)
        println("✅ Native BLE service started with device: $deviceAddress")
    }
    
    private fun stopNativeBleService() {
        val serviceIntent = Intent(this, ForegroundService::class.java).apply {
            action = ForegroundService.ACTION_STOP_SERVICE
        }
        stopService(serviceIntent)
        SyncAlarmReceiver.cancelSync(this)
        println("🛑 Native BLE service stopped")
    }
    
    private fun updateNativeServiceHealthData(
        deviceId: String?,
        heartRate: Int?,
        spo2: Int?,
        temperature: Double?,
        batteryLevel: Int?,
        bpSystolic: Int?,
        bpDiastolic: Int?,
        steps: Int?
    ) {
        val serviceIntent = Intent(this, ForegroundService::class.java).apply {
            action = ForegroundService.ACTION_UPDATE_HEALTH_DATA
            putExtra("deviceId", deviceId)
            putExtra("heartRate", heartRate ?: -1)
            putExtra("spo2", spo2 ?: -1)
            putExtra("temperature", temperature ?: -1.0)
            putExtra("batteryLevel", batteryLevel ?: -1)
            putExtra("bpSystolic", bpSystolic ?: -1)
            putExtra("bpDiastolic", bpDiastolic ?: -1)
            putExtra("steps", steps ?: -1)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
    
    private fun enableBackgroundExecution() {
        // Keep screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Schedule periodic sync alarms to keep service alive
        SyncAlarmReceiver.scheduleSync(this)
        println("✅ Background execution enabled with sync alarms")
    }
    
    private fun disableBackgroundExecution() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Stop foreground service
        val serviceIntent = Intent(this, ForegroundService::class.java)
        serviceIntent.action = ForegroundService.ACTION_STOP_SERVICE
        stopService(serviceIntent)
        
        // Cancel sync alarms
        SyncAlarmReceiver.cancelSync(this)
        println("🛑 Background execution disabled")
    }
    
    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            val packageName = packageName
            
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
                
                // Show autostart guidance after battery exemption request
                android.os.Handler(mainLooper).postDelayed({
                    showAutostartGuidanceIfNeeded()
                }, 1500) // Delay to let battery exemption dialog close
            } else {
                // Battery optimization already disabled, check autostart
                showAutostartGuidanceIfNeeded()
            }
        }
    }
    
    private fun isBatteryOptimizationDisabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            return powerManager.isIgnoringBatteryOptimizations(packageName)
        }
        return true // No battery optimization on older Android versions
    }
    
    private fun showAutostartGuidanceIfNeeded() {
        // Check if we've already shown this dialog
        val prefs = getSharedPreferences("hfc_app_prefs", Context.MODE_PRIVATE)
        val hasShownAutostart = prefs.getBoolean("has_shown_autostart_guidance", false)
        
        if (hasShownAutostart) {
            return // Already shown, don't show again
        }
        
        // Check if device is from a manufacturer that requires autostart permission
        val manufacturer = Build.MANUFACTURER.lowercase()
        val needsAutostartGuidance = manufacturer.contains("xiaomi") ||
                                     manufacturer.contains("oppo") ||
                                     manufacturer.contains("vivo") ||
                                     manufacturer.contains("realme") ||
                                     manufacturer.contains("oneplus")
        
        if (!needsAutostartGuidance) {
            return // Not a manufacturer that typically requires autostart permission
        }
        
        // Show autostart guidance dialog
        val manufacturerName = Build.MANUFACTURER.replaceFirstChar { 
            if (it.isLowerCase()) it.titlecase() else it.toString() 
        }
        
        AlertDialog.Builder(this)
            .setTitle("Enable Autostart")
            .setMessage("For uninterrupted background monitoring, please enable Autostart permission:\n\n" +
                "📱 Settings → Apps → HFC App → Autostart → Enable\n\n" +
                "This ensures the app continues monitoring your device after phone restart.\n\n" +
                "(Detected: $manufacturerName device)")
            .setPositiveButton("Open Settings") { _, _ ->
                tryOpenAutostartSettings()
                prefs.edit().putBoolean("has_shown_autostart_guidance", true).apply()
            }
            .setNegativeButton("Later") { _, _ ->
                prefs.edit().putBoolean("has_shown_autostart_guidance", true).apply()
            }
            .setCancelable(false)
            .show()
    }
    
    private fun tryOpenAutostartSettings() {
        val manufacturer = Build.MANUFACTURER.lowercase()
        
        try {
            val intent = when {
                manufacturer.contains("xiaomi") -> Intent().apply {
                    component = ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity"
                    )
                }
                manufacturer.contains("oppo") -> Intent().apply {
                    component = ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                    )
                }
                manufacturer.contains("vivo") -> Intent().apply {
                    component = ComponentName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                    )
                }
                manufacturer.contains("realme") || manufacturer.contains("oneplus") -> Intent().apply {
                    component = ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                    )
                }
                else -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
            }
            startActivity(intent)
            println("✅ Opened autostart settings for $manufacturer")
        } catch (e: Exception) {
            // Fallback to app settings if manufacturer-specific intent fails
            println("⚠️ Failed to open manufacturer-specific settings, opening app settings")
            try {
                val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(fallbackIntent)
            } catch (fallbackException: Exception) {
                println("❌ Failed to open any settings: ${fallbackException.message}")
            }
        }
    }
    
    /**
     * Check if app has permission to schedule exact alarms (Android 12+)
     */
    private fun checkExactAlarmPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val canSchedule = alarmManager.canScheduleExactAlarms()
            Log.d(TAG, "📋 SCHEDULE_EXACT_ALARM permission: $canSchedule")
            canSchedule
        } else {
            Log.d(TAG, "📋 SCHEDULE_EXACT_ALARM permission: not required on Android < 12")
            true
        }
    }
    
    /**
     * Request permission to schedule exact alarms (opens Settings on Android 12+)
     */
    private fun requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                Log.d(TAG, "🔐 Requesting SCHEDULE_EXACT_ALARM permission...")
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to request exact alarm permission: ${e.message}")
                // Fallback to app settings
                try {
                    val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(fallback)
                } catch (fallbackEx: Exception) {
                    Log.e(TAG, "❌ Fallback also failed: ${fallbackEx.message}")
                }
            }
        } else {
            Log.d(TAG, "ℹ️ SCHEDULE_EXACT_ALARM not required on Android < 12")
        }
    }
    
    /**
     * Test if alarms are actually scheduled
     */
    private fun testAlarmScheduling(): Map<String, Any> {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        
        // Check if keepalive alarm exists
        val keepaliveIntent = Intent(applicationContext, AppRestartReceiver::class.java).apply {
            action = "com.example.hfc_app.RESTART_APP"
        }
        val keepalivePending = PendingIntent.getBroadcast(
            applicationContext, 12346, keepaliveIntent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Check if workmanager alarm exists
        val workIntent = Intent(applicationContext, AppRestartReceiver::class.java).apply {
            action = "com.example.hfc_app.RESTART_APP"
        }
        val workPending = PendingIntent.getBroadcast(
            applicationContext, 12347, workIntent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        
        val keepaliveExists = keepalivePending != null
        val workExists = workPending != null
        
        Log.d(TAG, "🧪 Alarm Test Results:")
        Log.d(TAG, "   Keepalive alarm (12346): ${if (keepaliveExists) "✅ SCHEDULED" else "❌ NOT FOUND"}")
        Log.d(TAG, "   WorkManager alarm (12347): ${if (workExists) "✅ SCHEDULED" else "❌ NOT FOUND"}")
        
        val result = mutableMapOf<String, Any>(
            "keepaliveExists" to keepaliveExists,
            "workExists" to workExists
        )
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val canSchedule = alarmManager.canScheduleExactAlarms()
            Log.d(TAG, "   Can schedule exact alarms: ${if (canSchedule) "✅ YES" else "❌ NO"}")
            result["canScheduleExact"] = canSchedule
        } else {
            result["canScheduleExact"] = true
        }
        
        return result
    }
    
    /**
     * Setup Main Engine Keep-Alive MethodChannel
     * This allows the main Flutter engine to stay alive when app goes to background
     * Instead of HeadlessFlutter, we keep the MAIN app running but minimized
     */
    private fun setupKeepAliveChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KEEPALIVE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startKeepAlive" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val userPhone = call.argument<String>("userPhone")
                    val heartRate = call.argument<Int>("heartRate") ?: 0
                    val spo2 = call.argument<Int>("spo2") ?: 0
                    val temperature = call.argument<Double>("temperature") ?: 0.0
                    val batteryLevel = call.argument<Int>("batteryLevel") ?: 0
                    
                    Log.d(TAG, "🚀 [KeepAlive] Starting main engine keep-alive mode")
                    Log.d(TAG, "   Device: $deviceId")
                    Log.d(TAG, "   Phone: $userPhone")
                    Log.d(TAG, "   HR: $heartRate, SpO2: $spo2, Temp: $temperature, Batt: $batteryLevel")
                    
                    startMainEngineKeepAlive(deviceId, userPhone, heartRate, spo2, temperature, batteryLevel)
                    result.success(true)
                }
                "stopKeepAlive" -> {
                    Log.d(TAG, "🛑 [KeepAlive] Stopping main engine keep-alive mode")
                    stopMainEngineKeepAlive()
                    result.success(true)
                }
                "updateHealthData" -> {
                    val heartRate = call.argument<Int>("heartRate") ?: 0
                    val spo2 = call.argument<Int>("spo2") ?: 0
                    val temperature = call.argument<Double>("temperature") ?: 0.0
                    val batteryLevel = call.argument<Int>("batteryLevel") ?: 0
                    val steps = call.argument<Int>("steps") ?: 0
                    val bpSystolic = call.argument<Int>("bpSystolic") ?: 0
                    val bpDiastolic = call.argument<Int>("bpDiastolic") ?: 0
                    
                    // Update the foreground service notification
                    updateKeepAliveNotification(heartRate, spo2, temperature, batteryLevel)
                    result.success(true)
                }
                "shouldKeepAlive" -> {
                    result.success(isKeepAliveMode)
                }
                else -> result.notImplemented()
            }
        }
        Log.d(TAG, "✅ Main Engine Keep-Alive MethodChannel configured")
    }
    
    /**
     * Start keep-alive mode - keeps main Flutter engine running in background
     * This is the KEY method that prevents Android from killing the app
     */
    private fun startMainEngineKeepAlive(
        deviceId: String?, 
        userPhone: String?,
        heartRate: Int,
        spo2: Int,
        temperature: Double,
        batteryLevel: Int
    ) {
        isKeepAliveMode = true
        keepAliveDeviceId = deviceId
        keepAliveUserPhone = userPhone
        
        // Start foreground service in "main engine mode" (no HeadlessFlutter)
        val serviceIntent = Intent(this, ForegroundService::class.java).apply {
            action = ForegroundService.ACTION_START_MAIN_ENGINE_MODE
            putExtra(ForegroundService.EXTRA_DEVICE_ADDRESS, deviceId)
            putExtra(ForegroundService.EXTRA_USER_PHONE, userPhone)
            putExtra("heartRate", heartRate)
            putExtra("spo2", spo2)
            putExtra("temperature", temperature)
            putExtra("batteryLevel", batteryLevel)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        
        Log.d(TAG, "✅ [KeepAlive] Foreground service started in main engine mode")
        Log.d(TAG, "   The main Flutter engine will stay alive even when app is backgrounded")
    }
    
    /**
     * Stop keep-alive mode
     */
    private fun stopMainEngineKeepAlive() {
        isKeepAliveMode = false
        
        val serviceIntent = Intent(this, ForegroundService::class.java).apply {
            action = ForegroundService.ACTION_STOP_MAIN_ENGINE_MODE
        }
        startService(serviceIntent)
        
        Log.d(TAG, "✅ [KeepAlive] Main engine keep-alive mode stopped")
    }
    
    /**
     * Update the keep-alive notification with current health data
     */
    private fun updateKeepAliveNotification(heartRate: Int, spo2: Int, temperature: Double, batteryLevel: Int) {
        val serviceIntent = Intent(this, ForegroundService::class.java).apply {
            action = ForegroundService.ACTION_UPDATE_MAIN_ENGINE_DATA
            putExtra("heartRate", heartRate)
            putExtra("spo2", spo2)
            putExtra("temperature", temperature)
            putExtra("batteryLevel", batteryLevel)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
    
    override fun onDestroy() {
        disableBackgroundExecution()
        super.onDestroy()
    }
}
