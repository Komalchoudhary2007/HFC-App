# Release Notes - Version 8.0.8 (Build 55)

**Release Date:** January 8, 2026

## 🎯 What's New

### 1. Auto-Reconnect Feature
- **Automatically reconnects** to your HC20 device when it comes back in Bluetooth range
- Device ID is saved after first connection
- Background scanner checks every 30 seconds for your saved device
- No need to manually reconnect after walking away and returning
- Works even after app restart

### 2. Enhanced Disconnect Detection
- App now distinguishes between two types of disconnects:
  - **Network Disconnect**: Lost internet connection
  - **Device Disconnect**: HC20 device out of Bluetooth range
- More accurate problem identification for troubleshooting

### 3. Improved Backend Communication
- Webhook now sends **every 2 minutes** (for testing - normally 10 minutes)
- Always sends data to backend, even when disconnected
- When disconnected, sends null values with timestamp for tracking
- Backend can now identify exact disconnect reasons

### 4. Device ID Display
- Shows your connected HC20 device ID in the menu drawer
- Displays auto-reconnect status
- Easy identification of which device is paired

## 🔧 Technical Improvements

### Webhook System
- **Frequency**: Every 2 minutes (120 seconds)
- **Always Active**: Sends data regardless of connection status
- **Connected**: Sends real health data (heart rate, SpO2, blood pressure, etc.)
- **Disconnected**: Sends null values with error type and timestamp

### Disconnect Payload
When device or network is disconnected, backend receives:
```json
{
  "heartRate": null,
  "spo2": null,
  "bloodPressure": null,
  "temperature": null,
  "batteryLevel": null,
  "steps": null,
  "status": null,
  "message": "Network Disconnect" or "Device Disconnect",
  "errorType": "Network Disconnect" or "Device Disconnect",
  "timestamp": "2026-01-08T10:30:00.000Z"
}
```

### Storage System
- Device ID saved in secure storage with SharedPreferences backup
- Persistent across app restarts
- Auto-reconnect resumes automatically

## 📱 User Experience Changes

### Before (v8.0.7)
- Manual reconnection required after device disconnect
- Single disconnect notification type
- Webhook only sent when connected
- No device ID visibility

### After (v8.0.8)
- ✅ Automatic reconnection when device returns
- ✅ Specific error types (Network vs Device)
- ✅ Continuous webhook tracking with timestamps
- ✅ Device ID displayed in menu
- ✅ Background scanner for saved device

## 🛠️ Bug Fixes
- Fixed duplicate methods in storage service
- Improved webhook timing consistency
- Enhanced error handling for network issues

## 📊 Timings & Intervals

| Feature | Interval | Purpose |
|---------|----------|---------|
| Webhook Timer | 2 minutes | Send health data to backend (testing) |
| Auto-Reconnect Scan | 30 seconds | Check for saved device |
| Scan Duration | 10 seconds | How long to scan per cycle |
| HRV Refresh | 6 hours | Update HRV data from HC20 |
| Real-time Stream | ~1 second | Live health data updates |

## 🚀 What Stays the Same

All existing features continue to work:
- ✅ OTP Authentication
- ✅ Real-time health monitoring
- ✅ Heart Rate, SpO2, Blood Pressure, Temperature, Steps
- ✅ Battery level monitoring
- ✅ Background execution with foreground service
- ✅ User profile management
- ✅ Secure data storage

## 📖 Documentation

New documentation files added:
- **HOW_IT_WORKS.md** - Complete system architecture and data flows
- **BACKEND_WEBHOOK_GUIDE.md** - Backend integration guide with code examples

## 🔄 Upgrade Notes

### From v8.0.7 to v8.0.8:
1. Install APK v8.0.8
2. Login with your phone number
3. Connect to your HC20 device
4. Device ID will be automatically saved
5. Auto-reconnect will activate automatically

**Note:** First-time users will need to connect once. After that, the app will auto-reconnect whenever the device is nearby.

## 🧪 Testing Checklist

When testing this version, verify:
- [ ] Device connects successfully
- [ ] Device ID appears in drawer menu
- [ ] Webhook sends every 2 minutes when connected
- [ ] Walk away from device and verify "Device Disconnect" webhook
- [ ] Turn off WiFi/data and verify "Network Disconnect" webhook
- [ ] Return to device range and verify auto-reconnect works
- [ ] Close and reopen app - auto-reconnect should resume
- [ ] Health data displays correctly in real-time
- [ ] Backend receives null values when disconnected

## 🆘 Troubleshooting

### Auto-reconnect not working?
- Check Bluetooth is enabled
- Verify device ID is saved (visible in drawer menu)
- Ensure battery optimization is disabled for the app
- Make sure device is powered on and in range

### Network vs Device disconnect unclear?
- Check the `errorType` field in backend webhook data
- "Network Disconnect" = Internet issue
- "Device Disconnect" = Bluetooth/device issue

### Webhook not sending?
- Check backend endpoint is accessible
- Verify phone number is registered
- Check app logs for webhook responses

## 📞 Support

For issues or questions:
- Check [HOW_IT_WORKS.md](HOW_IT_WORKS.md) for system details
- Review [BACKEND_WEBHOOK_GUIDE.md](BACKEND_WEBHOOK_GUIDE.md) for backend integration
- Check debug logs in the app
- Verify backend webhook endpoint is responding

---

**Version:** 8.0.8+55  
**Tested On:** Android 11+  
**Flutter SDK:** Stable Channel  
**Backend API:** https://api.hireforcare.com  
**HC20 SDK Version:** 1.0.4
