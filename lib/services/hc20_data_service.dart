import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hc20/hc20.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ✅ CONSOLIDATED SERVICE: HC20 Data Management
/// Combines:
/// - Data conversion (HC20 device format → Webhook JSON)
/// - Webhook API communication
/// - Real-time data fetching
/// - History data fetching
///
/// Single responsibility: "Manage HC20 data flow from device → API"
class HC20DataService extends ChangeNotifier {
  // Webhook configuration
  static const String _webhookUrl =
      'https://api.hireforcare.com/webhook/hc20-data';
  late final Dio _dio;

  // Webhook statistics
  int webhookSuccessCount = 0;
  int webhookErrorCount = 0;
  String lastWebhookStatus = '';
  String lastWebhookError = '';
  DateTime? lastWebhookTime;

  // Sync timestamps
  DateTime? lastRealtimeSync;
  DateTime? lastHistorySync;
  DateTime? lastHistorySyncDate; // Track WHICH DATE was synced
  DateTime? lastDataReceived;

  // Real-time vitals (for local UI state)
  int? heartRate;
  int? spo2;
  List<int>? bloodPressure;
  double? temperature;
  int? batteryLevel;

  HC20DataService() {
    _initializeDio();
  }

  // ==================== DIO INITIALIZATION ====================
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

    // Add interceptor to ensure response body is consumed (prevents OkHttp connection leak)
    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        response.data; // Force body consumption to prevent connection leak
        handler.next(response);
      },
      onError: (error, handler) {
        if (error.response != null) {
          error.response!.data; // Consume response body in error cases too
        }
        handler.next(error);
      },
    ));

    // Conditional logging: Verbose in debug mode, SILENT in production
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => print('🌐 Dio Log: $obj'),
      ));
      print('🔧 [DEV] Dio verbose logging ENABLED');
    } else {
      _dio.interceptors.add(InterceptorsWrapper(
        onError: (DioException error, handler) {
          if (error.response != null) {
            print(
                '🌐 Dio Error: ${error.response?.statusCode} ${error.requestOptions.method} ${error.requestOptions.uri}');
          } else {
            print('🌐 Dio Error: Network failure - ${error.message}');
          }
          handler.next(error);
        },
      ));
      print('🔧 [PROD] Dio error-only logging ENABLED');
    }
  }

  // ==================== LOCATION HELPER ====================
  // Cache location to avoid frequent GPS calls (valid for 5 minutes)
  String? _cachedLocation;
  DateTime? _locationCacheTime;
  static const _locationCacheMinutes = 5;

  /// Get current location as "lat,long" string (returns cached or null if unavailable)
  Future<String?> _getCurrentLocation({bool skipGps = false}) async {
    // Return cached location if still valid
    if (_cachedLocation != null && _locationCacheTime != null) {
      final age = DateTime.now().difference(_locationCacheTime!).inMinutes;
      if (age < _locationCacheMinutes) {
        return _cachedLocation;
      }
    }

    // Skip GPS fetch if requested (for background isolates)
    if (skipGps) return _cachedLocation;

    try {
      // Check if location services are enabled
      if (!await Geolocator.isLocationServiceEnabled()) return _cachedLocation;

      // Check permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return _cachedLocation;
      }
      if (permission == LocationPermission.deniedForever)
        return _cachedLocation;

      // Get position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      _cachedLocation = '${position.latitude},${position.longitude}';
      _locationCacheTime = DateTime.now();
      return _cachedLocation;
    } catch (e) {
      if (kDebugMode) print('📍 Location error: $e');
      return _cachedLocation;
    }
  }

  // ==================== DATA CONVERSION ====================
  /// Convert HC20 realtime data to webhook JSON payload
  /// Note: Backend expects specific format with camelCase keys
  Map<String, dynamic> convertRealtimeToWebhook(
    Hc20Device device,
    Hc20RealtimeV2 data, {
    bool isStressAlert = false,
    String? userPhone,
    String? userId,
    String? userName,
    String? deviceManufacturer,
    String? deviceModel,
    String? deviceOsVersion,
    String? mobileDeviceId,
    bool isBluetoothOn = true,
    bool hasInternet = true,
    bool isLowBattery = false,
    String? latlong,
  }) {
    final now = DateTime.now();
    final batteryLevel = data.battery?.percent;

    return {
      'dataType': 'live',
      'liveType': 'realtime_data',
      'source': isStressAlert ? 'StressAlert' : 'Auto_LiveData',
      'isStressAlert': isStressAlert,
      'timestamp': now.toIso8601String(),
      'datetime':
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00',
      'latlong': latlong,
      'status': 'Connected',
      'bluetoothStatus': isBluetoothOn ? 'Connected' : 'Disconnected',
      'internetStatus': hasInternet ? 'Connected' : 'Disconnected',
      'deviceBatteryLevel': batteryLevel,
      'isDeviceLowBattery':
          isLowBattery || (batteryLevel != null && batteryLevel < 20),
      'user': {
        'id': userId ?? 'unknown',
        'name': userName ?? 'unknown',
      },
      'device': {
        'id': device.id,
        'name': device.name,
      },
      'mobileDevice': {
        'manufacturer': deviceManufacturer,
        'model': deviceModel,
        'osVersion': deviceOsVersion,
        'deviceId': mobileDeviceId,
      },
      'realtime_data': {
        'heart_rate': data.heart,
        'rri': data.rri,
        'spo2': data.spo2,
        'blood_pressure': data.bp != null
            ? {
                'systolic': data.bp!.isNotEmpty ? data.bp![0] : null,
                'diastolic': data.bp!.length > 1 ? data.bp![1] : null,
              }
            : null,
        'temperature': data.temperature?.map((t) => t / 100.0).toList(),
        'battery': data.battery != null
            ? {
                'percent': data.battery!.percent,
                'charge': data.battery!.charge,
              }
            : null,
        'basic_data': data.basicData,
        'barometric_pressure': data.baro,
        'wear_status': data.wear,
        'sleep': data.sleep,
        'gnss': data.gnss,
        'hrv_raw': data.hrv,
        'hrv_metrics': data.hrvMetrics != null
            ? {
                'sdnn': data.hrvMetrics!.sdnn,
                'tp': data.hrvMetrics!.tp,
                'lf': data.hrvMetrics!.lf,
                'hf': data.hrvMetrics!.hf,
                'vlf': data.hrvMetrics!.vlf,
              }
            : null,
        'hrv2_raw': data.hrv2,
        'hrv2_metrics': data.hrv2Metrics != null
            ? {
                'mental_stress': data.hrv2Metrics!.mentStress,
                'fatigue_level': data.hrv2Metrics!.fatigueLevel,
                'stress_resistance': data.hrv2Metrics!.stressResistance,
                'regulation_ability': data.hrv2Metrics!.regulationAbility,
              }
            : null,
      },
    };
  }

  /// Convert HC20 history data to webhook JSON payload
  /// Note: Backend expects specific format with camelCase keys
  Map<String, dynamic> convertHistoryToWebhook({
    required String deviceId,
    required String deviceName,
    required String dateStr,
    String? userPhone,
    String? userId,
    String? userName,
    String? deviceManufacturer,
    String? deviceModel,
    String? deviceOsVersion,
    String? mobileDeviceId,
    String? latlong,
    bool isAutomatic = true,
    List<dynamic>? hrv2Rows,
    List<dynamic>? hrvRows,
    List<dynamic>? bpRows,
    List<dynamic>? spo2Rows,
    List<dynamic>? stepsRows,
    List<dynamic>? sleepRows,
    List<dynamic>? caloriesRows,
    List<dynamic>? summaryRows,
  }) {
    // Convert rows to JSON lists (filter only valid rows before conversion)
    final hrv2JsonList = hrv2Rows
            ?.where((row) => row.valid == true)
            .map((row) => _convertRowToJson(row))
            .where((r) => r != null)
            .toList() ??
        [];
    final hrvJsonList = hrvRows
            ?.where((row) => row.valid == true)
            .map((row) => _convertRowToJson(row))
            .where((r) => r != null)
            .toList() ??
        [];
    final bpJsonList = bpRows
            ?.where((row) => row.valid == true)
            .map((row) => _convertRowToJson(row))
            .where((r) => r != null)
            .toList() ??
        [];
    final spo2JsonList = spo2Rows
            ?.where((row) => row.valid == true)
            .map((row) => _convertRowToJson(row))
            .where((r) => r != null)
            .toList() ??
        [];
    final stepsJsonList = stepsRows
            ?.where((row) => row.valid == true)
            .map((row) => _convertRowToJson(row))
            .where((r) => r != null)
            .toList() ??
        [];
    final sleepJsonList = sleepRows
            ?.where((row) => row.valid == true)
            .map((row) => _convertRowToJson(row))
            .where((r) => r != null)
            .toList() ??
        [];
    final caloriesJsonList = caloriesRows
            ?.where((row) => row.valid == true)
            .map((row) => _convertRowToJson(row))
            .where((r) => r != null)
            .toList() ??
        [];
    final summaryJsonList = summaryRows
            ?.where((row) => row.valid == true)
            .map((row) => _convertRowToJson(row))
            .where((r) => r != null)
            .toList() ??
        [];

    return {
      'dataType': 'history',
      'historyType': 'all',
      'source': isAutomatic ? 'auto_6hour_refresh' : 'manual_send',
      'timestamp': DateTime.now().toIso8601String(),
      'date': dateStr,
      'latlong': latlong,
      'user': {
        'id': userId ?? 'unknown',
        'name': userName ?? 'unknown',
      },
      'device': {
        'id': deviceId,
        'name': deviceName,
      },
      'mobileDevice': {
        'manufacturer': deviceManufacturer,
        'model': deviceModel,
        'osVersion': deviceOsVersion,
        'deviceId': mobileDeviceId,
      },
      'history_data': {
        'hrv2': hrv2JsonList,
        'hrv': hrvJsonList,
        'bp': bpJsonList,
        'spo2': spo2JsonList,
        'steps': stepsJsonList,
        'calories': caloriesJsonList,
        'sleep': sleepJsonList,
        'summary': summaryJsonList,
      },
      'recordCounts': {
        'hrv2': hrv2JsonList.length,
        'hrv': hrvJsonList.length,
        'bp': bpJsonList.length,
        'spo2': spo2JsonList.length,
        'steps': stepsJsonList.length,
        'calories': caloriesJsonList.length,
        'sleep': sleepJsonList.length,
        'summary': summaryJsonList.length,
      },
    };
  }

  /// Convert SDK row object to JSON-serializable map
  Map<String, dynamic>? _convertRowToJson(dynamic row) {
    if (row == null) return null;
    try {
      // Handle Hc20AllDayRow objects from SDK - use built-in toJson()
      if (row is Hc20AllDayRow) return row.toJson();
      // If already a map, return as-is
      if (row is Map<String, dynamic>) return row;
      return {'raw': row.toString()};
    } catch (e) {
      return {'raw': row.toString()};
    }
  }

  /// Convert disconnection data to webhook JSON payload
  Map<String, dynamic> convertDisconnectToWebhook(
    String deviceId,
    String reason, {
    String? userPhone,
    int? lastHeartRate,
    int? lastSpo2,
    double? lastTemperature,
    int? batteryLevel,
  }) {
    return {
      'device': {'id': deviceId}, // Backend expects nested device object
      'timestamp': DateTime.now().toIso8601String(),
      'data_type': 'disconnect',
      'user_phone': userPhone,
      'disconnect_reason': reason,
      'last_known_vitals': {
        'heart_rate': lastHeartRate,
        'spo2': lastSpo2,
        'temperature': lastTemperature,
        'battery_level': batteryLevel
      },
    };
  }

  // ==================== WEBHOOK COMMUNICATION ====================
  /// Send realtime data to webhook
  Future<bool> sendRealtimeDataToWebhook(
    Hc20Device device,
    Hc20RealtimeV2 data, {
    bool isStressAlert = false,
    String? userPhone,
    String? userId,
    String? userName,
    String? deviceManufacturer,
    String? deviceModel,
    String? deviceOsVersion,
    String? mobileDeviceId,
    bool isBluetoothOn = true,
    bool hasInternet = true,
    bool isLowBattery = false,
    String? latlong,
  }) async {
    try {
      // Get location automatically if not provided
      final location = latlong ?? await _getCurrentLocation();

      final payload = convertRealtimeToWebhook(
        device,
        data,
        isStressAlert: isStressAlert,
        userPhone: userPhone,
        userId: userId,
        userName: userName,
        deviceManufacturer: deviceManufacturer,
        deviceModel: deviceModel,
        deviceOsVersion: deviceOsVersion,
        mobileDeviceId: mobileDeviceId,
        isBluetoothOn: isBluetoothOn,
        hasInternet: hasInternet,
        isLowBattery: isLowBattery,
        latlong: location,
      );

      final response = await _dio.post(_webhookUrl, data: payload);

      if (response.statusCode == 200) {
        webhookSuccessCount++;
        lastWebhookStatus = 'Success';
        lastWebhookTime = DateTime.now();
        lastWebhookError = '';

        print('✅ [Webhook] Realtime data sent successfully');
        print('   Success count: $webhookSuccessCount');

        notifyListeners();
        return true;
      } else {
        throw Exception('Unexpected status code: ${response.statusCode}');
      }
    } catch (e) {
      webhookErrorCount++;
      lastWebhookStatus = 'Failed';
      lastWebhookError = e.toString();
      lastWebhookTime = DateTime.now();

      print('❌ [Webhook] Failed to send realtime data: $e');
      print('   Error count: $webhookErrorCount');

      notifyListeners();
      return false;
    }
  }

  /// Send history data to webhook
  Future<bool> sendHistoryDataToWebhook({
    required String deviceId,
    required String deviceName,
    required String dateStr,
    String? userPhone,
    String? userId,
    String? userName,
    String? deviceManufacturer,
    String? deviceModel,
    String? deviceOsVersion,
    String? mobileDeviceId,
    String? latlong,
    bool isAutomatic = true,
    List<dynamic>? hrv2Rows,
    List<dynamic>? hrvRows,
    List<dynamic>? bpRows,
    List<dynamic>? spo2Rows,
    List<dynamic>? stepsRows,
    List<dynamic>? sleepRows,
    List<dynamic>? caloriesRows,
    List<dynamic>? summaryRows,
  }) async {
    try {
      // Get location automatically if not provided
      final location = latlong ?? await _getCurrentLocation();

      final payload = convertHistoryToWebhook(
        deviceId: deviceId,
        deviceName: deviceName,
        dateStr: dateStr,
        userPhone: userPhone,
        userId: userId,
        userName: userName,
        deviceManufacturer: deviceManufacturer,
        deviceModel: deviceModel,
        deviceOsVersion: deviceOsVersion,
        mobileDeviceId: mobileDeviceId,
        latlong: location,
        isAutomatic: isAutomatic,
        hrv2Rows: hrv2Rows,
        hrvRows: hrvRows,
        bpRows: bpRows,
        spo2Rows: spo2Rows,
        stepsRows: stepsRows,
        sleepRows: sleepRows,
        caloriesRows: caloriesRows,
        summaryRows: summaryRows,
      );

      final response = await _dio.post(_webhookUrl, data: payload);

      if (response.statusCode == 200) {
        webhookSuccessCount++;
        lastWebhookStatus = 'Success';
        lastWebhookTime = DateTime.now();

        // Log record counts
        final counts = payload['recordCounts'] as Map<String, dynamic>;
        final totalRecords =
            counts.values.fold<int>(0, (sum, count) => sum + (count as int));
        print('✅ [Webhook] History data sent successfully for date: $dateStr');
        print(
            '   Total records: $totalRecords (hrv2: ${counts['hrv2']}, hrv: ${counts['hrv']}, bp: ${counts['bp']}, spo2: ${counts['spo2']}, steps: ${counts['steps']}, calories: ${counts['calories']}, sleep: ${counts['sleep']}, summary: ${counts['summary']})');

        notifyListeners();
        return true;
      } else {
        throw Exception('Unexpected status code: ${response.statusCode}');
      }
    } catch (e) {
      webhookErrorCount++;
      lastWebhookStatus = 'Failed';
      lastWebhookError = e.toString();
      lastWebhookTime = DateTime.now();

      print('❌ [Webhook] Failed to send history data: $e');
      notifyListeners();
      return false;
    }
  }

  /// Send disconnection data to webhook
  Future<bool> sendDisconnectToWebhook(
    String deviceId,
    String reason, {
    String? userPhone,
    int? lastHeartRate,
    int? lastSpo2,
    double? lastTemperature,
    int? batteryLevel,
  }) async {
    try {
      final payload = convertDisconnectToWebhook(
        deviceId,
        reason,
        userPhone: userPhone,
        lastHeartRate: lastHeartRate,
        lastSpo2: lastSpo2,
        lastTemperature: lastTemperature,
        batteryLevel: batteryLevel,
      );

      final response = await _dio.post(_webhookUrl, data: payload);

      if (response.statusCode == 200) {
        print('✅ [Webhook] Disconnect data sent successfully');
        return true;
      } else {
        throw Exception('Unexpected status code: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [Webhook] Failed to send disconnect data: $e');
      return false;
    }
  }

  // ==================== PERSISTENCE ====================
  /// Save sync timestamps to SharedPreferences
  Future<void> saveSyncTimestamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (lastRealtimeSync != null) {
        await prefs.setString(
            'last_realtime_sync', lastRealtimeSync!.toIso8601String());
      }

      if (lastHistorySync != null) {
        await prefs.setString(
            'last_history_sync', lastHistorySync!.toIso8601String());
      }

      if (lastHistorySyncDate != null) {
        await prefs.setString(
            'last_history_sync_date', lastHistorySyncDate!.toIso8601String());
      }

      if (lastDataReceived != null) {
        await prefs.setString(
            'last_data_received', lastDataReceived!.toIso8601String());
      }

      // Save current vitals
      if (heartRate != null) await prefs.setInt('heart_rate', heartRate!);
      if (spo2 != null) await prefs.setInt('spo2', spo2!);
      if (bloodPressure != null) {
        await prefs.setString('blood_pressure', bloodPressure!.join(','));
      }
      if (temperature != null) {
        await prefs.setDouble('temperature', temperature!);
      }
      if (batteryLevel != null) {
        await prefs.setInt('battery_level', batteryLevel!);
      }

      if (kDebugMode) {
        print('💾 [HC20DataService] Sync timestamps saved');
      }
    } catch (e) {
      print('❌ [HC20DataService] Error saving timestamps: $e');
    }
  }

  /// Load sync timestamps from SharedPreferences
  Future<void> loadSyncTimestamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final realtimeStr = prefs.getString('last_realtime_sync');
      if (realtimeStr != null) {
        lastRealtimeSync = DateTime.parse(realtimeStr);
      }

      final historyStr = prefs.getString('last_history_sync');
      if (historyStr != null) {
        lastHistorySync = DateTime.parse(historyStr);
      }

      final historySyncDateStr = prefs.getString('last_history_sync_date');
      if (historySyncDateStr != null) {
        lastHistorySyncDate = DateTime.parse(historySyncDateStr);
      }

      final dataReceivedStr = prefs.getString('last_data_received');
      if (dataReceivedStr != null) {
        lastDataReceived = DateTime.parse(dataReceivedStr);
      }

      // Load last known vitals
      heartRate = prefs.getInt('heart_rate');
      spo2 = prefs.getInt('spo2');
      final bpStr = prefs.getString('blood_pressure');
      if (bpStr != null && bpStr.isNotEmpty) {
        bloodPressure = bpStr.split(',').map((e) => int.parse(e)).toList();
      }
      temperature = prefs.getDouble('temperature');
      batteryLevel = prefs.getInt('battery_level');

      if (kDebugMode) {
        print('📂 [HC20DataService] Sync timestamps loaded');
        print('   Last realtime: $lastRealtimeSync');
        print('   Last history: $lastHistorySync');
      }

      notifyListeners();
    } catch (e) {
      print('❌ [HC20DataService] Error loading timestamps: $e');
    }
  }

  /// Clear all sync data and timestamps
  Future<void> clearSyncData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear sync timestamps
      await prefs.remove('last_realtime_sync');
      await prefs.remove('last_history_sync');
      await prefs.remove('last_history_sync_date');
      await prefs.remove('last_data_received');

      // Clear cached vitals
      await prefs.remove('heart_rate');
      await prefs.remove('spo2');
      await prefs.remove('blood_pressure');
      await prefs.remove('temperature');
      await prefs.remove('battery_level');

      // Reset local state
      lastRealtimeSync = null;
      lastHistorySync = null;
      lastHistorySyncDate = null;
      lastDataReceived = null;
      heartRate = null;
      spo2 = null;
      bloodPressure = null;
      temperature = null;
      batteryLevel = null;

      // Reset webhook counters
      webhookSuccessCount = 0;
      webhookErrorCount = 0;
      lastWebhookStatus = 'Not sent yet';
      lastWebhookTime = null;
      lastWebhookError = '';

      print('✅ [HC20DataService] Sync data cleared');
      notifyListeners();
    } catch (e) {
      print('❌ [HC20DataService] Error clearing sync data: $e');
    }
  }

  /// Update local vitals (for UI state)
  void updateLocalVitals({
    int? heartRate,
    int? spo2,
    List<int>? bloodPressure,
    double? temperature,
    int? batteryLevel,
  }) {
    if (heartRate != null) this.heartRate = heartRate;
    if (spo2 != null) this.spo2 = spo2;
    if (bloodPressure != null) this.bloodPressure = bloodPressure;
    if (temperature != null) this.temperature = temperature;
    if (batteryLevel != null) this.batteryLevel = batteryLevel;

    lastDataReceived = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    saveSyncTimestamps(); // Save before disposing
    super.dispose();
  }
}
