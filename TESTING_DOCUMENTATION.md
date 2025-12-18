# HC20 SDK Testing Documentation
# Version: 1.0
# Last Updated: December 10, 2025

## Overview

This document provides comprehensive instructions for testing the new HC20 SDK (`hc20_new` v1.0.2) against the current stable SDK (`hc20` v1.0.0) **without breaking any existing functionality**.

---

## What's New in hc20_new (v1.0.2)?

The new SDK includes the following improvements:

### 1. **Auto-Enable Background Sync**
   - Raw sensor data upload starts automatically when device connects
   - No manual intervention needed
   - Continuous data streaming to cloud

### 2. **Auto-Enable Sensors**
   - Sensors (IMU, PPG, GSR) are enabled automatically on connection
   - Eliminates manual sensor activation step
   - Faster time-to-data

### 3. **Development/Production API Toggle**
   - New `Hc20CloudConfig.isDevelopment` flag
   - Switch between dev and production API endpoints
   - Useful for testing before production deployment

### 4. **Improved Raw Sensor Handling**
   - Better logic for disabling/enabling sensors during historical data retrieval
   - Reduces packet loss
   - More reliable data transfer

### 5. **Simplified Authentication**
   - Removed client ID/secret requirements
   - Streamlined OAuth flow

---

## Safe Testing Approach

### Method 1: Manual SDK Switching (Recommended)

#### Step 1: Check Current Configuration
```bash
cd /workspaces/HFC-App
grep -A2 "hc20:" pubspec.yaml
```

You should see:
```yaml
hc20:
  path: ./hc20
```

#### Step 2: Switch to New SDK
Edit `pubspec.yaml` and change:
```yaml
# FROM:
hc20:
  path: ./hc20

# TO:
hc20:
  path: ./hc20_new
```

#### Step 3: Update Dependencies
```bash
flutter pub get
flutter clean  # Recommended to avoid cache issues
```

#### Step 4: Run the App
```bash
flutter run
```

#### Step 5: Test All Features (See Testing Checklist below)

#### Step 6: Rollback if Needed
If you encounter any issues:
```bash
# Restore from backup
cp pubspec.yaml.backup pubspec.yaml
flutter pub get
flutter clean
flutter run
```

---

### Method 2: Using the SDK Switcher Script (Automated)

We've provided a convenient script for switching:

```bash
cd /workspaces/HFC-App
./switch_sdk.sh
```

The script will:
1. Show you the current SDK version
2. Ask if you want to switch
3. Create a timestamped backup
4. Update pubspec.yaml
5. Run flutter pub get
6. Provide next steps

---

## Testing Checklist

### ✅ Essential Features (MUST TEST)

#### 1. Device Connection
- [ ] Scan for HC20 devices
- [ ] Connect to device successfully
- [ ] Verify device ID and MAC address
- [ ] Check connection status indicator

#### 2. Real-Time Data Updates
- [ ] Heart Rate (HR) updates
- [ ] SpO2 updates
- [ ] Blood Pressure (Systolic/Diastolic) updates
- [ ] Temperature updates
- [ ] Battery level displays correctly
- [ ] Steps counter works

#### 3. Automatic Sensor Enabling (NEW SDK ONLY)
- [ ] Sensors enable automatically after connection
- [ ] No manual "Enable Sensors" button press needed
- [ ] Data starts flowing immediately

#### 4. Background Sync (NEW SDK ONLY)
- [ ] Background sync starts automatically on connection
- [ ] Raw sensor data uploads to cloud
- [ ] Check logs for "RawManager started successfully"

#### 5. Webhook Data Transmission
- [ ] Processed data sends to webhook URL
- [ ] Webhook success count increments
- [ ] Check webhook status messages
- [ ] Verify data arrives at backend

#### 6. Historical Data Retrieval
- [ ] Retrieve historical HR data
- [ ] Retrieve historical SpO2 data
- [ ] Retrieve historical BP data
- [ ] Retrieve historical Temperature data
- [ ] Data displays correctly on "All Data" page

#### 7. Time Synchronization
- [ ] Device time syncs with phone
- [ ] Time sync status shows success
- [ ] Timestamp accuracy verified

#### 8. Device Lifecycle
- [ ] Disconnect device gracefully
- [ ] Reconnect device successfully
- [ ] Background sync resumes after reconnection
- [ ] Data continues flowing after reconnection

#### 9. App Lifecycle
- [ ] App works in foreground
- [ ] App continues in background
- [ ] App resumes from background correctly
- [ ] No crashes or memory leaks

#### 10. Error Handling
- [ ] Handle Bluetooth permission denial
- [ ] Handle device out of range
- [ ] Handle low battery scenarios
- [ ] Handle network errors for webhooks

---

### ✅ New SDK Specific Features

#### Auto Background Sync Verification
1. Connect device
2. Check logs for:
   ```
   [HC20Client] Starting RawManager for device: <device_id>
   [HC20Client] RawManager started successfully
   ```
3. Verify raw data uploads in backend/cloud dashboard

#### Auto Sensor Enable Verification
1. Connect device (don't press "Enable Sensors")
2. Check logs for:
   ```
   [HC20Client] Automatically enabling sensors after connection...
   [HC20Client] Sensors enabled automatically on connection
   ```
3. Verify data starts flowing immediately

#### Development/Production Toggle Testing
Add this code to test environment switching:
```dart
// In main.dart or where you initialize HC20
import 'package:hc20/hc20.dart';

// For development testing
Hc20CloudConfig.isDevelopment = true;  // Uses dev API

// For production
Hc20CloudConfig.isDevelopment = false;  // Uses production API
```

---

## Comparison Table

| Feature | Old SDK (v1.0.0) | New SDK (v1.0.2) |
|---------|------------------|------------------|
| Manual Sensor Enable | ✅ Required | ❌ Automatic |
| Background Sync | ❌ Disabled | ✅ Auto-enabled |
| Raw Data Upload | ❌ Disabled | ✅ Enabled |
| Dev/Prod Toggle | ❌ No | ✅ Yes |
| Sensor Disable on Historical Data | ⚠️ Manual | ✅ Automatic |
| Authentication | Complex | ✅ Simplified |

---

## Expected Behavior Changes

### With OLD SDK (v1.0.0):
1. Connect device → Manual enable sensors → Data flows
2. Background sync disabled
3. Raw data upload disabled

### With NEW SDK (v1.0.2):
1. Connect device → **Sensors auto-enable** → Data flows immediately
2. **Background sync starts automatically**
3. **Raw data uploads automatically**

---

## Troubleshooting

### Issue: New SDK doesn't auto-enable sensors
**Solution:**
- Check Bluetooth permissions
- Verify device firmware version
- Check logs for error messages
- Try manual sensor enable as fallback

### Issue: Background sync not starting
**Solution:**
- Verify internet connection
- Check cloud API credentials
- Review RawManager logs
- Verify device MAC address is set

### Issue: Historical data retrieval fails
**Solution:**
- Check device has historical data stored
- Verify date parameters are correct
- Ensure sensors are temporarily disabled during retrieval
- Check for packet loss errors

### Issue: Webhook transmission fails
**Solution:**
- Verify webhook URL is correct
- Check network connectivity
- Review webhook response codes
- Check backend logs

### Issue: App crashes or freezes
**Solution:**
- Run `flutter clean`
- Clear app cache and data
- Rebuild: `flutter run --release`
- Check for null safety issues in logs

---

## Rollback Procedure

If the new SDK causes critical issues:

### Quick Rollback:
```bash
cd /workspaces/HFC-App
cp pubspec.yaml.backup pubspec.yaml
flutter pub get
flutter clean
flutter run
```

### Using Git (if tracked):
```bash
git checkout pubspec.yaml
flutter pub get
flutter clean
flutter run
```

---

## Performance Testing

### Metrics to Monitor:
1. **Connection Time**: Time from scan to first data
2. **Data Latency**: Time from sensor read to display
3. **Battery Usage**: Monitor device battery drain
4. **Memory Usage**: Check for memory leaks
5. **Network Traffic**: Monitor data upload volume
6. **Crash Rate**: Zero crashes expected

---

## Logging and Debugging

### Enable Verbose Logging:
The SDK uses `Hc20CloudConfig.debugPrint()` for logging. Check your console/logcat for:

```
[HC20Client] Connection successful
[HC20Client] Starting RawManager for device: xxx
[HC20Client] RawManager started successfully
[HC20Client] Automatically enabling sensors after connection...
[HC20Client] Sensors enabled automatically on connection
```

### Key Log Messages to Watch:

**Good Signs (New SDK):**
- ✅ "RawManager started successfully"
- ✅ "Sensors enabled automatically on connection"
- ✅ "Background sync active"

**Warning Signs:**
- ⚠️ "Warning: Could not automatically enable sensors"
- ⚠️ "Failed to start RawManager"
- ⚠️ "Connection lost"

---

## Reporting Issues

If you find bugs or issues with the new SDK:

### Information to Collect:
1. SDK version being tested
2. Device firmware version
3. Flutter/Dart version
4. Full error logs
5. Steps to reproduce
6. Expected vs actual behavior
7. Screenshots/videos if applicable

### Log Collection:
```bash
# Android
adb logcat -d > logs.txt

# iOS
xcrun simctl spawn booted log stream > logs.txt
```

---

## Conclusion

This testing framework allows you to:
- ✅ Test new SDK safely without breaking production
- ✅ Easy switching between SDK versions
- ✅ Comprehensive testing checklist
- ✅ Quick rollback if needed
- ✅ Side-by-side comparison

**Remember**: The old SDK (v1.0.0) remains your stable fallback. Only switch to production use of new SDK after thorough testing and validation.

---

## Quick Reference Commands

```bash
# Switch to new SDK
./switch_sdk.sh
# OR manually edit pubspec.yaml: path: ./hc20_new

# Update dependencies
flutter pub get

# Clean build
flutter clean

# Run app
flutter run

# Rollback to old SDK
cp pubspec.yaml.backup pubspec.yaml && flutter pub get

# Check current SDK version
grep -A2 "hc20:" pubspec.yaml
```

---

**For questions or support, refer to:**
- SDK_TESTING_GUIDE.md (this file)
- hc20_new/CHANGELOG.md (version history)
- hc20_new/README.md (SDK documentation)
- docs/hc20-integration.md (integration guide)
