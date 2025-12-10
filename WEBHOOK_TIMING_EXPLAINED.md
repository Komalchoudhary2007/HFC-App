# 🕐 HC20 Webhook Timing - Complete Explanation

## ⚠️ **Important Discovery About HC20 Device**

After reviewing the HC20 SDK documentation and source code, I discovered:

**The HC20 device does NOT automatically send real-time data at any fixed interval.**

### How HC20 Real-Time Data Works:

```dart
// When you call realtimeV2(), it sends this command to the device:
_tx.request(d.id, 0x05, const [0x02])  // Trigger command

// Device responds with ONE data packet
// Then stops until you send the trigger again
```

**The device ONLY sends data when you explicitly request it via the `0x05` `0x02` command.**

---

## ✅ **Solution Implemented in v1.4.0**

### Automatic 5-Second Webhook Interval

I've implemented a **Timer.periodic** that triggers data refresh every 5 seconds:

```dart
// Timer runs every 5 seconds
_dataRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
  // Send trigger to HC20 device
  _client!.realtimeV2(device).listen((data) {
    // Update UI
    setState(() { ... });
    
    // Send to webhook
    _sendDataToWebhook(device, data);
  });
});
```

---

## 📊 **Webhook Timing Details**

### Main Page (Home Screen):
- **First webhook**: Immediate (when device connects)
- **Subsequent webhooks**: Every 5 seconds
- **Automatic**: Yes - runs in background while connected
- **Stops when**: Device disconnected or app closed

### All Data Page:
- **First data update**: Immediate (when page opens)
- **Subsequent updates**: Every 5 seconds
- **Automatic**: Yes - refreshes while page is open
- **Stops when**: Page is closed or device disconnected

---

## ⏱️ **Timeline Example**

```
00:00 - User connects to HC20 device
00:00 - First webhook sent immediately (Main page)
00:05 - Second webhook sent (5-second timer)
00:10 - Third webhook sent (5-second timer)
00:15 - Fourth webhook sent (5-second timer)
00:20 - Fifth webhook sent (5-second timer)
...continues every 5 seconds...

00:30 - User clicks "View All Data"
00:30 - All Data page opens, starts its own 5-second timer
00:35 - All Data page refreshes (5-second timer)
00:40 - All Data page refreshes (5-second timer)
...both timers run simultaneously...

01:00 - User goes back to Main page
01:00 - All Data page timer stops
...Main page timer continues every 5 seconds...
```

---

## 🔍 **Why This Solution?**

### Problem with Previous Approach:
❌ Assumed HC20 device would send data automatically  
❌ Only called `realtimeV2()` once on connection  
❌ Device stopped sending after first response  
❌ Webhook only triggered when "View All Data" was clicked (because that called `realtimeV2()` again)

### Current Solution:
✅ Timer calls `realtimeV2()` every 5 seconds to trigger device  
✅ Device responds with fresh data each time  
✅ Webhook sends automatically every 5 seconds  
✅ Works on both Main page and All Data page  
✅ No manual interaction needed

---

## 🎯 **Webhook Payload**

Every 5 seconds, the following JSON is sent to:
**https://api.hireforcare.com/webhook/hc20-data**

```json
{
  "timestamp": "2025-12-04T10:00:00.000Z",
  "device": {
    "id": "XX:XX:XX:XX:XX:XX",
    "name": "HC20-XXXX"
  },
  "realtime_data": {
    "heart_rate": 75,
    "rri": [800, 810, 795],
    "spo2": 98,
    "blood_pressure": {
      "systolic": 120,
      "diastolic": 80
    },
    "temperature": [36.5],
    "battery": {
      "percent": 85,
      "charge": 1
    },
    "basic_data": [1234, 450, 890],
    "barometric_pressure": [1013],
    "wear_status": [1],
    "sleep": [0, 0, 0, 0, 1],
    "gnss": [1, 3, 1638614400, 37.7749, -122.4194, 50],
    "hrv_raw": [50000, 2500000, 800000, 600000, 1100000],
    "hrv_metrics": {
      "sdnn": 50.0,
      "tp": 2500.0,
      "lf": 800.0,
      "hf": 600.0,
      "vlf": 1100.0
    },
    "hrv2_raw": [35, 25, 70, 65],
    "hrv2_metrics": {
      "mental_stress": 35,
      "fatigue_level": 25,
      "stress_resistance": 70,
      "regulation_ability": 65
    }
  }
}
```

---

## 🔧 **Customizing the Interval**

To change the webhook interval, modify this line in `lib/main.dart`:

```dart
// Change Duration(seconds: 5) to your desired interval
_dataRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
  ...
});
```

### Recommended Intervals:
- **5 seconds**: Good balance (current setting)
- **10 seconds**: Reduces battery usage
- **3 seconds**: More frequent updates (higher battery drain)
- **1 second**: Maximum frequency (not recommended - high battery drain)

**Note:** The HC20 device itself may have internal rate limits. Testing with real hardware will determine the optimal interval.

---

## 📱 **What You'll See in Console Logs**

```
🚀 ========================================
🚀 Starting real-time data stream for device: HC20-1234
🚀 Device ID: AA:BB:CC:DD:EE:FF
🚀 Webhook URL: https://api.hireforcare.com/webhook/hc20-data
🚀 Data refresh: Every 5 seconds
🚀 ========================================

✓ Real-time stream subscription created and stored in _realtimeSubscription
✓ Starting periodic timer to request data every 5 seconds...
✓ Webhook will send automatically every 5 seconds

⏰ [Timer] Requesting fresh data from device...

📊 [2025-12-04T10:00:00.000Z] Received real-time data:
   Heart: 75, SpO2: 98, BP: [120, 80]
   Temp: [3650], Battery: 85%
   Steps: 1234
📤 Sending data to webhook at https://api.hireforcare.com/webhook/hc20-data...

✅ ========================================
✅ Webhook SUCCESS!
✅ Status Code: 200
✅ Success Count: 1
✅ Response: {"status":"ok"}
✅ ========================================

⏰ [Timer] Requesting fresh data from device...
(repeats every 5 seconds)
```

---

## ✅ **Success Indicators**

You'll know it's working when you see:
1. ✓ Timer logs every 5 seconds: `⏰ [Timer] Requesting fresh data...`
2. ✓ Data reception logs every 5 seconds: `📊 [timestamp] Received real-time data`
3. ✓ Webhook logs every 5 seconds: `📤 Sending data to webhook...`
4. ✓ Success logs every 5 seconds: `✅ Webhook SUCCESS! Status Code: 200`
5. ✓ Webhook Status Card shows increasing success count
6. ✓ "Last sent: X seconds ago" updates regularly

---

## 🆘 **If Webhooks Still Don't Send**

If you still don't see automatic webhooks after connecting:

1. **Check device is actually connected**: Status should say "Connected to HC20-XXXX"
2. **Check console for timer logs**: Should see `⏰ [Timer] Requesting fresh data...` every 5 seconds
3. **Check device is streaming**: HC20 might need to be worn on wrist (wear detection)
4. **Check network connection**: Phone needs WiFi or mobile data
5. **Check backend endpoint**: Ask backend team if endpoint is receiving requests

---

## 📞 **Backend Integration**

Your backend should expect POST requests to:
**https://api.hireforcare.com/webhook/hc20-data**

**Frequency**: Every 5 seconds while device is connected

**Headers**:
```
Content-Type: application/json
```

**Expected Response**:
```json
{
  "status": "ok"
}
```

HTTP Status: 200 OK

---

## 🎉 **Summary**

✅ **Webhook sends automatically every 5 seconds**  
✅ **No manual button clicks needed**  
✅ **Works on both Main page and All Data page**  
✅ **Starts immediately when device connects**  
✅ **Stops automatically when device disconnects**  
✅ **Fully configurable interval**

**Version: 1.4.0**  
**Download: http://[YOUR-CODESPACE-URL]:9000/download.html**
