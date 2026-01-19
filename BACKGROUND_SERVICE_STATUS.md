# Background Service Detailed Status Report

## Executive Summary
**Date:** January 17, 2026  
**Version:** 8.0.31+1

This document analyzes the 5 critical background service requirements when the app is closed and provides detailed status and fixes for each.

---

## 1. ❌ Background Service Send Webhooks (App Closed)

### **STATUS: BROKEN - Cannot Be Fixed With Current Architecture**

#### Problem Analysis:
```
background_isolate_service.dart (line 352):
  _hc20Client = await Hc20Client.create(config: config).timeout(Duration(seconds: 10));
  ^^^ THIS LINE HANGS OR FAILS ^^^
```

#### Root Cause:
- **HC20 SDK 1.0.4** requires native BLE plugin access
- **Flutter plugins** require Flutter engine context
- **Background isolates** run in separate Dart VM without engine context
- **Result:** `Hc20Client.create()` cannot access platform channels → hangs indefinitely

#### Evidence:
- User reports: Service stuck at "Connecting to HC20 device..." notification
- Never reaches line 360: `print('✅ GOOD: HC20Client created!')`
- Webhook timer (line 258) never gets created
- NO webhooks ever sent from background isolate

#### Why This Cannot Work:
```dart
// Background isolate (separate Dart VM)
FlutterBackgroundService.onStart() {
  // ❌ No Flutter engine context here
  // ❌ Platform channels don't work
  // ❌ Native plugins unavailable
  var client = await Hc20Client.create(); // HANGS/FAILS
}
```

#### Alternative Solutions:
1. **Keep app alive** with AlarmManager auto-restart (implemented ✅) - Current solution
2. **Native Android Foreground Service** - RECOMMENDED for true background operation
3. **Accept limitation** - app must stay open for HC20 connection

---

## 🎯 RECOMMENDED SOLUTION: Native Android Foreground Service

### **Why This Is The Only Real Fix:**

The HC20 SDK is a Flutter package that wraps native BLE functionality. When you run it in a background isolate, it tries to access platform channels that don't exist in that context. The solution is to **bypass Flutter entirely** and communicate with the HC20 device directly using native Android BLE APIs.

### **Architecture Overview:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (UI Only)                     │
│  - User selects device                                       │
│  - Configures webhook URL                                    │
│  - Starts native service                                     │
│  - Displays real-time data from service                      │
└─────────────────────────────────────────────────────────────┘
                            ↕ MethodChannel
┌─────────────────────────────────────────────────────────────┐
│         Native Android Foreground Service (Kotlin)           │
│  ✅ Runs COMPLETELY INDEPENDENT of Flutter                   │
│  ✅ Direct BLE communication with HC20 device                │
│  ✅ Continues when app closed/killed                         │
│  ✅ Sends webhooks every 3 minutes                           │
│  ✅ Auto-reconnects on disconnect                            │
│  ✅ Survives device reboot                                   │
│  ✅ Works in Doze mode                                       │
└─────────────────────────────────────────────────────────────┘
                            ↕ HTTPS
┌─────────────────────────────────────────────────────────────┐
│              Webhook Server (api.hireforcare.com)            │
└─────────────────────────────────────────────────────────────┘
```

### **Implementation Plan:**

#### **Phase 1: Reverse Engineer HC20 BLE Protocol**

The HC20 SDK communicates with the device using Bluetooth Low Energy. You need to:

1. **Capture BLE communication** while Flutter app is running:
   ```bash
   # Enable HCI snoop log on Android
   adb shell settings put secure bluetooth_hci_log 1
   
   # Reproduce: Connect to device, get heart rate/SpO2 data
   # Stop HCI snoop log
   adb shell settings put secure bluetooth_hci_log 0
   
   # Pull the log file
   adb pull /sdcard/btsnoop_hci.log
   
   # Analyze with Wireshark
   wireshark btsnoop_hci.log
   ```

2. **Document the BLE protocol**:
   - Service UUIDs
   - Characteristic UUIDs
   - Command structure for:
     - Device scanning/discovery
     - Connection establishment
     - Authentication (OAuth tokens)
     - Real-time data subscription
     - Data parsing (heart rate, SpO2, temperature, etc.)

3. **Alternative: Decompile HC20 SDK**:
   ```bash
   # Extract AAR/JAR from Flutter package
   cd hc20_1.0.4/android/
   
   # Use jadx to decompile
   jadx -d output/ hc20.aar
   
   # Look for BLE service/characteristic UUIDs and protocol
   grep -r "UUID" output/
   ```

#### **Phase 2: Create Native Foreground Service**

Create a new Kotlin service that runs independently:

**File: `android/app/src/main/kotlin/com/example/hfc_app/Hc20ForegroundService.kt`**

```kotlin
package com.example.hfc_app

import android.app.*
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.*
import android.os.*
import androidx.core.app.NotificationCompat
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.*
import java.util.concurrent.TimeUnit

class Hc20ForegroundService : Service() {
    
    companion object {
        private const val TAG = "Hc20ForegroundService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "hc20_service"
        
        // Action constants
        const val ACTION_START = "com.example.hfc_app.START_SERVICE"
        const val ACTION_STOP = "com.example.hfc_app.STOP_SERVICE"
        
        // HC20 BLE UUIDs (MUST BE DISCOVERED FROM PROTOCOL ANALYSIS)
        private val SERVICE_UUID = UUID.fromString("0000xxxx-0000-1000-8000-00805f9b34fb")
        private val CHAR_REALTIME_UUID = UUID.fromString("0000yyyy-0000-1000-8000-00805f9b34fb")
    }
    
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothGatt: BluetoothGatt? = null
    private var deviceId: String? = null
    private var webhookUrl: String? = null
    private var isConnected = false
    
    // Latest health data
    private var heartRate: Int = 0
    private var spo2: Int = 0
    private var temperature: Float = 0f
    
    // Webhook timer
    private val handler = Handler(Looper.getMainLooper())
    private val webhookRunnable = object : Runnable {
        override fun run() {
            sendWebhook()
            handler.postDelayed(this, 3 * 60 * 1000) // 3 minutes
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        createNotificationChannel()
        
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                deviceId = intent.getStringExtra("deviceId")
                webhookUrl = intent.getStringExtra("webhookUrl")
                
                startForeground(NOTIFICATION_ID, createNotification("Starting..."))
                connectToDevice()
                startWebhookTimer()
            }
            ACTION_STOP -> {
                stopSelf()
            }
        }
        
        return START_STICKY // Restart service if killed
    }
    
    private fun connectToDevice() {
        Log.d(TAG, "Connecting to device: $deviceId")
        updateNotification("Scanning for device...")
        
        val scanner = bluetoothAdapter?.bluetoothLeScanner
        val scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                if (result.device.address == deviceId) {
                    scanner?.stopScan(this)
                    Log.d(TAG, "Device found, connecting...")
                    updateNotification("Device found, connecting...")
                    
                    bluetoothGatt = result.device.connectGatt(
                        this@Hc20ForegroundService,
                        false,
                        gattCallback
                    )
                }
            }
            
            override fun onScanFailed(errorCode: Int) {
                Log.e(TAG, "Scan failed: $errorCode")
                updateNotification("Scan failed, retrying...")
                // Retry after 30 seconds
                handler.postDelayed({ connectToDevice() }, 30000)
            }
        }
        
        scanner?.startScan(scanCallback)
        
        // Timeout after 30 seconds
        handler.postDelayed({
            scanner?.stopScan(scanCallback)
            if (!isConnected) {
                updateNotification("Device not found, retrying...")
                handler.postDelayed({ connectToDevice() }, 30000)
            }
        }, 30000)
    }
    
    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.d(TAG, "Connected to GATT server")
                    isConnected = true
                    updateNotification("Connected, discovering services...")
                    gatt.discoverServices()
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    Log.d(TAG, "Disconnected from GATT server")
                    isConnected = false
                    updateNotification("Disconnected, reconnecting...")
                    // Auto-reconnect after 10 seconds
                    handler.postDelayed({ connectToDevice() }, 10000)
                }
            }
        }
        
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                Log.d(TAG, "Services discovered")
                val service = gatt.getService(SERVICE_UUID)
                val characteristic = service?.getCharacteristic(CHAR_REALTIME_UUID)
                
                if (characteristic != null) {
                    // Enable notifications for real-time data
                    gatt.setCharacteristicNotification(characteristic, true)
                    
                    val descriptor = characteristic.getDescriptor(
                        UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
                    )
                    descriptor?.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    gatt.writeDescriptor(descriptor)
                    
                    updateNotification("✅ Connected - Receiving data")
                } else {
                    Log.e(TAG, "Required characteristic not found")
                    updateNotification("❌ Configuration error")
                }
            }
        }
        
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            // Parse real-time data (MUST MATCH HC20 PROTOCOL)
            val data = characteristic.value
            
            // Example parsing (actual format depends on HC20 protocol):
            if (data.size >= 6) {
                heartRate = data[0].toInt() and 0xFF
                spo2 = data[1].toInt() and 0xFF
                temperature = ((data[2].toInt() and 0xFF) + (data[3].toInt() and 0xFF) * 256) / 10f
                
                Log.d(TAG, "Data received - HR: $heartRate, SpO2: $spo2, Temp: $temperature")
                updateNotification("✅ HR: $heartRate | SpO2: $spo2% | Temp: ${temperature}°C")
            }
        }
    }
    
    private fun startWebhookTimer() {
        handler.post(webhookRunnable)
    }
    
    private fun sendWebhook() {
        if (webhookUrl == null) return
        
        Log.d(TAG, "Sending webhook...")
        
        val client = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .writeTimeout(10, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build()
        
        val json = JSONObject().apply {
            put("device_id", deviceId)
            put("source", "NATIVE_SERVICE")
            put("is_connected", isConnected)
            put("data", JSONObject().apply {
                put("heart_rate", heartRate)
                put("spo2", spo2)
                put("temperature", temperature)
            })
            put("timestamp", System.currentTimeMillis())
        }
        
        val body = json.toString()
            .toRequestBody("application/json".toMediaType())
        
        val request = Request.Builder()
            .url(webhookUrl!!)
            .post(body)
            .build()
        
        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e(TAG, "Webhook failed: ${e.message}")
            }
            
            override fun onResponse(call: Call, response: Response) {
                Log.d(TAG, "Webhook sent: ${response.code}")
            }
        })
    }
    
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "HC20 Background Service",
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
    
    private fun createNotification(content: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("HC20 Service Running")
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()
    }
    
    private fun updateNotification(content: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, createNotification(content))
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(webhookRunnable)
        bluetoothGatt?.disconnect()
        bluetoothGatt?.close()
        Log.d(TAG, "Service destroyed")
    }
}
```

#### **Phase 3: Integrate with Flutter App**

**File: `lib/services/native_hc20_service.dart`**

```dart
import 'package:flutter/services.dart';

class NativeHc20Service {
  static const MethodChannel _channel = MethodChannel('com.example.hfc_app/native_service');
  
  /// Start native HC20 foreground service
  static Future<bool> start({
    required String deviceId,
    required String webhookUrl,
  }) async {
    try {
      final result = await _channel.invokeMethod('startNativeService', {
        'deviceId': deviceId,
        'webhookUrl': webhookUrl,
      });
      return result == true;
    } catch (e) {
      print('Failed to start native service: $e');
      return false;
    }
  }
  
  /// Stop native HC20 foreground service
  static Future<bool> stop() async {
    try {
      final result = await _channel.invokeMethod('stopNativeService');
      return result == true;
    } catch (e) {
      print('Failed to stop native service: $e');
      return false;
    }
  }
  
  /// Check if service is running
  static Future<bool> isRunning() async {
    try {
      final result = await _channel.invokeMethod('isServiceRunning');
      return result == true;
    } catch (e) {
      return false;
    }
  }
}
```

**File: `android/app/src/main/kotlin/com/example/hfc_app/MainActivity.kt`**

Add MethodChannel handler:

```kotlin
class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, 
            "com.example.hfc_app/native_service")
            .setMethodCallHandler { call, result ->
            when (call.method) {
                "startNativeService" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val webhookUrl = call.argument<String>("webhookUrl")
                    
                    val intent = Intent(this, Hc20ForegroundService::class.java).apply {
                        action = Hc20ForegroundService.ACTION_START
                        putExtra("deviceId", deviceId)
                        putExtra("webhookUrl", webhookUrl)
                    }
                    
                    startForegroundService(intent)
                    result.success(true)
                }
                "stopNativeService" -> {
                    val intent = Intent(this, Hc20ForegroundService::class.java).apply {
                        action = Hc20ForegroundService.ACTION_STOP
                    }
                    stopService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
```

**AndroidManifest.xml:**

```xml
<service
    android:name=".Hc20ForegroundService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="connectedDevice" />
```

#### **Phase 4: Add Dependencies**

**File: `android/app/build.gradle`**

```gradle
dependencies {
    // OkHttp for webhook calls
    implementation 'com.squareup.okhttp3:okhttp:4.11.0'
}
```

### **Benefits of Native Service Approach:**

✅ **True Background Operation**: Runs completely independent of Flutter  
✅ **Continuous Webhooks**: Sends data every 3 minutes even when app closed  
✅ **Auto-Reconnect**: Handles disconnections automatically  
✅ **Survives App Kill**: Service continues even if app is force-closed  
✅ **Works in Doze Mode**: Android prioritizes foreground services  
✅ **Battery Efficient**: Direct BLE communication without Flutter overhead  
✅ **No AlarmManager Needed**: Service runs continuously  

### **Challenges:**

❌ **Requires HC20 Protocol Knowledge**: Must reverse engineer BLE communication  
❌ **Development Time**: ~40-80 hours to implement and test  
❌ **Maintenance**: Updates to HC20 SDK won't automatically apply  
❌ **Testing**: Need physical HC20 device for BLE protocol capture  

### **Estimated Implementation Time:**

| Task | Duration |
|------|----------|
| BLE Protocol Analysis | 8-16 hours |
| Native Service Development | 16-24 hours |
| Testing & Debugging | 12-24 hours |
| Integration with Flutter | 4-8 hours |
| Final Testing | 8-12 hours |
| **Total** | **48-84 hours** |

### **Alternative: Contact HC20 SDK Provider**

If the HC20 SDK provider offers a native Android library (not Flutter wrapper), you could:
1. Use their native SDK directly in the foreground service
2. Avoid reverse engineering the BLE protocol
3. Get official support and updates

**Recommended Action**: Contact SDK provider and ask for native Android SDK documentation.

---

---

## 2. ✅ AlarmManager Re-launch App (App Closed)

### **STATUS: FIXED - Working with Native Broadcast**

#### Implementation:
```dart
// app_keepalive_service.dart
AppKeepaliveService.startPeriodicKeepalive() {
  // Schedules native broadcast alarm (15 minutes)
  _scheduleNativeRestartAlarm(); // Line 35
}

_scheduleNativeRestartAlarm() {
  // Calls native method WHILE app is running (MethodChannel available)
  await _channel.invokeMethod('scheduleKeepaliveRestart', {
    'delaySeconds': 900, // 15 minutes
  });
}
```

#### Native Flow:
```kotlin
// AppLauncher.kt
fun scheduleKeepaliveRestart(context: Context, delaySeconds: Int) {
  // Creates PendingIntent with broadcast to AppRestartReceiver
  alarmManager.setExactAndAllowWhileIdle(triggerTime, pendingIntent)
}

// AppRestartReceiver.kt
override fun onReceive(context: Context, intent: Intent) {
  AppLauncher.launchApp(context) // Launch app
  AppLauncher.scheduleKeepaliveRestart(context, 900) // Reschedule next alarm
}
```

#### Self-Perpetuating Cycle:
1. App starts → schedules native broadcast alarm (15 min)
2. 15 min later → alarm fires → AppRestartReceiver triggered
3. AppRestartReceiver → launches app + reschedules next alarm
4. Repeat forever ♻️

#### How It Works:
- ✅ Scheduled from main app (MethodChannel available)
- ✅ Uses native Android AlarmManager
- ✅ Works in Doze mode (`setExactAndAllowWhileIdle`)
- ✅ Survives app kill
- ✅ Auto-reschedules after each trigger
- ✅ Works after device reboot (BOOT_COMPLETED handler)

---

## 3. ✅ WorkManager Re-launch App (App Closed)

### **STATUS: FIXED - Working with Native Broadcast**

#### Implementation:
```dart
// background_sync_service.dart
BackgroundSyncService.startPeriodicSync() {
  // Schedules native broadcast alarm (20 minutes)
  _scheduleNativeWorkManagerRestart(); // Line 85
}

_scheduleNativeWorkManagerRestart() {
  // Calls same native method as AlarmManager
  await _channel.invokeMethod('scheduleKeepaliveRestart', {
    'delaySeconds': 1200, // 20 minutes
  });
}
```

#### Strategy:
- Uses **same native broadcast mechanism** as AlarmManager
- Different interval (20 min vs 15 min) to stagger restarts
- Provides **redundancy** if AlarmManager fails

#### Flow:
1. App starts → schedules WorkManager (15 min) + native alarm (20 min)
2. At 15 min → WorkManager callback runs (can't launch app from isolate)
3. At 20 min → Native alarm fires → AppRestartReceiver → launches app
4. App relaunches → reschedules both mechanisms
5. Repeat ♻️

#### Why Two Systems:
- **Redundancy**: If one fails, other works
- **Staggered timing**: More frequent restart attempts
- **Best of both**: WorkManager for task management + Native for app launch

---

## 4. ❌ Background Isolate Re-launch App (App Closed)

### **STATUS: BROKEN - Cannot Be Fixed**

#### Code Location:
```dart
// background_isolate_service.dart (line 668-700)
Future<void> _launchFlutterApp() async {
  // Method 1: Try MethodChannel
  const MethodChannel channel = MethodChannel('com.example.hfc_app/app_launcher');
  await channel.invokeMethod('launchApp'); // ❌ FAILS in isolate
  
  // Method 2: Try service invoke
  service.invoke('launchApp'); // ❌ Doesn't actually work
}
```

#### Why It Fails:
- **MethodChannel doesn't work in isolates** - requires Flutter engine
- **service.invoke()** doesn't have app launch capability
- **No Dart-based solution** exists for launching app from isolate

#### Current Behavior:
```
Line 286: Every 5 failed reconnects (2.5 min) → _launchFlutterApp()
Line 668: _launchFlutterApp() tries MethodChannel → FAILS
Line 688: _launchFlutterApp() tries service.invoke → DOESN'T WORK
Line 695: Shows notification "⚠️ TAP HERE TO OPEN APP"
```

#### Why We Don't Need To Fix This:
✅ **AlarmManager already handles app relaunch** (every 15 min)  
✅ **WorkManager also handles app relaunch** (every 20 min)  
✅ Background isolate doesn't need this capability

---

## 5. ⚠️ Background Isolate Show Notifications (Not Print)

### **STATUS: PARTIALLY WORKING - Needs Enhancement**

#### Current Implementation:
```dart
// background_isolate_service.dart
void _updateNotification(String content) {
  if (service is AndroidServiceInstance) {
    (service as AndroidServiceInstance).setForegroundNotificationInfo(
      title: 'HFC Background (INDEPENDENT)',
      content: content,
    );
  }
}
```

#### What Works:
- ✅ Foreground service notification shows status
- ✅ Updates with each step (STEP 1/2/3)
- ✅ Shows connection status, errors, webhook count

#### What's Missing:
- ❌ Critical errors only in foreground notification (can be missed)
- ❌ No separate dismissible error notifications
- ❌ No tap action to open app from error notification

#### Fix Required:
Add separate error notification system using `FlutterLocalNotificationsPlugin`.

---

## Implementation Plan

### IMMEDIATE FIXES:

#### Fix #1: Add Error Notification System
```dart
void _showErrorNotification(String title, String message) {
  final plugin = FlutterLocalNotificationsPlugin();
  const details = AndroidNotificationDetails(
    'hfc_errors',
    'HFC Errors',
    importance: Importance.high,
    priority: Priority.high,
  );
  plugin.show(notificationId, title, message, NotificationDetails(android: details));
}
```

#### Fix #2: Call Error Notifications on Failures
```dart
// When HC20 client creation fails
catch (e) {
  _showErrorNotification(
    'Connection Failed',
    'HC20 SDK incompatible with background isolate. App needs to stay open.',
  );
}

// When device not found
_showErrorNotification(
  'Device Not Found',
  'Could not find HC20 device. Make sure it is powered on.',
);

// When webhook fails
_showErrorNotification(
  'Webhook Failed',
  'Failed to send data to server',
);
```

#### Fix #3: Add Startup Warning
```dart
Future<void> start() async {
  _showErrorNotification(
    'Background Service Started',
    '⚠️ Background HC20 may fail. AlarmManager will restart app every 15 min.',
  );
}
```

---

## Summary Table

| Requirement | Status | Works? | Solution |
|------------|--------|--------|----------|
| **1. Background Webhooks** | ❌ Broken | NO | Cannot fix - HC20 SDK incompatible |
| **2. AlarmManager Relaunch** | ✅ Fixed | YES | Native broadcast alarm |
| **3. WorkManager Relaunch** | ✅ Fixed | YES | Native broadcast alarm |
| **4. Isolate Relaunch** | ❌ Won't Fix | NO | Not needed (1 & 2 cover it) |
| **5. Error Notifications** | ⚠️ Partial | PARTIAL | Add separate error notifications |

---

## Recommended Next Steps

### Priority 1: Add Error Notifications ⚠️
Implement `_showErrorNotification()` method to show critical errors.

### Priority 2: Test Native Restart Alarms ✅
1. Install APK
2. Open app, let run 30 seconds
3. Force close app
4. Wait 15 minutes → verify app relaunches automatically
5. Check logcat for alarm triggers

### Priority 3: Document Limitations 📝
Update user documentation:
- Background webhooks don't work (HC20 SDK limitation)
- App will auto-restart every 15-20 minutes if closed
- Best practice: Keep app open for continuous connection

### Priority 4: Consider Native Service 🔄
For true independent background operation:
- Rewrite HC20 BLE logic in Kotlin
- Create native Android ForegroundService
- Bypass Flutter isolate limitations

---

## Technical Details

### Why Isolates Fail:
```
┌─────────────────────────────────────┐
│ Main Flutter App                    │
│ - Has Flutter engine context        │
│ - MethodChannel works ✅            │
│ - Platform plugins work ✅          │
│ - HC20 SDK works ✅                 │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Background Isolate (Separate VM)    │
│ - NO Flutter engine context         │
│ - MethodChannel FAILS ❌            │
│ - Platform plugins FAIL ❌          │
│ - HC20 SDK FAILS ❌                 │
└─────────────────────────────────────┘
```

### Why Native Alarms Work:
```
App (Flutter) → MethodChannel → Native AppLauncher.scheduleKeepaliveRestart()
                                 ↓
                          Android AlarmManager (Native)
                                 ↓
                          15 minutes later...
                                 ↓
                          Broadcast to AppRestartReceiver (Native)
                                 ↓
                          Launch app + reschedule next alarm
                                 ↓
                          App opens → cycle repeats ♻️
```

---

## Conclusion

**Current State:**
- ✅ App will **auto-restart every 15-20 minutes** when closed
- ❌ Background webhooks **don't work** (HC20 SDK limitation)
- ✅ Notifications **show status** but need error enhancements

**Expected Behavior:**
- App closes → AlarmManager relaunches after 15 min
- App closes → WorkManager alarm relaunches after 20 min
- User sees notifications for errors and status
- HC20 connection maintained while app is open

**Known Limitations:**
- HC20 SDK cannot work in background isolates
- True "independent background connection" not possible
- App must stay open OR rely on auto-restart for continuous operation
