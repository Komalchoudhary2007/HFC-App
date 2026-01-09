# Backend: Device Disconnect Notification System

## Overview
Automatically detect when HC20 devices stop sending data and send WhatsApp notifications to users.

---

## 1. API Endpoint for Manual Testing

### POST `/api/notifications/device-disconnect`

**Purpose:** Manual trigger for disconnect notifications (used by Test button in app)

**Headers:**
```
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json
```

**Request Body:**
```json
{
  "phone": "9999999999",
  "deviceId": "HC20_DEVICE_ID",
  "deviceName": "HC20 Device",
  "timestamp": "2026-01-06T10:00:00.000Z"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Notification sent successfully",
  "messageId": "wamid_xxxxx"
}
```

---

## 2. Backend Implementation

### Step 1: Create Notification Endpoint

**File:** `apps/api/src/controllers/notifications/deviceDisconnect.ts`

```typescript
import { Request, Response } from 'express';
import axios from 'axios';
import prisma from '@repo/database';

// WhatsApp Configuration (reuse from auth)
const WHATSAPP_TOKEN = "YOUR_WHATSAPP_TOKEN";
const WHATSAPP_PHONE_NUMBER_ID = "105369022472808";
const WHATSAPP_TEMPLATE = "device_disconnect"; // Create this template

export const sendDeviceDisconnectNotification = async (req: Request, res: Response) => {
  const { phone, deviceId, deviceName, timestamp } = req.body;
  const userId = req.user?.id; // From JWT auth middleware
  
  try {
    console.log(`📱 Sending disconnect notification to ${phone} for device ${deviceId}`);
    
    // Send WhatsApp notification
    const messageBody = {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: phone,
      type: "template",
      template: {
        name: WHATSAPP_TEMPLATE,
        language: {
          code: "en"
        },
        components: [
          {
            type: "body",
            parameters: [
              {
                type: "text",
                text: deviceName || "HC20 Device"
              }
            ]
          }
        ]
      }
    };

    const response = await axios.post(
      `https://graph.facebook.com/v13.0/${WHATSAPP_PHONE_NUMBER_ID}/messages`,
      messageBody,
      {
        headers: {
          'Authorization': `Bearer ${WHATSAPP_TOKEN}`,
          'Content-Type': 'application/json'
        }
      }
    );

    console.log('✅ WhatsApp notification sent:', response.data);

    // Log notification in database
    await prisma.deviceNotification.create({
      data: {
        userId,
        deviceId,
        phone,
        type: 'DISCONNECT',
        status: 'SENT',
        wamid: response.data.messages?.[0]?.id,
        sentAt: new Date(),
      },
    });

    return res.status(200).json({
      success: true,
      message: 'Notification sent successfully',
      messageId: response.data.messages?.[0]?.id,
    });

  } catch (error: any) {
    console.error('❌ Error sending disconnect notification:', error);
    
    // Log failed attempt
    await prisma.deviceNotification.create({
      data: {
        userId,
        deviceId,
        phone,
        type: 'DISCONNECT',
        status: 'FAILED',
        error: error.message,
        sentAt: new Date(),
      },
    }).catch(console.error);

    return res.status(500).json({
      success: false,
      error: 'Failed to send notification',
      details: error.message,
    });
  }
};
```

---

### Step 2: Add Route

**File:** `apps/api/src/routes/notifications.ts`

```typescript
import { Router } from 'express';
import { authMiddleware } from '../middleware/auth';
import { sendDeviceDisconnectNotification } from '../controllers/notifications/deviceDisconnect';

const router = Router();

// Manual trigger (from app test button)
router.post('/device-disconnect', authMiddleware, sendDeviceDisconnectNotification);

export default router;
```

**File:** `apps/api/src/index.ts`

```typescript
import notificationsRouter from './routes/notifications';

// ... existing code ...

app.use('/api/notifications', notificationsRouter);
```

---

### Step 3: Create Prisma Schema for Notification Tracking

**File:** `packages/database/prisma/schema.prisma`

```prisma
model DeviceNotification {
  id        String   @id @default(cuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id])
  deviceId  String
  phone     String
  type      String   // 'DISCONNECT', 'RECONNECT'
  status    String   // 'SENT', 'FAILED'
  wamid     String?  // WhatsApp message ID
  error     String?
  sentAt    DateTime @default(now())
  createdAt DateTime @default(now())
  
  @@index([userId, deviceId])
  @@index([deviceId, createdAt])
  @@map("device_notifications")
}

// Add to User model
model User {
  // ... existing fields ...
  deviceNotifications DeviceNotification[]
}
```

Run migration:
```bash
npx prisma migrate dev --name add_device_notifications
```

---

## 3. Automatic Disconnect Detection (Cron Job)

### Step 4: Create Background Monitor

**File:** `apps/api/src/services/deviceMonitor.ts`

```typescript
import prisma from '@repo/database';
import axios from 'axios';

const WHATSAPP_TOKEN = "YOUR_WHATSAPP_TOKEN";
const WHATSAPP_PHONE_NUMBER_ID = "105369022472808";
const WHATSAPP_TEMPLATE = "device_disconnect";

// Check interval: 10 minutes (600 seconds)
const DATA_TIMEOUT_MINUTES = 10;

export async function checkDisconnectedDevices() {
  console.log('🔍 Checking for disconnected devices...');
  
  try {
    // Find devices that haven't sent data in last 10 minutes
    const tenMinutesAgo = new Date(Date.now() - DATA_TIMEOUT_MINUTES * 60 * 1000);
    
    const disconnectedDevices = await prisma.$queryRaw`
      SELECT DISTINCT
        hc."deviceId",
        hc."userId",
        u.phone,
        u.name,
        MAX(hc."timestamp") as last_seen
      FROM "HC20Data" hc
      JOIN "User" u ON u.id = hc."userId"
      WHERE hc."timestamp" < ${tenMinutesAgo}
      AND hc."userId" IS NOT NULL
      GROUP BY hc."deviceId", hc."userId", u.phone, u.name
      HAVING MAX(hc."timestamp") < ${tenMinutesAgo}
    `;
    
    console.log(`Found ${disconnectedDevices.length} disconnected devices`);
    
    for (const device of disconnectedDevices as any[]) {
      // Check if we already sent notification for this disconnection
      const existingNotification = await prisma.deviceNotification.findFirst({
        where: {
          deviceId: device.deviceId,
          userId: device.userId,
          type: 'DISCONNECT',
          status: 'SENT',
          createdAt: {
            gte: new Date(Date.now() - 24 * 60 * 60 * 1000), // Last 24 hours
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
      });
      
      // Only send if no notification sent in last 24 hours
      if (!existingNotification) {
        console.log(`📱 Sending notification to ${device.phone} for device ${device.deviceId}`);
        
        await sendWhatsAppDisconnectNotification(
          device.phone,
          device.deviceId,
          device.userId,
          'HC20 Device'
        );
      } else {
        console.log(`⏭️  Skipping ${device.deviceId} - notification already sent recently`);
      }
    }
    
  } catch (error) {
    console.error('❌ Error in device monitor:', error);
  }
}

async function sendWhatsAppDisconnectNotification(
  phone: string,
  deviceId: string,
  userId: string,
  deviceName: string
) {
  try {
    const messageBody = {
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: phone,
      type: "template",
      template: {
        name: WHATSAPP_TEMPLATE,
        language: {
          code: "en"
        },
        components: [
          {
            type: "body",
            parameters: [
              {
                type: "text",
                text: deviceName
              }
            ]
          }
        ]
      }
    };

    const response = await axios.post(
      `https://graph.facebook.com/v13.0/${WHATSAPP_PHONE_NUMBER_ID}/messages`,
      messageBody,
      {
        headers: {
          'Authorization': `Bearer ${WHATSAPP_TOKEN}`,
          'Content-Type': 'application/json'
        }
      }
    );

    // Log success
    await prisma.deviceNotification.create({
      data: {
        userId,
        deviceId,
        phone,
        type: 'DISCONNECT',
        status: 'SENT',
        wamid: response.data.messages?.[0]?.id,
        sentAt: new Date(),
      },
    });

    console.log(`✅ Notification sent to ${phone}`);

  } catch (error: any) {
    console.error(`❌ Failed to send notification to ${phone}:`, error);
    
    // Log failure
    await prisma.deviceNotification.create({
      data: {
        userId,
        deviceId,
        phone,
        type: 'DISCONNECT',
        status: 'FAILED',
        error: error.message,
        sentAt: new Date(),
      },
    }).catch(console.error);
  }
}
```

---

### Step 5: Setup Cron Job

**Option A: Using node-cron (Simple)**

**File:** `apps/api/src/cron/deviceMonitor.ts`

```typescript
import cron from 'node-cron';
import { checkDisconnectedDevices } from '../services/deviceMonitor';

// Run every 10 minutes
export function startDeviceMonitoring() {
  console.log('🚀 Starting device disconnect monitoring cron job');
  console.log('⏰ Running every 10 minutes');
  
  // Run every 10 minutes: */10 * * * *
  cron.schedule('*/10 * * * *', async () => {
    console.log('\n⏰ [Cron] Running device disconnect check...');
    await checkDisconnectedDevices();
  });
  
  // Also run immediately on startup
  checkDisconnectedDevices();
}
```

**File:** `apps/api/src/index.ts`

```typescript
import { startDeviceMonitoring } from './cron/deviceMonitor';

// ... existing code ...

// Start cron jobs
startDeviceMonitoring();

console.log('✅ API server started with device monitoring');
```

Install dependency:
```bash
npm install node-cron
npm install --save-dev @types/node-cron
```

---

**Option B: Using BullMQ (Production-grade)**

```typescript
import { Queue, Worker } from 'bullmq';
import { checkDisconnectedDevices } from '../services/deviceMonitor';

const connection = {
  host: process.env.REDIS_HOST || 'localhost',
  port: Number(process.env.REDIS_PORT) || 6379,
};

// Create queue
const deviceMonitorQueue = new Queue('device-monitor', { connection });

// Add recurring job (every 10 minutes)
export async function startDeviceMonitoring() {
  await deviceMonitorQueue.add(
    'check-disconnected-devices',
    {},
    {
      repeat: {
        every: 10 * 60 * 1000, // 10 minutes in ms
      },
    }
  );
  
  console.log('✅ Device monitoring queue started');
}

// Create worker
const worker = new Worker(
  'device-monitor',
  async (job) => {
    console.log('⏰ Running device disconnect check...');
    await checkDisconnectedDevices();
  },
  { connection }
);

worker.on('completed', (job) => {
  console.log(`✅ Job ${job.id} completed`);
});

worker.on('failed', (job, err) => {
  console.error(`❌ Job ${job?.id} failed:`, err);
});
```

---

## 4. WhatsApp Template Setup

### Create Template on Facebook Business Manager

1. Go to **Meta Business Suite** → **WhatsApp Manager**
2. **Create New Template**:
   - **Name:** `device_disconnect`
   - **Category:** Utility
   - **Language:** English
   
3. **Template Content:**

**Header:** None

**Body:**
```
🚨 Device Disconnected

Your {{1}} has stopped sending data.

Please check:
• Device is powered on
• Bluetooth is enabled
• Device is within range

Open the app to reconnect.
```

**Footer:** None

**Buttons:** None

4. **Submit for Approval** (usually approved in 24 hours)

---

## 5. Testing

### Test Manual Notification (App Button)

1. Open HFC App
2. Connect to device
3. Click **"Test Disconnect Notification"** button
4. Check WhatsApp for notification

### Test Automatic Detection

1. Connect device and let it send data
2. Disconnect device or turn off app
3. Wait 10 minutes
4. Cron job will detect and send notification
5. Check WhatsApp

### Verify in Logs

```bash
# Check cron execution
grep "device disconnect check" logs/api.log

# Check notifications sent
grep "Notification sent to" logs/api.log

# Check database
psql -d hfc_db -c "SELECT * FROM device_notifications ORDER BY created_at DESC LIMIT 10;"
```

---

## 6. Environment Variables

Add to `.env`:

```env
# WhatsApp (if not already set)
WHATSAPP_TOKEN=your_whatsapp_token
WHATSAPP_PHONE_NUMBER_ID=105369022472808

# Redis (if using BullMQ)
REDIS_HOST=localhost
REDIS_PORT=6379

# Monitoring
DEVICE_TIMEOUT_MINUTES=10
NOTIFICATION_COOLDOWN_HOURS=24
```

---

## Summary

✅ **Manual Test:** Test button in app triggers instant notification
✅ **Automatic:** Cron job checks every 10 minutes for disconnected devices
✅ **One notification:** Only sends once per 24 hours per device
✅ **Database tracking:** All notifications logged for audit
✅ **WhatsApp:** Uses existing Meta Business API setup

The system will automatically notify users when their device stops sending data!
