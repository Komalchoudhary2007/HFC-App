# HFC App v1.5.1 - Crash Fix

## Problem
The app was crashing immediately after installation with "keeps stopping" error.

## Root Cause
The app was trying to initialize the HC20 client during app startup (in `initState()`) with placeholder OAuth credentials:
```dart
clientId: 'your-client-id',
clientSecret: 'your-client-secret',
```

The HC20 SDK validates these credentials and throws an error when they are invalid, causing the app to crash before the UI even appears.

## Solution
Changed the initialization strategy to **lazy loading**:

### Before (v1.5.0)
```dart
@override
void initState() {
  super.initState();
  _initializeDio();
  _initializeHC20Client();  // ❌ Crashes here with invalid credentials
  _initializeBackgroundService();
}
```

### After (v1.5.1)
```dart
@override
void initState() {
  super.initState();
  _initializeDio();
  _initializeBackgroundService();
  // HC20 client initializes when user clicks "Start Scanning"
}

void _startScanning() async {
  // Initialize client on-demand
  if (_client == null) {
    await _initializeHC20Client();
    if (_client == null) {
      setState(() {
        _statusMessage = 'Failed to initialize. Check OAuth credentials.';
      });
      return;
    }
  }
  // ... continue scanning
}
```

## Changes Made

1. **Removed automatic initialization** - HC20 client no longer initializes on app startup
2. **Added lazy initialization** - Client initializes only when user clicks "Start Scanning"
3. **Improved error handling** - If initialization fails, app shows error message instead of crashing
4. **Better user feedback** - Status message explains OAuth credential requirement

## Benefits

✅ **App starts successfully** - No more crashes on launch  
✅ **Graceful failure** - Invalid credentials show error message, not crash  
✅ **Better UX** - User can see the app interface even with invalid credentials  
✅ **Easier debugging** - Error messages guide users to get valid credentials  

## Testing

1. Install the APK
2. App should open without crashing
3. You'll see: "Click 'Start Scanning' to search for HC20 devices"
4. Click "Start Scanning"
5. If credentials are invalid, you'll see: "Failed to initialize. Check OAuth credentials."
6. If credentials are valid, scanning will begin normally

## Next Steps

To fully use the app, you need to replace the placeholder OAuth credentials in `lib/main.dart` and `lib/services/background_service.dart`:

```dart
// Replace these lines:
clientId: 'your-client-id',
clientSecret: 'your-client-secret',

// With actual credentials from HC20 dev team:
clientId: 'actual-client-id-from-dev-team',
clientSecret: 'actual-client-secret-from-dev-team',
```

Then rebuild the APK:
```bash
flutter build apk --release --no-tree-shake-icons
```

## Build Information

- **Version:** 1.5.1 - Crash Fix
- **Build Date:** December 6, 2025 7:18 PM
- **File Size:** 47 MB
- **Download:** Access via HTTP server on port 9000

## Files Modified

- `lib/main.dart` - Changed initialization strategy, added lazy loading
- `download.html` - Updated version info and features list
- `CRASH_FIX_v1.5.1.md` - This document
