package com.example.hfc_app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel

/**
 * HeadlessFlutterService - Maintains a background Flutter engine for HC20 SDK
 * 
 * WHY THIS IS NEEDED:
 * - HC20 SDK is a Flutter/Dart package
 * - When UI is closed, normal Flutter engine dies
 * - This creates a "headless" Flutter engine that runs in the background
 * - The headless engine can run the HC20 SDK and send webhooks
 * 
 * HOW IT WORKS:
 * 1. Creates a separate FlutterEngine (no UI)
 * 2. Runs a special Dart entry point: @pragma('vm:entry-point') void backgroundMain()
 * 3. That Dart code connects to HC20 and sends webhooks
 * 4. Engine runs as long as ForegroundService is alive
 * 
 * IMPORTANT: Plugins must be registered for BLE, HTTP, SharedPreferences to work!
 */
object HeadlessFlutterService {
    private const val TAG = "HeadlessFlutter"
    private const val ENGINE_ID = "hfc_background_engine"
    private const val CHANNEL_NAME = "com.example.hfc_app/headless"
    private const val HC20_CHANNEL_ID = "hc20_debug_channel"
    private const val HC20_NOTIFICATION_ID_BASE = 1000 // Different from foreground service ID (1)
    
    private var flutterEngine: FlutterEngine? = null
    private var isRunning = false
    private var appContext: Context? = null
    private var notificationIdCounter = HC20_NOTIFICATION_ID_BASE
    
    /**
     * Start the headless Flutter engine
     * Call this from ForegroundService.onCreate()
     */
    fun start(context: Context, deviceMac: String?, userPhone: String?) {
        if (isRunning) {
            Log.d(TAG, "⚠️ Headless Flutter already running")
            return
        }
        
        Log.d(TAG, "🚀 Starting Headless Flutter Engine...")
        Log.d(TAG, "   Device: $deviceMac")
        Log.d(TAG, "   Phone: $userPhone")
        
        // Store context for notifications
        appContext = context.applicationContext
        
        // Create notification channel for HC20 debug notifications
        createHC20NotificationChannel(appContext!!)
        
        // Check BLE permissions (critical for HC20 SDK)
        val hasBluetoothConnect = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            context.checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        val hasBluetoothScan = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            context.checkSelfPermission(android.Manifest.permission.BLUETOOTH_SCAN) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        val hasLocationFine = context.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED
        
        Log.d(TAG, "   BLE Permissions: CONNECT=$hasBluetoothConnect SCAN=$hasBluetoothScan LOCATION=$hasLocationFine")
        
        if (!hasBluetoothConnect || !hasBluetoothScan) {
            Log.e(TAG, "❌ CRITICAL: Missing BLE permissions! HC20 SDK will NOT work!")
            Log.e(TAG, "   This is likely why HC20 is not connecting in headless mode.")
        }
        
        try {
            // Create a new Flutter engine (not attached to any activity)
            // Use application context to ensure it has all necessary permissions
            val appContext = context.applicationContext
            flutterEngine = FlutterEngine(appContext).apply {
                // Don't automatically run the default entry point
                navigationChannel.setInitialRoute("/background")
            }
            
            // CRITICAL: Register all Flutter plugins!
            // Without this, BLE, HTTP, SharedPreferences won't work
            try {
                GeneratedPluginRegistrant.registerWith(flutterEngine!!)
                Log.d(TAG, "✅ Flutter plugins registered")
            } catch (e: Exception) {
                Log.e(TAG, "⚠️ Plugin registration error (may be okay): ${e.message}")
            }
            
            // Cache the engine so it can be reused
            FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
            
            // Execute the background Dart entry point
            // This calls the @pragma('vm:entry-point') function in Dart
            val bundlePath = FlutterInjector.instance().flutterLoader().findAppBundlePath()
            flutterEngine?.dartExecutor?.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(bundlePath, "backgroundMain")
            )
            
            Log.d(TAG, "✅ Dart entry point 'backgroundMain' started")
            
            // Setup method channel to communicate with the headless Dart code
            setupMethodChannel(deviceMac, userPhone)
            
            isRunning = true
            Log.d(TAG, "✅✅✅ Headless Flutter Engine is now running! ✅✅✅")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start headless Flutter: ${e.message}", e)
        }
    }
    
    /**
     * Setup method channel to communicate with headless Dart code
     */
    private fun setupMethodChannel(deviceMac: String?, userPhone: String?) {
        flutterEngine?.let { engine ->
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME).apply {
                // Send device info to Dart so it can connect
                invokeMethod("initialize", mapOf(
                    "deviceMac" to deviceMac,
                    "userPhone" to userPhone,
                    "timestamp" to System.currentTimeMillis()
                ))
                
                // Handle calls from Dart
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "log" -> {
                            val message = call.argument<String>("message")
                            Log.d(TAG, "[Dart] $message")
                            result.success(true)
                        }
                        "onDataReceived" -> {
                            val heartRate = call.argument<Int>("heartRate")
                            val spo2 = call.argument<Int>("spo2")
                            Log.d(TAG, "📊 Data from headless Dart: HR=$heartRate SpO2=$spo2")
                            result.success(true)
                        }
                        "onWebhookSent" -> {
                            val success = call.argument<Boolean>("success")
                            Log.d(TAG, "📤 Webhook from headless Dart: ${if (success == true) "✅" else "❌"}")
                            result.success(true)
                        }
                        "showNotification" -> {
                            // NEW: Handle notification requests from Dart
                            val title = call.argument<String>("title") ?: "HC20"
                            val message = call.argument<String>("message") ?: ""
                            val isError = call.argument<Boolean>("isError") ?: false
                            Log.d(TAG, "🔔 Notification from Dart: $title - $message (error=$isError)")
                            appContext?.let { ctx ->
                                showHC20Notification(ctx, title, message, isError)
                            }
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
        }
    }
    
    /**
     * Stop the headless Flutter engine
     * Call this when service is destroyed
     */
    fun stop() {
        Log.d(TAG, "🛑 Stopping Headless Flutter Engine...")
        
        try {
            FlutterEngineCache.getInstance().remove(ENGINE_ID)
            flutterEngine?.destroy()
            flutterEngine = null
            isRunning = false
            
            Log.d(TAG, "✅ Headless Flutter Engine stopped")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping engine: ${e.message}")
        }
    }
    
    /**
     * Check if headless engine is running
     */
    fun isRunning(): Boolean = isRunning
    
    /**
     * Get the cached engine (for plugin registration)
     */
    fun getEngine(): FlutterEngine? = flutterEngine
    
    /**
     * Create notification channel for HC20 debug notifications
     */
    private fun createHC20NotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                HC20_CHANNEL_ID,
                "HC20 Connection Status",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shows HC20 device connection status and errors"
                setShowBadge(true)
                enableVibration(true)
                setSound(null, null)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            Log.d(TAG, "✅ HC20 notification channel created")
        }
    }
    
    /**
     * Show HC20 notification (called from Dart)
     */
    private fun showHC20Notification(context: Context, title: String, message: String, isError: Boolean) {
        try {
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            
            val notification = NotificationCompat.Builder(context, HC20_CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .setSmallIcon(if (isError) android.R.drawable.ic_dialog_alert else android.R.drawable.ic_dialog_info)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setAutoCancel(true) // Can be dismissed
                .setShowWhen(true)
                .build()
            
            val manager = context.getSystemService(NotificationManager::class.java)
            // Use incrementing IDs so each notification is separate (not replaced)
            manager.notify(notificationIdCounter++, notification)
            
            Log.d(TAG, "✅ Notification shown: $title")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to show notification: ${e.message}", e)
        }
    }
}
