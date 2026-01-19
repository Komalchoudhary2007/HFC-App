package com.example.hfc_app

import android.annotation.SuppressLint
import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

/**
 * NativeHC20Service - Pure Native Kotlin Foreground Service for HC20
 * 
 * This is the ONLY approach that works when app is swiped away:
 * - Pure Native Android BLE (no Flutter)
 * - Implements HC20 protocol parsing in Kotlin
 * - Sends webhooks directly from native code
 * - Runs indefinitely as a Foreground Service
 * 
 * Why this works:
 * - ForegroundService survives app swipe
 * - Native BLE doesn't need Flutter engine
 * - All logic is in Kotlin, not Dart
 */
class NativeHC20Service : Service() {
    
    companion object {
        private const val TAG = "NativeHC20Service"
        private const val CHANNEL_ID = "hfc_native_hc20"
        private const val NOTIFICATION_ID = 2 // IMPORTANT: Different from ForegroundService (ID=1) to avoid conflicts
        private const val WEBHOOK_URL = "https://api.hireforcare.com/webhook/hc20-data"
        private const val WEBHOOK_INTERVAL_MS = 180000L // 3 minutes (to avoid conflict with Flutter's 2-minute interval)
        private const val HEARTBEAT_INTERVAL_MS = 60000L // 1 minute status check
        
        const val ACTION_START = "com.example.hfc_app.NativeHC20Service.START"
        const val ACTION_STOP = "com.example.hfc_app.NativeHC20Service.STOP"
        const val EXTRA_DEVICE_ID = "device_id"
        const val EXTRA_USER_PHONE = "user_phone"
        
        @Volatile
        private var instance: NativeHC20Service? = null
        
        fun isRunning(): Boolean = instance != null
        
        fun start(context: Context, deviceId: String?, userPhone: String?) {
            if (isRunning()) {
                Log.d(TAG, "⚠️ Service already running - skipping duplicate start")
                return
            }
            
            Log.d(TAG, "🚀 Starting NativeHC20Service (INDEPENDENT of Flutter service)")
            
            val intent = Intent(context, NativeHC20Service::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_DEVICE_ID, deviceId)
                putExtra(EXTRA_USER_PHONE, userPhone)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stop(context: Context) {
            val intent = Intent(context, NativeHC20Service::class.java).apply {
                action = ACTION_STOP
            }
            context.stopService(intent)
        }
        
        /**
         * Check if BLE device lock is active
         */
        fun isBleDeviceLocked(context: Context): Boolean {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isLocked = prefs.getBoolean("native_ble_lock_active", false)
            val lockTimestamp = prefs.getLong("native_ble_lock_timestamp", 0)
            
            // Consider lock stale if older than 5 minutes (safety mechanism)
            val lockAge = System.currentTimeMillis() - lockTimestamp
            val isStale = lockAge > 300000L // 5 minutes
            
            if (isLocked && isStale) {
                Log.w(TAG, "⚠️ BLE lock is stale ($lockAge ms old) - auto-releasing")
                prefs.edit().apply {
                    putBoolean("native_ble_lock_active", false)
                    apply()
                }
                return false
            }
            
            return isLocked && !isStale
        }
    }
    
    // Components
    private lateinit var bleManager: HC20NativeBleManager
    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private val webhookClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()
    
    // State
    private var deviceId: String? = null
    private var userPhone: String? = null
    private var lastRealtimeData: HC20Protocol.RealtimeData? = null
    private var lastDataReceivedTime: Long = 0
    private var lastWebhookTime: Long = 0
    private var connectionAttempts: Int = 0
    private var webhooksSucceeded: Int = 0
    private var webhooksFailed: Int = 0
    
    // Runnables
    private var webhookRunnable: Runnable? = null
    private var heartbeatRunnable: Runnable? = null
    private var reconnectScanRunnable: Runnable? = null
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        
        Log.d(TAG, "\n")
        Log.d(TAG, "=".repeat(60))
        Log.d(TAG, "🚀 STEP 1: NativeHC20Service CREATED")
        Log.d(TAG, "=".repeat(60))
        Log.d(TAG, "✅ INDEPENDENT from Flutter service - will run separately")
        Log.d(TAG, "✅ Process ID: ${android.os.Process.myPid()}")
        Log.d(TAG, "✅ Thread: ${Thread.currentThread().name}")
        
        // STEP 1: Request battery optimization exemption FIRST
        Log.d(TAG, "\n🚀 STEP 2: Request battery optimization exemption...")
        requestBatteryOptimizationExemption()
        
        // Create notification channel
        Log.d(TAG, "\n🚀 STEP 3: Create notification channel...")
        createNotificationChannel()
        
        // Start foreground immediately with HIGH priority notification
        // Use DIFFERENT notification ID (2) from Flutter service (1)
        Log.d(TAG, "\n🚀 STEP 4: Start foreground service...")
        val notification = createNotification("Initializing HC20 connection...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID, 
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        Log.d(TAG, "✅ Foreground service started with notification ID: $NOTIFICATION_ID")
        
        // Acquire PARTIAL wake lock to prevent CPU sleep
        Log.d(TAG, "\n🚀 STEP 5: Acquire wake lock...")
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "HFCApp::NativeHC20WakeLock"
        ).apply {
            acquire()
            Log.d(TAG, "✅ Wake lock acquired - CPU will stay awake")
        }
        
        // Initialize BLE manager
        Log.d(TAG, "\n🚀 STEP 6: Initialize BLE manager...")
        bleManager = HC20NativeBleManager(applicationContext)
        setupBleCallbacks()
        Log.d(TAG, "✅ BLE manager initialized")
        
        Log.d(TAG, "\n✅ Service initialized with maximum protection against killing")
        Log.d(TAG, "✅ Notification ID: $NOTIFICATION_ID (Flutter uses ID 1, we use ID 2)")
        Log.d(TAG, "=".repeat(60))
        Log.d(TAG, "\n")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                Log.d(TAG, "\n🛑 STOP ACTION RECEIVED")
                releaseBleDeviceLock()
                stopSelf()
                return START_NOT_STICKY
            }
            
            ACTION_START -> {
                Log.d(TAG, "\n")
                Log.d(TAG, "=".repeat(60))
                Log.d(TAG, "🚀 STEP 7: START ACTION RECEIVED")
                Log.d(TAG, "=".repeat(60))
                
                deviceId = intent.getStringExtra(EXTRA_DEVICE_ID) ?: loadDeviceIdFromPrefs()
                userPhone = intent.getStringExtra(EXTRA_USER_PHONE) ?: loadUserPhoneFromPrefs()
                
                Log.d(TAG, "📱 Device ID: $deviceId")
                Log.d(TAG, "📞 User Phone: $userPhone")
                
                // CRITICAL: Claim exclusive BLE device access
                // This prevents Flutter service from conflicting with us
                Log.d(TAG, "\n🚀 STEP 8: Acquire BLE device lock...")
                acquireBleDeviceLock(deviceId)
                Log.d(TAG, "✅ BLE lock acquired - Flutter will back off")
                
                // Save to prefs
                saveToPrefs()
                
                if (deviceId != null) {
                    Log.d(TAG, "\n🚀 STEP 9: Start connection sequence...")
                    startConnection()
                    
                    Log.d(TAG, "\n🚀 STEP 10: Start periodic webhook (every 3 minutes)...")
                    startPeriodicWebhook()
                    
                    Log.d(TAG, "\n🚀 STEP 11: Start heartbeat check (every 1 minute)...")
                    startHeartbeat()
                    
                    Log.d(TAG, "\n✅ All background tasks started!")
                    Log.d(TAG, "=".repeat(60))
                    Log.d(TAG, "\n")
                } else {
                    Log.e(TAG, "❌ No device ID - cannot start")
                    updateNotification("⚠️ No HC20 device configured")
                }
            }
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "\n")
        Log.d(TAG, "=".repeat(60))
        Log.d(TAG, "⚠️⚠️⚠️ APP SWIPED AWAY - SERVICE CONTINUES! ⚠️⚠️⚠️")
        Log.d(TAG, "=".repeat(60))
        Log.d(TAG, "✅ NativeHC20Service is INDEPENDENT of Flutter")
        Log.d(TAG, "✅ Service will continue running in background")
        Log.d(TAG, "✅ BLE connection will remain active")
        Log.d(TAG, "✅ Webhooks will continue every 3 minutes")
        Log.d(TAG, "✅ Time: ${System.currentTimeMillis()}")
        
        // Send immediate webhook to confirm service survives
        Log.d(TAG, "\n📤 Sending confirmation webhook...")
        sendWebhook("app_swiped_away")
        
        // Enable continuous scanning mode for auto-reconnect
        Log.d(TAG, "\n🔄 Enabling continuous reconnect scanning...")
        startContinuousReconnectScanning()
        
        // Schedule restart as safety net
        Log.d(TAG, "\n📅 Scheduling auto-restart as safety net...")
        scheduleRestart()
        
        Log.d(TAG, "=".repeat(60))
        Log.d(TAG, "\n")
        
        super.onTaskRemoved(rootIntent)
    }
    
    override fun onDestroy() {
        Log.d(TAG, "🛑 NativeHC20Service DESTROYED")
        instance = null
        
        // Release BLE device lock so Flutter can use it again if needed
        releaseBleDeviceLock()
        
        // Cleanup
        webhookRunnable?.let { handler.removeCallbacks(it) }
        heartbeatRunnable?.let { handler.removeCallbacks(it) }
        reconnectScanRunnable?.let { handler.removeCallbacks(it) }
        bleManager.destroy()
        wakeLock?.release()
        
        // Schedule restart
        scheduleRestart()
        
        super.onDestroy()
    }
    
    /**
     * Setup BLE manager callbacks
     */
    private fun setupBleCallbacks() {
        bleManager.setCallbacks(
            onDeviceFound = { id, name ->
                Log.d(TAG, "📱 Device found: $name ($id)")
            },
            
            onConnected = { id ->
                Log.d(TAG, "\n")
                Log.d(TAG, "=".repeat(60))
                Log.d(TAG, "✅ STEP 13: CONNECTED TO HC20 DEVICE")
                Log.d(TAG, "=".repeat(60))
                Log.d(TAG, "✅ Device: $id")
                Log.d(TAG, "✅ Connection attempt: $connectionAttempts")
                Log.d(TAG, "✅ Time: ${System.currentTimeMillis()}")
                connectionAttempts = 0
                
                // Update notification for HRV2 test
                updateNotification("⏳ Testing HRV2 data...")
                
                // Stop reconnect scanning once connected
                reconnectScanRunnable?.let { handler.removeCallbacks(it) }
                
                Log.d(TAG, "\n📤 NEXT STEPS:")
                Log.d(TAG, "   1. BLE manager will discover services")
                Log.d(TAG, "   2. Enable notifications on FFF1")
                Log.d(TAG, "   3. Send set time command")
                Log.d(TAG, "   4. Start aggressive HRV2 enable loop (every 3s)")
                Log.d(TAG, "   5. Wait for HRV2 data in realtime frames")
                Log.d(TAG, "=".repeat(60))
                Log.d(TAG, "\n")
                
                // Wait a bit before sending webhook (let initialization complete)
                handler.postDelayed({
                    sendWebhook("connected")
                }, 10000) // Wait 10 seconds for HRV2 data
            },
            
            onDisconnected = {
                Log.d(TAG, "🔌 Disconnected - starting auto-reconnect scanning")
                updateNotification("🔄 Reconnecting to HC20...")
                
                // Start continuous reconnect scanning immediately when disconnected
                // This works whether app is open or closed
                startContinuousReconnectScanning()
                
                sendWebhook("disconnected")
            },
            
            onRealtimeData = { data ->
                Log.d(TAG, "💓 Realtime: HR=${data.heartRate} SpO2=${data.spo2}")
                lastRealtimeData = data
                lastDataReceivedTime = System.currentTimeMillis()
                
                // Always update notification with live data
                // This prevents stuck "Scanning..." notification
                updateNotificationWithData(data)
            },
            
            onDeviceInfo = { info ->
                Log.d(TAG, "📱 Device: ${info.name} MAC=${info.mac}")
            },
            
            onError = { error ->
                Log.e(TAG, "❌ Error: $error")
                updateNotification("⚠️ $error")
            }
        )
    }
    
    /**
     * Start connecting to the HC20 device
     */
    private fun startConnection() {
        val id = deviceId ?: return
        
        connectionAttempts++
        Log.d(TAG, "\n")
        Log.d(TAG, "🔌 STEP 12: Connecting to HC20 (attempt $connectionAttempts)")
        Log.d(TAG, "🔌 Device: $id")
        
        // Only show "Scanning" notification if we're truly disconnected
        // Don't spam notification updates if already connected or reconnecting
        if (!bleManager.isConnected()) {
            updateNotification("🔍 Scanning for HC20...")
        }
        
        if (!bleManager.hasPermissions()) {
            Log.e(TAG, "❌ Missing BLE permissions!")
            updateNotification("⚠️ Missing Bluetooth permissions")
            sendWebhook("error_no_permissions")
            return
        }
        Log.d(TAG, "✅ BLE permissions: OK")
        
        if (!bleManager.isBluetoothEnabled()) {
            Log.e(TAG, "❌ Bluetooth is disabled!")
            updateNotification("⚠️ Bluetooth is disabled")
            sendWebhook("error_bluetooth_disabled")
            return
        }
        Log.d(TAG, "✅ Bluetooth enabled: OK")
        
        Log.d(TAG, "🔎 Starting BLE connection...")
        bleManager.connect(id)
    }
    
    /**
     * Start periodic webhook sender
     */
    private fun startPeriodicWebhook() {
        webhookRunnable?.let { handler.removeCallbacks(it) }
        
        webhookRunnable = object : Runnable {
            override fun run() {
                sendWebhook("periodic")
                handler.postDelayed(this, WEBHOOK_INTERVAL_MS)
            }
        }
        
        // Start after initial delay
        handler.postDelayed(webhookRunnable!!, WEBHOOK_INTERVAL_MS)
        Log.d(TAG, "✅ Periodic webhook started (every ${WEBHOOK_INTERVAL_MS/1000}s)")
    }
    
    /**
     * Start heartbeat check
     */
    private fun startHeartbeat() {
        heartbeatRunnable?.let { handler.removeCallbacks(it) }
        
        heartbeatRunnable = object : Runnable {
            override fun run() {
                checkHealth()
                handler.postDelayed(this, HEARTBEAT_INTERVAL_MS)
            }
        }
        
        handler.postDelayed(heartbeatRunnable!!, HEARTBEAT_INTERVAL_MS)
        Log.d(TAG, "✅ Heartbeat check started (every ${HEARTBEAT_INTERVAL_MS/1000}s)")
    }
    
    /**
     * Check connection health and reconnect if needed
     * CRITICAL: Detect when BLE says "connected" but no data is arriving (notifications stopped)
     */
    private fun checkHealth() {
        val now = System.currentTimeMillis()
        val timeSinceLastData = if (lastDataReceivedTime > 0) now - lastDataReceivedTime else -1
        val isConnected = bleManager.isConnected()
        
        Log.d(TAG, "💓 Heartbeat: connected=$isConnected, timeSinceLastData=${timeSinceLastData/1000}s")
        
        // Case 1: Not connected at all
        if (!isConnected && deviceId != null) {
            Log.d(TAG, "🔄 Not connected - attempting reconnect")
            startConnection()
            return
        }
        
        // Case 2: CRITICAL - Connected but no data for >45 seconds
        // This happens after app swipe - BLE says connected but notifications stopped
        if (isConnected && timeSinceLastData > 45000) {
            Log.w(TAG, "⚠️⚠️⚠️ STALE DATA DETECTED: Connected but no data for ${timeSinceLastData/1000}s")
            Log.w(TAG, "⚠️⚠️⚠️ BLE notifications likely stopped after app swipe - forcing reconnect")
            
            // Update notification to show we detected the issue
            updateNotification("🔄 Data stopped - reconnecting...")
            
            // Force disconnect and reconnect to re-enable notifications
            bleManager.disconnect()
            
            handler.postDelayed({
                if (deviceId != null) {
                    Log.d(TAG, "🔄 Reconnecting to restore data flow...")
                    bleManager.connect(deviceId!!)
                }
            }, 2000)
        }
    }
    
    /**
     * Start continuous background scanning for auto-reconnect
     * This runs in ALL scenarios to ensure device reconnects automatically:
     * - When app is swiped away / closed
     * - When app is open but device disconnects
     * - When device is turned off and back on
     * - When device goes out of range and comes back
     */
    private fun startContinuousReconnectScanning() {
        // Cancel any existing reconnect scanning
        reconnectScanRunnable?.let { handler.removeCallbacks(it) }
        
        reconnectScanRunnable = object : Runnable {
            override fun run() {
                if (!bleManager.isConnected() && deviceId != null) {
                    Log.d(TAG, "🔍 [Auto-Reconnect] Scanning for device: $deviceId")
                    bleManager.connect(deviceId!!)
                } else if (bleManager.isConnected()) {
                    Log.d(TAG, "✅ [Auto-Reconnect] Device connected - stopping scan")
                    return // Stop scanning once connected
                }
                
                // Check again every 30 seconds (infinite loop until connected)
                handler.postDelayed(this, 30000)
            }
        }
        
        Log.d(TAG, "✅ Continuous reconnect scanning enabled (every 30s) - works in ALL scenarios")
        handler.post(reconnectScanRunnable!!)
    }
    
    /**
     * Send webhook with current data - matching Flutter payload format exactly
     */
    private fun sendWebhook(trigger: String) {
        Log.d(TAG, "\n📤 === SENDING NATIVE WEBHOOK ($trigger) ===")
        
        if (userPhone == null) {
            Log.e(TAG, "❌ No user phone - skipping webhook")
            return
        }
        
        val now = System.currentTimeMillis()
        val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSSSS", Locale.getDefault())
        
        val isConnected = bleManager.isConnected()
        val data = lastRealtimeData
        val mac = bleManager.getConnectedDeviceMac() ?: deviceId ?: "unknown"
        val deviceName = bleManager.getConnectedDeviceName() ?: "B20_${mac.replace(":", "")}"
        
        // Calculate time since we last RECEIVED data (more accurate than data.timestamp)
        val timeSinceLastData = if (lastDataReceivedTime > 0) now - lastDataReceivedTime else -1
        val dataAge = if (data != null) now - data.timestamp else -1
        
        // Data is valid if: Connected AND received data in last 90 seconds
        val hasValidData = isConnected && data != null && timeSinceLastData >= 0 && timeSinceLastData < 90000
        val actualData = if (hasValidData) data else null
        
        Log.d(TAG, "📊 Webhook: connected=$isConnected, timeSinceReceived=${timeSinceLastData/1000}s, dataAge=${dataAge/1000}s, hasValidData=$hasValidData")
        if (actualData != null) {
            Log.d(TAG, "📊 Data fields: HR=${actualData.heartRate}, RRI=${actualData.rri}, SpO2=${actualData.spo2}, BP=${actualData.bloodPressure}, Temp=${actualData.temperature}, Steps=${actualData.steps}, Baro=${actualData.baro}, Sleep=${actualData.sleep}, GNSS=${actualData.gnss}, HRV=${actualData.hrv}, HRV2=${actualData.hrv2}")
        }
        
        if (!hasValidData) {
            if (!isConnected) {
                Log.w(TAG, "⚠️ Not connected - sending NULL data")
            } else if (data == null) {
                Log.w(TAG, "⚠️ No data received yet - sending NULL data")
            } else if (timeSinceLastData >= 90000) {
                Log.w(TAG, "⚠️ Data stale (last received ${timeSinceLastData/1000}s ago) - sending NULL data")
            }
        }
        
        // Build JSON matching Flutter _sendDataToWebhook payload format
        val json = JSONObject().apply {
            // Top-level fields (include phone for consistency with Flutter)
            put("phone", userPhone)
            put("isStressAlert", false)
            put("timestamp", dateFormat.format(Date(now)))
            
            // Status fields - reflect ACTUAL data availability (not just BLE state)
            // If not receiving data, we're effectively disconnected regardless of BLE state
            put("status", if (hasValidData) "Connected" else "Disconnected")
            put("bluetoothStatus", if (bleManager.isBluetoothEnabled()) "Connected" else "Disconnected")
            put("internetStatus", "Connected") // We're sending webhook, so internet is connected
            put("dataType", if (hasValidData) "live" else "disconnect")
            
            // Device battery information
            put("deviceBatteryLevel", actualData?.batteryPercent)
            put("isDeviceLowBattery", (actualData?.batteryPercent ?: 100) <= 20)
            
            // Device object
            put("device", JSONObject().apply {
                put("id", mac)
                put("name", deviceName)
            })
            
            // MINIMAL TEST: Send ONLY hrv2_metrics and heart_rate
            put("realtime_data", JSONObject().apply {
                // Minimal baseline
                put("heart_rate", actualData?.heartRate)
                put("battery_percent", actualData?.batteryPercent)
                
                // HRV2 (raw array: mental_stress, fatigue, stress_resistance, regulation_ability)
                actualData?.hrv2?.let { hrv2 ->
                    put("hrv2_raw", org.json.JSONArray(hrv2))
                } ?: put("hrv2_raw", JSONObject.NULL)
                
                // HRV2 metrics - THIS IS THE TEST TARGET
                actualData?.hrv2Metrics?.let { metrics ->
                    put("hrv2_metrics", JSONObject().apply {
                        put("mental_stress", metrics.mentalStress)
                        put("fatigue_level", metrics.fatigueLevel)
                        put("stress_resistance", metrics.stressResistance)
                        put("regulation_ability", metrics.regulationAbility)
                    })
                } ?: put("hrv2_metrics", JSONObject.NULL)
            })
            
            // Additional metadata for debugging (optional, can be removed later)
            put("_meta", JSONObject().apply {
                put("source", "NATIVE_KOTLIN_SERVICE")
                put("trigger", trigger)
                put("phone", userPhone)
            })
        }
        
        Log.d(TAG, "📤 Webhook payload: ${json.toString(2)}")
        
        val request = Request.Builder()
            .url(WEBHOOK_URL)
            .post(json.toString().toRequestBody("application/json".toMediaType()))
            .addHeader("X-Source", "native-kotlin")
            .addHeader("X-Device-Id", mac)
            .build()
        
        webhookClient.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                webhooksFailed++
                Log.e(TAG, "❌ Webhook failed: ${e.message}")
            }
            
            override fun onResponse(call: Call, response: Response) {
                response.use {
                    if (response.isSuccessful) {
                        webhooksSucceeded++
                        lastWebhookTime = now
                        Log.d(TAG, "✅ Webhook sent successfully (${response.code})")
                    } else {
                        webhooksFailed++
                        Log.e(TAG, "❌ Webhook error: ${response.code} ${response.message}")
                    }
                }
            }
        })
    }
    
    /**
     * Request battery optimization exemption
     * This prevents Android from killing the service after 15 minutes in background
     */
    @SuppressLint("BatteryLife")
    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            val packageName = packageName
            
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                Log.w(TAG, "⚠️ Battery optimization NOT exempted - requesting exemption")
                try {
                    val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = android.net.Uri.parse("package:$packageName")
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    Log.d(TAG, "✅ Battery optimization exemption requested")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to request battery optimization exemption: ${e.message}")
                }
            } else {
                Log.d(TAG, "✅ Battery optimization already exempted - service protected!")
            }
        }
    }
    
    /**
     * Create notification channel
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "HC20 Native Service",
                NotificationManager.IMPORTANCE_HIGH // HIGH to prevent Android from killing
            ).apply {
                description = "Background HC20 health monitoring - HRV2 test mode"
                setShowBadge(true)
                enableVibration(false)
                enableLights(false)
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    /**
     * Create notification
     */
    private fun createNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("HC20 Health Monitor")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setOngoing(true) // Cannot be dismissed by user
            .setAutoCancel(false) // Cannot be cancelled
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_MAX) // MAXIMUM priority
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }
    
    /**
     * Update notification text
     */
    private fun updateNotification(text: String) {
        val notification = createNotification(text)
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification)
    }
    
    /**
     * Update notification with health data
     */
    private fun updateNotificationWithData(data: HC20Protocol.RealtimeData) {
        val text = buildString {
            // Check if we have HRV2 (test target)
            val hrv2 = data.hrv2Metrics
            if (hrv2 != null) {
                append("✅ HRV2: ✅ ")
                append("Stress=${hrv2.mentalStress} ")
                append("Fatigue=${hrv2.fatigueLevel} ")
            } else {
                append("⏳ HRV2: waiting... ")
            }
            
            data.heartRate?.let { append("💓$it BPM ") }
            data.batteryPercent?.let { append("🔋$it%") }
        }
        updateNotification(text.ifEmpty { "📡 Testing HRV2..." })
    }
    
    /**
     * Schedule service restart with MULTIPLE mechanisms
     * Layer 1: AlarmManager (survives app kill)
     * Layer 2: PendingIntent with setExactAndAllowWhileIdle
     * Layer 3: Broadcast receiver for BOOT_COMPLETED
     */
    private fun scheduleRestart() {
        val intent = Intent(applicationContext, NativeHC20Service::class.java).apply {
            action = ACTION_START
            putExtra(EXTRA_DEVICE_ID, deviceId)
            putExtra(EXTRA_USER_PHONE, userPhone)
        }
        
        val pendingIntent = PendingIntent.getService(
            applicationContext,
            100,
            intent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // Use setExactAndAllowWhileIdle for maximum reliability
        // This works even in Doze mode
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ requires SCHEDULE_EXACT_ALARM permission
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        android.os.SystemClock.elapsedRealtime() + 1000,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Exact alarm scheduled for restart (Android 12+)")
                } else {
                    // Fallback to non-exact alarm
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        android.os.SystemClock.elapsedRealtime() + 1000,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Non-exact alarm scheduled for restart (no permission)")
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    android.os.SystemClock.elapsedRealtime() + 1000,
                    pendingIntent
                )
                Log.d(TAG, "✅ Exact alarm scheduled for restart")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to schedule restart: ${e.message}")
            // Fallback: immediate restart attempt
            handler.postDelayed({
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
            }, 1000)
        }
    }
    
    /**
     * Acquire exclusive BLE device access lock
     * This prevents Flutter service from accessing the same device simultaneously
     */
    private fun acquireBleDeviceLock(deviceId: String?) {
        if (deviceId == null) return
        
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putBoolean("native_ble_lock_active", true)
            putString("native_ble_lock_device", deviceId)
            putLong("native_ble_lock_timestamp", System.currentTimeMillis())
            apply()
        }
        
        Log.d(TAG, "🔒 BLE device lock ACQUIRED for $deviceId")
        Log.d(TAG, "🔒 Flutter service should now back off from BLE operations")
    }
    
    /**
     * Release BLE device access lock
     * Allows Flutter service to use BLE again
     */
    private fun releaseBleDeviceLock() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putBoolean("native_ble_lock_active", false)
            remove("native_ble_lock_device")
            remove("native_ble_lock_timestamp")
            apply()
        }
        
        Log.d(TAG, "🔓 BLE device lock RELEASED")
        Log.d(TAG, "🔓 Flutter service can now use BLE if needed")
    }
    
    /**
     * Load device ID from SharedPreferences
     */
    private fun loadDeviceIdFromPrefs(): String? {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getString("flutter.last_connected_device_id", null)
            ?: prefs.getString("last_connected_device_id", null)
    }
    
    /**
     * Load user phone from SharedPreferences
     */
    private fun loadUserPhoneFromPrefs(): String? {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getString("flutter.user_phone", null)
            ?: prefs.getString("user_phone", null)
    }
    
    /**
     * Save current settings to SharedPreferences
     */
    private fun saveToPrefs() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().apply {
            deviceId?.let { 
                putString("flutter.last_connected_device_id", it) 
                putString("native_hc20_device_id", it)
            }
            userPhone?.let { 
                putString("flutter.user_phone", it) 
                putString("native_hc20_user_phone", it)
            }
            putBoolean("native_hc20_service_enabled", true)
            apply()
        }
    }
}
