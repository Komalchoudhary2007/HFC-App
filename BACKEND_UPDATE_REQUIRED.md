# Backend Update Required for History Data

## Problem
Your current backend endpoint extracts data like this:
```javascript
const { timestamp, device, realtime_data, stress_alert } = req.body;
```

But historical data from the app sends:
```json
{
  "dataType": "history",
  "historyType": "heart_rate",
  "history_data": {...},  // NOT realtime_data
  "device": {...}
}
```

## Required Changes

### 1. Add data type check at the beginning of the endpoint:

```javascript
app.post("/webhook/hc20-data", async (req, res) => {
  // ... existing timeout code ...

  try {
    console.log('📱 HC20 WEBHOOK - FULL DATA RECEIVED:', JSON.stringify(req.body, null, 2));

    // ✅ ADD THIS: Check if it's historical data
    const dataType = req.body.dataType || 'live';
    
    if (dataType === 'history') {
      // Handle historical data separately
      return await handleHistoricalData(req, res, responseTimeout);
    }

    // ... rest of your existing live data code ...
    const { timestamp, device, realtime_data, stress_alert } = req.body;
    // ... continue as normal ...
```

### 2. Add new function to handle historical data:

```javascript
async function handleHistoricalData(req, res, responseTimeout) {
  try {
    const { timestamp, device, history_data, historyType } = req.body;
    
    // Validate required fields
    if (!device?.id || !timestamp || !historyType) {
      clearTimeout(responseTimeout);
      return res.status(400).json({
        error: 'Missing required fields for historical data'
      });
    }

    // Parse timestamp
    const parsedTimestamp = new Date(timestamp);
    const dataTimestamp = new Date(history_data.data_timestamp);

    // Check if device is associated with a user
    const deviceUserCheck = await prisma.hc20Data.findFirst({
      where: { 
        deviceId: device.id,
        userId: { not: null }
      },
      select: { userId: true },
      take: 1
    });
    
    const associatedUserId = deviceUserCheck?.userId || null;

    // Store historical data with marker
    const hc20Data = await prisma.hc20Data.create({
      data: {
        deviceId: device.id,
        deviceName: device.name || null,
        userId: associatedUserId,
        timestamp: dataTimestamp, // Use original data timestamp
        rawData: req.body, // Store complete payload
        hfcData: {
          device: {
            id: device.id,
            name: device.name
          },
          timestamp: dataTimestamp.toISOString(),
          dataType: 'history',
          historyType: historyType,
          history_data: history_data
        },
        // Set specific fields based on history type
        ...(historyType === 'heart_rate' && {
          // Parse heart rate from history_data string if needed
        }),
        ...(historyType === 'hrv' && {
          // Parse HRV from history_data string if needed
        }),
        ...(historyType === 'summary' && {
          // Parse summary (steps, calories) from history_data string if needed
        })
      }
    });

    clearTimeout(responseTimeout);
    return res.status(200).json({
      success: true,
      message: 'Historical data received and stored',
      deviceId: device.id,
      userId: associatedUserId,
      historyType: historyType,
      timestamp: dataTimestamp.toISOString(),
      userLinked: !!associatedUserId
    });

  } catch (error) {
    console.error('❌ Historical data processing error:', error);
    clearTimeout(responseTimeout);
    return res.status(500).json({
      error: 'Failed to process historical data',
      message: error.message
    });
  }
}
```

### 3. Alternative: Simpler approach (just store as rawData)

If you don't need to parse historical data immediately, you can do this:

```javascript
// At the beginning of your endpoint
const dataType = req.body.dataType || 'live';

if (dataType === 'history') {
  // Quick storage without parsing
  const { device, timestamp, history_data, historyType } = req.body;
  
  await prisma.hc20Data.create({
    data: {
      deviceId: device.id,
      deviceName: device.name,
      userId: null, // Will be linked later
      timestamp: new Date(history_data.data_timestamp || timestamp),
      rawData: req.body, // Store complete payload
      hfcData: {
        dataType: 'history',
        historyType: historyType,
        device: device,
        data: history_data
      }
    }
  });
  
  clearTimeout(responseTimeout);
  return res.status(200).json({
    success: true,
    message: 'Historical data stored',
    historyType: historyType
  });
}

// Continue with live data processing...
```

## Summary

**Option 1 (Recommended)**: Add proper historical data parsing  
**Option 2 (Quick Fix)**: Just store historical data in `rawData` and `hfcData` fields for later processing

Choose Option 2 if you want to get it working quickly and parse historical data later in a background job.
