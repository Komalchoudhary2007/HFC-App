# HC20 Flutter Plugin

Flutter plugin for HC20 wearable providing processed data APIs and hidden raw sensor pipeline with automatic cloud upload.

## Things to Note

- When the wearable is connected, raw data sensors will be automatically enabled when `connect()` is called and successfully connects.

- When raw data is enabled, the raw data will automatically upload to Nitto cloud. Note: Please set `clientId` and `clientSecret` when creating the `Hc20Client`. You can get the `clientId` and `clientSecret` from dev team.

- All data upload functions to Nitto cloud (such as raw data sensor enabled, `getAllDayHrvRows()`, `getAllDayHrv2Rows()` and `getAllDayRriRows()`) require network connectivity. However, without network connectivity, the UI won't be blocked; errors need to be handled by the HFC app.

- Please call `setTime()` every time you connect.

## Things to Implement in the HFC App

- The HFC app must enable background sync, so that when the app is in the background, raw data can still be uploaded to Nitto Cloud.

- When retrieving historical data, kindly retrieve HRV, HRV2 and RRI data as well by calling `getAllDayHrvRows()`, `getAllDayHrv2Rows()` and `getAllDayRriRows()`, as these functions include automatic upload functionality to Nitto cloud.

- RRI data can be large; please consider implementing background data retrieval.


## Install

Add to pubspec:

```yaml
dependencies:
  hc20:
    path: ../hc20
```

On iOS/Android, ensure Bluetooth permissions are configured.

## Quick Start

```dart
import 'package:hc20/hc20.dart';

// Create client with OAuth credentials (required)
final client = await Hc20Client.create(
  config: Hc20Config(
    clientId: 'your-client-id',
    clientSecret: 'your-client-secret',
  ),
);

// Scan and connect
client.scan().listen((device) async {
  await client.connect(device);
  final info = await client.readDeviceInfo(device);
  print('Connected: ${info.name} v${info.version}');
  
  // Start receiving realtime data
  client.realtimeV2(device).listen((data) {
    print('Heart rate: ${data.heart} bpm');
    print('SpO2: ${data.spo2}%');
  });
});
```

## API Reference

### Client Creation

#### `Hc20Client.create({required Hc20Config config})`

Creates and initializes an HC20 client instance.

```dart
// Create client with OAuth credentials (required)
final client = await Hc20Client.create(
  config: Hc20Config(
    clientId: 'your-client-id',
    clientSecret: 'your-client-secret',
  ),
);
```

**Parameters:**
- `config`: Required configuration object
  - `clientId`: OAuth client ID for cloud API authentication (required)
  - `clientSecret`: OAuth client secret for cloud API authentication (required)
  
**Note:** The `authUrl` and `baseUrl` are always retrieved from `Hc20CloudConfig` and cannot be overridden. Only `clientId` and `clientSecret` need to be provided by the client application.

**Returns:** `Future<Hc20Client>`

---

### Device Discovery & Connection

#### `scan({Hc20ScanFilter filter = const Hc20ScanFilter()})`

Scans for nearby HC20 devices.

```dart
// Basic scan
client.scan().listen((device) {
  print('Found: ${device.name} (${device.id})');
});

// Scan with filter (allow duplicates)
client.scan(filter: Hc20ScanFilter(allowDuplicates: true)).listen((device) {
  // Handle device
});
```

**Returns:** `Stream<Hc20Device>`

**Parameters:**
- `filter`: Optional scan filter configuration
  - `allowDuplicates`: Whether to emit duplicate scan results (default: `false`)

---

#### `connect(Hc20Device device)`

Connects to a device and initializes the raw data pipeline. Automatically enables health monitoring features and sensors.

```dart
await client.connect(device);
```

**Parameters:**
- `device`: The device to connect to (from `scan()`)

**Throws:** Connection errors if the device cannot be reached

**Note:** This method automatically:
- Reads device info to get MAC address (with retries for iOS compatibility)
- Starts the raw data pipeline (RawManager)
- Enables health monitoring (SpO2, BP, HRV at 5-minute intervals)
- Enables all sensors (IMU, PPG, GSR) for automatic background streaming

---

#### `disconnect(Hc20Device device)`

Disconnects from a device and stops all data streams, including raw sensor data pipeline.

```dart
await client.disconnect(device);
```

**Note:** This method stops the RawManager and disables auto-reconnect if it was enabled.

---

### Device Information

#### `readDeviceInfo(Hc20Device device)`

Reads device information including name, MAC address, version, and build time.

```dart
final info = await client.readDeviceInfo(device);
print('Name: ${info.name}');
print('MAC: ${info.mac}');
print('Version: ${info.version}');
print('Build time: ${info.buildTime}');
```

**Returns:** `Future<Hc20DeviceInfo>`

**Hc20DeviceInfo fields:**
- `name`: Device name
- `mac`: MAC address
- `version`: Firmware version
- `versionTag`: Optional version tag
- `buildTime`: Optional build timestamp

---

#### `factoryReset(Hc20Device device)`

Performs a factory reset on the device.

```dart
await client.factoryReset(device);
```

**Warning:** This will erase all data on the device.

---

### Parameters Management

#### `setParameters(Hc20Device device, Map<String, dynamic> params)`

Sets device parameters. Common parameters include user info and health monitor settings.

```dart
// Set user information
await client.setParameters(device, {
  'user_info': {
    'name': 'John Doe',
    'gender': 1,  // 0=female, 1=male
    'height': 175,  // cm
    'weight': 70,   // kg
  },
});

```

**Parameters:**
- `device`: The connected device
- `params`: Map of parameter keys and values

---

#### `getParameters(Hc20Device device, Map<String, dynamic> request)`

Retrieves device parameters.

```dart
final params = await client.getParameters(device, {
  'request': 'user_info',
});
print('User info: $params');
```

**Returns:** `Future<Map<String, dynamic>>`

**Parameters:**
- `device`: The connected device
- `request`: Map specifying which parameters to retrieve

---

### Time Management

#### `setTime(Hc20Device device, {required int timestamp, int timezone = 8})`

Sets the device's internal clock.

```dart
final now = DateTime.now();
await client.setTime(
  device,
  timestamp: now.millisecondsSinceEpoch ~/ 1000,  // Unix timestamp in seconds
  timezone: 8,  // UTC+8
);
```

**Parameters:**
- `device`: The connected device
- `timestamp`: Unix timestamp in seconds
- `timezone`: Timezone offset (default: 8)

---

#### `getTime(Hc20Device device)`

Gets the device's current time and timezone.

```dart
final time = await client.getTime(device);
print('Device time: ${time.timestamp}');
print('Timezone: UTC+${time.timezone}');
```

**Returns:** `Future<Hc20Time>`

**Hc20Time fields:**
- `timestamp`: Unix timestamp in seconds
- `timezone`: Timezone offset

---

### Realtime Data

#### `realtimeV2(Hc20Device device)`

Streams real-time health data from the device. This includes battery, heart rate, SpO2, blood pressure, temperature, and more.

```dart
client.realtimeV2(device).listen((data) {
  // Battery information
  if (data.battery != null) {
    print('Battery: ${data.battery!.percent}%');
    print('Charging: ${data.battery!.charge}');
  }
  
  // Basic activity data
  if (data.basicData != null) {
    print('Steps: ${data.basicData![0]}');
    print('Calories: ${data.basicData![1]}');
    print('Distance: ${data.basicData![2]} m');
  }
  
  // Heart rate
  if (data.heart != null) {
    print('Heart rate: ${data.heart} bpm');
  }
  
  // SpO2
  if (data.spo2 != null) {
    print('SpO2: ${data.spo2}%');
  }
  
  // Blood pressure
  if (data.bp != null) {
    print('BP: ${data.bp![0]}/${data.bp![1]} mmHg');
  }
  
  // Temperature
  if (data.temperature != null) {
    print('Temperature: ${data.temperature![0] / 100}°C');
  }
  
  // HRV metrics
  if (data.hrvMetrics != null) {
    print('SDNN: ${data.hrvMetrics!.sdnn}');
    print('TP: ${data.hrvMetrics!.tp}');
  }
});
```

**Returns:** `Stream<Hc20RealtimeV2>`

**Hc20RealtimeV2 fields:**
- `battery`: `Hc20BatteryInfo?` - Battery percentage and charging status
- `basicData`: `List<int>?` - [steps, calories, distance]
- `heart`: `int?` - Heart rate in bpm
- `rri`: `int?` - R-R interval in ms
- `spo2`: `int?` - SpO2 percentage
- `bp`: `List<int>?` - [systolic, diastolic] in mmHg
- `temperature`: `List<int>?` - [hand, env, body] × 100
- `baro`: `int?` - Barometric pressure
- `wear`: `int?` - Wear detection status
- `sleep`: `List<int>?` - [status, deep, light, rem, sober]
- `gnss`: `List<num>?` - [onoff, sigqual, timestamp, lat, lon, alt]
- `hrv`: `List<int>?` - [SDNN, TP, LF, HF, VLF] × 1000
- `hrv2`: `List<int>?` - [mental_stress, fatigue, stress_res, reg_ability]
- `hrvMetrics`: `Hc20HrvMetrics?` - Parsed HRV metrics
- `hrv2Metrics`: `Hc20Hrv2Metrics?` - Parsed HRV2 metrics

---

### History Data - All Day Rows

These methods return data in a unified `Hc20AllDayRow` format with timestamps and validity flags.

#### `getAllDaySummaryRows(Hc20Device device, {required int yy, required int mm, required int dd})`

Gets all-day summary data (steps, calories, distance, active/silent time).

```dart
final rows = await client.getAllDaySummaryRows(device, yy: 24, mm: 10, dd: 28);
for (final row in rows) {
  print('Date: ${row.dateTime}');
  print('Steps: ${row.values['stepsTotal']}');
  print('Calories: ${row.values['caloriesTotalKcal']}');
  print('Valid: ${row.valid}');
}
```

**Returns:** `Future<List<Hc20AllDayRow>>`

**Hc20AllDayRow fields:**
- `dateTime`: ISO 8601 timestamp string
- `values`: Map of metric values
- `valid`: Whether the data is valid (not invalid marker)

---

#### `getAllDayHeartRows(Hc20Device device, {required int yy, required int mm, required int dd, int? packetIndex})`

Gets heart rate data (5-second intervals). Each packet covers 15 minutes.

```dart
// Get all heart rate data for a day
final rows = await client.getAllDayHeartRows(device, yy: 24, mm: 10, dd: 28);

// Get specific packet (packet 1 = first 15 minutes of day)
final packetRows = await client.getAllDayHeartRows(
  device, 
  yy: 24, 
  mm: 10, 
  dd: 28, 
  packetIndex: 1,
);

for (final row in rows) {
  print('Time: ${row.dateTime}');
  print('BPM: ${row.values['bpm']}');
}
```

**Returns:** `Future<List<Hc20AllDayRow>>`

**Values:** `{'bpm': int?}` - Heart rate in bpm

---

#### `getAllDayStepsRows(Hc20Device device, {required int yy, required int mm, required int dd, int? packetIndex})`

Gets step count data (5-minute intervals). Each packet covers 8 hours.

```dart
final rows = await client.getAllDayStepsRows(device, yy: 24, mm: 10, dd: 28);
for (final row in rows) {
  print('Time: ${row.dateTime}');
  print('Steps: ${row.values['steps']}');
}
```

**Returns:** `Future<List<Hc20AllDayRow>>`

**Values:** `{'steps': int?}` - Steps in that 5-minute interval

---

#### `getAllDaySpo2Rows(Hc20Device device, {required int yy, required int mm, required int dd, int? packetIndex})`

Gets SpO2 (blood oxygen) data (5-minute intervals). Each packet covers 12 hours.

```dart
final rows = await client.getAllDaySpo2Rows(device, yy: 24, mm: 10, dd: 28);
for (final row in rows) {
  print('Time: ${row.dateTime}');
  print('SpO2: ${row.values['spo2Pct']}%');
}
```

**Returns:** `Future<List<Hc20AllDayRow>>`

**Values:** `{'spo2Pct': int?}` - SpO2 percentage

---

#### `getAllDayRriRows(Hc20Device device, {required int yy, required int mm, required int dd, int? packetIndex})`

Gets RRI (R-R Interval) data (5-second intervals). Each packet covers 8 minutes. Automatically uploads to cloud.

```dart
final rows = await client.getAllDayRriRows(device, yy: 24, mm: 10, dd: 28);
for (final row in rows) {
  print('Time: ${row.dateTime}');
  print('RRI: ${row.values['rriMs']} ms');
}
```

**Returns:** `Future<List<Hc20AllDayRow>>`

**Values:** `{'rriMs': int?}` - R-R interval in milliseconds

**Note:** RRI data is automatically uploaded to cloud after parsing.

---

#### `getAllDayTemperatureRows(Hc20Device device, {required int yy, required int mm, required int dd, int? packetIndex})`

Gets temperature data (1-minute intervals). Each packet covers 48 minutes.

```dart
final rows = await client.getAllDayTemperatureRows(device, yy: 24, mm: 10, dd: 28);
for (final row in rows) {
  print('Time: ${row.dateTime}');
  print('Skin temp: ${row.values['skinC']}°C');
  print('Env temp: ${row.values['envC']}°C');
}
```

**Returns:** `Future<List<Hc20AllDayRow>>`

**Values:** 
- `{'skinC': double?}` - Skin temperature in Celsius
- `{'envC': double?}` - Ambient temperature in Celsius

---

#### `getAllDayBaroRows(Hc20Device device, {required int yy, required int mm, required int dd, int? packetIndex})`

Gets barometric pressure data (1-minute intervals). Each packet covers 48 minutes.

```dart
final rows = await client.getAllDayBaroRows(device, yy: 24, mm: 10, dd: 28);
for (final row in rows) {
  print('Time: ${row.dateTime}');
  print('Pressure: ${row.values['pressurePa']} Pa');
}
```

**Returns:** `Future<List<Hc20AllDayRow>>`

**Values:** `{'pressurePa': int?}` - Barometric pressure in Pascals

---

#### `getAllDayBpRows(Hc20Device device, {required int yy, required int mm, required int dd, int? packetIndex})`

Gets blood pressure data (5-minute intervals). Each packet covers 8 hours.

```dart
final rows = await client.getAllDayBpRows(device, yy: 24, mm: 10, dd: 28);
for (final row in rows) {
  print('Time: ${row.dateTime}');
  print('BP: ${row.values['sys']}/${row.values['dia']} mmHg');
}
```

**Returns:** `Future<List<Hc20AllDayRow>>`

**Values:**
- `{'sys': int?}` - Systolic pressure in mmHg
- `{'dia': int?}` - Diastolic pressure in mmHg

---

#### `getAllDayHrvRows(Hc20Device device, {required int yy, required int mm, required int dd, int? packetIndex})`

Gets HRV (Heart Rate Variability) data (5-minute intervals). Each packet covers 45 minutes. Automatically uploads to cloud.

```dart
final rows = await client.getAllDayHrvRows(device, yy: 24, mm: 10, dd: 28);
for (final row in rows) {
  print('Time: ${row.dateTime}');
  print('SDNN: ${row.values['sdnn']}');
  print('TP: ${row.values['tp']}');
  print('LF: ${row.values['lf']}');
  print('HF: ${row.values['hf']}');
  print('VLF: ${row.values['vlf']}');
}
```

**Returns:** `Future<List<Hc20AllDayRow>>`

**Values:**
- `{'sdnn': double?}` - SDNN in seconds
- `{'tp': double?}` - Total Power in seconds
- `{'lf': double?}` - Low Frequency in seconds
- `{'hf': double?}` - High Frequency in seconds
- `{'vlf': double?}` - Very Low Frequency in seconds

**Note:** HRV data is automatically uploaded to cloud after parsing.

---

#### `getAllDaySleepRows(Hc20Device device, {required int yy, required int mm, required int dd, int? packetIndex, bool includeSummary = false})`

Gets sleep data. Packet 0 contains summary, other packets contain detailed sleep states.

```dart
// Get all sleep data including summary
final rows = await client.getAllDaySleepRows(
  device, 
  yy: 24, 
  mm: 10, 
  dd: 28,
  includeSummary: true,
);

for (final row in rows) {
  if (row.values.containsKey('sleepState')) {
    print('Time: ${row.dateTime}');
    print('State: ${row.values['sleepState']}');  // 'awake', 'light', 'deep', 'rem'
  } else {
    // Summary row
    print('Sober: ${row.values['soberMin']} min');
    print('Light: ${row.values['lightMin']} min');
    print('Deep: ${row.values['deepMin']} min');
    print('REM: ${row.values['remMin']} min');
  }
}
```

**Returns:** `Future<List<Hc20AllDayRow>>`

**Values:**
- Summary (packet 0): `{'soberMin': int?}`, `{'lightMin': int?}`, `{'deepMin': int?}`, `{'remMin': int?}`, `{'napMin': int?}`
- Details: `{'sleepState': String}` - One of: 'awake', 'light', 'deep', 'rem'

---

#### `getAllDayCaloriesRows(Hc20Device device, {required int yy, required int mm, required int dd, int? packetIndex})`

Gets calorie burn data (5-minute intervals). Each packet covers 8 hours.

```dart
final rows = await client.getAllDayCaloriesRows(device, yy: 24, mm: 10, dd: 28);
for (final row in rows) {
  print('Time: ${row.dateTime}');
  print('Calories: ${row.values['kcal']} kcal');
}
```

**Returns:** `Future<List<Hc20AllDayRow>>`

**Values:** `{'kcal': int?}` - Calories burned in kcal

---

#### `getAllDayHrv2Rows(Hc20Device device, {required int yy, required int mm, required int dd, int? packetIndex})`

Gets HRV2 (advanced HRV) data (5-minute intervals). Each packet covers 120 minutes.

```dart
final rows = await client.getAllDayHrv2Rows(device, yy: 24, mm: 10, dd: 28);
for (final row in rows) {
  print('Time: ${row.dateTime}');
  print('Mental stress: ${row.values['mentalStress']}');
  print('Fatigue: ${row.values['fatigue']}');
  print('Stress resistance: ${row.values['stressResistance']}');
  print('Regulation ability: ${row.values['regulationAbility']}');
}
```

**Returns:** `Future<List<Hc20AllDayRow>>`

**Values:**
- `{'mentalStress': int?}` - Mental stress level
- `{'fatigue': int?}` - Fatigue level
- `{'stressResistance': int?}` - Stress resistance
- `{'regulationAbility': int?}` - Regulation ability

---



## Complete Example

```dart
import 'package:hc20/hc20.dart';

void main() async {
  // Create client with OAuth credentials (required)
  final client = await Hc20Client.create(
    config: Hc20Config(
      clientId: 'your-client-id',
      clientSecret: 'your-client-secret',
    ),
  );
  
  // Scan for devices
  await for (final device in client.scan()) {
    print('Found device: ${device.name}');
    
    // Connect
    await client.connect(device);
    print('Connected!');
    
    // Read device info
    final info = await client.readDeviceInfo(device);
    print('Device: ${info.name} v${info.version}');
    print('MAC: ${info.mac}');
    
    // Set user parameters
    await client.setParameters(device, {
      'user_info': {
        'name': 'John Doe',
        'gender': 1,
        'height': 175,
        'weight': 70,
      },
    });
    
    // Sync time
    final now = DateTime.now();
    await client.setTime(
      device,
      timestamp: now.millisecondsSinceEpoch ~/ 1000,
      timezone: 8,
    );
    
    // Listen to realtime data
    final subscription = client.realtimeV2(device).listen((data) {
      if (data.heart != null) {
        print('Heart rate: ${data.heart} bpm');
      }
      if (data.spo2 != null) {
        print('SpO2: ${data.spo2}%');
      }
    });
    
    // Enable sensors and stream raw data
    await client.setSensorState(device);
    
    client.streamImu(device).listen((imu) {
      print('IMU: accel=(${imu.accelX}, ${imu.accelY}, ${imu.accelZ})');
    });
    
    // Get history data
    final today = DateTime.now();
    final summary = await client.getAllDaySummary(
      device,
      yy: today.year % 100,
      mm: today.month,
      dd: today.day,
    );
    print('Today\'s steps: ${summary.steps}');
    
    // Get heart rate data
    final heartRows = await client.getAllDayHeartRows(
      device,
      yy: today.year % 100,
      mm: today.month,
      dd: today.day,
    );
    print('Heart rate data points: ${heartRows.length}');
    
    // Clean up
    await subscription.cancel();
    await client.disconnect(device);
    break;  // Exit after first device
  }
}
```

