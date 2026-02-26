import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

/// Monitors BLE hardware connection state to detect reconnections faster than SDK
/// This is COMPLEMENTARY to SDK's ConnectionManager, not a replacement
/// Ticket #2: Detect hardware reconnections 50-60s earlier
class BleConnectionMonitor {
  final FlutterReactiveBle _ble;
  final String _deviceId;
  
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  DeviceConnectionState _lastState = DeviceConnectionState.disconnected;
  DateTime? _lastStateChange;
  
  /// Callbacks
  Function()? onHardwareConnected;
  Function()? onHardwareDisconnected;
  
  BleConnectionMonitor({
    required FlutterReactiveBle ble,
    required String deviceId,
  }) : _ble = ble, _deviceId = deviceId;
  
  /// Start monitoring GATT connection state for specific device
  void startMonitoring({
    Function()? onConnected,
    Function()? onDisconnected,
  }) {
    print('👁️ [BleMonitor] Starting for device: $_deviceId');
    
    onHardwareConnected = onConnected;
    onHardwareDisconnected = onDisconnected;
    
    // Cancel existing subscription
    _connectionSubscription?.cancel();
    
    // Monitor connection state updates
    _connectionSubscription = _ble
        .connectToDevice(id: _deviceId)
        .listen(
          (ConnectionStateUpdate update) {
            _handleConnectionStateChange(update);
          },
          onError: (error) {
            print('⚠️ [BleMonitor] Stream error: $error');
          },
          cancelOnError: false, // Keep monitoring even if errors occur
        );
    
    print('✅ [BleMonitor] Monitoring active');
  }
  
  /// Handle connection state changes from hardware
  void _handleConnectionStateChange(ConnectionStateUpdate update) {
    final newState = update.connectionState;
    final now = DateTime.now();
    
    // Detect state transitions
    if (newState != _lastState) {
      print('🔔 [BleMonitor] State change: $_lastState → $newState');
      
      if (_lastStateChange != null) {
        final duration = now.difference(_lastStateChange!);
        print('⏱️ [BleMonitor] Duration in last state: ${duration.inSeconds}s');
      }
      
      // Handle specific transitions
      if (newState == DeviceConnectionState.connected && 
          _lastState == DeviceConnectionState.disconnected) {
        print('✅ [BleMonitor] HARDWARE CONNECTED - SDK may not know yet!');
        onHardwareConnected?.call();
      }
      
      if (newState == DeviceConnectionState.disconnected && 
          _lastState == DeviceConnectionState.connected) {
        print('❌ [BleMonitor] HARDWARE DISCONNECTED');
        onHardwareDisconnected?.call();
      }
      
      _lastState = newState;
      _lastStateChange = now;
    }
  }
  
  /// Stop monitoring
  void stopMonitoring() {
    print('🛑 [BleMonitor] Stopping');
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }
  
  /// Get current state
  DeviceConnectionState get currentState => _lastState;
  
  /// Check if hardware is connected (regardless of SDK state)
  bool get isHardwareConnected => _lastState == DeviceConnectionState.connected;
  
  /// Get status (for debugging)
  Map<String, dynamic> getStatus() {
    return {
      'deviceId': _deviceId,
      'currentState': _lastState.toString(),
      'isMonitoring': _connectionSubscription != null,
      'lastStateChange': _lastStateChange?.toIso8601String(),
    };
  }
}
