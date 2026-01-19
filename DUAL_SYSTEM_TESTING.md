# 🧪 Dual Background System Testing Configuration

## Overview
Both background systems are now running **simultaneously** at **different intervals** for testing purposes. Each system has clear identifiers in webhooks to track which one is working.

---

## 📊 System Configuration

### 🔵 System 1: Native Service (Kotlin)
- **File:** `android/app/src/main/kotlin/com/example/hfc_app/ForegroundService.kt`
- **Interval:** ⏱️ **2 minutes** (120 seconds)
- **Webhook Identifier:** `"source": "NATIVE_SERVICE"`
- **Method:** `"method": "android_foreground_service"`
- **How it works:**
  - Runs as Android Foreground Service
  - Receives data from Flutter while app is open
  - Sends webhooks with that data every 2 minutes
  - **Limitation:** Cannot connect to HC20 device by itself (needs Flutter)

### 🟢 System 2: Background Isolate (Dart)
- **File:** `lib/services/background_isolate_service.dart`
- **Interval:** ⏱️ **3 minutes** (180 seconds)
- **Webhook Identifier:** `"source": "BACKGROUND_ISOLATE"`
- **Method:** `"method": "flutter_background_service"`
- **How it works:**
  - Runs Flutter code in separate isolate
  - Can use HC20 SDK directly
  - Scans for and connects to device independently
  - Sends webhooks with live data every 3 minutes

---

## 🔍 Webhook Identification

### Native Service Webhook Format:
```json
{
  "phone": "user_phone_number",
  "deviceId": "device_mac_address",
  "source": "NATIVE_SERVICE",
  "method": "android_foreground_service",
  "interval": "2_minutes",
  "dataAgeSeconds": 15,
  "isDataFresh": true,
  "heartRate": 72,
  "spo2": 98,
  "timestamp": 1234567890
}
```

### Background Isolate Webhook Format:
```json
{
  "device_id": "device_mac_address",
  "device_name": "HC20-ABCD",
  "user_phone": "user_phone_number",
  "source": "BACKGROUND_ISOLATE",
  "method": "flutter_background_service",
  "interval": "3_minutes",
  "data": {
    "heart_rate": 72,
    "spo2": 98,
    "blood_pressure": "120/80",
    "timestamp": "2026-01-16T10:30:00.000Z"
  },
  "data_freshness": {
    "age_seconds": 5,
    "is_fresh": true,
    "last_update": "2026-01-16T10:30:00.000Z"
  },
  "sent_at": "2026-01-16T10:30:05.000Z"
}
```

---

## 📝 Log Prefixes

To easily identify which system is logging:

- **Native Service:** `[NATIVE-SERVICE]` 
- **Background Isolate:** `[Background-Isolate]`
- **Flutter Main:** `[Flutter]` or no prefix

Example logs:
```
[NATIVE-SERVICE] Webhook sent (2-min): 200 - Fresh Data - HR:72 SpO2:98
[Background-Isolate] ✅ Received data: HR=72, SPO2=98, BP=120/80
[Background-Isolate] 📤 Sending webhook (3-min interval)
```

---

## 🧪 Testing Scenarios

### Scenario 1: App Open (Foreground)
**Expected Behavior:**
- ✅ Native Service: Receives data from Flutter → sends every 2 minutes
- ✅ Background Isolate: Connected to device → sends every 3 minutes
- **Result:** Webhooks every 2 minutes (native) + every 3 minutes (isolate)

### Scenario 2: App Minimized (Background)
**Expected Behavior:**
- ⚠️ Native Service: May continue receiving Flutter data → sends every 2 minutes
- ✅ Background Isolate: Still connected → sends every 3 minutes
- **Result:** Depends on Android memory management

### Scenario 3: App Closed (Swiped Away)
**Expected Behavior:**
- ❌ Native Service: No more Flutter data → sends webhooks with stale/null data
- ✅ Background Isolate: Continues independently → sends live data every 3 minutes
- **Result:** Only background isolate sends live data

---

## 📈 Success Metrics

### Native Service is Working If:
1. Webhooks arrive every **2 minutes** while app is open
2. Webhook contains `"source": "NATIVE_SERVICE"`
3. Webhook has `isDataFresh: true` while app is open
4. Webhook has `isDataFresh: false` after app closes

### Background Isolate is Working If:
1. Webhooks arrive every **3 minutes** (even when app closed)
2. Webhook contains `"source": "BACKGROUND_ISOLATE"`
3. Webhook has fresh data (`data_freshness.is_fresh: true`)
4. Data continues flowing after app is swiped away

---

## 🎯 Expected Timeline (Testing)

```
Time    | Native (2-min) | Isolate (3-min) | Notes
--------|----------------|-----------------|---------------------------
00:00   | ✅ Webhook     | -               | App opened, device connected
00:02   | ✅ Webhook     | -               | Native sends
00:03   | -              | ✅ Webhook      | Isolate sends
00:04   | ✅ Webhook     | -               | Native sends
00:06   | ✅ Webhook     | ✅ Webhook      | Both send!
00:08   | ✅ Webhook     | -               | Native sends
00:09   | -              | ✅ Webhook      | Isolate sends
00:10   | ✅ Webhook     | -               | APP CLOSED HERE
00:12   | ⚠️ Stale       | ✅ Live Data    | Isolate still works!
00:14   | ⚠️ Stale       | -               | Native has no data
00:15   | -              | ✅ Live Data    | Isolate continues
```

---

## 🔧 Key Fixes Applied

### Background Isolate Service:
1. ✅ Fixed HC20 initialization (uses `Hc20Client.create()`)
2. ✅ Added device scanning to get `Hc20Device` object
3. ✅ Added `user_phone` field to webhooks
4. ✅ Changed interval to 3 minutes
5. ✅ Added clear source identifier: `BACKGROUND_ISOLATE`
6. ✅ Added data freshness tracking
7. ✅ All logs prefixed with `[Background-Isolate]`

### Native Service:
1. ✅ Changed log prefix to `[NATIVE-SERVICE]`
2. ✅ Added clear source identifier: `NATIVE_SERVICE`
3. ✅ Added `method` and `interval` fields
4. ✅ Updated notification to show `[NATIVE 2-min]`
5. ✅ Kept 2-minute interval (unchanged)

---

## 🚨 Important Notes

### Production Recommendation:
**Choose ONE system for production:**
- If HC20 needs to work when app is closed: Use **Background Isolate only** (disable native)
- If app will stay open: Use **Native Service only** (simpler, more efficient)

**Running both is only for testing!** It wastes battery and bandwidth.

### Why Two Systems?
This dual configuration allows you to:
1. **Compare performance** - which one actually works?
2. **Test reliability** - which survives app closure?
3. **Verify data quality** - which provides fresh data?
4. **Identify issues** - webhook source tells you which failed

---

## 📞 Backend Integration

Your webhook receiver should check the `source` field:

```javascript
// Example webhook handler
if (payload.source === 'NATIVE_SERVICE') {
  console.log('From Android Native Service (2-min)');
  console.log('Data freshness:', payload.isDataFresh);
  
} else if (payload.source === 'BACKGROUND_ISOLATE') {
  console.log('From Flutter Background Isolate (3-min)');
  console.log('Data freshness:', payload.data_freshness.is_fresh);
}
```

---

## ✅ Build Ready

The code is now ready to build. After testing:

1. **Monitor logs** for both prefixes
2. **Check webhook receiver** for source identifiers
3. **Test with app closed** to verify background isolate works
4. **Choose winning system** and disable the other

Good luck with testing! 🚀
