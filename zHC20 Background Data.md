# HC20 SDK Background Operation - Technical Analysis Report

## Executive Summary

We have extensively tested multiple approaches to keep the HC20 SDK running and streaming live health data when the mobile app is closed (swiped away from recent apps). This document details each approach, the implementation, and why it failed.

**Key Finding:** The HC20 SDK is a Flutter/Dart package that requires the Flutter engine to run. When the user swipes away the app, Android **kills the Flutter engine**, making it impossible to maintain the HC20 BLE connection without relaunching the app.

---

## Approach #1: ForegroundService Only

### Implementation
- Created an Android ForegroundService that runs when app is closed
- Service shows a persistent notification
- Service is marked with `stopWithTask="false"` to survive app swipe

### Result: ❌ FAILED

### Why It Failed
- The ForegroundService keeps the **native Android process** alive
- However, the **Flutter engine attached to MainActivity is killed** when app is swiped
- The HC20 SDK is Dart code that runs in the Flutter engine
- No Flutter engine = No HC20 SDK = No BLE connection

---

## Approach #2: HeadlessFlutter Engine

### Implementation
- When app is swiped away, start a **separate headless Flutter engine**
- This engine runs a `@pragma('vm:entry-point') void backgroundMain()` function
- The background function initializes HC20 SDK, scans for device, connects, and streams data

### Result: ❌ FAILED

### Why It Failed
1. **BLE Scanning Fails in Background**: Android restricts BLE scanning for background processes. Even with all permissions granted, the scan returns no results
2. **BLE Connection Fails**: Even when we skip scanning and try to connect directly with the device ID, the connection fails silently
3. **Plugin Registration Issues**: Some Flutter plugins don't work correctly in headless mode
4. **State Not Preserved**: The HeadlessFlutter engine is a NEW engine - it doesn't have access to the connected device state from the main engine

### Evidence from Logs
```json
{
  "source": "NATIVE_SERVICE",
  "headlessFlutterRunning": true,
  "message": "HeadlessFlutter running but no data yet - HC20 SDK may be connecting",
  "dataSource": "no_data_yet"
}
```

---

## Approach #3: Keep Main Flutter Engine Running (Not Headless)

### Implementation
- When app goes to background (paused state), start ForegroundService to "protect" the process
- Theory: If ForegroundService keeps process alive, maybe Flutter engine survives

### Result: ❌ FAILED

### Why It Failed
- The Flutter engine is tied to the **MainActivity lifecycle**
- When user swipes away the app, Android calls `onDestroy()` on MainActivity
- This destroys the Flutter engine regardless of ForegroundService
- ForegroundService cannot prevent MainActivity destruction

---

## Approach #4: Android Companion Device Manager API

### Implementation
- Use Android's CompanionDeviceManager to get **privileged BLE access**
- Associate the HC20 device as a "companion device"
- Theory: Companion devices get better background BLE access

### Result: ❌ FAILED

### Why It Failed
- On Redmi Note 9 (Android 12), the system device picker dialog **never appeared**
- The `CompanionDeviceManager.associate()` callback was called, but `startIntentSenderForResult()` did nothing
- This appears to be a manufacturer-specific issue (MIUI customizations)
- Even if association worked, it wouldn't solve the Flutter engine death problem

---

## Approach #5: WorkManager for Periodic Tasks

### Implementation
- Use Android WorkManager to schedule periodic background tasks
- Every 15 minutes, WorkManager triggers a task that tries to send cached health data

### Result: ⚠️ PARTIAL (Can only send stale data)

### Why It Failed for Live Data
- WorkManager runs in a **separate process** from the app
- It cannot access the HC20 SDK or BLE connection
- Can only send **cached data** that was saved before app was closed
- Data becomes stale (shows `dataAgeSeconds: 240, 360, etc.`)

---

## Approach #6: Native Android BLE (Without Flutter)

### Implementation
- Write native Kotlin code to handle BLE connection directly
- Bypass the HC20 SDK entirely
- Connect to device using BluetoothGatt API

### Result: ❌ NOT FEASIBLE

### Why It's Not Feasible
- The HC20 device uses a **proprietary protocol** for health data
- The data format is complex (heart rate, SpO2, temperature, HRV, blood pressure, etc.)
- Without the HC20 SDK documentation/source code, we cannot decode the BLE data
- The SDK handles authentication, data parsing, and device communication
- Reimplementing this natively would require extensive reverse engineering

---

## Approach #7: AlarmManager + Full-Screen Intent (WORKING!)

### Implementation
- Schedule periodic alarms using AlarmManager
- When alarm fires and **screen is OFF**, use a Full-Screen Intent to launch the app
- App launches even over lock screen
- Flutter engine starts fresh, HC20 SDK reconnects

### Result: ✅ WORKING (with limitations)

### Why It Works
- Full-Screen Intents are allowed when screen is OFF (for incoming calls, alarms)
- This launches the **real MainActivity with full Flutter engine**
- HC20 SDK can scan, connect, and stream data normally

### Limitations
- Only works when **screen is OFF**
- When screen is ON, Android blocks full-screen intents (user would see a notification instead)
- There's a **delay** between app closure and relaunch (typically 5 minutes)
- Each relaunch consumes battery

---

## Approach #8: Overlay Permission (Display Over Other Apps)

### Implementation
- Request SYSTEM_ALERT_WINDOW permission
- When app is closed and screen is ON, show an overlay that relaunches the app

### Result: ❌ BLOCKED BY ANDROID

### Why It Failed
- Modern Android (10+) heavily restricts overlay usage
- Cannot launch activities from overlays without user interaction
- Xiaomi/MIUI further restricts this

---

## Root Cause Analysis

### The Core Problem

```
┌─────────────────────────────────────────────────────────┐
│                     ANDROID OS                          │
├─────────────────────────────────────────────────────────┤
│  App Process                                            │
│  ├── MainActivity (Flutter Engine lives here)          │
│  │   └── Flutter Engine                                 │
│  │       └── Dart VM                                    │
│  │           └── HC20 SDK (Dart code)                   │
│  │               └── BLE Connection                     │
│  │                                                      │
│  └── ForegroundService (Native Kotlin)                  │
│      └── Can keep process alive                         │
│      └── Cannot keep Flutter Engine alive ❌            │
└─────────────────────────────────────────────────────────┘

When user swipes away:
1. Android destroys MainActivity
2. Flutter Engine dies with MainActivity
3. HC20 SDK stops (it's Dart code in Flutter Engine)
4. BLE connection drops
5. ForegroundService survives but has no HC20 SDK
```

### Why HC20 SDK Cannot Run in Background

1. **HC20 SDK is a Flutter Package**: It's written in Dart and runs in the Flutter engine
2. **Flutter Engine Requires Activity**: The Flutter engine is created by FlutterActivity and destroyed with it
3. **HeadlessFlutter Has Limitations**: BLE scanning and connection don't work reliably
4. **No Native HC20 Implementation**: We don't have native Kotlin/Java HC20 SDK

---

## Recommendations for HC20 SDK Provider

To enable true background operation, the HC20 SDK provider could:

### Option A: Provide Native Android SDK
- Create a native Kotlin/Java version of the HC20 SDK
- This could run in a Service independent of Flutter
- Would enable true background BLE operation

### Option B: Provide HeadlessFlutter-Compatible Version
- Ensure all BLE operations work in headless Flutter mode
- Provide a way to "resume" a connection without scanning
- Allow connection using only device ID (skip scan phase)

### Option C: Document Direct BLE Protocol
- Provide documentation for the raw BLE protocol
- Include GATT service UUIDs, characteristic UUIDs
- Document the data format for each health metric
- We could then implement native BLE connection ourselves

---

## Current Working Solution

**AlarmManager + Full-Screen Intent** is the only reliable solution:

| Scenario | Data Flow |
|----------|-----------|
| App in foreground | ✅ Live data every 2 minutes |
| App minimized | ✅ Live data continues |
| App swiped away, screen ON | ❌ No data (cannot relaunch) |
| App swiped away, screen OFF | ✅ App relaunches in 5 min, data resumes |
| Phone restarted | ✅ Boot receiver relaunches app |

---

## Conclusion

The HC20 SDK's architecture as a Flutter-only package creates an inherent limitation for background operation on Android. When the user closes the app, the Flutter engine dies, and with it, the HC20 SDK.

The only workaround is to **periodically relaunch the app** using AlarmManager when the screen is off. This is not a perfect solution but provides a balance between background data collection and Android's strict background execution limits.