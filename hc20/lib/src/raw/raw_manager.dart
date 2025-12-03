import 'dart:async';
import 'dart:typed_data';
import '../core/transport.dart' show IHc20Transport;
import '../models/raw_models.dart' show ImuSample, PpgSample, GsrSample;
import 'parsers.dart';
import 'uploader.dart';
import 'config.dart';

class RawManager {
  final IHc20Transport _tx;
  final RawDataUploader _uploader;
  String? _deviceId;
  String? _macAddress;
  StreamSubscription? _sensorSub;

  // Batch sizes for sensor data uploads
  static const int _imuBatchSize = 1000;
  static const int _ppgBatchSize = 1000;
  static const int _gsrBatchSize = 100;

  // Buffers for batching sensor data
  final List<ImuSample> _imuBuffer = [];
  final List<PpgSample> _ppgBuffer = [];
  final List<GsrSample> _gsrBuffer = [];
  
  // Store raw payloads per packet_id (map of packet_id -> raw_payload)
  final Map<int, Uint8List> _imuRawPayloads = {};
  final Map<int, Uint8List> _ppgRawPayloads = {};
  final Map<int, Uint8List> _gsrRawPayloads = {};
  
  // Track batch construction start times
  DateTime? _imuBatchStartTime;
  DateTime? _ppgBatchStartTime;
  DateTime? _gsrBatchStartTime;
  
  // Track packet counts for batch statistics
  int _imuPacketCount = 0;
  int _ppgPacketCount = 0;
  int _gsrPacketCount = 0;

  RawManager(this._tx, {required RawUploadConfig uploadConfig})
      : _uploader = HttpRawDataUploader(uploadConfig);

  /// Set the MAC address for uploads. This should be called before enabling sensors.
  /// The MAC address is obtained from readDeviceInfo() in Hc20Client.
  void setMacAddress(String mac) {
    if (mac.isEmpty) {
      Hc20CloudConfig.debugPrint('[HC20 RawManager] Warning: Empty MAC address provided');
      return;
    }
    _macAddress = mac;
    Hc20CloudConfig.debugPrint('[HC20 RawManager] MAC address set: $_macAddress');
  }

  Future<void> start(String deviceId) async {
    _deviceId = deviceId;
    
    // Set up listeners - MAC address will be read when sensors are enabled
    Hc20CloudConfig.debugPrint('[HC20 RawManager] Starting raw manager for device: $deviceId');
    
    // Listen for realtime V2 (0x85) and upload a compact payload (always on)
    _tx.notifications(deviceId).where((f) => f.func == 0x85).listen((f) async {
      try {
        // final s = utf8.decode(f.payload.sublist(1, f.payload.lastIndexOf(0x00)));
        // final m = json.decode(s) as Map<String, dynamic>;
        // final rt = Hc20RealtimeV2.fromMap(m);
        // await _uploader.uploadRealtime({
        //   'ts': m['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        //   'mac': m['mac'] ?? '',
        //   'rri': rt.rri,
        //   'wear': rt.wear,
        //   'hrv': rt.hrvMetrics == null ? null : {
        //     'sdnn': rt.hrvMetrics!.sdnn,
        //     'tp': rt.hrvMetrics!.tp,
        //     'lf': rt.hrvMetrics!.lf,
        //     'hf': rt.hrvMetrics!.hf,
        //     'vlf': rt.hrvMetrics!.vlf,
        //   },
        //   'hrv2': rt.hrv2Metrics == null ? null : {
        //     'ment_stress': rt.hrv2Metrics!.mentStress,
        //     'fatigue_level': rt.hrv2Metrics!.fatigueLevel,
        //     'stress_res': rt.hrv2Metrics!.stressResistance,
        //     'reg_ablty': rt.hrv2Metrics!.regulationAbility,
        //   },
        // });
      } catch (_) {}
    });

    // Automatically listen for raw sensor packets (0xB0) and upload immediately with all samples from the packet
    _sensorSub = _tx.notifications(deviceId).where((f) => f.func == 0xB0).listen((f) async {
      if (f.payload.isEmpty) {
        Hc20CloudConfig.debugPrint('[HC20 RawManager] Empty payload received, skipping');
        return;
      }
      if (_deviceId == null) {
        Hc20CloudConfig.debugPrint('[HC20 RawManager] Device ID is null, skipping upload');
        return;
      }
      if (_macAddress == null) {
        Hc20CloudConfig.debugPrint('[HC20 RawManager] MAC address is null, skipping upload');
        return;
      }
      
      try {
        final kind = f.payload[0];
        final rawPayload = Uint8List.fromList(f.payload);
        
        // Use MAC address for device_id field in uploads
        final deviceIdForUpload = _macAddress!;
        
        if (kind == 0x81) {
          // IMU data - accumulate samples in buffer and upload when batch size is reached
          final samples = RawParsers.parseImu(f.payload);
          if (samples.isNotEmpty) {
            // Track start time for first packet in batch
            if (_imuRawPayloads.isEmpty) {
              _imuBatchStartTime = DateTime.now();
              _imuPacketCount = 0;
            }
            // Store raw payload for each packet_id (all samples from same packet have same packet_id)
            final packetId = samples.first.packetId;
            
            // Check if we've already seen this packet_id with a different raw payload
            // This can happen if the same packet is received multiple times or if there's a collision
            if (_imuRawPayloads.containsKey(packetId)) {
              final existingPayload = _imuRawPayloads[packetId]!;
              if (existingPayload.length != rawPayload.length || 
                  !_arePayloadsEqual(existingPayload, rawPayload)) {
                Hc20CloudConfig.debugPrint('[HC20 RawManager] WARNING: Duplicate packet_id=$packetId detected with different payload. This may indicate duplicate packet reception or packet_id collision.');
                Hc20CloudConfig.debugPrint('[HC20 RawManager] Existing payload length: ${existingPayload.length}, new payload length: ${rawPayload.length}');
              }
            }
            
            _imuRawPayloads[packetId] = rawPayload;
            _imuPacketCount++;
            _imuBuffer.addAll(samples);
            Hc20CloudConfig.debugPrint('[HC20 RawManager] IMU packet #$_imuPacketCount (packet_id=$packetId): ${samples.length} sample(s), buffer: ${_imuBuffer.length}/${_imuBatchSize}');
            
            // Upload if batch size reached
            if (_imuBuffer.length >= _imuBatchSize) {
              await _flushImuBuffer(deviceIdForUpload);
            }
          } else {
            Hc20CloudConfig.debugPrint('[HC20 RawManager] IMU packet has no samples, skipping');
          }
        } else if (kind == 0x82) {
          // PPG data - accumulate samples in buffer and upload when batch size is reached
          final samples = RawParsers.parsePpg(f.payload);
          if (samples.isNotEmpty) {
            // Track start time for first packet in batch
            if (_ppgRawPayloads.isEmpty) {
              _ppgBatchStartTime = DateTime.now();
              _ppgPacketCount = 0;
            }
            // Store raw payload for each packet_id (all samples from same packet have same packet_id)
            final packetId = samples.first.packetId;
            
            // Check if we've already seen this packet_id with a different raw payload
            // This can happen if the same packet is received multiple times or if there's a collision
            if (_ppgRawPayloads.containsKey(packetId)) {
              final existingPayload = _ppgRawPayloads[packetId]!;
              if (existingPayload.length != rawPayload.length || 
                  !_arePayloadsEqual(existingPayload, rawPayload)) {
                Hc20CloudConfig.debugPrint('[HC20 RawManager] WARNING: Duplicate packet_id=$packetId detected with different payload. This may indicate duplicate packet reception or packet_id collision.');
                Hc20CloudConfig.debugPrint('[HC20 RawManager] Existing payload length: ${existingPayload.length}, new payload length: ${rawPayload.length}');
              }
            }
            
            _ppgRawPayloads[packetId] = rawPayload;
            _ppgPacketCount++;
            _ppgBuffer.addAll(samples);
            Hc20CloudConfig.debugPrint('[HC20 RawManager] PPG packet #$_ppgPacketCount (packet_id=$packetId): ${samples.length} sample(s), buffer: ${_ppgBuffer.length}/${_ppgBatchSize}');
            
            // Upload if batch size reached
            if (_ppgBuffer.length >= _ppgBatchSize) {
              await _flushPpgBuffer(deviceIdForUpload);
            }
          } else {
            Hc20CloudConfig.debugPrint('[HC20 RawManager] PPG packet has no samples, skipping');
          }
        } else if (kind == 0x84) {
          // GSR data - accumulate samples in buffer and upload when batch size is reached
          final samples = RawParsers.parseGsr(f.payload);
          if (samples.isNotEmpty) {
            // Track start time for first packet in batch
            if (_gsrRawPayloads.isEmpty) {
              _gsrBatchStartTime = DateTime.now();
              _gsrPacketCount = 0;
            }
            // Store raw payload for each packet_id (all samples from same packet have same packet_id)
            final packetId = samples.first.packetId;
            
            // Check if we've already seen this packet_id with a different raw payload
            // This can happen if the same packet is received multiple times or if there's a collision
            if (_gsrRawPayloads.containsKey(packetId)) {
              final existingPayload = _gsrRawPayloads[packetId]!;
              if (existingPayload.length != rawPayload.length || 
                  !_arePayloadsEqual(existingPayload, rawPayload)) {
                Hc20CloudConfig.debugPrint('[HC20 RawManager] WARNING: Duplicate packet_id=$packetId detected with different payload. This may indicate duplicate packet reception or packet_id collision.');
                Hc20CloudConfig.debugPrint('[HC20 RawManager] Existing payload length: ${existingPayload.length}, new payload length: ${rawPayload.length}');
              }
            }
            
            _gsrRawPayloads[packetId] = rawPayload;
            _gsrPacketCount++;
            _gsrBuffer.addAll(samples);
            Hc20CloudConfig.debugPrint('[HC20 RawManager] GSR packet #$_gsrPacketCount (packet_id=$packetId): ${samples.length} sample(s), buffer: ${_gsrBuffer.length}/${_gsrBatchSize}');
            
            // Upload if batch size reached
            if (_gsrBuffer.length >= _gsrBatchSize) {
              await _flushGsrBuffer(deviceIdForUpload);
            }
          } else {
            Hc20CloudConfig.debugPrint('[HC20 RawManager] GSR packet has no samples, skipping');
          }
        }
      } catch (e) {
        // Log error but don't let it crash the stream
        // Network errors are expected when offline and are handled in the uploader
        final errorStr = e.toString().toLowerCase();
        if (!errorStr.contains('host lookup') && 
            !errorStr.contains('network') && 
            !errorStr.contains('connection')) {
          // Only log non-network errors to reduce log spam
          Hc20CloudConfig.debugPrint('[HC20 RawManager] Error processing sensor packet: $e');
        }
        // Continue processing - don't let upload failures stop sensor streaming
      }
    });
  }

  Future<void> stop() async {
    await _sensorSub?.cancel();
    _sensorSub = null;
    
    // Flush any remaining samples in buffers
    if (_macAddress != null) {
      final deviceIdForUpload = _macAddress!;
      if (_imuBuffer.isNotEmpty) {
        Hc20CloudConfig.debugPrint('[HC20 RawManager] Flushing ${_imuBuffer.length} remaining IMU samples');
        await _flushImuBuffer(deviceIdForUpload);
      }
      if (_ppgBuffer.isNotEmpty) {
        Hc20CloudConfig.debugPrint('[HC20 RawManager] Flushing ${_ppgBuffer.length} remaining PPG samples');
        await _flushPpgBuffer(deviceIdForUpload);
      }
      if (_gsrBuffer.isNotEmpty) {
        Hc20CloudConfig.debugPrint('[HC20 RawManager] Flushing ${_gsrBuffer.length} remaining GSR samples');
        await _flushGsrBuffer(deviceIdForUpload);
      }
    }
  }

  /// Flush IMU buffer and upload
  Future<void> _flushImuBuffer(String deviceId) async {
    if (_imuBuffer.isEmpty || _imuRawPayloads.isEmpty) return;
    
    try {
      final samplesToUpload = List<ImuSample>.from(_imuBuffer);
      final rawPayloadsMap = Map<int, Uint8List>.from(_imuRawPayloads);
      
      // Calculate batch construction time
      final batchConstructionTime = _imuBatchStartTime != null 
          ? DateTime.now().difference(_imuBatchStartTime!)
          : null;
      
      // Calculate statistics
      final packetCount = _imuPacketCount;
      final avgSamplesPerPacket = packetCount > 0 ? (samplesToUpload.length / packetCount).toStringAsFixed(1) : '0';
      final effectiveSampleRate = batchConstructionTime != null && batchConstructionTime.inMilliseconds > 0
          ? (samplesToUpload.length * 1000 / batchConstructionTime.inMilliseconds).toStringAsFixed(1)
          : '0';
      
      // Save batch start time BEFORE clearing it (needed for Unix timestamp conversion)
      final batchStartTime = _imuBatchStartTime;
      
      // Clear buffer, payloads, start time, and packet count
      _imuBuffer.clear();
      _imuRawPayloads.clear();
      _imuBatchStartTime = null;
      _imuPacketCount = 0;
      
      // Log batch info with construction time and statistics
      final batchTimeStr = batchConstructionTime != null
          ? ', batch construction time: ${batchConstructionTime.inMilliseconds}ms (${(batchConstructionTime.inSeconds).toStringAsFixed(2)}s)'
          : '';
      Hc20CloudConfig.debugPrint('[HC20 RawManager] Uploading IMU batch: ${samplesToUpload.length} sample(s) from $packetCount packet(s) (avg ${avgSamplesPerPacket} samples/packet)$batchTimeStr, effective rate: ${effectiveSampleRate} samples/s');
      
      // Track upload time
      final uploadStartTime = DateTime.now();
      // Use batch start time as base for Unix timestamp conversion
      final baseUnixTimestamp = batchStartTime?.millisecondsSinceEpoch;
      // Use first payload as fallback for uploader (uploader will use per-sample payloads from the map)
      final firstPayload = rawPayloadsMap.values.isNotEmpty ? rawPayloadsMap.values.first : Uint8List(0);
      await _uploader.uploadImu(samplesToUpload, deviceId, firstPayload, baseUnixTimestampMs: baseUnixTimestamp, rawPayloadsByPacketId: rawPayloadsMap);
      final uploadTime = DateTime.now().difference(uploadStartTime);
      Hc20CloudConfig.debugPrint('[HC20 RawManager] IMU batch upload completed, upload time: ${uploadTime.inMilliseconds}ms (${(uploadTime.inSeconds).toStringAsFixed(2)}s)');
    } catch (e) {
      // Log error but don't rethrow - allow streaming to continue
      final errorStr = e.toString().toLowerCase();
      if (!errorStr.contains('host lookup') && 
          !errorStr.contains('network') && 
          !errorStr.contains('connection')) {
        Hc20CloudConfig.debugPrint('[HC20 RawManager] Error uploading IMU batch: $e');
      }
      // Reset start time and packet count on error
      _imuBatchStartTime = null;
      _imuPacketCount = 0;
    }
  }

  /// Flush PPG buffer and upload
  Future<void> _flushPpgBuffer(String deviceId) async {
    if (_ppgBuffer.isEmpty || _ppgRawPayloads.isEmpty) return;
    
    try {
      final samplesToUpload = List<PpgSample>.from(_ppgBuffer);
      final rawPayloadsMap = Map<int, Uint8List>.from(_ppgRawPayloads);
      
      // Calculate batch construction time
      final batchConstructionTime = _ppgBatchStartTime != null 
          ? DateTime.now().difference(_ppgBatchStartTime!)
          : null;
      
      // Calculate statistics
      final packetCount = _ppgPacketCount;
      final avgSamplesPerPacket = packetCount > 0 ? (samplesToUpload.length / packetCount).toStringAsFixed(1) : '0';
      final effectiveSampleRate = batchConstructionTime != null && batchConstructionTime.inMilliseconds > 0
          ? (samplesToUpload.length * 1000 / batchConstructionTime.inMilliseconds).toStringAsFixed(1)
          : '0';
      
      // Save batch start time BEFORE clearing it (needed for Unix timestamp conversion)
      final batchStartTime = _ppgBatchStartTime;
      
      // Clear buffer, payloads, start time, and packet count
      _ppgBuffer.clear();
      _ppgRawPayloads.clear();
      _ppgBatchStartTime = null;
      _ppgPacketCount = 0;
      
      // Log batch info with construction time and statistics
      final batchTimeStr = batchConstructionTime != null
          ? ', batch construction time: ${batchConstructionTime.inMilliseconds}ms (${(batchConstructionTime.inSeconds).toStringAsFixed(2)}s)'
          : '';
      Hc20CloudConfig.debugPrint('[HC20 RawManager] Uploading PPG batch: ${samplesToUpload.length} sample(s) from $packetCount packet(s) (avg ${avgSamplesPerPacket} samples/packet)$batchTimeStr, effective rate: ${effectiveSampleRate} samples/s');
      
      // Track upload time
      final uploadStartTime = DateTime.now();
      // Use batch start time as base for Unix timestamp conversion
      final baseUnixTimestamp = batchStartTime?.millisecondsSinceEpoch;
      // Use first payload as fallback for uploader (uploader will use per-sample payloads from the map)
      final firstPayload = rawPayloadsMap.values.isNotEmpty ? rawPayloadsMap.values.first : Uint8List(0);
      await _uploader.uploadPpg(samplesToUpload, deviceId, firstPayload, baseUnixTimestampMs: baseUnixTimestamp, rawPayloadsByPacketId: rawPayloadsMap);
      final uploadTime = DateTime.now().difference(uploadStartTime);
      Hc20CloudConfig.debugPrint('[HC20 RawManager] PPG batch upload completed, upload time: ${uploadTime.inMilliseconds}ms (${(uploadTime.inSeconds).toStringAsFixed(2)}s)');
    } catch (e) {
      // Log error but don't rethrow - allow streaming to continue
      final errorStr = e.toString().toLowerCase();
      if (!errorStr.contains('host lookup') && 
          !errorStr.contains('network') && 
          !errorStr.contains('connection')) {
        Hc20CloudConfig.debugPrint('[HC20 RawManager] Error uploading PPG batch: $e');
      }
      // Reset start time and packet count on error
      _ppgBatchStartTime = null;
      _ppgPacketCount = 0;
    }
  }

  /// Flush GSR buffer and upload
  Future<void> _flushGsrBuffer(String deviceId) async {
    if (_gsrBuffer.isEmpty || _gsrRawPayloads.isEmpty) return;
    
    try {
      final samplesToUpload = List<GsrSample>.from(_gsrBuffer);
      final rawPayloadsMap = Map<int, Uint8List>.from(_gsrRawPayloads);
      
      // Calculate batch construction time
      final batchConstructionTime = _gsrBatchStartTime != null 
          ? DateTime.now().difference(_gsrBatchStartTime!)
          : null;
      
      // Calculate statistics
      final packetCount = _gsrPacketCount;
      final avgSamplesPerPacket = packetCount > 0 ? (samplesToUpload.length / packetCount).toStringAsFixed(1) : '0';
      final effectiveSampleRate = batchConstructionTime != null && batchConstructionTime.inMilliseconds > 0
          ? (samplesToUpload.length * 1000 / batchConstructionTime.inMilliseconds).toStringAsFixed(1)
          : '0';
      
      // Save batch start time BEFORE clearing it (needed for Unix timestamp conversion)
      final batchStartTime = _gsrBatchStartTime;
      
      // Clear buffer, payloads, start time, and packet count
      _gsrBuffer.clear();
      _gsrRawPayloads.clear();
      _gsrBatchStartTime = null;
      _gsrPacketCount = 0;
      
      // Log batch info with construction time and statistics
      final batchTimeStr = batchConstructionTime != null
          ? ', batch construction time: ${batchConstructionTime.inMilliseconds}ms (${(batchConstructionTime.inSeconds).toStringAsFixed(2)}s)'
          : '';
      Hc20CloudConfig.debugPrint('[HC20 RawManager] Uploading GSR batch: ${samplesToUpload.length} sample(s) from $packetCount packet(s) (avg ${avgSamplesPerPacket} samples/packet)$batchTimeStr, effective rate: ${effectiveSampleRate} samples/s');
      
      // Track upload time
      final uploadStartTime = DateTime.now();
      // Use batch start time as base for Unix timestamp conversion
      final baseUnixTimestamp = batchStartTime?.millisecondsSinceEpoch;
      // Use first payload as fallback for uploader (uploader will use per-sample payloads from the map)
      final firstPayload = rawPayloadsMap.values.isNotEmpty ? rawPayloadsMap.values.first : Uint8List(0);
      await _uploader.uploadGsr(samplesToUpload, deviceId, firstPayload, baseUnixTimestampMs: baseUnixTimestamp, rawPayloadsByPacketId: rawPayloadsMap);
      final uploadTime = DateTime.now().difference(uploadStartTime);
      Hc20CloudConfig.debugPrint('[HC20 RawManager] GSR batch upload completed, upload time: ${uploadTime.inMilliseconds}ms (${(uploadTime.inSeconds).toStringAsFixed(2)}s)');
    } catch (e) {
      // Log error but don't rethrow - allow streaming to continue
      final errorStr = e.toString().toLowerCase();
      if (!errorStr.contains('host lookup') && 
          !errorStr.contains('network') && 
          !errorStr.contains('connection')) {
        Hc20CloudConfig.debugPrint('[HC20 RawManager] Error uploading GSR batch: $e');
      }
      // Reset start time and packet count on error
      _gsrBatchStartTime = null;
      _gsrPacketCount = 0;
    }
  }

  /// Helper function to compare two payloads byte-by-byte
  bool _arePayloadsEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> uploadAllDayHrv(List<Map<String, dynamic>> hrvEntries, String mac) {
    return _uploader.uploadAllDayHrv(hrvEntries, mac);
  }

  Future<void> uploadAllDayRri(List<Map<String, dynamic>> rriEntries, String mac, int packetIndex, int totalPackets) {
    return _uploader.uploadAllDayRri(rriEntries, mac, packetIndex, totalPackets);
  }

  Future<void> uploadAllDayHrv2(List<Map<String, dynamic>> hrv2Entries, String mac) {
    return _uploader.uploadAllDayHrv2(hrv2Entries, mac);
  }
}


