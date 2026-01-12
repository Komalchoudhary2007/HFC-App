# 🚀 HFC App - New Features & Testing Guide

**Date:** January 12, 2026  
**Version:** 8.0.11+  
**For:** QA Team & Testing Team

---

## 📋 Overview

This document outlines the latest features and automations added to the HFC App. Please test each feature thoroughly and report any issues.

---

## 🆕 NEW FEATURES

### 1. ⏱️ Data Refresh Interval Updated
**What Changed:**
- Webhook data is now sent every **10 minutes** 
- Reduces server load while maintaining effective monitoring
- Device data still collected in real-time, just sent less frequently

**How to Test:**
- Connect device and wait
- Check backend logs - data should arrive every 10 minutes
- Verify timestamps show consistent 600-second gaps

---

### 2. 🔋 Low Battery Warning System
**What It Does:**
- Monitors HC20 device battery level continuously
- Shows prominent red warning banner when battery drops below 20%
- Sends special webhook notification to backend with low battery flag
- Alert sent only once per low battery event (no spam)

**How to Test:**
- Wait until device battery reaches 19% or lower
- Check app screen - should see red warning banner
- Verify webhook sent with low battery flag
- Confirm alert doesn't repeat unnecessarily

**What to Look For:**
- Red banner appears prominently on home screen
- Banner shows current battery percentage
- Backend receives low battery notification
- Warning disappears when device charged above 20%

---

### 3. 📱 Push Notifications System
**What It Does:**
- Shows mobile notifications for critical events
- Works even when app is in background
- Different notification types with color coding

**Notification Types:**

**🔴 Device Disconnected (Red)**
- Triggers when HC20 device disconnects
- Different messages for different reasons:
  - Bluetooth turned off
  - Device powered off
  - Device out of range
  - Connection failed
- Tap notification to open app

**🟠 No Internet Connection (Orange)**
- Triggers when phone loses WiFi/mobile data
- Warns that health monitoring is paused
- Auto-dismisses when internet restored

**🟢 Connection Restored (Green)**
- Shows when device successfully reconnects
- Silent notification (no sound)
- Confirms monitoring resumed

**How to Test:**
1. **Test Bluetooth Disconnect:**
   - Turn off Bluetooth → Check red notification appears
   - Turn on Bluetooth → Check green notification appears

2. **Test Device Power Off:**
   - Power off HC20 device → Check red notification with correct message
   - Power on device → Check green notification

3. **Test Out of Range:**
   - Walk away from device → Check red notification
   - Walk back → Check green notification

4. **Test Internet Loss:**
   - Turn on airplane mode → Check orange notification
   - Turn off airplane mode → Check green notification

5. **Test Notification Tap:**
   - Tap any notification → Verify app opens

**What to Look For:**
- Notifications appear within 30-60 seconds of event
- Correct color coding (red/orange/green)
- Appropriate message for each scenario
- No duplicate notifications
- Old notifications cleared when issue resolved

---

### 4. 🔄 Manual Reconnect Button
**What It Does:**
- Appears automatically when device disconnects
- Allows user to force reconnection without restarting app
- Blue button with "Reconnect to Device" label
- Scans for 10 seconds to find saved device

**How to Test:**
- Disconnect device (turn off Bluetooth or power off device)
- Wait for button to appear on screen
- Tap "Reconnect to Device" button
- Verify device reconnects within 10 seconds
- Check button disabled during reconnection

**What to Look For:**
- Button only visible when disconnected
- Button shows clear "Reconnecting..." state
- Successfully finds and reconnects to device
- Button disappears after successful connection

---

### 5. 📊 Connection History Log
**What It Does:**
- Tracks all connection events (connect, disconnect, reconnect)
- Stores last 50 events
- Shows timestamp for each event
- Color-coded entries for easy reading
- Expandable section to save screen space

**How to Test:**
- Connect/disconnect device multiple times
- Tap "Show Connection History" to expand section
- Verify all events logged correctly
- Check timestamps show relative time (e.g., "5m ago")
- Disconnect for different reasons and verify reason shown

**What to Look For:**
- Green entries for connections
- Red entries for disconnections
- Orange entries for reconnections
- Correct disconnect reasons shown
- Timestamps update correctly
- Section expands/collapses smoothly

---

### 6. 📈 Disconnect Pattern Analytics
**What It Does:**
- Calculates statistics about connection patterns
- Shows total disconnects and reconnects
- Displays most common disconnect reason
- Calculates percentages for each disconnect type
- Expandable section with visual tiles

**How to Test:**
- Disconnect device multiple times using different methods:
  - Turn off Bluetooth
  - Power off device
  - Walk out of range
- Tap "Show Analytics" to view statistics
- Verify counters increment correctly
- Check percentages calculated properly

**What to Look For:**
- Total disconnect counter accurate
- Total reconnect counter accurate
- Most common reason displayed correctly
- Percentages add up properly
- Analytics update in real-time

---

### 7. 🌐 Bluetooth & Internet Status Indicators
**What It Does:**
- Shows real-time Bluetooth status (ON/OFF)
- Shows real-time Internet status (Connected/Disconnected)
- Updates every 15 seconds automatically
- Color-coded status boxes
- Visible at top of home screen

**How to Test:**
1. **Bluetooth Monitor:**
   - Check shows "Bluetooth: ON" when Bluetooth enabled
   - Turn off Bluetooth → Verify changes to "Bluetooth: OFF" (red)
   - Turn on Bluetooth → Verify changes back to "Bluetooth: ON" (blue)

2. **Internet Monitor:**
   - Check shows "Internet: Connected" normally
   - Turn on airplane mode → Verify changes to "Internet: Disconnected" (orange)
   - Turn off airplane mode → Verify changes back to "Internet: Connected" (green)

**What to Look For:**
- Status updates within 15-20 seconds
- Correct colors for each state
- Clear, readable text
- Always visible on home screen

---

### 8. ⚡ Improved Disconnect Detection
**What It Does:**
- Detects disconnections much faster than before
- Multiple detection methods for reliability
- Automatic reconnection when device comes back

**Detection Methods:**
- **Active Ping:** Checks device every 30 seconds (fastest)
- **Bluetooth Monitor:** Detects Bluetooth off within 15 seconds
- **Data Check:** Backup method checks if data missing for 5 minutes

**How to Test:**
1. **Test Device Shutdown:**
   - Power off HC20 device
   - Time how long until app shows "Disconnected"
   - Should detect within 30-60 seconds

2. **Test Bluetooth Off:**
   - Turn off phone Bluetooth
   - Should detect within 15-30 seconds

3. **Test Out of Range:**
   - Walk away from device
   - Should detect within 30-60 seconds

4. **Test Auto-Reconnect:**
   - After any disconnect, bring device back
   - Should auto-reconnect within 30-60 seconds

**What to Look For:**
- Fast disconnect detection (under 1 minute)
- UI updates immediately when disconnected
- Auto-reconnect works without user action
- Correct disconnect reason shown

---

### 9. 🎨 Enhanced Status Display
**What It Does:**
- Shows detailed connection status with colors
- Clear status messages with emoji indicators
- Shows time since last data received
- Different status states clearly differentiated

**Status States:**
- 🟢 **Connected** - Device working normally
- 🔴 **Disconnected** - Device not connected
- 🟡 **Reconnecting** - Attempting to reconnect
- 🔵 **Connecting** - Initial connection in progress
- 🔴 **Error** - Connection error occurred

**How to Test:**
- Connect device → Check "Connected" with green color
- Disconnect device → Check "Disconnected" with red color
- Tap reconnect → Check "Reconnecting" with yellow color
- Verify status messages clear and helpful

**What to Look For:**
- Correct colors for each state
- Clear, easy-to-understand messages
- Emoji indicators visible
- Status updates in real-time

---

### 10. 📤 Enhanced Webhook Data
**What It Does:**
- Sends more detailed information to backend
- Includes connection status in every webhook
- Separate flags for different event types
- Sends data even when disconnected (with null values)

**New Data Included:**
- Connection status (CONNECTED/DISCONNECTED)
- Bluetooth status (ON/OFF)
- Internet status (Connected/Disconnected)
- Low battery flag
- Stress alert flag
- Disconnect flag with reason
- Data type (live/history/disconnect)

**How to Test:**
- Connect device and check backend logs
- Verify all new fields present in webhooks
- Disconnect device → Check null values sent with disconnect info
- Verify backend receives data every 10 minutes regardless of connection

**What to Look For:**
- Webhooks sent every 10 minutes consistently
- All status fields populated correctly
- Disconnect webhooks contain reason
- Backend can differentiate event types

---

## 🧪 COMPREHENSIVE TEST SCENARIOS

### Scenario 1: Normal Operation
1. Install and open app
2. Login with credentials
3. Scan and connect to HC20 device
4. Verify "Connected" status shows green
5. Check Bluetooth and Internet indicators show ON/Connected
6. Wait 10 minutes → Verify webhook sent to backend
7. Check device data updates on screen (heart rate, SpO2, etc.)
8. Leave app running for 1 hour → Verify stable connection

### Scenario 2: Device Disconnect & Reconnect
1. Start with connected device
2. Power off HC20 device
3. Verify disconnect detected within 60 seconds
4. Verify red notification appears
5. Check status shows "Disconnected" in red
6. Check disconnect logged in history
7. Power on device
8. Verify auto-reconnect within 60 seconds
9. Verify green notification appears
10. Check reconnect logged in history

### Scenario 3: Bluetooth Toggle
1. Start with connected device
2. Turn off phone Bluetooth
3. Verify disconnect detected within 30 seconds
4. Verify Bluetooth status shows "OFF" in red
5. Verify disconnect reason shows "Bluetooth turned off"
6. Turn on phone Bluetooth
7. Verify auto-reconnect
8. Verify Bluetooth status shows "ON" in blue

### Scenario 4: Internet Loss
1. Keep device connected
2. Turn on airplane mode
3. Verify Internet status shows "Disconnected" in orange
4. Verify orange notification appears
5. Wait 10 minutes → Verify webhook still attempts to send
6. Turn off airplane mode
7. Verify Internet status shows "Connected" in green
8. Verify green notification appears

### Scenario 5: Low Battery
1. Use device until battery drops below 20%
2. Verify red battery warning banner appears
3. Check backend receives low battery webhook
4. Verify alert sent only once
5. Charge device above 20%
6. Verify warning banner disappears

### Scenario 6: Manual Reconnect
1. Disconnect device (any method)
2. Wait for "Reconnect to Device" button to appear
3. Tap button
4. Verify button shows "Reconnecting..." state
5. Verify device reconnects within 10 seconds
6. Verify button disappears after connection
7. Check connection logged in history

### Scenario 7: Analytics & History
1. Disconnect device 3 times using different methods:
   - Turn off Bluetooth once
   - Power off device once
   - Walk out of range once
2. Tap "Show Connection History"
3. Verify 3 disconnect events logged with correct reasons
4. Tap "Show Analytics"
5. Verify counters show correct numbers
6. Verify most common reason calculated correctly
7. Check percentages add up to 100%

---

## ✅ TEST CHECKLIST

### Quick Validation (30 minutes)
- [ ] App installs and opens successfully
- [ ] Login works correctly
- [ ] Device connects successfully
- [ ] Status indicators show correct states
- [ ] Disconnect detected within 1 minute
- [ ] Notifications appear for disconnects
- [ ] Manual reconnect button works
- [ ] Auto-reconnect works
- [ ] Data sent to backend every 10 minutes

### Full Validation (2 hours)
- [ ] All notification types tested
- [ ] Connection history tracks all events
- [ ] Analytics calculate correctly
- [ ] Low battery warning appears at 20%
- [ ] Bluetooth monitor works
- [ ] Internet monitor works
- [ ] All disconnect scenarios tested
- [ ] Webhooks sent correctly
- [ ] Background operation verified
- [ ] 1-hour stability test passed

---

## 🐛 WHAT TO REPORT

If you find issues, please report:

1. **What feature** was being tested
2. **What you did** (steps to reproduce)
3. **What you expected** to happen
4. **What actually happened** instead
5. **Screenshots or screen recording** if possible
6. **Device model** and Android version
7. **Backend logs** if webhook-related

---

## 📞 SUPPORT

**Questions?** Contact development team with:
- Feature name from this document
- Specific question or issue
- Screenshots if helpful

---

## 🎯 TESTING PRIORITY

### High Priority (Test First)
1. Push notification system
2. Disconnect detection speed
3. Data webhook timing (10 minutes)
4. Auto-reconnect functionality

### Medium Priority (Test Next)
5. Low battery warning
6. Manual reconnect button
7. Status indicators (Bluetooth/Internet)
8. Connection history

### Low Priority (Test Last)
9. Analytics calculations
10. UI color schemes and styling

---

## ✨ SUCCESS CRITERIA

**All tests pass when:**
- Disconnects detected within 1 minute
- Notifications appear for all events
- Data sent to backend every 10 minutes reliably
- Auto-reconnect works consistently
- No app crashes or freezes
- Battery warning appears at 20%
- All status indicators update correctly
- History and analytics show accurate data

---

**Happy Testing! 🎉**
