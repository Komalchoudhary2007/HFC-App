import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DeviceStatusService - Manages HC20 device connection state and sync times
/// 
/// Features:
/// - Connection state tracking (connected/disconnected)
/// - Device info (ID, name, battery level)
/// - Last sync timestamps (realtime, history)
/// - Bluetooth & Internet status
/// - Data persistence
/// - Auto-refresh UI every 10 seconds to update "X ago" timestamps
/// 
/// Usage:
/// ```dart
/// final deviceStatus = Provider.of<DeviceStatusService>(context);
/// print('Device: ${deviceStatus.deviceName ?? "Not connected"}');
/// print('Last sync: ${deviceStatus.getLastRealtimeSyncText()}');
/// ```
class DeviceStatusService extends ChangeNotifier {
  // ==================== AUTO-REFRESH TIMER ====================
  Timer? _refreshTimer;
  
  // ==================== CONNECTION STATE ====================
  bool _isConnected = false;
  String? _deviceId;
  String? _deviceName;
  int? _deviceBatteryLevel;
  
  // ==================== SYNC TIMESTAMPS ====================
  DateTime? _lastRealtimeSync;
  DateTime? _lastHistorySync;
  DateTime? _lastWebhookSync;
  
  // ==================== STATUS INDICATORS ====================
  bool _isBluetoothOn = true;
  bool _isInternetConnected = true;
  
  // ==================== CONSTRUCTOR ====================
  DeviceStatusService() {
    // Start a timer to refresh UI every 10 seconds
    // This ensures "X seconds ago" timestamps update automatically
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      notifyListeners(); // Trigger UI rebuild to show updated "ago" text
    });
    
    if (kDebugMode) {
      print('🔄 [DeviceStatusService] Auto-refresh timer started (every 10s)');
    }
  }
  
  // ==================== GETTERS ====================
  bool get isConnected => _isConnected;
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;
  int? get deviceBatteryLevel => _deviceBatteryLevel;
  DateTime? get lastRealtimeSync => _lastRealtimeSync;
  DateTime? get lastHistorySync => _lastHistorySync;
  DateTime? get lastWebhookSync => _lastWebhookSync;
  bool get isBluetoothOn => _isBluetoothOn;
  bool get isInternetConnected => _isInternetConnected;
  
  // ==================== HELPER METHODS ====================
  
  /// Get human-readable last realtime sync text
  String getLastRealtimeSyncText() {
    if (_lastRealtimeSync == null) return 'Never synced';
    return _formatTimeDifference(_lastRealtimeSync!);
  }
  
  /// Get human-readable last webhook sync text
  String getLastWebhookSyncText() {
    if (_lastWebhookSync == null) return 'Never synced';
    return _formatTimeDifference(_lastWebhookSync!);
  }
  
  /// Get human-readable last history sync text
  String getLastHistorySyncText() {
    if (_lastHistorySync == null) return 'Never synced';
    return _formatTimeDifference(_lastHistorySync!);
  }
  
  /// Check if realtime data is stale (older than 10 minutes)
  bool get isRealtimeDataStale {
    if (_lastRealtimeSync == null) return true;
    final diff = DateTime.now().difference(_lastRealtimeSync!);
    return diff.inMinutes > 10;
  }
  
  /// Check if history data is stale (older than 6 hours)
  bool get isHistoryDataStale {
    if (_lastHistorySync == null) return true;
    final diff = DateTime.now().difference(_lastHistorySync!);
    return diff.inHours > 6;
  }
  
  /// Format time difference to human-readable string
  String _formatTimeDifference(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
  
  // ==================== SETTERS (called from main.dart) ====================
  
  /// Update connection state
  void updateConnectionState({
    required bool connected,
    String? deviceId,
    String? deviceName,
    int? batteryLevel,
  }) {
    _isConnected = connected;
    _deviceId = deviceId;
    _deviceName = deviceName;
    _deviceBatteryLevel = batteryLevel;
    
    _saveToStorage();
    notifyListeners();
    
    if (kDebugMode) {
      print('📱 [DeviceStatusService] Connection: ${connected ? "CONNECTED" : "DISCONNECTED"}');
      if (connected && deviceName != null) {
        print('   Device: $deviceName ($deviceId)');
      }
    }
  }
  
  /// Update realtime sync timestamp
  void updateRealtimeSyncTime(DateTime syncTime) {
    _lastRealtimeSync = syncTime;
    _saveToStorage();
    notifyListeners();
    
    if (kDebugMode) {
      print('⏰ [DeviceStatusService] Realtime sync updated: ${getLastRealtimeSyncText()}');
    }
  }
  
  /// Update history sync timestamp
  void updateHistorySyncTime(DateTime syncTime) {
    _lastHistorySync = syncTime;
    _saveToStorage();
    notifyListeners();
    
    if (kDebugMode) {
      print('⏰ [DeviceStatusService] History sync updated: ${getLastHistorySyncText()}');
    }
  }
  
  /// Update webhook sync timestamp
  void updateWebhookSyncTime(DateTime syncTime) {
    _lastWebhookSync = syncTime;
    _saveToStorage();
    notifyListeners();
    
    if (kDebugMode) {
      print('⏰ [DeviceStatusService] Webhook sync updated: ${getLastWebhookSyncText()}');
    }
  }
  
  /// Update Bluetooth status
  void updateBluetoothStatus(bool isOn) {
    if (_isBluetoothOn != isOn) {
      _isBluetoothOn = isOn;
      notifyListeners();
      
      if (kDebugMode) {
        print('📡 [DeviceStatusService] Bluetooth: ${isOn ? "ON" : "OFF"}');
      }
    }
  }
  
  /// Update Internet status
  void updateInternetStatus(bool isConnected) {
    if (_isInternetConnected != isConnected) {
      _isInternetConnected = isConnected;
      notifyListeners();
      
      if (kDebugMode) {
        print('🌐 [DeviceStatusService] Internet: ${isConnected ? "CONNECTED" : "DISCONNECTED"}');
      }
    }
  }
  
  // ==================== PERSISTENCE ====================
  
  /// Save data to SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('device_isConnected', _isConnected);
      if (_deviceId != null) await prefs.setString('device_id', _deviceId!);
      if (_deviceName != null) await prefs.setString('device_name', _deviceName!);
      if (_deviceBatteryLevel != null) await prefs.setInt('device_batteryLevel', _deviceBatteryLevel!);
      
      if (_lastRealtimeSync != null) {
        await prefs.setString('device_lastRealtimeSync', _lastRealtimeSync!.toIso8601String());
      }
      if (_lastHistorySync != null) {
        await prefs.setString('device_lastHistorySync', _lastHistorySync!.toIso8601String());
      }
      if (_lastWebhookSync != null) {
        await prefs.setString('device_lastWebhookSync', _lastWebhookSync!.toIso8601String());
      }
      
      if (kDebugMode) {
        print('💾 [DeviceStatusService] Status saved to storage');
      }
    } catch (e) {
      print('❌ [DeviceStatusService] Error saving to storage: $e');
    }
  }
  
  /// Load data from SharedPreferences
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _isConnected = prefs.getBool('device_isConnected') ?? false;
      _deviceId = prefs.getString('device_id');
      _deviceName = prefs.getString('device_name');
      _deviceBatteryLevel = prefs.getInt('device_batteryLevel');
      
      final realtimeSyncStr = prefs.getString('device_lastRealtimeSync');
      if (realtimeSyncStr != null) {
        _lastRealtimeSync = DateTime.parse(realtimeSyncStr);
      }
      
      final historySyncStr = prefs.getString('device_lastHistorySync');
      if (historySyncStr != null) {
        _lastHistorySync = DateTime.parse(historySyncStr);
      }
      
      final webhookSyncStr = prefs.getString('device_lastWebhookSync');
      if (webhookSyncStr != null) {
        _lastWebhookSync = DateTime.parse(webhookSyncStr);
      }
      
      notifyListeners();
      
      if (kDebugMode) {
        print('📂 [DeviceStatusService] Status loaded from storage');
        print('   Device: ${_deviceName ?? "None"}');
        print('   Last realtime sync: ${getLastRealtimeSyncText()}');
        print('   Last history sync: ${getLastHistorySyncText()}');
      }
    } catch (e) {
      print('❌ [DeviceStatusService] Error loading from storage: $e');
    }
  }
  
  /// Clear all device data
  Future<void> clearAllData() async {
    try {
      _isConnected = false;
      _deviceId = null;
      _deviceName = null;
      _deviceBatteryLevel = null;
      _lastRealtimeSync = null;
      _lastHistorySync = null;
      _lastWebhookSync = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('device_isConnected');
      await prefs.remove('device_id');
      await prefs.remove('device_name');
      await prefs.remove('device_batteryLevel');
      await prefs.remove('device_lastRealtimeSync');
      await prefs.remove('device_lastHistorySync');
      await prefs.remove('device_lastWebhookSync');
      
      notifyListeners();
      
      print('🗑️  [DeviceStatusService] All device data cleared');
    } catch (e) {
      print('❌ [DeviceStatusService] Error clearing data: $e');
    }
  }
  
  // ==================== CLEANUP ====================
  
  @override
  void dispose() {
    _refreshTimer?.cancel(); // Cancel the timer when service is disposed
    super.dispose();
    
    if (kDebugMode) {
      print('🛑 [DeviceStatusService] Auto-refresh timer cancelled');
    }
  }
}
