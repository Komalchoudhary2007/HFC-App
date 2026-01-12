# Main.dart - Error Handling & Troubleshooting Documentation

**Part 6 of 7**  
**Last Updated:** January 9, 2026  
**File:** `lib/main.dart` (Error Scenarios & Debugging)

---

## Table of Contents
1. [Common Error Scenarios](#common-error-scenarios)
2. [Bluetooth Connection Errors](#bluetooth-connection-errors)
3. [Webhook/API Errors](#webhookapi-errors)
4. [Permission Errors](#permission-errors)
5. [Battery Optimization Issues](#battery-optimization-issues)
6. [Authentication Errors](#authentication-errors)
7. [Debugging Techniques](#debugging-techniques)
8. [Log Interpretation Guide](#log-interpretation-guide)
9. [Testing Checklist](#testing-checklist)

---

## Common Error Scenarios

### Error Decision Tree

```
User Reports Issue
   │
   ▼
What's the symptom?
   │
   ├─→ "Can't find device"
   │   └─→ Check: Permissions → Bluetooth → Device Power
   │
   ├─→ "Connected but no data"
   │   └─→ Check: Webhook URL → Network → API credentials
   │
   ├─→ "App keeps crashing"
   │   └─→ Check: Memory leaks → Null checks → Timer cleanup
   │
   ├─→ "Device disconnects frequently"
   │   └─→ Check: Signal strength → Battery optimization → BLE interference
   │
   └─→ "Data not reaching backend"
       └─→ Check: Webhook logs → Network connectivity → API status
```

---

## Bluetooth Connection Errors

### Error 1: Device Not Found During Scan

**Error Message:**
```
ℹ️ No devices found
```

**Possible Causes:**

| Cause | Solution | How to Verify |
|-------|----------|---------------|
| **Bluetooth OFF** | Enable Bluetooth | Settings → Bluetooth → ON |
| **Location Permission Missing** | Grant location permission | Run `_requestPermissions()` |
| **Device Powered Off** | Turn on HC20 | Check LED indicators |
| **Device Already Connected** | Disconnect other apps | Close other BLE apps |
| **Out of Range** | Move closer (< 10m) | Test at 2-3 meters |

**Debug Steps:**
```dart
// 1. Check Bluetooth status
print('📱 Checking Bluetooth...');
// (No direct API - use platform channel if needed)

// 2. Check permissions
final locationStatus = await Permission.locationWhenInUse.status;
print('📍 Location permission: $locationStatus');

// 3. Verify scan is running
print('🔍 Starting scan...');
final devices = [];
_client!.scan().listen((device) {
  devices.add(device);
  print('   Found: ${device.name}');
});

await Future.delayed(Duration(seconds: 10));
print('📊 Total devices found: ${devices.length}');
```

---

### Error 2: Connection Timeout

**Error Message:**
```
❌ Error connecting to device: TimeoutException after 0:00:30.000000
```

**Possible Causes:**

1. **Device is low battery** → Charge device
2. **Too far away** → Move closer
3. **BLE interference** → Move away from WiFi routers
4. **Device in pairing mode with another phone** → Unpair from other devices

**Fix:**
```dart
// Add timeout handling
try {
  await _client!.connect(device).timeout(
    const Duration(seconds: 30),
    onTimeout: () {
      throw TimeoutException('Connection took too long');
    },
  );
} on TimeoutException catch (e) {
  print('⏱️ Connection timeout - device may be too far');
  print('   Solution: Move device closer and try again');
  
  setState(() {
    _statusMessage = 'Connection timeout. Move device closer.';
  });
}
```

---

### Error 3: GATT Error (Connection Lost)

**Error Message:**
```
❌ Real-time stream error: GATT operation failed
```

**Possible Causes:**

| GATT Error | Meaning | Solution |
|------------|---------|----------|
| **GATT 133** | Connection lost suddenly | Automatic reconnect will handle |
| **GATT 8** | Insufficient authentication | Re-pair device in Bluetooth settings |
| **GATT 22** | Invalid attribute handle | Disconnect and reconnect |
| **GATT 14** | Unlikely error | Try airplane mode on/off |

**Fix:**
```dart
onError: (error) {
  print('❌ Real-time stream error: $error');
  
  // Parse GATT error code
  final errorStr = error.toString();
  if (errorStr.contains('GATT')) {
    // Extract error code if possible
    final match = RegExp(r'GATT (\d+)').firstMatch(errorStr);
    if (match != null) {
      final gattCode = int.parse(match.group(1)!);
      print('⚠️ GATT Error Code: $gattCode');
      
      switch (gattCode) {
        case 133:
          print('   → Connection lost, will auto-reconnect');
          break;
        case 8:
          print('   → Authentication failed, re-pair device');
          break;
        case 22:
          print('   → Invalid handle, reconnecting...');
          break;
      }
    }
  }
  
  _handleDisconnection();
}
```

---

### Error 4: Multiple Connections

**Error Message:**
```
⚠️ Already attempting reconnection...
```

**Cause:** App trying to connect multiple times simultaneously

**Fix:** Already implemented with `_isReconnecting` flag
```dart
if (_isReconnecting) {
  print('⏳ Already attempting reconnection...');
  return;  // Prevent duplicate attempts
}
```

---

## Webhook/API Errors

### Error 5: DioException - Connection Timeout

**Error Message:**
```
❌ Request timeout: The connection has timed out (CONNECTION_TIMEOUT)
```

**Possible Causes:**

1. **Slow internet connection** → Switch to WiFi
2. **Backend server down** → Check API status
3. **Firewall blocking** → Check network settings
4. **VPN interference** → Disable VPN temporarily

**Fix:**
```dart
// Already implemented in _sendDataToWebhook
catch (e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        print('❌ Request timeout: Check your internet connection');
        _statusMessage = 'Network timeout. Check internet connection.';
        
        // RECOMMENDATION: Queue data for retry
        await _queueDataForRetry(device, data);
        break;
    }
  }
}
```

**Recommended Addition:**
```dart
// Implement offline data queue
class OfflineDataQueue {
  final List<Map<String, dynamic>> _queue = [];
  
  void add(Map<String, dynamic> data) {
    _queue.add(data);
    print('📦 Queued data for retry (${_queue.length} items)');
  }
  
  Future<void> flushQueue() async {
    if (_queue.isEmpty) return;
    
    print('🔄 Flushing ${_queue.length} queued items...');
    
    for (final data in _queue) {
      try {
        await _dio.post(_webhookUrl, data: data);
        print('✅ Sent queued item');
      } catch (e) {
        print('❌ Failed to send queued item: $e');
        return; // Stop if network still down
      }
    }
    
    _queue.clear();
    print('✅ All queued data sent');
  }
}
```

---

### Error 6: DioException - Bad Response (400-500)

**Error Message:**
```
❌ Server error: Request returned error (BAD_RESPONSE) - Status: 401
```

**Status Code Meanings:**

| Code | Meaning | Cause | Solution |
|------|---------|-------|----------|
| **400** | Bad Request | Invalid data format | Check payload structure |
| **401** | Unauthorized | Invalid/expired token | Re-authenticate user |
| **403** | Forbidden | No permission | Check API key |
| **404** | Not Found | Wrong URL | Verify webhook URL |
| **500** | Server Error | Backend crash | Contact backend team |
| **502** | Bad Gateway | Backend offline | Wait and retry |
| **503** | Service Unavailable | Backend overloaded | Implement exponential backoff |

**Fix:**
```dart
case DioExceptionType.badResponse:
  final statusCode = e.response?.statusCode;
  print('❌ Server error: Status $statusCode');
  
  switch (statusCode) {
    case 401:
      print('   → Authentication expired, please log in again');
      // Navigate to login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
      break;
      
    case 500:
    case 502:
    case 503:
      print('   → Server error, will retry later');
      await _queueDataForRetry(device, data);
      break;
      
    case 400:
      print('   → Invalid data format');
      print('   Payload: ${jsonEncode(e.response?.data)}');
      break;
  }
  break;
```

---

### Error 7: Invalid Phone Number Format

**Error Message:**
```
❌ No phone number available for current user
```

**Cause:** User object doesn't have phone field

**Fix:**
```dart
// Check phone number before sending webhook
if (user.phone.isEmpty) {
  print('❌ No phone number for user');
  
  // RECOMMENDATION: Show dialog to user
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Phone Number Required'),
      content: Text('Please add your phone number in settings'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // Navigate to settings
          },
          child: Text('Go to Settings'),
        ),
      ],
    ),
  );
  
  return;
}
```

---

## Permission Errors

### Error 8: Location Permission Denied

**Error Message:**
```
⚠️ Location permission denied. Bluetooth scanning requires location access on Android.
```

**Cause:** User denied location permission (required for BLE scanning on Android)

**Fix:**
```dart
// Already implemented in _requestPermissions
if (!locationStatus.isGranted) {
  print('\n❌ ========================================');
  print('❌ LOCATION PERMISSION REQUIRED');
  print('❌ ========================================');
  print('❌ Bluetooth scanning on Android requires location permission');
  print('❌ Please grant "Allow all the time" for background scanning');
  print('❌ ========================================\n');
  
  // Show explanation dialog
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('Location Permission Required'),
      content: Text(
        'Bluetooth scanning requires location permission on Android.\n\n'
        'This is a system requirement and your location data is NOT tracked.'
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            openAppSettings();
          },
          child: Text('Open Settings'),
        ),
      ],
    ),
  );
}
```

**Manual Fix for Users:**
```
Settings → Apps → HFC App → Permissions → Location → Allow all the time
```

---

### Error 9: Bluetooth Permission Denied

**Error Message:**
```
⚠️ Bluetooth permission denied
```

**Cause:** User denied Bluetooth permission

**Fix:**
```dart
// Request Bluetooth permission
final bluetoothStatus = await Permission.bluetoothScan.request();
final bluetoothConnectStatus = await Permission.bluetoothConnect.request();

if (!bluetoothStatus.isGranted || !bluetoothConnectStatus.isGranted) {
  print('❌ Bluetooth permissions denied');
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Bluetooth Permission Required'),
      content: Text('Please grant Bluetooth permission to connect to HC20 devices'),
      actions: [
        TextButton(
          onPressed: () => openAppSettings(),
          child: Text('Open Settings'),
        ),
      ],
    ),
  );
}
```

---

## Battery Optimization Issues

### Error 10: App Killed in Background

**Symptom:** App stops streaming data after screen turns off

**Cause:** Android battery optimization killing app

**Fix:** Already implemented in `_requestBatteryOptimizationExemption()`

**Verification:**
```dart
// Check if exemption is granted
final isExempted = await _methodChannel.invokeMethod('isBatteryOptimizationDisabled');
print('🔋 Battery optimization exempted: $isExempted');

if (!isExempted) {
  print('⚠️ App may be killed in background');
  print('   Please disable battery optimization manually:');
  print('   Settings → Apps → HFC App → Battery → Unrestricted');
}
```

**Manual Steps for Users:**
```
Samsung: Settings → Apps → HFC App → Battery → Optimize battery usage → Turn OFF
Xiaomi: Settings → Apps → HFC App → Battery saver → No restrictions
OnePlus: Settings → Apps → HFC App → Battery → Battery optimization → Don't optimize
Google Pixel: Settings → Apps → HFC App → Battery → Unrestricted
```

---

### Error 11: Background Scanner Stops

**Symptom:** Device doesn't auto-reconnect after disconnect

**Cause:** Timer cancelled by system

**Fix:** Use WorkManager for guaranteed execution

**Recommended Implementation:**
```dart
import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔄 Background task triggered: $task');
    
    // Scan for saved device
    final deviceId = await StorageService().getSavedDeviceId();
    if (deviceId != null) {
      // Trigger scan
      await _scanForSavedDevice();
    }
    
    return Future.value(true);
  });
}

// Register periodic task
Workmanager().registerPeriodicTask(
  "auto_reconnect_scanner",
  "scanForDevice",
  frequency: Duration(minutes: 15), // Minimum is 15 min
);
```

---

## Authentication Errors

### Error 12: No Auth Token

**Error Message:**
```
❌ No auth token found. User may not be logged in.
```

**Cause:** User session expired or never logged in

**Fix:**
```dart
// Check auth before initializing
final authService = Provider.of<AuthService>(context, listen: false);
final token = await authService.getToken();

if (token == null || token.isEmpty) {
  print('❌ No valid auth token');
  
  // Redirect to login
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  });
  return;
}
```

---

### Error 13: OAuth Credentials Error

**Error Message:**
```
❌ Error initializing Dio: No such module 'googleapis.oauth2.credentials'
```

**Cause:** Python OAuth import issue (if using Python backend)

**Fix:** This is a backend issue, not mobile app issue

**Workaround:** Use JWT tokens instead of OAuth
```dart
// Configure Dio with JWT
_dio = Dio(BaseOptions(
  baseUrl: 'https://api.hireforcare.com',
  headers: {
    'Authorization': 'Bearer $jwtToken',
    'Content-Type': 'application/json',
  },
));
```

---

## Debugging Techniques

### Technique 1: Enable Verbose Logging

```dart
// Add at top of _HC20HomePageState
static const bool _debugMode = true;

void _log(String message) {
  if (_debugMode) {
    print('[${DateTime.now().toIso8601String()}] $message');
  }
}

// Usage
_log('🔍 Starting device scan...');
```

---

### Technique 2: Connection State Debugger

```dart
// Add to build method
if (_debugMode) {
  return Column(
    children: [
      _buildDebugPanel(),
      Expanded(child: _buildMainUI()),
    ],
  );
}

Widget _buildDebugPanel() {
  return Container(
    color: Colors.black87,
    padding: EdgeInsets.all(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🔧 DEBUG INFO', style: TextStyle(color: Colors.yellow)),
        Text('Connected: $_isConnected', style: TextStyle(color: Colors.white)),
        Text('Reconnecting: $_isReconnecting', style: TextStyle(color: Colors.white)),
        Text('Auto-reconnecting: $_isAutoReconnecting', style: TextStyle(color: Colors.white)),
        Text('Scanning: $_isScanning', style: TextStyle(color: Colors.white)),
        Text('Reconnect Attempts: $_reconnectAttempts', style: TextStyle(color: Colors.white)),
        Text('Saved Device: $_savedDeviceId', style: TextStyle(color: Colors.white)),
        Text('Last Data: ${_lastDataReceived?.toString() ?? "Never"}', style: TextStyle(color: Colors.white)),
      ],
    ),
  );
}
```

---

### Technique 3: Timer Status Monitor

```dart
void _logTimerStatus() {
  print('\n📊 ========== TIMER STATUS ==========');
  print('Real-time subscription: ${_realtimeSubscription != null ? "Active" : "Inactive"}');
  print('Webhook timer: ${_dataRefreshTimer?.isActive ?? false ? "Active" : "Inactive"}');
  print('HRV refresh timer: ${_hrvRefreshTimer?.isActive ?? false ? "Active" : "Inactive"}');
  print('Connection monitor: ${_connectionMonitor?.isActive ?? false ? "Active" : "Inactive"}');
  print('Auto-reconnect scanner: ${_autoReconnectScanner?.isActive ?? false ? "Active" : "Inactive"}');
  print('=====================================\n');
}

// Call periodically
Timer.periodic(Duration(minutes: 1), (_) => _logTimerStatus());
```

---

### Technique 4: Network Request Inspector

```dart
// Add Dio interceptor for debugging
_dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) {
    print('\n📤 REQUEST ============');
    print('URL: ${options.uri}');
    print('Method: ${options.method}');
    print('Headers: ${options.headers}');
    print('Body: ${options.data}');
    print('========================\n');
    return handler.next(options);
  },
  onResponse: (response, handler) {
    print('\n📥 RESPONSE ===========');
    print('Status: ${response.statusCode}');
    print('Data: ${response.data}');
    print('========================\n');
    return handler.next(response);
  },
  onError: (error, handler) {
    print('\n❌ ERROR =============');
    print('Type: ${error.type}');
    print('Message: ${error.message}');
    print('Response: ${error.response?.data}');
    print('========================\n');
    return handler.next(error);
  },
));
```

---

### Technique 5: Crash Reporter Integration

**Recommended: Add Sentry or Firebase Crashlytics**

```dart
// Add to pubspec.yaml
dependencies:
  sentry_flutter: ^7.0.0

// Initialize in main()
await SentryFlutter.init(
  (options) {
    options.dsn = 'https://your-sentry-dsn';
    options.tracesSampleRate = 1.0;
  },
  appRunner: () => runApp(MyApp()),
);

// Wrap errors
try {
  await _connectToDevice(device);
} catch (e, stackTrace) {
  Sentry.captureException(e, stackTrace: stackTrace);
  rethrow;
}
```

---

## Log Interpretation Guide

### Normal Operation Logs

```
✅ HC20 client initialized successfully
🔍 Starting device scan...
   📡 Found: HC20-1234 (XX:XX:XX:XX:XX:XX)
🔌 Connecting to HC20-1234...
✅ Connected successfully to HC20-1234
⏰ Syncing time with device...
✅ Time synced successfully
✅ Real-time data stream started
⏰ Starting 2-minute webhook timer...
📊 [Real-time] HR: 75 bpm, SpO2: 98%, Temp: 36.5°C
📤 Sending health data to webhook...
✅ Webhook sent successfully (200)
```

**Interpretation:** Perfect! All systems working.

---

### Reconnection Logs

```
❌ Real-time stream error: GATT operation failed
❌ Device may have disconnected or gone out of range
🔄 Device disconnected - attempting reconnection...
🔄 Reconnection attempt 1/3...
🧹 Cleaning up connections...
✓ Cleanup complete
🔄 Attempting to reconnect to HC20-1234...
✅ Reconnection successful!
✅ Real-time data stream started
```

**Interpretation:** Temporary disconnect, successfully recovered.

---

### Failed Reconnection Logs

```
🔄 Reconnection attempt 1/3...
❌ Reconnection attempt 1 failed: TimeoutException
🔄 Reconnection attempt 2/3...
❌ Reconnection attempt 2 failed: TimeoutException
🔄 Reconnection attempt 3/3...
❌ Reconnection attempt 3 failed: TimeoutException
❌ Max reconnection attempts (3) reached.
   Switching to background scanner mode...
🔍 Starting Auto-Reconnect Scanner
```

**Interpretation:** Device out of range, background scanner will keep trying.

---

### Webhook Error Logs

```
📤 Sending health data to webhook...
❌ Error sending webhook data: DioException [connection timeout]
❌ Connection timeout: The connection has timed out
```

**Interpretation:** Network issue, check internet connection.

---

### Permission Error Logs

```
❌ ========================================
❌ LOCATION PERMISSION REQUIRED
❌ ========================================
❌ Bluetooth scanning on Android requires location permission
```

**Interpretation:** User needs to grant location permission.

---

## Testing Checklist

### Pre-Release Testing

- [ ] **Connection Test**
  - [ ] Device found during scan
  - [ ] Connection successful
  - [ ] Time sync works
  - [ ] Real-time data streaming

- [ ] **Disconnection Test**
  - [ ] Turn off device → Auto-reconnect works
  - [ ] Walk out of range → Background scanner works
  - [ ] Reconnection after 30 seconds

- [ ] **Webhook Test**
  - [ ] Data sent every 2 minutes
  - [ ] Payload contains all fields
  - [ ] Disconnect webhook sent
  - [ ] Error handling works

- [ ] **Permission Test**
  - [ ] Location permission requested
  - [ ] Bluetooth permission requested
  - [ ] Battery optimization disabled
  - [ ] App works after permission grant

- [ ] **Background Test**
  - [ ] App works with screen off
  - [ ] Foreground service shows notification
  - [ ] Data continues streaming
  - [ ] Auto-reconnect works in background

- [ ] **Error Test**
  - [ ] Handle invalid phone number
  - [ ] Handle network timeout
  - [ ] Handle server error (500)
  - [ ] Handle invalid token (401)

- [ ] **UI Test**
  - [ ] Status messages update correctly
  - [ ] Buttons disabled during operations
  - [ ] Health data displayed correctly
  - [ ] No UI freezing during operations

---

## Emergency Troubleshooting Commands

### Reset Everything

```dart
// Add reset button for testing
void _emergencyReset() async {
  print('🚨 EMERGENCY RESET INITIATED');
  
  // Stop all timers
  _realtimeSubscription?.cancel();
  _dataRefreshTimer?.cancel();
  _hrvRefreshTimer?.cancel();
  _connectionMonitor?.cancel();
  _autoReconnectScanner?.cancel();
  
  // Clear saved data
  await StorageService().clearSavedDeviceId();
  
  // Reset state
  setState(() {
    _isConnected = false;
    _isScanning = false;
    _isReconnecting = false;
    _isAutoReconnecting = false;
    _connectedDevice = null;
    _savedDeviceId = null;
    _reconnectAttempts = 0;
  });
  
  // Reinitialize
  await _initializeHC20Client();
  
  print('✅ Reset complete - ready for fresh start');
}
```

---

## Next Steps

Continue to Part 7 for recommendations and best practices:

📄 **[Part 7: Recommendations & Best Practices →](07_RECOMMENDATIONS_BEST_PRACTICES.md)**

---

**End of Part 6**  
**Previous: [Part 5 - Auto-Reconnection](05_AUTO_RECONNECTION_SYSTEM.md)**  
**Next: [Part 7 - Recommendations](07_RECOMMENDATIONS_BEST_PRACTICES.md)**
