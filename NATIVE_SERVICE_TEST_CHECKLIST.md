# Native Kotlin Service - Final Test Checklist

## Test Objective
**Verify that NativeHC20Service can receive HRV2 data from HC20 device when app is CLOSED (swiped away)**

## Pre-Test Setup
1. ✅ Install APK v8.0.57+ on Android device
2. ✅ Enable all permissions (Location, Bluetooth, Battery Optimization Exemption)
3. ✅ Connect to HC20 device in app
4. ✅ Wait for connection success message
5. ✅ Verify "Native HC20 Service Started" message appears

## Test Steps

### Phase 1: Verify Service Start (App Open)
**Expected Logs in Logcat:**
```
🚀 STEP 1: NativeHC20Service CREATED
🚀 STEP 2: Request battery optimization exemption...
🚀 STEP 3: Create notification channel...
🚀 STEP 4: Start foreground service...
🚀 STEP 5: Acquire wake lock...
🚀 STEP 6: Initialize BLE manager...
🚀 STEP 7: START ACTION RECEIVED
🚀 STEP 8: Acquire BLE device lock...
🚀 STEP 9: Start connection sequence...
🚀 STEP 10: Start periodic webhook (every 3 minutes)...
🚀 STEP 11: Start heartbeat check (every 1 minute)...
🔌 STEP 12: Connecting to HC20
```

**Verification:**
- [ ] All 12 steps complete without errors
- [ ] Service notification visible in status bar: "⏳ Testing HRV2 data..."
- [ ] Battery optimization exemption granted

### Phase 2: Verify BLE Connection (App Open)
**Expected Logs:**
```
✅ STEP 13: CONNECTED TO HC20 DEVICE
✅ Services discovered!
✅ Found HC20 service (FFF0)
✅ Notifications enabled for FFF1
```

**Expected Actions:**
```
📤 [Step 1] Setting device time...
📤 [Step 2] Starting aggressive HRV2 enable loop...
📤 [HRV2 Enable #1]
📤 HRV2-ONLY command: [hex bytes]
```

**Verification:**
- [ ] BLE connection established
- [ ] Services discovered successfully
- [ ] Notifications enabled
- [ ] Set time command sent
- [ ] HRV2 enable commands sending every 3 seconds

### Phase 3: Verify Data Reception (App Open)
**Expected Logs:**
```
📥 Received X bytes: [hex data]
🔢 Frame: func=0x85 len=X
📥 Data packet: HR=XX Batt=XX% (HRV2: waiting...)
```

**Then eventually:**
```
✅✅✅ HRV2 DATA RECEIVED! ✅✅✅
✅ HRV2 raw: [X, X, X, X]
✅ HRV2 metrics: HrvMetrics2(mentalStress=X, fatigueLevel=X, ...)
✅ HR=XX Batt=XX%
✅ TEST SUCCESSFUL - Device CAN send data when app closed!
```

**Verification:**
- [ ] Initial data packets received (HR, battery)
- [ ] HRV2 enable commands continue sending
- [ ] Eventually HRV2 data appears
- [ ] Notification updates to: "✅ HRV2: ✅ Stress=XX Fatigue=XX 💓XX BPM 🔋XX%"

### Phase 4: Verify App Swipe (CRITICAL TEST)
**Action:** Swipe away app from recent apps

**Expected Logs:**
```
⚠️⚠️⚠️ APP SWIPED AWAY - SERVICE CONTINUES! ⚠️⚠️⚠️
✅ NativeHC20Service is INDEPENDENT of Flutter
✅ Service will continue running in background
✅ BLE connection will remain active
✅ Webhooks will continue every 3 minutes
📤 Sending confirmation webhook...
🔄 Enabling continuous reconnect scanning...
📅 Scheduling auto-restart as safety net...
```

**Verification:**
- [ ] Service does NOT stop
- [ ] Notification stays in status bar
- [ ] BLE connection stays active
- [ ] Data continues flowing
- [ ] "app_swiped_away" webhook sent

### Phase 5: Verify Data After Swipe (App Closed)
**Wait 1 minute after swiping**

**Expected Logs (should continue):**
```
📥 Received X bytes: [data]
💓 Heartbeat: connected=true, timeSinceLastData=XX s
📤 [HRV2 Enable #XX]
```

**Expected:**
- [ ] Data packets still arriving
- [ ] Heartbeat checks running
- [ ] HRV2 enable commands still sending
- [ ] HRV2 data still present
- [ ] Notification still shows live data

### Phase 6: Verify Webhook After Swipe
**Wait 3 minutes for periodic webhook**

**Expected Webhook JSON:**
```json
{
  "phone": "9828096110",
  "status": "Connected",
  "dataType": "live",
  "device": {
    "id": "50:C0:F0:42:48:07",
    "name": "B20_50C0F0424807"
  },
  "realtime_data": {
    "heart_rate": XX,
    "battery_percent": XX,
    "hrv2_raw": [XX, XX, XX, XX],
    "hrv2_metrics": {
      "mental_stress": XX,
      "fatigue_level": XX,
      "stress_resistance": XX,
      "regulation_ability": XX
    }
  },
  "_meta": {
    "source": "NATIVE_KOTLIN_SERVICE",
    "trigger": "periodic"
  }
}
```

**Verification:**
- [ ] Webhook received at backend
- [ ] `status` = "Connected"
- [ ] `dataType` = "live"
- [ ] `heart_rate` has value
- [ ] `hrv2_metrics` has ALL 4 values (NOT null)
- [ ] `source` = "NATIVE_KOTLIN_SERVICE"
- [ ] `trigger` = "periodic"

## Success Criteria

### ✅ Test PASSES if:
1. Service starts successfully (all 13 steps)
2. BLE connects and discovers services
3. HRV2 data received while app is OPEN
4. Service survives app swipe
5. Data continues flowing after swipe
6. Webhook contains HRV2 data after swipe
7. Notification stays visible with live data

### ❌ Test FAILS if:
1. Service stops when app is swiped
2. BLE disconnects when app is swiped
3. No data received after swipe
4. Webhook shows null hrv2_metrics after swipe
5. Notification disappears after swipe
6. Service crashes or restarts unexpectedly

## Logcat Filter Commands

**View all Native service logs:**
```bash
adb logcat -s NativeHC20Service HC20NativeBLE HC20Protocol
```

**View step-by-step flow:**
```bash
adb logcat | grep "STEP"
```

**View HRV2 data reception:**
```bash
adb logcat | grep "HRV2"
```

**View app swipe event:**
```bash
adb logcat | grep "SWIPED"
```

## Troubleshooting

### If no data after swipe:
1. Check if service is still running: `adb logcat -s NativeHC20Service`
2. Check if BLE connected: look for "connected=true" in heartbeat logs
3. Check if notifications stopped: reconnect will fix this
4. Check logcat for errors or crashes

### If HRV2 still null:
1. Verify HRV2 enable commands sending: `adb logcat | grep "HRV2 Enable"`
2. Check device firmware supports HRV2
3. Wait longer (may take 30-60 seconds for first HRV2 data)
4. Check if receiving ANY data frames

### If service stops after swipe:
1. Check battery optimization: must be EXEMPTED
2. Check notification channel: must be IMPORTANCE_HIGH
3. Check wake lock: must be acquired
4. Check Android version (Android 12+ may have additional restrictions)

## Expected Outcome

**PASS:** 
- Service survives app swipe ✅
- HRV2 data flows continuously ✅
- Webhooks sent every 3 minutes with complete data ✅
- Notification shows live HRV2 metrics ✅

**This proves Native Kotlin approach WORKS for background data streaming!**
