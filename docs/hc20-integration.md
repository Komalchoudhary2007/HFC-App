# HC20 SDK Integration Guide

## Overview
This document provides detailed information about integrating the HC20 wearable SDK into the HFC Flutter application.

## SDK Structure
The HC20 SDK (`/hc20/`) is a comprehensive Flutter plugin that provides:

### Core Features
- **Bluetooth Low Energy (BLE) Communication**: Direct connection to HC20 devices
- **Real-time Data Streaming**: Live health metrics including heart rate, SpO2, blood pressure
- **Historical Data Retrieval**: Access to stored device data in various time intervals
- **Cloud Integration**: Automatic data upload to Nitto Cloud for HRV and RRI data
- **Device Management**: Connection, configuration, and parameter settings

### SDK Components

#### 1. Core Layer (`src/core/`)
- `ble_adapter.dart`: Bluetooth Low Energy communication interface
- `transport.dart`: Data frame encoding/decoding
- `response_parser.dart`: Device response parsing logic
- `frame.dart`: Communication protocol definitions
- `errors.dart`: Error handling and exception types

#### 2. Models (`src/models/`)
- `processed_models.dart`: High-level data structures for client use
- `raw_models.dart`: Low-level sensor data models
- `models.dart`: Combined model exports

#### 3. Client Interface (`src/processed/`)
- `hc20_client.dart`: Main client API - **primary integration point**

#### 4. Raw Data Pipeline (`src/raw/`)
- `raw_manager.dart`: Raw data collection and upload management
- `auth_service.dart`: OAuth authentication for cloud services
- `uploader.dart`: Cloud data upload functionality
- `config.dart`: Configuration management
- `parsers.dart`: Raw data parsing utilities

## Integration Implementation

### 1. Dependencies
```yaml
dependencies:
  hc20:
    path: ./hc20
  permission_handler: ^11.3.1
```

### 2. Permissions Setup
The app requires several permissions for Bluetooth and location access:

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth access to connect to HC20 wearable devices</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access for Bluetooth scanning</string>
```

### 3. Client Initialization
```dart
final client = await Hc20Client.create(
  config: Hc20Config(
    clientId: 'your-oauth-client-id',
    clientSecret: 'your-oauth-client-secret',
  ),
);
```

### 4. Device Discovery and Connection
```dart
// Start scanning for devices
client.scan().listen((device) async {
  print('Found: ${device.name}');
  
  // Connect to device
  await client.connect(device);
  
  // Set device time (required)
  await client.setTime(device, 
    timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    timezone: 8
  );
});
```

### 5. Real-time Data Streaming
```dart
client.realtimeV2(device).listen((data) {
  // Heart rate
  if (data.heart != null) {
    print('Heart Rate: ${data.heart} bpm');
  }
  
  // Blood oxygen
  if (data.spo2 != null) {
    print('SpO2: ${data.spo2}%');
  }
  
  // Blood pressure
  if (data.bp != null) {
    print('BP: ${data.bp![0]}/${data.bp![1]} mmHg');
  }
  
  // Battery status
  if (data.battery != null) {
    print('Battery: ${data.battery!.percent}%');
  }
});
```

### 6. Historical Data Retrieval
```dart
final now = DateTime.now();

// Get daily summary
final summary = await client.getAllDaySummaryRows(device,
  yy: now.year % 100,
  mm: now.month, 
  dd: now.day
);

// Get heart rate history
final heartData = await client.getAllDayHeartRows(device,
  yy: now.year % 100,
  mm: now.month,
  dd: now.day
);

// Get HRV data (automatically uploaded to cloud)
final hrvData = await client.getAllDayHrvRows(device,
  yy: now.year % 100,
  mm: now.month,
  dd: now.day
);
```

## Data Types and Structures

### Real-time Data (`Hc20RealtimeV2`)
- `heart`: Heart rate (bpm)
- `spo2`: Blood oxygen percentage
- `bp`: Blood pressure [systolic, diastolic]
- `temperature`: Temperature readings [skin, ambient, body]
- `battery`: Battery info (percentage, charging status)
- `basicData`: Activity data [steps, calories, distance]
- `hrv`: HRV metrics [SDNN, TP, LF, HF, VLF]
- `hrv2`: Advanced HRV [mental stress, fatigue, stress resistance]

### Historical Data (`Hc20AllDayRow`)
- `dateTime`: ISO timestamp
- `values`: Data values map
- `valid`: Data validity flag

### Device Information (`Hc20DeviceInfo`)
- `name`: Device name
- `mac`: MAC address
- `version`: Firmware version
- `buildTime`: Build timestamp

## Cloud Integration

### Automatic Data Upload
The SDK automatically uploads certain data types to Nitto Cloud:

1. **HRV Data**: `getAllDayHrvRows()` triggers automatic upload
2. **HRV2 Data**: `getAllDayHrv2Rows()` triggers automatic upload  
3. **RRI Data**: `getAllDayRriRows()` triggers automatic upload
4. **Raw Sensor Data**: Continuously uploaded when connected

### OAuth Authentication
- Cloud authentication is handled automatically using provided credentials
- No manual token management required
- Automatic retry and error handling included

## Error Handling

### Common Error Scenarios
1. **Bluetooth Permission Denied**: Handle permission requests properly
2. **Device Connection Timeout**: Implement retry logic
3. **Network Connectivity**: Cloud uploads require internet access
4. **Invalid Credentials**: Ensure correct OAuth credentials

### Best Practices
- Always check connection status before operations
- Implement proper error boundaries in UI
- Handle network errors gracefully
- Provide user feedback for connection states

## Performance Considerations

### Memory Management
- Dispose of streams properly when done
- Disconnect devices when app goes to background
- Limit concurrent data operations

### Data Volume
- RRI data can be large - consider background processing
- Implement data pagination for large history requests
- Cache frequently accessed data locally

### Battery Optimization
- Use background sync for continuous data collection
- Implement intelligent connection management
- Balance data frequency vs. power consumption

## Testing and Debugging

### Testing Without Hardware
- SDK provides mock data streams for development
- Use Flutter's device emulation for UI testing
- Implement feature flags for hardware-dependent features

### Debugging Tools
- Enable verbose logging in debug builds
- Use Flutter Inspector for UI debugging
- Monitor Bluetooth logs on device

## Production Deployment

### Prerequisites
1. Valid OAuth credentials from Nitto development team
2. Proper app store permissions for Bluetooth access
3. Background processing permissions for continuous sync
4. Network connectivity requirements documented

### Configuration
- Replace placeholder credentials in production builds
- Configure proper error reporting and analytics
- Implement user onboarding for device pairing
- Add proper loading states and error messages

## Security Considerations

### Data Protection
- All cloud communication uses OAuth 2.0
- Device communication encrypted via BLE
- No sensitive data stored locally without encryption

### Privacy Compliance
- Implement proper user consent flows
- Document data collection and usage
- Provide data export/deletion capabilities
- Follow healthcare data regulations (HIPAA, GDPR)

---

*This integration guide was created on December 2, 2025, for the HFC App project.*