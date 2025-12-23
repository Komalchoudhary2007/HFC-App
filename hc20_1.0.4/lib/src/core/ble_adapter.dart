import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:meta/meta.dart';
import '../raw/config.dart';

@immutable
class BleIds {
  final Uuid serviceFff0 = Uuid.parse("0000FFF0-0000-1000-8000-00805F9B34FB");
  final Uuid charFff1 = Uuid.parse("0000FFF1-0000-1000-8000-00805F9B34FB");
  final Uuid charFff2 = Uuid.parse("0000FFF2-0000-1000-8000-00805F9B34FB");
  final Uuid svcHr = Uuid.parse("0000180D-0000-1000-8000-00805F9B34FB");
  final Uuid charHr = Uuid.parse("00002A37-0000-1000-8000-00805F9B34FB");
  BleIds();
}

class Hc20BleAdapter {
  final FlutterReactiveBle _ble;
  final BleIds ids;
  final Map<String, StreamSubscription<ConnectionStateUpdate>> _connSubs = {};
  final Map<String, Function(String)?> _reconnectCallbacks = {};
  final Map<String, Function(String)?> _disconnectCallbacks = {};
  final Map<String, bool> _autoReconnectEnabled = {};
  final Map<String, Timer?> _reconnectTimers = {};
  final Map<String, bool> _isReconnecting = {};
  final Map<String, int> _reconnectAttempts = {};
  
  Hc20BleAdapter({FlutterReactiveBle? ble, BleIds? ids}) : _ble = ble ?? FlutterReactiveBle(), ids = ids ?? BleIds();
  
  /// Get the underlying FlutterReactiveBle instance (for ConnectionManager)
  FlutterReactiveBle get bleInstance => _ble;

  Stream<DiscoveredDevice> scan({required bool allowDuplicates}) {
    // On Android 12+ (API 31+), location is not required when using BLUETOOTH_SCAN with neverForLocation flag
    // On older Android versions and iOS, location services are required for BLE scanning
    final bool requireLocation = Platform.isAndroid 
        ? false  // Android 12+ uses BLUETOOTH_SCAN with neverForLocation, older versions still need location but we handle it via permissions
        : true;  // iOS requires location services for BLE scanning
    
    // Scan without service UUIDs on both platforms - devices may advertise manufacturer data
    // but not always include service UUIDs in scan response
    // Android: Use balanced or lowLatency mode depending on requirements
    // iOS: Use lowLatency for faster detection
    final ScanMode scanMode = Platform.isAndroid 
        ? ScanMode.lowLatency  // Low latency helps Android discover devices faster
        : ScanMode.lowLatency;
    
    return _ble
        .scanForDevices(
          withServices: const [],  // Empty - scan all devices, filter by manufacturer data
          scanMode: scanMode, 
          requireLocationServicesEnabled: requireLocation
        )
        .where((d) {
          // Filter by manufacturer data containing HC20 identifier (0xB8)
          // Also accept devices that advertise the HC20 service UUID (0xFFF0)
          // as a fallback in case manufacturer data parsing differs on Android
          final hasService = d.serviceUuids.contains(ids.serviceFff0);
          final hasManufacturerData = _isHc20Adv(d.manufacturerData);
          
          // Debug logging for Android
          if (Platform.isAndroid) {
            final mfrHex = d.manufacturerData.isEmpty 
                ? 'empty' 
                : d.manufacturerData.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
            final services = d.serviceUuids.map((u) => u.toString()).join(', ');
            
            if (hasManufacturerData || hasService) {
              // Log accepted devices
              //Hc20CloudConfig.debugPrint('HC20 SCAN DEBUG: ✅ ACCEPTED device id=${d.id} name=${d.name} mfr=[$mfrHex] services=[$services] hasMfr=$hasManufacturerData hasSvc=$hasService');
            } else {
              // Log filtered devices
              //Hc20CloudConfig.debugPrint('HC20 SCAN DEBUG: ❌ FILTERED device id=${d.id} name=${d.name} mfr=[$mfrHex] services=[$services]');
            }
          }
          
          // Accept if either manufacturer data matches OR service UUID matches
          // This handles cases where Android might parse manufacturer data differently
          // TEMPORARY: On Android, also check device name as fallback (remove after testing)
          if (Platform.isAndroid && !hasManufacturerData && !hasService) {
            // Check if device name contains HC20 or similar patterns (temporary debugging)
            final name = d.name.toLowerCase();
            if (name.contains('B20') || name.contains('hc-20')) {
              //Hc20CloudConfig.debugPrint('HC20 SCAN DEBUG: ⚠️ ACCEPTED BY NAME device id=${d.id} name=${d.name}');
              return true;
            }
          }
          
          return hasManufacturerData || hasService;
        })
        .distinct((a, b) => !allowDuplicates && a.id == b.id);
  }

  bool _isHc20Adv(Uint8List mfr) {
    if (mfr.isEmpty) return false;
    
    // According to protocol, HC20 devices can advertise in two formats:
    // 1. Broadcast Data Format: xx FF B8 xx xx xx ...
    //    - 0xFF is custom data type
    //    - 0xB8 is the first byte of custom data (HC20 identifier)
    // 2. Response Broadcast Format: 0B FF B6 xx xx B7 xx xx xx xx xx xx
    //    - 0xB6 and 0xB7 are markers for response format
    //    - Data following 0xB7 represents device MAC address in little-endian
    
    // Check for Broadcast Format (0xB8):
    // Simple check: look for 0xB8 anywhere in the data
    if (mfr.any((b) => b == 0xB8)) {
      return true;
    }
    
    // Enhanced check: look for pattern FF B8 (custom data type followed by HC20 identifier)
    for (int i = 0; i < mfr.length - 1; i++) {
      if (mfr[i] == 0xFF && mfr[i + 1] == 0xB8) {
        return true;
      }
    }
    
    // Check for Response Broadcast Format (0xB6 and 0xB7):
    // Format: 0B FF B6 xx xx B7 xx xx xx xx xx xx
    // Look for both 0xB6 and 0xB7 in the data (they should appear together)
    final hasB6 = mfr.any((b) => b == 0xB6);
    final hasB7 = mfr.any((b) => b == 0xB7);
    if (hasB6 && hasB7) {
      // Additional check: verify 0xB7 appears after 0xB6 (more robust)
      int b6Index = -1;
      int b7Index = -1;
      for (int i = 0; i < mfr.length; i++) {
        if (mfr[i] == 0xB6 && b6Index == -1) b6Index = i;
        if (mfr[i] == 0xB7 && b7Index == -1) b7Index = i;
      }
      if (b6Index >= 0 && b7Index > b6Index) {
        return true;
      }
    }
    
    return false;
  }

  /// Enable automatic reconnection for a device
  /// When enabled, the adapter will automatically attempt to reconnect
  /// when the connection is lost, and call the provided callback when reconnected.
  void enableAutoReconnect(String deviceId, {Function(String)? onReconnected, Function(String)? onDisconnected}) {
    _autoReconnectEnabled[deviceId] = true;
    if (onReconnected != null) {
      _reconnectCallbacks[deviceId] = onReconnected;
    }
    if (onDisconnected != null) {
      _disconnectCallbacks[deviceId] = onDisconnected;
    }
    Hc20CloudConfig.debugPrint('[HC20BleAdapter] Auto-reconnect enabled for device: $deviceId');
  }

  /// Disable automatic reconnection for a device
  void disableAutoReconnect(String deviceId) {
    _autoReconnectEnabled[deviceId] = false;
    _reconnectCallbacks.remove(deviceId);
    _disconnectCallbacks.remove(deviceId);
    _reconnectTimers[deviceId]?.cancel();
    _reconnectTimers.remove(deviceId);
    _isReconnecting[deviceId] = false;
    _reconnectAttempts.remove(deviceId);
    Hc20CloudConfig.debugPrint('[HC20BleAdapter] Auto-reconnect disabled for device: $deviceId');
  }

  Future<void> connect(String deviceId, {bool enableAutoReconnect = false}) async {
    // If already connected and monitoring, don't reconnect
    if (_connSubs.containsKey(deviceId) && !enableAutoReconnect) {
      return;
    }
    
    // Cancel any existing reconnection timer
    _reconnectTimers[deviceId]?.cancel();
    _reconnectTimers.remove(deviceId);
    _isReconnecting[deviceId] = false;
    
    final completer = Completer<void>();
    Timer? fallback;
    
    // Cancel existing subscription if reconnecting
    if (enableAutoReconnect && _connSubs.containsKey(deviceId)) {
      await _connSubs[deviceId]?.cancel();
      _connSubs.remove(deviceId);
    }
    
    final sub = _ble
        .connectToDevice(id: deviceId, connectionTimeout: const Duration(seconds: 10))
        .listen((update) async {
      // Handle connection state changes
      if (update.connectionState == DeviceConnectionState.connected) {
        if (!completer.isCompleted) {
          fallback?.cancel();
          completer.complete();
        }
        // Reset reconnecting flag and attempt counter
        _isReconnecting[deviceId] = false;
        _reconnectTimers[deviceId]?.cancel();
        _reconnectTimers.remove(deviceId);
        _reconnectAttempts.remove(deviceId);
        
        // Call reconnection callback if this was a reconnection
        if (enableAutoReconnect && _reconnectCallbacks.containsKey(deviceId)) {
          Hc20CloudConfig.debugPrint('[HC20BleAdapter] Device reconnected: $deviceId');
          _reconnectCallbacks[deviceId]?.call(deviceId);
        }
        return;
      }
      
      // Handle disconnection
      if (update.connectionState == DeviceConnectionState.disconnected) {
        Hc20CloudConfig.debugPrint('[HC20BleAdapter] Device disconnected: $deviceId');
        
        // Call disconnection callback if registered
        if (_disconnectCallbacks.containsKey(deviceId)) {
          Hc20CloudConfig.debugPrint('[HC20BleAdapter] Calling disconnection callback for $deviceId');
          _disconnectCallbacks[deviceId]?.call(deviceId);
        }
        
        // If auto-reconnect is enabled, start reconnection process
        if (_autoReconnectEnabled[deviceId] == true && (_isReconnecting[deviceId] != true)) {
          _isReconnecting[deviceId] = true;
          _scheduleReconnect(deviceId);
        }
        
        // Complete with error if this was initial connection
        if (!completer.isCompleted && !enableAutoReconnect) {
          completer.completeError(Exception('Connection lost during initial connect'));
        }
        return;
      }
      
      // Consider discovery success as connected enough
      try {
        final services = await _ble.getDiscoveredServices(deviceId);
        if (services.isNotEmpty && !completer.isCompleted) {
          fallback?.cancel();
          completer.complete();
          return;
        }
      } catch (_) {}
    }, onError: (Object e, StackTrace st) {
      Hc20CloudConfig.debugPrint('[HC20BleAdapter] Connection error for $deviceId: $e');
      
      // If auto-reconnect is enabled, schedule reconnection
      if (_autoReconnectEnabled[deviceId] == true && (_isReconnecting[deviceId] != true)) {
        _isReconnecting[deviceId] = true;
        _scheduleReconnect(deviceId);
      }
      
      if (!completer.isCompleted) completer.completeError(e, st);
    });
    
    _connSubs[deviceId] = sub;
    
    // Fallback: if platform doesn't emit connected but link is usable, avoid blocking UI
    fallback = Timer(const Duration(milliseconds: 600), () {
      if (!completer.isCompleted) completer.complete();
    });
    
    await completer.future;
    
    // Give the peripheral a brief moment and discover services
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try { await _ble.getDiscoveredServices(deviceId); } catch (_) {}
  }

  void _scheduleReconnect(String deviceId) {
    // Cancel any existing timer
    _reconnectTimers[deviceId]?.cancel();
    
    // Increment attempt counter
    _reconnectAttempts[deviceId] = (_reconnectAttempts[deviceId] ?? 0) + 1;
    final attemptCount = _reconnectAttempts[deviceId]!;
    
    // Exponential backoff: start with 2 seconds, max 30 seconds
    final delaySeconds = (attemptCount <= 5) 
        ? 2 * (1 << (attemptCount - 1)) // 2, 4, 8, 16, 32 seconds
        : 30; // Max 30 seconds
    
    Hc20CloudConfig.debugPrint('[HC20BleAdapter] Scheduling reconnection for $deviceId in ${delaySeconds}s (attempt $attemptCount)');
    
    _reconnectTimers[deviceId] = Timer(Duration(seconds: delaySeconds), () async {
      if (_autoReconnectEnabled[deviceId] != true) {
        Hc20CloudConfig.debugPrint('[HC20BleAdapter] Auto-reconnect disabled, cancelling reconnection for $deviceId');
        _isReconnecting[deviceId] = false;
        _reconnectAttempts.remove(deviceId);
        return;
      }
      
      Hc20CloudConfig.debugPrint('[HC20BleAdapter] Attempting to reconnect to $deviceId...');
      try {
        await connect(deviceId, enableAutoReconnect: true);
        // Reset attempt counter on successful reconnection
        _reconnectAttempts.remove(deviceId);
      } catch (e) {
        Hc20CloudConfig.debugPrint('[HC20BleAdapter] Reconnection attempt failed for $deviceId: $e');
        // Schedule another attempt
        _isReconnecting[deviceId] = false;
        _scheduleReconnect(deviceId);
      }
    });
  }

  Future<void> disconnect(String deviceId, {bool keepAutoReconnect = false}) async {
    // Only disable auto-reconnect if explicitly requested
    // By default, keep it enabled so device can reconnect when it comes back in range
    if (!keepAutoReconnect) {
      disableAutoReconnect(deviceId);
    }
    final sub = _connSubs.remove(deviceId);
    await sub?.cancel();
  }

  Stream<List<int>> subscribe(String deviceId, Uuid service, Uuid characteristic) {
    final ctrl = StreamController<List<int>>.broadcast();
    StreamSubscription<List<int>>? sub;
    () async {
      try {
        // Warm up service discovery to reduce iOS race conditions
        await _warmupServices(deviceId, const Duration(seconds: 2));
        final ch = QualifiedCharacteristic(deviceId: deviceId, serviceId: service, characteristicId: characteristic);
        sub = _ble.subscribeToCharacteristic(ch).listen(
          (data) => ctrl.add(data),
          onError: (e, st) async {
            // Retry once after re-discovery if characteristic not yet resolved
            await _warmupServices(deviceId, const Duration(seconds: 1));
            try {
              sub?.cancel();
              sub = _ble.subscribeToCharacteristic(ch).listen((d) => ctrl.add(d), onError: ctrl.addError);
            } catch (e2, st2) {
              ctrl.addError(e2, st2);
            }
          },
        );
      } catch (e, st) {
        ctrl.addError(e, st);
      }
    }();
    ctrl.onCancel = () async { await sub?.cancel(); };
    return ctrl.stream;
  }

  Future<void> _warmupServices(String deviceId, Duration total) async {
    final deadline = DateTime.now().add(total);
    while (DateTime.now().isBefore(deadline)) {
      try { await _ble.getDiscoveredServices(deviceId); } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<void> write(String deviceId, Uuid service, Uuid characteristic, List<int> value, {bool withoutResponse = true}) async {
    final ch = QualifiedCharacteristic(deviceId: deviceId, serviceId: service, characteristicId: characteristic);
    final hex = value.map((b)=>b.toRadixString(16).padLeft(2,'0')).join(' ');
    if (characteristic == ids.charFff2) {
      // Per spec: all commands are written to 0xFFF2 without response
      Hc20CloudConfig.debugPrint('HC20 TX device=$deviceId mode=writeWithoutResponse svc=${service.toString()} ch=${characteristic.toString()} bytes=$hex');
      await _ble.writeCharacteristicWithoutResponse(ch, value: value);
      return;
    }
    // Default for other chars: with response
    Hc20CloudConfig.debugPrint('HC20 TX device=$deviceId mode=writeWithResponse svc=${service.toString()} ch=${characteristic.toString()} bytes=$hex');
    await _ble.writeCharacteristicWithResponse(ch, value: value);
  }
}


