import 'dart:async';
import 'package:hc20/hc20.dart';

/// Sends periodic "ping" to device to prevent connection timeout
/// Ticket #5: Prevent premature disconnections (99s uptime issue)
class BleKeepaliveService {
  Timer? _keepaliveTimer;
  int _pingCount = 0;
  int _failedPings = 0;
  
  /// Configuration
  static const Duration keepaliveInterval = Duration(seconds: 30);
  static const Duration pingTimeout = Duration(seconds: 5);
  static const int maxFailedPings = 3;
  
  /// Start sending keepalive pings every 30 seconds
  void start(Hc20Client client, Hc20Device device) {
    print('💓 [BleKeepalive] Starting ${keepaliveInterval.inSeconds}s keepalive pings');
    
    _pingCount = 0;
    _failedPings = 0;
    
    _keepaliveTimer?.cancel();
    _keepaliveTimer = Timer.periodic(keepaliveInterval, (timer) async {
      await _sendPing(client, device);
    });
  }
  
  /// Send a single ping to keep connection alive
  Future<void> _sendPing(Hc20Client client, Hc20Device device) async {
    try {
      _pingCount++;
      print('💓 [BleKeepalive] Sending ping #$_pingCount...');
      
      // Request real-time data (lightweight operation to keep connection alive)
      final stream = client.realtimeV2(device);
      
      // Take first data point with timeout
      await stream.first.timeout(
        pingTimeout,
        onTimeout: () {
          throw TimeoutException('Ping timeout after ${pingTimeout.inSeconds}s');
        },
      );
      
      // Reset failed count on success
      if (_failedPings > 0) {
        print('✅ [BleKeepalive] Ping recovered (previous failures: $_failedPings)');
        _failedPings = 0;
      } else {
        print('✅ [BleKeepalive] Ping #$_pingCount successful');
      }
    } catch (e) {
      _failedPings++;
      print('⚠️ [BleKeepalive] Ping #$_pingCount failed ($_failedPings/$maxFailedPings): $e');
      
      // If too many failures, assume connection is dead
      if (_failedPings >= maxFailedPings) {
        print('❌ [BleKeepalive] Too many failed pings - connection likely dead');
        print('   SDK will handle reconnection');
        // Don't stop timer - let it continue for when connection recovers
      }
    }
  }
  
  /// Stop keepalive pings
  void stop() {
    print('🛑 [BleKeepalive] Stopping (sent $_pingCount pings, $_failedPings failed)');
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    _pingCount = 0;
    _failedPings = 0;
  }
  
  /// Get status (for debugging)
  Map<String, dynamic> getStatus() {
    return {
      'isActive': _keepaliveTimer?.isActive ?? false,
      'totalPings': _pingCount,
      'failedPings': _failedPings,
      'intervalSeconds': keepaliveInterval.inSeconds,
    };
  }
}
