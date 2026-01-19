# 🔧 Webhook Configuration

## ⏱️ Webhook Interval Settings

### Current Configuration: **2 MINUTES (Testing Mode)**

**Location:** `android/app/src/main/kotlin/com/example/hfc_app/ForegroundService.kt`

```kotlin
private const val WEBHOOK_INTERVAL_MS = 120000L // 2 minutes
```

---

## 📝 Configuration Change History

| Date | Interval | Reason | Status |
|------|----------|--------|--------|
| 2026-01-16 | **2 minutes** | Testing mode - faster feedback for debugging | ✅ CURRENT |
| Future | **10 minutes** | Production mode - reduce server load | ⏳ PLANNED |

---

## 🔄 How to Change Webhook Interval

### Option 1: Quick Change (Rebuild Required)

Edit the file: [`android/app/src/main/kotlin/com/example/hfc_app/ForegroundService.kt`](android/app/src/main/kotlin/com/example/hfc_app/ForegroundService.kt )

**Line 58:**
```kotlin
// Testing: Send webhook every 2 minutes
private const val WEBHOOK_INTERVAL_MS = 120000L // 2 minutes

// Production: Send webhook every 10 minutes
// private const val WEBHOOK_INTERVAL_MS = 600000L // 10 minutes
```

Then rebuild APK:
```bash
bash build_and_serve.sh
```

---

## 📊 Recommended Intervals

### Testing Mode ✅ (Current)
- **Interval:** 2 minutes (120000ms)
- **Use Case:** Development, debugging, verification
- **Battery Impact:** Moderate
- **Server Load:** Higher (acceptable for testing)
- **Benefit:** Quick feedback on data transmission issues

### Production Mode 🚀 (Recommended After Testing)
- **Interval:** 10 minutes (600000ms)
- **Use Case:** Normal operation, deployed to users
- **Battery Impact:** Low
- **Server Load:** Lower
- **Benefit:** Better battery life, reduced server costs

### High Frequency Mode ⚡ (Not Recommended)
- **Interval:** 1 minute (60000ms)
- **Use Case:** Critical monitoring scenarios only
- **Battery Impact:** High
- **Server Load:** Very high
- **Benefit:** Near real-time updates

---

## 🔍 Other Timing Configurations

### Flutter Real-time Stream (Updated for Testing)
**Location:** `lib/main.dart`

```dart
// Timer interval: 120 seconds (2 minutes) - TESTING MODE
// Production should be: 600 seconds (10 minutes)
_dataRefreshTimer = Timer.periodic(const Duration(seconds: 120), ...);
```

**Lines to change:**
- Line ~1273: Print message showing interval
- Line ~1280: `const Duration(seconds: 120)` → Change to `600` for production
- Line ~1384: Print message showing interval

### WorkManager Sync (Keepalive)
**Location:** `lib/services/background_sync_service.dart`

```dart
// Minimum interval on Android: 15 minutes
// WorkManager is only for keepalive, NOT for data sending
```

### Flutter Real-time Stream
**Location:** `lib/main.dart`

```dart
// Sends data IMMEDIATELY when received from HC20 device
// No interval - event-driven
// Only works when app is open
```

---

## ⚠️ Important Notes

1. **Native Service Webhook:**
   - Runs every 2 minutes (current setting)
   - Works even when app is closed
   - Sends last known data + connection status
   - **This is the primary background data sender**

2. **Flutter Webhook:**
   - Sends immediately on data receipt
   - Only works when app is open
   - Sends fresh real-time data
   - **This is for live monitoring**

3. **WorkManager:**
   - Runs every 15 minutes (Android minimum)
   - Only keeps service alive
   - **Does NOT send data anymore** (disabled in previous fixes)

---

## 🎯 Production Checklist

Before deploying to production, change these settings:

- [ ] Update webhook interval to 10 minutes (600000ms)
- [ ] Test on physical device for 24 hours
- [ ] Verify battery consumption is acceptable
- [ ] Check server load and costs
- [ ] Remove any debug logging from production build
- [ ] Update this document with actual production settings

---

**Current Status:** ✅ **TESTING MODE (2 minutes)**  
**Next Action:** Change to 10 minutes after successful testing  
**Last Updated:** 2026-01-16
