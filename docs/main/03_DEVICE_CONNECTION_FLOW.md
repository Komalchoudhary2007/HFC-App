# Main.dart - Device Connection Flow Documentation

**Part 3 of 7**  
**Last Updated:** January 9, 2026  
**File:** `lib/main.dart` (Lines 445-745)

---

## Table of Contents
1. [Connection Overview](#connection-overview)
2. [Device Scanning](#device-scanning)
3. [Device Connection](#device-connection)
4. [Time Synchronization](#time-synchronization)
5. [User Parameters](#user-parameters)
6. [Device Association](#device-association)
7. [Connection Errors](#connection-errors)

---

## Connection Overview

The device connection process has **6 major steps**:

```
Step 1: Scan for Devices (30 seconds)
   │
   ▼
Step 2: User Selects Device
   │
   ▼
Step 3: Connect to Device (BLE)
   │
   ▼
Step 4: Sync Time (Mobile → Device)
   │
   ▼
Step 5: Set User Parameters
   │
   ▼
Step 6: Associate Device with User Account
   │
   ▼
Connection Complete! Start Data Streaming
```

---

## Device Scanning

**Location:** Lines 445-525  
**Duration:** 30 seconds (auto-stop)  
**Purpose:** Find HC20 devices nearby via Bluetooth Low Energy

### Scanning Flow Diagram

```
User Clicks "Start Scanning" Button
   │
   ▼
Check Battery Optimization
   │
   ├─── Disabled ──→ Continue
   │
   └─── Enabled ──→ Show Warning Dialog
                        │
                        ├─── User Dismisses ──→ Continue Anyway
                        └─── User Opens Settings ──→ Wait for User
   │
   ▼
Initialize HC20 Client (if first time)
   │
   ▼
Start BLE Scan
   │
   ├──→ Device Found ──→ Add to _discoveredDevices list
   ├──→ Device Found ──→ Add to list
   ├──→ Device Found ──→ Add to list
   │
   ▼
After 30 seconds → Auto-Stop Scan
   │
   ▼
Show List of Discovered Devices
```

### Code Walkthrough

```dart
void _startScanning() async {
  // STEP 1: Check battery optimization
  if (!_isBatteryOptimizationDisabled) {
    await _checkBatteryOptimizationStatus();
    
    if (!_isBatteryOptimizationDisabled) {
      // Show warning but allow scan
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Battery Optimization Enabled'),
          content: Text(
            'Background monitoring may not work properly. '
            'Please disable battery optimization for best results.'
          ),
          actions: [
            TextButton(
              child: Text('Continue Anyway'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text('Open Settings'),
              onPressed: () {
                Navigator.pop(context);
                _requestBatteryOptimizationExemption();
              },
            ),
          ],
        ),
      );
      return;  // Stop here if user opens settings
    }
  }
  
  // STEP 2: Initialize HC20 client if needed
  if (_client == null) {
    await _initializeHC20Client();
    if (_client == null) {
      setState(() {
        _statusMessage = 'Failed to initialize. Check OAuth credentials.';
      });
      return;
    }
  }

  // STEP 3: Start scanning
  setState(() {
    _isScanning = true;
    _discoveredDevices.clear();
    _statusMessage = 'Scanning for HC20 devices...';
  });

  // STEP 4: Listen for discovered devices
  _client!.scan().listen(
    (device) {
      // New device found!
      print('📡 Found device: ${device.name} (${device.id})');
      
      setState(() {
        // Avoid duplicates
        if (!_discoveredDevices.any((d) => d.id == device.id)) {
          _discoveredDevices.add(device);
          _statusMessage = 'Found ${_discoveredDevices.length} device(s)';
        }
      });
    },
    onError: (error) {
      print('❌ Scan error: $error');
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan error: $error';
      });
    },
  );

  // STEP 5: Auto-stop after 30 seconds
  Future.delayed(const Duration(seconds: 30), () {
    if (_isScanning) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan complete. ${_discoveredDevices.length} device(s) found.';
      });
    }
  });
}
```

### What Happens During Scan?

```
0s  → Scan starts
    → BLE radio turns on
    → Listening for advertisements

1s  → Device "HC20-1234" found
    → Added to list

5s  → Device "HC20-5678" found
    → Added to list

10s → Device "HC20-1234" seen again
    → Ignored (duplicate)

30s → Scan auto-stops
    → BLE radio returns to idle
    → Show devices to user
```

### Discovered Device Object

```dart
class Hc20Device {
  String id;        // e.g., "HC20-1234"
  String name;      // e.g., "HC20 Watch"
  int? rssi;        // Signal strength (-100 to 0 dBm)
  // Other properties...
}
```

**RSSI (Signal Strength):**
- `-30 to -50 dBm` = Excellent (very close)
- `-50 to -70 dBm` = Good (within range)
- `-70 to -90 dBm` = Fair (far away)
- `-90 to -100 dBm` = Poor (barely reachable)

---

## Device Connection

**Location:** Lines 527-690  
**Duration:** 5-15 seconds  
**Purpose:** Establish BLE connection and prepare device

### Connection Flow

```
User Taps Device in List
   │
   ▼
Update UI: "Connecting to HC20-1234..."
   │
   ▼
Call _client.connect(device)
   │
   ├──→ BLE GATT Connection Established
   │      │
   │      └──→ Service Discovery
   │             │
   │             ├──→ Device Info Service
   │             ├──→ Battery Service
   │             ├──→ Heart Rate Service
   │             └──→ Custom HC20 Services
   │
   ▼
Read Device Info
   │
   ├──→ Name: "HC20 Watch"
   ├──→ Version: "v2.1.0"
   ├──→ Serial: "ABC123"
   └──→ Battery: 85%
   │
   ▼
Sync Time with Device
   │
   ▼
Set User Parameters (age, height, weight)
   │
   ▼
Associate Device with User Account
   │
   ▼
Start Data Streaming
   │
   ▼
CONNECTION COMPLETE ✅
```

### Code Breakdown

```dart
Future<void> _connectToDevice(Hc20Device device) async {
  if (_client == null) return;

  try {
    // STEP 1: Show connecting status
    setState(() {
      _statusMessage = 'Connecting to ${device.name}...';
    });

    print('🔌 Attempting to connect to device: ${device.name}');
    print('⚠️  Note: Connection may fail if OAuth credentials are invalid');
    print('⚠️  HC20 SDK automatically enables raw data upload to cloud');
    
    // STEP 2: Connect to device (BLE GATT connection)
    // This takes 3-10 seconds
    // Automatically starts RawManager for cloud upload
    await _client!.connect(device);
    
    // STEP 3: Read device information
    final info = await _client!.readDeviceInfo(device);
    print('ℹ️  Device: ${info.name}');
    print('ℹ️  Version: ${info.version}');
    print('ℹ️  Battery: ${info.battery}%');
    
    // STEP 4: Sync time (CRITICAL - explained in next section)
    setState(() {
      _statusMessage = 'Syncing time with device...';
    });
    
    try {
      await _syncTimeWithDevice(device);
    } catch (timeError) {
      print('❌ Time sync error: $timeError');
      print('⚠️  Continuing without time sync - device may have incorrect time');
      // Continue anyway - not fatal
    }

    // STEP 5: Set user parameters
    await _client!.setParameters(device, {
      'user_info': {
        'age': 30,
        'height': 170,
        'weight': 70,
      },
    });

    // STEP 6: Update connection state
    setState(() {
      _connectedDevice = device;
      _isConnected = true;
      _statusMessage = 'Connected to ${info.name} v${info.version}';
    });

    // STEP 7: Associate with user account
    await _associateDeviceWithUser(device);

    // STEP 8: Start data streaming (covered in Part 4)
    _startRealtimeDataStream(device);
    _startConnectionMonitoring();
    _startHrvAutoRefresh();
    
    // STEP 9: Save device for auto-reconnect
    await _saveDeviceForAutoReconnect(device.id);
    
    // STEP 10: Reset reconnection counter
    _reconnectAttempts = 0;
    _isReconnecting = false;

    print('✅ Connection complete!');

  } catch (e) {
    // Handle errors (see Connection Errors section)
    _handleConnectionError(e);
  }
}
```

### What `_client.connect()` Does

The HC20 SDK handles these automatically:

1. **BLE GATT Connection**
   - Establish link-layer connection
   - Negotiate MTU (Maximum Transmission Unit)
   - Bond/pair if needed

2. **Service Discovery**
   - Find all GATT services
   - Find all characteristics
   - Find all descriptors

3. **Enable Notifications**
   - Subscribe to real-time data
   - Subscribe to battery updates
   - Subscribe to status changes

4. **Start RawManager**
   - Begin uploading raw data to Nitto cloud
   - Requires valid OAuth credentials
   - Runs in background

---

## Time Synchronization

**Location:** Lines 554-606  
**Why Critical:** Device timestamps must match real time for accurate health data

### The Problem

HC20 devices have an internal clock that may drift:
- ❌ Device clock: `2026-01-09 07:55:00` (5 minutes behind)
- ✅ Phone clock: `2026-01-09 08:00:00` (correct)

If not synced:
- Health data has wrong timestamps
- Backend rejects data as outdated
- Historical data queries fail

### Timezone Challenge

**Problem:** HC20 API expects timezone as **integer hours**, but some timezones have **30-minute offsets**.

Examples:
- `UTC+5:30` (India) → Can't represent as integer
- `UTC+9:00` (Japan) → Easy (just 9)

**Solution:** Adjust timestamp to compensate for partial hours.

### Code Implementation

```dart
Future<void> _syncTimeWithDevice(Hc20Device device) async {
  final now = DateTime.now();
  
  // Get timezone offset
  final offsetMinutes = now.timeZoneOffset.inMinutes;
  final offsetHours = offsetMinutes ~/ 60;      // Integer hours
  final remainingMinutes = offsetMinutes % 60;  // Remaining minutes
  
  // Adjust timestamp for non-hour offsets
  // Example: UTC+5:30
  // - offsetHours = 5
  // - remainingMinutes = 30
  // - Add 30*60 seconds to timestamp
  final adjustedTimestamp = (now.millisecondsSinceEpoch ~/ 1000) 
                          + (remainingMinutes * 60);
  
  print('⏰ Syncing time with device...');
  print('   Mobile time: ${now.toIso8601String()}');
  print('   Base timestamp: ${now.millisecondsSinceEpoch ~/ 1000}');
  print('   Adjusted timestamp: $adjustedTimestamp');
  print('   Timezone: UTC+${offsetMinutes / 60.0} (sending as $offsetHours hours)');
  
  // Send to device
  await _client!.setTime(
    device,
    timestamp: adjustedTimestamp,
    timezone: offsetHours,
  );
  
  print('✓ Time synced successfully');
  
  // Verify sync
  final deviceTime = await _client!.getTime(device);
  final timeDiff = (now.millisecondsSinceEpoch ~/ 1000) - deviceTime.timestamp;
  
  print('✓ Device time verification:');
  print('   Device timestamp: ${deviceTime.timestamp}');
  print('   Device timezone: UTC+${deviceTime.timezone}');
  print('   Time difference: ${timeDiff.abs()} seconds');
  
  if (timeDiff.abs() > 60) {
    print('⚠️  Time difference > 1 minute, retrying...');
    await Future.delayed(Duration(seconds: 2));
    await _syncTimeWithDevice(device);  // Retry once
  } else {
    print('✅ Time sync verified (diff < 1 minute)');
    _lastTimeSyncStatus = '✅ Synced (diff: ${timeDiff}s)';
    _lastTimeSyncTime = DateTime.now();
  }
}
```

### Timezone Examples

| Location | Timezone | offsetHours | remainingMinutes | Adjustment |
|----------|----------|-------------|------------------|------------|
| India | UTC+5:30 | 5 | 30 | +1800s |
| Australia | UTC+9:30 | 9 | 30 | +1800s |
| Nepal | UTC+5:45 | 5 | 45 | +2700s |
| Japan | UTC+9:00 | 9 | 0 | 0s |
| USA EST | UTC-5:00 | -5 | 0 | 0s |

---

## User Parameters

**Location:** Lines 624-630  
**Purpose:** Configure device for personalized health calculations

```dart
await _client!.setParameters(device, {
  'user_info': {
    'age': 30,        // Years
    'height': 170,    // Centimeters
    'weight': 70,     // Kilograms
  },
});
```

### Why These Matter

The device uses these parameters to calculate:

| Metric | Uses Age? | Uses Height? | Uses Weight? |
|--------|-----------|--------------|--------------|
| **Heart Rate Zones** | ✅ Yes | ❌ No | ❌ No |
| **Calorie Burn** | ✅ Yes | ✅ Yes | ✅ Yes |
| **BMI** | ❌ No | ✅ Yes | ✅ Yes |
| **VO2 Max** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Step Length** | ❌ No | ✅ Yes | ❌ No |

### 🎯 Improvement Needed

**Current:** Hardcoded values  
**Better:** Get from user profile

```dart
final authService = Provider.of<AuthService>(context, listen: false);
final user = authService.currentUser;

await _client!.setParameters(device, {
  'user_info': {
    'age': user?.age ?? 30,
    'height': user?.height ?? 170,
    'weight': user?.weight ?? 70,
  },
});
```

---

## Device Association

**Location:** Lines 692-745  
**Purpose:** Link device to user account in backend database

### Why Associate?

Without association:
- ❌ Data stored without owner info
- ❌ Multiple users can't share devices
- ❌ Can't track device history
- ❌ Can't show "My Devices" list

With association:
- ✅ Data tagged with user ID
- ✅ User can see their device history
- ✅ Backend can send personalized alerts
- ✅ Support multiple devices per user

### Code Flow

```dart
Future<void> _associateDeviceWithUser(Hc20Device device) async {
  try {
    // Get logged-in user
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      print('⚠️ No user logged in, skipping device association');
      return;
    }
    
    print('🔗 Associating device ${device.id} with user ${user.id}');
    
    setState(() {
      _statusMessage = 'Linking device to your account...';
    });
    
    // Call backend API
    final response = await _apiService.associateDevice(
      device.id,
      user.id,
      deviceName: device.name,
    );
    
    if (response['success'] == true) {
      print('✅ Device associated successfully!');
      print('   Updated ${response['updatedRecords']} records');
      
      setState(() {
        _isDeviceAssociated = true;
        _statusMessage = 'Device linked! Updated ${response['updatedRecords']} health records';
      });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device linked to your account'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      print('⚠️ Device association failed: ${response['error']}');
      setState(() {
        _statusMessage = 'Warning: Device not linked to account';
      });
    }
  } catch (e) {
    print('❌ Error associating device: $e');
    setState(() {
      _statusMessage = 'Warning: Could not link device to account';
    });
    // Non-fatal - continue anyway
  }
}
```

### Backend API Call

```dart
// ApiService.associateDevice()
Future<Map<String, dynamic>> associateDevice(
  String deviceId,
  String userId,
  {String? deviceName}
) async {
  final response = await _dio.post(
    'https://api.hireforcare.com/devices/associate',
    data: {
      'device_id': deviceId,
      'user_id': userId,
      'device_name': deviceName,
      'associated_at': DateTime.now().toIso8601String(),
    },
  );
  
  return response.data;
}
```

### Database Schema

```sql
CREATE TABLE device_associations (
  id SERIAL PRIMARY KEY,
  device_id VARCHAR(50) NOT NULL,
  user_id INTEGER NOT NULL REFERENCES users(id),
  device_name VARCHAR(100),
  associated_at TIMESTAMP DEFAULT NOW(),
  last_seen_at TIMESTAMP,
  UNIQUE(device_id, user_id)
);
```

---

## Connection Errors

### Error Types & Solutions

#### Error 1: Service Discovery Failure
```
Exception: service_discovery_failure (status 8)
```

**Cause:** Device disconnected during GATT service discovery  
**Common Reason:** Invalid OAuth credentials → RawManager fails → Device disconnects

**Solution:**
```dart
if (e.toString().contains('service_discovery_failure') || 
    e.toString().contains('status 8')) {
  errorMessage = 'Connection failed: Device disconnected during setup.\n\n'
      'This often happens when OAuth credentials are invalid. '
      'The HC20 SDK tries to start cloud upload and fails, '
      'causing the device to disconnect.\n\n'
      'Contact dev team for valid OAuth credentials.';
}
```

#### Error 2: OAuth/Authentication
```
Exception: Invalid OAuth credentials (401)
```

**Cause:** Wrong clientId or clientSecret  
**Solution:** Get correct credentials from Nitto

```dart
if (e.toString().contains('Invalid OAuth') || 
    e.toString().contains('401') ||
    e.toString().contains('authentication')) {
  errorMessage = 'Authentication failed: Invalid OAuth credentials.\n\n'
      'The HC20 SDK requires valid clientId and clientSecret '
      'for cloud data upload. Contact dev team for credentials.';
}
```

#### Error 3: Device Out of Range
```
Exception: Connection timeout
```

**Cause:** Device too far away or powered off  
**Solution:** Ask user to bring device closer

#### Error 4: Bluetooth Off
```
Exception: Bluetooth is powered off
```

**Cause:** User disabled Bluetooth  
**Solution:** Show dialog to enable Bluetooth

```dart
if (e.toString().contains('powered off')) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Bluetooth Required'),
      content: Text('Please turn on Bluetooth to connect to devices.'),
      actions: [
        TextButton(
          child: Text('Open Settings'),
          onPressed: () => AppSettings.openBluetoothSettings(),
        ),
      ],
    ),
  );
}
```

---

## Troubleshooting Guide

### Connection Takes Too Long (>30s)

**Possible Causes:**
1. Weak signal (device too far)
2. Multiple BLE devices nearby (interference)
3. Android BLE stack issues

**Solutions:**
- Move device within 1 meter
- Turn off other BLE devices
- Restart phone Bluetooth

### Connection Succeeds Then Immediately Disconnects

**Possible Causes:**
1. Invalid OAuth credentials
2. Battery optimization killing app
3. Device battery low

**Solutions:**
- Check OAuth credentials
- Disable battery optimization
- Charge device

### Time Sync Fails

**Possible Causes:**
1. Device firmware old
2. BLE connection unstable

**Solutions:**
- Update device firmware
- Retry connection
- Reset device

---

## Best Practices

### ✅ DO
- Show connection progress to user
- Verify time sync completed
- Handle all error types gracefully
- Provide helpful error messages
- Test with multiple devices
- Log connection events

### ❌ DON'T
- Hardcode user parameters
- Ignore time sync errors silently
- Block UI during connection
- Give up after one failed attempt
- Skip device association
- Use generic error messages

---

## Next Steps

Continue to Part 4 for data streaming and webhooks:

📄 **[Part 4: Data Streaming & Webhooks →](04_DATA_STREAMING_WEBHOOKS.md)**

---

**End of Part 3**  
**Previous: [Part 2 - Initialization](02_INITIALIZATION_AND_SETUP.md)**  
**Next: [Part 4 - Data Streaming](04_DATA_STREAMING_WEBHOOKS.md)**
