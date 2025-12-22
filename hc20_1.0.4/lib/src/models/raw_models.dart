// Internal models for parsing
class ImuSample {
  final int tsMs;
  final int packetId;
  final int x, y, z;
  final int kind; // 0=acc,1=gyr,2=mag
  ImuSample(this.tsMs, this.packetId, this.x, this.y, this.z, this.kind);
}

class PpgSample {
  final int tsMs;
  final int packetId;
  final int? green, red, ir;
  PpgSample(this.tsMs, this.packetId, {this.green, this.red, this.ir});
}

class GsrSample {
  final int tsMs;
  final int packetId;
  final int i, q, raw;
  GsrSample(this.tsMs, this.packetId, this.i, this.q, this.raw);
}

// Client-facing models
class Hc20ImuData {
  final int timestampMs;
  final int packetId;
  final Hc20AccelerometerData? accelerometer;
  final Hc20GyroscopeData? gyroscope;
  final Hc20MagnetometerData? magnetometer;
  
  Hc20ImuData({
    required this.timestampMs,
    required this.packetId,
    this.accelerometer,
    this.gyroscope,
    this.magnetometer,
  });
}

class Hc20AccelerometerData {
  final int x, y, z; // Raw signed 16-bit values
  Hc20AccelerometerData(this.x, this.y, this.z);
}

class Hc20GyroscopeData {
  final int x, y, z; // Raw signed 16-bit values
  Hc20GyroscopeData(this.x, this.y, this.z);
}

class Hc20MagnetometerData {
  final int x, y, z; // Raw signed 16-bit values
  Hc20MagnetometerData(this.x, this.y, this.z);
}

class Hc20PpgData {
  final int timestampMs;
  final int packetId;
  final int? green; // 24-bit value
  final int? red;   // 24-bit value
  final int? ir;    // 24-bit value
  
  Hc20PpgData({
    required this.timestampMs,
    required this.packetId,
    this.green,
    this.red,
    this.ir,
  });
}

class Hc20GsrData {
  final int timestampMs;
  final int packetId;
  final int i;   // 24-bit value
  final int q;   // 24-bit value
  final int raw; // 24-bit value
  
  Hc20GsrData({
    required this.timestampMs,
    required this.packetId,
    required this.i,
    required this.q,
    required this.raw,
  });
}

// Sensor configuration models
class Hc20SensorConfig {
  final Hc20ImuConfig? imu;
  final Hc20PpgConfig? ppg;
  final Hc20EcgConfig? ecg;
  final Hc20GsrConfig? gsr;
  
  Hc20SensorConfig({
    this.imu,
    this.ppg,
    this.ecg,
    this.gsr,
  });
  
  factory Hc20SensorConfig.fromJson(Map<String, dynamic> json) {
    return Hc20SensorConfig(
      imu: json['imu'] != null ? Hc20ImuConfig.fromString(json['imu']) : null,
      ppg: json['ppg'] != null ? Hc20PpgConfig.fromString(json['ppg']) : null,
      ecg: json['ecg'] != null ? Hc20EcgConfig.fromString(json['ecg']) : null,
      gsr: json['gsr'] != null ? Hc20GsrConfig.fromString(json['gsr']) : null,
    );
  }
}

class Hc20ImuConfig {
  final int rate;           // Sampling rate (Hz)
  final int depth;          // Sample bit depth (bits)
  final bool acceSupported; // Accelerometer supported
  final bool gyroSupported; // Gyroscope supported
  final bool magSupported;  // Magnetometer supported
  final double acceRange;   // Accelerometer range (G)
  final double gyroRange;   // Gyroscope range (DPS)
  
  Hc20ImuConfig({
    required this.rate,
    required this.depth,
    required this.acceSupported,
    required this.gyroSupported,
    required this.magSupported,
    required this.acceRange,
    required this.gyroRange,
  });
  
  factory Hc20ImuConfig.fromString(String str) {
    final parts = str.split(',');
    if (parts.length < 7) throw FormatException('Invalid IMU config format');
    return Hc20ImuConfig(
      rate: int.tryParse(parts[0].trim()) ?? 0,
      depth: int.tryParse(parts[1].trim()) ?? 0,
      acceSupported: int.tryParse(parts[2].trim()) == 1,
      gyroSupported: int.tryParse(parts[3].trim()) == 1,
      magSupported: int.tryParse(parts[4].trim()) == 1,
      acceRange: double.tryParse(parts[5].trim()) ?? 0.0,
      gyroRange: double.tryParse(parts[6].trim()) ?? 0.0,
    );
  }
}

class Hc20PpgConfig {
  final int rate;        // Sampling rate (Hz)
  final int depth;        // Sample bit depth (bits)
  final bool greenSupported; // LED_Green supported
  final bool redSupported;   // LED_Red supported
  final bool irSupported;    // LED_IR supported
  
  Hc20PpgConfig({
    required this.rate,
    required this.depth,
    required this.greenSupported,
    required this.redSupported,
    required this.irSupported,
  });
  
  factory Hc20PpgConfig.fromString(String str) {
    final parts = str.split(',');
    if (parts.length < 5) throw FormatException('Invalid PPG config format');
    return Hc20PpgConfig(
      rate: int.tryParse(parts[0].trim()) ?? 0,
      depth: int.tryParse(parts[1].trim()) ?? 0,
      greenSupported: int.tryParse(parts[2].trim()) == 1,
      redSupported: int.tryParse(parts[3].trim()) == 1,
      irSupported: int.tryParse(parts[4].trim()) == 1,
    );
  }
}

class Hc20EcgConfig {
  final int rate;  // Sampling rate (Hz)
  final int depth; // Sample bit depth (bits)
  
  Hc20EcgConfig({
    required this.rate,
    required this.depth,
  });
  
  factory Hc20EcgConfig.fromString(String str) {
    final parts = str.split(',');
    if (parts.length < 2) throw FormatException('Invalid ECG config format');
    return Hc20EcgConfig(
      rate: int.tryParse(parts[0].trim()) ?? 0,
      depth: int.tryParse(parts[1].trim()) ?? 0,
    );
  }
}

class Hc20GsrConfig {
  final int rate;  // Sampling rate (Hz)
  final int depth; // Sample bit depth (bits)
  
  Hc20GsrConfig({
    required this.rate,
    required this.depth,
  });
  
  factory Hc20GsrConfig.fromString(String str) {
    final parts = str.split(',');
    if (parts.length < 2) throw FormatException('Invalid GSR config format');
    return Hc20GsrConfig(
      rate: int.tryParse(parts[0].trim()) ?? 0,
      depth: int.tryParse(parts[1].trim()) ?? 0,
    );
  }
}

// Sensor state models
class Hc20SensorState {
  final Hc20ImuState? imu;
  final Hc20PpgState? ppg;
  final Hc20EcgState? ecg;
  final Hc20GsrState? gsr;
  
  Hc20SensorState({
    this.imu,
    this.ppg,
    this.ecg,
    this.gsr,
  });
  
  factory Hc20SensorState.fromJson(Map<String, dynamic> json) {
    return Hc20SensorState(
      imu: json['imu'] != null ? Hc20ImuState.fromJson(json['imu']) : null,
      ppg: json['ppg'] != null ? Hc20PpgState.fromJson(json['ppg']) : null,
      ecg: json['ecg'] != null ? Hc20EcgState.fromJson(json['ecg']) : null,
      gsr: json['gsr'] != null ? Hc20GsrState.fromJson(json['gsr']) : null,
    );
  }
}

class Hc20ImuState {
  final bool accelerometerEnabled;
  final bool gyroscopeEnabled;
  final bool magnetometerEnabled;
  
  Hc20ImuState({
    required this.accelerometerEnabled,
    required this.gyroscopeEnabled,
    required this.magnetometerEnabled,
  });
  
  factory Hc20ImuState.fromJson(Map<String, dynamic> json) {
    final ctrl = json['ctrl'] as int? ?? 0;
    return Hc20ImuState(
      accelerometerEnabled: (ctrl & 0x01) != 0,
      gyroscopeEnabled: (ctrl & 0x02) != 0,
      magnetometerEnabled: (ctrl & 0x04) != 0,
    );
  }
  
  int get ctrlValue {
    return (accelerometerEnabled ? 0x01 : 0) |
           (gyroscopeEnabled ? 0x02 : 0) |
           (magnetometerEnabled ? 0x04 : 0);
  }
}

class Hc20PpgState {
  final bool greenEnabled;
  final bool redEnabled;
  final bool irEnabled;
  
  Hc20PpgState({
    required this.greenEnabled,
    required this.redEnabled,
    required this.irEnabled,
  });
  
  factory Hc20PpgState.fromJson(Map<String, dynamic> json) {
    final ctrl = json['ctrl'] as int? ?? 0;
    return Hc20PpgState(
      greenEnabled: (ctrl & 0x01) != 0,
      redEnabled: (ctrl & 0x02) != 0,
      irEnabled: (ctrl & 0x04) != 0,
    );
  }
  
  int get ctrlValue {
    return (greenEnabled ? 0x01 : 0) |
           (redEnabled ? 0x02 : 0) |
           (irEnabled ? 0x04 : 0);
  }
}

class Hc20EcgState {
  final bool enabled;
  
  Hc20EcgState({required this.enabled});
  
  factory Hc20EcgState.fromJson(Map<String, dynamic> json) {
    final ctrl = json['ctrl'] as int? ?? 0;
    return Hc20EcgState(enabled: (ctrl & 0x01) != 0);
  }
  
  int get ctrlValue => enabled ? 0x01 : 0x00;
}

class Hc20GsrState {
  final bool enabled;
  
  Hc20GsrState({required this.enabled});
  
  factory Hc20GsrState.fromJson(Map<String, dynamic> json) {
    final ctrl = json['ctrl'] as int? ?? 0;
    return Hc20GsrState(enabled: (ctrl & 0x01) != 0);
  }
  
  int get ctrlValue => enabled ? 0x01 : 0x00;
}


