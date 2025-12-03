import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/raw_models.dart';
import 'auth_service.dart';
import 'config.dart';

abstract class RawDataUploader {
  Future<void> uploadImu(List<ImuSample> samples, String mac, Uint8List rawPayload, {int? baseUnixTimestampMs, Map<int, Uint8List>? rawPayloadsByPacketId});
  Future<void> uploadPpg(List<PpgSample> samples, String mac, Uint8List rawPayload, {int? baseUnixTimestampMs, Map<int, Uint8List>? rawPayloadsByPacketId});
  Future<void> uploadGsr(List<GsrSample> samples, String mac, Uint8List rawPayload, {int? baseUnixTimestampMs, Map<int, Uint8List>? rawPayloadsByPacketId});
  Future<void> uploadRealtime(Map<String, dynamic> payload);
  Future<void> uploadAllDayHrv(List<Map<String, dynamic>> hrvEntries, String mac);
  Future<void> uploadAllDayRri(List<Map<String, dynamic>> rriEntries, String mac, int packetIndex, int totalPackets);
  Future<void> uploadAllDayHrv2(List<Map<String, dynamic>> hrv2Entries, String mac);
}

class RawUploadConfig {
  final String? baseUrl;
  final int batchSize;
  
  // OAuth credentials (clientId and clientSecret are required)
  final String? authUrl;
  final String clientId;
  final String clientSecret;
  final String? grantType;
  
  /// Create a config with cloud API defaults
  /// clientId and clientSecret are required
  const RawUploadConfig.cloud({
    this.baseUrl,
    this.batchSize = Hc20CloudConfig.batchSize,
    this.authUrl,
    required this.clientId,
    required this.clientSecret,
    this.grantType,
  });
  
  /// Constructor for backward compatibility
  const RawUploadConfig({
    this.baseUrl,
    this.batchSize = 100,
    this.authUrl,
    required this.clientId,
    required this.clientSecret,
    this.grantType,
  });
  
  /// Get effective values using cloud config as defaults
  String get effectiveBaseUrl => baseUrl ?? Hc20CloudConfig.baseUrl;
  String get effectiveAuthUrl => authUrl ?? Hc20CloudConfig.authUrl;
  String get effectiveClientId => clientId;
  String get effectiveClientSecret => clientSecret;
  String get effectiveGrantType => grantType ?? Hc20CloudConfig.grantType;
}

class HttpRawDataUploader implements RawDataUploader {
  final Dio _dio;
  final RawUploadConfig cfg;
  final Hc20AuthService _authService;
  bool _isRefreshing = false;

  HttpRawDataUploader(this.cfg) 
      : _authService = Hc20AuthService(
          authUrl: cfg.effectiveAuthUrl,
          clientId: cfg.effectiveClientId,
          clientSecret: cfg.effectiveClientSecret,
          grantType: cfg.effectiveGrantType,
        ),
        _dio = Dio(BaseOptions(
          baseUrl: cfg.effectiveBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    // Use authentication service for OAuth
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await _authService.getAccessToken();
          options.headers['Authorization'] = 'Bearer $token';
        } catch (e) {
          handler.reject(DioException(
            requestOptions: options,
            error: 'Failed to get access token: $e',
          ));
          return;
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 errors by refreshing token and retrying
        if (error.response?.statusCode == 401 && !_isRefreshing) {
          _isRefreshing = true;
          try {
            _authService.clearToken();
            final token = await _authService.getAccessToken();
            
            // Retry the request with new token
            final options = error.requestOptions;
            options.headers['Authorization'] = 'Bearer $token';
            
            final response = await _dio.fetch(options);
            _isRefreshing = false;
            handler.resolve(response);
            return;
          } catch (e) {
            _isRefreshing = false;
            handler.reject(DioException(
              requestOptions: error.requestOptions,
              error: 'Token refresh failed: $e',
            ));
            return;
          }
        }
        _isRefreshing = false;
        handler.next(error);
      },
      onResponse: (response, handler) {
        // Log successful uploads
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.data;
          if (data is Map<String, dynamic>) {
            final message = data['message']?.toString() ?? '';
            final count = data['count']?.toString() ?? '';
            if (message.isNotEmpty) {
              Hc20CloudConfig.debugPrint('[HC20 Cloud Upload] Success: $message${count.isNotEmpty ? ' (count: $count)' : ''}');
            }
          }
        }
        handler.next(response);
      },
    ));
  }

  /// Check if an error is a network-related error that should be handled gracefully
  bool _isNetworkError(dynamic error) {
    if (error is DioException) {
      final type = error.type;
      // Network errors: connection timeout, send timeout, receive timeout, connection error
      if (type == DioExceptionType.connectionTimeout ||
          type == DioExceptionType.sendTimeout ||
          type == DioExceptionType.receiveTimeout ||
          type == DioExceptionType.connectionError ||
          type == DioExceptionType.unknown) {
        // Check error message for network-related keywords
        final errorMsg = error.message?.toLowerCase() ?? '';
        final errorStr = error.toString().toLowerCase();
        return errorMsg.contains('host lookup') ||
            errorMsg.contains('network') ||
            errorMsg.contains('connection') ||
            errorMsg.contains('timeout') ||
            errorStr.contains('host lookup') ||
            errorStr.contains('network') ||
            errorStr.contains('connection') ||
            errorStr.contains('timeout');
      }
    }
    return false;
  }

  /// Handle upload with retry logic for network errors
  Future<void> _uploadWithRetry(
    String endpoint,
    Map<String, dynamic> payload,
    String logPrefix, {
    int maxRetries = 2,
  }) async {
    int attempt = 0;
    while (attempt <= maxRetries) {
      try {
        final response = await _dio.post(endpoint, data: payload);
        if (response.statusCode == 200 || response.statusCode == 201) {
          return; // Success
        }
        // Non-2xx response - don't retry
        Hc20CloudConfig.debugPrint('[$logPrefix] Unexpected status code: ${response.statusCode}');
        return;
      } catch (e) {
        attempt++;
        final isNetworkError = _isNetworkError(e);
        
        if (isNetworkError && attempt <= maxRetries) {
          // Network error - retry with exponential backoff
          final delaySeconds = attempt * 2; // 2s, 4s
          Hc20CloudConfig.debugPrint('[$logPrefix] Network error (attempt $attempt/${maxRetries + 1}), retrying in ${delaySeconds}s...');
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        } else {
          // Not a network error, or max retries reached - log and rethrow only if not network error
          if (isNetworkError) {
            Hc20CloudConfig.debugPrint('[$logPrefix] Network error after ${maxRetries + 1} attempts, giving up. Data will be lost.');
            return; // Don't rethrow network errors - they're expected when offline
          } else {
            // Non-network error - rethrow
            rethrow;
          }
        }
      }
    }
  }

  @override
  Future<void> uploadImu(List<ImuSample> samples, String mac, Uint8List rawPayload, {int? baseUnixTimestampMs, Map<int, Uint8List>? rawPayloadsByPacketId}) async {
    if (samples.isEmpty) {
      Hc20CloudConfig.debugPrint('[HC20 IMU Upload] No samples to upload');
      return;
    }
    
    Hc20CloudConfig.debugPrint('[HC20 IMU Upload] Preparing upload: ${samples.length} sample(s), MAC: $mac');
    
    // Get base Unix timestamp for conversion (use provided base or current time)
    final baseUnixTimestamp = baseUnixTimestampMs ?? DateTime.now().millisecondsSinceEpoch;
    // Use the first sample's device timestamp as reference
    final firstDeviceTs = samples.first.tsMs;
    
    // First, group samples by (packet_id, device_timestamp) to combine accel, gyro, and mag into one entry
    // Use device timestamp directly to avoid conversion issues
    // Multiple samples from the same packet will have same packet_id and raw_data, but different timestamps
    final tempGrouped = <String, Map<String, dynamic>>{}; // Key: "$pid:$deviceTs"
    
    for (final sample in samples) {
      final pid = sample.packetId;
      // Use device timestamp directly for grouping (should be unique per sample)
      final deviceTs = sample.tsMs;
      
      // Warn if packet_id and timestamp are both 0 (invalid header)
      if (pid == 0 && deviceTs == 0) {
        Hc20CloudConfig.debugPrint('[HC20 IMU Upload] WARNING: Sample with invalid header (packet_id=0, device_timestamp=0) detected. This should have been rejected by the parser.');
      }
      
      final key = '$pid:$deviceTs';
      
      if (!tempGrouped.containsKey(key)) {
        // Get the correct raw payload for this packet_id
        Uint8List sampleRawPayload;
        if (rawPayloadsByPacketId != null && rawPayloadsByPacketId.containsKey(pid)) {
          sampleRawPayload = rawPayloadsByPacketId[pid]!;
        } else {
          sampleRawPayload = rawPayload; // Fallback to single payload
          if (rawPayloadsByPacketId != null && !rawPayloadsByPacketId.isEmpty) {
            Hc20CloudConfig.debugPrint('[HC20 IMU Upload] WARNING: packet_id=$pid not found in rawPayloadsByPacketId map. Using fallback payload.');
          }
        }
        final rawDataHex = sampleRawPayload.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
        
        // Convert device timestamp to Unix timestamp for upload
        // Calculate relative offset from first sample and add to base Unix timestamp
        final deviceTsOffset = sample.tsMs - firstDeviceTs;
        final unixTimestamp = baseUnixTimestamp + deviceTsOffset;
        
        tempGrouped[key] = {
          'device_id': mac,
          'packet_id': pid,
          'device_timestamp': deviceTs, // Store device timestamp for deduplication
          'timestamp': unixTimestamp, // Unix timestamp for upload
          'data_transfer_flag': Hc20CloudConfig.dataTransferFlag,
          'accelerometer_x': null,
          'accelerometer_y': null,
          'accelerometer_z': null,
          'gyroscope_x': null,
          'gyroscope_y': null,
          'gyroscope_z': null,
          'magnetometer_x': null,
          'magnetometer_y': null,
          'magnetometer_z': null,
          'raw_data': rawDataHex,
        };
      }
      
      final entry = tempGrouped[key]!;
      // kind: 0=acc, 1=gyr, 2=mag
      if (sample.kind == 0) {
        entry['accelerometer_x'] = sample.x;
        entry['accelerometer_y'] = sample.y;
        entry['accelerometer_z'] = sample.z;
      } else if (sample.kind == 1) {
        entry['gyroscope_x'] = sample.x;
        entry['gyroscope_y'] = sample.y;
        entry['gyroscope_z'] = sample.z;
      } else if (sample.kind == 2) {
        entry['magnetometer_x'] = sample.x;
        entry['magnetometer_y'] = sample.y;
        entry['magnetometer_z'] = sample.z;
      }
    }
    
    // Now deduplicate by (packet_id, device_timestamp, all sensor values)
    // Use device timestamp (not Unix timestamp) for deduplication to avoid conversion issues
    // If (packet_id, device_timestamp, data) are all the same → skip (true duplicate)
    // If (packet_id, device_timestamp) are same but data is different → keep (upload)
    final grouped = <String, Map<String, dynamic>>{}; // Key includes all sensor values
    // Track (packet_id, timestamp) collisions for database uniqueness constraint
    final timestampCollisions = <String, int>{}; // Key: "$packet_id:$timestamp", Value: offset count
    
    for (final entry in tempGrouped.values) {
      // Create key with packet_id, device timestamp, and all sensor values
      // Use device_timestamp for consistency (should be unique per sample)
      // Handle null values by converting to string 'null' for consistent key generation
      final key = '${entry['packet_id']}:${entry['device_timestamp']}:'
          '${entry['accelerometer_x'] ?? 'null'}:${entry['accelerometer_y'] ?? 'null'}:${entry['accelerometer_z'] ?? 'null'}:'
          '${entry['gyroscope_x'] ?? 'null'}:${entry['gyroscope_y'] ?? 'null'}:${entry['gyroscope_z'] ?? 'null'}:'
          '${entry['magnetometer_x'] ?? 'null'}:${entry['magnetometer_y'] ?? 'null'}:${entry['magnetometer_z'] ?? 'null'}';
      
      // Skip if this exact entry already exists (true duplicate)
      if (grouped.containsKey(key)) {
        Hc20CloudConfig.debugPrint('[HC20 IMU Upload] Skipping duplicate entry: packet_id=${entry['packet_id']}, device_timestamp=${entry['device_timestamp']}');
        continue;
      }
      
      // Remove device_timestamp from entry before upload (it's only for deduplication)
      final uploadEntry = Map<String, dynamic>.from(entry);
      uploadEntry.remove('device_timestamp');
      
      // Check for (packet_id, timestamp) collision and adjust timestamp if needed
      // Database has unique constraint on (packet_id, timestamp), so we need to ensure uniqueness
      final packetId = uploadEntry['packet_id'] as int;
      final unixTimestamp = uploadEntry['timestamp'] as int;
      final collisionKey = '$packetId:$unixTimestamp';
      
      if (timestampCollisions.containsKey(collisionKey)) {
        // This (packet_id, timestamp) combination already exists, increment offset
        final offset = timestampCollisions[collisionKey]! + 1;
        timestampCollisions[collisionKey] = offset;
        uploadEntry['timestamp'] = unixTimestamp + offset;
        Hc20CloudConfig.debugPrint('[HC20 IMU Upload] Adjusting timestamp for database uniqueness: packet_id=$packetId, original_timestamp=$unixTimestamp, offset=$offset ms, adjusted_timestamp=${uploadEntry['timestamp']}');
      } else {
        // First occurrence of this (packet_id, timestamp) combination
        timestampCollisions[collisionKey] = 0;
      }
      
      // Add entry with unique (packet_id, device_timestamp, data) combination
      grouped[key] = uploadEntry;
    }
    
    // IMPORTANT: Deduplication is complete - grouped map only contains unique entries
    // Duplicates have been removed BEFORE JSON construction to prevent database errors
    if (grouped.isEmpty) {
      Hc20CloudConfig.debugPrint('[HC20 IMU Upload] No unique entries to upload after deduplication');
      return;
    }
    
    // Construct JSON payload ONLY from deduplicated entries (no duplicates in payload)
    final payload = {
      'data': grouped.values.toList(),
    };
    
    // Print JSON payload for debugging
    final jsonPayload = jsonEncode(payload);
    Hc20CloudConfig.debugPrint('[HC20 IMU Upload] JSON Payload:');
    Hc20CloudConfig.debugPrint(jsonPayload);
    final duplicatesRemoved = tempGrouped.length - grouped.length;
    if (duplicatesRemoved > 0) {
      Hc20CloudConfig.debugPrint('[HC20 IMU Upload] Removed $duplicatesRemoved duplicate entry/entries (same packet_id, timestamp, and sensor values)');
    }
    Hc20CloudConfig.debugPrint('[HC20 IMU Upload] Uploading to ${cfg.effectiveBaseUrl}/sensor/imu with ${grouped.length} entry/entries');
    
    try {
      await _uploadWithRetry('/sensor/imu', payload, 'HC20 IMU Upload');
      Hc20CloudConfig.debugPrint('[HC20 IMU Upload] Success: Uploaded ${grouped.length} entry/entries from ${samples.length} sample(s)');
    } catch (e, stackTrace) {
      // Only log non-network errors (network errors are already handled in _uploadWithRetry)
      if (!_isNetworkError(e)) {
        Hc20CloudConfig.debugPrint('[HC20 IMU Upload] Non-network error: $e');
        Hc20CloudConfig.debugPrint('[HC20 IMU Upload] Stack trace: $stackTrace');
        if (e is DioException) {
          Hc20CloudConfig.debugPrint('[HC20 IMU Upload] DioException details:');
          Hc20CloudConfig.debugPrint('  - Request: ${e.requestOptions.method} ${e.requestOptions.uri}');
          Hc20CloudConfig.debugPrint('  - Response: ${e.response?.statusCode} ${e.response?.statusMessage}');
          Hc20CloudConfig.debugPrint('  - Response data: ${e.response?.data}');
        }
        // Don't rethrow - allow sensor streaming to continue even if upload fails
      }
    }
  }

  @override
  Future<void> uploadPpg(List<PpgSample> samples, String mac, Uint8List rawPayload, {int? baseUnixTimestampMs, Map<int, Uint8List>? rawPayloadsByPacketId}) async {
    if (samples.isEmpty) {
      Hc20CloudConfig.debugPrint('[HC20 PPG Upload] No samples to upload');
      return;
    }
    
    Hc20CloudConfig.debugPrint('[HC20 PPG Upload] Preparing upload: ${samples.length} sample(s), MAC: $mac');
    
    // Get base Unix timestamp for conversion (use provided base or current time)
    final baseUnixTimestamp = baseUnixTimestampMs ?? DateTime.now().millisecondsSinceEpoch;
    // Use the first sample's device timestamp as reference
    final firstDeviceTs = samples.first.tsMs;
    
    // Group samples by (packet_id, device_timestamp, data) to deduplicate entries
    // Use device timestamp directly for deduplication to avoid conversion issues
    // If (packet_id, device_timestamp, data) are all the same → skip (true duplicate)
    // If (packet_id, device_timestamp) are same but data is different → keep (upload)
    final grouped = <String, Map<String, dynamic>>{}; // Key: "$pid:$deviceTs:$green:$red:$ir"
    // Track (packet_id, timestamp) collisions for database uniqueness constraint
    final timestampCollisions = <String, int>{}; // Key: "$packet_id:$timestamp", Value: offset count
    
    for (final sample in samples) {
      final pid = sample.packetId;
      // Use device timestamp directly for deduplication (should be unique per sample)
      final deviceTs = sample.tsMs;
      
      // Warn if packet_id and timestamp are both 0 (invalid header)
      if (pid == 0 && deviceTs == 0) {
        Hc20CloudConfig.debugPrint('[HC20 PPG Upload] WARNING: Sample with invalid header (packet_id=0, device_timestamp=0) detected. This should have been rejected by the parser.');
      }
      
      // Get the correct raw payload for this packet_id
      Uint8List sampleRawPayload;
      if (rawPayloadsByPacketId != null && rawPayloadsByPacketId.containsKey(pid)) {
        sampleRawPayload = rawPayloadsByPacketId[pid]!;
      } else {
        sampleRawPayload = rawPayload; // Fallback to single payload
        if (rawPayloadsByPacketId != null && !rawPayloadsByPacketId.isEmpty) {
          Hc20CloudConfig.debugPrint('[HC20 PPG Upload] WARNING: packet_id=$pid not found in rawPayloadsByPacketId map. Using fallback payload.');
        }
      }
      final rawDataHex = sampleRawPayload.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
      
      // Create key with packet_id, device timestamp, and all data values
      // Handle null values by converting to string 'null' for consistent key generation
      // If this exact combination exists, it's a true duplicate → skip
      final key = '$pid:$deviceTs:${sample.green ?? 'null'}:${sample.red ?? 'null'}:${sample.ir ?? 'null'}';
      
      // Skip if this exact entry already exists (true duplicate)
      if (grouped.containsKey(key)) {
        Hc20CloudConfig.debugPrint('[HC20 PPG Upload] Skipping duplicate entry: packet_id=$pid, device_timestamp=$deviceTs, green=${sample.green}, red=${sample.red}, ir=${sample.ir}');
        continue;
      }
      
      // Convert device timestamp to Unix timestamp for upload
      // Calculate relative offset from first sample and add to base Unix timestamp
      final deviceTsOffset = sample.tsMs - firstDeviceTs;
      int unixTimestamp = baseUnixTimestamp + deviceTsOffset;
      
      // Check for (packet_id, timestamp) collision and adjust timestamp if needed
      // Database has unique constraint on (packet_id, timestamp), so we need to ensure uniqueness
      final collisionKey = '$pid:$unixTimestamp';
      
      if (timestampCollisions.containsKey(collisionKey)) {
        // This (packet_id, timestamp) combination already exists, increment offset
        final offset = timestampCollisions[collisionKey]! + 1;
        timestampCollisions[collisionKey] = offset;
        unixTimestamp = unixTimestamp + offset;
        Hc20CloudConfig.debugPrint('[HC20 PPG Upload] Adjusting timestamp for database uniqueness: packet_id=$pid, original_timestamp=${baseUnixTimestamp + deviceTsOffset}, offset=$offset ms, adjusted_timestamp=$unixTimestamp');
      } else {
        // First occurrence of this (packet_id, timestamp) combination
        timestampCollisions[collisionKey] = 0;
      }
      
      // Add entry with unique (packet_id, device_timestamp, data) combination
      grouped[key] = {
        'device_id': mac,
        'packet_id': pid,
        'timestamp': unixTimestamp,
        'data_transfer_flag': 7,
        'led_green': sample.green,
        'led_red': sample.red,
        'led_ir': sample.ir,
        'raw_data': rawDataHex,
      };
    }
    
    // IMPORTANT: Deduplication is complete - grouped map only contains unique entries
    // Duplicates have been removed BEFORE JSON construction to prevent database errors
    if (grouped.isEmpty) {
      Hc20CloudConfig.debugPrint('[HC20 PPG Upload] No unique entries to upload after deduplication');
      return;
    }
    
    // Construct JSON payload ONLY from deduplicated entries (no duplicates in payload)
    final payload = {
      'data': grouped.values.toList(),
    };
    
    // Print JSON payload for debugging
    final jsonPayload = jsonEncode(payload);
    Hc20CloudConfig.debugPrint('[HC20 PPG Upload] JSON Payload:');
    Hc20CloudConfig.debugPrint(jsonPayload);
    final duplicatesRemoved = samples.length - grouped.length;
    if (duplicatesRemoved > 0) {
      Hc20CloudConfig.debugPrint('[HC20 PPG Upload] Removed $duplicatesRemoved duplicate sample(s) (same packet_id, timestamp, and data values)');
    }
    Hc20CloudConfig.debugPrint('[HC20 PPG Upload] Uploading to ${cfg.effectiveBaseUrl}/sensor/ppg with ${grouped.length} entry/entries');
    
    try {
      await _uploadWithRetry('/sensor/ppg', payload, 'HC20 PPG Upload');
      Hc20CloudConfig.debugPrint('[HC20 PPG Upload] Success: Uploaded ${grouped.length} entry/entries from ${samples.length} sample(s)');
    } catch (e, stackTrace) {
      // Only log non-network errors (network errors are already handled in _uploadWithRetry)
      if (!_isNetworkError(e)) {
        Hc20CloudConfig.debugPrint('[HC20 PPG Upload] Non-network error: $e');
        Hc20CloudConfig.debugPrint('[HC20 PPG Upload] Stack trace: $stackTrace');
        if (e is DioException) {
          Hc20CloudConfig.debugPrint('[HC20 PPG Upload] DioException details:');
          Hc20CloudConfig.debugPrint('  - Request: ${e.requestOptions.method} ${e.requestOptions.uri}');
          Hc20CloudConfig.debugPrint('  - Response: ${e.response?.statusCode} ${e.response?.statusMessage}');
          Hc20CloudConfig.debugPrint('  - Response data: ${e.response?.data}');
        }
        // Don't rethrow - allow sensor streaming to continue even if upload fails
      }
    }
  }

  @override
  Future<void> uploadGsr(List<GsrSample> samples, String mac, Uint8List rawPayload, {int? baseUnixTimestampMs, Map<int, Uint8List>? rawPayloadsByPacketId}) async {
    if (samples.isEmpty) {
      Hc20CloudConfig.debugPrint('[HC20 GSR Upload] No samples to upload');
      return;
    }
    
    Hc20CloudConfig.debugPrint('[HC20 GSR Upload] Preparing upload: ${samples.length} sample(s), MAC: $mac');
    
    // Get base Unix timestamp for conversion (use provided base or current time)
    final baseUnixTimestamp = baseUnixTimestampMs ?? DateTime.now().millisecondsSinceEpoch;
    // Use the first sample's device timestamp as reference
    final firstDeviceTs = samples.first.tsMs;
    
    // Group samples by (packet_id, device_timestamp, data) to deduplicate entries
    // Use device timestamp directly for deduplication to avoid conversion issues
    // If (packet_id, device_timestamp, data) are all the same → skip (true duplicate)
    // If (packet_id, device_timestamp) are same but data is different → keep (upload)
    final grouped = <String, Map<String, dynamic>>{}; // Key: "$pid:$deviceTs:$i:$q:$raw"
    // Track (packet_id, timestamp) collisions for database uniqueness constraint
    final timestampCollisions = <String, int>{}; // Key: "$packet_id:$timestamp", Value: offset count
    
    for (final sample in samples) {
      final pid = sample.packetId;
      // Use device timestamp directly for deduplication (should be unique per sample)
      final deviceTs = sample.tsMs;
      
      // Warn if packet_id and timestamp are both 0 (invalid header)
      if (pid == 0 && deviceTs == 0) {
        Hc20CloudConfig.debugPrint('[HC20 GSR Upload] WARNING: Sample with invalid header (packet_id=0, device_timestamp=0) detected. This should have been rejected by the parser.');
      }
      
      // Get the correct raw payload for this packet_id
      Uint8List sampleRawPayload;
      if (rawPayloadsByPacketId != null && rawPayloadsByPacketId.containsKey(pid)) {
        sampleRawPayload = rawPayloadsByPacketId[pid]!;
      } else {
        sampleRawPayload = rawPayload; // Fallback to single payload
        if (rawPayloadsByPacketId != null && !rawPayloadsByPacketId.isEmpty) {
          Hc20CloudConfig.debugPrint('[HC20 GSR Upload] WARNING: packet_id=$pid not found in rawPayloadsByPacketId map. Using fallback payload.');
        }
      }
      final rawDataHex = sampleRawPayload.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
      
      // Create key with packet_id, device timestamp, and all data values
      // GSR values (i, q, raw) are non-nullable, so no null handling needed
      // If this exact combination exists, it's a true duplicate → skip
      final key = '$pid:$deviceTs:${sample.i}:${sample.q}:${sample.raw}';
      
      // Skip if this exact entry already exists (true duplicate)
      if (grouped.containsKey(key)) {
        Hc20CloudConfig.debugPrint('[HC20 GSR Upload] Skipping duplicate entry: packet_id=$pid, device_timestamp=$deviceTs, i=${sample.i}, q=${sample.q}, raw=${sample.raw}');
        continue;
      }
      
      // Convert device timestamp to Unix timestamp for upload
      // Calculate relative offset from first sample and add to base Unix timestamp
      final deviceTsOffset = sample.tsMs - firstDeviceTs;
      int unixTimestamp = baseUnixTimestamp + deviceTsOffset;
      
      // Check for (packet_id, timestamp) collision and adjust timestamp if needed
      // Database has unique constraint on (packet_id, timestamp), so we need to ensure uniqueness
      final collisionKey = '$pid:$unixTimestamp';
      
      if (timestampCollisions.containsKey(collisionKey)) {
        // This (packet_id, timestamp) combination already exists, increment offset
        final offset = timestampCollisions[collisionKey]! + 1;
        timestampCollisions[collisionKey] = offset;
        unixTimestamp = unixTimestamp + offset;
        Hc20CloudConfig.debugPrint('[HC20 GSR Upload] Adjusting timestamp for database uniqueness: packet_id=$pid, original_timestamp=${baseUnixTimestamp + deviceTsOffset}, offset=$offset ms, adjusted_timestamp=$unixTimestamp');
      } else {
        // First occurrence of this (packet_id, timestamp) combination
        timestampCollisions[collisionKey] = 0;
      }
      
      // Add entry with unique (packet_id, device_timestamp, data) combination
      grouped[key] = {
        'device_id': mac,
        'packet_id': pid,
        'timestamp': unixTimestamp,
        'reserved_flag': 0,
        'gsr_i': sample.i,
        'gsr_q': sample.q,
        'gsr_raw': sample.raw,
        'raw_data': rawDataHex,
      };
    }
    
    // IMPORTANT: Deduplication is complete - grouped map only contains unique entries
    // Duplicates have been removed BEFORE JSON construction to prevent database errors
    if (grouped.isEmpty) {
      Hc20CloudConfig.debugPrint('[HC20 GSR Upload] No unique entries to upload after deduplication');
      return;
    }
    
    // Construct JSON payload ONLY from deduplicated entries (no duplicates in payload)
    final payload = {
      'data': grouped.values.toList(),
    };
    
    // Print JSON payload for debugging
    final jsonPayload = jsonEncode(payload);
    Hc20CloudConfig.debugPrint('[HC20 GSR Upload] JSON Payload:');
    Hc20CloudConfig.debugPrint(jsonPayload);
    final duplicatesRemoved = samples.length - grouped.length;
    if (duplicatesRemoved > 0) {
      Hc20CloudConfig.debugPrint('[HC20 GSR Upload] Removed $duplicatesRemoved duplicate sample(s) (same packet_id, timestamp, and data values)');
    }
    Hc20CloudConfig.debugPrint('[HC20 GSR Upload] Uploading to ${cfg.effectiveBaseUrl}/sensor/gsr with ${grouped.length} entry/entries');
    
    try {
      await _uploadWithRetry('/sensor/gsr', payload, 'HC20 GSR Upload');
      Hc20CloudConfig.debugPrint('[HC20 GSR Upload] Success: Uploaded ${grouped.length} entry/entries from ${samples.length} sample(s)');
    } catch (e, stackTrace) {
      // Only log non-network errors (network errors are already handled in _uploadWithRetry)
      if (!_isNetworkError(e)) {
        Hc20CloudConfig.debugPrint('[HC20 GSR Upload] Non-network error: $e');
        Hc20CloudConfig.debugPrint('[HC20 GSR Upload] Stack trace: $stackTrace');
        if (e is DioException) {
          Hc20CloudConfig.debugPrint('[HC20 GSR Upload] DioException details:');
          Hc20CloudConfig.debugPrint('  - Request: ${e.requestOptions.method} ${e.requestOptions.uri}');
          Hc20CloudConfig.debugPrint('  - Response: ${e.response?.statusCode} ${e.response?.statusMessage}');
          Hc20CloudConfig.debugPrint('  - Response data: ${e.response?.data}');
        }
        // Don't rethrow - allow sensor streaming to continue even if upload fails
      }
    }
  }

  @override
  Future<void> uploadRealtime(Map<String, dynamic> payload) async {
    try {
      await _uploadWithRetry('/realtime', payload, 'HC20 Realtime Upload', maxRetries: 1);
    } catch (e) {
      // Silently ignore network errors for realtime data
      if (!_isNetworkError(e)) {
        Hc20CloudConfig.debugPrint('[HC20 Realtime Upload] Error: $e');
      }
    }
  }

  @override
  Future<void> uploadAllDayHrv(List<Map<String, dynamic>> hrvEntries, String mac) async {
    if (hrvEntries.isEmpty) {
      Hc20CloudConfig.debugPrint('[HC20 HRV Upload] No entries to upload');
      return;
    }
    
    Hc20CloudConfig.debugPrint('[HC20 HRV Upload] Preparing upload: ${hrvEntries.length} entry/entries, MAC: $mac');
    
    // Helper function to convert ISO dateTime string to unix timestamp (milliseconds)
    int _isoToUnixTimestamp(String isoString) {
      try {
        // Parse ISO string like "2025-01-01T12:00:00" or "2025-01-01T12:00:00.000"
        final dt = DateTime.parse(isoString);
        return dt.millisecondsSinceEpoch;
      } catch (e) {
        Hc20CloudConfig.debugPrint('[HC20 HRV Upload] Error parsing timestamp "$isoString": $e');
        return 0;
      }
    }
    
    // Batch entries into groups of 100
    const batchSize = 500;
    final batches = <List<Map<String, dynamic>>>[];
    
    for (int i = 0; i < hrvEntries.length; i += batchSize) {
      final end = (i + batchSize < hrvEntries.length) ? i + batchSize : hrvEntries.length;
      batches.add(hrvEntries.sublist(i, end));
    }
    
    Hc20CloudConfig.debugPrint('[HC20 HRV Upload] Split into ${batches.length} batch/batches (${batches.length} × up to $batchSize entries)');
    
    // Upload each batch
    for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      final batch = batches[batchIndex];
      final entries = <Map<String, dynamic>>[];
      
      for (final entry in batch) {
        final dateTimeStr = entry['dateTime'] as String?;
        final values = entry['values'] as Map<String, dynamic>?;
        final valid = entry['valid'] as bool? ?? false;
        
        if (dateTimeStr == null || values == null) {
          Hc20CloudConfig.debugPrint('[HC20 HRV Upload] Skipping entry with missing dateTime or values');
          continue;
        }
        
        // Skip invalid entries
        if (!valid) {
          continue;
        }
        
        // Convert ISO dateTime to unix timestamp
        final timestamp = _isoToUnixTimestamp(dateTimeStr);
        if (timestamp == 0) {
          Hc20CloudConfig.debugPrint('[HC20 HRV Upload] Skipping entry with invalid timestamp: $dateTimeStr');
          continue;
        }
        
        // Extract HRV values
        final sdnn = values['sdnn'] as num?;
        final tp = values['tp'] as num?;
        final lf = values['lf'] as num?;
        final hf = values['hf'] as num?;
        final vlf = values['vlf'] as num?;
        
        // Only include entries with all required values
        if (sdnn == null || tp == null || lf == null || hf == null || vlf == null) {
          continue;
        }
        
        entries.add({
          'device_id': mac,
          'timestamp': timestamp,
          'sdnn': sdnn.toDouble(),
          'tp': tp.toDouble(),
          'lf': lf.toDouble(),
          'hf': hf.toDouble(),
          'vlf': vlf.toDouble(),
        });
      }
      
      if (entries.isEmpty) {
        Hc20CloudConfig.debugPrint('[HC20 HRV Upload] Batch ${batchIndex + 1}/${batches.length} has no valid entries, skipping');
        continue;
      }
      
      final payload = {
        'data': entries,
      };
      
      // Print JSON payload for debugging
      final jsonPayload = jsonEncode(payload);
      Hc20CloudConfig.debugPrint('[HC20 HRV Upload] Batch ${batchIndex + 1}/${batches.length} JSON Payload:');
      Hc20CloudConfig.debugPrint(jsonPayload);
      Hc20CloudConfig.debugPrint('[HC20 HRV Upload] Uploading batch ${batchIndex + 1}/${batches.length} to ${cfg.effectiveBaseUrl}/all-day/hrv with ${entries.length} entry/entries');
      
      try {
        await _uploadWithRetry('/all-day/hrv', payload, 'HC20 HRV Upload');
        Hc20CloudConfig.debugPrint('[HC20 HRV Upload] Batch ${batchIndex + 1}/${batches.length} success: Uploaded ${entries.length} entry/entries');
      } catch (e, stackTrace) {
        // Only log non-network errors
        if (!_isNetworkError(e)) {
          Hc20CloudConfig.debugPrint('[HC20 HRV Upload] Batch ${batchIndex + 1}/${batches.length} non-network error: $e');
          Hc20CloudConfig.debugPrint('[HC20 HRV Upload] Batch ${batchIndex + 1}/${batches.length} stack trace: $stackTrace');
          if (e is DioException) {
            Hc20CloudConfig.debugPrint('[HC20 HRV Upload] Batch ${batchIndex + 1}/${batches.length} DioException details:');
            Hc20CloudConfig.debugPrint('  - Request: ${e.requestOptions.method} ${e.requestOptions.uri}');
            Hc20CloudConfig.debugPrint('  - Response: ${e.response?.statusCode} ${e.response?.statusMessage}');
            Hc20CloudConfig.debugPrint('  - Response data: ${e.response?.data}');
          }
        }
        // Continue with next batch even if this one fails
      }
    }
    
    Hc20CloudConfig.debugPrint('[HC20 HRV Upload] All batches completed');
  }

  @override
  Future<void> uploadAllDayRri(List<Map<String, dynamic>> rriEntries, String mac, int packetIndex, int totalPackets) async {
    if (rriEntries.isEmpty) {
      Hc20CloudConfig.debugPrint('[HC20 RRI Upload] No entries to upload');
      return;
    }
    
    Hc20CloudConfig.debugPrint('[HC20 RRI Upload] Preparing upload: ${rriEntries.length} entry/entries, MAC: $mac, packetIndex: $packetIndex, totalPackets: $totalPackets');
    
    // Helper function to convert ISO dateTime string to unix timestamp (milliseconds)
    int _isoToUnixTimestamp(String isoString) {
      try {
        // Parse ISO string like "2025-01-01T12:00:00" or "2025-01-01T12:00:00.000"
        final dt = DateTime.parse(isoString);
        return dt.millisecondsSinceEpoch;
      } catch (e) {
        Hc20CloudConfig.debugPrint('[HC20 RRI Upload] Error parsing timestamp "$isoString": $e');
        return 0;
      }
    }
    
    // Batch entries into groups of 100
    const batchSize = 1000;
    final batches = <List<Map<String, dynamic>>>[];
    
    for (int i = 0; i < rriEntries.length; i += batchSize) {
      final end = (i + batchSize < rriEntries.length) ? i + batchSize : rriEntries.length;
      batches.add(rriEntries.sublist(i, end));
    }
    
    Hc20CloudConfig.debugPrint('[HC20 RRI Upload] Split into ${batches.length} batch/batches (${batches.length} × up to $batchSize entries)');
    
    // Upload each batch
    for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      final batch = batches[batchIndex];
      final entries = <Map<String, dynamic>>[];
      
      for (final entry in batch) {
        final dateTimeStr = entry['dateTime'] as String?;
        final values = entry['values'] as Map<String, dynamic>?;
        final valid = entry['valid'] as bool? ?? false;
        
        if (dateTimeStr == null || values == null) {
          Hc20CloudConfig.debugPrint('[HC20 RRI Upload] Skipping entry with missing dateTime or values');
          continue;
        }
        
        // Skip invalid entries
        if (!valid) {
          continue;
        }
        
        // Convert ISO dateTime to unix timestamp
        final timestamp = _isoToUnixTimestamp(dateTimeStr);
        if (timestamp == 0) {
          Hc20CloudConfig.debugPrint('[HC20 RRI Upload] Skipping entry with invalid timestamp: $dateTimeStr');
          continue;
        }
        
        // Extract RRI value
        final rri = values['rriMs'] as num?;
        
        // Only include entries with required value
        if (rri == null) {
          continue;
        }
        
        entries.add({
          'device_id': mac,
          'timestamp': timestamp,
          'packet_index': packetIndex,
          'total_packets': totalPackets,
          'rri': rri.toInt(),
        });
      }
      
      if (entries.isEmpty) {
        Hc20CloudConfig.debugPrint('[HC20 RRI Upload] Batch ${batchIndex + 1}/${batches.length} has no valid entries, skipping');
        continue;
      }
      
      final payload = {
        'data': entries,
      };
      
      // Print JSON payload for debugging
      final jsonPayload = jsonEncode(payload);
      Hc20CloudConfig.debugPrint('[HC20 RRI Upload] Batch ${batchIndex + 1}/${batches.length} JSON Payload:');
      Hc20CloudConfig.debugPrint(jsonPayload);
      Hc20CloudConfig.debugPrint('[HC20 RRI Upload] Uploading batch ${batchIndex + 1}/${batches.length} to ${cfg.effectiveBaseUrl}/all-day/rri with ${entries.length} entry/entries');
      
      try {
        await _uploadWithRetry('/all-day/rri', payload, 'HC20 RRI Upload');
        Hc20CloudConfig.debugPrint('[HC20 RRI Upload] Batch ${batchIndex + 1}/${batches.length} success: Uploaded ${entries.length} entry/entries');
      } catch (e, stackTrace) {
        // Only log non-network errors
        if (!_isNetworkError(e)) {
          Hc20CloudConfig.debugPrint('[HC20 RRI Upload] Batch ${batchIndex + 1}/${batches.length} non-network error: $e');
          Hc20CloudConfig.debugPrint('[HC20 RRI Upload] Batch ${batchIndex + 1}/${batches.length} stack trace: $stackTrace');
          if (e is DioException) {
            Hc20CloudConfig.debugPrint('[HC20 RRI Upload] Batch ${batchIndex + 1}/${batches.length} DioException details:');
            Hc20CloudConfig.debugPrint('  - Request: ${e.requestOptions.method} ${e.requestOptions.uri}');
            Hc20CloudConfig.debugPrint('  - Response: ${e.response?.statusCode} ${e.response?.statusMessage}');
            Hc20CloudConfig.debugPrint('  - Response data: ${e.response?.data}');
          }
        }
        // Continue with next batch even if this one fails
      }
    }
    
    Hc20CloudConfig.debugPrint('[HC20 RRI Upload] All batches completed');
  }

  @override
  Future<void> uploadAllDayHrv2(List<Map<String, dynamic>> hrv2Entries, String mac) async {
    if (hrv2Entries.isEmpty) {
      Hc20CloudConfig.debugPrint('[HC20 HRV2 Upload] No entries to upload');
      return;
    }
    
    Hc20CloudConfig.debugPrint('[HC20 HRV2 Upload] Preparing upload: ${hrv2Entries.length} entry/entries, MAC: $mac');
    
    // Helper function to convert ISO dateTime string to unix timestamp (milliseconds)
    int _isoToUnixTimestamp(String isoString) {
      try {
        // Parse ISO string like "2025-01-01T12:00:00" or "2025-01-01T12:00:00.000"
        final dt = DateTime.parse(isoString);
        return dt.millisecondsSinceEpoch;
      } catch (e) {
        Hc20CloudConfig.debugPrint('[HC20 HRV2 Upload] Error parsing timestamp "$isoString": $e');
        return 0;
      }
    }
    
    // Batch entries into groups of 500 (same as HRV)
    const batchSize = 500;
    final batches = <List<Map<String, dynamic>>>[];
    
    for (int i = 0; i < hrv2Entries.length; i += batchSize) {
      final end = (i + batchSize < hrv2Entries.length) ? i + batchSize : hrv2Entries.length;
      batches.add(hrv2Entries.sublist(i, end));
    }
    
    Hc20CloudConfig.debugPrint('[HC20 HRV2 Upload] Split into ${batches.length} batch/batches (${batches.length} × up to $batchSize entries)');
    
    // Upload each batch
    for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      final batch = batches[batchIndex];
      final entries = <Map<String, dynamic>>[];
      
      for (final entry in batch) {
        final dateTimeStr = entry['dateTime'] as String?;
        final values = entry['values'] as Map<String, dynamic>?;
        final valid = entry['valid'] as bool? ?? false;
        
        if (dateTimeStr == null || values == null) {
          Hc20CloudConfig.debugPrint('[HC20 HRV2 Upload] Skipping entry with missing dateTime or values');
          continue;
        }
        
        // Skip invalid entries
        if (!valid) {
          continue;
        }
        
        // Convert ISO dateTime to unix timestamp
        final timestamp = _isoToUnixTimestamp(dateTimeStr);
        if (timestamp == 0) {
          Hc20CloudConfig.debugPrint('[HC20 HRV2 Upload] Skipping entry with invalid timestamp: $dateTimeStr');
          continue;
        }
        
        // Extract HRV2 values
        final mentalStress = values['mentalStress'] as num?;
        final fatigueLevel = values['fatigue'] as num?;
        final stressResistance = values['stressResistance'] as num?;
        final regulationAbility = values['regulationAbility'] as num?;
        
        // Only include entries with all required values
        if (mentalStress == null || fatigueLevel == null || stressResistance == null || regulationAbility == null) {
          continue;
        }
        
        entries.add({
          'device_id': mac,
          'timestamp': timestamp,
          'mental_stress': mentalStress.toInt(),
          'fatigue_level': fatigueLevel.toInt(),
          'stress_resistance': stressResistance.toInt(),
          'regulation_ability': regulationAbility.toInt(),
          'reserved': '0',
        });
      }
      
      if (entries.isEmpty) {
        Hc20CloudConfig.debugPrint('[HC20 HRV2 Upload] Batch ${batchIndex + 1}/${batches.length} has no valid entries, skipping');
        continue;
      }
      
      final payload = {
        'data': entries,
      };
      
      // Print JSON payload for debugging
      final jsonPayload = jsonEncode(payload);
      Hc20CloudConfig.debugPrint('[HC20 HRV2 Upload] Batch ${batchIndex + 1}/${batches.length} JSON Payload:');
      Hc20CloudConfig.debugPrint(jsonPayload);
      Hc20CloudConfig.debugPrint('[HC20 HRV2 Upload] Uploading batch ${batchIndex + 1}/${batches.length} to ${cfg.effectiveBaseUrl}/all-day/hrv2 with ${entries.length} entry/entries');
      
      try {
        await _uploadWithRetry('/all-day/hrv2', payload, 'HC20 HRV2 Upload');
        Hc20CloudConfig.debugPrint('[HC20 HRV2 Upload] Batch ${batchIndex + 1}/${batches.length} success: Uploaded ${entries.length} entry/entries');
      } catch (e, stackTrace) {
        // Only log non-network errors
        if (!_isNetworkError(e)) {
          Hc20CloudConfig.debugPrint('[HC20 HRV2 Upload] Batch ${batchIndex + 1}/${batches.length} non-network error: $e');
          Hc20CloudConfig.debugPrint('[HC20 HRV2 Upload] Batch ${batchIndex + 1}/${batches.length} stack trace: $stackTrace');
          if (e is DioException) {
            Hc20CloudConfig.debugPrint('[HC20 HRV2 Upload] Batch ${batchIndex + 1}/${batches.length} DioException details:');
            Hc20CloudConfig.debugPrint('  - Request: ${e.requestOptions.method} ${e.requestOptions.uri}');
            Hc20CloudConfig.debugPrint('  - Response: ${e.response?.statusCode} ${e.response?.statusMessage}');
            Hc20CloudConfig.debugPrint('  - Response data: ${e.response?.data}');
          }
        }
        // Continue with next batch even if this one fails
      }
    }
    
    Hc20CloudConfig.debugPrint('[HC20 HRV2 Upload] All batches completed');
  }
}


