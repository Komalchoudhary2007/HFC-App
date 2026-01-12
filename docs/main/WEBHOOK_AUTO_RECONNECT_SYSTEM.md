# Webhook & Auto-Reconnect System Documentation

**Last Updated:** January 9, 2026  
**Version:** 1.0  
**Status:** Currently Implemented ✅

---

## Table of Contents
1. [Overview](#overview)
2. [Current Implementation](#current-implementation)
3. [System Components](#system-components)
4. [Data Flow](#data-flow)
5. [Alternative Implementation](#alternative-implementation)
6. [Comparison & Recommendations](#comparison--recommendations)
7. [Code References](#code-references)

---

## Overview

This document explains how the HFC App handles:
- **Periodic data collection** from HC20 devices (every 2 minutes)
- **Automatic reconnection** when device disconnects
- **Webhook notifications** to backend API
- **Disconnect alerts** when connection fails

### Key Requirements
✅ Send device data to webhook every 2 minutes  
✅ Detect when device disconnects  
✅ Automatically reconnect to device  
✅ Send disconnect notification if reconnection fails  
✅ Work in background (even when app is minimized)

---

## Current Implementation

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    HFC Mobile App                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐      ┌──────────────────┐            │
│  │ Real-time Data  │      │  Webhook Timer   │            │
│  │    Stream       │      │  (120 seconds)   │            │
│  │  (continuous)   │      │                  │            │
│  └────────┬────────┘      └────────┬─────────┘            │
│           │                        │                       │
│           ▼                        ▼                       │
│  ┌─────────────────────────────────────────┐              │
│  │  _sendDataToWebhook()                   │              │
│  │  - Sends health data to backend         │              │
│  │  - Handles success/error states         │              │
│  └─────────────────┬───────────────────────┘              │
│                    │                                       │
│           ┌────────┴────────┐                             │
│           ▼                 ▼                              │
│  ┌──────────────┐  ┌─────────────────┐                   │
│  │   Success    │  │ Error/Timeout   │                   │
│  │   Update UI  │  │ _handleDisconnect│                   │
│  └──────────────┘  └────────┬────────┘                   │
│                              │                             │
│                              ▼                             │
│                     ┌─────────────────┐                   │
│                     │ Auto-Reconnect  │                   │
│                     │ (max 3 attempts)│                   │
│                     └────────┬────────┘                   │
│                              │                             │
│                     ┌────────┴─────────┐                  │
│                     ▼                  ▼                   │
│            ┌──────────────┐   ┌──────────────┐           │
│            │  Reconnected │   │    Failed    │           │
│            │  Resume data │   │Send Disconnect│           │
│            └──────────────┘   └──────────────┘           │
│                                                             │
│  ┌─────────────────────────────────────────┐              │
│  │  Background Auto-Reconnect Scanner      │              │
│  │  (runs every 30 seconds)                │              │
│  │  - Scans for saved device when offline  │              │
│  │  - Auto-connects when device is nearby  │              │
│  └─────────────────────────────────────────┘              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## System Components

### 1. Real-Time Data Stream
**Location:** `lib/main.dart` - `_startRealtimeDataStream()`  
**Trigger:** When device connects successfully  
**Frequency:** Continuous (event-driven)

**Functionality:**
```dart
_realtimeSubscription = _client!.realtimeV2(device).listen(
  (data) {
    // Data received from device
    _lastDataReceived = DateTime.now();
    
    // Update UI
    setState(() {
      _heartRate = data.heart;
      _spo2 = data.spo2;
      // ... other vitals
    });
    
    // Send to webhook immediately
    _sendDataToWebhook(device, data);
  },
  onError: (error) {
    // Connection lost - trigger reconnection
    _handleDisconnection();
  }
);
```

**Key Features:**
- ✅ Receives data as soon as device sends it
- ✅ Updates UI in real-time
- ✅ Automatically detects disconnections
- ✅ Triggers reconnection on error

---

### 2. Webhook Timer (2-Minute Periodic Check)
**Location:** `lib/main.dart` - `_startRealtimeDataStream()` (lines 833-877)  
**Trigger:** Every 120 seconds (2 minutes)  
**Purpose:** Ensure regular data updates even if device doesn't send spontaneously

**Functionality:**
```dart
_dataRefreshTimer = Timer.periodic(const Duration(seconds: 120), (timer) async {
  if (_isConnected && _connectedDevice != null) {
    // Device connected - request fresh data
    print('✅ Device connected - requesting fresh data...');
    _client!.realtimeV2(device).listen(
      (data) {
        print('✅ Fresh data received, webhook will be sent automatically');
      }
    );
  } else {
    // Device disconnected - send null webhook with error
    print('⚠️ Device DISCONNECTED - sending disconnect webhook...');
    
    bool isNetworkIssue = await _checkNetworkConnectivity();
    String disconnectReason = isNetworkIssue 
        ? 'Network Disconnect' 
        : 'Device Disconnect';
    
    await _sendDisconnectWebhook(user.phone, reason: disconnectReason);
  }
});
```

**Key Features:**
- ✅ Forces data refresh every 2 minutes
- ✅ Detects silent disconnections
- ✅ Sends disconnect notification immediately
- ✅ Distinguishes between network/device issues

---

### 3. Webhook Sender
**Location:** `lib/main.dart` - `_sendDataToWebhook()` (lines 1084-1224)  
**Purpose:** Send health data to backend API  
**Endpoint:** `https://api.hireforcare.com/webhook/hc20-data`

**Payload Structure:**
```json
{
  "timestamp": "2026-01-09T08:00:00.000+05:30",
  "stress_alert": false,
  "device": {
    "id": "DEVICE_ID",
    "name": "HC20-XXXX"
  },
  "realtime_data": {
    "heart_rate": 72,
    "rri": [800, 810, 795],
    "spo2": 98,
    "blood_pressure": {
      "systolic": 120,
      "diastolic": 80
    },
    "temperature": [36.5],
    "battery": {
      "percent": 85,
      "charge": true
    },
    "basic_data": [5000, 250, 3500],
    "wear_status": 1,
    "hrv_metrics": {
      "sdnn": 45,
      "tp": 1200,
      "lf": 600,
      "hf": 400,
      "vlf": 200
    },
    "hrv2_metrics": {
      "mental_stress": 3,
      "fatigue_level": 2,
      "stress_resistance": 4,
      "regulation_ability": 4
    }
  }
}
```

**Error Handling:**
| Error Type | Description | Action |
|------------|-------------|--------|
| `connectionTimeout` | Backend took >5s | Retry next cycle |
| `sendTimeout` | Data send took >5s | Retry next cycle |
| `receiveTimeout` | No response in 5s | Retry next cycle |
| `badResponse` | HTTP 4xx/5xx error | Log error, continue |
| `connectionError` | Network unreachable | Check WiFi/Mobile data |
| `badCertificate` | SSL error | Report to backend team |

---

### 4. Auto-Reconnection Handler
**Location:** `lib/main.dart` - `_handleDisconnection()` (lines 990-1041)  
**Trigger:** When real-time stream errors or data timeout  
**Max Attempts:** 3 reconnections

**Functionality:**
```dart
void _handleDisconnection() async {
  if (_isReconnecting) return;
  
  if (_reconnectAttempts >= _maxReconnectAttempts) {
    setState(() {
      _statusMessage = 'Device disconnected. Please reconnect manually.';
      _isConnected = false;
    });
    _cleanup();
    return;
  }
  
  _isReconnecting = true;
  _reconnectAttempts++;
  
  print('🔄 Reconnection attempt $_reconnectAttempts/$_maxReconnectAttempts...');
  
  _cleanup(); // Clean old connections
  await Future.delayed(Duration(seconds: 2));
  
  if (_connectedDevice != null && _client != null) {
    try {
      await _connectToDevice(_connectedDevice!);
      print('✅ Reconnection successful!');
      _reconnectAttempts = 0; // Reset on success
    } catch (e) {
      print('❌ Reconnection failed: $e');
      if (_reconnectAttempts < _maxReconnectAttempts) {
        _isReconnecting = false;
        _handleDisconnection(); // Retry
      }
    }
  }
  
  _isReconnecting = false;
}
```

**Reconnection Strategy:**
1. Detect disconnection
2. Wait 2 seconds (debounce)
3. Attempt reconnection
4. If failed, retry (max 3 times)
5. If all failed, wait for background scanner

---

### 5. Background Auto-Reconnect Scanner
**Location:** `lib/main.dart` - `_startAutoReconnectScanner()` (lines 1291-1324)  
**Trigger:** Automatically when device ID is saved  
**Frequency:** Every 30 seconds  
**Purpose:** Long-term reconnection for devices out of range

**Functionality:**
```dart
_autoReconnectScanner = Timer.periodic(const Duration(seconds: 30), (timer) async {
  if (_isConnected || _isAutoReconnecting || _isScanning) {
    return; // Skip if already connected
  }
  
  print('🔍 [Auto-Reconnect] Scanning for saved device...');
  await _scanForSavedDevice();
});
```

**Scan Process:**
```dart
Future<void> _scanForSavedDevice() async {
  if (_savedDeviceId == null || _isConnected) return;
  
  // Initialize client if needed
  if (_client == null) {
    await _initializeHC20Client();
  }
  
  setState(() { _isAutoReconnecting = true; });
  
  Hc20Device? foundDevice;
  
  // Scan for 10 seconds
  final subscription = _client!.scan().listen(
    (device) {
      if (device.id == _savedDeviceId) {
        foundDevice = device;
      }
    }
  );
  
  await Future.delayed(const Duration(seconds: 10));
  subscription.cancel();
  
  // If found, auto-connect
  if (foundDevice != null) {
    await _connectToDevice(foundDevice!);
  }
  
  setState(() { _isAutoReconnecting = false; });
}
```

**Key Features:**
- ✅ Works even when app is backgrounded
- ✅ Doesn't drain battery (only scans when disconnected)
- ✅ Remembers last connected device
- ✅ Auto-connects when device comes in range

---

### 6. Disconnect Webhook
**Location:** `lib/main.dart` - `_sendDisconnectWebhook()` (lines 1226-1254)  
**Purpose:** Notify backend when device cannot reconnect

**Payload:**
```json
{
  "phone": "+91XXXXXXXXXX",
  "deviceId": "DEVICE_ID",
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

**Disconnect Types:**
- **Device Disconnect:** HC20 device out of range or powered off
- **Network Disconnect:** Mobile app has no internet connection

---

## Data Flow

### Flow Diagram: 2-Minute Timer Cycle

```
┌─────────────────────────────────────────┐
│ Timer triggers every 2 minutes (120s)  │
└─────────────┬───────────────────────────┘
              │
              ▼
       ┌──────────────┐
       │ Is Connected? │
       └──────┬───────┘
              │
      ┌───────┴────────┐
      │                │
      ▼ YES            ▼ NO
┌─────────────┐  ┌──────────────────┐
│ Request     │  │ Send Disconnect  │
│ Fresh Data  │  │ Webhook (null)   │
└─────┬───────┘  └──────────────────┘
      │
      ▼
┌──────────────────┐
│ Device Responds? │
└──────┬───────────┘
       │
   ┌───┴───┐
   │       │
   ▼ YES   ▼ NO (timeout/error)
┌────────┐ ┌─────────────────┐
│ Send   │ │ Call            │
│ Webhook│ │_handleDisconnect│
└────────┘ └────────┬────────┘
                    │
                    ▼
           ┌─────────────────┐
           │ Reconnect Tries │
           │ (max 3 attempts)│
           └────────┬────────┘
                    │
            ┌───────┴────────┐
            │                │
            ▼ Success        ▼ Failed (after 3 tries)
    ┌──────────────┐  ┌──────────────────────┐
    │ Resume       │  │ Background Scanner   │
    │ Data Stream  │  │ takes over (30s)     │
    │ Reset counter│  │                      │
    └──────────────┘  └──────────────────────┘
```

### Timeline Example: Device Disconnect Scenario

```
Time    Event
──────────────────────────────────────────────────────────
00:00   Device connected, streaming data
00:30   User moves away, device disconnects
00:30   Real-time stream error detected
00:30   _handleDisconnection() called (attempt 1/3)
00:32   Reconnection failed (device out of range)
00:35   _handleDisconnection() retry (attempt 2/3)
00:37   Reconnection failed
00:40   _handleDisconnection() retry (attempt 3/3)
00:42   Reconnection failed - max attempts reached
00:42   Background scanner takes over
02:00   Timer triggers - sends disconnect webhook
02:12   Background scanner finds device
02:12   Auto-reconnects successfully
02:15   Data streaming resumes
04:00   Timer triggers - sends normal webhook with data
```

---

## Alternative Implementation

### Proposed Flow (Modified Approach)

Some users may prefer a flow where the timer **attempts reconnection before sending disconnect webhook**:

```
┌─────────────────────────────────────────┐
│ Timer triggers every 2 minutes (120s)  │
└─────────────┬───────────────────────────┘
              │
              ▼
       ┌──────────────┐
       │ Is Connected? │
       └──────┬───────┘
              │
      ┌───────┴────────┐
      │                │
      ▼ YES            ▼ NO
┌─────────────┐  ┌──────────────────────┐
│ Request     │  │ Try Auto-Reconnect   │
│ Fresh Data  │  │ (scan 10s + wait)    │
└─────┬───────┘  └────────┬─────────────┘
      │                   │
      ▼               ┌───┴────┐
┌──────────┐         │        │
│ Send     │         ▼ YES    ▼ NO
│ Webhook  │    ┌─────────┐  ┌──────────┐
└──────────┘    │ Request │  │ Send     │
                │ Data &  │  │Disconnect│
                │ Send    │  │ Webhook  │
                │ Webhook │  └──────────┘
                └─────────┘
```

### Implementation Code

```dart
_dataRefreshTimer = Timer.periodic(const Duration(seconds: 120), (timer) async {
  try {
    print('\n⏰ [Timer] 2-minute webhook timer triggered');
    
    if (_isConnected && _connectedDevice != null) {
      // Device connected - request fresh data
      print('   ✅ Device connected - requesting fresh data...');
      
      bool dataReceived = false;
      
      try {
        // Try to get fresh data with timeout
        final dataSubscription = _client!.realtimeV2(device).listen(
          (data) {
            dataReceived = true;
            print('   ✅ Fresh data received, sending webhook...');
            _sendDataToWebhook(device, data);
          }, 
          onError: (e) {
            print('   ⚠️ Error receiving data: $e');
          }
        );
        
        // Wait max 10 seconds for data
        await Future.delayed(Duration(seconds: 10));
        dataSubscription.cancel();
        
        if (!dataReceived) {
          print('   ❌ No data received - triggering reconnection...');
          _handleDisconnection();
        }
        
      } catch (e) {
        print('   ❌ Error requesting data: $e');
        _handleDisconnection();
      }
      
    } else {
      // Device disconnected - try to reconnect first
      print('   ⚠️ Device DISCONNECTED - attempting reconnection...');
      
      // Try auto-reconnect
      await _scanForSavedDevice();
      
      // Wait for reconnection
      await Future.delayed(Duration(seconds: 15));
      
      if (_isConnected && _connectedDevice != null) {
        // Reconnected! Request data
        print('   ✅ Reconnected! Requesting data...');
        
        bool dataReceived = false;
        final dataSubscription = _client!.realtimeV2(device).listen(
          (data) {
            dataReceived = true;
            print('   ✅ Data received after reconnect, sending webhook...');
            _sendDataToWebhook(device, data);
          }
        );
        
        await Future.delayed(Duration(seconds: 10));
        dataSubscription.cancel();
        
        if (!dataReceived) {
          print('   ⚠️ Reconnected but no data - sending disconnect webhook...');
          await _sendDisconnectWebhookHelper();
        }
        
      } else {
        // Failed to reconnect - send disconnect webhook
        print('   ❌ Reconnection failed - sending disconnect webhook...');
        await _sendDisconnectWebhookHelper();
      }
    }
    
    print('⏰ Timer execution completed\n');
  } catch (e) {
    print('   ❌ CRITICAL ERROR in timer callback: $e');
  }
});

// Helper method
Future<void> _sendDisconnectWebhookHelper() async {
  try {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user != null) {
      bool isNetworkIssue = await _checkNetworkConnectivity();
      String disconnectReason = isNetworkIssue 
          ? 'Network Disconnect' 
          : 'Device Disconnect';
      await _sendDisconnectWebhook(user.phone, reason: disconnectReason);
    }
  } catch (e) {
    print('   ❌ Error sending disconnect webhook: $e');
  }
}
```

---

## Comparison & Recommendations

### Current Implementation (Recommended ✅)

**Pros:**
- ✅ **Fast notifications**: Backend knows about disconnects within 2 minutes
- ✅ **Parallel processing**: Reconnection happens independently in background
- ✅ **Battery efficient**: Doesn't force scan on every timer tick
- ✅ **Simpler code**: Less nested conditions, easier to debug
- ✅ **Separation of concerns**: Monitoring and reconnecting are independent
- ✅ **Already tested**: Working in production

**Cons:**
- ⚠️ May send disconnect webhook even if device reconnects within 2 minutes
- ⚠️ Backend receives disconnect notification before reconnection attempts complete

**Best for:**
- Healthcare monitoring (fast alerts critical)
- Compliance requirements (must notify immediately)
- Production environments (proven and stable)

---

### Alternative Implementation

**Pros:**
- ✅ Fewer false disconnect notifications
- ✅ Attempts reconnection before alerting backend
- ✅ More "forgiving" for temporary disconnects

**Cons:**
- ❌ **Delayed notifications**: Backend notified 15-25 seconds later
- ❌ **Battery drain**: Forces BLE scan every 2 minutes when disconnected
- ❌ **Code complexity**: More nested conditions and timeouts
- ❌ **Race conditions**: Timer and background scanner may conflict
- ❌ **Blocking**: Timer callback takes 25+ seconds to complete
- ❌ **Timeout stacking**: Multiple overlapping timeouts

**Best for:**
- Non-critical monitoring
- Development/testing environments
- Scenarios with frequent brief disconnects

---

## Recommendations

### ✅ Keep Current Implementation If:
1. You need **fast disconnect notifications** (within 2 minutes)
2. Healthcare compliance requires **immediate alerts**
3. Battery life is important
4. Code stability matters (production environment)
5. Backend can handle occasional false positives

### 🔄 Switch to Alternative If:
1. False disconnect alerts are a major problem
2. You can tolerate 15-25 second notification delays
3. Battery drain is not a concern
4. You're in a testing/development phase
5. Temporary disconnects are common

### 🎯 Hybrid Approach (Best of Both Worlds)
Consider implementing a **grace period** in the current implementation:

```dart
// Add to timer callback
if (!_isConnected && _connectedDevice != null) {
  // Check if recently disconnected
  final timeSinceDisconnect = DateTime.now().difference(_lastDataReceived!).inSeconds;
  
  if (timeSinceDisconnect < 60) {
    // Disconnected less than 1 minute ago - give background scanner time
    print('   ⏳ Recently disconnected, waiting for background scanner...');
    return; // Skip this cycle
  } else {
    // Disconnected for >1 minute - send notification
    print('   ❌ Disconnected for ${timeSinceDisconnect}s - sending webhook...');
    await _sendDisconnectWebhook(user.phone, reason: disconnectReason);
  }
}
```

This approach:
- ✅ Gives background scanner 1 minute to reconnect
- ✅ Still notifies backend within 3 minutes total
- ✅ Reduces false positives
- ✅ Minimal code changes
- ✅ No battery impact

---

## Code References

### Key Files
- **Main App**: `lib/main.dart`
- **Auth Service**: `lib/services/auth_service.dart`
- **API Service**: `lib/services/api_service.dart`
- **Storage Service**: `lib/services/storage_service.dart`

### Key Functions

| Function | Line Range | Purpose |
|----------|-----------|---------|
| `_startRealtimeDataStream()` | 747-884 | Sets up continuous data stream & timer |
| `_sendDataToWebhook()` | 1084-1224 | Sends health data to backend |
| `_handleDisconnection()` | 990-1041 | Manages reconnection attempts |
| `_startAutoReconnectScanner()` | 1291-1324 | Background scanner for lost devices |
| `_scanForSavedDevice()` | 1327-1382 | Scans and reconnects to saved device |
| `_sendDisconnectWebhook()` | 1226-1254 | Sends disconnect notification |
| `_checkNetworkConnectivity()` | 1257-1267 | Determines disconnect type |

### Configuration Constants

```dart
// Webhook settings
static const String _webhookUrl = 'https://api.hireforcare.com/webhook/hc20-data';

// Timing
const Duration timerInterval = Duration(seconds: 120);  // 2 minutes
const Duration scanInterval = Duration(seconds: 30);     // Background scan
const Duration dataTimeout = Duration(seconds: 10);      // Data wait time

// Reconnection
static const int _maxReconnectAttempts = 3;
const Duration reconnectDelay = Duration(seconds: 2);
```

---

## Testing Checklist

### Scenario 1: Normal Operation
- [ ] Device connects successfully
- [ ] Data received every 2 minutes
- [ ] Webhooks sent successfully
- [ ] UI updates in real-time

### Scenario 2: Temporary Disconnect
- [ ] User moves out of range briefly
- [ ] Auto-reconnection attempts (3x)
- [ ] Successfully reconnects
- [ ] Data streaming resumes

### Scenario 3: Permanent Disconnect
- [ ] Device powered off
- [ ] 3 reconnection attempts fail
- [ ] Background scanner activates
- [ ] Disconnect webhook sent after 2 minutes
- [ ] Null values in webhook payload

### Scenario 4: Network Issues
- [ ] Mobile data turned off
- [ ] Webhook fails with network error
- [ ] Error logged but app continues
- [ ] Retries next cycle when network restored

### Scenario 5: Background Operation
- [ ] App minimized
- [ ] Webhooks continue every 2 minutes
- [ ] Background scanner still active
- [ ] Reconnects when device in range

---

## Troubleshooting

### Problem: Disconnect webhooks too frequent
**Solution:** Implement grace period (see Hybrid Approach above)

### Problem: Device not auto-reconnecting
**Check:**
1. Device ID saved? (`_savedDeviceId` not null)
2. Background scanner running? (Check logs)
3. Bluetooth permissions granted?
4. Battery optimization disabled?

### Problem: Webhooks failing
**Check:**
1. Network connectivity
2. Backend API status
3. Webhook URL correct?
4. Timeout values (increase if needed)

### Problem: High battery drain
**Check:**
1. Background scanner interval (increase from 30s)
2. Real-time stream properly cancelled on disconnect?
3. Battery optimization enabled for app?

---

## Future Enhancements

### Planned Features
1. **Adaptive reconnection**: Increase delay between attempts
2. **Smart scanning**: Only scan during likely connection times
3. **Webhook batching**: Queue failed webhooks and retry
4. **Connection quality metrics**: Signal strength monitoring
5. **Predictive disconnection**: Warn before disconnect likely

### Performance Optimization
1. Reduce background scan frequency when battery low
2. Cache webhook data for offline mode
3. Implement exponential backoff for reconnections
4. Add connection stability score

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Jan 9, 2026 | Initial documentation |

---

## Contact & Support

For questions or issues:
- Check logs in Android Studio Logcat
- Review error messages in UI
- Contact backend team for webhook issues
- Review this document for implementation details

---

**End of Documentation**
