# Main.dart - Overview & Architecture Documentation

**Part 1 of 7**  
**Last Updated:** January 9, 2026  
**File:** `lib/main.dart`

---

## Table of Contents
1. [Introduction](#introduction)
2. [File Structure Overview](#file-structure-overview)
3. [Architecture Diagram](#architecture-diagram)
4. [State Variables](#state-variables)
5. [Dependencies](#dependencies)
6. [App Initialization Flow](#app-initialization-flow)

---

## Introduction

The `main.dart` file is the **core of the HFC (Hire For Care) mobile application**. It handles:

- 🏥 **Healthcare Device Integration**: Connects to HC20 wearable health monitoring devices via Bluetooth
- 📊 **Real-time Data Collection**: Streams vital signs (heart rate, SpO2, blood pressure, temperature)
- 🌐 **Backend Communication**: Sends health data to backend API via webhooks
- 🔄 **Auto-Reconnection**: Automatically reconnects to devices when connection is lost
- 🔋 **Background Execution**: Continues monitoring even when app is minimized
- 👤 **User Authentication**: Integrates with login system and associates devices with users

### Purpose
This app is designed for **continuous health monitoring** of patients/users, ensuring caregivers receive real-time health data and disconnect alerts.

---

## File Structure Overview

```
lib/main.dart (2,779 lines)
├── Imports (Lines 1-16)
├── main() function (Lines 18-30)
├── MyApp widget (Lines 32-54)
├── HC20HomePage widget (Lines 56-64)
└── _HC20HomePageState class (Lines 66-2779)
    ├── State Variables (Lines 68-111)
    ├── Initialization Methods (Lines 113-320)
    ├── Bluetooth & Device Methods (Lines 400-690)
    ├── Data Streaming (Lines 747-960)
    ├── Auto-Reconnection (Lines 990-1383)
    ├── Webhook & API Methods (Lines 1084-1270)
    ├── Testing & Utilities (Lines 1386-1762)
    └── UI Build Method (Lines 1764-2779)
```

### Line Count Breakdown
| Section | Lines | Purpose |
|---------|-------|---------|
| State Management | ~50 | Variables for connection, data, timers |
| Initialization | ~200 | Setup, permissions, background service |
| Bluetooth/Device | ~300 | Scanning, connecting, syncing |
| Data Streaming | ~200 | Real-time data, webhooks, monitoring |
| Auto-Reconnect | ~400 | Background scanning, reconnection logic |
| UI | ~1000 | User interface, buttons, data display |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         HFC Mobile App                          │
│                         (main.dart)                             │
└────────────────────────┬────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ AuthService  │  │ ApiService   │  │StorageService│
│ (Login/User) │  │ (Backend API)│  │ (Local Data) │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       │                 │                 │
       └─────────────────┴─────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   HC20 SDK   │  │Android Native│  │  Backend API │
│  (Bluetooth) │  │   Platform   │  │   (Webhook)  │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ HC20 Device  │  │   Battery    │  │   Database   │
│  (Wearable)  │  │Optimization  │  │   (Cloud)    │
└──────────────┘  └──────────────┘  └──────────────┘
```

### Data Flow

```
User Opens App
      │
      ▼
Check Authentication (AuthService)
      │
      ├─── Not Logged In ──→ Show Login Page
      │
      └─── Logged In ──→ Show HC20HomePage
                              │
                              ▼
                    Initialize Background Service
                              │
                              ▼
                    Check Battery Optimization
                              │
                              ▼
                    Load Saved Device (if any)
                              │
                              ▼
                    Start Auto-Reconnect Scanner
                              │
                              ▼
                    User Clicks "Start Scanning"
                              │
                              ▼
                    Scan for HC20 Devices (30s)
                              │
                              ▼
                    User Selects Device
                              │
                              ▼
                    Connect to Device
                              │
                              ├─── Sync Time
                              ├─── Set User Parameters
                              ├─── Associate with User Account
                              └─── Start Data Streaming
                                      │
                                      ▼
                              Real-time Data Stream
                                      │
                              ┌───────┴───────┐
                              │               │
                              ▼               ▼
                      Update UI      Send to Webhook (Every 2 min)
                                              │
                                              ▼
                                      Backend Stores Data
```

---

## State Variables

The `_HC20HomePageState` class contains **~50 state variables** organized into categories:

### 1. **Connection State** (Lines 68-75)
```dart
Hc20Client? _client;                    // HC20 SDK client instance
Hc20Device? _connectedDevice;           // Currently connected device
bool _isScanning = false;               // Is BLE scan active?
bool _isConnected = false;              // Is device connected?
List<Hc20Device> _discoveredDevices;    // Found devices during scan
String _statusMessage;                   // UI status text
```

**Purpose:** Track Bluetooth connection state and discovered devices.

---

### 2. **Webhook Configuration** (Lines 77-80)
```dart
late final Dio _dio;                                          // HTTP client
static const String _webhookUrl = 'https://api.hireforcare.com/webhook/hc20-data';
int _webhookSuccessCount = 0;                                 // Success counter
int _webhookErrorCount = 0;                                   // Error counter
```

**Purpose:** Manage HTTP requests to backend API for health data delivery.

---

### 3. **Time Sync Info** (Lines 82-87)
```dart
String _lastTimeSyncStatus = 'Not synced yet';
DateTime? _lastTimeSyncTime;
String _lastWebhookStatus = '';
String _lastWebhookError = '';
DateTime? _lastWebhookTime;
```

**Purpose:** Track device time synchronization and webhook status for debugging.

---

### 4. **Real-time Health Data** (Lines 89-100)
```dart
int? _heartRate;                        // BPM (beats per minute)
int? _spo2;                             // Blood oxygen % (0-100)
List<int>? _bloodPressure;              // [systolic, diastolic]
double? _temperature;                   // Body temp in °C
int? _batteryLevel;                     // Device battery % (0-100)
int? _steps;                            // Daily step count
bool _stressAlertPending = false;       // Emergency alert flag

// Timers and Subscriptions
StreamSubscription? _realtimeSubscription;  // BLE data stream
Timer? _dataRefreshTimer;                   // 2-minute webhook timer
Timer? _connectionMonitor;                  // 30s connection check
Timer? _hrvRefreshTimer;                    // 6-hour HRV data fetch
Timer? _autoReconnectScanner;               // 30s background scan
DateTime? _lastDataReceived;                // Last data timestamp
```

**Purpose:** Store latest health metrics and manage timers for periodic tasks.

---

### 5. **Auto-Reconnect State** (Lines 102-109)
```dart
String? _savedDeviceId;                 // Saved device for auto-connect
bool _isAutoReconnecting = false;       // Background scan in progress?
DateTime? _lastHrvRefresh;              // Last HRV data fetch time
bool _isReconnecting = false;           // Manual reconnect in progress?
int _reconnectAttempts = 0;             // Current retry count
static const int _maxReconnectAttempts = 3;  // Max retries before giving up
bool _isBatteryOptimizationDisabled = false; // Battery permission status
```

**Purpose:** Manage automatic reconnection attempts when device disconnects.

---

### 6. **Services** (Lines 111)
```dart
final ApiService _apiService = ApiService();   // Backend API calls
bool _isDeviceAssociated = false;              // Device linked to user?
```

**Purpose:** Service instances for API communication and device association.

---

## Dependencies

### Flutter/Dart Packages
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Bluetooth & Device
  hc20: ^1.0.4                    # HC20 wearable SDK
  permission_handler: ^10.0.0     # Android/iOS permissions
  
  # HTTP & Networking
  dio: ^5.0.0                     # HTTP client
  
  # State Management
  provider: ^6.0.0                # State management
  
  # Local Storage
  flutter_secure_storage: ^8.0.0  # Secure local storage
```

### Native Platform Features
```kotlin
// Android (MainActivity.kt)
- Foreground Service (Background execution)
- Wake Lock (Keep CPU awake)
- Battery Optimization Exemption
- Bluetooth Low Energy (BLE)
```

---

## App Initialization Flow

### Step-by-Step Startup Process

```
1. main() function executes
   └── WidgetsFlutterBinding.ensureInitialized()
   └── Initialize AuthService
   └── Wait 1 second (auth check)
   └── Wrap app in ChangeNotifierProvider
   └── Run MyApp widget

2. MyApp builds
   └── Create MaterialApp
   └── Use Consumer<AuthService>
   └── Check if user logged in
       ├── Yes → Show HC20HomePage
       └── No  → Show LoginPage

3. HC20HomePage initState() runs
   └── Add lifecycle observer
   └── Initialize Dio HTTP client
   └── Enable background execution (native)
   └── Check battery optimization permission
   └── Load saved device ID
   └── Start auto-reconnect scanner (if device saved)

4. User sees home screen
   └── "Start Scanning" button ready
   └── Status message displayed
   └── Battery optimization dialog (if not disabled)
```

### Code Flow Diagram

```
main()
  │
  ├─→ WidgetsFlutterBinding.ensureInitialized()
  │
  ├─→ AuthService() created
  │      │
  │      └─→ Checks stored credentials
  │
  ├─→ Future.delayed(1 second)
  │
  └─→ runApp(MyApp())
         │
         └─→ MaterialApp
                │
                └─→ Consumer<AuthService>
                       │
                       ├─→ if (!isLoggedIn) → LoginPage
                       │
                       └─→ if (isLoggedIn) → HC20HomePage
                              │
                              └─→ initState()
                                     │
                                     ├─→ _initializeDio()
                                     ├─→ _enableBackgroundExecution()
                                     ├─→ _checkAndShowBatteryOptimizationDialog()
                                     └─→ _loadSavedDevice()
                                            │
                                            └─→ If device saved:
                                                   _startAutoReconnectScanner()
```

---

## Key Features at a Glance

| Feature | Description | Status |
|---------|-------------|--------|
| **Authentication** | Login system via AuthService | ✅ Implemented |
| **BLE Scanning** | Find HC20 devices nearby | ✅ Implemented |
| **Device Connection** | Connect via HC20 SDK | ✅ Implemented |
| **Time Sync** | Sync device clock with phone | ✅ Implemented |
| **Real-time Data** | Stream health metrics | ✅ Implemented |
| **Webhooks** | Send data to backend (2 min) | ✅ Implemented |
| **Auto-Reconnect** | Background reconnection (30s scan) | ✅ Implemented |
| **HRV Auto-Refresh** | Fetch HRV data (6 hours) | ✅ Implemented |
| **Connection Monitor** | Detect silent disconnects (30s) | ✅ Implemented |
| **Battery Optimization** | Request exemption | ✅ Implemented |
| **Background Service** | Keep app alive when minimized | ✅ Implemented |
| **Device Association** | Link device to user account | ✅ Implemented |
| **Stress Alerts** | Emergency notification system | ✅ Implemented |
| **Disconnect Webhooks** | Notify backend of disconnects | ✅ Implemented |

---

## Next Steps

Continue to the next documentation file for detailed initialization and setup processes:

📄 **[Part 2: Initialization & Setup →](02_INITIALIZATION_AND_SETUP.md)**

---

## Quick Reference

### Important Line Numbers
- **main() function**: Line 18
- **MyApp widget**: Line 32
- **State variables**: Lines 68-111
- **initState()**: Line 113
- **Background service**: Line 148
- **Battery optimization**: Line 161

### Related Files
- `services/auth_service.dart` - User authentication
- `services/api_service.dart` - Backend API calls
- `services/storage_service.dart` - Local data storage
- `android/app/src/main/kotlin/.../MainActivity.kt` - Native Android code

---

**End of Part 1**  
**Next: [Part 2 - Initialization & Setup](02_INITIALIZATION_AND_SETUP.md)**
