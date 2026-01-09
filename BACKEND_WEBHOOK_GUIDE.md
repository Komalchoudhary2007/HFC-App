# Backend Webhook Integration Guide

## Overview

The HFC Flutter mobile app continuously sends health data to the backend webhook endpoint **every 2 minutes**. The webhook is always called regardless of device connection status, allowing the backend to track both connected and disconnected states.

---

## Webhook Endpoint

**URL:** `POST https://api.hireforcare.com/webhook/hc20-data`

**Frequency:** Every 2 minutes (120 seconds)

**Always Sends:** Yes, even when device is disconnected

---

## Payload Structure

### 1. When Device is CONNECTED (Normal Operation)

**All health data fields have real values:**

```json
{
  "phone": "+1234567890",
  "deviceId": "HC20_A1B2C3D4E5F6",
  "heartRate": 75,
  "spo2": 98,
  "bloodPressure": [120, 80],
  "temperature": 36.5,
  "batteryLevel": 85,
  "steps": 5420,
  "timestamp": "2026-01-08T10:30:45.123Z"
}
```

### 2. When Device is DISCONNECTED

**All health data fields are `null`, with error details:**

```json
{
  "phone": "+1234567890",
  "deviceId": "HC20_A1B2C3D4E5F6",
  "heartRate": null,
  "spo2": null,
  "bloodPressure": null,
  "temperature": null,
  "batteryLevel": null,
  "steps": null,
  "status": null,
  "message": "Device Disconnect",
  "errorType": "Device Disconnect",
  "timestamp": "2026-01-08T10:32:00.000Z"
}
```

---

## Error Types

The app automatically detects the disconnect reason and sends one of two error types:

### 1. **"Network Disconnect"**
- **Meaning:** The mobile app lost internet connectivity
- **Cause:** WiFi/mobile data disabled, poor signal, API server unreachable
- **User Action Needed:** Check internet connection

### 2. **"Device Disconnect"**
- **Meaning:** HC20 wearable device disconnected from phone via Bluetooth
- **Cause:** Device out of range, powered off, battery dead, Bluetooth disabled
- **User Action Needed:** Bring device closer, charge battery, check Bluetooth

---

## Backend Implementation Guide

### Step 1: Identify Connection Status

```javascript
// Check if device is connected or disconnected
const isDisconnected = 
  data.heartRate === null && 
  data.spo2 === null && 
  data.temperature === null;

if (isDisconnected) {
  // Device is disconnected - handle disconnect logic
  handleDisconnect(data);
} else {
  // Device is connected - store health data
  storeHealthData(data);
}
```

### Step 2: Store Health Data (When Connected)

```javascript
async function storeHealthData(data) {
  try {
    const healthRecord = await prisma.hc20Data.create({
      data: {
        phone: data.phone,
        deviceId: data.deviceId,
        heartRate: data.heartRate,
        spo2: data.spo2,
        bloodPressure: data.bloodPressure,
        temperature: data.temperature,
        batteryLevel: data.batteryLevel,
        steps: data.steps,
        timestamp: new Date(data.timestamp),
        receivedAt: new Date(),
        status: 'connected'
      }
    });
    
    console.log('✅ Health data stored:', healthRecord.id);
    return { success: true };
  } catch (error) {
    console.error('❌ Error storing data:', error);
    return { success: false, error: error.message };
  }
}
```

### Step 3: Handle Disconnect (When Disconnected)

```javascript
async function handleDisconnect(data) {
  try {
    // Store disconnect event with error type
    const disconnectRecord = await prisma.hc20Data.create({
      data: {
        phone: data.phone,
        deviceId: data.deviceId,
        heartRate: null,
        spo2: null,
        bloodPressure: null,
        temperature: null,
        batteryLevel: null,
        steps: null,
        timestamp: new Date(data.timestamp),
        receivedAt: new Date(),
        status: 'disconnected',
        errorType: data.errorType,  // "Network Disconnect" or "Device Disconnect"
        errorMessage: data.message
      }
    });
    
    console.log(`⚠️ Disconnect logged: ${data.errorType}`);
    
    // Optional: Send notification based on error type
    await sendDisconnectNotification(data);
    
    return { success: true };
  } catch (error) {
    console.error('❌ Error handling disconnect:', error);
    return { success: false, error: error.message };
  }
}
```

### Step 4: Send Appropriate Notifications

```javascript
async function sendDisconnectNotification(data) {
  // Check if notification was already sent recently (cooldown logic)
  const lastNotification = await prisma.deviceNotification.findFirst({
    where: {
      deviceId: data.deviceId,
      phone: data.phone,
      sentAt: {
        gte: new Date(Date.now() - 30 * 60 * 1000) // 30 minutes ago
      }
    }
  });
  
  if (lastNotification) {
    console.log('⏸️ Notification cooldown active - skipping');
    return;
  }
  
  // Send different messages based on error type
  let messageBody;
  
  if (data.errorType === 'Network Disconnect') {
    messageBody = `⚠️ Internet Connection Lost\n\n` +
                  `Your HC20 device app has lost internet connectivity.\n\n` +
                  `Please check:\n` +
                  `• WiFi or mobile data is enabled\n` +
                  `• Signal strength is adequate\n` +
                  `• Mobile data not exhausted\n\n` +
                  `Health monitoring will resume automatically when connection is restored.`;
  } else {
    // Device Disconnect
    messageBody = `⚠️ HC20 Device Disconnected\n\n` +
                  `Your HC20 device (${data.deviceId}) has been disconnected.\n\n` +
                  `Please check:\n` +
                  `• Device battery level\n` +
                  `• Device is within Bluetooth range (10 meters)\n` +
                  `• Device is powered on\n` +
                  `• Bluetooth is enabled on your phone\n\n` +
                  `The app will automatically reconnect when the device is nearby.`;
  }
  
  // Send WhatsApp notification
  await sendWhatsAppMessage(data.phone, messageBody);
  
  // Log notification
  await prisma.deviceNotification.create({
    data: {
      deviceId: data.deviceId,
      phone: data.phone,
      type: data.errorType,
      message: messageBody,
      status: 'sent',
      sentAt: new Date()
    }
  });
  
  console.log(`✅ ${data.errorType} notification sent to ${data.phone}`);
}
```

---

## Complete Backend Webhook Handler Example

```javascript
app.post('/webhook/hc20-data', async (req, res) => {
  try {
    const data = req.body;
    
    // Validate required fields
    if (!data.phone || !data.deviceId || !data.timestamp) {
      return res.status(400).json({ 
        success: false, 
        error: 'Missing required fields: phone, deviceId, timestamp' 
      });
    }
    
    // Check if device is disconnected (all health values are null)
    const isDisconnected = 
      data.heartRate === null && 
      data.spo2 === null && 
      data.temperature === null;
    
    if (isDisconnected) {
      // Handle disconnect
      console.log(`⚠️ Disconnect detected: ${data.errorType}`);
      await handleDisconnect(data);
      
      return res.status(200).json({ 
        success: true, 
        message: 'Disconnect recorded',
        errorType: data.errorType
      });
    } else {
      // Handle normal health data
      console.log(`✅ Health data received from ${data.phone}`);
      const result = await storeHealthData(data);
      
      return res.status(200).json({ 
        success: true, 
        message: 'Health data stored',
        recordId: result.id
      });
    }
  } catch (error) {
    console.error('❌ Webhook error:', error);
    return res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});
```

---

## Database Schema Recommendations

### Table: `hc20_data`

```sql
CREATE TABLE hc20_data (
  id SERIAL PRIMARY KEY,
  phone VARCHAR(20) NOT NULL,
  device_id VARCHAR(50) NOT NULL,
  heart_rate INTEGER,
  spo2 INTEGER,
  blood_pressure INTEGER[],
  temperature DECIMAL(4,1),
  battery_level INTEGER,
  steps INTEGER,
  status VARCHAR(20), -- 'connected' or 'disconnected'
  error_type VARCHAR(50), -- 'Network Disconnect' or 'Device Disconnect'
  error_message TEXT,
  timestamp TIMESTAMP NOT NULL,
  received_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW(),
  
  INDEX idx_phone (phone),
  INDEX idx_device_id (device_id),
  INDEX idx_timestamp (timestamp),
  INDEX idx_status (status)
);
```

### Table: `device_notifications`

```sql
CREATE TABLE device_notifications (
  id SERIAL PRIMARY KEY,
  device_id VARCHAR(50) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  type VARCHAR(50) NOT NULL, -- 'Network Disconnect' or 'Device Disconnect'
  message TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'sent',
  sent_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  
  INDEX idx_device_phone (device_id, phone),
  INDEX idx_sent_at (sent_at)
);
```

---

## Testing the Integration

### Test 1: Simulate Connected Device

**POST** `https://api.hireforcare.com/webhook/hc20-data`

```json
{
  "phone": "+1234567890",
  "deviceId": "TEST_DEVICE_001",
  "heartRate": 72,
  "spo2": 97,
  "bloodPressure": [118, 78],
  "temperature": 36.6,
  "batteryLevel": 80,
  "steps": 4500,
  "timestamp": "2026-01-08T10:00:00.000Z"
}
```

**Expected Backend Response:**
```json
{
  "success": true,
  "message": "Health data stored",
  "recordId": 12345
}
```

### Test 2: Simulate Network Disconnect

**POST** `https://api.hireforcare.com/webhook/hc20-data`

```json
{
  "phone": "+1234567890",
  "deviceId": "TEST_DEVICE_001",
  "heartRate": null,
  "spo2": null,
  "bloodPressure": null,
  "temperature": null,
  "batteryLevel": null,
  "steps": null,
  "status": null,
  "message": "Network Disconnect",
  "errorType": "Network Disconnect",
  "timestamp": "2026-01-08T10:02:00.000Z"
}
```

**Expected Backend Response:**
```json
{
  "success": true,
  "message": "Disconnect recorded",
  "errorType": "Network Disconnect"
}
```

**Expected Backend Action:**
- Store disconnect record with error type
- Send WhatsApp notification about network issue
- Log notification to prevent spam

### Test 3: Simulate Device Disconnect

**POST** `https://api.hireforcare.com/webhook/hc20-data`

```json
{
  "phone": "+1234567890",
  "deviceId": "TEST_DEVICE_001",
  "heartRate": null,
  "spo2": null,
  "bloodPressure": null,
  "temperature": null,
  "batteryLevel": null,
  "steps": null,
  "status": null,
  "message": "Device Disconnect",
  "errorType": "Device Disconnect",
  "timestamp": "2026-01-08T10:04:00.000Z"
}
```

**Expected Backend Response:**
```json
{
  "success": true,
  "message": "Disconnect recorded",
  "errorType": "Device Disconnect"
}
```

**Expected Backend Action:**
- Store disconnect record with error type
- Send WhatsApp notification about device issue
- Log notification with cooldown

---

## Notification Cooldown Logic (Recommended)

To prevent notification spam, implement a cooldown period:

```javascript
// Recommended: 30 minutes between notifications for same device
const NOTIFICATION_COOLDOWN = 30 * 60 * 1000; // 30 minutes in milliseconds

async function shouldSendNotification(deviceId, phone) {
  const lastNotification = await prisma.deviceNotification.findFirst({
    where: {
      deviceId: deviceId,
      phone: phone,
      sentAt: {
        gte: new Date(Date.now() - NOTIFICATION_COOLDOWN)
      }
    },
    orderBy: { sentAt: 'desc' }
  });
  
  return !lastNotification; // Send if no recent notification
}
```

---

## Dashboard Queries (Examples)

### Get Latest Device Status

```javascript
// Get most recent record for a device
const latestStatus = await prisma.hc20Data.findFirst({
  where: {
    deviceId: 'HC20_A1B2C3D4E5F6',
    phone: '+1234567890'
  },
  orderBy: { timestamp: 'desc' }
});

const isConnected = latestStatus.status === 'connected';
```

### Get Disconnect History

```javascript
// Get all disconnects in last 24 hours
const disconnects = await prisma.hc20Data.findMany({
  where: {
    deviceId: 'HC20_A1B2C3D4E5F6',
    status: 'disconnected',
    timestamp: {
      gte: new Date(Date.now() - 24 * 60 * 60 * 1000)
    }
  },
  orderBy: { timestamp: 'desc' }
});
```

### Get Health Data Trends

```javascript
// Get last 10 health readings (excluding disconnects)
const healthData = await prisma.hc20Data.findMany({
  where: {
    deviceId: 'HC20_A1B2C3D4E5F6',
    status: 'connected',
    heartRate: { not: null }
  },
  orderBy: { timestamp: 'desc' },
  take: 10
});
```

---

## Key Points for Backend Team

1. ✅ **Always respond with HTTP 200** - App needs confirmation webhook was received
2. ✅ **Check for null values** - This identifies disconnects (don't check status field)
3. ✅ **Use errorType field** - Determines which notification message to send
4. ✅ **Implement cooldown** - Prevent notification spam (recommended: 30 minutes)
5. ✅ **Store all records** - Both connected and disconnected states for analytics
6. ✅ **Validate timestamp** - Use for disconnect duration calculations
7. ✅ **Include deviceId** - Essential for tracking specific HC20 devices

---

## Troubleshooting

### Issue: Too many notifications

**Solution:** Implement or reduce cooldown period

### Issue: Not receiving webhooks

**Check:**
- Backend endpoint is accessible at `https://api.hireforcare.com/webhook/hc20-data`
- No firewall blocking requests
- Endpoint returns HTTP 200 response

### Issue: Can't differentiate connected/disconnected

**Check:**
- Look for `null` values in health fields (`heartRate`, `spo2`, etc.)
- Don't rely only on `status` field

### Issue: Wrong notification sent

**Check:**
- Read `errorType` field correctly
- Ensure string comparison is case-sensitive: `"Network Disconnect"` vs `"Device Disconnect"`

---

## Contact & Support

For integration issues or questions:
- Review webhook logs in backend console
- Check mobile app debug logs for webhook responses
- Verify payload structure matches examples above

---

**Last Updated:** January 8, 2026  
**App Version:** 8.0.8 (Build 55)  
**Webhook Frequency:** Every 2 minutes  
**Backend API:** https://api.hireforcare.com
