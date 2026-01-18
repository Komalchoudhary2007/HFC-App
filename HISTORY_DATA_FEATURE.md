# History Data Fetch Feature

## ⚠️ IMPORTANT: Feature Currently DISABLED

**The automatic history data fetch is currently DISABLED** due to connection stability issues:
- Was causing Dio exceptions when sending data
- Device disconnections during history fetch
- Slow reconnection times

The feature code is present but commented out. Enable manually only when backend is ready and after thorough testing.

## Overview
This feature automatically detects data gaps when a device reconnects and fetches historical data from the device to ensure no data is lost during disconnection periods.

## How It Works

### 1. **Last Data Tracking**
- The app tracks the last data received timestamp for each device
- Stored in memory using `Map<String, DateTime> _lastDataReceivedByDevice`
- Key: Device ID
- Value: Last data received timestamp

### 2. **Gap Detection**
When webhook data is successfully sent:
1. App checks when data was last received from this device
2. Calculates time difference between now and last received time
3. If gap is **≥ 10 minutes**, triggers historical data fetch

### 3. **Historical Data Fetch**
If a gap is detected, the app automatically:
- Fetches **Heart Rate** history for the 10-minute gap period
- Fetches **HRV (Heart Rate Variability)** history for the gap period
- Fetches **Summary** data (steps, calories, distance) for the gap period

### 4. **Data Transmission**
Each historical record is:
- Sent individually to the webhook endpoint
- Marked with `"dataType": "history"` to distinguish from live data
- Tagged with history type: `"heart_rate"`, `"hrv"`, or `"summary"`
- Includes original data timestamp for proper sequencing

## Key Functions

### `_fetchAndSendHistoryDataAfterWebhook(Hc20Device device)`
Main coordinator function that:
- Prevents simultaneous history fetches
- Checks last data received timestamp
- Detects gaps ≥ 10 minutes
- Triggers appropriate history fetch functions

### `_fetchAndSendHeartRateHistory(device, startTime, endTime)`
- Fetches heart rate records from device
- Sends each record to webhook with `historyType: "heart_rate"`

### `_fetchAndSendHRVHistory(device, startTime, endTime)`
- Fetches HRV records from device
- Sends each record to webhook with `historyType: "hrv"`

### `_fetchAndSendSummaryHistory(device, startTime, endTime)`
- Fetches summary records (steps, calories, distance)
- Sends each record to webhook with `historyType: "summary"`

## Webhook Payload Structure

### Live Data (Normal)
```json
{
  "timestamp": "2026-01-17T10:30:00.000Z",
  "dataType": "live",
  "device": { "id": "...", "name": "..." },
  "realtime_data": { ... }
}
```

### Historical Data
```json
{
  "timestamp": "2026-01-17T10:30:00.000Z",
  "dataType": "history",
  "historyType": "heart_rate",
  "device": { "id": "...", "name": "..." },
  "history_data": {
    "heart_rate": "...",
    "data_timestamp": "2026-01-17T10:15:00.000Z"
  }
}
```

## Usage Example

### Scenario
1. Device connected at 9:00 AM, sending data normally
2. Device disconnects at 9:15 AM
3. Device reconnects at 9:30 AM (15-minute gap)

### What Happens
1. ✅ Live data webhook sent at 9:30 AM
2. 🔍 App detects 15-minute gap (≥ 10 minutes threshold)
3. 📊 App fetches historical data from 9:15 AM to 9:25 AM (10 minutes)
4. 📤 Sends all historical records to webhook
5. 💾 Backend receives both live and historical data

## Benefits

1. **No Data Loss**: Captures data recorded during disconnection
2. **Automatic**: No manual intervention required
3. **Non-Blocking**: Runs asynchronously, doesn't affect live data
4. **Backend-Friendly**: Clear data type markers for easy processing
5. **Reliable**: Error handling prevents crashes

## Backend Integration

Your backend should:

1. **Check `dataType` field**:
   - `"live"` = Real-time data from device
   - `"history"` = Historical data fetched after reconnection

2. **For history data, check `historyType`**:
   - `"heart_rate"` = Heart rate measurements
   - `"hrv"` = HRV metrics
   - `"summary"` = Steps, calories, distance

3. **Use `data_timestamp`**:
   - This is when the data was originally recorded on device
   - Different from `timestamp` (when data was sent to webhook)

## Configuration

### Enable/Disable Automatic History Fetch

To **enable** automatic history fetch (in [lib/main.dart](lib/main.dart) line ~1990):
```dart
// After successful webhook, check if we need to fetch and send historical data
_fetchAndSendHistoryDataAfterWebhook(device).catchError((error) {
  print('⚠️ History data fetch failed (non-critical): $error');
});
```

Currently **disabled** (recommended):
```dart
// DISABLED: Automatic history fetch causes connection issues
// _fetchAndSendHistoryDataAfterWebhook(device);
```

### Threshold (10 minutes)
To change the gap detection threshold, modify line in `_fetchAndSendHistoryDataAfterWebhook()`:
```dart
if (timeSinceLastData.inMinutes >= 10) {  // Change 10 to your desired minutes
```

### Delay Between Requests
To change delay between sending historical records (updated to 500ms for stability):
```dart
await Future.delayed(const Duration(milliseconds: 500));  // Increased from 100ms
```

### Rate Limiting
- Maximum 20 records sent per history type (prevents overwhelming)
- 5-second delay before starting history fetch
- 2-second delay between different history types
- 30-second timeout on device data fetch operations

## Performance Improvements

Recent updates to prevent connection issues:
1. **Longer timeouts**: 10 seconds for webhook requests (vs 5 seconds)
2. **Device fetch timeout**: 30-second timeout with graceful fallback
3. **Rate limiting**: Max 20 records per type, 500ms delay between sends
4. **Initial delay**: 5-second wait before starting history fetch
5. **Inter-type delay**: 2-second pause between heart rate, HRV, and summary fetches
6. **Continue on error**: Failed records don't stop the entire process

## Error Handling

- History fetch failures don't crash the app
- Non-critical errors are logged but don't affect live data transmission
- Flag `_isProcessingHistoryData` prevents simultaneous fetches
- Each history type fetch is independent (one failing doesn't stop others)

## Logs

Look for these log messages:

```
📊 HISTORY DATA CHECK
📊 Device: XX:XX:XX:XX:XX:XX
📊 Last received: 2026-01-17 09:15:00
📊 Time since last: 15 minutes
🔍 Gap detected! Fetching 10 minutes of historical data...
💓 Fetching heart rate history...
📈 Fetching HRV history...
📊 Fetching summary history...
✅ Historical data fetched and sent for 10-minute gap
```

## Notes

- First data from a device doesn't trigger history fetch
- History fetch is non-blocking and won't slow down live data
- Each device is tracked independently
- Historical data is sent with small delays to avoid overwhelming server
