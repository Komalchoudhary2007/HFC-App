# HFC App - AI Agent Instructions

## Project Overview
Flutter mobile app for HC20 wearable health monitoring with stress management for special needs parents. 7-month POC study. Backend-heavy architecture with real-time BLE data streaming and webhook integration.

## Architecture

### Core Navigation Pattern
**CRITICAL**: Single navigation system in `lib/ui/widgets/bottom_navigation_bar.dart` (MainScaffold):
- 4 screens: Home (index 0), Clinical (1), Vitals (2), Device/HC20 (3)
- Default start: Device screen (index 3) - `_currentIndex = 3`
- App bar shows on Home/Clinical/Vitals, hidden on Device (HC20HomePage has own)
- `main.dart` uses `MainScaffold()` directly, NOT duplicate `MainAppWithNavBar`

### HC20 Device Integration
**BLE Connection Lifecycle**:
1. Scan → Connect → Time Sync → Real-time Stream → Background Keep-Alive
2. Main page: `lib/main.dart` → `HC20HomePage` (~4500 lines, includes device management)
3. SDK: `hc20_1.0.4/` (local package, OAuth required: clientId/clientSecret)
4. OAuth config: `Hc20Config(clientId: '...', clientSecret: '...')` - contact dev team for credentials

**Background Execution Strategy** (CRITICAL):
```
Android Native Service (ForegroundService.kt)
    ↓
AlarmManager (5-min keepalive) + WorkManager (15-min backup)
    ↓
Main Engine Keep-Alive (MainEngineKeepAliveService)
    ↓
Webhooks every 5 min (aligned to :00, :05, :10, etc.)
```

**Data Flow**:
```
HC20 Device (BLE) → Flutter App → Native Android Service
                                      ↓
                            Webhook API (2-min intervals)
                                      ↓
                            api.hireforcare.com/webhook/hc20-data
```

### State Management
- **Provider pattern**: AuthService, HC20Service (global state)
- **Local storage**: flutter_secure_storage (tokens), SharedPreferences (device IDs)
- **Real-time updates**: StreamSubscription from `client.realtimeV2(device)`

### Authentication Flow
```dart
// OTP-based login (lib/services/auth_service.dart)
1. sendOTP(phone) → GET /api/users/send-otp
2. verifyOTP(phone, otp) → POST /api/users/verify-otp
3. Token stored in flutter_secure_storage (encrypted)
4. Auto-navigation via Provider<AuthService> in main.dart
```

## Critical Services

### Background Services (Android-Specific)
**Order of Importance**:
1. `MainEngineKeepAliveService` - Keeps Flutter engine alive in background
2. `ForegroundService.kt` - Native Android service (survives app swipe-away)
3. `AppKeepaliveService` - AlarmManager-based (5-min interval)
4. `BackgroundSyncService` - WorkManager (15-min fallback)

**Key Methods**:
- `_startMainEngineKeepAlive()` - Call when app goes to background
- `_stopMainEngineKeepAlive()` - Call when app resumes foreground
- Always add `@pragma('vm:entry-point')` to methods called from native code

### Webhook Implementation
```dart
// lib/main.dart (~line 1600-1800)
static const String _webhookUrl = 'https://api.hireforcare.com/webhook/hc20-data';

// Timer aligns to 5-minute marks (:00, :05, :10, etc.)
_dataRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
  // Send device data OR null values with error type if disconnected
});
```

## Key File Locations

### UI Layer
```
lib/ui/
├── screens/          # Main app screens
│   ├── home_screen.dart         # Dashboard (Purple UI, 8 sections)
│   ├── clinical_screen.dart     # Placeholder
│   ├── vitals_screen.dart       # Placeholder
│   └── connectivity_screen.dart # Placeholder redirect
├── widgets/
│   ├── bottom_navigation_bar.dart  # SINGLE navigation system
│   ├── app_top_bar.dart           # Top bar with logo + device status
│   └── side_drawer.dart           # Navigation drawer
└── core/constants/
    ├── app_colors.dart      # Brand colors (#532A7B purple)
    └── app_text_styles.dart # Typography system
```

### Services Layer
```
lib/services/
├── auth_service.dart              # Login/OTP/token management
├── api_service.dart               # REST API client (Dio)
├── hc20_service.dart              # Global HC20 connection state
├── storage_service.dart           # Secure storage wrapper
├── app_keepalive_service.dart     # AlarmManager keepalive
├── main_engine_keepalive_service.dart  # Flutter engine keepalive
└── background_sync_service.dart   # WorkManager backup
```

### Native Android
```
android/app/src/main/kotlin/com/example/hfc_app/
├── MainActivity.kt           # Platform channel bridge
├── ForegroundService.kt      # Native BLE + webhook service
├── SyncAlarmReceiver.kt      # AlarmManager receiver
└── AppRestartWorker.kt       # WorkManager worker
```

## Development Workflow

### Running the App
```bash
# Install dependencies
flutter pub get

# Run on emulator
flutter run -d emulator-5554

# Run on wireless device (after pairing)
export PATH="/Users/developer/Library/Android/sdk/platform-tools:$PATH"
adb connect 192.168.1.X:XXXXX
flutter run -d 192.168.1.X:XXXXX

# Build release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Testing Devices
- **Emulator**: sdk gphone64 arm64 (emulator-5554)
- **Real device**: Wireless ADB (see README.md for pairing steps)
- **Default start**: Device screen shows immediately (HC20 connection)

### Hot Reload Caveat
Pressing 'q' in `flutter run` disconnects terminal but app KEEPS RUNNING. BLE subscriptions try sending to detached Flutter → warnings spam (cosmetic, no functional impact).

## Common Patterns

### Adding New Screen with App Bar
```dart
// 1. Create screen without Scaffold
class NewScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(  // NOT Scaffold!
      child: Column(children: [...])
    );
  }
}

// 2. Add to bottom_navigation_bar.dart
final List<Widget> _screens = [
  const HomeScreen(),
  const NewScreen(),  // Add here
  // ...
];

// 3. AppTopBar shows automatically (unless you hide it conditionally)
```

### Provider Usage
```dart
// Access auth state
final authService = Provider.of<AuthService>(context, listen: false);
final user = authService.currentUser;

// Access HC20 state
final hc20Service = Provider.of<HC20Service>(context);
final isConnected = hc20Service.isConnected;
```

### Platform Channel Calls
```dart
// Always wrap in try-catch
const platform = MethodChannel('com.hfc.app/background');
try {
  await platform.invokeMethod('startNativeBleService', {
    'deviceAddress': deviceId,
    'userPhone': userPhone,
  });
} catch (e) {
  print('⚠️ Platform channel error: $e');
}
```

## Known Issues & Fixes

### 1. AOT Entry Point (Release Builds)
**Problem**: Methods called from native code get tree-shaken in release builds.
**Fix**: Add `@pragma('vm:entry-point')` to all methods/classes called from Kotlin/Java.
```dart
@pragma('vm:entry-point')
class AppKeepaliveService {
  @pragma('vm:entry-point')
  static void markAppActive() { /* ... */ }
}
```

### 2. BLE Scan Leak Warnings
**Problem**: Scan subscription not cancelled → warnings after 'q' in dev.
**Fix**: Cancel `_scanSubscription` after connection succeeds or in dispose():
```dart
Future<void> _connectToDevice(String deviceId) async {
  _scanSubscription?.cancel();  // Stop manual scan
  // ... connection logic
}
```

### 3. HTTP Connection Leak (OkHttp)
**Problem**: Dio responses not fully consumed.
**Fix**: Ensure `response.data` is accessed to trigger full read.

## Best Practices

### DO
- Use `MainScaffold` for navigation (single source of truth)
- Add `@pragma('vm:entry-point')` for native-called code
- Cancel BLE scans after connection
- Use `flutter_secure_storage` for tokens
- Test release builds before production

### DON'T
- Create multiple navigation systems (causes confusion)
- Use `Scaffold` in screen widgets (MainScaffold provides it)
- Forget to handle BLE disconnections
- Hardcode OAuth credentials (use env vars in production)
- Skip battery optimization permission checks on Android

## API Integration

### Base URL
`https://api.hireforcare.com/api`

### Key Endpoints
```dart
POST /users/send-otp         // Send OTP
POST /users/verify-otp       // Login/Register
POST /devices/associate      // Link device to user
POST /webhook/hc20-data      // Upload health data (called by native service)
```

### Example Usage
```dart
// lib/api_usage_examples.dart has 13+ examples
final apiService = ApiService();
final response = await apiService.associateDevice(
  deviceId, userId, deviceName: 'HC20'
);
```

## Documentation

- **Main docs**: `/docs/` (QUICK_START.md, API_DOCUMENTATION.md, etc.)
- **Issues**: `/docs/future-implementations/ISSUES_TO_FIX.md`
- **HC20 SDK**: `/hc20_1.0.4/README.md`
- **Setup**: `SETUP_CHECKLIST.md`
- **Build guide**: `README.md` (wireless ADB pairing steps)

## Color Scheme
Primary: `#532A7B` (purple)  
Secondary: `#ff6158` (light red)  
Background: `#E7E2FD` (light purple)  
Card: `#F8F1F9` (off-white)  
Success: `#1DB50F` (green)  
Error: `#FF5F5A` (red)

## Questions to Ask User
When unclear about implementation, ask:
1. Should this work in background when app is closed?
2. Does this need to survive phone reboot?
3. Is this a debug feature or production requirement?
4. Should OAuth credentials come from environment variables?
5. Does this need to be synced to backend API?
