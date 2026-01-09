# HFC App - How It Works

## 📱 Overview

The HFC App is a Flutter-based mobile application that connects to HC20 wearable devices via Bluetooth, collects real-time health data, and continuously syncs it with the backend API server. The app features automatic reconnection, persistent login, and background data synchronization.

---

## 🔄 Complete Data Flow

```
┌─────────────────┐
│   HC20 Device   │
│   (Bluetooth)   │
└────────┬────────┘
         │ BLE Connection
         ↓
┌─────────────────────────────────────────────────────┐
│              Flutter Mobile App                     │
│                                                      │
│  ┌─────────────────────────────────────────────┐  │
│  │  Real-time Data Stream (every 1 second)     │  │
│  │  • Heart Rate, SpO2, Blood Pressure         │  │
│  │  • Temperature, Steps, Battery Level        │  │
│  └──────────────┬──────────────────────────────┘  │
│                 │                                   │
│                 ↓                                   │
│  ┌─────────────────────────────────────────────┐  │
│  │  Webhook Timer (Every 2 Minutes)            │  │
│  │  • Device Connected: Send real health data  │  │
│  │  • Device Disconnected: Send status update  │  │
│  └──────────────┬──────────────────────────────┘  │
│                 │                                   │
│                 ↓                                   │
│  ┌─────────────────────────────────────────────┐  │
│  │  Auto-Reconnect Scanner (Every 30 Seconds)  │  │
│  │  • Scans for saved device ID                │  │
│  │  • Auto-connects when found                 │  │
│  └─────────────────────────────────────────────┘  │
└────────────────┬────────────────────────────────────┘
                 │ HTTPS POST
                 ↓
┌─────────────────────────────────────────────────────┐
│          Backend API Server                         │
│          https://api.hireforcare.com                │
│                                                      │
│  ┌─────────────────────────────────────────────┐  │
│  │  Webhook Endpoint                           │  │
│  │  POST /webhook/hc20-data                    │  │
│  │  • Receives health data                     │  │
│  │  • Stores with timestamp                    │  │
│  │  • Associates with user via phone number    │  │
│  └──────────────┬──────────────────────────────┘  │
│                 │                                   │
│                 ↓                                   │
│  ┌─────────────────────────────────────────────┐  │
│  │  CRON Job (Every 1 Minute)                  │  │
│  │  • Checks for devices with no data >10 min  │  │
│  │  • Sends WhatsApp disconnect notification   │  │
│  │  • 4-hour cooldown between notifications    │  │
│  └──────────────┬──────────────────────────────┘  │
│                 │                                   │
│                 ↓                                   │
│  ┌─────────────────────────────────────────────┐  │
│  │  WhatsApp Business API                      │  │
│  │  • Sends automated messages                 │  │
│  │  • Notifies device disconnections           │  │
│  └─────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

---

## 🔌 1. Device Connection & Data Streaming

### Initial Connection Flow

**File:** `lib/main.dart` - `_connectToDevice()` method

```dart
// User manually connects to HC20 device
await _client!.connect(device);

// Read device info
final info = await _client!.readDeviceInfo(device);

// Sync time with mobile device
await _client!.syncTime(device);

// Associate device with logged-in user
await _associateDeviceWithUser(device);

// Start real-time data stream
_startRealtimeDataStream(device);

// Save device ID for auto-reconnect
await _saveDeviceForAutoReconnect(device.id);
```

**What happens:**
1. Bluetooth connection established to HC20 device
2. Device information retrieved (name, version, battery)
3. Device clock synchronized with phone time
4. Device linked to user account via backend API
5. Real-time data stream activated
6. Device ID saved locally for future auto-reconnect

---

## 📊 2. Real-time Data Stream

### Continuous Health Data Collection

**File:** `lib/main.dart` - `_startRealtimeDataStream()` method

```dart
// Subscribe to real-time data stream (updates every ~1 second)
_realtimeSubscription = _client!.realtimeV2(device).listen(
  (data) async {
    // Update UI with latest health metrics
    setState(() {
      _heartRate = data.heartRate;
      _spo2 = data.oxygenSaturation;
      _bloodPressure = data.bloodPressure;
      _temperature = data.temperature;
      _batteryLevel = data.batteryLevel;
      _steps = data.steps;
    });

    // Send data to webhook API immediately
    await _sendHealthDataToWebhook(data);
  }
);
```

**Data Sent to Backend:**
```json
{
  "phone": "user_phone_number",
  "deviceId": "HC20_DEVICE_ID",
  "heartRate": 75,
  "spo2": 98,
  "bloodPressure": [120, 80],
  "temperature": 36.5,
  "batteryLevel": 85,
  "steps": 5420,
  "timestamp": "2026-01-08T10:30:45.123Z"
}
```

**Frequency:** Real-time (every ~1 second when new data available)

---

## ⏰ 3. Webhook Timer System (2-Minute Interval)

### Periodic Data Sync

**File:** `lib/main.dart` - Lines 823-846

```dart
// Timer triggers every 120 seconds (2 minutes)
_dataRefreshTimer = Timer.periodic(const Duration(seconds: 120), (timer) async {
  print('⏰ [Timer] 2-minute webhook timer triggered');
  
  if (_isConnected && _connectedDevice != null) {
    // Device connected: Request fresh data
    print('   Device connected - requesting fresh data...');
    _client!.realtimeV2(device).listen((_) {}, onError: (_) {});
  } else {
    // Device disconnected: Send status update with timestamp
    print('   Device DISCONNECTED - sending disconnect status');
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user != null) {
      await _sendDisconnectWebhook(user.phone);
    }
  }
});
```

**Purpose:**
- **Connected Mode:** Triggers data refresh every 2 minutes to ensure continuous backend updates
- **Disconnected Mode:** Sends disconnect status with current timestamp so backend knows device is offline

**Disconnect Webhook Payload:**
```json
{
  "phone": "user_phone_number",
  "status": "disconnected",
  "message": "Device is not connected",
  "timestamp": "2026-01-08T10:32:00.000Z"
}
```

**Why 2 minutes?**
- Balances between real-time updates and battery conservation
- Backend CRON checks every 1 minute, so 2-minute app interval ensures overlap
- Provides timestamp updates even when device disconnected

---

## 🔄 4. Auto-Reconnect System

### Automatic Device Recovery

**File:** `lib/main.dart` - Lines 1241-1321

#### Save Device on First Connection
```dart
Future<void> _saveDeviceForAutoReconnect(String deviceId) async {
  // Save device ID to secure storage
  await StorageService().saveDeviceId(deviceId);
  
  // Start background scanner
  _startAutoReconnectScanner();
}
```

#### Background Scanner (Every 30 Seconds)
```dart
void _startAutoReconnectScanner() {
  // Scan every 30 seconds for saved device
  _autoReconnectScanner = Timer.periodic(const Duration(seconds: 30), (timer) async {
    // Only scan if disconnected
    if (_isConnected || _isAutoReconnecting || _isScanning) {
      return;
    }
    
    print('⏰ [Auto-Reconnect] Scanning for saved device...');
    await _scanForSavedDevice();
  });
}
```

#### Smart Reconnection Logic
```dart
Future<void> _scanForSavedDevice() async {
  // Initialize HC20 client if needed
  if (_client == null) {
    await _initializeHC20Client();
  }
  
  Hc20Device? foundDevice;
  
  // Scan for 10 seconds
  final subscription = _client!.scan().listen((device) {
    if (device.id == _savedDeviceId && foundDevice == null) {
      foundDevice = device;
      print('✅ [Auto-Reconnect] Found saved device!');
    }
  });
  
  await Future.delayed(const Duration(seconds: 10));
  subscription.cancel();
  
  // Auto-connect if device found
  if (foundDevice != null) {
    print('🔌 [Auto-Reconnect] Connecting...');
    await _connectToDevice(foundDevice!);
  }
}
```

**Auto-Reconnect Flow:**
```
Device Disconnects
      ↓
App detects disconnection
      ↓
Auto-reconnect scanner activates
      ↓
Scan every 30 seconds for saved device ID
      ↓
Device comes back in range
      ↓
Scanner detects saved device
      ↓
Automatically connects
      ↓
Data streaming resumes
```

**Storage:** Device ID saved in both secure storage and SharedPreferences for redundancy

---

## 🌐 5. Backend API Integration

### Webhook Endpoint

**Endpoint:** `POST https://api.hireforcare.com/webhook/hc20-data`

**File:** `lib/services/api_service.dart` - `sendHealthData()` method

```dart
Future<Map<String, dynamic>> sendHealthData(Map<String, dynamic> data) async {
  try {
    final response = await _dio.post(
      '/webhook/hc20-data',
      data: data,
    );
    
    if (response.statusCode == 200) {
      print('✅ Health data sent successfully');
      return {'success': true, 'data': response.data};
    }
  } catch (e) {
    print('❌ Webhook error: $e');
    return {'success': false, 'error': e.toString()};
  }
}
```

### Backend Webhook Processing (Node.js/Express)

**Endpoint:** `POST /webhook/hc20-data`

```javascript
// Backend receives webhook data
app.post('/webhook/hc20-data', async (req, res) => {
  const { phone, deviceId, heartRate, spo2, bloodPressure, temperature, batteryLevel, steps, timestamp } = req.body;
  
  try {
    // Store health data in database with timestamp
    const healthRecord = await prisma.hc20Data.create({
      data: {
        phone,
        deviceId,
        heartRate,
        spo2,
        bloodPressure,
        temperature,
        batteryLevel,
        steps,
        timestamp: new Date(timestamp),
        receivedAt: new Date()
      }
    });
    
    res.status(200).json({ success: true, recordId: healthRecord.id });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});
```

---

## 📬 6. Backend Notification System

### Automatic Disconnect Detection (CRON Job)

**Backend File:** `checkDisconnectedDevices()` function

```javascript
// Runs every 1 minute
cron.schedule('* * * * *', async () => {
  console.log('🔍 Checking for disconnected devices...');
  
  try {
    // Find devices with no data in last 10+ minutes
    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
    
    const disconnectedDevices = await prisma.hc20Data.groupBy({
      by: ['deviceId', 'phone'],
      having: {
        timestamp: {
          lt: tenMinutesAgo
        }
      }
    });
    
    // Send WhatsApp notification for each disconnected device
    for (const device of disconnectedDevices) {
      // Check if notification already sent recently (4-hour cooldown)
      const lastNotification = await prisma.deviceNotification.findFirst({
        where: {
          deviceId: device.deviceId,
          phone: device.phone,
          type: 'disconnect',
          sentAt: {
            gte: new Date(Date.now() - 4 * 60 * 60 * 1000) // 4 hours ago
          }
        }
      });
      
      // Only send if no notification in last 4 hours
      if (!lastNotification) {
        await sendAutoDisconnectNotification(device.phone, device.deviceId);
      }
    }
  } catch (error) {
    console.error('❌ CRON error:', error);
  }
});
```

### WhatsApp Notification Function

```javascript
async function sendAutoDisconnectNotification(phone, deviceId) {
  const whatsappAPIUrl = `https://graph.facebook.com/v21.0/${PHONE_NUMBER_ID}/messages`;
  
  const message = {
    messaging_product: 'whatsapp',
    to: phone,
    type: 'text',
    text: {
      body: `⚠️ HC20 Device Alert\n\nYour HC20 device (${deviceId}) has been disconnected for more than 10 minutes.\n\nPlease check:\n• Device battery level\n• Bluetooth connection\n• Device is within range\n\nHealth monitoring has been paused.`
    }
  };
  
  try {
    const response = await axios.post(whatsappAPIUrl, message, {
      headers: {
        'Authorization': `Bearer ${WHATSAPP_ACCESS_TOKEN}`,
        'Content-Type': 'application/json'
      }
    });
    
    // Log notification in database
    await prisma.deviceNotification.create({
      data: {
        deviceId,
        phone,
        type: 'disconnect',
        status: 'sent',
        sentAt: new Date()
      }
    });
    
    console.log('✅ WhatsApp notification sent');
  } catch (error) {
    console.error('❌ WhatsApp send error:', error);
  }
}
```

---

## 🔐 7. Authentication Flow

### Login with OTP

**File:** `lib/pages/login_page.dart` - `_verifyOTP()` method

**Flow:**
```
User enters phone number
      ↓
App sends OTP request to backend
      ↓
Backend sends OTP via SMS/WhatsApp/Email
      ↓
User enters OTP code
      ↓
App verifies OTP with backend
      ↓
Backend returns JWT token + user data
      ↓
App saves token to secure storage
      ↓
Token used in all subsequent API calls
```

**API Endpoints:**
- `POST /api/auth/send-otp` - Request OTP
- `POST /api/auth/verify-otp` - Verify OTP and get token

**Token Storage:**
```dart
// Save to both secure storage and SharedPreferences
await _secureStorage.write(key: 'auth_token', value: token);
final prefs = await SharedPreferences.getInstance();
await prefs.setString('backup_auth_token', token);
```

**Token Usage in API Calls:**
```dart
Future<Map<String, String>> _getHeaders({bool includeAuth = false}) async {
  final headers = {
    'Content-Type': 'application/json',
  };
  
  if (includeAuth) {
    final token = await StorageService().getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
  }
  
  return headers;
}
```

---

## ⚡ 8. Background Execution

### Android Foreground Service + Wake Lock

**File:** `android/app/src/main/kotlin/MainActivity.kt`

```kotlin
// Enable background execution
private fun enableBackgroundExecution() {
    // Start foreground service with persistent notification
    val serviceIntent = Intent(this, BackgroundService::class.java)
    startForegroundService(serviceIntent)
    
    // Acquire wake lock to keep CPU running
    val powerManager = getSystemService(POWER_SERVICE) as PowerManager
    wakeLock = powerManager.newWakeLock(
        PowerManager.PARTIAL_WAKE_LOCK,
        "HFCApp::BackgroundSync"
    )
    wakeLock?.acquire()
}
```

**Benefits:**
- App continues running even when screen is off
- Bluetooth connection maintained in background
- Webhook timer continues executing
- Auto-reconnect scanner stays active

**Battery Optimization:**
- User must disable battery optimization for the app
- App requests exemption on first launch
- Required for reliable background operation

---

## 📊 9. Complete API Reference

### Flutter App → Backend API Calls

| Endpoint | Method | Purpose | Frequency |
|----------|--------|---------|-----------|
| `/api/auth/send-otp` | POST | Request OTP for login | On login |
| `/api/auth/verify-otp` | POST | Verify OTP and get token | On login |
| `/webhook/hc20-data` | POST | Send health data | Every 1s + Every 2min |
| `/webhook/hc20-data` (disconnect) | POST | Send disconnect status | Every 2min (when disconnected) |
| `/api/hc20-data/:deviceId/user` | PUT | Associate device with user | On first connection |
| `/api/notifications/device-disconnect` | POST | Manual test notification | Manual trigger only |

### Backend Cron Jobs

| Job | Frequency | Purpose |
|-----|-----------|---------|
| `checkDisconnectedDevices()` | Every 1 minute | Detect devices offline >10 minutes |
| `sendAutoDisconnectNotification()` | As needed | Send WhatsApp alerts (4-hour cooldown) |

---

## 🎯 10. Key Timings & Intervals

| Component | Interval | Purpose |
|-----------|----------|---------|
| Real-time data stream | ~1 second | Live health metrics |
| Webhook timer | 2 minutes | Periodic backend sync |
| Auto-reconnect scanner | 30 seconds | Check for saved device |
| Auto-reconnect scan duration | 10 seconds | BLE scan window |
| HRV data refresh | 6 hours | Heart rate variability |
| Backend CRON job | 1 minute | Disconnect detection |
| Disconnect threshold | 10 minutes | No data = disconnected |
| Notification cooldown | 4 hours | Prevent spam |

---

## 🔍 11. Data Flow Examples

### Example 1: Normal Operation (Device Connected)

```
10:00:00 - Device connects, starts streaming
10:00:01 - Real-time data: HR=75, SpO2=98 → Webhook sent
10:00:02 - Real-time data: HR=76, SpO2=98 → Webhook sent
10:00:03 - Real-time data: HR=75, SpO2=98 → Webhook sent
...
10:02:00 - 2-minute timer triggers → Fresh data requested
10:02:01 - Real-time data: HR=77, SpO2=97 → Webhook sent
...
10:04:00 - 2-minute timer triggers → Fresh data requested
...
```

### Example 2: Device Disconnect Scenario

```
10:00:00 - Device connected, streaming normally
10:05:00 - User walks away, device disconnects
10:05:01 - App detects disconnection
10:05:30 - Auto-reconnect scanner starts (first scan)
10:06:00 - 2-minute timer: Sends disconnect status to backend
10:06:00 - Auto-reconnect scanner (2nd scan) - device not found
10:07:00 - Backend CRON: Checks timestamps (still < 10 min)
10:08:00 - 2-minute timer: Sends disconnect status again
10:08:00 - Auto-reconnect scanner (3rd scan) - device not found
...
10:15:00 - Backend CRON: Detects >10 min no data
10:15:01 - Backend sends WhatsApp notification
10:20:00 - User returns, device in range
10:20:30 - Auto-reconnect scanner finds device
10:20:31 - Automatically reconnects
10:20:32 - Data streaming resumes
```

---

## 📱 12. Storage Architecture

**File:** `lib/services/storage_service.dart`

### Dual Storage Strategy

```dart
// Primary: Secure Storage (encrypted)
final _secureStorage = const FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ),
);

// Backup: SharedPreferences (fallback)
final prefs = await SharedPreferences.getInstance();
```

**Stored Data:**
- `auth_token` - JWT authentication token
- `user_data` - User profile (name, phone, email, role)
- `device_id` - Last connected HC20 device ID (for auto-reconnect)

**Why Dual Storage?**
- Secure storage can fail on some devices
- SharedPreferences provides reliable fallback
- Ensures data never lost even if one storage fails

---

## 🚀 13. App Versions & Features

### Version 8.0.7 (Current)

**Key Features:**
- ✅ 2-minute webhook interval (changed from 10 minutes)
- ✅ Always-send webhook (even when disconnected)
- ✅ Auto-reconnect every 30 seconds
- ✅ Persistent login with dual storage
- ✅ Background execution with foreground service
- ✅ Real-time health data streaming
- ✅ Manual test notification button
- ✅ Auth status display in drawer

---

## 🔧 14. Troubleshooting Guide

### Common Issues

**1. Device Not Connecting**
- Check: Battery optimization disabled?
- Check: Bluetooth permissions granted?
- Check: Device in range (<10 meters)?
- Check: OAuth credentials valid?

**2. No Webhook Data Received**
- Check: Internet connection active?
- Check: Backend API reachable?
- Check: User logged in with valid token?
- Check: Device associated with user?

**3. Auto-Reconnect Not Working**
- Check: Device ID saved correctly?
- Check: Auto-reconnect scanner running?
- Check: Device powered on and in range?
- Check: Bluetooth not disabled by user?

**4. WhatsApp Notifications Not Received**
- Check: Backend CRON job running?
- Check: Device actually disconnected >10 minutes?
- Check: Not in 4-hour cooldown period?
- Check: WhatsApp Business API token valid?

---

## 📚 15. File Structure

```
lib/
├── main.dart                 # Main app, connection logic, webhook timer
├── sdk_config.dart          # HC20 SDK OAuth configuration
├── pages/
│   ├── login_page.dart      # OTP authentication
│   ├── all_data_page.dart   # View all health data
│   └── test_notification_page.dart
├── services/
│   ├── api_service.dart     # All backend API calls
│   ├── auth_service.dart    # Authentication state management
│   └── storage_service.dart # Secure data storage
└── models/
    └── user_model.dart      # User data model

android/
└── app/src/main/kotlin/
    └── MainActivity.kt      # Background service, wake lock

Backend (Node.js):
├── webhook/
│   └── hc20-data.js        # Webhook endpoint handler
├── cron/
│   └── checkDevices.js     # Disconnect detection
└── notifications/
    └── whatsapp.js         # WhatsApp messaging
```

---

## 🎓 16. Developer Notes

### Adding New Health Metrics

1. Update real-time data handler in `main.dart`:
```dart
_realtimeSubscription = _client!.realtimeV2(device).listen((data) {
  setState(() {
    _newMetric = data.newMetric;  // Add new metric
  });
});
```

2. Update webhook payload:
```dart
final payload = {
  'newMetric': _newMetric,  // Include in webhook
  // ... other fields
};
```

3. Update backend database schema to store new metric

### Changing Webhook Interval

**File:** `lib/main.dart` - Line 827

```dart
// Change Duration(seconds: 120) to desired interval
_dataRefreshTimer = Timer.periodic(const Duration(seconds: 120), ...);
```

### Changing Auto-Reconnect Interval

**File:** `lib/main.dart` - Line 1266

```dart
// Change Duration(seconds: 30) to desired interval
_autoReconnectScanner = Timer.periodic(const Duration(seconds: 30), ...);
```

---

## 📞 Support

For technical issues or questions:
- Check logs: `flutter run` or Android Studio logcat
- Review API responses in debug console
- Verify backend server status
- Check WhatsApp Business API dashboard

---

**Last Updated:** January 8, 2026  
**App Version:** 8.0.7 (Build 54)  
**Flutter SDK:** Stable Channel  
**Backend API:** https://api.hireforcare.com
