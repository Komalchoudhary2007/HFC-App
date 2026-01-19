package com.example.hfc_app

import android.app.*
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.*

class ForegroundService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothGatt: BluetoothGatt? = null
    private var bleScanner: BluetoothLeScanner? = null
    private val handler = Handler(Looper.getMainLooper())
    private val webhookClient = OkHttpClient()
    
    // Device info from SharedPreferences
    private var deviceMacAddress: String? = null
    private var userPhone: String? = null
    
    // Latest health data
    private var heartRate: Int? = null
    private var spo2: Int? = null
    private var temperature: Double? = null
    private var batteryLevel: Int? = null
    private var lastDataUpdateTime: Long = 0
    
    // Auto-reconnection
    private var reconnectRunnable: Runnable? = null
    private var isConnecting = false
    private var reconnectAttempts = 0
    private val maxReconnectAttempts = 5
    
    // Periodic webhook sender
    private var webhookRunnable: Runnable? = null
    
    // Main Engine Mode: When true, Flutter main engine handles everything
    // We just keep the service alive to prevent Android from killing the app
    private var isMainEngineMode = false
    
    companion object {
        private const val CHANNEL_ID = "hfc_background"
        private const val NOTIFICATION_ID = 1
        const val ACTION_START_SERVICE = "START_SERVICE"
        const val ACTION_STOP_SERVICE = "STOP_SERVICE"
        const val ACTION_UPDATE_HEALTH_DATA = "UPDATE_HEALTH_DATA"
        // New actions for main engine keep-alive mode
        const val ACTION_START_MAIN_ENGINE_MODE = "START_MAIN_ENGINE_MODE"
        const val ACTION_STOP_MAIN_ENGINE_MODE = "STOP_MAIN_ENGINE_MODE"
        const val ACTION_UPDATE_MAIN_ENGINE_DATA = "UPDATE_MAIN_ENGINE_DATA"
        const val EXTRA_DEVICE_ADDRESS = "device_address"
        const val EXTRA_USER_PHONE = "user_phone"
        private const val WEBHOOK_URL = "https://api.hireforcare.com/webhook/hc20-data"
        private const val WEBHOOK_INTERVAL_MS = 120000L // 2 minutes
        private const val RECONNECT_DELAY_MS = 5000L // 5 seconds
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        
        // Start foreground immediately with persistent notification
        val notification = createNotification("Initializing...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, 
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        
        // Acquire PARTIAL_WAKE_LOCK to keep CPU running for BLE + network
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "HFCApp::ServiceWakeLock"
        ).apply {
            acquire()
        }
        
        // Initialize Bluetooth
        bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter
        bleScanner = bluetoothAdapter?.bluetoothLeScanner
        
        println("✅ [ForegroundService] Started with wake lock and BLE initialized")
    }
    
    /**
     * Start headless Flutter engine for background HC20 connection
     * This keeps the HC20 SDK running even when UI is closed
     */
    private fun startHeadlessFlutter() {
        // Get device info from SharedPreferences if not available from intent
        if (deviceMacAddress == null || userPhone == null) {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (deviceMacAddress == null) {
                deviceMacAddress = prefs.getString("flutter.last_connected_device_id", null)
            }
            if (userPhone == null) {
                userPhone = prefs.getString("flutter.user_phone", null)
            }
            println("📋 [ForegroundService] Loaded from prefs: device=$deviceMacAddress phone=$userPhone")
        }
        
        if (!HeadlessFlutterService.isRunning()) {
            println("🚀 [ForegroundService] Starting Headless Flutter Engine for HC20...")
            println("   Device: $deviceMacAddress")
            println("   Phone: $userPhone")
            HeadlessFlutterService.start(applicationContext, deviceMacAddress, userPhone)
        } else {
            println("✅ [ForegroundService] Headless Flutter already running")
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_SERVICE -> {
                stopBleConnection()
                stopSelf()
                return START_NOT_STICKY
            }
            
            // ==================== MAIN ENGINE KEEP-ALIVE MODE ====================
            // This is the NEW approach: keep main Flutter engine alive instead of HeadlessFlutter
            ACTION_START_MAIN_ENGINE_MODE -> {
                isMainEngineMode = true
                deviceMacAddress = intent.getStringExtra(EXTRA_DEVICE_ADDRESS)
                userPhone = intent.getStringExtra(EXTRA_USER_PHONE)
                
                val hr = intent.getIntExtra("heartRate", 0)
                val sp = intent.getIntExtra("spo2", 0)
                val temp = intent.getDoubleExtra("temperature", 0.0)
                val batt = intent.getIntExtra("batteryLevel", 0)
                
                if (hr > 0) heartRate = hr
                if (sp > 0) spo2 = sp
                if (temp > 0) temperature = temp
                if (batt > 0) batteryLevel = batt
                
                // Save to SharedPreferences
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putBoolean("is_main_engine_mode", true)
                    if (deviceMacAddress != null) {
                        putString("flutter.last_connected_device_id", deviceMacAddress)
                    }
                    if (userPhone != null) {
                        putString("flutter.user_phone", userPhone)
                    }
                    apply()
                }
                
                println("🚀🚀🚀 [ForegroundService] MAIN ENGINE KEEP-ALIVE MODE STARTED! 🚀🚀🚀")
                println("   ✅ Main Flutter engine will stay alive in background")
                println("   ✅ HC20 connection already established - no need to reconnect!")
                println("   ✅ BLE permissions already granted - no issues!")
                println("   Device: $deviceMacAddress")
                println("   Phone: $userPhone")
                
                // Update notification to show we're in keep-alive mode
                if (heartRate != null && heartRate!! > 0) {
                    updateNotification("💓 $heartRate BPM | 🩸 $spo2% | 🌡️ $temperature°C | 🔋 $batteryLevel% (Background)")
                } else {
                    updateNotification("📡 Monitoring HC20 in background...")
                }
                
                // DON'T start HeadlessFlutter - main engine handles everything!
                // DON'T start periodic webhook - Flutter is still sending them!
                
                return START_STICKY
            }
            
            ACTION_STOP_MAIN_ENGINE_MODE -> {
                isMainEngineMode = false
                
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("is_main_engine_mode", false).apply()
                
                println("🛑 [ForegroundService] Main engine keep-alive mode STOPPED")
                println("   App came to foreground - normal mode resumed")
                
                // Don't stop the service, just update the mode
                updateNotification("📱 App in foreground - monitoring active")
                
                return START_STICKY
            }
            
            ACTION_UPDATE_MAIN_ENGINE_DATA -> {
                // Update notification with latest health data (main engine still running)
                val hr = intent.getIntExtra("heartRate", -1)
                val sp = intent.getIntExtra("spo2", -1)
                val temp = intent.getDoubleExtra("temperature", -1.0)
                val batt = intent.getIntExtra("batteryLevel", -1)
                
                if (hr != -1) heartRate = hr
                if (sp != -1) spo2 = sp
                if (temp != -1.0) temperature = temp
                if (batt != -1) batteryLevel = batt
                
                lastDataUpdateTime = System.currentTimeMillis()
                
                if (heartRate != null && heartRate!! > 0) {
                    updateNotification("💓 $heartRate BPM | 🩸 $spo2% | 🌡️ $temperature°C | 🔋 $batteryLevel% (Background)")
                }
                
                return START_STICKY
            }
            // ==================== END MAIN ENGINE MODE ====================
            
            ACTION_UPDATE_HEALTH_DATA -> {
                // Update health data from Flutter (legacy mode)
                val deviceId = intent.getStringExtra("deviceId")
                val hr = intent.getIntExtra("heartRate", -1)
                val sp = intent.getIntExtra("spo2", -1)
                val temp = intent.getDoubleExtra("temperature", -1.0)
                val batt = intent.getIntExtra("batteryLevel", -1)
                val bpSys = intent.getIntExtra("bpSystolic", -1)
                val bpDia = intent.getIntExtra("bpDiastolic", -1)
                val st = intent.getIntExtra("steps", -1)
                
                if (hr != -1) heartRate = hr
                if (sp != -1) spo2 = sp
                if (temp != -1.0) temperature = temp
                if (batt != -1) batteryLevel = batt
                
                // Track last update time for freshness check
                lastDataUpdateTime = System.currentTimeMillis()
                
                println("📊 [ForegroundService] Health data updated from Flutter: HR=$heartRate SpO2=$spo2 Temp=$temperature Batt=$batteryLevel")
                updateNotification("💓 $heartRate BPM | 🩸 $spo2% | 🌡️ $temperature°C | 🔋 $batteryLevel%")
                
                return START_STICKY
            }
            ACTION_START_SERVICE -> {
                // Get device info from intent
                deviceMacAddress = intent.getStringExtra(EXTRA_DEVICE_ADDRESS)
                userPhone = intent.getStringExtra(EXTRA_USER_PHONE)
                
                // Save to SharedPreferences so HeadlessFlutter can access them
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    if (deviceMacAddress != null) {
                        putString("flutter.last_connected_device_id", deviceMacAddress)
                    }
                    if (userPhone != null) {
                        putString("flutter.user_phone", userPhone)
                    }
                    apply()
                }
                
                println("🚀 [ForegroundService] Service started for device: $deviceMacAddress")
                println("   Flutter handles BLE connection - Native service handles webhooks")
                updateNotification("Monitoring device: $deviceMacAddress")
                
                // Start periodic webhook sender (Flutter will provide data)
                startPeriodicWebhook()
                
                // Start headless Flutter engine as backup for when UI is closed
                // This keeps HC20 SDK running in background
                startHeadlessFlutter()
                
                println("✅ [ForegroundService] Webhook sender started - waiting for data from Flutter")
            }
        }
        
        // START_STICKY ensures service is restarted if killed by system
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    /**
     * Called when user swipes away app from recent apps
     * 
     * CRITICAL FIX: When app is swiped away, the Flutter engine attached to MainActivity
     * IS DESTROYED - ForegroundService cannot prevent that!
     * 
     * NEW APPROACH: Start NativeHC20Service (Pure Kotlin BLE) instead of HeadlessFlutter
     * NativeHC20Service doesn't need Flutter engine at all!
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        println("⚠️⚠️⚠️ [ForegroundService] APP SWIPED AWAY - Main Flutter Engine is DYING! ⚠️⚠️⚠️")
        
        // Get saved device info from SharedPreferences
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val savedDeviceId = prefs.getString("flutter.last_connected_device_id", null)
        val savedPhone = prefs.getString("flutter.user_phone", null)
        val wasMainEngineMode = prefs.getBoolean("is_main_engine_mode", false) || isMainEngineMode
        
        println("   Device: $savedDeviceId")
        println("   Phone: $savedPhone")
        println("   Was Main Engine Mode: $wasMainEngineMode")
        
        // NEW: Start NativeHC20Service (Pure Kotlin BLE) - NO FLUTTER NEEDED!
        // This is the ONLY approach that truly works when app is swiped away.
        println("🚀🚀🚀 [ForegroundService] Starting NativeHC20Service (Pure Kotlin BLE)! 🚀🚀🚀")
        println("   This service uses NATIVE Kotlin BLE - no Flutter engine needed!")
        
        if (!NativeHC20Service.isRunning()) {
            println("   🔄 NativeHC20Service not running - starting now!")
            NativeHC20Service.start(applicationContext, savedDeviceId, savedPhone)
            println("   ✅ NativeHC20Service started!")
        } else {
            println("   ✅ NativeHC20Service already running - will continue HC20 monitoring")
        }
        
        // Update notification to show we're in native mode
        updateNotification("📡 HC20 monitoring via Native Kotlin BLE...")
        
        // Schedule restart using AlarmManager with device info as safety net
        val restartServiceIntent = Intent(applicationContext, ForegroundService::class.java).apply {
            action = ACTION_START_SERVICE  // Use normal service mode
            setPackage(packageName)
            putExtra(EXTRA_DEVICE_ADDRESS, savedDeviceId ?: deviceMacAddress)
            putExtra(EXTRA_USER_PHONE, savedPhone ?: userPhone)
        }
        
        val restartServicePendingIntent = PendingIntent.getService(
            applicationContext,
            1,
            restartServiceIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        alarmManager.setExactAndAllowWhileIdle(
            android.app.AlarmManager.ELAPSED_REALTIME_WAKEUP,
            android.os.SystemClock.elapsedRealtime() + 1000, // 1 second
            restartServicePendingIntent
        )
        
        println("✅ [ForegroundService] Restart scheduled in 1 second with device: $savedDeviceId")
        println("   isMainEngineMode: $isMainEngineMode")
        super.onTaskRemoved(rootIntent)
    }
    
    override fun onDestroy() {
        println("⚠️ [ForegroundService] onDestroy called - scheduling restart...")
        println("✅ [ForegroundService] NativeHC20Service runs INDEPENDENTLY - will NOT be affected")
        
        // Get saved device info from SharedPreferences
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val savedDeviceId = prefs.getString("flutter.last_connected_device_id", null)
        val savedPhone = prefs.getString("flutter.user_phone", null)
        
        // Schedule restart before destroying with device info
        val restartServiceIntent = Intent(applicationContext, ForegroundService::class.java).apply {
            action = ACTION_START_SERVICE
            setPackage(packageName)
            putExtra(EXTRA_DEVICE_ADDRESS, savedDeviceId ?: deviceMacAddress)
            putExtra(EXTRA_USER_PHONE, savedPhone ?: userPhone)
        }
        
        val restartServicePendingIntent = PendingIntent.getService(
            applicationContext,
            2,
            restartServiceIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        alarmManager.setExactAndAllowWhileIdle(
            android.app.AlarmManager.ELAPSED_REALTIME_WAKEUP,
            android.os.SystemClock.elapsedRealtime() + 1000, // 1 second
            restartServicePendingIntent
        )
        
        stopBleConnection()
        stopPeriodicWebhook()
        
        // NOTE: Don't stop HeadlessFlutter here!
        // We want it to keep running for HC20 SDK connection
        // The service will restart in 1 second anyway
        // HeadlessFlutterService.stop()  <- Commented out intentionally
        println("   HeadlessFlutter kept running: ${HeadlessFlutterService.isRunning()}")
        
        wakeLock?.release()
        println("🛑 [ForegroundService] Stopped - restart scheduled in 1s")
        super.onDestroy()
    }
    
    // BLE Connection Management
    private fun startBleConnection() {
        // Note: Native service coordination will be added later if needed
        if (deviceMacAddress == null) {
            println("❌ [ForegroundService] No device address provided")
            return
        }
        
        if (isConnecting) {
            println("⚠️ [ForegroundService] Already connecting, skipping")
            return
        }
        
        isConnecting = true
        
        try {
            val device = bluetoothAdapter?.getRemoteDevice(deviceMacAddress)
            if (device == null) {
                println("❌ [ForegroundService] Device not found: $deviceMacAddress")
                scheduleReconnect()
                return
            }
            
            println("🔌 [ForegroundService] Connecting to ${device.address}...")
            bluetoothGatt = device.connectGatt(this, true, gattCallback)
        } catch (e: Exception) {
            println("❌ [ForegroundService] Connection error: ${e.message}")
            isConnecting = false
            scheduleReconnect()
        }
    }
    
    private fun stopBleConnection() {
        reconnectRunnable?.let { handler.removeCallbacks(it) }
        bluetoothGatt?.disconnect()
        bluetoothGatt?.close()
        bluetoothGatt = null
        isConnecting = false
        println("🔌 [ForegroundService] BLE connection stopped")
    }
    
    private fun scheduleReconnect() {
        if (reconnectAttempts >= maxReconnectAttempts) {
            println("❌ [ForegroundService] Max reconnection attempts reached")
            updateNotification("Connection failed - max attempts reached")
            return
        }
        
        reconnectAttempts++
        println("🔄 [ForegroundService] Scheduling reconnect attempt $reconnectAttempts...")
        
        reconnectRunnable = Runnable {
            isConnecting = false
            startBleConnection()
        }
        
        handler.postDelayed(reconnectRunnable!!, RECONNECT_DELAY_MS)
    }
    
    // BLE GATT Callback
    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    println("✅ [ForegroundService] BLE Connected!")
                    isConnecting = false
                    reconnectAttempts = 0
                    updateNotification("Device connected - syncing data...")
                    
                    // Discover services
                    handler.postDelayed({ gatt.discoverServices() }, 1000)
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    println("🔌 [ForegroundService] BLE Disconnected")
                    isConnecting = false
                    updateNotification("Device disconnected - reconnecting...")
                    scheduleReconnect()
                }
            }
        }
        
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                println("✅ [ForegroundService] Services discovered")
                updateNotification("Listening for device data...")
                
                // Enable notifications for health data characteristics
                // Note: You'll need to implement the specific UUID characteristics for HC20 device
                // This is a placeholder - you need the actual HC20 UUIDs
                enableNotifications(gatt)
            }
        }
        
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            // Parse health data from characteristic
            parseHealthData(characteristic)
        }
    }
    
    private fun enableNotifications(gatt: BluetoothGatt) {
        // TODO: Replace with actual HC20 service and characteristic UUIDs
        // This is a placeholder - you need to get the correct UUIDs from HC20 SDK documentation
        
        // Example for heart rate (standard UUID)
        val heartRateServiceUUID = UUID.fromString("0000180D-0000-1000-8000-00805f9b34fb")
        val heartRateCharUUID = UUID.fromString("00002A37-0000-1000-8000-00805f9b34fb")
        
        val service = gatt.getService(heartRateServiceUUID)
        val characteristic = service?.getCharacteristic(heartRateCharUUID)
        
        characteristic?.let {
            gatt.setCharacteristicNotification(it, true)
            
            // Enable notifications via descriptor
            val descriptor = it.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
            descriptor?.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            gatt.writeDescriptor(descriptor)
            
            println("✅ [ForegroundService] Notifications enabled for health data")
        }
    }
    
    private fun parseHealthData(characteristic: BluetoothGattCharacteristic) {
        // Parse the characteristic data
        // This is device-specific - you need HC20's data format
        
        val data = characteristic.value
        if (data != null && data.isNotEmpty()) {
            // Example parsing (replace with actual HC20 format)
            heartRate = data[0].toInt() and 0xFF
            
            println("📊 [ForegroundService] Data received - HR: $heartRate")
            updateNotification("💓 $heartRate BPM | 🩸 $spo2% | 🌡️ $temperature°C")
        }
    }
    
    // Webhook Management
    private fun startPeriodicWebhook() {
        webhookRunnable = object : Runnable {
            override fun run() {
                sendWebhook()
                handler.postDelayed(this, WEBHOOK_INTERVAL_MS)
            }
        }
        handler.post(webhookRunnable!!)
        println("✅ [ForegroundService] Periodic webhook sender started (every ${WEBHOOK_INTERVAL_MS/1000}s)")
    }
    
    private fun stopPeriodicWebhook() {
        webhookRunnable?.let { handler.removeCallbacks(it) }
        println("⏹️ [ForegroundService] Periodic webhook sender stopped")
    }
    
    private fun sendWebhook() {
        println("\n🔔 [NATIVE-SERVICE] === WEBHOOK ATTEMPT (2-min interval) ===")
        println("   Device MAC: $deviceMacAddress")
        println("   User Phone: $userPhone")
        println("   Health Data: HR=$heartRate SpO2=$spo2 Temp=$temperature Batt=$batteryLevel")
        
        if (userPhone == null || deviceMacAddress == null) {
            println("❌ [NATIVE-SERVICE] Missing user/device info for webhook")
            return
        }
        
        // Check data freshness
        val dataAge = if (lastDataUpdateTime > 0) {
            System.currentTimeMillis() - lastDataUpdateTime
        } else {
            -1L
        }
        val isDataFresh = dataAge >= 0 && dataAge < 120000 // Less than 2 minutes old
        
        println("   Data Age: ${if (dataAge >= 0) "${dataAge/1000}s" else "Never received"}")
        println("   Data Freshness: ${if (isDataFresh) "✅ Fresh" else "❌ Stale/None"}")
        
        if (!isDataFresh && heartRate == null) {
            println("⚠️ [NATIVE-SERVICE] WARNING: No fresh data available!")
            println("   Reason: Flutter app is likely closed/stopped")
            println("   Solution: Background Isolate service should take over")
        }
        
        // Check if we have recent data from Flutter
        val hasData = heartRate != null || spo2 != null
        
        // Get HeadlessFlutter status
        val isHeadlessRunning = HeadlessFlutterService.isRunning()
        
        // Format timestamps for readability
        val dateFormat = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", java.util.Locale.getDefault())
        val now = System.currentTimeMillis()
        val readableTimestamp = dateFormat.format(java.util.Date(now))
        val lastFlutterUpdateReadable = if (lastDataUpdateTime > 0) dateFormat.format(java.util.Date(lastDataUpdateTime)) else null
        
        val json = JSONObject().apply {
            put("phone", userPhone)
            put("deviceId", deviceMacAddress)
            put("timestamp", now)
            put("timestampReadable", readableTimestamp)
            put("source", "NATIVE_SERVICE")
            put("method", "android_foreground_service")
            put("interval", "2_minutes")
            put("dataSource", if (hasData) "flutter_realtime" else "no_data_yet")
            put("dataAgeSeconds", if (dataAge >= 0) dataAge / 1000 else -1)
            put("isDataFresh", isDataFresh)
            put("lastFlutterUpdate", if (lastDataUpdateTime > 0) lastDataUpdateTime else null)
            put("lastFlutterUpdateReadable", lastFlutterUpdateReadable)
            put("heartRate", heartRate)
            put("spo2", spo2)
            put("temperature", temperature)
            put("batteryLevel", batteryLevel)
            put("bluetoothStatus", if (bluetoothAdapter?.isEnabled == true) "ON" else "OFF")
            
            // HeadlessFlutter status - explains why live data (webhook 2) may not be coming
            put("headlessFlutterRunning", isHeadlessRunning)
            
            // Build explanation message
            val message = when {
                !hasData && !isHeadlessRunning -> "HeadlessFlutter NOT running - cannot connect to HC20 device for live data. Live data webhook will not be sent."
                !hasData && isHeadlessRunning -> "HeadlessFlutter running but no data yet - HC20 SDK may be connecting. Live data webhook should arrive soon."
                isDataFresh -> "Live data from Flutter (${dataAge/1000}s ago)"
                else -> "Stale data from Flutter (${dataAge/1000}s ago) - app UI closed, HeadlessFlutter running: $isHeadlessRunning"
            }
            put("message", message)
            
            // Add detailed status for debugging
            val liveDataStatus = when {
                !isHeadlessRunning -> "BLOCKED - HeadlessFlutter engine not started"
                !hasData -> "PENDING - HeadlessFlutter started, waiting for HC20 SDK to connect and stream data"
                isDataFresh -> "ACTIVE - Live data flowing"
                else -> "STALE - Last data received ${dataAge/1000}s ago"
            }
            put("liveDataWebhookStatus", liveDataStatus)
        }
        
        val body = json.toString().toRequestBody("application/json".toMediaType())
        val request = Request.Builder()
            .url(WEBHOOK_URL)
            .post(body)
            .build()
        
        webhookClient.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                println("❌ [NATIVE-SERVICE] Webhook failed: ${e.message}")
            }
            
            override fun onResponse(call: Call, response: Response) {
                val dataStatus = when {
                    !hasData -> "📭 No Data"
                    isDataFresh -> "📊 Fresh Data"
                    else -> "⚠️ Stale Data"
                }
                println("✅ [NATIVE-SERVICE] Webhook sent (2-min): ${response.code} - $dataStatus - HR:$heartRate SpO2:$spo2")
                updateNotification("[NATIVE 2-min] $dataStatus - ${java.text.SimpleDateFormat("HH:mm:ss").format(java.util.Date())}")
            }
        })
    }
    
    // Notification Management
    private fun createNotification(status: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("HFC Health Monitor - Active")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)  // Cannot be dismissed
            .setPriority(NotificationCompat.PRIORITY_HIGH)  // Higher priority
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setShowWhen(true)
            .setAutoCancel(false)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }
    
    private fun updateNotification(status: String) {
        val notification = createNotification(status)
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "HFC Background Sync",
                NotificationManager.IMPORTANCE_HIGH  // Higher importance = less likely to be killed
            ).apply {
                description = "Keeps HC20 device connected and syncing health data"
                setShowBadge(true)
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
