import 'dart:async';
import 'dart:io';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../raw/config.dart';

/// Manages persistent storage of last connected device and monitors Bluetooth state
class ConnectionManager {
  static const String _lastDeviceIdKey = 'hc20_last_connected_device_id';
  static const String _lastDeviceNameKey = 'hc20_last_connected_device_name';
  
  final FlutterReactiveBle _ble;
  final SharedPreferences _prefs;
  StreamSubscription<BleStatus>? _bleStatusSubscription;
  Function(String deviceId, String? deviceName)? _onBluetoothEnabled;
  Function()? _onBluetoothDisabled;
  Timer? _periodicReconnectTimer;
  bool _isMonitoring = false;
  bool _periodicReconnectEnabled = false;

  ConnectionManager(this._ble, this._prefs);

  /// Get the last connected device ID
  String? getLastConnectedDeviceId() {
    return _prefs.getString(_lastDeviceIdKey);
  }

  /// Get the last connected device name
  String? getLastConnectedDeviceName() {
    return _prefs.getString(_lastDeviceNameKey);
  }

  /// Save the last connected device
  Future<void> saveLastConnectedDevice(String deviceId, String? deviceName) async {
    await _prefs.setString(_lastDeviceIdKey, deviceId);
    if (deviceName != null && deviceName.isNotEmpty) {
      await _prefs.setString(_lastDeviceNameKey, deviceName);
    } else {
      await _prefs.remove(_lastDeviceNameKey);
    }
    Hc20CloudConfig.debugPrint('[ConnectionManager] Saved last connected device: $deviceId (${deviceName ?? 'unknown'})');
  }

  /// Clear the last connected device
  Future<void> clearLastConnectedDevice() async {
    await _prefs.remove(_lastDeviceIdKey);
    await _prefs.remove(_lastDeviceNameKey);
    Hc20CloudConfig.debugPrint('[ConnectionManager] Cleared last connected device');
  }

  /// Start monitoring Bluetooth state changes
  /// When Bluetooth turns back on, the callback will be called with the last connected device
  /// When Bluetooth turns off, onBluetoothDisabled callback will be called
  void startMonitoringBluetoothState(
    Function(String deviceId, String? deviceName) onBluetoothEnabled, {
    bool enablePeriodicReconnect = true,
    Function()? onBluetoothDisabled,
  }) {
    if (_isMonitoring) {
      Hc20CloudConfig.debugPrint('[ConnectionManager] Already monitoring Bluetooth state');
      return;
    }

    _onBluetoothEnabled = onBluetoothEnabled;
    _onBluetoothDisabled = onBluetoothDisabled;
    _isMonitoring = true;
    _periodicReconnectEnabled = enablePeriodicReconnect;
    
    // Monitor Bluetooth status changes
    _bleStatusSubscription = _ble.statusStream.listen((status) {
      Hc20CloudConfig.debugPrint('[ConnectionManager] Bluetooth status changed: $status');
      
      if (status == BleStatus.ready) {
        // Bluetooth is ready/enabled
        final lastDeviceId = getLastConnectedDeviceId();
        if (lastDeviceId != null && lastDeviceId.isNotEmpty) {
          final lastDeviceName = getLastConnectedDeviceName();
          Hc20CloudConfig.debugPrint('[ConnectionManager] Bluetooth enabled, attempting to reconnect to last device: $lastDeviceId');
          // Wait a bit for Bluetooth to fully initialize
          Future.delayed(const Duration(seconds: 1), () {
            _onBluetoothEnabled?.call(lastDeviceId, lastDeviceName);
          });
        } else {
          Hc20CloudConfig.debugPrint('[ConnectionManager] Bluetooth enabled but no last device to reconnect to');
        }
      } else if (status == BleStatus.poweredOff || status == BleStatus.unauthorized || status == BleStatus.unsupported) {
        // Bluetooth is turned off or unavailable
        Hc20CloudConfig.debugPrint('[ConnectionManager] Bluetooth disabled/unavailable: $status');
        _onBluetoothDisabled?.call();
      }
    });
    
    // Start periodic reconnection attempts if enabled
    if (_periodicReconnectEnabled) {
      _startPeriodicReconnect();
    }
    
    Hc20CloudConfig.debugPrint('[ConnectionManager] Started monitoring Bluetooth state');
  }
  
  /// Start periodic reconnection attempts (every 30 seconds)
  /// Note: On iOS, periodic timers may not fire reliably when app is in background.
  /// The BLE adapter's connection state monitoring handles most reconnection scenarios.
  void _startPeriodicReconnect() {
    _periodicReconnectTimer?.cancel();
    
    // On iOS, use longer intervals to reduce battery drain and respect background limitations
    // On Android, shorter intervals are fine
    final interval = Platform.isIOS 
        ? const Duration(seconds: 60)  // iOS: 60 seconds to respect background limitations
        : const Duration(seconds: 30); // Android: 30 seconds
    
    _periodicReconnectTimer = Timer.periodic(interval, (timer) {
      final lastDeviceId = getLastConnectedDeviceId();
      if (lastDeviceId != null && lastDeviceId.isNotEmpty && _ble.status == BleStatus.ready) {
        final lastDeviceName = getLastConnectedDeviceName();
        Hc20CloudConfig.debugPrint('[ConnectionManager] Periodic reconnect attempt for device: $lastDeviceId');
        _onBluetoothEnabled?.call(lastDeviceId, lastDeviceName);
      }
    });
    Hc20CloudConfig.debugPrint('[ConnectionManager] Started periodic reconnection (${interval.inSeconds} seconds)');
  }
  
  /// Stop periodic reconnection attempts
  void _stopPeriodicReconnect() {
    _periodicReconnectTimer?.cancel();
    _periodicReconnectTimer = null;
    _periodicReconnectEnabled = false;
    Hc20CloudConfig.debugPrint('[ConnectionManager] Stopped periodic reconnection');
  }

  /// Stop monitoring Bluetooth state changes
  void stopMonitoringBluetoothState() {
    if (!_isMonitoring) return;
    
    _bleStatusSubscription?.cancel();
    _bleStatusSubscription = null;
    _onBluetoothEnabled = null;
    _onBluetoothDisabled = null;
    _isMonitoring = false;
    _stopPeriodicReconnect();
    Hc20CloudConfig.debugPrint('[ConnectionManager] Stopped monitoring Bluetooth state');
  }

  /// Dispose resources
  void dispose() {
    stopMonitoringBluetoothState();
  }
}

