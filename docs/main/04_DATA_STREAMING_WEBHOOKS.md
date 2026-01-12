# Main.dart - Data Streaming & Webhooks Documentation

**Part 4 of 7**  
**Last Updated:** January 9, 2026  
**File:** `lib/main.dart` (Lines 747-1270)

---

## Table of Contents
1. [Data Streaming Overview](#data-streaming-overview)
2. [Real-Time Data Stream](#real-time-data-stream)
3. [Webhook Timer (2 Minutes)](#webhook-timer-2-minutes)
4. [Webhook Payload Structure](#webhook-payload-structure)
5. [Error Handling](#error-handling)
6. [HRV Auto-Refresh (6 Hours)](#hrv-auto-refresh-6-hours)
7. [Connection Monitoring](#connection-monitoring)
8. [Stress Alert System](#stress-alert-system)

---

## Data Streaming Overview

Once connected, the app manages **3 parallel data streams**:

```
┌─────────────────────────────────────────┐
│          Connected to HC20              │
└─────────────┬───────────────────────────┘
              │
     ┌────────┼────────┐
     │        │        │
     ▼        ▼        ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│Real-time│ │Webhook  │ │  HRV    │
│ Stream  │ │ Timer   │ │Auto-Ref │
│(Events) │ │(120s)   │ │(6 hrs)  │
└────┬────┘ └────┬────┘ └────┬────┘
     │           │           │
     ▼           ▼           ▼
 Update UI   Send Data   Fetch HRV
             to Backend  from Device
```

### Purpose of Each Stream

| Stream | Frequency | Purpose |
|--------|-----------|---------|
| **Real-time** | Event-driven | Update UI, detect disconnects |
| **Webhook Timer** | Every 2 minutes | Ensure regular backend updates |
| **HRV Refresh** | Every 6 hours | Fetch detailed HRV metrics |

---

## Real-Time Data Stream

**Location:** Lines 747-825  
**Trigger:** Immediately after device connection  
**Duration:** Continuous until disconnect

### Stream Initialization

```dart
void _startRealtimeDataStream(Hc20Device device) {
  // Clean up any existing subscriptions
  _realtimeSubscription?.cancel();
  _dataRefreshTimer?.cancel();
  
  print('\n🚀 ========================================');
  print('🚀 Starting real-time data stream');
  print('🚀 Device: ${device.name}');
  print('🚀 Webhook URL: $_webhookUrl');
  print('🚀 Data refresh: Every 120 seconds');
  print('🚀 ========================================\n');
  
  // Subscribe to real-time data from device
  _realtimeSubscription = _client!.realtimeV2(device).listen(
    (data) {
      // Data received! (See next section)
      _handleRealtimeData(data, device);
    },
    onError: (error) {
      // Connection lost!
      _handleStreamError(error);
    },
    onDone: () {
      // Stream completed
      print('✅ Real-time stream closed');
    },
  );
  
  // Start 2-minute timer (covered in next section)
  _startWebhookTimer(device);
}
```

### Data Received Callback

```dart
void _handleRealtimeData(Hc20RealtimeV2 data, Hc20Device device) {
  final timestamp = DateTime.now().toIso8601String();
  _lastDataReceived = DateTime.now();
  
  print('\n📊 [$timestamp] Received real-time data:');
  print('   Heart: ${data.heart} BPM');
  print('   SpO2: ${data.spo2}%');
  print('   BP: ${data.bp}');
  print('   Temp: ${data.temperature}°C');
  print('   Battery: ${data.battery?.percent}%');
  print('   Steps: ${data.basicData?[0] ?? "N/A"}');
  
  // Update UI state
  setState(() {
    if (data.heart != null) _heartRate = data.heart;
    if (data.spo2 != null) _spo2 = data.spo2;
    if (data.bp != null) _bloodPressure = data.bp;
    if (data.temperature != null && data.temperature!.isNotEmpty) {
      _temperature = data.temperature![0] / 100.0;  // Convert to °C
    }
    if (data.battery != null) _batteryLevel = data.battery!.percent;
    if (data.basicData != null && data.basicData!.isNotEmpty) {
      _steps = data.basicData![0];  // Steps at index 0
    }
  });
  
  // Check if stress alert pending
  if (_stressAlertPending) {
    print('🚨 Stress alert flag detected - sending STRESS webhook');
    _stressAlertPending = false;
    _sendDataToWebhook(device, data, isStressAlert: true);
    setState(() {
      _statusMessage = 'Stress alert sent!';
    });
  } else {
    // Send regular webhook
    _sendDataToWebhook(device, data);
  }
}
```

### HC20RealtimeV2 Data Structure

```dart
class Hc20RealtimeV2 {
  int? heart;              // Heart rate (BPM)
  List<int>? rri;          // R-R intervals (ms)
  int? spo2;               // Blood oxygen (%)
  List<int>? bp;           // [systolic, diastolic]
  List<int>? temperature;  // Body temp (×100, so 3650 = 36.5°C)
  
  Hc20Battery? battery;    // Battery info
  List<int>? basicData;    // [steps, calories, distance]
  List<int>? baro;         // Barometric pressure
  int? wear;               // Wear status (0=off, 1=on)
  
  List<int>? sleep;        // Sleep data
  List<int>? gnss;         // GPS data
  
  List<int>? hrv;          // HRV raw [SDNN, TP, LF, HF, VLF]
  Hc20HrvMetrics? hrvMetrics;  // Parsed HRV
  
  List<int>? hrv2;         // HRV2 raw [stress, fatigue, etc.]
  Hc20Hrv2Metrics? hrv2Metrics;  // Parsed HRV2
}
```

### Data Frequency

| Data Type | Frequency | Notes |
|-----------|-----------|-------|
| **Heart Rate** | 1-5 seconds | Most frequent |
| **SpO2** | 10-30 seconds | Power intensive |
| **Blood Pressure** | On-demand | Manual measurement |
| **Temperature** | 30-60 seconds | Continuous monitoring |
| **Battery** | 1 minute | Changes slowly |
| **Steps** | 1-10 seconds | Accelerometer-based |

---

## Webhook Timer (2 Minutes)

**Location:** Lines 833-884  
**Purpose:** Ensure regular data updates even if device doesn't send spontaneously

### Timer Flow Diagram

```
Timer Triggers (Every 120s)
   │
   ▼
Is Device Connected?
   │
   ├─── YES ──→ Request Fresh Data
   │               │
   │               └──→ Device Responds
   │                      │
   │                      └──→ Send Webhook (Real Data)
   │
   └─── NO ──→ Check Network
                   │
                   ├─── Network OK ──→ Device Disconnect
                   │                      │
                   │                      └──→ Send Disconnect Webhook
                   │
                   └─── Network DOWN ──→ Network Disconnect
                                             │
                                             └──→ Send Disconnect Webhook
```

### Timer Implementation

```dart
_dataRefreshTimer = Timer.periodic(const Duration(seconds: 120), (timer) async {
  try {
    print('\n⏰ ========================================');
    print('⏰ [Timer] 2-minute webhook timer triggered');
    print('⏰ Status: ${_isConnected ? "CONNECTED" : "DISCONNECTED"}');
    print('⏰ ========================================');
    
    if (_isConnected && _connectedDevice != null) {
      // CONNECTED: Request fresh data
      print('   ✅ Device connected - requesting fresh data...');
      
      try {
        // Trigger device to send new data
        _client!.realtimeV2(device).listen(
          (data) {
            print('   ✅ Fresh data received, webhook sent automatically');
          }, 
          onError: (e) {
            print('   ⚠️ Error requesting fresh data: $e');
            _handleDisconnection();  // Connection lost
          }
        );
      } catch (e) {
        print('   ⚠️ Error creating realtimeV2 subscription: $e');
      }
      
    } else {
      // DISCONNECTED: Send null webhook with error reason
      print('   ⚠️ Device DISCONNECTED - sending disconnect webhook...');
      
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final user = authService.currentUser;
        
        if (user != null) {
          // Determine disconnect reason
          bool isNetworkIssue = await _checkNetworkConnectivity();
          String disconnectReason = isNetworkIssue 
              ? 'Network Disconnect' 
              : 'Device Disconnect';
          
          print('   📤 Sending disconnect webhook: $disconnectReason');
          await _sendDisconnectWebhook(user.phone, reason: disconnectReason);
          print('   ✅ Disconnect webhook sent successfully');
        } else {
          print('   ⚠️ No user found, cannot send disconnect webhook');
        }
      } catch (e) {
        print('   ❌ Error sending disconnect webhook: $e');
      }
    }
    
    print('⏰ Timer execution completed\n');
  } catch (e) {
    print('   ❌ CRITICAL ERROR in timer callback: $e');
    print('   Stack trace: ${StackTrace.current}');
  }
});
```

### Why 2 Minutes?

**Too Short (< 1 min):**
- ❌ Battery drain (excessive BLE communication)
- ❌ Backend overload (too many requests)
- ❌ Data redundancy (no significant changes)

**Too Long (> 5 min):**
- ❌ Delayed disconnect detection
- ❌ Missing critical health events
- ❌ Poor user experience

**2 Minutes is Optimal:**
- ✅ Balance between frequency and efficiency
- ✅ Meets healthcare monitoring standards
- ✅ Acceptable battery consumption
- ✅ Fast enough for emergency detection

---

## Webhook Payload Structure

**Location:** Lines 1084-1148  
**Endpoint:** `https://api.hireforcare.com/webhook/hc20-data`  
**Method:** POST  
**Content-Type:** application/json

### Complete Payload Example

```json
{
  "timestamp": "2026-01-09T08:00:00.000+05:30",
  "stress_alert": false,
  "device": {
    "id": "HC20-1234",
    "name": "HC20 Watch"
  },
  "realtime_data": {
    "heart_rate": 72,
    "rri": [850, 860, 845, 855],
    "spo2": 98,
    "blood_pressure": {
      "systolic": 120,
      "diastolic": 80
    },
    "temperature": [36.5, 36.6],
    "battery": {
      "percent": 85,
      "charge": false
    },
    "basic_data": [5423, 287, 3841],
    "barometric_pressure": [1013, 1014],
    "wear_status": 1,
    "sleep": [0, 120, 180, 60, 240],
    "gnss": [1, 4, 1641720000, 35.6762, 139.6503, 40],
    "hrv_raw": [45, 1200, 600, 400, 200],
    "hrv_metrics": {
      "sdnn": 45,
      "tp": 1200,
      "lf": 600,
      "hf": 400,
      "vlf": 200
    },
    "hrv2_raw": [3, 2, 4, 4],
    "hrv2_metrics": {
      "mental_stress": 3,
      "fatigue_level": 2,
      "stress_resistance": 4,
      "regulation_ability": 4
    }
  }
}
```

### Field Explanations

#### Basic Vitals
| Field | Type | Unit | Range | Description |
|-------|------|------|-------|-------------|
| `heart_rate` | int | BPM | 40-200 | Beats per minute |
| `rri` | int[] | ms | 300-2000 | R-R intervals (heart variability) |
| `spo2` | int | % | 70-100 | Blood oxygen saturation |
| `blood_pressure` | object | mmHg | 60-220 | Systolic/Diastolic |
| `temperature` | float[] | °C | 34-42 | Body temperature |

#### Battery & Activity
| Field | Type | Unit | Range | Description |
|-------|------|------|-------|-------------|
| `battery.percent` | int | % | 0-100 | Battery level |
| `battery.charge` | bool | - | true/false | Is charging? |
| `basic_data[0]` | int | steps | 0-50000 | Daily step count |
| `basic_data[1]` | int | kcal | 0-5000 | Calories burned |
| `basic_data[2]` | int | meters | 0-50000 | Distance traveled |

#### HRV (Heart Rate Variability)
| Metric | Normal Range | Meaning |
|--------|-------------|----------|
| **SDNN** | 30-100 ms | Overall HRV (higher = better) |
| **TP** | 500-2000 ms² | Total power (all frequencies) |
| **LF** | 300-1000 ms² | Low frequency (sympathetic) |
| **HF** | 200-800 ms² | High frequency (parasympathetic) |
| **VLF** | 100-500 ms² | Very low frequency |

#### HRV2 (Stress Metrics)
| Metric | Scale | Meaning |
|--------|-------|---------|
| **Mental Stress** | 1-5 | 1=low, 5=high stress |
| **Fatigue Level** | 1-5 | 1=energized, 5=exhausted |
| **Stress Resistance** | 1-5 | 1=poor, 5=excellent |
| **Regulation Ability** | 1-5 | 1=poor, 5=excellent |

### Payload Assembly Code

```dart
final payload = {
  'timestamp': now.toIso8601String(),
  'stress_alert': isStressAlert,
  'device': {
    'id': device.id,
    'name': device.name,
  },
  'realtime_data': {
    // Vital signs
    'heart_rate': data.heart,
    'rri': data.rri,
    'spo2': data.spo2,
    'blood_pressure': data.bp != null ? {
      'systolic': data.bp!.length > 0 ? data.bp![0] : null,
      'diastolic': data.bp!.length > 1 ? data.bp![1] : null,
    } : null,
    
    // Temperature (divide by 100)
    'temperature': data.temperature?.map((t) => t / 100.0).toList(),
    
    // Battery
    'battery': data.battery != null ? {
      'percent': data.battery!.percent,
      'charge': data.battery!.charge,
    } : null,
    
    // Activity
    'basic_data': data.basicData,
    'barometric_pressure': data.baro,
    'wear_status': data.wear,
    
    // Sleep & GPS
    'sleep': data.sleep,
    'gnss': data.gnss,
    
    // HRV
    'hrv_raw': data.hrv,
    'hrv_metrics': data.hrvMetrics != null ? {
      'sdnn': data.hrvMetrics!.sdnn,
      'tp': data.hrvMetrics!.tp,
      'lf': data.hrvMetrics!.lf,
      'hf': data.hrvMetrics!.hf,
      'vlf': data.hrvMetrics!.vlf,
    } : null,
    
    // HRV2 (Stress)
    'hrv2_raw': data.hrv2,
    'hrv2_metrics': data.hrv2Metrics != null ? {
      'mental_stress': data.hrv2Metrics!.mentStress,
      'fatigue_level': data.hrv2Metrics!.fatigueLevel,
      'stress_resistance': data.hrv2Metrics!.stressResistance,
      'regulation_ability': data.hrv2Metrics!.regulationAbility,
    } : null,
  },
};
```

---

## Error Handling

**Location:** Lines 1178-1224  
**Purpose:** Robust webhook error handling with detailed categorization

### Error Types

```dart
on DioException catch (e) {
  String errorDetail = '';
  
  if (e.type == DioExceptionType.connectionTimeout) {
    errorDetail = 'Timeout: Backend took >5s to respond';
    
  } else if (e.type == DioExceptionType.sendTimeout) {
    errorDetail = 'Send timeout: Data send took >5s';
    
  } else if (e.type == DioExceptionType.receiveTimeout) {
    errorDetail = 'Receive timeout: No response in 5s';
    
  } else if (e.type == DioExceptionType.badResponse) {
    errorDetail = 'HTTP ${e.response?.statusCode}: ${e.response?.statusMessage}\n'
                  'Data: ${e.response?.data}';
    
  } else if (e.type == DioExceptionType.connectionError) {
    errorDetail = 'Network error: ${e.message}\n'
                  'Check: WiFi/Mobile data enabled?';
    
  } else if (e.type == DioExceptionType.badCertificate) {
    errorDetail = 'SSL/Certificate error: ${e.message}';
    
  } else if (e.type == DioExceptionType.cancel) {
    errorDetail = 'Request cancelled';
    
  } else {
    errorDetail = 'Error: ${e.type}\n${e.message}';
  }
  
  setState(() {
    _webhookErrorCount++;
    _lastWebhookStatus = '✗ Failed';
    _lastWebhookError = errorDetail;
    _lastWebhookTime = DateTime.now();
  });
  
  print('\n❌ ========================================');
  print('❌ Webhook DioException!');
  print('❌ Error Type: ${e.type}');
  print('❌ Error Count: $_webhookErrorCount');
  print('❌ Detail: $errorDetail');
  print('❌ ========================================\n');
}
```

### Error Recovery Strategy

| Error Type | Retry? | Action |
|------------|--------|--------|
| **Timeout** | Yes (next cycle) | Wait 2 minutes, retry |
| **Network Error** | Yes (when online) | Check connectivity |
| **Bad Response 4xx** | No | Log and alert dev |
| **Bad Response 5xx** | Yes | Backend issue, retry |
| **SSL Error** | No | Critical - alert admin |

---

## HRV Auto-Refresh (6 Hours)

**Location:** Lines 887-960  
**Purpose:** Fetch detailed HRV data periodically for long-term health tracking

### Why Separate from Real-Time?

| Real-Time HRV | 6-Hour HRV Fetch |
|---------------|------------------|
| Instant values | Historical data |
| Live monitoring | Trend analysis |
| Limited detail | Full dataset |
| No storage needed | Stored on device |
| Event-driven | Time-based |

### Implementation

```dart
void _startHrvAutoRefresh() {
  _hrvRefreshTimer?.cancel();
  
  print('\n📊 Starting HRV auto-refresh (every 6 hours)');
  
  // Set up 6-hour timer
  _hrvRefreshTimer = Timer.periodic(const Duration(hours: 6), (timer) async {
    if (_isConnected && _connectedDevice != null && _client != null) {
      print('\n⏰ [HRV Auto-Refresh] 6-hour timer triggered');
      await _fetchHrvData();
    } else {
      print('⚠️ [HRV Auto-Refresh] Device not connected, skipping');
    }
  });
  
  // Do immediate first fetch
  _fetchHrvData();
}

Future<void> _fetchHrvData() async {
  if (_client == null || _connectedDevice == null) return;
  
  try {
    final now = DateTime.now();
    final yy = now.year % 100;  // 2026 → 26
    final mm = now.month;        // 1-12
    final dd = now.day;          // 1-31
    
    print('\n📊 Fetching HRV data for $yy-$mm-$dd');
    
    // Fetch from device (also uploads to Nitto cloud)
    final hrvRows = await _client!.getAllDayHrvRows(
      _connectedDevice!,
      yy: yy,
      mm: mm,
      dd: dd,
    );
    
    print('✅ HRV data fetched: ${hrvRows.length} records');
    print('✅ Data automatically uploaded to Nitto cloud');
    
    setState(() {
      _lastHrvRefresh = DateTime.now();
    });
  } catch (e) {
    print('❌ Error fetching HRV data: $e');
    
    if (e.toString().contains('0xE2')) {
      print('ℹ️ Device reported no HRV data available');
    }
  }
}
```

### Why 6 Hours?

- ✅ Captures multiple activity periods
- ✅ Enough data for trend analysis
- ✅ Not too frequent (battery consideration)
- ✅ Aligns with medical monitoring standards

---

## Connection Monitoring

**Location:** Lines 963-989  
**Purpose:** Detect silent disconnections (device doesn't send disconnect event)

### Monitoring Logic

```dart
void _startConnectionMonitoring() {
  print('🔍 Starting connection monitoring (every 30 seconds)');
  
  _connectionMonitor?.cancel();
  _connectionMonitor = Timer.periodic(const Duration(seconds: 30), (timer) {
    if (!_isConnected || _connectedDevice == null) {
      timer.cancel();
      return;
    }
    
    final now = DateTime.now();
    if (_lastDataReceived != null) {
      final timeSinceLastData = now.difference(_lastDataReceived!).inSeconds;
      
      print('🔍 [Monitor] Last data received: ${timeSinceLastData}s ago');
      
      // Threshold: 720 seconds (12 minutes)
      // This is 2 minutes longer than 5 timer cycles (10 min)
      if (timeSinceLastData > 720) {
        print('⚠️ [Monitor] No data for ${timeSinceLastData}s - disconnected');
        _handleDisconnection();
      } else if (timeSinceLastData > 660) {
        print('⏰ [Monitor] Data delayed (${timeSinceLastData}s), still OK');
      }
    }
  });
}
```

### Why 12-Minute Threshold?

```
Webhook Timer: Every 2 minutes
   │
   ├─→ 2 min: Data expected
   ├─→ 4 min: Data expected
   ├─→ 6 min: Data expected
   ├─→ 8 min: Data expected
   ├─→ 10 min: Data expected
   └─→ 12 min: If no data, assume disconnected
```

**Reasoning:**
- Allows for 2 missed timer cycles
- Accounts for network delays
- Prevents false positives

---

## Stress Alert System

**Location:** Lines 1057-1081  
**Purpose:** Emergency notification for stress/panic situations

### User Flow

```
User Feels Stressed
   │
   ▼
Presses "Send Stress Alert" Button
   │
   ▼
Set _stressAlertPending = true
   │
   ▼
Request IMMEDIATE fresh data from device
   │
   ▼
Device sends latest vitals
   │
   ▼
Real-time stream receives data
   │
   ▼
Checks _stressAlertPending flag
   │
   ▼
Sends webhook with stress_alert: true
   │
   ▼
Backend triggers emergency protocol
   │
   ▼
Caregiver notified immediately
```

### Implementation

```dart
void _sendStressWebhook() {
  if (_connectedDevice == null || !_isConnected || _client == null) {
    print('⚠️ Cannot send stress webhook - no device connected');
    setState(() {
      _statusMessage = 'No device connected';
    });
    return;
  }
  
  print('\n🚨 STRESS BUTTON PRESSED');
  print('🚨 Requesting IMMEDIATE fresh data...');
  
  setState(() {
    _stressAlertPending = true;  // Set flag
    _statusMessage = 'Requesting fresh data...';
  });
  
  // Trigger immediate data request
  // Brief subscription causes device to send fresh data
  // Main subscription will catch it
  _client!.realtimeV2(_connectedDevice!)
    .listen((_) {}, onError: (_) {})
    .cancel();
}
```

### Backend Handling

```javascript
// Backend webhook handler
app.post('/webhook/hc20-data', (req, res) => {
  const { stress_alert, device, realtime_data } = req.body;
  
  if (stress_alert === true) {
    // EMERGENCY PROTOCOL
    console.log('🚨 STRESS ALERT RECEIVED');
    
    // 1. Send SMS to caregiver
    await sendSMS(caregiver.phone, 
      `⚠️ STRESS ALERT from ${user.name}! Heart: ${realtime_data.heart_rate} BPM`
    );
    
    // 2. Send push notification
    await sendPushNotification(caregiver.device, {
      title: '🚨 STRESS ALERT',
      body: `${user.name} needs immediate attention`,
      priority: 'high',
    });
    
    // 3. Log in database
    await db.stressAlerts.create({
      user_id: user.id,
      device_id: device.id,
      vitals: realtime_data,
      timestamp: new Date(),
    });
    
    // 4. Escalate if no response in 5 minutes
    setTimeout(() => checkAlertResponse(alert.id), 5 * 60 * 1000);
  }
  
  res.json({ success: true });
});
```

---

## Common Issues & Solutions

### Issue 1: Webhooks Stop After 10 Minutes
**Cause:** Battery optimization killing app  
**Solution:** Disable battery optimization + ensure foreground service running

### Issue 2: Duplicate Data
**Cause:** Both real-time stream and timer sending  
**Solution:** This is intentional - timer is backup mechanism

### Issue 3: Missing HRV Data
**Cause:** Device hasn't collected enough data yet  
**Solution:** Wait 2-4 hours for device to gather HRV data

### Issue 4: Stress Alert Not Working
**Cause:** Device disconnected or not receiving data  
**Solution:** Check connection status before sending

---

## Best Practices

### ✅ DO
- Keep timer running even when disconnected
- Send comprehensive data in webhooks
- Log all webhook attempts
- Handle all error types
- Update UI on data receive
- Use timestamps with timezone

### ❌ DON'T
- Cancel timer on disconnect
- Send partial/incomplete data
- Ignore webhook errors
- Block UI thread with network calls
- Assume data is always available
- Use local timestamps without timezone

---

## Next Steps

📄 **Part 5 will cover:**
- Auto-Reconnection System
- Background Scanning
- Reconnection Strategies
- Error Recovery

This completes Part 4. Would you like me to continue with Parts 5, 6, and 7?

---

**End of Part 4**  
**Previous: [Part 3 - Device Connection](03_DEVICE_CONNECTION_FLOW.md)**  
**Next: Part 5 - Auto-Reconnection System (To be created)**
