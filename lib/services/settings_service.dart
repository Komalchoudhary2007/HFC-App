import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SettingsService - Manages app settings and user preferences
/// 
/// Features:
/// - Notification preferences (stress, fatigue, BP, SpO2 alerts)
/// - Auto-reconnect preferences
/// - Data sync preferences
/// - Display preferences (theme, temperature unit)
/// - Data persistence across app restarts
/// 
/// Usage:
/// ```dart
/// final settings = Provider.of<SettingsService>(context);
/// print('Notifications enabled: ${settings.notificationsEnabled}');
/// await settings.setStressAlertNotificationsEnabled(true);
/// ```
class SettingsService extends ChangeNotifier {
  // ==================== NOTIFICATION PREFERENCES ====================
  bool _notificationsEnabled = true;
  bool _disconnectNotificationsEnabled = true;
  bool _lowBatteryNotificationsEnabled = true;
  bool _stressAlertNotificationsEnabled = true;
  bool _fatigueAlertNotificationsEnabled = true;
  bool _bpAlertsEnabled = false;
  bool _spo2AlertsEnabled = true;
  
  // ==================== AUTO-RECONNECT PREFERENCES ====================
  bool _autoReconnectEnabled = true;
  int _autoReconnectInterval = 30; // seconds
  
  // ==================== DATA SYNC PREFERENCES ====================
  bool _autoSyncEnabled = true;
  int _syncInterval = 5; // minutes
  bool _backgroundSyncEnabled = true;
  
  // ==================== DISPLAY PREFERENCES ====================
  bool _showRealtimeGraph = true;
  String _temperatureUnit = 'celsius'; // 'celsius' or 'fahrenheit'
  String _theme = 'light'; // 'light', 'dark', 'auto'
  
  // ==================== GETTERS ====================
  
  // Notifications
  bool get notificationsEnabled => _notificationsEnabled;
  bool get disconnectNotificationsEnabled => _disconnectNotificationsEnabled;
  bool get lowBatteryNotificationsEnabled => _lowBatteryNotificationsEnabled;
  bool get stressAlertNotificationsEnabled => _stressAlertNotificationsEnabled;
  bool get fatigueAlertNotificationsEnabled => _fatigueAlertNotificationsEnabled;
  bool get stressAlertsEnabled => _stressAlertNotificationsEnabled;
  bool get fatigueAlertsEnabled => _fatigueAlertNotificationsEnabled;
  bool get bpAlertsEnabled => _bpAlertsEnabled;
  bool get spo2AlertsEnabled => _spo2AlertsEnabled;
  
  // Auto-reconnect
  bool get autoReconnectEnabled => _autoReconnectEnabled;
  int get autoReconnectInterval => _autoReconnectInterval;
  
  // Data sync
  bool get autoSyncEnabled => _autoSyncEnabled;
  int get syncInterval => _syncInterval;
  bool get backgroundSyncEnabled => _backgroundSyncEnabled;
  
  // Display
  bool get showRealtimeGraph => _showRealtimeGraph;
  String get temperatureUnit => _temperatureUnit;
  String get theme => _theme;
  
  // ==================== SETTERS (with persistence) ====================
  
  // Notification Setters
  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    await _saveToStorage();
    notifyListeners();
    
    if (kDebugMode) {
      print('⚙️  [SettingsService] Notifications: ${value ? "ENABLED" : "DISABLED"}');
    }
  }
  
  Future<void> setDisconnectNotificationsEnabled(bool value) async {
    _disconnectNotificationsEnabled = value;
    await _saveToStorage();
    notifyListeners();
  }
  
  Future<void> setLowBatteryNotificationsEnabled(bool value) async {
    _lowBatteryNotificationsEnabled = value;
    await _saveToStorage();
    notifyListeners();
  }
  
  Future<void> setStressAlertNotificationsEnabled(bool value) async {
    _stressAlertNotificationsEnabled = value;
    await _saveToStorage();
    notifyListeners();
    
    if (kDebugMode) {
      print('⚙️  [SettingsService] Stress alerts: ${value ? "ENABLED" : "DISABLED"}');
    }
  }
  
  Future<void> setFatigueAlertNotificationsEnabled(bool value) async {
    _fatigueAlertNotificationsEnabled = value;
    await _saveToStorage();
    notifyListeners();
  }
  
  Future<void> setStressAlerts(bool value) async {
    _stressAlertNotificationsEnabled = value;
    await _saveToStorage();
    notifyListeners();
  }
  
  Future<void> setFatigueAlerts(bool value) async {
    _fatigueAlertNotificationsEnabled = value;
    await _saveToStorage();
    notifyListeners();
  }
  
  Future<void> setBpAlerts(bool value) async {
    _bpAlertsEnabled = value;
    await _saveToStorage();
    notifyListeners();
  }
  
  Future<void> setSpo2Alerts(bool value) async {
    _spo2AlertsEnabled = value;
    await _saveToStorage();
    notifyListeners();
  }
  
  // Auto-reconnect Setters
  Future<void> setAutoReconnectEnabled(bool value) async {
    _autoReconnectEnabled = value;
    await _saveToStorage();
    notifyListeners();
    
    if (kDebugMode) {
      print('⚙️  [SettingsService] Auto-reconnect: ${value ? "ENABLED" : "DISABLED"}');
    }
  }
  
  Future<void> setAutoReconnectInterval(int seconds) async {
    _autoReconnectInterval = seconds;
    await _saveToStorage();
    notifyListeners();
    
    if (kDebugMode) {
      print('⚙️  [SettingsService] Reconnect interval: ${seconds}s');
    }
  }
  
  // Data Sync Setters
  Future<void> setAutoSyncEnabled(bool value) async {
    _autoSyncEnabled = value;
    await _saveToStorage();
    notifyListeners();
  }
  
  Future<void> setSyncInterval(int minutes) async {
    _syncInterval = minutes;
    await _saveToStorage();
    notifyListeners();
    
    if (kDebugMode) {
      print('⚙️  [SettingsService] Sync interval: ${minutes}min');
    }
  }
  
  Future<void> setBackgroundSyncEnabled(bool value) async {
    _backgroundSyncEnabled = value;
    await _saveToStorage();
    notifyListeners();
  }
  
  // Display Setters
  Future<void> setShowRealtimeGraph(bool value) async {
    _showRealtimeGraph = value;
    await _saveToStorage();
    notifyListeners();
  }
  
  Future<void> setTemperatureUnit(String unit) async {
    if (unit != 'celsius' && unit != 'fahrenheit') {
      print('❌ [SettingsService] Invalid temperature unit: $unit');
      return;
    }
    
    _temperatureUnit = unit;
    await _saveToStorage();
    notifyListeners();
    
    if (kDebugMode) {
      print('⚙️  [SettingsService] Temperature unit: $unit');
    }
  }
  
  Future<void> setTheme(String theme) async {
    if (theme != 'light' && theme != 'dark' && theme != 'auto') {
      print('❌ [SettingsService] Invalid theme: $theme');
      return;
    }
    
    _theme = theme;
    await _saveToStorage();
    notifyListeners();
    
    if (kDebugMode) {
      print('⚙️  [SettingsService] Theme: $theme');
    }
  }
  
  // ==================== PERSISTENCE ====================
  
  /// Save all settings to SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Notifications
      await prefs.setBool('settings_notificationsEnabled', _notificationsEnabled);
      await prefs.setBool('settings_disconnectNotificationsEnabled', _disconnectNotificationsEnabled);
      await prefs.setBool('settings_lowBatteryNotificationsEnabled', _lowBatteryNotificationsEnabled);
      await prefs.setBool('settings_stressAlertNotificationsEnabled', _stressAlertNotificationsEnabled);
      await prefs.setBool('settings_fatigueAlertNotificationsEnabled', _fatigueAlertNotificationsEnabled);
      await prefs.setBool('settings_bpAlertsEnabled', _bpAlertsEnabled);
      await prefs.setBool('settings_spo2AlertsEnabled', _spo2AlertsEnabled);
      
      // Auto-reconnect
      await prefs.setBool('settings_autoReconnectEnabled', _autoReconnectEnabled);
      await prefs.setInt('settings_autoReconnectInterval', _autoReconnectInterval);
      
      // Data sync
      await prefs.setBool('settings_autoSyncEnabled', _autoSyncEnabled);
      await prefs.setInt('settings_syncInterval', _syncInterval);
      await prefs.setBool('settings_backgroundSyncEnabled', _backgroundSyncEnabled);
      
      // Display
      await prefs.setBool('settings_showRealtimeGraph', _showRealtimeGraph);
      await prefs.setString('settings_temperatureUnit', _temperatureUnit);
      await prefs.setString('settings_theme', _theme);
      
      if (kDebugMode) {
        print('💾 [SettingsService] Settings saved to storage');
      }
    } catch (e) {
      print('❌ [SettingsService] Error saving to storage: $e');
    }
  }
  
  /// Load settings from SharedPreferences
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Notifications
      _notificationsEnabled = prefs.getBool('settings_notificationsEnabled') ?? true;
      _disconnectNotificationsEnabled = prefs.getBool('settings_disconnectNotificationsEnabled') ?? true;
      _lowBatteryNotificationsEnabled = prefs.getBool('settings_lowBatteryNotificationsEnabled') ?? true;
      _stressAlertNotificationsEnabled = prefs.getBool('settings_stressAlertNotificationsEnabled') ?? true;
      _fatigueAlertNotificationsEnabled = prefs.getBool('settings_fatigueAlertNotificationsEnabled') ?? true;
      _bpAlertsEnabled = prefs.getBool('settings_bpAlertsEnabled') ?? false;
      _spo2AlertsEnabled = prefs.getBool('settings_spo2AlertsEnabled') ?? true;
      
      // Auto-reconnect
      _autoReconnectEnabled = prefs.getBool('settings_autoReconnectEnabled') ?? true;
      _autoReconnectInterval = prefs.getInt('settings_autoReconnectInterval') ?? 30;
      
      // Data sync
      _autoSyncEnabled = prefs.getBool('settings_autoSyncEnabled') ?? true;
      _syncInterval = prefs.getInt('settings_syncInterval') ?? 5;
      _backgroundSyncEnabled = prefs.getBool('settings_backgroundSyncEnabled') ?? true;
      
      // Display
      _showRealtimeGraph = prefs.getBool('settings_showRealtimeGraph') ?? true;
      _temperatureUnit = prefs.getString('settings_temperatureUnit') ?? 'celsius';
      _theme = prefs.getString('settings_theme') ?? 'light';
      
      notifyListeners();
      
      if (kDebugMode) {
        print('📂 [SettingsService] Settings loaded from storage');
        print('   Notifications: $_notificationsEnabled');
        print('   Auto-reconnect: $_autoReconnectEnabled (${_autoReconnectInterval}s)');
        print('   Sync interval: ${_syncInterval}min');
      }
    } catch (e) {
      print('❌ [SettingsService] Error loading from storage: $e');
    }
  }
  
  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    try {
      // Reset to default values
      _notificationsEnabled = true;
      _disconnectNotificationsEnabled = true;
      _lowBatteryNotificationsEnabled = true;
      _stressAlertNotificationsEnabled = true;
      _fatigueAlertNotificationsEnabled = true;
      _bpAlertsEnabled = false;
      _spo2AlertsEnabled = true;
      _autoReconnectEnabled = true;
      _autoReconnectInterval = 30;
      _autoSyncEnabled = true;
      _syncInterval = 5;
      _backgroundSyncEnabled = true;
      _showRealtimeGraph = true;
      _temperatureUnit = 'celsius';
      _theme = 'light';
      
      await _saveToStorage();
      notifyListeners();
      
      print('🔄 [SettingsService] Settings reset to defaults');
    } catch (e) {
      print('❌ [SettingsService] Error resetting settings: $e');
    }
  }
  
  /// Clear all settings data
  Future<void> clearAllData() async {
    await resetToDefaults();
    print('🗑️  [SettingsService] All settings cleared (reset to defaults)');
  }
}

