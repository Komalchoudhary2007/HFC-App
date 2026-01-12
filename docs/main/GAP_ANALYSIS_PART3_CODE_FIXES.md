# 🔧 COMPREHENSIVE GAP ANALYSIS - PART 3: COMPLETE CODE FIXES

**Date:** January 10, 2026  
**Focus:** Ready-to-implement code fixes with exact line replacements

---

## 🚀 IMPLEMENTATION STRATEGY

This document provides **EXACT CODE REPLACEMENTS** for all identified issues.

### Fix Order (by priority):
1. ✅ **FIX #1:** Inverted network check logic (CRITICAL)
2. ✅ **FIX #2:** Remove duplicate stress alert flags (HIGH)
3. ✅ **FIX #3:** Add phone battery monitoring (CRITICAL)
4. ✅ **FIX #4:** Add missing webhook fields (MEDIUM)
5. ✅ **FIX #5:** Remove duplicate UI sections (HIGH)
6. ✅ **FIX #6:** Fix internet status monitoring (MEDIUM)
7. ✅ **FIX #7:** Improve login display (LOW)
8. ✅ **FIX #8:** Add history webhook button (MEDIUM)

---

## 🔧 FIX #1: INVERTED NETWORK CHECK LOGIC (CRITICAL)

### 📍 Location: `lib/main.dart` Line 1456-1464

### ❌ CURRENT CODE (BROKEN):
```dart
Future<bool> _checkNetworkConnectivity() async {
  try {
    final result = await _dio.get(
      'https://api.hireforcare.com/health',
      options: Options(receiveTimeout: const Duration(seconds: 5)),
    );
    return result.statusCode != 200;  // ❌ INVERTED LOGIC!
  } catch (e) {
    return true;  // ❌ WRONG: Returns true when network fails!
  }
}
```

### ✅ FIXED CODE:
```dart
Future<bool> _checkNetworkConnectivity() async {
  try {
    final result = await _dio.get(
      'https://api.hireforcare.com/health',
      options: Options(receiveTimeout: const Duration(seconds: 5)),
    );
    return result.statusCode == 200;  // ✅ CORRECT: Returns true when OK
  } catch (e) {
    return false;  // ✅ CORRECT: Returns false when network fails
  }
}
```

### Testing:
```dart
// Before fix: Always returns "Network Disconnect"
// After fix: Returns correct disconnect reason (Bluetooth/Device)
```

---

## 🔧 FIX #2: REMOVE DUPLICATE STRESS ALERT FLAGS (HIGH)

### 📍 Location: `lib/main.dart` Line 1278-1282

### ❌ CURRENT CODE (BROKEN):
```dart
final payload = {
  'userId': user?.id,
  'deviceId': _connectedDevice?.id,
  'timestamp': DateTime.now().toIso8601String(),
  'isStressAlert': true,
  'stress_alert': true,  // ❌ DUPLICATE FIELD!
  'stressLevel': stressLevel,
  // ... more fields
};
```

### ✅ FIXED CODE:
```dart
final payload = {
  'userId': user?.id,
  'deviceId': _connectedDevice?.id,
  'timestamp': DateTime.now().toIso8601String(),
  'isStressAlert': true,  // ✅ Keep only this one
  'stressLevel': stressLevel,
  // ... more fields
};
```

### Impact:
- Backend receives cleaner payloads
- No confusion about which field to use
- Consistent with naming convention

---

## 🔧 FIX #3: ADD PHONE BATTERY MONITORING (CRITICAL)

### 📍 Location: `lib/main.dart` Line 900-920

### ⚙️ PREREQUISITE: Add dependency to `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  battery_plus: ^5.0.2  # ✅ ADD THIS
  # ... existing dependencies
```

Run: `flutter pub get`

### 📍 Add imports at top of `main.dart`:

```dart
import 'package:battery_plus/battery_plus.dart';
```

### ❌ CURRENT CODE (INCOMPLETE):
```dart
Future<void> _checkBatteryStatus() async {
  if (_client == null) {
    setState(() {
      _batteryLevel = 0;
      _isLowBattery = false;
    });
    return;
  }

  try {
    final batteryResult = await _client!.getBattery();
    final batteryLevel = batteryResult.quantity ?? 0;

    setState(() {
      _batteryLevel = batteryLevel;
      _isLowBattery = batteryLevel <= 20;  // ❌ Only checks DEVICE battery!
    });

    // Send webhook only if battery is low
    if (_isLowBattery && !_lowBatterySent) {
      await _sendLowBatteryAlert();
      _lowBatterySent = true;
    }
  } catch (e) {
    print('Error checking battery: $e');
  }
}
```

### ✅ FIXED CODE:
```dart
// Add these state variables at the top of _MyAppState class (around line 200):
int _phoneBatteryLevel = 100;
bool _isPhoneLowBattery = false;

Future<void> _checkBatteryStatus() async {
  // ✅ STEP 1: Check PHONE battery first
  final Battery battery = Battery();
  int phoneBattery = 100;
  try {
    phoneBattery = await battery.batteryLevel;
  } catch (e) {
    print('Error checking phone battery: $e');
  }

  // ✅ STEP 2: Check DEVICE battery
  int deviceBattery = 0;
  if (_client != null) {
    try {
      final batteryResult = await _client!.getBattery();
      deviceBattery = batteryResult.quantity ?? 0;
    } catch (e) {
      print('Error checking device battery: $e');
    }
  }

  // ✅ STEP 3: Update state with BOTH values
  setState(() {
    _phoneBatteryLevel = phoneBattery;
    _batteryLevel = deviceBattery;
    
    // Low battery if EITHER phone OR device is low
    _isPhoneLowBattery = phoneBattery <= 20;
    _isLowBattery = deviceBattery <= 20;
  });

  // ✅ STEP 4: Send alert if EITHER is low
  if ((_isLowBattery || _isPhoneLowBattery) && !_lowBatterySent) {
    await _sendLowBatteryAlert(
      phoneBattery: phoneBattery,
      deviceBattery: deviceBattery,
    );
    _lowBatterySent = true;
  } else if (!_isLowBattery && !_isPhoneLowBattery) {
    // Reset flag when both batteries are OK
    _lowBatterySent = false;
  }
}
```

### 📍 Update `_sendLowBatteryAlert()` function (Line 1330-1365):

### ❌ CURRENT:
```dart
Future<void> _sendLowBatteryAlert() async {
  final authService = Provider.of<AuthService>(context, listen: false);
  final user = authService.currentUser;

  if (user == null) return;

  try {
    final payload = {
      'userId': user.id,
      'deviceId': _connectedDevice?.id,
      'timestamp': DateTime.now().toIso8601String(),
      'alertType': 'low_battery',
      'batteryLevel': _batteryLevel,  // ❌ Only device battery
      'message': 'Device battery is at $_batteryLevel%',
    };

    await _dio.post(_webhookUrl, data: payload);
    print('Low battery alert sent');
  } catch (e) {
    print('Error sending low battery alert: $e');
  }
}
```

### ✅ FIXED:
```dart
Future<void> _sendLowBatteryAlert({
  required int phoneBattery,
  required int deviceBattery,
}) async {
  final authService = Provider.of<AuthService>(context, listen: false);
  final user = authService.currentUser;

  if (user == null) return;

  try {
    // ✅ Determine which battery is low
    String alertMessage;
    if (phoneBattery <= 20 && deviceBattery <= 20) {
      alertMessage = 'Both phone ($phoneBattery%) and device ($deviceBattery%) batteries are low';
    } else if (phoneBattery <= 20) {
      alertMessage = 'Phone battery is low at $phoneBattery%';
    } else {
      alertMessage = 'Device battery is low at $deviceBattery%';
    }

    final payload = {
      'userId': user.id,
      'deviceId': _connectedDevice?.id,
      'timestamp': DateTime.now().toIso8601String(),
      'alertType': 'low_battery',
      'phoneBatteryLevel': phoneBattery,      // ✅ Phone battery
      'deviceBatteryLevel': deviceBattery,    // ✅ Device battery
      'isPhoneLowBattery': phoneBattery <= 20,
      'isDeviceLowBattery': deviceBattery <= 20,
      'message': alertMessage,
    };

    await _dio.post(_webhookUrl, data: payload);
    print('Low battery alert sent: $alertMessage');
  } catch (e) {
    print('Error sending low battery alert: $e');
  }
}
```

---

## 🔧 FIX #4: ADD MISSING WEBHOOK FIELDS (MEDIUM)

### 📍 Location: `lib/main.dart` Line 1280-1340 (`_sendDataToWebhook`)

### ❌ CURRENT CODE (MISSING FIELDS):
```dart
Future<void> _sendDataToWebhook(Hc20StreamData data) async {
  final authService = Provider.of<AuthService>(context, listen: false);
  final user = authService.currentUser;

  if (user == null) return;

  try {
    final payload = {
      'userId': user.id,
      'deviceId': _connectedDevice?.id,
      'timestamp': DateTime.now().toIso8601String(),
      // ❌ MISSING: 'status' field
      // ❌ MISSING: 'bluetoothStatus' field
      // ❌ MISSING: 'internetStatus' field
      // ❌ MISSING: 'dataType' field (live vs history)
      'ecg': data.ecg,
      'ppg': data.ppg,
      'heartRate': data.hr,
      // ... other data fields
    };

    await _dio.post(_webhookUrl, data: payload);
  } catch (e) {
    print('Error sending data: $e');
  }
}
```

### ✅ FIXED CODE:
```dart
Future<void> _sendDataToWebhook(Hc20StreamData data) async {
  final authService = Provider.of<AuthService>(context, listen: false);
  final user = authService.currentUser;

  if (user == null) return;

  try {
    final payload = {
      'userId': user.id,
      'deviceId': _connectedDevice?.id,
      'timestamp': DateTime.now().toIso8601String(),
      
      // ✅ ADD: Connection status fields
      'status': 'Connected',                              // ✅ NEW
      'bluetoothStatus': _isBluetoothOn ? 'Connected' : 'Disconnected',  // ✅ NEW
      'internetStatus': _isInternetConnected ? 'Connected' : 'Disconnected',  // ✅ NEW
      'dataType': 'live',                                 // ✅ NEW (vs 'history')
      
      // ✅ ADD: Battery information
      'phoneBatteryLevel': _phoneBatteryLevel,            // ✅ NEW
      'deviceBatteryLevel': _batteryLevel,                // ✅ NEW
      
      // Existing fields
      'ecg': data.ecg,
      'ppg': data.ppg,
      'heartRate': data.hr,
      'respiratoryRate': data.rr,
      'bloodOxygen': data.bo,
      'temperature': data.temp,
      'motion': data.motion,
      'isStressAlert': false,  // Regular data, not stress alert
    };

    await _dio.post(_webhookUrl, data: payload);
  } catch (e) {
    print('Error sending data: $e');
  }
}
```

### 📍 Also update disconnect webhook (Line 1370-1390):

```dart
Future<void> _sendDisconnectWebhook() async {
  // ... existing code ...
  
  final payload = {
    'userId': user.id,
    'deviceId': _connectedDevice?.id,
    'timestamp': DateTime.now().toIso8601String(),
    'status': 'Disconnected',  // ✅ Already has this!
    
    // ✅ ADD: More detailed status
    'bluetoothStatus': _isBluetoothOn ? 'Connected' : 'Disconnected',
    'internetStatus': _isInternetConnected ? 'Connected' : 'Disconnected',
    'dataType': 'disconnect',  // ✅ NEW
    
    // Existing fields
    'disconnectReason': reason,
    'lastHeartRate': _lastHeartRate,
    // ... other fields
  };
  
  // ... rest of function
}
```

---

## 🔧 FIX #5: REMOVE DUPLICATE UI SECTIONS (HIGH)

### 📍 Location: `lib/main.dart` Line 3108-3250 (DELETE THIS ENTIRE SECTION)

### ❌ DUPLICATE CODE TO REMOVE:

Find this second occurrence and DELETE it entirely:

```dart
// Line 3108 - DELETE FROM HERE
if (!_isConnected && _savedDeviceId != null)
  Column(
    children: [
      // Device Disconnected card
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          // ... entire duplicate section
        ),
      ),
      
      // Connection Analytics section (duplicate)
      ExpansionTile(
        // ... duplicate analytics
      ),
    ],
  ),
// Line 3250 - DELETE TO HERE
```

### ✅ SOLUTION:

**DELETE Lines 3108-3250** completely. Keep only the first occurrence at Line 2774-2830.

If user wants to remove Connection Analytics entirely, also modify Line 2800:

```dart
// ❌ REMOVE THIS if user doesn't want analytics:
ExpansionTile(
  title: Text('Connection Analytics'),
  // ... analytics content
),
```

---

## 🔧 FIX #6: FIX INTERNET STATUS MONITORING (MEDIUM)

### 📍 Location: `lib/main.dart` Line 200 (add state variable)

### Add timer variable:
```dart
class _MyAppState extends State<MyApp> {
  // ... existing variables ...
  
  Timer? _internetMonitorTimer;  // ✅ ADD THIS
  
  // ... rest of class
}
```

### 📍 Location: Line 413-418 - Store timer properly

### ❌ CURRENT:
```dart
void _startBluetoothAndInternetMonitoring() {
  // Check every 15 seconds
  Timer.periodic(const Duration(seconds: 15), (timer) {
    _checkBluetoothAndInternetStatus();
  });  // ❌ Timer not stored!
}
```

### ✅ FIXED:
```dart
void _startBluetoothAndInternetMonitoring() {
  // Cancel existing timer if any
  _internetMonitorTimer?.cancel();
  
  // Check every 15 seconds and store the timer
  _internetMonitorTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
    _checkBluetoothAndInternetStatus();
  });
  
  // Also check immediately
  _checkBluetoothAndInternetStatus();
}
```

### 📍 Location: `dispose()` method - Cancel timer on cleanup

```dart
@override
void dispose() {
  _internetMonitorTimer?.cancel();  // ✅ ADD THIS
  // ... existing dispose code
  super.dispose();
}
```

---

## 🔧 FIX #7: IMPROVE LOGIN DISPLAY (LOW)

### 📍 Location: `lib/main.dart` Line 2492-2503

### ❌ CURRENT:
```dart
Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: Colors.green.shade50,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.green, width: 2),
  ),
  child: Row(
    children: [
      Icon(Icons.check_circle, color: Colors.green, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          '✓ Logged in as ${user.name} (Login saved)',
          style: TextStyle(
            color: Colors.green.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    ],
  ),
)
```

### ✅ FIXED:
```dart
Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.green.shade50,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.green, width: 2),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Header
      Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(
            'Account Connected',
            style: TextStyle(
              color: Colors.green.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      
      // User and Device Info
      Row(
        children: [
          // User Icon and Name
          Icon(Icons.person, color: Colors.green.shade700, size: 18),
          const SizedBox(width: 6),
          Text(
            user.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade900,
            ),
          ),
          
          // Divider
          if (_savedDeviceId != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('|', style: TextStyle(color: Colors.grey.shade400)),
            ),
            
            // Device Icon and ID
            Icon(Icons.watch, color: Colors.blue.shade700, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _savedDeviceId!,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Courier',  // Monospace for MAC address
                  color: Colors.blue.shade900,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    ],
  ),
)
```

---

## 🔧 FIX #8: ADD HISTORY WEBHOOK BUTTON (MEDIUM)

### 📍 Location: `lib/main.dart` Line 2025-2055 (Modify dialog)

### ❌ CURRENT:
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('History Data'),
    content: SingleChildScrollView(
      child: Text(historyText),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Close'),
      ),
    ],
  ),
);
```

### ✅ FIXED:
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Row(
      children: [
        Icon(Icons.history, color: Colors.blue),
        const SizedBox(width: 8),
        Text('History Data Retrieved'),
      ],
    ),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(historyText),
          const SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Click "Send to Server" to upload this data',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Close'),
      ),
      ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          _sendHistoryDataToWebhook(
            hrvData: hrvData,
            hrv2Data: hrvData2,
            sleepData: sleepData,
            exerciseData: exerciseData,
            bloodOxygenData: bloodOxygenData,
            activityData: activityData,
          );
        },
        icon: Icon(Icons.cloud_upload),
        label: Text('Send to Server'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
    ],
  ),
);
```

### 📍 Add NEW function after `_getHistoryData()` (after Line 2079):

```dart
Future<void> _sendHistoryDataToWebhook({
  required List<Hc20HrvRow> hrvData,
  required List<Hc20Hrv2Row> hrv2Data,
  required List<Hc20SleepRow> sleepData,
  required List<Hc20ExerciseRow> exerciseData,
  required List<Hc20BoRow> bloodOxygenData,
  required List<Hc20ActivityRow> activityData,
}) async {
  final authService = Provider.of<AuthService>(context, listen: false);
  final user = authService.currentUser;

  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ User not logged in')),
    );
    return;
  }

  try {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Uploading history data...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    final payload = {
      'userId': user.id,
      'deviceId': _connectedDevice?.id,
      'timestamp': DateTime.now().toIso8601String(),
      'dataType': 'history',  // ✅ Flag to distinguish from live data
      'dataSource': 'device_memory',
      'status': 'Retrieved',
      'bluetoothStatus': _isBluetoothOn ? 'Connected' : 'Disconnected',
      'internetStatus': _isInternetConnected ? 'Connected' : 'Disconnected',
      
      'historyData': {
        'hrv': hrvData.map((row) => {
          'timestamp': row.timestamp,
          'sdnn': row.sdnn,
          'rmssd': row.rmssd,
          'pnn50': row.pnn50,
          'meanRr': row.meanRr,
          'stress': row.stress,
        }).toList(),
        
        'hrv2': hrv2Data.map((row) => {
          'timestamp': row.timestamp,
          'minHr': row.minHr,
          'maxHr': row.maxHr,
          'avgHr': row.avgHr,
        }).toList(),
        
        'sleep': sleepData.map((row) => {
          'startTime': row.startTime,
          'stopTime': row.stopTime,
          'deepSleepMinutes': row.deepSleepMins,
          'lightSleepMinutes': row.lightSleepMins,
          'totalSleepMinutes': row.totalMins,
          'wakeCount': row.wakeCount,
        }).toList(),
        
        'exercise': exerciseData.map((row) => {
          'startTime': row.startTime,
          'stopTime': row.stopTime,
          'duration': row.duration,
          'type': row.type,
          'calories': row.calories,
          'distance': row.distance,
        }).toList(),
        
        'bloodOxygen': bloodOxygenData.map((row) => {
          'timestamp': row.timestamp,
          'value': row.bo,
        }).toList(),
        
        'activity': activityData.map((row) => {
          'timestamp': row.timestamp,
          'steps': row.step,
          'calories': row.calorie,
          'distance': row.distance,
        }).toList(),
      },
      
      'recordCounts': {
        'hrv': hrvData.length,
        'hrv2': hrv2Data.length,
        'sleep': sleepData.length,
        'exercise': exerciseData.length,
        'bloodOxygen': bloodOxygenData.length,
        'activity': activityData.length,
      },
    };

    final response = await _dio.post(_webhookUrl, data: payload);
    
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '✅ History data uploaded successfully (${hrvData.length + hrv2Data.length + sleepData.length} records)',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    print('Error sending history data: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Failed to upload history data: $e'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );
  }
}
```

---

## 📋 COMPLETE FIX CHECKLIST

### Phase 1: Critical Fixes (30 mins)
- [ ] Fix inverted network logic (Line 1456-1464)
- [ ] Add battery_plus dependency to pubspec.yaml
- [ ] Add phone battery monitoring (Line 900-920)
- [ ] Update low battery alert function (Line 1330-1365)

### Phase 2: High Priority Fixes (45 mins)
- [ ] Remove duplicate stress flag (Line 1281)
- [ ] Delete duplicate UI sections (Line 3108-3250)
- [ ] Store internet monitor timer properly (Line 413-418)
- [ ] Add timer cleanup in dispose()

### Phase 3: Medium Priority Fixes (1 hour)
- [ ] Add missing webhook fields (Line 1280-1340)
- [ ] Update disconnect webhook fields (Line 1370-1390)
- [ ] Add history webhook button to dialog (Line 2025-2055)
- [ ] Implement _sendHistoryDataToWebhook() function

### Phase 4: Low Priority Fixes (20 mins)
- [ ] Improve login display with device ID (Line 2492-2503)

### Phase 5: Testing (30 mins)
- [ ] Test disconnect detection (BT off, device off, out of range)
- [ ] Test stress alert webhook (verify no duplicates)
- [ ] Test low battery alert (both phone and device)
- [ ] Test history data upload button
- [ ] Verify UI shows only one "Device Disconnected" section
- [ ] Check internet status UI updates properly

**Total Estimated Time:** 3-3.5 hours

---

**Continue to:** `GAP_ANALYSIS_PART4_RECOMMENDATIONS.md` for expert best practices and architecture improvements
