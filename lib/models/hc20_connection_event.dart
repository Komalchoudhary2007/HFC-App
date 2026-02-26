import 'package:hc20/hc20.dart';

/// Connection event types from SDK
enum HC20ConnectionEventType {
  connected,    // Initial connection established
  reconnected,  // Auto-reconnection successful
  disconnected, // Connection lost
}

/// Connection event data emitted by HC20Service
/// 
/// This class wraps SDK connection state changes and forwards them
/// to app components for reaction (time sync, API calls, UI updates, etc.)
class HC20ConnectionEvent {
  final HC20ConnectionEventType type;
  final Hc20Device? device;
  final String? reason;
  final DateTime timestamp;

  HC20ConnectionEvent({
    required this.type,
    this.device,
    this.reason,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'HC20ConnectionEvent{type: $type, device: ${device?.name}, reason: $reason, timestamp: $timestamp}';
  }
}
