import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'; // ✅ FIX #3: BLE status checking

/// Monitors reconnection and triggers actions if SDK takes too long
/// Ticket #1: Reduce reconnection timeout from 60s to 15s
/// ✅ FIX #3: Check actual BLE hardware state, not just SDK state
class ReconnectionMonitor {
  Timer? _reconnectionTimeoutTimer;
  DateTime? _disconnectTime;
  int _reconnectionAttempts = 0;
  final FlutterReactiveBle _ble = FlutterReactiveBle(); // ✅ FIX #3: BLE radio access
  
  /// Configuration
  /// ✅ FIX #4: Increased from 15s to 30s for better SDK stability
  static const Duration timeout = Duration(seconds: 30); // Was 15s, increased to 30s
  static const int maxAttempts = 3;
  
  /// Callbacks
  Function()? onTimeout;
  Function(Duration duration)? onReconnected;
  Function()? onManualReconnect; // ✅ FIX #3: Trigger manual reconnect
  
  /// Start monitoring (call when disconnect detected)
  void startMonitoring({
    required Function() onTimeoutCallback,
    Function()? onManualReconnectCallback, // ✅ FIX #3: Optional manual reconnect
  }) {
    print('⏱️ [ReconnectionMonitor] Starting ${timeout.inSeconds}s timeout...');
    
    _disconnectTime = DateTime.now();
    _reconnectionAttempts++;
    onTimeout = onTimeoutCallback;
    onManualReconnect = onManualReconnectCallback; // ✅ FIX #3: Store callback
    
    // Cancel existing timer
    _reconnectionTimeoutTimer?.cancel();
    
    // Start timeout timer
    _reconnectionTimeoutTimer = Timer(timeout, () async {
      final elapsed = DateTime.now().difference(_disconnectTime!);
      print('⏱️ [ReconnectionMonitor] Timeout expired after ${elapsed.inSeconds}s');
      
      // ✅ FIX #3: Check actual BLE hardware state
      await _checkHardwareState();
      
      onTimeout?.call(); // Always call, no max limit
      print('🔄 [ReconnectionMonitor] Attempt #$_reconnectionAttempts (no limit)');
    });
  }
  
  /// ✅ FIX #3: Check actual BLE hardware state and attempt manual reconnect if ready
  Future<void> _checkHardwareState() async {
    try {
      final bleStatus = await _ble.statusStream.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => BleStatus.unknown,
      );
      
      print('🔍 [ReconnectionMonitor] BLE radio status: $bleStatus');
      
      if (bleStatus == BleStatus.ready) {
        print('✅ [ReconnectionMonitor] Hardware ready - attempting manual reconnect...');
        
        // Trigger manual reconnect callback if provided
        if (onManualReconnect != null) {
          try {
            onManualReconnect!();
            print('✅ [ReconnectionMonitor] Manual reconnect triggered');
          } catch (e) {
            print('❌ [ReconnectionMonitor] Manual reconnect failed: $e');
          }
        } else {
          print('⚠️ [ReconnectionMonitor] No manual reconnect callback provided');
        }
      } else {
        print('⚠️ [ReconnectionMonitor] Hardware not ready: $bleStatus');
        print('💡 [ReconnectionMonitor] SDK will retry when hardware becomes available');
      }
    } catch (e) {
      print('⚠️ [ReconnectionMonitor] Cannot check BLE status: $e');
    }
  }
  
  /// Stop monitoring (call when reconnected)
  void stopMonitoring({bool reconnected = false}) {
    _reconnectionTimeoutTimer?.cancel();
    
    if (reconnected && _disconnectTime != null) {
      final duration = DateTime.now().difference(_disconnectTime!);
      print('✅ [ReconnectionMonitor] Reconnected in ${duration.inSeconds}s');
      onReconnected?.call(duration);
      
      // Reset attempts on successful reconnection
      _reconnectionAttempts = 0;
    }
    
    _disconnectTime = null;
  }
  
  /// Reset (call when user manually disconnects)
  void reset() {
    stopMonitoring();
    _reconnectionAttempts = 0;
  }
  
  /// Get current status (for debugging)
  Map<String, dynamic> getStatus() {
    return {
      'isMonitoring': _reconnectionTimeoutTimer?.isActive ?? false,
      'attempts': _reconnectionAttempts,
      'disconnectTime': _disconnectTime?.toIso8601String(),
      'timeoutSeconds': timeout.inSeconds,
    };
  }
}
