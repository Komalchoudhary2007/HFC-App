# HC20 Backend - Flutter Integration Guide

**Date:** January 8, 2026  
**Backend API:** `https://api.hireforcare.com`  
**Purpose:** Complete specification of what backend expects from Flutter app

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Webhook Endpoint](#webhook-endpoint)
3. [Normal Health Data Payload](#normal-health-data-payload)
4. [Disconnect Payload (Currently Broken)](#disconnect-payload-currently-broken)
5. [Backend Response Format](#backend-response-format)
6. [Cron Job Backup System](#cron-job-backup-system)
7. [Database Tables](#database-tables)
8. [Current Issues](#current-issues)
9. [Testing & Validation](#testing--validation)

---

## 🎯 Overview

### System Architecture

```
Flutter App (2-min intervals)
    ↓
Webhook: POST /webhook/hc20-data
    ↓
Backend Processing
    ↓
Store in Database (hc20_data table)
    ↓
Cron Job (every 3 min) - Backup detection
    ↓
WhatsApp Notifications (if needed)
```

### Key Components

1. **Flutter App:** Sends health data every 2 minutes via webhook
2. **Backend Webhook:** Receives and processes data
3. **Cron Job:** Backup system to detect complete silence (no webhooks)
4. **Notifications:** WhatsApp alerts for disconnections

---

## 🔌 Webhook Endpoint

### Endpoint Details

```
URL: POST https://api.hireforcare.com/webhook/hc20-data
Content-Type: application/json
Frequency: Every 2 minutes
Timeout: 5 seconds
```

### CRITICAL: Timestamp Format

**❌ WRONG (Current Flutter Issue):**
```dart
'timestamp': DateTime.now().toIso8601String()  
// Sends local timezone: 2026-01-08T19:29:14.671Z (IST - 5.5 hours ahead)
```

**✅ CORRECT (Required):**
```dart
'timestamp': DateTime.now().toUtc().toIso8601String()
// Sends UTC: 2026-01-08T14:00:00.000Z
```

**Why this matters:**
- Backend stores timestamps using **server time (UTC)**
- If Flutter sends IST time, backend thinks data is 5.5 hours in the future
- Causes incorrect disconnect detection
- **Must use `.toUtc()` before `.toIso8601String()`**

---

## 📊 Normal Health Data Payload

### What Backend Expects

```json
{
  "timestamp": "2026-01-08T14:00:00.000Z",  // ✅ MUST BE UTC
  "device": {
    "id": "50:C0:F0:FE:BC:4F",              // MAC address or unique ID
    "name": "HC20 Watch",                    // Device name
    "battery": 85                            // Battery percentage
  },
  "realtime_data": {
    "heart_rate": 75,                        // BPM
    "spo2": 98,                              // Oxygen saturation %
    "blood_pressure": {
      "systolic": 120,                       // mm Hg
      "diastolic": 80                        // mm Hg
    },
    "temperature": [36.5, 25.0],             // [body_temp, env_temp] in Celsius
    "battery": {
      "level": 85,                           // Battery %
      "charging": false                      // Boolean
    },
    "steps": 5420,                           // Step count
    "distance": 3.2,                         // km
    "calories": 245,                         // kcal
    "sleep": {
      "duration": 420,                       // minutes
      "deep": 180,                           // minutes
      "light": 200,                          // minutes
      "rem": 40                              // minutes
    },
    "location": {
      "latitude": 28.6139,                   // GPS coordinates
      "longitude": 77.2090,
      "altitude": 216.0,                     // meters
      "pressure": 1013.25                    // hPa
    },
    "hrv": {
      "rmssd": 45.2,                         // Heart rate variability
      "pnn50": 12.5
    }
  }
}
```

### Minimum Required Fields

```json
{
  "timestamp": "2026-01-08T14:00:00.000Z",  // ✅ REQUIRED (UTC)
  "device": {
    "id": "50:C0:F0:FE:BC:4F"               // ✅ REQUIRED
  },
  "realtime_data": {
    "heart_rate": 75,                        // ✅ REQUIRED
    "spo2": 98                               // ✅ REQUIRED
  }
}
```

### Backend Processing

1. **Receives webhook** at `/webhook/hc20-data`
2. **Validates** `device.id` and `timestamp` are present
3. **Parses timestamp** and creates server timestamp
4. **Extracts all health metrics** from `realtime_data`
5. **Stores in database** with **server timestamp** (not device timestamp)
6. **Returns success response** immediately (within 4.5 seconds)

---

## ⚠️ Disconnect Payload (Currently Broken)

### What Flutter WANTS to Send (Not Implemented Yet)

```json
{
  "phone": "+919876543210",                  // User's phone number
  "deviceId": "50:C0:F0:FE:BC:4F",          // Device MAC address
  "heartRate": null,                         // ❌ ALL health fields NULL
  "spo2": null,                              // ❌
  "bloodPressure": null,                     // ❌
  "temperature": null,                       // ❌
  "batteryLevel": null,                      // ❌
  "steps": null,                             // ❌
  "status": null,                            // ❌
  "message": "Device Disconnect",            // Disconnect reason
  "errorType": "Device Disconnect",          // Type: "Device Disconnect" or "Network Disconnect"
  "timestamp": "2026-01-08T14:00:00.000Z"   // ✅ MUST BE UTC
}
```

### Two Disconnect Types

#### 1. Device Disconnect (Bluetooth Issue)
```json
{
  "errorType": "Device Disconnect",
  "message": "Device Disconnect"
}
```

**When to send:**
- HC20 device out of Bluetooth range (>10 meters)
- Device powered off
- Device battery dead
- Bluetooth disabled on phone

#### 2. Network Disconnect (Internet Issue)
```json
{
  "errorType": "Network Disconnect",
  "message": "Network Disconnect"
}
```

**When to send:**
- WiFi turned off (but app can still run)
- Mobile data disabled (but app can still run)
- Weak signal (can send webhook but can't reach backend health check)
- Backend API unreachable

### How Backend Handles Disconnects

**Current Status:** ❌ **NOT IMPLEMENTED IN FLUTTER YET**

Backend expects:
1. All health fields as `null`
2. `errorType` field present
3. Phone number for user lookup
4. UTC timestamp

Backend will:
1. Detect disconnect by checking `heartRate === null && spo2 === null`
2. Look up user by phone number
3. Check 30-minute cooldown
4. Send appropriate WhatsApp notification
5. Log to `device_notifications` table

---

## ✅ Backend Response Format

### Success Response (Normal Data)

```json
{
  "success": true,
  "message": "HC20 data received and processing",
  "deviceId": "50:C0:F0:FE:BC:4F",
  "userId": "8aeac9b8-9b0a-4008-ba82-8c525b1629dc",
  "timestamp": "2026-01-08T14:00:00.000Z",
  "isNewData": true,
  "stressAlert": false,
  "userLinked": true
}
```

### Success Response (Disconnect - When Implemented)

```json
{
  "success": true,
  "message": "Disconnect recorded",
  "errorType": "Device Disconnect",
  "notificationSent": true
}
```

### Error Response

```json
{
  "success": false,
  "error": "Missing required fields: device.id and timestamp are required"
}
```

### HTTP Status Codes

- `200` - Success (data received)
- `400` - Bad request (missing required fields)
- `500` - Server error

**IMPORTANT:** Backend ALWAYS returns `200` for disconnect payloads (even if notification fails)

---

## 🤖 Cron Job Backup System

### Purpose

Detect complete silence when phone has **NO internet at all** (cannot send webhooks).

### How It Works

```
Every 3 minutes:
  1. Query database for devices with no data in last 3 minutes
  2. For each silent device:
     - Check if notification sent in last 5 minutes (cooldown)
     - If cooldown expired:
       → Send WhatsApp notification
       → Log to device_notifications
     - If cooldown active:
       → Skip (prevent spam)
```

### Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| Cron interval | 3 minutes | How often to check |
| Silence threshold | 3 minutes | How long before considered disconnected |
| Cooldown period | 5 minutes | Time between notifications |
| Notification type | "Complete Silence" | Differentiates from Flutter disconnect |

### SQL Query (What Cron Does)

```sql
SELECT DISTINCT
  hc."device_id" as "deviceId",
  hc."user_id" as "userId",
  u.phone,
  u.name,
  MAX(hc."timestamp") as last_seen
FROM "hc20_data" hc
JOIN "User" u ON u.id = hc."user_id"
WHERE hc."timestamp" < (NOW() - INTERVAL '3 minutes')
  AND hc."user_id" IS NOT NULL
  AND u.phone IS NOT NULL
GROUP BY hc."device_id", hc."user_id", u.phone, u.name
HAVING MAX(hc."timestamp") < (NOW() - INTERVAL '3 minutes')
```

**Translation:** Find all devices that haven't sent ANY data in the last 3 minutes.

### When Cron Triggers

**Scenario 1:** Phone has NO internet (WiFi + Data OFF)
```
10:00 AM - Last webhook received ✅
10:03 AM - No webhook (no internet) ❌
10:03 AM - Cron runs, finds 3-min silence ⚠️
10:03 AM - Checks cooldown → None → Sends notification 📱
10:06 AM - Cron runs, cooldown active → Skip
10:09 AM - Cron runs, cooldown still active → Skip
```

**Scenario 2:** Phone has internet (Flutter handles it)
```
10:00 AM - Last webhook with normal data ✅
10:02 AM - Webhook with "Device Disconnect" payload ⚠️
10:02 AM - Backend sends notification immediately 📱
10:03 AM - Cron runs, finds device silent but notification already sent → Skip
```

---

## 💾 Database Tables

### hc20_data Table

Stores all health data from HC20 devices.

```sql
CREATE TABLE "hc20_data" (
  "id" TEXT PRIMARY KEY,
  "device_id" TEXT NOT NULL,            -- Device MAC address
  "device_name" TEXT,                   -- Device name
  "user_id" TEXT,                       -- User who owns device
  "timestamp" TIMESTAMP NOT NULL,       -- Server timestamp (UTC)
  
  -- Health metrics (NULL if disconnected)
  "heart_rate" INTEGER,
  "spo2" INTEGER,
  "systolic" INTEGER,
  "diastolic" INTEGER,
  "temperature" DOUBLE PRECISION,
  "battery_level" INTEGER,
  "steps" INTEGER,
  "distance" DOUBLE PRECISION,
  "calories" INTEGER,
  
  -- Additional metrics
  "latitude" DOUBLE PRECISION,
  "longitude" DOUBLE PRECISION,
  "altitude" DOUBLE PRECISION,
  "pressure" DOUBLE PRECISION,
  "rmssd" DOUBLE PRECISION,
  "pnn50" DOUBLE PRECISION,
  
  -- Metadata
  "raw_data" JSONB,                     -- Complete Flutter payload
  "created_at" TIMESTAMP DEFAULT NOW(),
  
  FOREIGN KEY ("user_id") REFERENCES "User"("id")
);

-- Indexes for performance
CREATE INDEX idx_hc20_device ON "hc20_data"("device_id");
CREATE INDEX idx_hc20_user ON "hc20_data"("user_id");
CREATE INDEX idx_hc20_timestamp ON "hc20_data"("timestamp");
```

### device_notifications Table

Stores all WhatsApp notification attempts.

```sql
CREATE TABLE "device_notifications" (
  "id" TEXT PRIMARY KEY,
  "user_id" TEXT NOT NULL,
  "device_id" TEXT NOT NULL,
  "phone" TEXT NOT NULL,
  "type" TEXT NOT NULL,                 -- "Device Disconnect", "Network Disconnect", "Complete Silence"
  "status" TEXT NOT NULL,               -- "SENT", "FAILED"
  "wamid" TEXT,                         -- WhatsApp message ID
  "error" TEXT,                         -- Error message if failed
  "sent_at" TIMESTAMP NOT NULL,
  "created_at" TIMESTAMP DEFAULT NOW(),
  
  FOREIGN KEY ("user_id") REFERENCES "User"("id")
);

-- Indexes
CREATE INDEX idx_notification_device ON "device_notifications"("device_id", "phone");
CREATE INDEX idx_notification_sent ON "device_notifications"("sent_at");
```

### Example Data (Normal)

```sql
-- hc20_data record (connected)
{
  "id": "cm5abc123",
  "device_id": "50:C0:F0:FE:BC:4F",
  "user_id": "8aeac9b8-9b0a",
  "timestamp": "2026-01-08 14:00:00 UTC",
  "heart_rate": 75,
  "spo2": 98,
  "systolic": 120,
  "diastolic": 80,
  "temperature": 36.5,
  "raw_data": { /* full Flutter payload */ }
}
```

### Example Data (Disconnected - When Implemented)

```sql
-- hc20_data record (disconnected)
{
  "id": "cm5xyz789",
  "device_id": "50:C0:F0:FE:BC:4F",
  "user_id": "8aeac9b8-9b0a",
  "timestamp": "2026-01-08 14:05:00 UTC",
  "heart_rate": null,
  "spo2": null,
  "systolic": null,
  "temperature": null,
  "raw_data": {
    "errorType": "Device Disconnect",
    "message": "Device Disconnect"
  }
}

-- device_notifications record
{
  "id": "cm5notif123",
  "user_id": "8aeac9b8-9b0a",
  "device_id": "50:C0:F0:FE:BC:4F",
  "phone": "+919876543210",
  "type": "Device Disconnect",
  "status": "SENT",
  "wamid": "wamid.HBgLOTE4MTIz...",
  "sent_at": "2026-01-08 14:05:10 UTC"
}
```

---

## 🐛 Current Issues

### Issue 1: Future Timestamps

**Problem:**
```
Flutter sends: 2026-01-08T19:29:14.671Z (7:29 PM IST)
Current time:  2026-01-08T14:00:00.000Z (2:00 PM UTC)
Difference: 5.5 hours in the future!
```

**Root Cause:**
- Flutter using `DateTime.now().toIso8601String()` sends local time
- Should use `DateTime.now().toUtc().toIso8601String()`

**Impact:**
- Backend thinks device is sending data from the future
- Cron job treats device as disconnected even when sending data
- Incorrect disconnect detection

**Fix Required in Flutter:**
```dart
// ❌ CURRENT (BROKEN)
'timestamp': DateTime.now().toIso8601String(),

// ✅ CORRECT
'timestamp': DateTime.now().toUtc().toIso8601String(),
```

---

### Issue 2: Disconnect Payloads Not Implemented

**Problem:**
- Flutter does NOT send disconnect payloads yet
- Only sends normal health data
- Backend has disconnect handling code but never receives disconnect events

**What's Missing in Flutter:**
1. Detection when HC20 disconnects (Bluetooth lost)
2. Detection when network lost (but app still running)
3. Sending payload with all health fields as `null`
4. Including `errorType` field

**Impact:**
- Backend relies ONLY on cron job (3-min delay)
- No instant disconnect notifications
- Cannot differentiate between network vs device issues

**Fix Required in Flutter:**
```dart
// When device disconnects
if (!_isConnected || _connectedDevice == null) {
  final hasNetworkIssue = await _checkNetworkConnectivity();
  
  if (hasNetworkIssue) {
    await _sendDisconnectWebhook(
      phone: userPhone,
      reason: 'Network Disconnect'
    );
  } else {
    await _sendDisconnectWebhook(
      phone: userPhone,
      reason: 'Device Disconnect'
    );
  }
}
```

---

### Issue 3: Notification Spam (Now Fixed)

**Problem (Was):**
- Cron sent notification every minute if device disconnected
- No proper cooldown enforcement
- Users received too many notifications

**Fix (Completed):**
- Changed cooldown from 4 hours to 5 minutes
- Fixed cooldown logic to check "last 5 minutes from NOW" (not 4 hours after disconnect)
- Cron runs every 3 minutes, cooldown is 5 minutes
- Maximum one notification per 5-minute period

**Current Status:** ✅ Fixed in backend

---

## 🧪 Testing & Validation

### Test 1: Normal Data Webhook

**Test Payload:**
```bash
curl -X POST https://api.hireforcare.com/webhook/hc20-data \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2026-01-08T14:00:00.000Z",
    "device": {
      "id": "TEST_DEVICE_001"
    },
    "realtime_data": {
      "heart_rate": 75,
      "spo2": 98
    }
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "HC20 data received and processing",
  "deviceId": "TEST_DEVICE_001",
  "timestamp": "2026-01-08T14:00:00.000Z"
}
```

**Verify:**
1. Check database: `SELECT * FROM hc20_data WHERE device_id = 'TEST_DEVICE_001' ORDER BY timestamp DESC LIMIT 1;`
2. Should see record with `timestamp` as server time (UTC)
3. `heart_rate = 75`, `spo2 = 98`

---

### Test 2: Disconnect Payload (When Implemented)

**Test Payload:**
```bash
curl -X POST https://api.hireforcare.com/webhook/hc20-data \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+919876543210",
    "deviceId": "TEST_DEVICE_001",
    "heartRate": null,
    "spo2": null,
    "temperature": null,
    "errorType": "Device Disconnect",
    "message": "Device Disconnect",
    "timestamp": "2026-01-08T14:00:00.000Z"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Disconnect recorded",
  "errorType": "Device Disconnect",
  "notificationSent": true
}
```

**Verify:**
1. Check database: `SELECT * FROM device_notifications WHERE device_id = 'TEST_DEVICE_001' ORDER BY sent_at DESC LIMIT 1;`
2. Should see notification with `type = 'Device Disconnect'` and `status = 'SENT'`
3. Check WhatsApp on +919876543210 for notification message

---

### Test 3: Cron Job Backup Detection

**Scenario:** Stop sending webhooks completely

1. Send normal data at 14:00:00
2. Wait 3+ minutes (don't send any webhooks)
3. At 14:03:00, cron runs
4. Should detect 3-min silence
5. Should send WhatsApp notification (if no recent notification)

**Verify:**
```bash
# Check backend logs
pm2 logs hireforcare-backend | grep "COMPLETE SILENCE"

# Should see:
# 🔍 [Backup Detection] Checking for COMPLETE SILENCE (3+ minutes no webhooks)...
# Found 1 devices with 3+ min silence
# ✅ No recent notification - sending COMPLETE SILENCE alert...
```

---

## 📝 Checklist for Flutter Team

### Must Implement:

- [ ] **UTC Timestamps:** Change `DateTime.now().toIso8601String()` → `DateTime.now().toUtc().toIso8601String()`
- [ ] **Disconnect Detection:** Detect when HC20 device disconnects (Bluetooth lost)
- [ ] **Network Detection:** Detect when internet lost (but app still running)
- [ ] **Disconnect Payload:** Send webhook with all health fields as `null` + `errorType` field
- [ ] **Phone Number:** Include user's phone number in disconnect payload
- [ ] **Error Types:** Send correct `errorType` ("Device Disconnect" or "Network Disconnect")

### Backend is Ready For:

- ✅ Receiving normal health data every 2 minutes
- ✅ Storing data with server timestamp (UTC)
- ✅ Receiving disconnect payloads (when Flutter implements)
- ✅ Sending WhatsApp notifications based on `errorType`
- ✅ 5-minute cooldown to prevent spam
- ✅ Cron backup detection (3-min intervals, 3-min silence threshold)

### Testing Steps:

1. **Fix timestamps first** (`.toUtc()`) - This is critical!
2. **Test normal data** - Verify timestamps are correct in database
3. **Implement disconnect detection** in Flutter
4. **Send disconnect payloads** with correct format
5. **Test both disconnect types** (Device and Network)
6. **Verify notifications** are received on WhatsApp
7. **Test cooldown** - Should only get one notification per 5 minutes

---

## 📞 Support & Questions

If you have questions or issues:

1. **Check backend logs:** `pm2 logs hireforcare-backend`
2. **Search for disconnect events:** `pm2 logs | grep "DISCONNECT"`
3. **Check database:** Query `hc20_data` and `device_notifications` tables
4. **Test with curl:** Use test payloads above to verify backend is working

---

**Last Updated:** January 8, 2026  
**Backend Version:** Latest (with 5-min cooldown fix)  
**Status:** Ready for Flutter disconnect implementation
