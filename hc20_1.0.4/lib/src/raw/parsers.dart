import 'dart:typed_data';
import '../models/raw_models.dart';
import 'config.dart';

class RawParsers {
  // Internal parsing (for raw_manager)
  static List<ImuSample> parseImu(Uint8List payload) {
    final samples = <ImuSample>[];
    int o = 0;
    if (payload.isEmpty || payload[o++] != 0x81) return samples;
    
    // Read header once
    final flag = payload[o++];
    final pid = _le32(payload, o); o += 4;
    final ts = _le32(payload, o); o += 4;
    
    // Validate packet header - reject packets with invalid packet_id and timestamp
    // This indicates an incomplete/corrupted packet that may cause duplicate entries
    if (pid == 0 && ts == 0) {
      Hc20CloudConfig.debugPrint('[HC20 IMU Parser] WARNING: Rejecting packet with invalid header (packet_id=0, timestamp=0). This may indicate an incomplete/corrupted packet.');
      return samples;
    }
    
    // Calculate expected bytes for one sample based on enabled sensors
    int bytesPerSample = 0;
    if ((flag & 0x01) != 0) bytesPerSample += 6; // Accel
    if ((flag & 0x02) != 0) bytesPerSample += 6; // Gyro
    if ((flag & 0x04) != 0) bytesPerSample += 6; // Mag
    
    if (bytesPerSample == 0) return samples; // No sensors enabled
    
    // Check if packet contains multiple samples (payload longer than single sample)
    final remainingBytes = payload.length - o;
    final sampleCount = remainingBytes ~/ bytesPerSample;
    
    // IMU sample rate is 104Hz, so interval is 1000/104 ≈ 9.615ms per sample
    const double imuSampleIntervalMs = 1000.0 / 104.0;
    
    // Parse all samples in the packet
    for (int sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
      int currentOffset = o + (sampleIndex * bytesPerSample);
      
      // Calculate timestamp for this sample
      int sampleTimestamp = ts;
      if (sampleCount > 1 && sampleIndex > 0) {
        sampleTimestamp = ts + (sampleIndex * imuSampleIntervalMs).round();
      }
      
      // Parse in order: Accel → Gyro → Mag (kinds: 0, 1, 2)
      for (final k in [0, 1, 2]) {
        final enabled = (flag & (1 << k)) != 0;
        if (!enabled) continue;
        if (currentOffset + 6 > payload.length) break;
        
        final x = _le16s(payload, currentOffset); currentOffset += 2;
        final y = _le16s(payload, currentOffset); currentOffset += 2;
        final z = _le16s(payload, currentOffset); currentOffset += 2;
        samples.add(ImuSample(sampleTimestamp, pid, x, y, z, k));
      }
    }
    
    return samples;
  }

  static List<PpgSample> parsePpg(Uint8List payload) {
    final results = <PpgSample>[];
    int o = 0;
    if (payload.isEmpty || payload[o++] != 0x82) return results;
    
    final flag = payload[o++];
    final pid = _le32(payload, o); o += 4;
    final ts = _le32(payload, o); o += 4;
    
    // Validate packet header - reject packets with invalid packet_id and timestamp
    // This indicates an incomplete/corrupted packet that may cause duplicate entries
    if (pid == 0 && ts == 0) {
      Hc20CloudConfig.debugPrint('[HC20 PPG Parser] WARNING: Rejecting packet with invalid header (packet_id=0, timestamp=0). This may indicate an incomplete/corrupted packet.');
      return results;
    }
    
    // Calculate bytes per sample
    int bytesPerSample = 0;
    if ((flag & 0x01) != 0) bytesPerSample += 3; // Green
    if ((flag & 0x02) != 0) bytesPerSample += 3; // Red
    if ((flag & 0x04) != 0) bytesPerSample += 3; // IR
    
    if (bytesPerSample == 0) return results;
    
    // Check if packet contains multiple samples
    final remainingBytes = payload.length - o;
    final sampleCount = remainingBytes ~/ bytesPerSample;
    
    // PPG sample rate is 100Hz, so interval is 10ms per sample
    const int ppgSampleIntervalMs = 10;
    
    // Parse all samples in the packet
    for (int sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
      int currentOffset = o + (sampleIndex * bytesPerSample);
      int? g, r, ir;
      
      if ((flag & 0x01) != 0 && currentOffset + 3 <= payload.length) {
        g = _le24(payload, currentOffset); currentOffset += 3;
      }
      if ((flag & 0x02) != 0 && currentOffset + 3 <= payload.length) {
        r = _le24(payload, currentOffset); currentOffset += 3;
      }
      if ((flag & 0x04) != 0 && currentOffset + 3 <= payload.length) {
        ir = _le24(payload, currentOffset); currentOffset += 3;
      }
      
      // Calculate timestamp for this sample
      int sampleTimestamp = ts;
      if (sampleCount > 1 && sampleIndex > 0) {
        sampleTimestamp = ts + (sampleIndex * ppgSampleIntervalMs);
      }
      
      results.add(PpgSample(sampleTimestamp, pid, green: g, red: r, ir: ir));
    }
    
    return results;
  }

  static List<GsrSample> parseGsr(Uint8List payload) {
    final out = <GsrSample>[];
    int o = 0;
    if (payload.isEmpty || payload[o++] != 0x84) return out;
    o++; // skip reserved flag
    final pid = _le32(payload, o); o += 4;
    final ts = _le32(payload, o); o += 4;
    
    // Validate packet header - reject packets with invalid packet_id and timestamp
    // This indicates an incomplete/corrupted packet that may cause duplicate entries
    if (pid == 0 && ts == 0) {
      Hc20CloudConfig.debugPrint('[HC20 GSR Parser] WARNING: Rejecting packet with invalid header (packet_id=0, timestamp=0). This may indicate an incomplete/corrupted packet.');
      return out;
    }
    
    // GSR sample rate is 8Hz, so interval is 125ms per sample
    const int gsrSampleIntervalMs = 125;
    const int bytesPerGsrSample = 9; // 3B I + 3B Q + 3B RAW
    
    int sampleIndex = 0;
    while (o + bytesPerGsrSample <= payload.length) {
      final i = _le24(payload, o); o += 3;
      final q = _le24(payload, o); o += 3;
      final raw = _le24(payload, o); o += 3;
      
      // Calculate timestamp for this sample
      int sampleTimestamp = ts;
      if (sampleIndex > 0) {
        sampleTimestamp = ts + (sampleIndex * gsrSampleIntervalMs);
      }
      
      out.add(GsrSample(sampleTimestamp, pid, i, q, raw));
      sampleIndex++;
    }
    return out;
  }

  // Client-facing parsing
  // Returns list because one packet may contain multiple samples at high rates
  // IMU is configured at 104Hz, so sample interval is ~9.615ms
  static List<Hc20ImuData> parseImuData(Uint8List payload) {
    final results = <Hc20ImuData>[];
    int o = 0;
    if (payload.isEmpty || payload[o++] != 0x81) return results;
    
    // Read header once
    final flag = payload[o++];
    final pid = _le32(payload, o); o += 4;
    final ts = _le32(payload, o); o += 4;
    
    // Validate packet header - reject packets with invalid packet_id and timestamp
    // This indicates an incomplete/corrupted packet that may cause duplicate entries
    if (pid == 0 && ts == 0) {
      Hc20CloudConfig.debugPrint('[HC20 IMU Parser] WARNING: Rejecting packet with invalid header (packet_id=0, timestamp=0). This may indicate an incomplete/corrupted packet.');
      return results;
    }
    
    // Calculate expected bytes for one sample based on enabled sensors
    int bytesPerSample = 0;
    if ((flag & 0x01) != 0) bytesPerSample += 6; // Accel
    if ((flag & 0x02) != 0) bytesPerSample += 6; // Gyro
    if ((flag & 0x04) != 0) bytesPerSample += 6; // Mag
    
    if (bytesPerSample == 0) return results; // No sensors enabled
    
    // Check if packet contains multiple samples (payload longer than single sample)
    final remainingBytes = payload.length - o;
    final sampleCount = remainingBytes ~/ bytesPerSample;
    
    // IMU sample rate is 104Hz, so interval is 1000/104 ≈ 9.615ms per sample
    const double imuSampleIntervalMs = 1000.0 / 104.0;
    
    // Parse all samples in the packet
    for (int sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
      int currentOffset = o + (sampleIndex * bytesPerSample);
      Hc20AccelerometerData? accel;
      Hc20GyroscopeData? gyro;
      Hc20MagnetometerData? mag;
      
      // Parse in order: Acce → Gyro → Mag
      if ((flag & 0x01) != 0 && currentOffset + 6 <= payload.length) {
        final x = _le16s(payload, currentOffset); currentOffset += 2;
        final y = _le16s(payload, currentOffset); currentOffset += 2;
        final z = _le16s(payload, currentOffset); currentOffset += 2;
        accel = Hc20AccelerometerData(x, y, z);
      }
      if ((flag & 0x02) != 0 && currentOffset + 6 <= payload.length) {
        final x = _le16s(payload, currentOffset); currentOffset += 2;
        final y = _le16s(payload, currentOffset); currentOffset += 2;
        final z = _le16s(payload, currentOffset); currentOffset += 2;
        gyro = Hc20GyroscopeData(x, y, z);
      }
      if ((flag & 0x04) != 0 && currentOffset + 6 <= payload.length) {
        final x = _le16s(payload, currentOffset); currentOffset += 2;
        final y = _le16s(payload, currentOffset); currentOffset += 2;
        final z = _le16s(payload, currentOffset); currentOffset += 2;
        mag = Hc20MagnetometerData(x, y, z);
      }
      
      // Calculate timestamp for this sample
      // For multiple samples, interpolate timestamps based on sample rate (104Hz)
      int sampleTimestamp = ts;
      if (sampleCount > 1 && sampleIndex > 0) {
        // Timestamp increments by sample interval for each subsequent sample
        sampleTimestamp = ts + (sampleIndex * imuSampleIntervalMs).round();
      }
      
      results.add(Hc20ImuData(
        timestampMs: sampleTimestamp,
        packetId: pid,
        accelerometer: accel,
        gyroscope: gyro,
        magnetometer: mag,
      ));
    }
    
    return results;
  }

  // Returns list because one packet may contain multiple samples at high rates
  // PPG is configured at 100Hz, so sample interval is 10ms per sample
  static List<Hc20PpgData> parsePpgData(Uint8List payload) {
    final results = <Hc20PpgData>[];
    int o = 0;
    if (payload.isEmpty || payload[o++] != 0x82) return results;
    
    final flag = payload[o++];
    final pid = _le32(payload, o); o += 4;
    final ts = _le32(payload, o); o += 4;
    
    // Validate packet header - reject packets with invalid packet_id and timestamp
    // This indicates an incomplete/corrupted packet that may cause duplicate entries
    if (pid == 0 && ts == 0) {
      Hc20CloudConfig.debugPrint('[HC20 PPG Parser] WARNING: Rejecting packet with invalid header (packet_id=0, timestamp=0). This may indicate an incomplete/corrupted packet.');
      return results;
    }
    
    // Calculate bytes per sample
    int bytesPerSample = 0;
    if ((flag & 0x01) != 0) bytesPerSample += 3; // Green
    if ((flag & 0x02) != 0) bytesPerSample += 3; // Red
    if ((flag & 0x04) != 0) bytesPerSample += 3; // IR
    
    if (bytesPerSample == 0) return results;
    
    // Check if packet contains multiple samples
    final remainingBytes = payload.length - o;
    final sampleCount = remainingBytes ~/ bytesPerSample;
    
    // PPG sample rate is 100Hz, so interval is 10ms per sample
    const int ppgSampleIntervalMs = 10;
    
    // Parse all samples in the packet
    for (int sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
      int currentOffset = o + (sampleIndex * bytesPerSample);
      int? g, r, ir;
      
      if ((flag & 0x01) != 0 && currentOffset + 3 <= payload.length) {
        g = _le24(payload, currentOffset); currentOffset += 3;
      }
      if ((flag & 0x02) != 0 && currentOffset + 3 <= payload.length) {
        r = _le24(payload, currentOffset); currentOffset += 3;
      }
      if ((flag & 0x04) != 0 && currentOffset + 3 <= payload.length) {
        ir = _le24(payload, currentOffset); currentOffset += 3;
      }
      
      // Calculate timestamp for this sample
      int sampleTimestamp = ts;
      if (sampleCount > 1 && sampleIndex > 0) {
        sampleTimestamp = ts + (sampleIndex * ppgSampleIntervalMs);
      }
      
      results.add(Hc20PpgData(
        timestampMs: sampleTimestamp,
        packetId: pid,
        green: g,
        red: r,
        ir: ir,
      ));
    }
    
    return results;
  }

  // GSR is configured at 8Hz, so sample interval is 125ms per sample
  static List<Hc20GsrData> parseGsrData(Uint8List payload) {
    int o = 0;
    if (payload.isEmpty || payload[o++] != 0x84) return const [];
    o++; // skip reserved flag
    final pid = _le32(payload, o); o += 4;
    final ts = _le32(payload, o); o += 4;
    
    // Validate packet header - reject packets with invalid packet_id and timestamp
    // This indicates an incomplete/corrupted packet that may cause duplicate entries
    if (pid == 0 && ts == 0) {
      Hc20CloudConfig.debugPrint('[HC20 GSR Parser] WARNING: Rejecting packet with invalid header (packet_id=0, timestamp=0). This may indicate an incomplete/corrupted packet.');
      return const [];
    }
    
    // GSR sample rate is 8Hz, so interval is 125ms per sample
    const int gsrSampleIntervalMs = 125;
    const int bytesPerGsrSample = 9; // 3B I + 3B Q + 3B RAW
    
    final out = <Hc20GsrData>[];
    int sampleIndex = 0;
    while (o + bytesPerGsrSample <= payload.length) {
      final i = _le24(payload, o); o += 3;
      final q = _le24(payload, o); o += 3;
      final raw = _le24(payload, o); o += 3;
      
      // Calculate timestamp for this sample
      int sampleTimestamp = ts;
      if (sampleIndex > 0) {
        sampleTimestamp = ts + (sampleIndex * gsrSampleIntervalMs);
      }
      
      out.add(Hc20GsrData(
        timestampMs: sampleTimestamp,
        packetId: pid,
        i: i,
        q: q,
        raw: raw,
      ));
      sampleIndex++;
    }
    return out;
  }

  static int _le16s(Uint8List b, int o) {
    final v = b[o] | (b[o+1] << 8);
    return (v & 0x8000) != 0 ? v - 0x10000 : v;
    }
  static int _le24(Uint8List b, int o) => b[o] | (b[o+1] << 8) | (b[o+2] << 16);
  static int _le32(Uint8List b, int o) => b[o] | (b[o+1] << 8) | (b[o+2] << 16) | (b[o+3] << 24);
}


