package com.example.hfc_app

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Native Kotlin BLE Manager for HC20 devices
 * 
 * This handles all BLE operations WITHOUT Flutter/Dart:
 * - Scanning for HC20 devices
 * - Connecting to HC20
 * - Enabling notifications
 * - Parsing HC20 protocol frames
 * - Callback for real-time health data
 * 
 * Key advantage: Works even when Flutter engine is dead (app swiped away)
 */
@SuppressLint("MissingPermission")
class HC20NativeBleManager(private val context: Context) {
    
    companion object {
        private const val TAG = "HC20NativeBLE"
        private const val SCAN_TIMEOUT_MS = 30000L // 30 seconds
        private const val CONNECTION_TIMEOUT_MS = 15000L // 15 seconds
        private const val RECONNECT_DELAY_MS = 5000L // 5 seconds
        private const val MAX_RECONNECT_ATTEMPTS = 10
        private const val SERVICE_DISCOVERY_DELAY_MS = 2000L // Wait before discovering services
    }
    
    // Bluetooth components
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.adapter
    private var bleScanner: BluetoothLeScanner? = null
    private var bluetoothGatt: BluetoothGatt? = null
    
    // State tracking
    private val isScanning = AtomicBoolean(false)
    private val isConnecting = AtomicBoolean(false)
    private val isConnected = AtomicBoolean(false)
    private var reconnectAttempts = 0
    
    // Handlers for timeouts and delays
    private val mainHandler = Handler(Looper.getMainLooper())
    
    // Data buffer for incomplete frames
    private val dataBuffer = mutableListOf<Byte>()
    
    // Device info
    private var connectedDeviceId: String? = null
    private var connectedDeviceMac: String? = null
    private var connectedDeviceName: String? = null
    private var deviceInfo: HC20Protocol.DeviceInfo? = null
    
    // Callbacks
    private var onDeviceFound: ((String, String) -> Unit)? = null // (deviceId, deviceName)
    private var onConnected: ((String) -> Unit)? = null
    private var onDisconnected: (() -> Unit)? = null
    private var onRealtimeData: ((HC20Protocol.RealtimeData) -> Unit)? = null
    private var onDeviceInfo: ((HC20Protocol.DeviceInfo) -> Unit)? = null
    private var onError: ((String) -> Unit)? = null
    
    // Known devices from scan
    private val foundDevices = ConcurrentHashMap<String, String>() // id -> name
    
    // Full data tracking
    private var hasReceivedFullData = false
    private var hasReceivedInitialData = false
    private var sensorEnableAttempts = 0
    private var sensorEnableRunnable: Runnable? = null
    private val commandQueue = mutableListOf<ByteArray>()
    private var isProcessingCommand = false
    
    // Scan callback
    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            processScanResult(result)
        }
        
        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            results.forEach { processScanResult(it) }
        }
        
        override fun onScanFailed(errorCode: Int) {
            Log.e(TAG, "❌ BLE Scan failed: errorCode=$errorCode")
            isScanning.set(false)
            onError?.invoke("BLE scan failed with error: $errorCode")
        }
    }
    
    // GATT callback for connection and data
    private val gattCallback = object : BluetoothGattCallback() {
        
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            val deviceId = gatt.device?.address ?: "unknown"
            
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.d(TAG, "✅ Connected to $deviceId (status=$status)")
                    isConnecting.set(false)
                    isConnected.set(true)
                    reconnectAttempts = 0
                    connectedDeviceId = deviceId
                    hasReceivedInitialData = false
                    
                    // Wait before discovering services (HC20 needs time to initialize)
                    mainHandler.postDelayed({
                        Log.d(TAG, "🔍 Discovering services...")
                        gatt.discoverServices()
                    }, SERVICE_DISCOVERY_DELAY_MS)
                    
                    mainHandler.post { onConnected?.invoke(deviceId) }
                }
                
                BluetoothProfile.STATE_DISCONNECTED -> {
                    Log.d(TAG, "🔌 Disconnected from $deviceId (status=$status)")
                    isConnecting.set(false)
                    isConnected.set(false)
                    
                    // Clear device info and cached data to prevent stale data
                    connectedDeviceName = null
                    deviceInfo = null
                    bluetoothGatt?.close()
                    bluetoothGatt = null
                    
                    mainHandler.post { onDisconnected?.invoke() }
                    
                    // Schedule reconnection
                    scheduleReconnect()
                }
            }
        }
        
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                Log.d(TAG, "✅ Services discovered!")
                
                // Log all services for debugging
                gatt.services.forEach { service ->
                    Log.d(TAG, "   Service: ${service.uuid}")
                    service.characteristics.forEach { char ->
                        Log.d(TAG, "     Char: ${char.uuid} props=${char.properties}")
                    }
                }
                
                // Find HC20 service (FFF0)
                val hc20Service = gatt.getService(UUID.fromString(HC20Protocol.SERVICE_FFF0))
                if (hc20Service != null) {
                    Log.d(TAG, "✅ Found HC20 service (FFF0)")
                    
                    // Enable notifications on FFF1 (receive data)
                    val notifyChar = hc20Service.getCharacteristic(UUID.fromString(HC20Protocol.CHAR_FFF1))
                    if (notifyChar != null) {
                        enableNotifications(gatt, notifyChar)
                    } else {
                        Log.e(TAG, "❌ FFF1 characteristic not found")
                    }
                } else {
                    Log.e(TAG, "❌ HC20 service (FFF0) not found")
                    onError?.invoke("HC20 service not found on device")
                }
            } else {
                Log.e(TAG, "❌ Service discovery failed: status=$status")
                onError?.invoke("Service discovery failed: $status")
            }
        }
        
        @Deprecated("Deprecated in Java")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            val data = characteristic.value ?: return
            handleNotificationData(data)
        }
        
        // Android 13+ version
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            handleNotificationData(value)
        }
        
        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                Log.d(TAG, "✅ Notifications enabled for ${descriptor.characteristic.uuid}")
                
                // After enabling notifications, send initialization commands
                mainHandler.postDelayed({
                    sendInitializationCommands()
                }, 1000)
            } else {
                Log.e(TAG, "❌ Failed to enable notifications: status=$status")
            }
        }
        
        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                Log.d(TAG, "✅✅ DEVICE CONFIRMED: Command received successfully")
                Log.d(TAG, "✅✅ Characteristic: ${characteristic.uuid}")
            } else {
                Log.e(TAG, "❌❌ DEVICE REJECTED: Command write failed!")
                Log.e(TAG, "❌❌ Status code: $status")
                Log.e(TAG, "❌❌ Characteristic: ${characteristic.uuid}")
                Log.e(TAG, "❌❌ This means device did NOT accept the command")
            }
        }
    }
    
    /**
     * Set callbacks for events
     */
    fun setCallbacks(
        onDeviceFound: ((String, String) -> Unit)? = null,
        onConnected: ((String) -> Unit)? = null,
        onDisconnected: (() -> Unit)? = null,
        onRealtimeData: ((HC20Protocol.RealtimeData) -> Unit)? = null,
        onDeviceInfo: ((HC20Protocol.DeviceInfo) -> Unit)? = null,
        onError: ((String) -> Unit)? = null
    ) {
        this.onDeviceFound = onDeviceFound
        this.onConnected = onConnected
        this.onDisconnected = onDisconnected
        this.onRealtimeData = onRealtimeData
        this.onDeviceInfo = onDeviceInfo
        this.onError = onError
    }
    
    /**
     * Check if BLE permissions are granted
     */
    fun hasPermissions(): Boolean {
        val hasConnect = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else true
        
        val hasScan = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
        } else true
        
        val hasLocation = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        
        Log.d(TAG, "Permissions: CONNECT=$hasConnect SCAN=$hasScan LOCATION=$hasLocation")
        return hasConnect && hasScan && hasLocation
    }
    
    /**
     * Check if Bluetooth is enabled
     */
    fun isBluetoothEnabled(): Boolean = bluetoothAdapter?.isEnabled == true
    
    /**
     * Start scanning for HC20 devices
     */
    fun startScan(targetDeviceId: String? = null) {
        if (!hasPermissions()) {
            Log.e(TAG, "❌ Missing BLE permissions")
            onError?.invoke("Missing BLE permissions")
            return
        }
        
        if (!isBluetoothEnabled()) {
            Log.e(TAG, "❌ Bluetooth is disabled")
            onError?.invoke("Bluetooth is disabled")
            return
        }
        
        if (isScanning.get()) {
            Log.w(TAG, "⚠️ Already scanning")
            return
        }
        
        Log.d(TAG, "🔍 Starting BLE scan for HC20 devices...")
        if (targetDeviceId != null) {
            Log.d(TAG, "   Target device: $targetDeviceId")
        }
        
        foundDevices.clear()
        bleScanner = bluetoothAdapter?.bluetoothLeScanner
        
        if (bleScanner == null) {
            Log.e(TAG, "❌ BLE Scanner not available")
            onError?.invoke("BLE Scanner not available")
            return
        }
        
        // Configure scan settings for low latency
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
            .build()
        
        // No service filter - scan all devices and filter by manufacturer data
        isScanning.set(true)
        bleScanner?.startScan(null, settings, scanCallback)
        
        Log.d(TAG, "✅ Scan started")
        
        // Schedule scan timeout
        mainHandler.postDelayed({
            if (isScanning.get()) {
                stopScan()
                Log.w(TAG, "⚠️ Scan timeout - no HC20 devices found")
                
                // If we had a target device, try to connect directly
                if (targetDeviceId != null) {
                    Log.d(TAG, "🔄 Trying direct connection to $targetDeviceId")
                    connectDirectly(targetDeviceId)
                }
            }
        }, SCAN_TIMEOUT_MS)
    }
    
    /**
     * Stop scanning
     */
    fun stopScan() {
        if (isScanning.compareAndSet(true, false)) {
            try {
                bleScanner?.stopScan(scanCallback)
                Log.d(TAG, "⏹️ Scan stopped")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping scan: ${e.message}")
            }
        }
    }
    
    /**
     * Process a scan result
     */
    private fun processScanResult(result: ScanResult) {
        val device = result.device
        val deviceId = device.address
        val deviceName = device.name ?: ""
        
        // Check if this is an HC20 device
        val scanRecord = result.scanRecord
        val manufacturerData = scanRecord?.bytes ?: ByteArray(0)
        
        val isHC20ByMfr = HC20Protocol.isHC20ManufacturerData(manufacturerData)
        val isHC20ByName = HC20Protocol.isHC20DeviceName(deviceName)
        val hasHC20Service = scanRecord?.serviceUuids?.any { 
            it.uuid.toString().uppercase() == HC20Protocol.SERVICE_FFF0.uppercase()
        } == true
        
        if (isHC20ByMfr || isHC20ByName || hasHC20Service) {
            if (!foundDevices.containsKey(deviceId)) {
                foundDevices[deviceId] = deviceName
                Log.d(TAG, "🎯 Found HC20 device: $deviceName ($deviceId)")
                Log.d(TAG, "   Match: mfr=$isHC20ByMfr name=$isHC20ByName service=$hasHC20Service")
                
                mainHandler.post { onDeviceFound?.invoke(deviceId, deviceName) }
            }
        }
    }
    
    /**
     * Connect to a device by ID (scan first if needed)
     */
    fun connect(deviceId: String) {
        if (!hasPermissions()) {
            onError?.invoke("Missing BLE permissions")
            return
        }
        
        if (!isBluetoothEnabled()) {
            onError?.invoke("Bluetooth is disabled")
            return
        }
        
        if (isConnected.get() && connectedDeviceId == deviceId) {
            Log.d(TAG, "✅ Already connected to $deviceId")
            return
        }
        
        // First check if device is bonded
        val bondedDevice = bluetoothAdapter?.bondedDevices?.find { it.address == deviceId }
        if (bondedDevice != null) {
            Log.d(TAG, "📱 Found bonded device: $deviceId")
            connectToDevice(bondedDevice)
            return
        }
        
        // Start scan to find the device
        Log.d(TAG, "🔍 Scanning for device: $deviceId")
        
        // Set up a callback to connect when found
        val previousCallback = onDeviceFound
        onDeviceFound = { foundId, foundName ->
            previousCallback?.invoke(foundId, foundName)
            if (foundId == deviceId) {
                Log.d(TAG, "✅ Target device found! Connecting...")
                stopScan()
                
                val device = bluetoothAdapter?.getRemoteDevice(deviceId)
                if (device != null) {
                    connectToDevice(device)
                }
            }
        }
        
        startScan(deviceId)
    }
    
    /**
     * Try to connect directly without scanning
     */
    private fun connectDirectly(deviceId: String) {
        try {
            val device = bluetoothAdapter?.getRemoteDevice(deviceId)
            if (device != null) {
                connectToDevice(device)
            } else {
                onError?.invoke("Cannot find device: $deviceId")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error connecting directly: ${e.message}")
            onError?.invoke("Connection error: ${e.message}")
        }
    }
    
    /**
     * Connect to a specific BluetoothDevice
     */
    private fun connectToDevice(device: BluetoothDevice) {
        if (isConnecting.get()) {
            Log.w(TAG, "⚠️ Already connecting")
            return
        }
        
        stopScan()
        disconnect()
        
        Log.d(TAG, "🔌 Connecting to ${device.address}...")
        isConnecting.set(true)
        
        // Store device name early
        device.name?.let { name ->
            if (name.isNotEmpty()) {
                connectedDeviceName = name
            }
        }
        
        // Use TRANSPORT_LE for BLE devices
        bluetoothGatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(context, false, gattCallback)
        }
        
        // Schedule connection timeout
        mainHandler.postDelayed({
            if (isConnecting.get() && !isConnected.get()) {
                Log.e(TAG, "❌ Connection timeout")
                disconnect()
                scheduleReconnect()
            }
        }, CONNECTION_TIMEOUT_MS)
    }
    
    /**
     * Disconnect from current device
     */
    fun disconnect() {
        isConnecting.set(false)
        isConnected.set(false)
        
        bluetoothGatt?.let { gatt ->
            try {
                gatt.disconnect()
                gatt.close()
            } catch (e: Exception) {
                Log.e(TAG, "Error disconnecting: ${e.message}")
            }
        }
        bluetoothGatt = null
        dataBuffer.clear()
    }
    
    /**
     * Enable notifications on a characteristic
     */
    private fun enableNotifications(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
        gatt.setCharacteristicNotification(characteristic, true)
        
        val descriptor = characteristic.getDescriptor(UUID.fromString(HC20Protocol.CCCD_UUID))
        if (descriptor != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeDescriptor(descriptor, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            } else {
                @Suppress("DEPRECATION")
                descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                @Suppress("DEPRECATION")
                gatt.writeDescriptor(descriptor)
            }
            Log.d(TAG, "📝 Enabling notifications for ${characteristic.uuid}")
        } else {
            Log.e(TAG, "❌ CCCD descriptor not found")
        }
    }
    
    /**
     * Send initialization commands after connection
     * MINIMAL TEST: Send HRV2-only command immediately and repeatedly
     */
    private fun sendInitializationCommands() {
        Log.d(TAG, "\n📤 ====== MINIMAL TEST MODE: HRV2 ONLY ======")
        Log.d(TAG, "📤 Goal: Test if device CAN send data when app is closed")
        Log.d(TAG, "📤 Focus: ONLY hrv2_metrics data")
        
        hasReceivedFullData = false
        hasReceivedInitialData = false
        sensorEnableAttempts = 0
        
        // 1. Set time immediately (device needs this)
        Log.d(TAG, "📤 [Step 1] Setting device time...")
        val timestamp = System.currentTimeMillis() / 1000
        queueCommand(HC20Protocol.createSetTimeCommand(timestamp))
        
        // 2. Start aggressive HRV2 enable loop immediately
        mainHandler.postDelayed({
            Log.d(TAG, "📤 [Step 2] Starting aggressive HRV2 enable loop...")
            startPersistentSensorEnable()
        }, 1000)
    }
    
    /**
     * Send HRV2-only command persistently until we get data
     * MINIMAL TEST: Focus ONLY on hrv2_metrics
     */
    private fun startPersistentSensorEnable() {
        // Cancel any existing loop
        sensorEnableRunnable?.let { mainHandler.removeCallbacks(it) }
        
        Log.d(TAG, "\n🔄 ====== AGGRESSIVE HRV2 ENABLE LOOP ======")
        Log.d(TAG, "🔄 Sending HRV2-ONLY command every 3 seconds")
        Log.d(TAG, "🔄 This will run INDEFINITELY until we get HRV2 data")
        
        sensorEnableRunnable = object : Runnable {
            override fun run() {
                sensorEnableAttempts++
                Log.d(TAG, "\n📤 ====== HRV2 ENABLE ATTEMPT #$sensorEnableAttempts ======")
                
                val command = HC20Protocol.createEnableHrv2OnlyCommand()
                Log.d(TAG, "📤 Creating HRV2-ONLY command...")
                Log.d(TAG, "📤 Command hex: ${command.joinToString(" ") { "%02X".format(it) }}")
                Log.d(TAG, "📤 Command size: ${command.size} bytes")
                Log.d(TAG, "📤 Queuing for transmission...")
                
                queueCommand(command)
                
                Log.d(TAG, "📤 Waiting for device response...")
                
                if (hasReceivedFullData) {
                    Log.d(TAG, "✅✅✅ HRV2 DATA RECEIVED - Test successful!")
                    // Don't stop - keep sending to ensure continuous data
                }
                
                // Send again in 3 seconds (aggressive)
                mainHandler.postDelayed(this, 3000)
            }
        }
        
        // Start immediately
        mainHandler.post(sensorEnableRunnable!!)
    }
    
    /**
     * Mark that we've received full data (called from onRealtimeData callback)
     */
    fun markFullDataReceived() {
        if (!hasReceivedFullData) {
            hasReceivedFullData = true
            Log.d(TAG, "✅✅✅ FULL DATA MODE CONFIRMED - device is now sending complete data!")
        }
    }
    
    /**
     * Queue a command to prevent conflicts and ensure sequential execution
     */
    private fun queueCommand(data: ByteArray) {
        synchronized(commandQueue) {
            commandQueue.add(data)
            Log.d(TAG, "📝 Command queued (${commandQueue.size} in queue)")
        }
        processCommandQueue()
    }
    
    /**
     * Process command queue sequentially
     */
    private fun processCommandQueue() {
        if (isProcessingCommand) {
            return
        }
        
        val command = synchronized(commandQueue) {
            if (commandQueue.isEmpty()) return
            commandQueue.removeAt(0)
        }
        
        isProcessingCommand = true
        sendCommandInternal(command)
        
        // Wait 1 second before processing next command
        mainHandler.postDelayed({
            isProcessingCommand = false
            processCommandQueue()
        }, 1000)
    }
    
    /**
     * Send a command to the device (internal)
     */
    private fun sendCommandInternal(data: ByteArray): Boolean {
        val gatt = bluetoothGatt ?: run {
            Log.e(TAG, "❌ Cannot send command: GATT is null")
            return false
        }
        
        val service = gatt.getService(UUID.fromString(HC20Protocol.SERVICE_FFF0)) ?: run {
            Log.e(TAG, "❌ Cannot send command: Service FFF0 not found")
            return false
        }
        
        val writeChar = service.getCharacteristic(UUID.fromString(HC20Protocol.CHAR_FFF2)) ?: run {
            Log.e(TAG, "❌ Cannot send command: Characteristic FFF2 not found")
            return false
        }
        
        Log.d(TAG, "📤 SENDING COMMAND TO DEVICE:")
        Log.d(TAG, "📤   Hex: ${HC20Protocol.bytesToHex(data)}")
        Log.d(TAG, "📤   Size: ${data.size} bytes")
        Log.d(TAG, "📤   To: FFF2 characteristic")
        
        val success = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val status = gatt.writeCharacteristic(writeChar, data, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)
            status == BluetoothStatusCodes.SUCCESS
        } else {
            @Suppress("DEPRECATION")
            writeChar.value = data
            @Suppress("DEPRECATION")
            gatt.writeCharacteristic(writeChar)
        }
        
        if (success) {
            Log.d(TAG, "✅ Command write initiated successfully")
        } else {
            Log.e(TAG, "❌ Command write FAILED")
        }
        
        return success
    }
    
    /**
     * Handle incoming notification data
     */
    private fun handleNotificationData(data: ByteArray) {
        Log.d(TAG, "\n📥 ====== DATA RECEIVED FROM DEVICE ======")
        Log.d(TAG, "📥 Size: ${data.size} bytes")
        Log.d(TAG, "📥 Hex: ${HC20Protocol.bytesToHex(data)}")
        
        // Add to buffer
        synchronized(dataBuffer) {
            dataBuffer.addAll(data.toList())
            
            // Try to decode frames
            val buffer = dataBuffer.toByteArray()
            val result = HC20Protocol.decode(buffer)
            
            if (result.frames.isNotEmpty()) {
                // Remove consumed bytes
                repeat(result.consumedBytes) {
                    if (dataBuffer.isNotEmpty()) dataBuffer.removeAt(0)
                }
                
                // Process frames
                result.frames.forEach { frame ->
                    processFrame(frame)
                }
            }
            
            // Prevent buffer from growing too large
            if (dataBuffer.size > 4096) {
                Log.w(TAG, "⚠️ Buffer too large, clearing")
                dataBuffer.clear()
            }
        }
    }
    
    /**
     * Process a decoded HC20 frame
     */
    private fun processFrame(frame: HC20Protocol.HC20Frame) {
        Log.d(TAG, "🔢 Frame: func=0x${frame.func.toString(16)} len=${frame.payload.size}")
        
        when (frame.func) {
            HC20Protocol.RESP_DEVICE_INFO.toInt() and 0xFF -> {
                val info = HC20Protocol.parseDeviceInfo(frame)
                if (info != null) {
                    deviceInfo = info
                    connectedDeviceMac = info.mac
                    connectedDeviceName = info.name
                    Log.d(TAG, "📱 Device Info: ${info.name} (${info.mac}) v${info.version}")
                    mainHandler.post { onDeviceInfo?.invoke(info) }
                }
            }
            
            HC20Protocol.RESP_REALTIME_V2.toInt() and 0xFF -> {
                val data = HC20Protocol.parseRealtimeV2(frame)
                if (data != null) {
                    // Check for HRV2 data (our test target)
                    val hasHrv2 = data.hrv2 != null
                    
                    if (hasHrv2) {
                        markFullDataReceived()
                        Log.d(TAG, "\n✅✅✅ HRV2 DATA RECEIVED! ✅✅✅")
                        Log.d(TAG, "✅ HRV2 raw: ${data.hrv2}")
                        Log.d(TAG, "✅ HRV2 metrics: ${data.hrv2Metrics}")
                        Log.d(TAG, "✅ HR=${data.heartRate} Batt=${data.batteryPercent}%")
                        Log.d(TAG, "✅ TEST SUCCESSFUL - Device CAN send data when app closed!")
                    } else {
                        Log.d(TAG, "📥 Data packet: HR=${data.heartRate} Batt=${data.batteryPercent}% (HRV2: waiting...)")
                        Log.d(TAG, "📥 Attempt #$sensorEnableAttempts - keep sending enable command...")
                    }
                    
                    mainHandler.post { onRealtimeData?.invoke(data) }
                }
            }
            
            else -> {
                Log.d(TAG, "📦 Other frame type: 0x${frame.func.toString(16)}")
            }
        }
    }
    
    /**
     * Schedule reconnection attempt
     */
    private fun scheduleReconnect() {
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            Log.e(TAG, "❌ Max reconnect attempts reached")
            onError?.invoke("Max reconnect attempts reached")
            return
        }
        
        reconnectAttempts++
        val delay = RECONNECT_DELAY_MS * reconnectAttempts // Exponential backoff
        
        Log.d(TAG, "🔄 Scheduling reconnect attempt $reconnectAttempts in ${delay}ms")
        
        mainHandler.postDelayed({
            connectedDeviceId?.let { deviceId ->
                Log.d(TAG, "🔄 Reconnect attempt $reconnectAttempts to $deviceId")
                connect(deviceId)
            }
        }, delay)
    }
    
    /**
     * Force reconnection now
     */
    fun forceReconnect() {
        reconnectAttempts = 0
        connectedDeviceId?.let { connect(it) }
    }
    
    /**
     * Get connection status
     */
    fun isConnected(): Boolean = isConnected.get()
    
    /**
     * Get the connected device MAC address
     */
    fun getConnectedDeviceMac(): String? = connectedDeviceMac
    
    /**
     * Get the connected device name
     */
    fun getConnectedDeviceName(): String? = connectedDeviceName ?: deviceInfo?.name
    
    /**
     * Get device info
     */
    fun getDeviceInfo(): HC20Protocol.DeviceInfo? = deviceInfo
    
    /**
     * Clean up resources
     */
    fun destroy() {
        mainHandler.removeCallbacksAndMessages(null)
        stopScan()
        disconnect()
        onDeviceFound = null
        onConnected = null
        onDisconnected = null
        onRealtimeData = null
        onDeviceInfo = null
        onError = null
    }
}
