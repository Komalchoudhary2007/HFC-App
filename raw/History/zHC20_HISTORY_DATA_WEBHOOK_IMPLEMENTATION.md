# HC20 History Data Webhook Implementation Guide

## Overview
This document explains how HRV2 historical data is being sent to your webhook endpoint, including both automatic (every 6 hours) and manual (button click) sending mechanisms.

---

## Architecture

### Data Flow Diagram

```
HC20 Device
    ↓
Fetch HRV2 Data (SDK)
    ├─→ Nitto Cloud (Automatic upload by SDK)
    └─→ Your Webhook (NEW: https://api.hireforcare.com/webhook/hc20-data)
```

### Two Types of Sends

#### 1. **AUTOMATIC (Every 6 Hours)** 🔄
- **Trigger**: Device connection → Immediate first fetch → Then every 6 hours
- **Destination**: 
  - Nitto cloud (SDK automatic upload)
  - Your webhook (NEW)
- **Function Flow**: 
  ```
  _startHrv2AutoRefresh() 
    → Timer.periodic(6 hours)
    → _fetchHrv2Data()
    → _sendHrv2ToWebhook(isAutomatic: true)
  ```

#### 2. **MANUAL (Button Click)** 👆
- **Trigger**: User clicks "Send History" button
- **Destination**: Your webhook only
- **Function Flow**:
  ```
  _sendHistoryDataToWebhook() 
    → Fetch HRV2 data
    → _sendHrv2ToWebhook(isAutomatic: false)
  ```

---

## Functions Added/Modified

### New Helper Functions

#### 1. `_convertHrv2RowsToJson()`
**Purpose**: Convert HC20 SDK HRV2 format to backend format

**Location**: [lib/main.dart](lib/main.dart#L1567)

**Input**:
```dart
List<dynamic> hrv2Rows  // From SDK's getAllDayHrv2Rows()
```

**Output**:
```dart
List<Map<String, dynamic>> hrv2JsonList
```

**Process**:
- Extracts values from `row.values` map (SDK format)
- Parses `row.dateTime` string to extract date components
- Maps SDK field names (camelCase) to backend format (snake_case):
  - `mentalStress` → `mental_stress`
  - `fatigue` → `fatigue_level`
  - `stressResistance` → `stress_resistance`
  - `regulationAbility` → `regulation_ability`

**Code**:
```dart
List<Map<String, dynamic>> _convertHrv2RowsToJson(List<dynamic> hrv2Rows) {
  return hrv2Rows.map((row) {
    final values = row.values ?? {};
    
    DateTime? parsedDateTime;
    try {
      parsedDateTime = DateTime.parse(row.dateTime);
    } catch (e) {
      parsedDateTime = DateTime.now();
    }
    
    
    return {
      'dateTime': row.dateTime,
      'mental_stress': values['mentalStress'],
      'fatigue_level': values['fatigue'],
      'stress_resistance': values['stressResistance'],
      'regulation_ability': values['regulationAbility'],
      'valid': row.valid,
    };
  }).toList();
}
```

---

#### 2. `_sendHrv2ToWebhook()`
**Purpose**: Send HRV2 data to webhook with proper formatting

**Location**: [lib/main.dart](lib/main.dart#L1608)

**Parameters**:
```dart
List<dynamic> hrv2Rows          // HRV2 data from device
String dateStr                  // Date in 'YYYY-MM-DD' format
bool isAutomatic = false        // true = automatic 6-hour, false = manual
```

**Features**:
- Uses helper function to convert rows to JSON
- Builds payload with all metadata
- Sends POST request to webhook
- Handles success/error responses
- Updates success/error counters
- Detailed logging

**Payload Structure**:
```json
{
  "dataType": "history",
  "historyType": "hrv2",
  "source": "auto_6hour_refresh" or "manual_send",
  "timestamp": "2025-01-19T10:30:45.123456Z",
  "device": {
    "id": "device_id_xyz",
    "name": "HC20 Device"
  },
  "history_data": {
    "hrv2": [
      {
        "dateTime": "2025-01-19T10:30:45Z",
        "mental_stress": 45,
        "fatigue_level": 32,
        "stress_resistance": 78,
        "regulation_ability": 65,
        "valid": true
      }
      // ... more records
    ],
    "phone": "+1234567890",
    "date": "2025-01-19",
    "recordCounts": {
      "hrv2": 24
    }
  },
  "recordCounts": {
    "hrv2": 24
  }
}
```

**Code**:
```dart
Future<void> _sendHrv2ToWebhook(List<dynamic> hrv2Rows, String dateStr, {bool isAutomatic = false}) async {
  try {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    final now = DateTime.now();
    
    final hrv2JsonList = _convertHrv2RowsToJson(hrv2Rows);
    
    final payload = {
      'dataType': 'history',
      'historyType': 'hrv2',
      'source': isAutomatic ? 'auto_6hour_refresh' : 'manual_send',
      'timestamp': now.toIso8601String(),
      'device': {
        'id': _connectedDevice!.id,
        'name': _connectedDevice!.name,
      },
      'history_data': {
        'hrv2': hrv2JsonList,
        'phone': user?.phone ?? 'unknown',
        'date': dateStr,
        'recordCounts': {
          'hrv2': hrv2JsonList.length,
        }
      },
      'recordCounts': {
        'hrv2': hrv2JsonList.length,
      }
    };

    print('\n📤 ========================================');
    print('📤 Sending HRV2 ${isAutomatic ? '(AUTO 6-hour)' : '(MANUAL)'} to webhook');
    print('📤 URL: $_webhookUrl');
    print('📤 Records: ${hrv2JsonList.length}');
    print('📤 Phone: ${user?.phone ?? 'unknown'}');
    print('📤 Source: ${isAutomatic ? 'Automatic 6-hour refresh' : 'Manual send button'}');
    print('📤 ========================================\n');

    final response = await _dio.post(
      _webhookUrl,
      data: payload,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('✅ HRV2 webhook response: ${response.statusCode}');
      print('✅ Backend received ${hrv2JsonList.length} HRV2 records');
      print('✅ Response: ${response.data}');
      _webhookSuccessCount++;
    } else {
      print('⚠️  Unexpected status code: ${response.statusCode}');
      print('📄 Response: ${response.data}');
    }
  } catch (e) {
    print('❌ Error sending HRV2 to webhook: $e');
    _webhookErrorCount++;
    rethrow;
  }
}
```

---

### Modified Functions

#### 1. `_fetchHrv2Data()` (AUTOMATIC)
**Previous Behavior**: Fetched HRV2 from device, uploaded to Nitto cloud only

**New Behavior**: Also sends to your webhook after fetching

**Location**: [lib/main.dart](lib/main.dart#L1606)

**Changes**:
```dart
// BEFORE
final hrv2Rows = await _client!.getAllDayHrv2Rows(...);
print('✅ HRV2 data fetched: ${hrv2Rows.length} records');
print('✅ Data automatically uploaded to Nitto cloud by SDK');
print('✅ HRV2 refresh completed successfully\n');

// AFTER
final hrv2Rows = await _client!.getAllDayHrv2Rows(...);
print('✅ HRV2 data fetched: ${hrv2Rows.length} records');
print('✅ Data automatically uploaded to Nitto cloud by SDK');

// Also send to your webhook (NEW)
if (hrv2Rows.isNotEmpty) {
  print('📤 Also sending to your webhook...');
  await _sendHrv2ToWebhook(hrv2Rows, dateStr, isAutomatic: true);
} else {
  print('⚠️  No HRV2 records to send to webhook');
}

print('✅ HRV2 refresh completed successfully\n');
```

**Call Stack**:
```
_startHrv2AutoRefresh()
  └─ Timer.periodic(6 hours) or _fetchHrv2Data()
     └─ _fetchHrv2Data()
        └─ _sendHrv2ToWebhook(hrv2Rows, dateStr, isAutomatic: true)
           ├─ _convertHrv2RowsToJson()
           └─ _dio.post() to webhook
```

---

#### 2. `_sendHistoryDataToWebhook()` (MANUAL)
**Previous Behavior**: Had inline conversion and webhook sending logic

**New Behavior**: Uses helper functions for cleaner code

**Location**: [lib/main.dart](lib/main.dart#L2849)

**Changes**:
```dart
// BEFORE - Inline conversion logic (40+ lines)
List<Map<String, dynamic>> hrv2JsonList = hrv2Rows.map((row) {
  final values = row.values ?? {};
  DateTime? parsedDateTime;
  try {
    parsedDateTime = DateTime.parse(row.dateTime);
  } catch (e) {
    parsedDateTime = DateTime.now();
  }
  final yy = parsedDateTime.year % 100;
  // ... 30+ more lines ...
  return {...};
}).toList();

// AFTER - Uses helper function
final hrv2JsonList = _convertHrv2RowsToJson(hrv2Rows);
await _sendHrv2ToWebhook(hrv2Rows, dateStr, isAutomatic: false);
```

**Benefits**:
- Code reuse between manual and automatic sending
- Easier maintenance
- Single source of truth for conversion logic

**Call Stack**:
```
_sendHistoryDataToWebhook() [UI Button triggered]
  ├─ Fetch HRV2 data from device
  └─ _sendHrv2ToWebhook(hrv2Rows, dateStr, isAutomatic: false)
     ├─ _convertHrv2RowsToJson()
     └─ _dio.post() to webhook
```

---

## Data Sending Timeline

### Automatic Sending
```
Device Connected
    ↓
_startHrv2AutoRefresh() called
    ↓
Immediate first HRV2 fetch & webhook send
    ↓
Timer starts (6-hour interval)
    ↓
Every 6 hours:
  ├─ Fetch HRV2 from device
  ├─ Send to Nitto cloud (SDK automatic)
  └─ Send to your webhook (_sendHrv2ToWebhook)
    ↓
Continues until device disconnects
```

### Manual Sending
```
User clicks "Send History" button
    ↓
_sendHistoryDataToWebhook() triggered
    ↓
Fetch HRV2 from device (today's date)
    ↓
_sendHrv2ToWebhook(isAutomatic: false)
    ↓
Backend receives data
    ↓
Modal dialog shown with confirmation
```

---

## Configuration

### Webhook URL
```dart
static const String _webhookUrl = 'https://api.hireforcare.com/webhook/hc20-data';
```

### Auto-Refresh Interval
```dart
Timer.periodic(const Duration(hours: 6), (timer) async { ... })
```

### HTTP Client Configuration
```dart
final _dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 30),
  receiveTimeout: const Duration(seconds: 30),
  sendTimeout: const Duration(seconds: 30),
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
));
```

---

## Error Handling

### Automatic Send Errors
- If webhook send fails, error is logged but doesn't interrupt device operations
- Error counter is incremented: `_webhookErrorCount++`
- Retry happens automatically on next 6-hour cycle

### Manual Send Errors
- Shows error dialog to user
- Error message includes exception details
- User can retry by clicking button again

### Logging
All operations include detailed console logging:
```
📊 [Fetch operations]
📤 [Webhook sends]
✅ [Successes]
❌ [Errors]
⚠️  [Warnings]
```

---

## Testing the Implementation

### Test Automatic Sending
1. Connect HC20 device to app
2. Check terminal logs for:
   ```
   📊 Fetching HRV2 data (AUTOMATIC - 6 hour refresh)
   📤 Also sending to your webhook...
   ✅ HRV2 webhook response: 200
   ```

### Test Manual Sending
1. Connect HC20 device
2. Click "Send History" button
3. Check for:
   - Modal dialog with success confirmation
   - Terminal logs showing webhook request
   - Backend database entry

### Backend Verification
Check your backend logs/database for:
```json
{
  "source": "auto_6hour_refresh" or "manual_send",
  "history_data.hrv2": [...records...]
}
```

---

## State Variables Used

```dart
// Timers
Timer? _hrv2RefreshTimer;  // Controls 6-hour automatic refresh

// HTTP Client
late final Dio _dio;  // Sends webhook requests

// Counters
int _webhookSuccessCount = 0;
int _webhookErrorCount = 0;

// Status
String _lastWebhookStatus = '';
String _lastWebhookError = '';
DateTime? _lastWebhookTime;

// Device Reference
Hc20Device? _connectedDevice;  // Current connected device
Hc20Client? _client;  // SDK client
```

---

## How to Implement in Another Codebase

### Step 1: Copy Helper Functions
Copy these three functions to your main.dart:
1. `_convertHrv2RowsToJson()`
2. `_sendHrv2ToWebhook()`
3. Update `_fetchHrv2Data()` to call webhook sender

### Step 2: Ensure Dependencies
```yaml
dependencies:
  dio: ^5.0.0  # HTTP client
  provider: ^6.0.0  # State management
  flutter_local_notifications: ^14.0.0  # Notifications
  hc20: ^1.0.4  # HC20 SDK
```

### Step 3: Configure Webhook URL
```dart
static const String _webhookUrl = 'YOUR_WEBHOOK_ENDPOINT';
```

### Step 4: Call from Your Auto-Refresh
```dart
void _startHrv2AutoRefresh() {
  _hrv2RefreshTimer = Timer.periodic(const Duration(hours: 6), (timer) async {
    if (_isConnected && _connectedDevice != null && _client != null) {
      await _fetchHrv2Data();  // This now calls webhook sender
    }
  });
}
```

### Step 5: Add Manual Trigger (Optional)
Add a button to UI:
```dart
ElevatedButton(
  onPressed: _isConnected ? _sendHistoryDataToWebhook : null,
  child: Text('Send History'),
)
```

---

## Changes Summary Table

| Function | Type | Change | Purpose |
|----------|------|--------|---------|
| `_convertHrv2RowsToJson()` | New | N/A | Converts SDK format to backend format |
| `_sendHrv2ToWebhook()` | New | N/A | Sends HRV2 data to webhook |
| `_fetchHrv2Data()` | Modified | Added webhook call | Automatic 6-hour webhook sending |
| `_sendHistoryDataToWebhook()` | Modified | Refactored | Now uses helper functions |

---

## Files Modified

- `/workspaces/HFC-App/lib/main.dart`
  - Added `_convertHrv2RowsToJson()` function
  - Added `_sendHrv2ToWebhook()` function
  - Modified `_fetchHrv2Data()` function
  - Refactored `_sendHistoryDataToWebhook()` function

---

## Performance Considerations

- **Automatic Sends**: Run every 6 hours, minimal impact on device
- **Data Conversion**: O(n) where n = number of HRV2 records (typically 24-48 per day)
- **Webhook Request**: Async, doesn't block UI
- **Error Handling**: Non-blocking, continues operation if webhook fails

---

## Future Enhancements

1. Add queue system for failed webhook sends
2. Add compression for large payloads
3. Add batch webhook sends (combine multiple 6-hour periods)
4. Add retry logic with exponential backoff
5. Add local storage for offline webhook queuing

---

## Support & Debugging

### Enable Detailed Logging
Dio already logs all requests:
```dart
_dio.interceptors.add(LogInterceptor(
  requestBody: true,
  responseBody: true,
  error: true,
  logPrint: (obj) => print('🌐 Dio Log: $obj'),
));
```

### Check Webhook Success Rate
```dart
print('Success: $_webhookSuccessCount');
print('Errors: $_webhookErrorCount');
print('Last Status: $_lastWebhookStatus');
print('Last Time: $_lastWebhookTime');
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Webhook not receiving data | Check webhook URL is correct |
| Wrong field names in backend | Verify snake_case conversion in helper |
| Data not sent every 6 hours | Check device stays connected |
| Modal not showing | Ensure `mounted` check is true |

---

**Document Version**: 1.0  
**Date**: January 19, 2026  
**Last Updated**: [Current Session]
