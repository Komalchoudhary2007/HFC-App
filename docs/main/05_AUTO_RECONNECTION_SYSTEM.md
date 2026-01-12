# Main.dart - Auto-Reconnection System Documentation

**Part 5 of 7**  
**Last Updated:** January 9, 2026  
**File:** `lib/main.dart` (Lines 990-1383)

---

## Table of Contents
1. [Auto-Reconnection Overview](#auto-reconnection-overview)
2. [Disconnection Detection](#disconnection-detection)
3. [Manual Reconnection (3 Attempts)](#manual-reconnection-3-attempts)
4. [Background Auto-Reconnect Scanner](#background-auto-reconnect-scanner)
5. [Saved Device Management](#saved-device-management)
6. [Disconnect Webhooks](#disconnect-webhooks)
7. [Network Connectivity Check](#network-connectivity-check)

---

## Auto-Reconnection Overview

The app uses a **2-tier reconnection strategy**:

```
Device Disconnects
   │
   ▼
Tier 1: IMMEDIATE RECONNECTION (3 attempts, 2s apart)
   │
   ├─── Attempt 1 (2s delay) ──→ Success? → Done ✅
   ├─── Attempt 2 (2s delay) ──→ Success? → Done ✅
   └─── Attempt 3 (2s delay) ──→ Success? → Done ✅
                                     │
                                     ▼ Failed
                          Tier 2: BACKGROUND SCANNER
                                     │
                                     ▼
                          Scan every 30 seconds
                                     │
                          ├─→ Device found? → Auto-connect
                          └─→ Not found? → Keep scanning
```

### Why 2 Tiers?

| Tier | When | Purpose | Battery Impact |
|------|------|---------|----------------|
| **Tier 1** | Immediate | Quick recovery from temporary disconnects | Low (only 3 attempts) |
| **Tier 2** | Long-term | Recover when device comes back in range | Medium (30s scans) |

---

## Disconnection Detection

### Multiple Detection Methods

```
┌─────────────────────────────────────┐
│     Disconnection Detection         │
├─────────────────────────────────────┤
│                                     │
│  Method 1: Real-Time Stream Error   │
│  ├─→ BLE connection lost           │
│  └─→ onError() callback triggered   │
│                                     │
│  Method 2: Connection Monitor       │
│  ├─→ No data for 12 minutes        │
│  └─→ Timer detects silence         │
│                                     │
│  Method 3: Manual Detection         │
│  ├─→ User reports disconnect       │
│  └─→ UI shows "Disconnected"       │
│                                     │
└─────────────────────────────────────┘
```

### Stream Error Detection

```dart
_realtimeSubscription = _client!.realtimeV2(device).listen(
  (data) {
    // Data received - connection OK
    _lastDataReceived = DateTime.now();
  },
  onError: (error) {
    // CONNECTION LOST!
    print('\n❌ Real-time stream error: $error');
    print('❌ Device may have disconnected or gone out of range');
    
    // Check error type
    if (error.toString().contains('disconnected') || 
        error.toString().contains('connection') ||
        error.toString().contains('GATT')) {
      print('🔄 Device disconnected - attempting reconnection...');
      _handleDisconnection();
    }
    
    setState(() {
      _statusMessage = 'Connection lost: $error';
    });
  },
);
```

### Silent Disconnection Detection

```dart
// Connection monitor checks every 30 seconds
_connectionMonitor = Timer.periodic(const Duration(seconds: 30), (timer) {
  if (!_isConnected || _connectedDevice == null) {
    timer.cancel();
    return;
  }
  
  final now = DateTime.now();
  if (_lastDataReceived != null) {
    final timeSinceLastData = now.difference(_lastDataReceived!).inSeconds;
    
    // If no data for 12 minutes (2 min timer × 6 cycles)
    if (timeSinceLastData > 720) {
      print('⚠️ [Monitor] No data for ${timeSinceLastData}s - device disconnected');
      _handleDisconnection();
    }
  }
});
```

---

## Manual Reconnection (3 Attempts)

**Location:** Lines 990-1041  
**Trigger:** Immediate after disconnect detection  
**Strategy:** 3 rapid attempts with 2-second delays

### Reconnection Flow Diagram

```
Disconnect Detected
   │
   ▼
Check if already reconnecting?
   │
   ├─── YES ──→ Skip (prevent duplicate attempts)
   │
   └─── NO ──→ Continue
                 │
                 ▼
         Check attempt counter
                 │
         ┌───────┴────────┐
         │                │
         ▼ < 3            ▼ ≥ 3
    Continue          Give Up
         │                │
         ▼                ▼
   Set flags:      Show message:
   _isReconnecting "Max attempts reached"
   _reconnectAttempts++    │
         │                └─→ Start Tier 2
         ▼                    (Background Scanner)
   Cleanup old
   connections
         │
         ▼
   Wait 2 seconds
         │
         ▼
   Try to connect
         │
    ┌────┴────┐
    │         │
    ▼ Success ▼ Failed
  Reset      Retry?
  counter      │
    │          └─→ Loop back if < 3 attempts
    │
    └─→ Resume normal operation
```

### Code Implementation

```dart
void _handleDisconnection() async {
  // STEP 1: Check if already reconnecting
  if (_isReconnecting) {
    print('⏳ Already attempting reconnection...');
    return;  // Prevent duplicate attempts
  }
  
  // STEP 2: Check max attempts
  if (_reconnectAttempts >= _maxReconnectAttempts) {
    print('❌ Max reconnection attempts (3) reached.');
    print('   Switching to background scanner mode...');
    
    setState(() {
      _statusMessage = 'Device disconnected. Scanning in background...';
      _isConnected = false;
    });
    
    _cleanup();  // Clean up resources
    return;  // Give up manual reconnection
  }
  
  // STEP 3: Set reconnection state
  _isReconnecting = true;
  _reconnectAttempts++;
  
  print('🔄 Reconnection attempt $_reconnectAttempts/$_maxReconnectAttempts...');
  
  setState(() {
    _statusMessage = 'Reconnecting... (Attempt $_reconnectAttempts/3)';
  });
  
  // STEP 4: Cleanup old connections
  _cleanup();
  
  // STEP 5: Wait before reconnecting (debounce)
  await Future.delayed(Duration(seconds: 2));
  
  // STEP 6: Try to reconnect
  if (_connectedDevice != null && _client != null) {
    try {
      print('🔄 Attempting to reconnect to ${_connectedDevice!.name}...');
      
      // Call the full connection method
      await _connectToDevice(_connectedDevice!);
      
      print('✅ Reconnection successful!');
      
      // Reset counter on success
      _reconnectAttempts = 0;
      
    } catch (e) {
      print('❌ Reconnection attempt $_reconnectAttempts failed: $e');
      
      setState(() {
        _statusMessage = 'Reconnection failed. Retrying...';
      });
      
      // Try again if we have attempts left
      await Future.delayed(Duration(seconds: 3));
      
      if (_reconnectAttempts < _maxReconnectAttempts) {
        _isReconnecting = false;
        _handleDisconnection();  // Recursive call for next attempt
      } else {
        print('❌ All reconnection attempts exhausted');
        print('   Background scanner will continue trying...');
      }
    }
  }
  
  _isReconnecting = false;
}
```

### Cleanup Process

```dart
void _cleanup() {
  print('🧹 Cleaning up connections...');
  
  // Cancel real-time subscription
  _realtimeSubscription?.cancel();
  _realtimeSubscription = null;
  
  // DON'T cancel _dataRefreshTimer!
  // It should keep running to send disconnect webhooks
  
  // Cancel connection monitor
  _connectionMonitor?.cancel();
  _connectionMonitor = null;
  
  // Cancel HRV refresh timer
  _hrvRefreshTimer?.cancel();
  _hrvRefreshTimer = null;
  
  print('✓ Cleanup complete');
}
```

### Why Keep Webhook Timer Running?

```
Device Disconnected
   │
   ▼
Webhook Timer Still Running (Every 2 min)
   │
   ├─→ Check: Is connected?
   │      │
   │      └─→ NO → Send disconnect webhook
   │                │
   │                └─→ Backend knows device is offline
   │
   └─→ This allows backend to track disconnect duration
```

---

## Background Auto-Reconnect Scanner

**Location:** Lines 1289-1383  
**Trigger:** Automatically when device ID is saved  
**Frequency:** Every 30 seconds  
**Purpose:** Long-term reconnection for devices that go out of range

### Scanner Flow Diagram

```
App Starts / Device Connects
   │
   ▼
Save Device ID to Storage
   │
   ▼
Start Background Scanner
   │
   ▼
Timer: Every 30 seconds
   │
   ├──→ Is already connected? ──→ YES → Skip this cycle
   │
   ├──→ Is already scanning? ──→ YES → Skip this cycle
   │
   └──→ Is auto-reconnecting? ──→ YES → Skip this cycle
         │
         └─→ NO → Start Scan
                    │
                    ▼
            Scan for 10 seconds
                    │
            ┌───────┴────────┐
            │                │
            ▼ Found          ▼ Not Found
       Auto-Connect      Log & Continue
            │                │
            ▼                │
       Connection OK         │
            │                │
            └────────────────┘
                    │
                    ▼
            Wait 30 seconds
                    │
                    └──→ Loop back to start
```

### Initialization

```dart
void _startAutoReconnectScanner() {
  if (_savedDeviceId == null || _savedDeviceId!.isEmpty) {
    print('ℹ️  No saved device - auto-reconnect scanner not started');
    return;
  }

  // Cancel any existing scanner
  _autoReconnectScanner?.cancel();

  print('\n🔍 ========================================');
  print('🔍 Starting Auto-Reconnect Scanner');
  print('🔍 Target Device: $_savedDeviceId');
  print('🔍 Scan interval: Every 30 seconds');
  print('🔍 Auto-connects when device is nearby');
  print('🔍 ========================================\n');

  // Set up periodic timer
  _autoReconnectScanner = Timer.periodic(
    const Duration(seconds: 30), 
    (timer) async {
      // Skip if already in good state
      if (_isConnected || _isAutoReconnecting || _isScanning) {
        return;
      }

      print('⏰ [Auto-Reconnect] Scanning for saved device...');
      await _scanForSavedDevice();
    }
  );

  // Do immediate first scan (after 2s delay)
  Future.delayed(const Duration(seconds: 2), () {
    if (!_isConnected && !_isAutoReconnecting) {
      _scanForSavedDevice();
    }
  });
}
```

### Scan Implementation

```dart
Future<void> _scanForSavedDevice() async {
  if (_savedDeviceId == null || _isConnected || _isAutoReconnecting) {
    return;  // Safety check
  }

  // STEP 1: Initialize client if needed
  if (_client == null) {
    await _initializeHC20Client();
    if (_client == null) {
      print('⚠️ [Auto-Reconnect] Failed to initialize HC20 client');
      return;
    }
  }

  // STEP 2: Set scanning flag
  setState(() {
    _isAutoReconnecting = true;
  });

  print('🔍 [Auto-Reconnect] Scanning for device: $_savedDeviceId');

  try {
    Hc20Device? foundDevice;
    
    // STEP 3: Listen for scanned devices
    final subscription = _client!.scan().listen(
      (device) {
        print('   📡 Found: ${device.name} (${device.id})');
        
        // Check if this is our saved device
        if (device.id == _savedDeviceId) {
          print('   ✅ MATCH! This is the saved device');
          foundDevice = device;
        }
      },
      onError: (error) {
        print('⚠️ [Auto-Reconnect] Scan error: $error');
      },
    );

    // STEP 4: Wait 10 seconds for scan
    await Future.delayed(const Duration(seconds: 10));
    subscription.cancel();

    // STEP 5: Connect if found
    if (foundDevice != null) {
      print('🔌 [Auto-Reconnect] Connecting to saved device...');
      
      setState(() {
        _statusMessage = '🔄 Auto-connecting to ${foundDevice!.name}...';
      });
      
      await _connectToDevice(foundDevice!);
      
      print('✅ [Auto-Reconnect] Connection successful!');
    } else {
      print('ℹ️  [Auto-Reconnect] Saved device not found nearby');
      print('   Will try again in 30 seconds...');
    }
    
  } catch (e) {
    print('⚠️ [Auto-Reconnect] Error: $e');
  } finally {
    // STEP 6: Clear flag
    setState(() {
      _isAutoReconnecting = false;
    });
  }
}
```

### Battery Impact Analysis

| Scenario | BLE Scans/Hour | Battery Drain |
|----------|----------------|---------------|
| **Always Connected** | 0 | ~1%/hour |
| **Frequent Disconnects** | 120 (2 per min) | ~5%/hour |
| **Background Scanner** | 2 (once per 30s) | ~2%/hour |

**Optimization:** Scanner only runs when disconnected, minimizing battery impact.

---

## Saved Device Management

**Location:** Lines 1271-1288  
**Purpose:** Remember last connected device for auto-reconnect

### Save Device on Connection

```dart
Future<void> _saveDeviceForAutoReconnect(String deviceId) async {
  try {
    // Save to secure local storage
    await StorageService().saveDeviceId(deviceId);
    
    setState(() {
      _savedDeviceId = deviceId;
    });
    
    print('💾 Device ID saved for auto-reconnect: $deviceId');
    print('   Device will auto-connect when nearby');
    
    // Start scanner if not already running
    if (_autoReconnectScanner == null || !_autoReconnectScanner!.isActive) {
      _startAutoReconnectScanner();
    }
  } catch (e) {
    print('⚠️ Error saving device ID: $e');
  }
}
```

### Load Saved Device on App Start

```dart
Future<void> _loadSavedDevice() async {
  try {
    final deviceId = await StorageService().getSavedDeviceId();
    
    if (deviceId != null && deviceId.isNotEmpty) {
      print('✅ Loaded saved device: $deviceId');
      
      setState(() {
        _savedDeviceId = deviceId;
      });
      
      print('🔍 Starting auto-reconnect scanner...');
      _startAutoReconnectScanner();
    } else {
      print('ℹ️  No saved device found');
    }
  } catch (e) {
    print('⚠️ Error loading saved device: $e');
  }
}
```

### StorageService Implementation

```dart
class StorageService {
  final _storage = FlutterSecureStorage();
  
  static const String _deviceIdKey = 'saved_device_id';
  
  // Save device ID
  Future<void> saveDeviceId(String deviceId) async {
    await _storage.write(key: _deviceIdKey, value: deviceId);
  }
  
  // Load device ID
  Future<String?> getSavedDeviceId() async {
    return await _storage.read(key: _deviceIdKey);
  }
  
  // Clear device ID
  Future<void> clearSavedDeviceId() async {
    await _storage.delete(key: _deviceIdKey);
  }
}
```

---

## Disconnect Webhooks

**Location:** Lines 1226-1254  
**Purpose:** Notify backend when device cannot reconnect

### Disconnect Webhook Payload

```json
{
  "phone": "+919876543210",
  "deviceId": "HC20-1234",
  "heartRate": null,
  "spo2": null,
  "bloodPressure": null,
  "temperature": null,
  "batteryLevel": null,
  "steps": null,
  "status": null,
  "message": "Device Disconnect",
  "errorType": "Device Disconnect",
  "timestamp": "2026-01-09T08:00:00.000+05:30"
}
```

### Implementation

```dart
Future<void> _sendDisconnectWebhook(String phone, {String reason = 'Device Disconnect'}) async {
  try {
    print('📤 Sending disconnect webhook: $reason');
    
    final response = await _dio.post(
      _webhookUrl,
      data: {
        'phone': phone,
        'deviceId': _connectedDevice?.id ?? _savedDeviceId ?? 'unknown',
        
        // All health metrics are NULL (indicates disconnect)
        'heartRate': null,
        'spo2': null,
        'bloodPressure': null,
        'temperature': null,
        'batteryLevel': null,
        'steps': null,
        'status': null,
        
        // Error information
        'message': reason,
        'errorType': reason,  // 'Device Disconnect' or 'Network Disconnect'
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    if (response.statusCode == 200) {
      print('✅ Disconnect webhook sent successfully');
      print('   Reason: $reason');
    } else {
      print('❌ Webhook failed: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Webhook error: $e');
  }
}
```

### Backend Detection Logic

```javascript
// Backend can identify disconnects by checking for null values
app.post('/webhook/hc20-data', (req, res) => {
  const { heartRate, errorType, timestamp } = req.body;
  
  if (heartRate === null && errorType) {
    // DISCONNECT DETECTED
    console.log(`🔴 Device disconnect: ${errorType}`);
    
    // Record disconnect event
    await db.disconnectEvents.create({
      device_id: req.body.deviceId,
      disconnect_type: errorType,
      timestamp: new Date(timestamp),
    });
    
    // Notify caregiver
    await notifyCaregiver(req.body.phone, errorType);
  } else {
    // Normal data
    await saveHealthData(req.body);
  }
  
  res.json({ success: true });
});
```

---

## Network Connectivity Check

**Location:** Lines 1257-1269  
**Purpose:** Distinguish between device disconnect and network disconnect

### Check Implementation

```dart
Future<bool> _checkNetworkConnectivity() async {
  try {
    // Try to reach backend health endpoint
    final result = await _dio.get(
      'https://api.hireforcare.com/health',
      options: Options(receiveTimeout: const Duration(seconds: 5)),
    );
    
    // If we get here, network is OK
    return result.statusCode != 200;  // Return true if network issue
    
  } catch (e) {
    // Network error = network disconnect
    print('⚠️ Network check failed: $e');
    return true;  // Network is down
  }
}
```

### Usage in Timer

```dart
if (!_isConnected && _connectedDevice != null) {
  // Device disconnected - determine reason
  bool isNetworkIssue = await _checkNetworkConnectivity();
  
  String disconnectReason = isNetworkIssue 
      ? 'Network Disconnect'   // Mobile has no internet
      : 'Device Disconnect';   // HC20 device out of range
  
  await _sendDisconnectWebhook(user.phone, reason: disconnectReason);
}
```

### Disconnect Types

| Type | Meaning | User Action |
|------|---------|-------------|
| **Device Disconnect** | HC20 out of range/powered off | Bring device closer or charge it |
| **Network Disconnect** | Phone has no internet | Enable WiFi or mobile data |

---

## Reconnection Timeline Example

### Scenario: User Walks Away from Device

```
Time     Event                              Action
─────────────────────────────────────────────────────────────
00:00    Device connected, streaming        Normal operation
00:30    User walks 50 meters away          No immediate effect
01:00    BLE signal weakens                 Connection unstable
01:15    Connection lost                    Disconnect detected!
01:15    → Tier 1 Attempt 1                Start reconnection
01:17    → Tier 1 Attempt 1 failed         Device still out of range
01:19    → Tier 1 Attempt 2                Retry
01:21    → Tier 1 Attempt 2 failed         Still out of range
01:23    → Tier 1 Attempt 3                Last attempt
01:25    → Tier 1 Attempt 3 failed         Switch to Tier 2
01:25    → Start background scanner        Scan every 30s
01:55    Background scan #1                Device not found
02:25    Background scan #2                Device not found
02:55    Background scan #3                Device not found
03:00    User returns with device          Device in range
03:25    Background scan #4                Device found!
03:26    → Auto-connect initiated          Connecting...
03:30    → Connection successful           Resume normal operation ✅
```

---

## Common Issues & Solutions

### Issue 1: Reconnection Loop
**Symptoms:** Constantly reconnecting and disconnecting  
**Cause:** Weak signal (device at edge of range)  
**Solution:** Ask user to keep device within 5 meters

### Issue 2: Background Scanner Not Working
**Symptoms:** Device never auto-reconnects  
**Cause:** Battery optimization killing scanner  
**Solution:** Ensure battery optimization disabled

### Issue 3: Multiple Connection Attempts
**Symptoms:** Logs show duplicate reconnection attempts  
**Cause:** `_isReconnecting` flag not properly set  
**Solution:** Check flag at start of `_handleDisconnection()`

### Issue 4: Scanner Draining Battery
**Symptoms:** High battery usage when disconnected  
**Cause:** Scanner interval too short  
**Solution:** 30 seconds is optimal, don't decrease

---

## Best Practices

### ✅ DO
- Check `_isReconnecting` flag before starting
- Reset attempt counter on successful connection
- Keep webhook timer running during disconnect
- Save device ID after every successful connection
- Clean up resources before reconnecting
- Use background scanner for long-term recovery

### ❌ DON'T
- Start multiple reconnection attempts simultaneously
- Cancel webhook timer on disconnect
- Scan continuously (battery drain)
- Give up after 3 attempts (use background scanner)
- Forget to reset `_reconnectAttempts` on success
- Block UI thread with reconnection logic

---

## Recommendations for Improvements

### 🎯 Improvement 1: Exponential Backoff
**Current:** Fixed 2-second delay  
**Better:** Increase delay with each attempt

```dart
final delay = Duration(seconds: 2 * _reconnectAttempts);
await Future.delayed(delay);
```

### 🎯 Improvement 2: Signal Strength Monitoring
**Current:** No signal strength tracking  
**Better:** Monitor RSSI before disconnect

```dart
if (device.rssi != null && device.rssi! < -85) {
  print('⚠️ Weak signal detected, connection may drop');
  // Show warning to user
}
```

### 🎯 Improvement 3: User Notification
**Current:** Only status message  
**Better:** Push notification when reconnected

```dart
if (reconnectionSuccessful) {
  showNotification(
    title: 'Device Reconnected',
    body: 'Your HC20 is back online',
  );
}
```

### 🎯 Improvement 4: Reconnection History
**Current:** No tracking  
**Better:** Log all reconnection attempts

```dart
class ReconnectionLog {
  DateTime timestamp;
  String deviceId;
  int attemptNumber;
  bool success;
  String error;
}
```

---

## Next Steps

Continue to Part 6 for error handling and troubleshooting:

📄 **[Part 6: Error Handling & Troubleshooting →](06_ERROR_HANDLING_TROUBLESHOOTING.md)**

---

**End of Part 5**  
**Previous: [Part 4 - Data Streaming](04_DATA_STREAMING_WEBHOOKS.md)**  
**Next: [Part 6 - Error Handling](06_ERROR_HANDLING_TROUBLESHOOTING.md)**
