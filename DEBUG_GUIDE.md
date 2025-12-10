# 🐛 DEBUG GUIDE - HC20 App Webhook Issues

## Version: 1.3.2 - Debug Enhanced

---

## 🔍 What to Check When App Runs

### 1. **Webhook Streaming Status**

The app should automatically send data every 1-5 seconds when device is connected. Look for these console logs:

```
🚀 ========================================
🚀 Starting real-time data stream for device: HC20-XXXX
🚀 Device ID: XX:XX:XX:XX:XX:XX
🚀 Webhook URL: https://api.hireforcare.com/webhook/hc20-data
🚀 ========================================
```

### 2. **Data Reception Logs**

Every 1-5 seconds you should see:

```
📊 [2025-12-04T10:00:00.000Z] Received real-time data:
   Heart: 75, SpO2: 98, BP: [120, 80]
   Temp: [3650], Battery: 85%
   Steps: 1234
📤 Sending data to webhook at https://api.hireforcare.com/webhook/hc20-data...
```

### 3. **Webhook Success Logs**

If data sends successfully:

```
✅ ========================================
✅ Webhook SUCCESS!
✅ Status Code: 200
✅ Success Count: 1
✅ Response: {"status":"ok"}
✅ ========================================
```

### 4. **Webhook Failure Logs**

If webhook fails, you'll see detailed error:

```
❌ ========================================
❌ Webhook DioException!
❌ Error Type: DioExceptionType.connectionTimeout
❌ Error Count: 1
❌ Detail: Timeout: Backend took >5s to respond
❌ Full error: [DioException details]
❌ ========================================
```

---

## 🚨 Common Issues & Solutions

### Issue 1: "NOT DOING - Webhook not sending automatically"

**Symptoms:**
- No webhook logs appearing
- Success count stays at 0
- No console output for data reception

**Possible Causes:**
1. **Device Not Connected** - Make sure you see "Connected to HC20-XXXX" status
2. **Device Not Streaming** - HC20 must be worn and active to send real-time data
3. **Subscription Not Created** - Check for "\u2713 Real-time stream subscription created" log

**Solutions:**
- Disconnect and reconnect to the device
- Make sure device is on your wrist (wear detection)
- Check Android logcat for errors: `adb logcat | grep Flutter`

### Issue 2: "Historical Data Popup White Screen"

**Status:** FIXED in v1.3.2

**What was wrong:** 
- Dialog content not sized properly
- SingleChildScrollView missing width constraint

**What was fixed:**
- Added `SizedBox(width: double.maxFinite)` wrapper
- Changed to `ListBody` for better rendering
- Added proper null checks for string lengths

**Test it:**
1. Connect to device
2. Click "Get History Data"
3. Should see dialog with:
   - Summary Records count + preview
   - Heart Rate Records count + preview  
   - HRV Records count + preview

---

## 📊 Webhook Status Card (On Main Screen)

You should see a card showing:

```
Webhook Status
✓ Sent (200) or ✗ Failed

Success: 15 | Errors: 2
Last sent: 2 seconds ago
URL: https://api.hireforcare.com/webhook/hc20-data

[Error details if any]
```

---

## 🧪 Manual Testing Steps

### Test 1: Check Stream Subscription
1. Open app
2. Scan for devices
3. Connect to HC20
4. Look for console log: "🚀 Starting real-time data stream"
5. Look for: "\u2713 Real-time stream subscription created"
6. Look for: "\u2713 Subscription will send data to webhook automatically"

### Test 2: Verify Data Reception
1. Wait 5 seconds after connection
2. Should see "📊 [timestamp] Received real-time data:" logs
3. If NO logs appear → Device is not streaming (check if worn on wrist)

### Test 3: Verify Webhook Sending
1. Every time you see "📊 Received real-time data"
2. Next line should be "📤 Sending data to webhook..."
3. Then either "✅ Webhook SUCCESS!" or "❌ Webhook DioException!"

### Test 4: Test Button
1. Click "Test Webhook" button
2. Should send test payload immediately
3. Check success/error counter updates

---

## 🔧 Advanced Debugging

### Enable Android Logcat (USB Debugging Required)

```bash
# Connect phone via USB with USB debugging enabled
adb logcat | grep -E "Flutter|HC20|Webhook"
```

### Check Network Connection

1. Make sure phone has WiFi or mobile data
2. Try opening https://api.hireforcare.com in phone browser
3. Check if backend endpoint is accepting connections

### Verify Backend is Receiving

Ask your backend team to check:
- Is the endpoint `/webhook/hc20-data` active?
- Are POST requests being logged?
- What response is being sent back?
- Expected payload format matches?

---

## 📝 Expected Webhook Payload

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

## ✅ Success Checklist

- [ ] Console shows "🚀 Starting real-time data stream"
- [ ] Console shows "\u2713 Real-time stream subscription created"
- [ ] Console shows "📊 Received real-time data" every 1-5 seconds
- [ ] Console shows "📤 Sending data to webhook" after each data reception
- [ ] Console shows "✅ Webhook SUCCESS!" with status code 200
- [ ] Webhook Status Card shows increasing success count
- [ ] Backend team confirms receiving POST requests
- [ ] Historical Data button shows proper dialog (not white screen)

---

## 🆘 Still Not Working?

If webhooks still not sending automatically after checking all above:

1. **Uninstall old app version** - Old version might be cached
2. **Install v1.3.2 APK fresh**
3. **Check device is actually streaming** - Some HC20 devices need to be activated/worn
4. **Verify backend endpoint** - Try curl test:
   ```bash
   curl -X POST https://api.hireforcare.com/webhook/hc20-data \
     -H "Content-Type: application/json" \
     -d '{"test": true}'
   ```

---

## 📞 Contact Info

If issues persist, provide:
1. Full console logs from app launch to connection
2. Screenshot of Webhook Status Card
3. Backend server logs (if accessible)
4. Device model and Android version
