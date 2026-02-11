import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// HealthDataService - Manages real-time health data from HC20 device
///
/// Features:
/// - Real-time vitals (HR, SpO2, BP, Temperature, Steps, Battery)
/// - HRV2 stress metrics (Mental Stress, Fatigue, Stress Resistance, Regulation Ability)
/// - Last sync timestamp tracking
/// - Data persistence across app restarts
/// - Manual data clearing
///
/// Usage:
/// ```dart
/// final healthData = Provider.of<HealthDataService>(context);
/// print('Heart Rate: ${healthData.heartRate ?? "--"}');
/// print('Last synced: ${healthData.getLastSyncText()}');
/// ```
class HealthDataService extends ChangeNotifier {
  // ==================== VITALS DATA ====================
  int? _heartRate;
  int? _spo2;
  List<int>? _bloodPressure; // [systolic, diastolic]
  double? _temperature; // In Celsius (wrist temperature)
  List<double>? _temperatureArray; // [wrist, ambient, body]
  int? _batteryLevel; // Device battery percentage
  int? _steps;
  int? _calories; // Calories burned (kcal)
  int? _distance; // Distance in meters
  int? _rri; // RR interval
  int? _barometricPressure; // In Pascals
  int? _wearStatus; // 0=not worn, 1=worn
  List<int>? _sleepData; // Sleep data array

  // ==================== HRV2 STRESS METRICS ====================
  int? _mentalStress; // 0-100 (higher = more stressed)
  int? _fatigueLevel; // 0-100 (higher = more fatigued)
  int? _stressResistance; // 0-100 (higher = better resistance)
  int? _regulationAbility; // 0-100 (higher = better regulation)

  // ==================== HRV RAW METRICS ====================
  int? _sdnn; // Standard Deviation of NN intervals
  int? _totalPower; // Total Power (TP)
  int? _lowFrequency; // Low Frequency (LF)
  int? _highFrequency; // High Frequency (HF)
  int? _veryLowFrequency; // Very Low Frequency (VLF)

  // ==================== METADATA ====================
  DateTime? _lastRealtimeSync;
  bool _isDeviceConnected = false;

  // ==================== GETTERS ====================

  // Vitals
  int? get heartRate => _heartRate;
  int? get spo2 => _spo2;
  List<int>? get bloodPressure => _bloodPressure;
  double? get temperature => _temperature;
  List<double>? get temperatureArray => _temperatureArray;
  int? get batteryLevel => _batteryLevel;
  int? get steps => _steps;
  int? get calories => _calories;
  int? get distance => _distance;
  int? get rri => _rri;
  int? get barometricPressure => _barometricPressure;
  int? get wearStatus => _wearStatus;
  List<int>? get sleepData => _sleepData;

  // HRV2 Stress Metrics
  int? get mentalStress => _mentalStress;
  int? get fatigueLevel => _fatigueLevel;
  int? get stressResistance => _stressResistance;
  int? get regulationAbility => _regulationAbility;

  // HRV Raw Metrics
  int? get sdnn => _sdnn;
  int? get totalPower => _totalPower;
  int? get lowFrequency => _lowFrequency;
  int? get highFrequency => _highFrequency;
  int? get veryLowFrequency => _veryLowFrequency;

  // Metadata
  DateTime? get lastRealtimeSync => _lastRealtimeSync;
  bool get isDeviceConnected => _isDeviceConnected;

  // Helper: Check if data is stale (older than 10 minutes)
  bool get isDataStale {
    if (_lastRealtimeSync == null) return true;
    final diff = DateTime.now().difference(_lastRealtimeSync!);
    return diff.inMinutes > 10;
  }

  // Helper: Get human-readable last sync text
  String getLastSyncText() {
    if (_lastRealtimeSync == null) return 'Never synced';

    final diff = DateTime.now().difference(_lastRealtimeSync!);

    if (diff.inSeconds < 60) {
      return 'Synced ${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return 'Synced ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return 'Synced ${diff.inHours}h ago';
    } else {
      return 'Synced ${diff.inDays}d ago';
    }
  }

  // Helper: Get stress level text (for UI display)
  String getStressLevelText() {
    if (_mentalStress == null) return 'Unknown';

    if (_mentalStress! >= 70) {
      return 'High';
    } else if (_mentalStress! >= 50) {
      return 'Moderate';
    } else if (_mentalStress! >= 30) {
      return 'Normal';
    } else {
      return 'Low';
    }
  }

  // ==================== SETTERS (called from main.dart) ====================

  /// Update realtime data from HC20 device
  /// This is called from main.dart BLE stream listener
  void updateRealtimeData({
    int? heartRate,
    int? spo2,
    List<int>? bloodPressure,
    double? temperature,
    List<double>? temperatureArray,
    int? batteryLevel,
    int? steps,
    int? calories,
    int? distance,
    int? rri,
    int? barometricPressure,
    int? wearStatus,
    List<int>? sleepData,
    int? mentalStress,
    int? fatigueLevel,
    int? stressResistance,
    int? regulationAbility,
    int? sdnn,
    int? totalPower,
    int? lowFrequency,
    int? highFrequency,
    int? veryLowFrequency,
  }) {
    // Update vitals (only if not null - preserves existing values)
    if (heartRate != null) _heartRate = heartRate;
    if (spo2 != null) _spo2 = spo2;
    if (bloodPressure != null) _bloodPressure = bloodPressure;
    if (temperature != null) _temperature = temperature;
    if (temperatureArray != null) _temperatureArray = temperatureArray;
    if (batteryLevel != null) _batteryLevel = batteryLevel;
    if (steps != null) _steps = steps;
    if (calories != null) _calories = calories;
    if (distance != null) _distance = distance;
    if (rri != null) _rri = rri;
    if (barometricPressure != null) _barometricPressure = barometricPressure;
    if (wearStatus != null) _wearStatus = wearStatus;
    if (sleepData != null) _sleepData = sleepData;

    // Update HRV2 stress metrics (only if not null)
    if (mentalStress != null) _mentalStress = mentalStress;
    if (fatigueLevel != null) _fatigueLevel = fatigueLevel;
    if (stressResistance != null) _stressResistance = stressResistance;
    if (regulationAbility != null) _regulationAbility = regulationAbility;

    // Update HRV raw metrics (only if not null)
    if (sdnn != null) _sdnn = sdnn;
    if (totalPower != null) _totalPower = totalPower;
    if (lowFrequency != null) _lowFrequency = lowFrequency;
    if (highFrequency != null) _highFrequency = highFrequency;
    if (veryLowFrequency != null) _veryLowFrequency = veryLowFrequency;

    // Update timestamp
    _lastRealtimeSync = DateTime.now();

    // Persist to storage
    _saveToStorage();

    // Notify all listeners (UI screens will rebuild)
    notifyListeners();

    if (kDebugMode) {
      print(
          '📊 [HealthDataService] Data updated: HR=$heartRate, SpO2=$spo2, Stress=$mentalStress');
    }
  }

  /// Update connection state
  void updateConnectionState(bool connected) {
    if (_isDeviceConnected != connected) {
      _isDeviceConnected = connected;
      notifyListeners();

      if (kDebugMode) {
        print(
            '📊 [HealthDataService] Connection state: ${connected ? "CONNECTED" : "DISCONNECTED"}');
      }
    }
  }

  // ==================== PERSISTENCE ====================

  /// Save all data to SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Vitals
      if (_heartRate != null)
        await prefs.setInt('health_heartRate', _heartRate!);
      if (_spo2 != null) await prefs.setInt('health_spo2', _spo2!);
      if (_bloodPressure != null) {
        await prefs.setString(
            'health_bloodPressure', _bloodPressure!.join(','));
      }
      if (_temperature != null)
        await prefs.setDouble('health_temperature', _temperature!);
      if (_temperatureArray != null) {
        await prefs.setString(
            'health_temperatureArray', _temperatureArray!.join(','));
      }
      if (_batteryLevel != null)
        await prefs.setInt('health_batteryLevel', _batteryLevel!);
      if (_steps != null) await prefs.setInt('health_steps', _steps!);
      if (_calories != null) await prefs.setInt('health_calories', _calories!);
      if (_distance != null) await prefs.setInt('health_distance', _distance!);
      if (_rri != null) await prefs.setInt('health_rri', _rri!);

      // Environmental data
      if (_barometricPressure != null)
        await prefs.setInt('health_barometricPressure', _barometricPressure!);
      if (_wearStatus != null)
        await prefs.setInt('health_wearStatus', _wearStatus!);
      if (_sleepData != null) {
        await prefs.setString('health_sleepData', _sleepData!.join(','));
      }

      // HRV2 Stress Metrics
      if (_mentalStress != null)
        await prefs.setInt('health_mentalStress', _mentalStress!);
      if (_fatigueLevel != null)
        await prefs.setInt('health_fatigueLevel', _fatigueLevel!);
      if (_stressResistance != null)
        await prefs.setInt('health_stressResistance', _stressResistance!);
      if (_regulationAbility != null)
        await prefs.setInt('health_regulationAbility', _regulationAbility!);

      // HRV Raw Metrics
      if (_sdnn != null) await prefs.setInt('health_sdnn', _sdnn!);
      if (_totalPower != null)
        await prefs.setInt('health_totalPower', _totalPower!);
      if (_lowFrequency != null)
        await prefs.setInt('health_lowFrequency', _lowFrequency!);
      if (_highFrequency != null)
        await prefs.setInt('health_highFrequency', _highFrequency!);
      if (_veryLowFrequency != null)
        await prefs.setInt('health_veryLowFrequency', _veryLowFrequency!);

      // Timestamp
      if (_lastRealtimeSync != null) {
        await prefs.setString(
            'health_lastRealtimeSync', _lastRealtimeSync!.toIso8601String());
      }

      if (kDebugMode) {
        print('💾 [HealthDataService] Data saved to storage');
      }
    } catch (e) {
      print('❌ [HealthDataService] Error saving to storage: $e');
    }
  }

  /// Load data from SharedPreferences on app start
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Vitals
      _heartRate = prefs.getInt('health_heartRate');
      _spo2 = prefs.getInt('health_spo2');

      final bpString = prefs.getString('health_bloodPressure');
      if (bpString != null && bpString.isNotEmpty) {
        _bloodPressure = bpString.split(',').map((e) => int.parse(e)).toList();
      }

      _temperature = prefs.getDouble('health_temperature');

      final tempArrayString = prefs.getString('health_temperatureArray');
      if (tempArrayString != null && tempArrayString.isNotEmpty) {
        _temperatureArray =
            tempArrayString.split(',').map((e) => double.parse(e)).toList();
      }

      _batteryLevel = prefs.getInt('health_batteryLevel');
      _steps = prefs.getInt('health_steps');
      _calories = prefs.getInt('health_calories');
      _distance = prefs.getInt('health_distance');
      _rri = prefs.getInt('health_rri');

      // Environmental data
      _barometricPressure = prefs.getInt('health_barometricPressure');
      _wearStatus = prefs.getInt('health_wearStatus');

      final sleepString = prefs.getString('health_sleepData');
      if (sleepString != null && sleepString.isNotEmpty) {
        _sleepData = sleepString.split(',').map((e) => int.parse(e)).toList();
      }

      // HRV2 Stress Metrics
      _mentalStress = prefs.getInt('health_mentalStress');
      _fatigueLevel = prefs.getInt('health_fatigueLevel');
      _stressResistance = prefs.getInt('health_stressResistance');
      _regulationAbility = prefs.getInt('health_regulationAbility');

      // HRV Raw Metrics
      _sdnn = prefs.getInt('health_sdnn');
      _totalPower = prefs.getInt('health_totalPower');
      _lowFrequency = prefs.getInt('health_lowFrequency');
      _highFrequency = prefs.getInt('health_highFrequency');
      _veryLowFrequency = prefs.getInt('health_veryLowFrequency');

      // Timestamp
      final syncStr = prefs.getString('health_lastRealtimeSync');
      if (syncStr != null) {
        _lastRealtimeSync = DateTime.parse(syncStr);
      }

      notifyListeners();

      if (kDebugMode) {
        print('📂 [HealthDataService] Data loaded from storage');
        print('   Last sync: ${getLastSyncText()}');
        print('   HR: $_heartRate, SpO2: $_spo2, Stress: $_mentalStress');
      }
    } catch (e) {
      print('❌ [HealthDataService] Error loading from storage: $e');
    }
  }

  /// Clear all data (manual user action)
  /// This is called when user explicitly wants to clear data
  Future<void> clearAllData() async {
    try {
      // Clear in-memory vitals data
      _heartRate = null;
      _spo2 = null;
      _bloodPressure = null;
      _temperature = null;
      _temperatureArray = null;
      _batteryLevel = null;
      _steps = null;
      _calories = null;
      _distance = null;
      _rri = null;
      _barometricPressure = null;
      _wearStatus = null;
      _sleepData = null;

      // Clear HRV2 stress metrics
      _mentalStress = null;
      _fatigueLevel = null;
      _stressResistance = null;
      _regulationAbility = null;

      // Clear HRV raw metrics
      _sdnn = null;
      _totalPower = null;
      _lowFrequency = null;
      _highFrequency = null;
      _veryLowFrequency = null;

      // Clear metadata (but NOT device connection state)
      _lastRealtimeSync = null;

      // Clear from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('health_heartRate');
      await prefs.remove('health_spo2');
      await prefs.remove('health_bloodPressure');
      await prefs.remove('health_temperature');
      await prefs.remove('health_temperatureArray');
      await prefs.remove('health_batteryLevel');
      await prefs.remove('health_steps');
      await prefs.remove('health_calories');
      await prefs.remove('health_distance');
      await prefs.remove('health_rri');
      await prefs.remove('health_barometricPressure');
      await prefs.remove('health_wearStatus');
      await prefs.remove('health_sleepData');
      await prefs.remove('health_mentalStress');
      await prefs.remove('health_fatigueLevel');
      await prefs.remove('health_stressResistance');
      await prefs.remove('health_regulationAbility');
      await prefs.remove('health_sdnn');
      await prefs.remove('health_totalPower');
      await prefs.remove('health_lowFrequency');
      await prefs.remove('health_highFrequency');
      await prefs.remove('health_veryLowFrequency');
      await prefs.remove('health_lastRealtimeSync');

      notifyListeners();

      print('🗑️  [HealthDataService] All health data cleared');
    } catch (e) {
      print('❌ [HealthDataService] Error clearing data: $e');
    }
  }
}
