# Main.dart - Initialization & Setup Documentation

**Part 2 of 7**  
**Last Updated:** January 9, 2026  
**File:** `lib/main.dart` (Lines 113-445)

---

## Table of Contents
1. [Initialization Overview](#initialization-overview)
2. [initState() Method](#initstate-method)
3. [Background Execution Setup](#background-execution-setup)
4. [Battery Optimization](#battery-optimization)
5. [Dio HTTP Client Setup](#dio-http-client-setup)
6. [HC20 Client Initialization](#hc20-client-initialization)
7. [Permissions Request](#permissions-request)
8. [Lifecycle Management](#lifecycle-management)

---

## Initialization Overview

The initialization process happens in **4 phases**:

```
Phase 1: Widget Lifecycle Setup
   └── Add app lifecycle observer
   └── Register dispose handlers

Phase 2: Service Initialization
   └── Initialize Dio HTTP client
   └── Enable background execution
   └── Check battery optimization

Phase 3: Device Management
   └── Load saved device ID
   └── Start auto-reconnect scanner

Phase 4: User Interaction
   └── HC20 client created on first scan
   └── Bluetooth permissions requested
```

---

## initState() Method

**Location:** Lines 113-121  
**Called:** Once when widget is created

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);        // Monitor app lifecycle
  _initializeDio();                                 // Setup HTTP client
  _enableBackgroundExecution();                     // Start foreground service
  _checkAndShowBatteryOptimizationDialog();        // Request permission
  _loadSavedDevice();                              // Load last device
  // Note: HC20 client initialized when user clicks scan
}
```

### Initialization Order
The order is **critical** for proper functionality:

1. ✅ **Lifecycle Observer** - Must be first to monitor app state
2. ✅ **Dio Client** - Needed for webhooks and API calls
3. ✅ **Background Service** - Must start before device connection
4. ✅ **Battery Optimization** - User experience improvement
5. ✅ **Saved Device** - Auto-reconnect preparation
6. ⏳ **HC20 Client** - Lazy initialization (on first scan)

---

## Background Execution Setup

**Location:** Lines 148-157  
**Purpose:** Keep app alive when minimized

### Android Native Implementation

```dart
Future<void> _enableBackgroundExecution() async {
  try {
    const platform = MethodChannel('com.hfc.app/background');
    await platform.invokeMethod('enableBackgroundExecution');
    print('✅ Background execution enabled');
  } catch (e) {
    print('⚠️ Could not enable background execution: $e');
  }
}
```

### What Happens on Android Side

```kotlin
// MainActivity.kt
when (call.method) {
    "enableBackgroundExecution" -> {
        // 1. Start Foreground Service
        val serviceIntent = Intent(this, ForegroundService::class.java)
        ContextCompat.startForegroundService(this, serviceIntent)
        
        // 2. Acquire Wake Lock
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "HFCApp::BackgroundLock"
        )
        wakeLock?.acquire()
        
        result.success(true)
    }
}
```

### Why This Is Needed

| Without Background Service | With Background Service |
|---------------------------|-------------------------|
| ❌ App killed after 5-10 min | ✅ App runs indefinitely |
| ❌ Timers stop | ✅ Timers continue |
| ❌ BLE disconnects | ✅ BLE stays connected |
| ❌ No webhooks sent | ✅ Webhooks every 2 min |
| ❌ Auto-reconnect stops | ✅ Auto-reconnect works |

---

## Battery Optimization

**Location:** Lines 161-320  
**Purpose:** Prevent Android from killing app to save battery

### Flow Diagram

```
App Starts
   │
   ▼
Check Battery Optimization Status
   │
   ├─── Disabled ──→ Continue normally
   │
   └─── Enabled ──→ Show Permission Dialog
                        │
                        ▼
                   User Clicks "Open Settings"
                        │
                        ▼
                   Android Settings Opens
                        │
                        ▼
                   User Disables Optimization
                        │
                        ▼
                   App Checks Status Again
                        │
                        └──→ Confirmed Disabled
```

### Check Battery Optimization

```dart
Future<void> _checkAndShowBatteryOptimizationDialog() async {
  try {
    const platform = MethodChannel('com.hfc.app/background');
    
    // Check current status
    final isDisabled = await platform.invokeMethod('isBatteryOptimizationDisabled');
    
    setState(() {
      _isBatteryOptimizationDisabled = isDisabled;
    });
    
    if (isDisabled) {
      print('✅ Battery optimization already disabled');
    } else {
      // Show dialog to user
      _showBatteryOptimizationPermissionDialog();
    }
  } catch (e) {
    print('⚠️ Could not check battery optimization: $e');
  }
}
```

### Permission Dialog

```dart
void _showBatteryOptimizationPermissionDialog() {
  if (!mounted) return;
  
  showDialog(
    context: context,
    barrierDismissible: false,  // User must take action
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Background Monitoring Required'),
        content: Text(
          'To continuously monitor your health, this app needs to run in the background.\n\n'
          'Please disable battery optimization for this app.'
        ),
        actions: [
          TextButton(
            child: Text('Open Settings'),
            onPressed: () {
              Navigator.of(context).pop();
              _requestBatteryOptimizationExemption();
            },
          ),
        ],
      );
    },
  );
}
```

### Android Implementation

```kotlin
// MainActivity.kt
"isBatteryOptimizationDisabled" -> {
    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
    val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)
    result.success(isIgnoring)
}

"requestBatteryOptimizationExemption" -> {
    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
    intent.data = Uri.parse("package:$packageName")
    startActivity(intent)
    result.success(true)
}
```

### ⚠️ Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Dialog shows repeatedly | Status not updating | Add 3s delay before recheck |
| Settings don't open | Wrong intent | Use ACTION_REQUEST_IGNORE |
| Permission denied | User declined | Show educational message |
| Optimization re-enables | System update/reset | Check on every app start |

---

## Dio HTTP Client Setup

**Location:** Lines 377-396  
**Purpose:** Configure HTTP client for API calls

```dart
void _initializeDio() {
  _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));
  
  // Add logging interceptor for debugging
  _dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    error: true,
    logPrint: (obj) => print('🌐 Dio Log: $obj'),
  ));
}
```

### Configuration Explained

| Setting | Value | Why |
|---------|-------|-----|
| **connectTimeout** | 30s | Max time to establish connection |
| **receiveTimeout** | 30s | Max time to receive response |
| **sendTimeout** | 30s | Max time to send request |
| **Content-Type** | application/json | Sending JSON data |
| **Accept** | application/json | Expecting JSON response |

### Logging Interceptor

The interceptor logs:
- ✅ Request URL and method
- ✅ Request headers and body
- ✅ Response status and data
- ✅ Error details

**Example Log:**
```
🌐 Dio Log: *** Request ***
uri: https://api.hireforcare.com/webhook/hc20-data
method: POST
data: {"timestamp":"2026-01-09T08:00:00.000+05:30","device":{"id":"HC20-1234"}}
*** End Request ***

🌐 Dio Log: *** Response ***
statusCode: 200
data: {"success":true,"message":"Data received"}
*** End Response ***
```

---

## HC20 Client Initialization

**Location:** Lines 398-428  
**When:** First time user clicks "Start Scanning"  
**Why Lazy:** Avoids OAuth errors if credentials not configured

```dart
Future<void> _initializeHC20Client() async {
  try {
    setState(() {
      _statusMessage = 'Initializing HC20 client...';
    });

    // Step 1: Request Bluetooth permissions
    await _requestPermissions();

    // Step 2: Create HC20 client with OAuth credentials
    _client = await Hc20Client.create(
      clientId: 'YOUR_CLIENT_ID',         // From Nitto
      clientSecret: 'YOUR_CLIENT_SECRET', // From Nitto
      // These enable cloud upload to Nitto servers
    );

    setState(() {
      _statusMessage = 'HC20 client initialized. Ready to scan!';
    });
    
    print('✓ HC20 client initialized successfully');
  } catch (e) {
    print('❌ HC20 client initialization error: $e');
    setState(() {
      _statusMessage = 'Error: Invalid OAuth credentials. Contact dev team.';
    });
    _client = null;  // Ensure client is null on error
  }
}
```

### Initialization Flow

```
User Clicks "Start Scanning"
   │
   ▼
Check if _client == null
   │
   ├─── Not null ──→ Start scanning immediately
   │
   └─── Null ──→ Initialize HC20 Client
                    │
                    ├─→ Request Bluetooth Permissions
                    │      │
                    │      ├─→ Bluetooth
                    │      ├─→ BluetoothConnect
                    │      ├─→ BluetoothScan
                    │      └─→ Location (Android requirement)
                    │
                    ├─→ Create Hc20Client
                    │      │
                    │      ├─→ Validate OAuth credentials
                    │      ├─→ Initialize BLE manager
                    │      └─→ Setup RawManager (cloud upload)
                    │
                    └─→ Start scanning for devices
```

### ⚠️ OAuth Credentials

**CRITICAL:** The `clientId` and `clientSecret` are provided by **Nitto Corporation** (HC20 manufacturer).

**Without valid credentials:**
- ❌ Client creation fails
- ❌ Cannot connect to devices
- ❌ Cloud upload won't work

**To get credentials:**
1. Contact Nitto sales/support
2. Sign NDA if required
3. Register your app
4. Receive OAuth keys

---

## Permissions Request

**Location:** Lines 430-443  
**Purpose:** Request Android permissions for BLE

```dart
Future<void> _requestPermissions() async {
  final permissions = [
    Permission.bluetooth,           // Basic BLE access
    Permission.bluetoothConnect,    // Connect to devices (Android 12+)
    Permission.bluetoothScan,       // Scan for devices (Android 12+)
    Permission.location,            // Required for BLE scanning
  ];

  for (final permission in permissions) {
    final status = await permission.request();
    if (status != PermissionStatus.granted) {
      print('❌ Permission denied: $permission');
      // Continue anyway - some permissions optional
    }
  }
}
```

### Android Version Differences

| Android Version | Permissions Needed |
|----------------|-------------------|
| **Android 11 and below** | Bluetooth + Location |
| **Android 12+** | Bluetooth + BluetoothScan + BluetoothConnect + Location |

### Why Location Permission?

Android requires location permission for BLE scanning because:
- Bluetooth can be used to determine approximate location
- Privacy protection measure
- Mandatory even if you don't use location features

### Permission States

```dart
PermissionStatus.granted      // ✅ User approved
PermissionStatus.denied       // ❌ User declined
PermissionStatus.restricted   // 🔒 System blocked
PermissionStatus.permanentlyDenied // 🚫 User said "Don't ask again"
```

---

## Lifecycle Management

**Location:** Lines 322-376  
**Purpose:** Handle app state changes

### States Explained

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  super.didChangeAppLifecycleState(state);
  print('📱 App lifecycle state changed: $state');
  
  switch (state) {
    case AppLifecycleState.resumed:
      // App in foreground
      print('✅ App resumed - user returned to app');
      // No action needed - background service handles everything
      break;
      
    case AppLifecycleState.paused:
      // App in background
      print('⏸️  App paused - moved to background');
      // Keep everything running via foreground service
      break;
      
    case AppLifecycleState.inactive:
      // Transitional state
      print('⏳ App inactive - temporary state');
      break;
      
    case AppLifecycleState.detached:
      // App being destroyed
      print('🔴 App detached - app closing');
      break;
      
    case AppLifecycleState.hidden:
      // iOS specific
      print('👻 App hidden');
  }
}
```

### State Transitions

```
User Behavior              →  App State
──────────────────────────────────────────
Opens app                  →  resumed
Presses Home button        →  paused
Switches to another app    →  paused
Returns to app             →  resumed
Swipes up to close        →  detached
Notification shows         →  inactive
```

### Cleanup on Dispose

```dart
@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _realtimeSubscription?.cancel();
  _dataRefreshTimer?.cancel();
  _connectionMonitor?.cancel();
  _hrvRefreshTimer?.cancel();
  _autoReconnectScanner?.cancel();
  _disableBackgroundExecution();
  super.dispose();
}
```

**Why cleanup is important:**
- Prevents memory leaks
- Stops unnecessary timers
- Releases Bluetooth resources
- Stops foreground service

---

## Common Errors & Solutions

### Error 1: PlatformException
```
PlatformException(error, Method not implemented, null, null)
```
**Cause:** Native Android code not implemented  
**Solution:** Check MainActivity.kt has all MethodChannel handlers

### Error 2: OAuth Invalid
```
❌ HC20 client initialization error: Invalid credentials
```
**Cause:** Wrong clientId/clientSecret  
**Solution:** Contact Nitto for correct credentials

### Error 3: Permission Denied
```
❌ Permission denied: Permission.bluetoothScan
```
**Cause:** User declined Bluetooth permission  
**Solution:** Show explanation dialog and request again

### Error 4: Battery Optimization
```
⚠️ Could not check battery optimization: null
```
**Cause:** Method not implemented or wrong Android version  
**Solution:** Check MainActivity.kt and test on Android 6+

---

## Best Practices

### ✅ DO
- Initialize services in order (lifecycle → HTTP → background → device)
- Handle errors gracefully with try-catch
- Show user-friendly error messages
- Clean up resources in dispose()
- Test on multiple Android versions
- Log important events for debugging

### ❌ DON'T
- Initialize HC20 client in initState() (lazy init better)
- Ignore permission errors
- Skip battery optimization check
- Forget to cancel timers
- Use hardcoded credentials (use config file)
- Block UI thread with long operations

---

## Recommendations

### 🎯 Improvement 1: Config File
**Current:** Credentials hardcoded  
**Better:** Load from `assets/config.json`

```dart
Future<void> _loadConfig() async {
  final jsonString = await rootBundle.loadString('assets/config.json');
  final config = jsonDecode(jsonString);
  _clientId = config['clientId'];
  _clientSecret = config['clientSecret'];
}
```

### 🎯 Improvement 2: Permission Rationale
**Current:** Direct permission request  
**Better:** Show explanation first

```dart
if (!await Permission.bluetoothScan.isGranted) {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Bluetooth Permission'),
      content: Text('We need Bluetooth to connect to your HC20 device'),
      actions: [/* ... */],
    ),
  );
}
```

### 🎯 Improvement 3: Error Reporting
**Current:** Print to console  
**Better:** Send to crash analytics

```dart
try {
  await _initializeHC20Client();
} catch (e, stackTrace) {
  FirebaseCrashlytics.instance.recordError(e, stackTrace);
  // Also show to user
}
```

---

## Next Steps

Continue to Part 3 for device connection and scanning:

📄 **[Part 3: Device Connection Flow →](03_DEVICE_CONNECTION_FLOW.md)**

---

**End of Part 2**  
**Previous: [Part 1 - Overview](01_OVERVIEW_AND_ARCHITECTURE.md)**  
**Next: [Part 3 - Device Connection](03_DEVICE_CONNECTION_FLOW.md)**
