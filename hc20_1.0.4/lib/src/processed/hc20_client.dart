import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/ble_adapter.dart';
import '../core/transport.dart' show IHc20Transport, Hc20Transport, jsonPayload;
import '../core/response_parser.dart';
import '../core/errors.dart';
import '../core/connection_manager.dart';
import '../models/processed_models.dart';
import '../raw/raw_manager.dart' as raw;
import '../raw/uploader.dart' as raw_uploader;
import '../raw/parsers.dart';
import '../raw/config.dart';
import '../models/raw_models.dart';

class _HistoryPacket {
  final int index;
  final int yy, mm, dd;
  final Uint8List data;
  const _HistoryPacket(this.index, this.yy, this.mm, this.dd, this.data);
}

@immutable
class Hc20Config {
  /// OAuth client ID for cloud API authentication (required)
  final String clientId;
  
  /// OAuth client secret for cloud API authentication (required)
  final String clientSecret;
  
  const Hc20Config({
    required this.clientId,
    required this.clientSecret,
  });
}

class Hc20ScanFilter {
  final bool allowDuplicates;
  const Hc20ScanFilter({this.allowDuplicates = false});
}

class Hc20Client {
  final Hc20BleAdapter _ble;
  final IHc20Transport _tx;
  final raw.RawManager _raw;
  final ConnectionManager _connectionManager;
  Hc20Device? _connectedDevice;
  String? _deviceMacAddress;
  bool _sensorsEnabled = false; // Track if sensors are currently enabled
  
  // Connection state stream controller
  final StreamController<Hc20ConnectionStateUpdate> _connectionStateController = 
      StreamController<Hc20ConnectionStateUpdate>.broadcast();
  
  // Track if this is a reconnection attempt
  bool _isReconnectionAttempt = false;
  // Track if reconnected state was already emitted (to prevent duplicates)
  bool _reconnectedStateEmitted = false;
  
  // Mutex for serializing historical data retrieval operations
  // This prevents concurrent calls from interfering with each other and causing incomplete Bluetooth packets
  Completer<void>? _historyMutex;
  final List<Completer<void>> _historyQueue = [];
  int _historyMutexDepth = 0; // Track re-entrancy depth for nested calls

  // Sensor disable tracking for history operations
  // These fields track sensor state during historical data retrieval to avoid frequent disable/enable cycles
  bool _sensorsDisabledForHistory = false; // Track if sensors are currently disabled for history operations
  Hc20Device? _historyDevice; // Track device for sensor operations during history retrieval
  bool _sensorsWereEnabledBeforeHistory = false; // Track if sensors were enabled before history operations

  Hc20Client._(this._ble, this._tx, this._raw, this._connectionManager);

  static Future<Hc20Client> create({required Hc20Config config}) async {
    final ble = Hc20BleAdapter();
    final tx = Hc20Transport(ble);
    // RawManager is always created - raw upload is automatic
    // Create upload config from Hc20Config if OAuth credentials are provided
    // authUrl and baseUrl are always retrieved from Hc20CloudConfig
    final uploadConfig = raw_uploader.RawUploadConfig.cloud(
      clientId: config.clientId,
      clientSecret: config.clientSecret,
    );
    final rm = raw.RawManager(tx, uploadConfig: uploadConfig);
    
    // Initialize connection manager for persistent storage and Bluetooth state monitoring
    final prefs = await SharedPreferences.getInstance();
    final connectionManager = ConnectionManager(ble.bleInstance, prefs);
    
    final client = Hc20Client._(ble, tx, rm, connectionManager);
    
    // Start monitoring Bluetooth state and attempt to reconnect when Bluetooth turns back on
    // Also enable periodic reconnection attempts (every 30 seconds) to handle out-of-range scenarios
    connectionManager.startMonitoringBluetoothState((deviceId, deviceName) async {
      // Skip if already connected to this device
      if (client._connectedDevice?.id == deviceId) {
        Hc20CloudConfig.debugPrint('[HC20Client] Already connected to device: $deviceId, skipping reconnect');
        return;
      }
      
      Hc20CloudConfig.debugPrint('[HC20Client] Attempting to reconnect to last device: $deviceId (${deviceName ?? 'unknown'})');
      try {
        // Mark as reconnection attempt before connecting
        client._isReconnectionAttempt = true;
        // Create a device object from stored info
        final device = Hc20Device(deviceId, deviceName ?? 'HC20 Device');
        await client.connect(device);
        
        // Note: Reconnected state will be emitted by _handleReconnection() callback
        // when the BLE adapter detects the connection. If the callback doesn't fire
        // (e.g., connection was already established), we don't emit here to avoid duplicates.
        // The _handleReconnection() method will handle emitting the reconnected state.
        client._isReconnectionAttempt = false;
      } catch (e) {
        Hc20CloudConfig.debugPrint('[HC20Client] Failed to auto-reconnect: $e');
        client._isReconnectionAttempt = false;
        // Don't throw - periodic reconnect will try again later
      }
    }, enablePeriodicReconnect: true, onBluetoothDisabled: () {
      // Emit disconnected state when Bluetooth is turned off
      if (client._connectedDevice != null) {
        Hc20CloudConfig.debugPrint('[HC20Client] Bluetooth disabled, emitting disconnected state');
        client._connectionStateController.add(Hc20ConnectionStateUpdate(
          device: client._connectedDevice!,
          state: Hc20ConnectionState.disconnected,
        ));
        Hc20CloudConfig.debugPrint('[HC20Client] Connection state updated: Disconnected (Bluetooth disabled)');
        
        // Clear internal state but keep last connected device stored for auto-reconnect
        // This ensures reconnection attempts won't be incorrectly skipped
        client._connectedDevice = null;
        client._deviceMacAddress = null;
        client._sensorsEnabled = false;
        client._isReconnectionAttempt = false;
        client._reconnectedStateEmitted = false;
        Hc20CloudConfig.debugPrint('[HC20Client] Internal state cleared (last device kept for auto-reconnect)');
      }
    });
    
    return client;
  }

  Stream<Hc20Device> scan({Hc20ScanFilter filter = const Hc20ScanFilter()}) {
    return _ble
        .scan(allowDuplicates: filter.allowDuplicates)
        .map((d) => Hc20Device(d.id, d.name));
  }

  /// Stream of connection state updates
  /// Emits events when device connects, reconnects, or disconnects
  /// Use this to differentiate between initial connections and reconnections
  Stream<Hc20ConnectionStateUpdate> get connectionState => _connectionStateController.stream;

  Future<void> connect(Hc20Device device) async {
    _connectedDevice = device;
    
    // Check if this is a reconnection attempt (device was previously connected)
    // This flag will be set to true by ConnectionManager when reconnecting
    final wasPreviouslyConnected = _isReconnectionAttempt || 
        (_connectionManager.getLastConnectedDeviceId() == device.id && 
         _connectedDevice == null);
    
    // Save last connected device for auto-reconnect
    await _connectionManager.saveLastConnectedDevice(device.id, device.name);
    
    // Always enable auto-reconnect for automatic reconnection when device comes back in range
    // or when Bluetooth is turned back on
    await _ble.connect(device.id);
    _ble.enableAutoReconnect(
      device.id, 
      onReconnected: _handleReconnection,
      onDisconnected: _handleDisconnection,
    );
    _tx.notifications(device.id);
    
    // Reset reconnection flag after checking
    _isReconnectionAttempt = false;
    
    // Wait 5 seconds for device to fully initialize before reading device info
    Hc20CloudConfig.debugPrint('[HC20Client] Waiting 5 seconds for device to initialize...');
    await Future.delayed(Duration(seconds: 5));
    
    // Read device info to get MAC address
    // Retry up to 3 times on failure (iOS sometimes needs retries)
    bool macAddressSet = false;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        Hc20CloudConfig.debugPrint('[HC20Client] Reading device info (attempt $attempt/3)...');
        final deviceInfo = await readDeviceInfo(device);
        _deviceMacAddress = deviceInfo.mac;
        if (_deviceMacAddress != null && _deviceMacAddress!.isNotEmpty) {
          _raw.setMacAddress(_deviceMacAddress!);
          macAddressSet = true;
          Hc20CloudConfig.debugPrint('[HC20Client] MAC address successfully set: $_deviceMacAddress');
          break;
        } else {
          Hc20CloudConfig.debugPrint('[HC20Client] Warning: Device info returned empty MAC address');
        }
      } catch (e) {
        Hc20CloudConfig.debugPrint('[HC20Client] Warning: Could not read device info (attempt $attempt/3): $e');
        if (attempt < 3) {
          // Wait a bit before retrying
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
    
    if (!macAddressSet) {
      Hc20CloudConfig.debugPrint('[HC20Client] Warning: Could not read MAC address after 3 attempts. MAC will be set when sensors are enabled.');
    }
    
    // Emit connection state only after we've successfully connected and can communicate with the device
    // If this is a reconnection attempt, the state will be emitted in _handleReconnection
    // Otherwise, emit connected state for initial connection (only if we can read device info)
    // We emit after reading device info to confirm the connection is actually working
    if (!wasPreviouslyConnected) {
      // Only emit if we successfully read device info (confirms connection is working)
      // If device info read failed, connection might not be fully established
      if (macAddressSet) {
        _connectionStateController.add(Hc20ConnectionStateUpdate(
          device: device,
          state: Hc20ConnectionState.connected,
        ));
        _reconnectedStateEmitted = false; // Reset flag for initial connection
        Hc20CloudConfig.debugPrint('[HC20Client] Connection state updated: Connected');
      } else {
        Hc20CloudConfig.debugPrint('[HC20Client] Connection state not updated: Device info read failed, connection may not be fully established');
      }
    } else {
      // For reconnection attempts, reset flag - will be set in _handleReconnection
      _reconnectedStateEmitted = false;
    }
    
    // RawManager is always initialized - raw upload is automatic
    Hc20CloudConfig.debugPrint('[HC20Client] Starting RawManager for device: ${device.id}');
    await _raw.start(device.id);
    Hc20CloudConfig.debugPrint('[HC20Client] RawManager started successfully');
    
    // Enable continuous monitoring at 5-minute intervals where required
    try {
      await setParameters(device, {
        'health_monitor': {
          'spo2_monitor': '5,1',
          'bp_monitor': '5,1',
          'hrv_monitor': '5,1',
        }
      });
    } catch (_) {
      // ignore enabling failure; device may not support some keys
    }
    
    // Automatically enable sensors when device connects
    try {
      Hc20CloudConfig.debugPrint('[HC20Client] Automatically enabling sensors after connection...');
      await setSensorState(device);
        Hc20CloudConfig.debugPrint('[HC20Client] Sensors enabled automatically on connection');
    } catch (e) {
        Hc20CloudConfig.debugPrint('[HC20Client] Warning: Could not automatically enable sensors: $e');
      // Don't throw - connection is successful, sensors can be manually enabled later
    }
  }

  /// Handle disconnection when device goes out of range or Bluetooth is turned off
  /// This emits disconnected state to notify listeners
  void _handleDisconnection(String deviceId) {
    // Only emit if this is the currently connected device
    if (_connectedDevice?.id == deviceId) {
      Hc20CloudConfig.debugPrint('[HC20Client] Device disconnected: $deviceId');
      _connectionStateController.add(Hc20ConnectionStateUpdate(
        device: _connectedDevice!,
        state: Hc20ConnectionState.disconnected,
      ));
      Hc20CloudConfig.debugPrint('[HC20Client] Connection state updated: Disconnected');
      
      // Clear internal state but keep last connected device stored for auto-reconnect
      // This ensures reconnection attempts won't be incorrectly skipped
      _connectedDevice = null;
      _deviceMacAddress = null;
      _sensorsEnabled = false;
      _isReconnectionAttempt = false;
      _reconnectedStateEmitted = false;
      Hc20CloudConfig.debugPrint('[HC20Client] Internal state cleared (last device kept for auto-reconnect)');
    } else {
      Hc20CloudConfig.debugPrint('[HC20Client] Disconnection callback received for different device: expected ${_connectedDevice?.id ?? 'none'}, got $deviceId');
    }
  }

  /// Handle reconnection after device comes back in range
  /// This resumes all services and streams that were active before disconnection
  /// Always enables sensors and uploads raw data to cloud
  Future<void> _handleReconnection(String deviceId) async {
    // If _connectedDevice is null (e.g., after automatic disconnect), restore it from stored device
    if (_connectedDevice == null) {
      final lastDeviceId = _connectionManager.getLastConnectedDeviceId();
      final lastDeviceName = _connectionManager.getLastConnectedDeviceName();
      if (lastDeviceId == deviceId) {
        _connectedDevice = Hc20Device(deviceId, lastDeviceName ?? 'HC20 Device');
        Hc20CloudConfig.debugPrint('[HC20Client] Restored connected device from stored info: $deviceId');
      } else {
        Hc20CloudConfig.debugPrint('[HC20Client] Reconnection callback received for unknown device: $deviceId');
        return;
      }
    } else if (_connectedDevice!.id != deviceId) {
      Hc20CloudConfig.debugPrint('[HC20Client] Reconnection callback received for different device: expected ${_connectedDevice!.id}, got $deviceId');
      return;
    }
    
    Hc20CloudConfig.debugPrint('[HC20Client] Handling reconnection for device: $deviceId');
    
    try {
      // Re-initialize notifications with force reconnect to re-establish subscriptions
      _tx.notifications(deviceId, forceReconnect: true);
      
      // Restart RawManager to resume sensor data streaming
      Hc20CloudConfig.debugPrint('[HC20Client] Restarting RawManager after reconnection...');
      await _raw.stop(); // Stop first to clean up
      await _raw.start(deviceId);
      
      // Re-set MAC address if we have it
      if (_deviceMacAddress != null && _deviceMacAddress!.isNotEmpty) {
        _raw.setMacAddress(_deviceMacAddress!);
      }
      
      // Re-enable continuous monitoring
      try {
        await setParameters(_connectedDevice!, {
          'health_monitor': {
            'spo2_monitor': '5,1',
            'bp_monitor': '5,1',
            'hrv_monitor': '5,1',
          }
        });
      } catch (_) {
        // ignore enabling failure; device may not support some keys
      }
      
      // Always enable sensors and upload raw data to cloud on reconnection
      // This ensures raw data streaming is active after reconnection
      Hc20CloudConfig.debugPrint('[HC20Client] Enabling sensors and raw data upload after reconnection...');
      bool canCommunicate = false;
      try {
        // Always try to read device info to verify we can actually communicate with the device
        // This ensures the connectionState reflects the actual connection status
        try {
          final deviceInfo = await readDeviceInfo(_connectedDevice!);
          canCommunicate = true;
          
          // If MAC address was lost during disconnect, restore it
          if (_deviceMacAddress == null || _deviceMacAddress!.isEmpty) {
            if (deviceInfo.mac.isNotEmpty) {
              _deviceMacAddress = deviceInfo.mac;
              _raw.setMacAddress(_deviceMacAddress!);
              Hc20CloudConfig.debugPrint('[HC20Client] MAC address restored: $_deviceMacAddress');
            }
          }
        } catch (e) {
          Hc20CloudConfig.debugPrint('[HC20Client] Warning: Could not read device info to verify connection: $e');
          // If we have a MAC address from before, assume connection is working
          // (device info read might fail for other reasons)
          if (_deviceMacAddress != null && _deviceMacAddress!.isNotEmpty) {
            canCommunicate = true;
            Hc20CloudConfig.debugPrint('[HC20Client] Using existing MAC address, assuming connection is working');
          }
        }
        
        // Call setSensorState to ensure MAC address is set and sensors are enabled
        // This will also ensure raw data upload is properly configured
        await setSensorState(_connectedDevice!);
        Hc20CloudConfig.debugPrint('[HC20Client] Sensors and raw data upload enabled successfully after reconnection');
      } catch (e) {
        Hc20CloudConfig.debugPrint('[HC20Client] Error enabling sensors after reconnection: $e');
        // Don't throw - connection is restored, sensors can be manually re-enabled
      }
      
      // Emit reconnection state only after we've verified we can communicate with the device
      // This ensures the connectionState reflects the actual connection status
      if (!_reconnectedStateEmitted) {
        // Only emit if we can communicate with the device (read device info successfully or have MAC address)
        if (canCommunicate) {
          _connectionStateController.add(Hc20ConnectionStateUpdate(
            device: _connectedDevice!,
            state: Hc20ConnectionState.reconnected,
          ));
          _reconnectedStateEmitted = true;
          Hc20CloudConfig.debugPrint('[HC20Client] Connection state updated: Reconnected');
        } else {
          Hc20CloudConfig.debugPrint('[HC20Client] Connection state not updated: Cannot verify device communication');
        }
      }
      
      Hc20CloudConfig.debugPrint('[HC20Client] Reconnection handling completed successfully');
    } catch (e, stackTrace) {
      Hc20CloudConfig.debugPrint('[HC20Client] Error during reconnection handling: $e');
      Hc20CloudConfig.debugPrint('[HC20Client] Stack trace: $stackTrace');
    }
  }

  Future<Hc20DeviceInfo> readDeviceInfo(Hc20Device d) async {
    // Per documentation: payload must be 0x01
    final f = await _tx.request(d.id, 0x1F, const [0x01]);
    final jstr = _payloadJsonString(f.payload, leading: 1);
    return Hc20DeviceInfo.fromJson(json.decode(jstr));
  }

  Future<void> factoryReset(Hc20Device d) async {
    await _tx.request(d.id, 0x1F, [0x02]);
  }

  Future<void> setParameters(Hc20Device d, Map<String, dynamic> params) async {
    // 0x02 set: 0x01 + JSON + 0x00
    await _tx.request(d.id, 0x02, jsonPayload(0x01, params));
  }

  Future<Map<String, dynamic>> getParameters(
      Hc20Device d, Map<String, dynamic> request) async {
    final f = await _tx.request(d.id, 0x02, jsonPayload(0x02, request));
    final j = json.decode(_payloadJsonString(f.payload, leading: 1))
        as Map<String, dynamic>;
    return j;
  }

  Future<void> setTime(Hc20Device d,
      {required int timestamp, int timezone = 8}) async {
    await _tx.request(d.id, 0x04,
        jsonPayload(0x01, {'timestamp': timestamp, 'timezone': timezone}));
  }

  Future<Hc20Time> getTime(Hc20Device d) async {
    final f = await _tx.request(d.id, 0x04, [0x02]);
    final m = json.decode(_payloadJsonString(f.payload, leading: 1))
        as Map<String, dynamic>;
    return Hc20Time(m['timestamp'] ?? 0, m['timezone'] ?? 8);
  }

  /// Streams real-time health data from the device.
  /// 
  /// Note: The realtime data trigger request is serialized with historical data retrieval
  /// operations to prevent Bluetooth packet conflicts. When historical data is being retrieved,
  /// the realtime trigger will wait until the historical operation completes.
  Stream<Hc20RealtimeV2> realtimeV2(Hc20Device d) {
    final ctrl = StreamController<Hc20RealtimeV2>.broadcast();
    StreamSubscription? sub;

    ctrl.onListen = () {
      // 1) Subscribe first to avoid missing the first notify
      sub = _tx
          .notificationsParsed(d.id)
          .where((m) => m is Hc20MsgRealtimeV2)
          .cast<Hc20MsgRealtimeV2>()
          .map((m) => m.rt)
          .listen(ctrl.add, onError: ctrl.addError);

      // 2) Trigger for Realtime V2 (0x05 with 0x02) - serialized with historical data operations
      // This ensures realtime data doesn't interfere with historical data retrieval
      // Note: No device needed here as this doesn't disable sensors
      () async {
        await _acquireHistoryMutex(device: null);
        try {
          await _tx.request(d.id, 0x05, const [0x02]);
          Hc20CloudConfig.debugPrint('[HC20Client] Realtime V2 trigger sent');
        } catch (e) {
          Hc20CloudConfig.debugPrint('[HC20Client] Error triggering realtime V2: $e');
        } finally {
          _releaseHistoryMutex();
        }
      }();
    };

    ctrl.onCancel = () async {
      await sub?.cancel();
    };

    return ctrl.stream;
  }

  // (V1 removed)

  // Raw sensor data methods
  /// Get sensor configuration (IMU, PPG, ECG, GSR)
  Future<Hc20SensorConfig> getSensorConfig(Hc20Device d) async {
    final f = await _tx.request(d.id, 0x30, const [0x01]);
    final jstr = _payloadJsonString(f.payload, leading: 1);
    final jsonData = json.decode(jstr) as Map<String, dynamic>;
    return Hc20SensorConfig.fromJson(jsonData);
  }

  /// Enable sensors (IMU, PPG, and GSR)
  /// Automatically enables all components:
  /// - IMU: accelerometer, gyroscope, and magnetometer
  /// - PPG: green, red, and IR LEDs
  /// - GSR: enabled
  /// 
  /// Note: Sensor configuration (rate, depth, ranges) is read-only from the device.
  /// This method only enables/disables sensors using their existing configuration.
  /// 
  /// This method will read device info first to get the MAC address, then enable sensors.
  /// When sensors are enabled, automatic reconnection is also enabled to maintain
  /// sensor streaming in the background.
  Future<void> setSensorState(Hc20Device d) async {
    // Read device info first to get MAC address before enabling sensors
    // If MAC address was already set during connect(), use it; otherwise read again
    if (_deviceMacAddress == null || _deviceMacAddress!.isEmpty) {
      Hc20CloudConfig.debugPrint('[HC20Client] MAC address not set, reading device info to get MAC address before enabling sensors...');
      // Retry up to 3 times on failure (iOS sometimes needs retries)
      bool macAddressSet = false;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          Hc20CloudConfig.debugPrint('[HC20Client] Reading device info (attempt $attempt/3)...');
          final deviceInfo = await readDeviceInfo(d);
          if (deviceInfo.mac.isNotEmpty) {
            _deviceMacAddress = deviceInfo.mac;
            _raw.setMacAddress(deviceInfo.mac);
            macAddressSet = true;
            Hc20CloudConfig.debugPrint('[HC20Client] MAC address set: ${deviceInfo.mac}');
            break;
          } else {
            Hc20CloudConfig.debugPrint('[HC20Client] Warning: Device info returned empty MAC address (attempt $attempt/3)');
          }
        } catch (e) {
          Hc20CloudConfig.debugPrint('[HC20Client] Warning: Could not read device info (attempt $attempt/3): $e');
          if (attempt < 3) {
            // Wait a bit before retrying
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      }
      
      if (!macAddressSet) {
        throw Hc20Exception(0xC0, 'Device MAC address is empty after 3 attempts. Cannot enable sensors.');
      }
    } else {
      // MAC address already set, just ensure RawManager has it
      _raw.setMacAddress(_deviceMacAddress!);
      Hc20CloudConfig.debugPrint('[HC20Client] Using existing MAC address: $_deviceMacAddress, enabling sensors...');
    }
    
    // According to bluetooth_protocol_rawdata.md, there is no "Set Sensor Configuration" command.
    // Sensor configuration can only be read (0x30, 0x01), not set.
    // The device uses its existing configuration. We only enable/disable sensors.
    
    // Enable sensors using function code 0x30 with payload 0x02
    final payload = <String, dynamic>{
      'imu': {'ctrl': 0x07}, // Enable all IMU: accel (0x01) + gyro (0x02) + mag (0x04)
      'ppg': {'ctrl': 0x07}, // Enable all PPG: green (0x01) + red (0x02) + ir (0x04)
      'gsr': {'ctrl': 0x01}, // Enable GSR
    };
    await _tx.request(d.id, 0x30, jsonPayload(0x02, payload));
    
    // Mark sensors as enabled
    // Note: Auto-reconnect is already enabled in connect(), but we ensure the callback is set
    _sensorsEnabled = true;
    _ble.enableAutoReconnect(d.id, onReconnected: _handleReconnection);
    Hc20CloudConfig.debugPrint('[HC20Client] Sensors enabled successfully.');
  }

  /// Disable sensors (IMU, PPG, and GSR)
  /// Note: Auto-reconnect remains enabled to allow reconnection when device comes back in range
  Future<void> disableSensorState(Hc20Device d) async {
    final payload = <String, dynamic>{
      'imu': {'ctrl': 0x00}, // Disable all IMU sensors
      'ppg': {'ctrl': 0x00}, // Disable all PPG LEDs
      'gsr': {'ctrl': 0x00}, // Disable GSR
    };
    await _tx.request(d.id, 0x30, jsonPayload(0x02, payload));
    
    // Mark sensors as disabled
    // Note: We keep auto-reconnect enabled so the device can reconnect even when sensors are off
    _sensorsEnabled = false;
    Hc20CloudConfig.debugPrint('[HC20Client] Sensors disabled. Auto-reconnect remains enabled.');
  }

  /// Acquire the history mutex to serialize historical data retrieval operations
  /// This ensures only one historical data retrieval happens at a time to prevent
  /// incomplete Bluetooth packets when multiple calls are made concurrently
  /// Supports re-entrancy: if called from within a method that already holds the mutex,
  /// it will increment the depth counter instead of queuing
  /// Also handles sensor disable/enable lifecycle: disables sensors when first operation starts
  Future<void> _acquireHistoryMutex({Hc20Device? device}) async {
    // If we already hold the mutex (re-entrant call), just increment depth
    if (_historyMutexDepth > 0) {
      _historyMutexDepth++;
      Hc20CloudConfig.debugPrint('[HC20Client] History mutex re-entered (depth: $_historyMutexDepth)');
      return;
    }
    
    // If mutex is available, acquire it immediately
    if (_historyMutex == null) {
      _historyMutex = Completer<void>();
      _historyMutex!.complete();
      _historyMutexDepth = 1;
      Hc20CloudConfig.debugPrint('[HC20Client] History mutex acquired');
      
      // Disable sensors when first operation starts (if device provided and sensors are enabled)
      if (device != null && _sensorsEnabled && !_sensorsDisabledForHistory) {
        await _disableSensorsForHistoryOperations(device);
      }
      return;
    }
    
    // Otherwise, queue this operation
    final completer = Completer<void>();
    _historyQueue.add(completer);
    Hc20CloudConfig.debugPrint('[HC20Client] History mutex busy, queuing operation (queue length: ${_historyQueue.length})');
    await completer.future;
    _historyMutexDepth = 1;
    Hc20CloudConfig.debugPrint('[HC20Client] History mutex acquired from queue');
    
    // Disable sensors when first operation starts (if device provided and sensors are enabled)
    if (device != null && _sensorsEnabled && !_sensorsDisabledForHistory) {
      await _disableSensorsForHistoryOperations(device);
    }
  }
  
  /// Release the history mutex and process the next queued operation
  /// Supports re-entrancy: only releases when depth reaches 0
  /// Also handles sensor restore: re-enables sensors when all operations complete
  void _releaseHistoryMutex() {
    // If this is a re-entrant release, just decrement depth
    if (_historyMutexDepth > 1) {
      _historyMutexDepth--;
      Hc20CloudConfig.debugPrint('[HC20Client] History mutex re-entrant release (depth: $_historyMutexDepth)');
      return;
    }
    
    // Actually release the mutex
    _historyMutexDepth = 0;
    if (_historyQueue.isEmpty) {
      _historyMutex = null;
      Hc20CloudConfig.debugPrint('[HC20Client] History mutex released (no queued operations)');
      
      // Re-enable sensors when all operations complete (queue is empty)
      if (_sensorsDisabledForHistory && _historyDevice != null) {
        _restoreSensorsAfterAllHistoryOperations(_historyDevice!);
      }
    } else {
      final next = _historyQueue.removeAt(0);
      _historyMutex = Completer<void>();
      _historyMutex!.complete();
      next.complete();
      Hc20CloudConfig.debugPrint('[HC20Client] History mutex released, processing next operation (${_historyQueue.length} remaining)');
      // Don't restore sensors yet - there are more operations queued
    }
  }

  /// Disable sensors when starting historical data operations
  /// This is called once when the first operation starts (mutex depth goes from 0 to 1)
  Future<void> _disableSensorsForHistoryOperations(Hc20Device d) async {
    if (_sensorsDisabledForHistory) {
      // Already disabled, just update device reference
      _historyDevice = d;
      return;
    }
    
    _sensorsWereEnabledBeforeHistory = _sensorsEnabled;
    _historyDevice = d;
    
    if (_sensorsWereEnabledBeforeHistory) {
      try {
        await _temporarilyDisableSensors(d);
        _sensorsDisabledForHistory = true;
        Hc20CloudConfig.debugPrint('[HC20Client] Sensors disabled for historical data operations (queue length: ${_historyQueue.length})');
      } catch (e) {
        Hc20CloudConfig.debugPrint('[HC20Client] Warning: Failed to disable sensors before historical data retrieval: $e');
        // Continue anyway - historical data retrieval may still work
      }
    }
  }

  /// Re-enable sensors when all historical data operations complete
  /// This is called when the mutex is fully released (queue is empty)
  Future<void> _restoreSensorsAfterAllHistoryOperations(Hc20Device d) async {
    if (!_sensorsDisabledForHistory) {
      return;
    }
    
    if (_sensorsWereEnabledBeforeHistory) {
      try {
        await _restoreSensors(d, shouldRestore: true);
        Hc20CloudConfig.debugPrint('[HC20Client] Sensors restored after all historical data operations completed');
      } catch (e) {
        Hc20CloudConfig.debugPrint('[HC20Client] Warning: Failed to restore sensors after historical data retrieval: $e');
      }
    }
    
    // Reset tracking state
    _sensorsDisabledForHistory = false;
    _historyDevice = null;
    _sensorsWereEnabledBeforeHistory = false;
  }

  /// Temporarily disable sensors without changing the _sensorsEnabled flag
  /// This is used during historical data retrieval to prevent packet loss
  Future<void> _temporarilyDisableSensors(Hc20Device d) async {
    final payload = <String, dynamic>{
      'imu': {'ctrl': 0x00}, // Disable all IMU sensors
      'ppg': {'ctrl': 0x00}, // Disable all PPG LEDs
      'gsr': {'ctrl': 0x00}, // Disable GSR
    };
    await _tx.request(d.id, 0x30, jsonPayload(0x02, payload));
    Hc20CloudConfig.debugPrint('[HC20Client] Sensors temporarily disabled for historical data retrieval');
  }

  /// Re-enable sensors if they were previously enabled
  /// This is used after historical data retrieval to restore sensor streaming
  /// [shouldRestore] - if true, restores sensors; if false, does nothing
  Future<void> _restoreSensors(Hc20Device d, {required bool shouldRestore}) async {
    if (shouldRestore) {
      final payload = <String, dynamic>{
        'imu': {'ctrl': 0x07}, // Enable all IMU: accel (0x01) + gyro (0x02) + mag (0x04)
        'ppg': {'ctrl': 0x07}, // Enable all PPG: green (0x01) + red (0x02) + ir (0x04)
        'gsr': {'ctrl': 0x01}, // Enable GSR
      };
      await _tx.request(d.id, 0x30, jsonPayload(0x02, payload));
      Hc20CloudConfig.debugPrint('[HC20Client] Sensors restored after historical data retrieval');
    }
  }

  /// Read current sensor state
  Future<Hc20SensorState> readSensorState(Hc20Device d) async {
    final f = await _tx.request(d.id, 0x30, const [0x03]);
    final jstr = _payloadJsonString(f.payload, leading: 1);
    final jsonData = json.decode(jstr) as Map<String, dynamic>;
    return Hc20SensorState.fromJson(jsonData);
  }

  /// Stream IMU data (accelerometer, gyroscope, magnetometer)
  Stream<Hc20ImuData> streamImu(Hc20Device d) {
    final ctrl = StreamController<Hc20ImuData>.broadcast();
    StreamSubscription? sub;

    ctrl.onListen = () {
      sub = _tx
          .notifications(d.id)
          .where((f) => f.func == 0xB0 && f.payload.isNotEmpty && f.payload[0] == 0x81)
          .expand((f) => RawParsers.parseImuData(f.payload))
          .listen(ctrl.add, onError: ctrl.addError, cancelOnError: false);
    };

    ctrl.onCancel = () async {
      await sub?.cancel();
    };

    return ctrl.stream;
  }

  /// Stream PPG data (green, red, IR LEDs)
  Stream<Hc20PpgData> streamPpg(Hc20Device d) {
    final ctrl = StreamController<Hc20PpgData>.broadcast();
    StreamSubscription? sub;

    ctrl.onListen = () {
      sub = _tx
          .notifications(d.id)
          .where((f) => f.func == 0xB0 && f.payload.isNotEmpty && f.payload[0] == 0x82)
          .expand((f) => RawParsers.parsePpgData(f.payload))
          .listen(ctrl.add, onError: ctrl.addError, cancelOnError: false);
    };

    ctrl.onCancel = () async {
      await sub?.cancel();
    };

    return ctrl.stream;
  }

  /// Stream GSR data (I, Q, raw values)
  Stream<Hc20GsrData> streamGsr(Hc20Device d) {
    final ctrl = StreamController<Hc20GsrData>.broadcast();
    StreamSubscription? sub;

    ctrl.onListen = () {
      sub = _tx
          .notifications(d.id)
          .where((f) => f.func == 0xB0 && f.payload.isNotEmpty && f.payload[0] == 0x84)
          .expand((f) => RawParsers.parseGsrData(f.payload))
          .listen(ctrl.add, onError: ctrl.addError);
    };

    ctrl.onCancel = () async {
      await sub?.cancel();
    };

    return ctrl.stream;
  }

  Future<List<int>> readHistoryPacket(Hc20Device d,
      {required int dataType,
      required int yy,
      required int mm,
      required int dd,
      required int index}) async {
    // Acquire mutex to serialize historical data retrieval operations
    // Sensor disable/enable is handled by the mutex system
    await _acquireHistoryMutex(device: d);
    
    try {
      final msg = await _readHistoryMessage(d,
          dataType: dataType, yy: yy, mm: mm, dd: dd, index: index);
      return msg.data;
    } finally {
      // Always release mutex, even if operation fails
      // Sensor restoration happens in _releaseHistoryMutex when queue is empty
      _releaseHistoryMutex();
    }
  }

  // Convenience typed history getters (0x17):
  Future<Hc20AllDaySummary> getAllDaySummary(Hc20Device d,
      {required int yy, required int mm, required int dd}) async {
    // Use the same decoding logic as getAllDaySummaryRows for consistency
    // This ensures both methods handle the same JSON key variations
    final rows = await getAllDaySummaryRows(d, yy: yy, mm: mm, dd: dd);
    
    if (rows.isEmpty || !rows.first.valid) {
      return Hc20AllDaySummary(
          steps: 0,
          calories: 0,
          distance: 0,
          activeTime: 0,
          silentTime: 0,
          activeCalories: 0,
          silentCalories: 0);
    }
    
    // Extract values from the decoded row, handling all key variations
    final values = rows.first.values;
    return Hc20AllDaySummary(
      steps: (values['stepsTotal'] ?? values['steps'] ?? 0) as int,
      calories: (values['caloriesTotalKcal'] ?? values['calories'] ?? 0) as int,
      distance: (values['distanceTotalM'] ?? values['distance'] ?? 0) as int,
      activeTime: (values['activeTimeSec'] ?? values['active_time'] ?? 0) as int,
      silentTime: (values['silentTimeSec'] ?? values['silent_time'] ?? 0) as int,
      activeCalories: (values['activeCaloriesKcal'] ?? values['active_calories'] ?? 0) as int,
      silentCalories: (values['silentCaloriesKcal'] ?? values['silent_calories'] ?? 0) as int,
    );
  }

  String _isoString(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}T${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  int _leUint16(Uint8List data, int offset) =>
      data[offset] | (data[offset + 1] << 8);

  int _leInt16(Uint8List data, int offset) {
    int value = _leUint16(data, offset);
    if ((value & 0x8000) != 0) value -= 0x10000;
    return value;
  }

  int _leUint32(Uint8List data, int offset) =>
      data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24);

  int _leInt32(Uint8List data, int offset) {
    int value = _leUint32(data, offset);
    if ((value & 0x80000000) != 0) value -= 0x100000000;
    return value;
  }

  bool _allBytesAreFF(Uint8List data, int offset, int length) {
    for (int i = 0; i < length; i++) {
      if (offset + i >= data.length) return false;
      if (data[offset + i] != 0xFF) return false;
    }
    return true;
  }

  num? _numFromJson(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value;
      if (value is String) {
        final parsed = num.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  Future<List<Hc20AllDayRow>> getAllDaySummaryRows(
    Hc20Device d, {
    required int yy,
    required int mm,
    required int dd,
  }) {
    return getAllDayRows(
      d,
      type: Hc20HistoryType.allDaySummary,
      yy: yy,
      mm: mm,
      dd: dd,
    );
  }

  Future<List<Hc20AllDayRow>> getAllDayHeartRows(
    Hc20Device d, {
    required int yy,
    required int mm,
    required int dd,
    int? packetIndex,
  }) {
    return getAllDayRows(
      d,
      type: Hc20HistoryType.heart5s,
      yy: yy,
      mm: mm,
      dd: dd,
      packetIndex: packetIndex,
    );
  }

  Future<List<Hc20AllDayRow>> getAllDayStepsRows(
    Hc20Device d, {
    required int yy,
    required int mm,
    required int dd,
    int? packetIndex,
  }) {
    return getAllDayRows(
      d,
      type: Hc20HistoryType.steps5m,
      yy: yy,
      mm: mm,
      dd: dd,
      packetIndex: packetIndex,
    );
  }

  Future<List<Hc20AllDayRow>> getAllDaySpo2Rows(
    Hc20Device d, {
    required int yy,
    required int mm,
    required int dd,
    int? packetIndex,
  }) {
    return getAllDayRows(
      d,
      type: Hc20HistoryType.spo25m,
      yy: yy,
      mm: mm,
      dd: dd,
      packetIndex: packetIndex,
    );
  }

  Future<List<Hc20AllDayRow>> getAllDayRriRows(
    Hc20Device d, {
    required int yy,
    required int mm,
    required int dd,
    int? packetIndex,
  }) async {
    // Sensor disable/enable is handled by the mutex system in getAllDayRows
    // No need to track or restore sensors here
    
    try {
      // If specific packet is requested, get it and upload
      if (packetIndex != null) {
        final msg = await _readHistoryMessage(
          d,
          dataType: 0x04, // RRI type
          yy: yy,
          mm: mm,
          dd: dd,
          index: packetIndex,
        );
        final rows = await getAllDayRows(
          d,
          type: Hc20HistoryType.rri5s,
          yy: yy,
          mm: mm,
          dd: dd,
          packetIndex: packetIndex,
          restoreSensorsAfterDecode: false, // Don't restore yet - wait for upload
        );
        
        // Upload RRI data to cloud after parsing
        if (rows.isNotEmpty) {
          try {
            final deviceInfo = await readDeviceInfo(d);
            // Convert Hc20AllDayRow to Map format expected by uploader
            final rriEntries = rows.map((row) => <String, dynamic>{
              'dateTime': row.dateTime,
              'values': row.values,
              'valid': row.valid,
            }).toList();
            
            Hc20CloudConfig.debugPrint('[HC20Client] Triggering RRI upload for ${rows.length} row(s) from packet $packetIndex');
            await _raw.uploadAllDayRri(rriEntries, deviceInfo.mac, msg.index, msg.total);
          } catch (e, stackTrace) {
            // Log error but don't fail the method - return rows even if upload fails
            Hc20CloudConfig.debugPrint('[HC20Client] Error uploading RRI data: $e');
            Hc20CloudConfig.debugPrint('[HC20Client] Stack trace: $stackTrace');
          }
        }
        
        // Sensor restoration is handled by the mutex system when all operations complete
        // No need to restore sensors here
        return rows;
      }
      
      // If all packets are requested, fetch them and upload all together in batches
      final rows = await getAllDayRows(
        d,
        type: Hc20HistoryType.rri5s,
        yy: yy,
        mm: mm,
        dd: dd,
        packetIndex: packetIndex,
        restoreSensorsAfterDecode: false, // Don't restore yet - wait for upload
      );
      
      // Upload RRI data to cloud after parsing - collect all entries and batch together
      if (rows.isNotEmpty) {
        try {
          final deviceInfo = await readDeviceInfo(d);
          
          // Get total_packets for metadata
          int totalPackets = 0;
          try {
            final firstMsg = await _readHistoryMessage(
              d,
              dataType: 0x04,
              yy: yy,
              mm: mm,
              dd: dd,
              index: 1,
            );
            totalPackets = firstMsg.total;
          } catch (_) {
            // Fallback: estimate from row count (96 entries per packet, 8 minutes per packet)
            totalPackets = (rows.length / 96).ceil();
          }
          
          // Convert all rows to entries format and calculate packet index from timestamp
          // Each RRI packet covers 8 minutes (480 seconds), packet index is 1-based
          final allRriEntries = rows.map((row) {
            // Calculate packet index from timestamp
            final dt = DateTime.parse(row.dateTime);
            final secondsFromMidnight = dt.hour * 3600 + dt.minute * 60 + dt.second;
            // Packet index: 1-based, each packet = 480 seconds (8 minutes)
            final calculatedPacketIndex = (secondsFromMidnight ~/ 480) + 1;
            
            return <String, dynamic>{
              'dateTime': row.dateTime,
              'values': row.values,
              'valid': row.valid,
              'packet_index': calculatedPacketIndex, // Pre-calculate packet index for each entry
            };
          }).toList();
          
          Hc20CloudConfig.debugPrint('[HC20Client] Triggering RRI upload for ${allRriEntries.length} row(s) from all packets (will be batched into groups of 1000)');
          
          // Upload all entries together - uploader will batch into groups of 1000
          // Pass packetIndex 0 as placeholder since each entry has its own packet_index
          await _raw.uploadAllDayRri(allRriEntries, deviceInfo.mac, 0, totalPackets);
        } catch (e, stackTrace) {
          // Log error but don't fail the method - return rows even if upload fails
          Hc20CloudConfig.debugPrint('[HC20Client] Error uploading RRI data: $e');
          Hc20CloudConfig.debugPrint('[HC20Client] Stack trace: $stackTrace');
        }
      }
      
      // Sensor restoration is handled by the mutex system when all operations complete
      // No need to restore sensors here
      return rows;
    } catch (e, stackTrace) {
      // Sensor restoration is handled by the mutex system when all operations complete
      // No need to restore sensors here even on error
      Hc20CloudConfig.debugPrint('[HC20Client] Error in getAllDayRriRows: $e');
      Hc20CloudConfig.debugPrint('[HC20Client] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Hc20AllDayRow>> getAllDayTemperatureRows(
    Hc20Device d, {
    required int yy,
    required int mm,
    required int dd,
    int? packetIndex,
  }) async {
    // Sensor disable/enable is handled by the mutex system in getAllDayRows
    // No need to track or restore sensors here
    
    try {
      // If specific packet is requested, get it and upload
      if (packetIndex != null) {
        final rows = await getAllDayRows(
          d,
          type: Hc20HistoryType.temperature1m,
          yy: yy,
          mm: mm,
          dd: dd,
          packetIndex: packetIndex,
          restoreSensorsAfterDecode: false, // Don't restore yet - wait for upload
        );
        
        // Upload temperature data to cloud after parsing
        if (rows.isNotEmpty) {
          try {
            final deviceInfo = await readDeviceInfo(d);
            // Convert Hc20AllDayRow to Map format expected by uploader
            final temperatureEntries = rows.map((row) => <String, dynamic>{
              'dateTime': row.dateTime,
              'values': row.values,
              'valid': row.valid,
            }).toList();
            
            Hc20CloudConfig.debugPrint('[HC20Client] Triggering temperature upload for ${rows.length} row(s) from packet $packetIndex');
            await _raw.uploadAllDayTemperature(temperatureEntries, deviceInfo.mac);
          } catch (e, stackTrace) {
            // Log error but don't fail the method - return rows even if upload fails
            Hc20CloudConfig.debugPrint('[HC20Client] Error uploading temperature data: $e');
            Hc20CloudConfig.debugPrint('[HC20Client] Stack trace: $stackTrace');
          }
        }
        
        // Sensor restoration is handled by the mutex system when all operations complete
        // No need to restore sensors here
        return rows;
      }
      
      // If all packets are requested, fetch them and upload all together in batches
      final rows = await getAllDayRows(
        d,
        type: Hc20HistoryType.temperature1m,
        yy: yy,
        mm: mm,
        dd: dd,
        packetIndex: packetIndex,
        restoreSensorsAfterDecode: false, // Don't restore yet - wait for upload
      );
      
      // Upload temperature data to cloud after parsing - collect all entries and batch together
      if (rows.isNotEmpty) {
        try {
          final deviceInfo = await readDeviceInfo(d);
          
          // Convert all rows to entries format
          final allTemperatureEntries = rows.map((row) => <String, dynamic>{
            'dateTime': row.dateTime,
            'values': row.values,
            'valid': row.valid,
          }).toList();
          
          Hc20CloudConfig.debugPrint('[HC20Client] Triggering temperature upload for ${allTemperatureEntries.length} row(s) from all packets (will be batched into groups of 1000)');
          
          // Upload all entries together - uploader will batch into groups of 1000
          await _raw.uploadAllDayTemperature(allTemperatureEntries, deviceInfo.mac);
        } catch (e, stackTrace) {
          // Log error but don't fail the method - return rows even if upload fails
          Hc20CloudConfig.debugPrint('[HC20Client] Error uploading temperature data: $e');
          Hc20CloudConfig.debugPrint('[HC20Client] Stack trace: $stackTrace');
        }
      }
      
      // Sensor restoration is handled by the mutex system when all operations complete
      // No need to restore sensors here
      return rows;
    } catch (e, stackTrace) {
      // Sensor restoration is handled by the mutex system when all operations complete
      // No need to restore sensors here even on error
      Hc20CloudConfig.debugPrint('[HC20Client] Error in getAllDayTemperatureRows: $e');
      Hc20CloudConfig.debugPrint('[HC20Client] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Hc20AllDayRow>> getAllDayBaroRows(
    Hc20Device d, {
    required int yy,
    required int mm,
    required int dd,
    int? packetIndex,
  }) {
    return getAllDayRows(
      d,
      type: Hc20HistoryType.baro1m,
      yy: yy,
      mm: mm,
      dd: dd,
      packetIndex: packetIndex,
    );
  }

  Future<List<Hc20AllDayRow>> getAllDayBpRows(
    Hc20Device d, {
    required int yy,
    required int mm,
    required int dd,
    int? packetIndex,
  }) {
    return getAllDayRows(
      d,
      type: Hc20HistoryType.bp5m,
      yy: yy,
      mm: mm,
      dd: dd,
      packetIndex: packetIndex,
    );
  }

  Future<List<Hc20AllDayRow>> getAllDayHrvRows(
    Hc20Device d, {
    required int yy,
    required int mm,
    required int dd,
    int? packetIndex,
  }) async {
    // Sensor disable/enable is handled by the mutex system in getAllDayRows
    // No need to track or restore sensors here
    
    try {
      final rows = await getAllDayRows(
        d,
        type: Hc20HistoryType.hrv5m,
        yy: yy,
        mm: mm,
        dd: dd,
        packetIndex: packetIndex,
        restoreSensorsAfterDecode: false, // Don't restore yet - wait for upload
      );
      
      // Upload HRV data to cloud after parsing
      if (rows.isNotEmpty) {
        try {
          final deviceInfo = await readDeviceInfo(d);
          // Convert Hc20AllDayRow to Map format expected by uploader
          final hrvEntries = rows.map((row) => <String, dynamic>{
            'dateTime': row.dateTime,
            'values': row.values,
            'valid': row.valid,
          }).toList();
          
          Hc20CloudConfig.debugPrint('[HC20Client] Triggering HRV upload for ${rows.length} row(s)');
          await _raw.uploadAllDayHrv(hrvEntries, deviceInfo.mac);
        } catch (e, stackTrace) {
          // Log error but don't fail the method - return rows even if upload fails
          Hc20CloudConfig.debugPrint('[HC20Client] Error uploading HRV data: $e');
          Hc20CloudConfig.debugPrint('[HC20Client] Stack trace: $stackTrace');
        }
      }
      
      // Sensor restoration is handled by the mutex system when all operations complete
      // No need to restore sensors here
      return rows;
    } catch (e, stackTrace) {
      // Sensor restoration is handled by the mutex system when all operations complete
      // No need to restore sensors here even on error
      Hc20CloudConfig.debugPrint('[HC20Client] Error in getAllDayHrvRows: $e');
      Hc20CloudConfig.debugPrint('[HC20Client] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Hc20AllDayRow>> getAllDayGnssRows(
    Hc20Device d, {
    required int yy,
    required int mm,
    required int dd,
    int? packetIndex,
  }) {
    return getAllDayRows(
      d,
      type: Hc20HistoryType.gnss1m,
      yy: yy,
      mm: mm,
      dd: dd,
      packetIndex: packetIndex,
    );
  }

  Future<List<Hc20AllDayRow>> getAllDaySleepRows(
    Hc20Device d, {
    required int yy,
    required int mm,
    required int dd,
    int? packetIndex,
    bool includeSummary = false,
  }) {
    return getAllDayRows(
      d,
      type: Hc20HistoryType.sleep,
      yy: yy,
      mm: mm,
      dd: dd,
      packetIndex: packetIndex,
      includeSummary: includeSummary,
    );
  }

  Future<List<Hc20AllDayRow>> getAllDayCaloriesRows(
    Hc20Device d, {
    required int yy,
    required int mm,
    required int dd,
    int? packetIndex,
  }) {
    return getAllDayRows(
      d,
      type: Hc20HistoryType.calories5m,
      yy: yy,
      mm: mm,
      dd: dd,
      packetIndex: packetIndex,
    );
  }

  Future<List<Hc20AllDayRow>> getAllDayHrv2Rows(
    Hc20Device d, {
    required int yy,
    required int mm,
    required int dd,
    int? packetIndex,
  }) async {
    // Sensor disable/enable is handled by the mutex system in getAllDayRows
    // No need to track or restore sensors here
    
    try {
      final rows = await getAllDayRows(
        d,
        type: Hc20HistoryType.hrv2_5m,
        yy: yy,
        mm: mm,
        dd: dd,
        packetIndex: packetIndex,
        restoreSensorsAfterDecode: false, // Don't restore yet - wait for upload
      );
      
      // Upload HRV2 data to cloud after parsing
      if (rows.isNotEmpty) {
        try {
          final deviceInfo = await readDeviceInfo(d);
          // Convert Hc20AllDayRow to Map format expected by uploader
          final hrv2Entries = rows.map((row) => <String, dynamic>{
            'dateTime': row.dateTime,
            'values': row.values,
            'valid': row.valid,
          }).toList();
          
          Hc20CloudConfig.debugPrint('[HC20Client] Triggering HRV2 upload for ${rows.length} row(s)');
          await _raw.uploadAllDayHrv2(hrv2Entries, deviceInfo.mac);
        } catch (e, stackTrace) {
          // Log error but don't fail the method - return rows even if upload fails
          Hc20CloudConfig.debugPrint('[HC20Client] Error uploading HRV2 data: $e');
          Hc20CloudConfig.debugPrint('[HC20Client] Stack trace: $stackTrace');
        }
      }
      
      // Sensor restoration is handled by the mutex system when all operations complete
      // No need to restore sensors here
      return rows;
    } catch (e, stackTrace) {
      // Sensor restoration is handled by the mutex system when all operations complete
      // No need to restore sensors here even on error
      Hc20CloudConfig.debugPrint('[HC20Client] Error in getAllDayHrv2Rows: $e');
      Hc20CloudConfig.debugPrint('[HC20Client] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Hc20AllDayRow>> getAllDayRows(
    Hc20Device d, {
    required Hc20HistoryType type,
    required int yy,
    required int mm,
    required int dd,
    int? packetIndex,
    bool includeSummary = false,
    bool restoreSensorsAfterDecode = true,
  }) async {
    if (!type.isAllDayMetric) {
      throw ArgumentError('History type $type is not an all-day metric');
    }

    // Acquire mutex to serialize historical data retrieval operations
    // This prevents concurrent calls from interfering with each other and causing incomplete Bluetooth packets
    // Sensor disable/enable is handled by the mutex system
    await _acquireHistoryMutex(device: d);
    
    try {
      return await _getAllDayRowsImpl(
        d,
        type: type,
        yy: yy,
        mm: mm,
        dd: dd,
        packetIndex: packetIndex,
        includeSummary: includeSummary,
        restoreSensorsAfterDecode: restoreSensorsAfterDecode,
      );
    } finally {
      // Always release mutex, even if operation fails
      // Sensor restoration happens in _releaseHistoryMutex when queue is empty
      _releaseHistoryMutex();
    }
  }

  Future<List<Hc20AllDayRow>> _getAllDayRowsImpl(
    Hc20Device d, {
    required Hc20HistoryType type,
    required int yy,
    required int mm,
    required int dd,
    int? packetIndex,
    bool includeSummary = false,
    bool restoreSensorsAfterDecode = true,
  }) async {
    final typeId = type.typeId;

    // Sensor disable/enable is handled by the mutex system in getAllDayRows
    // No need to disable/enable sensors here

    try {
      if (packetIndex != null) {
        final msg = await _readHistoryMessage(
          d,
          dataType: typeId,
          yy: yy,
          mm: mm,
          dd: dd,
          index: packetIndex,
        );
        Hc20CloudConfig.debugPrint('HC20 DEBUG: Packet response type=0x${typeId.toRadixString(16)} reqDate=$yy-$mm-$dd respDate=${msg.yy}-${msg.mm}-${msg.dd} packetIdx=${msg.index} totalPackets=${msg.total}');
        // Use response date from device (device knows what date the data belongs to)
        final result = _decodeAllDayRows(
          typeId: typeId,
          yy: msg.yy,
          mm: msg.mm,
          dd: msg.dd,
          packetIndex: msg.index,
          totalPackets: msg.total,
          data: msg.data,
        );
        // Sensor restoration is handled by the mutex system when all operations complete
        // No need to restore sensors here
        return result;
      }

      if (type == Hc20HistoryType.allDaySummary) {
        final msg = await _readHistoryMessage(
          d,
          dataType: typeId,
          yy: yy,
          mm: mm,
          dd: dd,
          index: 0,
        );
        Hc20CloudConfig.debugPrint('HC20 DEBUG: Summary response type=0x${typeId.toRadixString(16)} reqDate=$yy-$mm-$dd respDate=${msg.yy}-${msg.mm}-${msg.dd} packetIdx=${msg.index}');
        // Print raw bytes
        final bytes = msg.data;
        final hexString = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        print('HC20 DEBUG: getAllDaySummaryRows raw bytes (length=${bytes.length}):');
        print('  Hex: $hexString');
        print('  Decimal: ${bytes.join(' ')}');
        // Use response date from device
        final result = _decodeAllDayRows(
          typeId: typeId,
          yy: msg.yy,
          mm: msg.mm,
          dd: msg.dd,
          packetIndex: msg.index,
          totalPackets: msg.total,
          data: msg.data,
        );
        // Sensor restoration is handled by the mutex system when all operations complete
        // No need to restore sensors here
        return result;
      }

      final rows = <Hc20AllDayRow>[];

      if (type == Hc20HistoryType.sleep && includeSummary) {
        try {
          final summary = await _readHistoryMessage(
            d,
            dataType: typeId,
            yy: yy,
            mm: mm,
            dd: dd,
            index: 0,
          );
          Hc20CloudConfig.debugPrint('HC20 DEBUG: Sleep summary reqDate=$yy-$mm-$dd respDate=${summary.yy}-${summary.mm}-${summary.dd}');
          // Use response date from device
          rows.addAll(_decodeAllDayRows(
            typeId: typeId,
            yy: summary.yy,
            mm: summary.mm,
            dd: summary.dd,
            packetIndex: summary.index,
            totalPackets: summary.total,
            data: summary.data,
          ));
        } catch (_) {
          // ignore summary fetch issues; device may not have data
        }
      }

      final packets = await _readAllHistoryPackets(
        d,
        dataType: typeId,
        yy: yy,
        mm: mm,
        dd: dd,
      );

      // RRI (0x04), Temperature (0x05), Baro (0x06), HRV (0x08), HRV2 (0x0C): 
      // packet index IS the time slot from midnight, use raw indices (not normalized)

      for (final packet in packets) {
        Hc20CloudConfig.debugPrint('HC20 DEBUG: Processing packet type=0x${typeId.toRadixString(16)} reqDate=$yy-$mm-$dd respDate=${packet.yy}-${packet.mm}-${packet.dd} packetIdx=${packet.index} dataLen=${packet.data.length}');
        // Use response date from device (device knows what date the data belongs to)
        rows.addAll(_decodeAllDayRows(
          typeId: typeId,
          yy: packet.yy,
          mm: packet.mm,
          dd: packet.dd,
          packetIndex: packet.index,
          minPacketIndex: null, // Not needed - these types use raw packet indices
          totalPackets: 0, // not available in _HistoryPacket, but not critical
          data: packet.data,
        ));
      }

      rows.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      
      // Sensor restoration is handled by the mutex system when all operations complete
      // No need to restore sensors here
      return rows;
    } catch (e) {
      // Sensor restoration is handled by the mutex system when all operations complete
      // No need to restore sensors here even on error
      rethrow;
    }
  }

  List<Hc20AllDayRow> _decodeAllDayRows({
    required int typeId,
    required int yy,
    required int mm,
    required int dd,
    required int packetIndex,
    required Uint8List data,
    int? minPacketIndex,
    int totalPackets = 0,
  }) {
    final rows = <Hc20AllDayRow>[];
    if (data.isEmpty) return rows;

    final int year = 2000 + yy;
    final DateTime baseDate = DateTime(year, mm, dd);
    final int effectivePacketIndex = packetIndex <= 0 ? 1 : packetIndex;
    // Calculate day-relative packet index: only for problematic data types that use global indices
    // Other types (Steps, Heart, Calories, SpO2) already use day-relative indices
    final int dayRelativePacketIndex;
    if (minPacketIndex != null && minPacketIndex > 0) {
      dayRelativePacketIndex = effectivePacketIndex - minPacketIndex + 1;
    } else {
      dayRelativePacketIndex = effectivePacketIndex;
    }
    
    Hc20CloudConfig.debugPrint('HC20 DEBUG: _decodeAllDayRows type=0x${typeId.toRadixString(16)} date=$yy-$mm-$dd year=$year packetIdx=$packetIndex minPacketIdx=$minPacketIndex dayRelativeIdx=$dayRelativePacketIndex totalPackets=$totalPackets dataLen=${data.length}');

    switch (typeId) {
      case 0x00:
        // Find null terminator and slice data up to it (excluding the null byte)
        // If null is at position 0, skip it; if not found (end == -1), use all data
        final end = data.lastIndexOf(0x00);
        Uint8List slice;
        if (end == -1) {
          // No null terminator found, use all data
          slice = data;
        } else if (end == 0) {
          // Null byte at start, skip it
          slice = data.length > 1 ? data.sublist(1) : Uint8List(0);
        } else {
          // Null byte found, slice up to it (excluding the null)
          slice = data.sublist(0, end);
        }
        final values = <String, dynamic>{
          'stepsTotal': null,
          'caloriesTotalKcal': null,
          'distanceTotalM': null,
          'activeTimeSec': null,
          'silentTimeSec': null,
          'activeCaloriesKcal': null,
          'silentCaloriesKcal': null,
        };
        bool valid = false;
        if (slice.isNotEmpty) {
          try {
            final m = json.decode(utf8.decode(slice)) as Map<String, dynamic>;
            void assign(String key, List<String> candidates) {
              final v = _numFromJson(m, candidates);
              if (v != null) {
                values[key] = v.toInt();
                valid = true;
              }
            }

            assign('stepsTotal', ['stepsTotal', 'steps_total', 'steps']);
            assign('caloriesTotalKcal',
                ['caloriesTotalKcal', 'calories_total_kcal', 'calories']);
            assign('distanceTotalM',
                ['distanceTotalM', 'distance_total_m', 'distance']);
            assign('activeTimeSec',
                ['activeTimeSec', 'active_time', 'active_time_sec']);
            assign('silentTimeSec',
                ['silentTimeSec', 'silent_time', 'silent_time_sec']);
            assign('activeCaloriesKcal', [
              'activeCaloriesKcal',
              'active_calories',
              'active_calories_kcal'
            ]);
            assign('silentCaloriesKcal', [
              'silentCaloriesKcal',
              'silent_calories',
              'silent_calories_kcal'
            ]);
          } catch (_) {
            valid = false;
          }
        }

        rows.add(Hc20AllDayRow(
          dateTime: _isoString(DateTime(year, mm, dd)),
          values: values,
          valid: valid,
        ));
        return rows;

      case 0x01:
        // Heart rate (5s): packets cover 15 minutes each (180 samples * 5s = 900s = 15min)
        // Packet index represents 15-minute block within the day (1-indexed)
        final int baseSeconds = (effectivePacketIndex - 1) * 900; // 15 minutes = 900 seconds
        Hc20CloudConfig.debugPrint('HC20 DEBUG: Heart rate (5s) baseSeconds=$baseSeconds (packet=$effectivePacketIndex, 15min blocks) samples=${data.length}');
        for (int i = 0; i < data.length; i++) {
          final totalSeconds = baseSeconds + i * 5;
          final dt = baseDate.add(Duration(seconds: totalSeconds));
          if (i == 0 || i == data.length - 1 || i % 100 == 0) {
            Hc20CloudConfig.debugPrint('HC20 DEBUG: Heart rate sample[$i] totalSec=$totalSeconds dt=${_isoString(dt)}');
          }
          final value = data[i];
          final valid = value != 0xFF;
          rows.add(Hc20AllDayRow(
            dateTime: _isoString(dt),
            values: {'bpm': valid ? value : null},
            valid: valid,
          ));
        }
        return rows;

      case 0x02:
        final int baseMinutes = (effectivePacketIndex - 1) * 480;
        for (int offset = 0; offset + 1 < data.length; offset += 2) {
          final slot = offset ~/ 2;
          final totalMinutes = baseMinutes + slot * 5;
          final dt = baseDate.add(Duration(minutes: totalMinutes));
          final raw = _leUint16(data, offset);
          final valid = raw != 0xFFFF;
          rows.add(Hc20AllDayRow(
            dateTime: _isoString(dt),
            values: {'steps': valid ? raw : null},
            valid: valid,
          ));
        }
        return rows;

      case 0x03:
        // SpO2 (5m): packets cover 12 hours each (144 samples * 5min = 720min = 12h)
        // Packet index represents 12-hour block within the day (1-indexed)
        // packetIndex 1 = 00:00-11:55, packetIndex 2 = 12:00-23:55
        final int baseMinutes = (effectivePacketIndex - 1) * 720; // 12 hours = 720 minutes per packet
        for (int i = 0; i < data.length; i++) {
          final totalMinutes = baseMinutes + i * 5;
          final dt = baseDate.add(Duration(minutes: totalMinutes));
          final value = data[i];
          final valid = value != 0xFF;
          rows.add(Hc20AllDayRow(
            dateTime: _isoString(dt),
            values: {'spo2Pct': valid ? value : null},
            valid: valid,
          ));
        }
        return rows;

      case 0x04:
        // RRI (5s): packets cover 8 minutes each (96 samples * 5s = 480s = 8min)
        // Packet index directly represents the 8-minute slot from midnight (not normalized)
        // packetIndex 72 = 72 * 8min = 576min = 9h36m from midnight
        final int baseSeconds = (effectivePacketIndex - 1) * 480; // 8 minutes = 480 seconds
        final sampleCount = (data.length ~/ 2);
        Hc20CloudConfig.debugPrint('HC20 DEBUG: RRI (5s) baseSeconds=$baseSeconds (packet=$effectivePacketIndex, 8min slots from midnight) samples=$sampleCount');
        for (int offset = 0; offset + 1 < data.length; offset += 2) {
          final slot = offset ~/ 2;
          final totalSeconds = baseSeconds + slot * 5;
          final dt = baseDate.add(Duration(seconds: totalSeconds));
          if (slot == 0 || slot == sampleCount - 1 || slot % 100 == 0) {
            Hc20CloudConfig.debugPrint('HC20 DEBUG: RRI sample[$slot] totalSec=$totalSeconds dt=${_isoString(dt)}');
          }
          final raw = _leUint16(data, offset);
          final valid = raw != 0xFFFF;
          rows.add(Hc20AllDayRow(
            dateTime: _isoString(dt),
            values: {'rriMs': valid ? raw : null},
            valid: valid,
          ));
        }
        return rows;

      case 0x05:
        // Temperature (1m): packets cover 48 minutes each (48 samples * 1min = 48min)
        // Packet index directly represents the 48-minute slot from midnight (not normalized)
        // packetIndex 13 = (13-1) * 48min = 576min = 9h36m from midnight
        final int baseMinutes = (effectivePacketIndex - 1) * 48; // 48 minutes per packet
        final sampleCount = (data.length ~/ 4);
        Hc20CloudConfig.debugPrint('HC20 DEBUG: Temperature (1m) baseMinutes=$baseMinutes (packet=$effectivePacketIndex, 48min slots from midnight) samples=$sampleCount');
        for (int offset = 0; offset + 3 < data.length; offset += 4) {
          final slot = offset ~/ 4;
          final totalMinutes = baseMinutes + slot;
          final dt = baseDate.add(Duration(minutes: totalMinutes));
          if (slot == 0 || slot == sampleCount - 1 || slot % 100 == 0) {
            Hc20CloudConfig.debugPrint('HC20 DEBUG: Temperature sample[$slot] totalMin=$totalMinutes dt=${_isoString(dt)}');
          }
          final allInvalid = _allBytesAreFF(data, offset, 4);
          double? skinC;
          double? envC;
          if (!allInvalid) {
            final surfaceInvalid =
                data[offset] == 0xFF && data[offset + 1] == 0xFF;
            final ambientInvalid =
                data[offset + 2] == 0xFF && data[offset + 3] == 0xFF;
            if (!surfaceInvalid) skinC = _leInt16(data, offset) / 100.0;
            if (!ambientInvalid) envC = _leInt16(data, offset + 2) / 100.0;
          }
          final valid = !allInvalid;
          rows.add(Hc20AllDayRow(
            dateTime: _isoString(dt),
            values: {
              'skinC': valid ? skinC : null,
              'envC': valid ? envC : null,
            },
            valid: valid,
          ));
        }
        return rows;

      case 0x06:
        // Barometric Pressure (1m): packets cover 48 minutes each (48 samples * 1min = 48min)
        // Packet index directly represents the 48-minute slot from midnight (not normalized)
        final int baseMinutes = (effectivePacketIndex - 1) * 48; // 48 minutes per packet
        final sampleCount = (data.length ~/ 4);
        Hc20CloudConfig.debugPrint('HC20 DEBUG: Pressure (1m) baseMinutes=$baseMinutes (packet=$effectivePacketIndex, 48min slots from midnight) samples=$sampleCount');
        for (int offset = 0; offset + 3 < data.length; offset += 4) {
          final slot = offset ~/ 4;
          final totalMinutes = baseMinutes + slot;
          final dt = baseDate.add(Duration(minutes: totalMinutes));
          if (slot == 0 || slot == sampleCount - 1 || slot % 100 == 0) {
            Hc20CloudConfig.debugPrint('HC20 DEBUG: Pressure sample[$slot] totalMin=$totalMinutes dt=${_isoString(dt)}');
          }
          final allInvalid = _allBytesAreFF(data, offset, 4);
          final value = _leUint32(data, offset);
          final valid = !allInvalid;
          rows.add(Hc20AllDayRow(
            dateTime: _isoString(dt),
            values: {'pressurePa': valid ? value : null},
            valid: valid,
          ));
        }
        return rows;

      case 0x07:
        final int baseMinutes = (effectivePacketIndex - 1) * 480;
        for (int offset = 0; offset + 1 < data.length; offset += 2) {
          final slot = offset ~/ 2;
          final totalMinutes = baseMinutes + slot * 5;
          final dt = baseDate.add(Duration(minutes: totalMinutes));
          final sys = data[offset];
          final dia = data[offset + 1];
          final valid = !(sys == 0xFF && dia == 0xFF);
          rows.add(Hc20AllDayRow(
            dateTime: _isoString(dt),
            values: {
              'sys': valid ? sys : null,
              'dia': valid ? dia : null,
            },
            valid: valid,
          ));
        }
        return rows;

      case 0x08:
        // HRV (5m): packets cover 45 minutes each (9 samples * 5min = 45min)
        // Packet index directly represents the 45-minute slot from midnight (not normalized)
        // packetIndex 13 = (13-1) * 45min = 540min = 9h from midnight
        final int baseMinutes = (effectivePacketIndex - 1) * 45; // 45 minutes per packet
        for (int offset = 0; offset + 19 < data.length; offset += 20) {
          final slot = offset ~/ 20;
          final totalMinutes = baseMinutes + slot * 5;
          final dt = baseDate.add(Duration(minutes: totalMinutes));
          final allInvalid = _allBytesAreFF(data, offset, 20);
          double? sdnn;
          double? tp;
          double? lf;
          double? hf;
          double? vlf;
          if (!allInvalid) {
            sdnn = _leUint32(data, offset) / 1000.0;
            tp = _leUint32(data, offset + 4) / 1000.0;
            lf = _leUint32(data, offset + 8) / 1000.0;
            hf = _leUint32(data, offset + 12) / 1000.0;
            vlf = _leUint32(data, offset + 16) / 1000.0;
          }
          final valid = !allInvalid;
          rows.add(Hc20AllDayRow(
            dateTime: _isoString(dt),
            values: {
              'sdnn': valid ? sdnn : null,
              'tp': valid ? tp : null,
              'lf': valid ? lf : null,
              'hf': valid ? hf : null,
              'vlf': valid ? vlf : null,
            },
            valid: valid,
          ));
        }
        return rows;

      case 0x09:
        final int baseMinutes = (effectivePacketIndex - 1) * 480;
        final sampleCount = (data.length ~/ 12);
        Hc20CloudConfig.debugPrint('HC20 DEBUG: GNSS (1m) baseMinutes=$baseMinutes samples=$sampleCount');
        for (int offset = 0; offset + 11 < data.length; offset += 12) {
          final slot = offset ~/ 12;
          final totalMinutes = baseMinutes + slot;
          final dt = baseDate.add(Duration(minutes: totalMinutes));
          if (slot == 0 || slot == sampleCount - 1 || slot % 100 == 0) {
            Hc20CloudConfig.debugPrint('HC20 DEBUG: GNSS sample[$slot] totalMin=$totalMinutes dt=${_isoString(dt)}');
          }
          final allInvalid = _allBytesAreFF(data, offset, 12);
          double? lat;
          double? lon;
          int? signal;
          if (!allInvalid) {
            lon = _leInt32(data, offset) / 1e6;
            lat = _leInt32(data, offset + 4) / 1e6;
            signal = data[offset + 8];
          }
          final valid = !allInvalid;
          rows.add(Hc20AllDayRow(
            dateTime: _isoString(dt),
            values: {
              'lat': valid ? lat : null,
              'lon': valid ? lon : null,
              'signal': valid ? signal : null,
            },
            valid: valid,
          ));
        }
        return rows;

      case 0x0A:
        if (packetIndex == 0) {
          final end = data.lastIndexOf(0x00);
          final slice = end > 0 ? data.sublist(0, end) : data;
          final values = <String, dynamic>{
            'soberMin': null,
            'lightMin': null,
            'deepMin': null,
            'remMin': null,
            'napMin': null,
          };
          bool valid = false;
          if (slice.isNotEmpty) {
            try {
              final m = json.decode(utf8.decode(slice)) as Map<String, dynamic>;
              void assign(String key, List<String> candidates) {
                final v = _numFromJson(m, candidates);
                if (v != null) {
                  values[key] = v.toInt();
                  valid = true;
                }
              }

              assign('soberMin', ['soberMin', 'sober_time']);
              assign('lightMin', ['lightMin', 'light_time']);
              assign('deepMin', ['deepMin', 'deep_time']);
              assign('remMin', ['remMin', 'rem_time']);
              assign('napMin', ['napMin', 'nap_time']);
            } catch (_) {
              valid = false;
            }
          }
          rows.add(Hc20AllDayRow(
            dateTime: _isoString(DateTime(year, mm, dd)),
            values: values,
            valid: valid,
          ));
          return rows;
        }

        const states = ['awake', 'light', 'deep', 'rem'];
        for (int offset = 0; offset + 3 < data.length; offset += 4) {
          if (_allBytesAreFF(data, offset, 4)) continue;
          final stateIdx = data[offset];
          final dayByte = data[offset + 1];
          final hour = data[offset + 2];
          final minute = data[offset + 3];
          final day = dayByte == 0 ? dd : dayByte;
          DateTime dt;
          try {
            dt = DateTime(year, mm, day, hour, minute);
          } catch (_) {
            final deltaDays = day - dd;
            dt = baseDate
                .add(Duration(days: deltaDays, hours: hour, minutes: minute));
          }
          final state = stateIdx < states.length ? states[stateIdx] : 'unknown';
          rows.add(Hc20AllDayRow(
            dateTime: _isoString(dt),
            values: {'sleepState': state},
            valid: true,
          ));
        }
        return rows;

      case 0x0B:
        final int baseMinutes = (effectivePacketIndex - 1) * 480;
        for (int offset = 0; offset + 1 < data.length; offset += 2) {
          final slot = offset ~/ 2;
          final totalMinutes = baseMinutes + slot * 5;
          final dt = baseDate.add(Duration(minutes: totalMinutes));
          final raw = _leUint16(data, offset);
          final valid = raw != 0xFFFF;
          rows.add(Hc20AllDayRow(
            dateTime: _isoString(dt),
            values: {'kcal': valid ? raw : null},
            valid: valid,
          ));
        }
        return rows;

      case 0x0C:
        // HRV2 (5m): packets cover 120 minutes each (24 samples * 5min = 120min = 2h)
        // Packet index directly represents the 120-minute slot from midnight (not normalized)
        // packetIndex 5 = (5-1) * 120min = 480min = 8h from midnight
        final int baseMinutes = (effectivePacketIndex - 1) * 120; // 120 minutes (2 hours) per packet
        final sampleCount = (data.length ~/ 8);
        Hc20CloudConfig.debugPrint('HC20 DEBUG: HRV2 (5m) date=$yy-$mm-$dd baseMinutes=$baseMinutes (packet=$effectivePacketIndex, 120min slots from midnight) samples=$sampleCount');
        for (int offset = 0; offset + 7 < data.length; offset += 8) {
          final slot = offset ~/ 8;
          final totalMinutes = baseMinutes + slot * 5;
          final dt = baseDate.add(Duration(minutes: totalMinutes));
          if (slot == 0 || slot == sampleCount - 1 || slot % 50 == 0) {
            Hc20CloudConfig.debugPrint('HC20 DEBUG: HRV2 sample[$slot] totalMin=$totalMinutes dt=${_isoString(dt)}');
          }
          final allInvalid = _allBytesAreFF(data, offset, 8);
          final ms = data[offset];
          final fl = data[offset + 1];
          final sr = data[offset + 2];
          final ra = data[offset + 3];
          final valid = !allInvalid;
          rows.add(Hc20AllDayRow(
            dateTime: _isoString(dt),
            values: {
              'mentalStress': valid ? ms : null,
              'fatigue': valid ? fl : null,
              'stressResistance': valid ? sr : null,
              'regulationAbility': valid ? ra : null,
            },
            valid: valid,
          ));
        }
        return rows;

      default:
        return rows;
    }
  }

  Future<Hc20SleepSummary> getAllDaySleepSummary(Hc20Device d,
      {required int yy, required int mm, required int dd}) async {
    final data = await readHistoryPacket(d,
        dataType: 0x0A, yy: yy, mm: mm, dd: dd, index: 0);
    if (data.isEmpty) {
      return Hc20SleepSummary(0, 0, 0, 0, 0);
    }
    final end = data.lastIndexOf(0x00);
    final slice = end > 0 ? data.sublist(0, end) : data;
    if (slice.isEmpty) {
      return Hc20SleepSummary(0, 0, 0, 0, 0);
    }
    final j = json.decode(utf8.decode(slice)) as Map<String, dynamic>;
    return Hc20SleepSummary(j['sober_time'] ?? 0, j['light_time'] ?? 0,
        j['deep_time'] ?? 0, j['rem_time'] ?? 0, j['nap_time'] ?? 0);
  }

  Future<String> readHistoryJson(Hc20Device d,
      {required int dataType,
      required int yy,
      required int mm,
      required int dd,
      required int index}) async {
    final p = await readHistoryPacket(d,
        dataType: dataType, yy: yy, mm: mm, dd: dd, index: index);
    if (p.isEmpty) return '';
    final end = p.lastIndexOf(0x00);
    final slice = end > 0 ? p.sublist(0, end) : p;
    if (slice.isEmpty) return '';
    return utf8.decode(slice);
  }

  Future<String> readPacketStatus(Hc20Device d,
      {required int dataType,
      required int yy,
      required int mm,
      required int dd}) async {
    // Acquire mutex to serialize historical data retrieval operations
    // Sensor disable/enable is handled by the mutex system
    await _acquireHistoryMutex(device: d);
    
    try {
      // Use history message parser; data begins with: 0xFD, type, yy, mm, dd, then statuses
      final msg = await _readHistoryMessage(d,
          dataType: 0xFD,
          yy: yy,
          mm: mm,
          dd: dd,
          index: 0,
          requestedType: dataType);
      final rd = msg.data;
      // statuses start after 5 bytes (fd + type + 3B date)
      if (rd.length <= 5) return '';
      return base64.encode(rd.sublist(5));
    } finally {
      // Always release mutex, even if operation fails
      // Sensor restoration happens in _releaseHistoryMutex when queue is empty
      _releaseHistoryMutex();
    }
  }

  Future<String> readStorageInfo(Hc20Device d) async {
    // Acquire mutex to serialize historical data retrieval operations
    // Sensor disable/enable is handled by the mutex system
    await _acquireHistoryMutex(device: d);
    
    try {
      final msg = await _readHistoryMessage(d,
          dataType: 0xFE, yy: 0, mm: 0, dd: 0, index: 0);
      final rd = msg.data; // starts with 0xFE then JSON + 0x00
      if (rd.isEmpty) return '';
      final start = 1;
      final end = rd.lastIndexOf(0x00);
      final slice = end > start ? rd.sublist(start, end) : rd.sublist(start);
      return utf8.decode(slice);
    } finally {
      // Always release mutex, even if operation fails
      // Sensor restoration happens in _releaseHistoryMutex when queue is empty
      _releaseHistoryMutex();
    }
  }

  Future<List<int>> readPacketStatuses(Hc20Device d,
      {required int dataType,
      required int yy,
      required int mm,
      required int dd}) async {
    // Acquire mutex to serialize historical data retrieval operations
    // Note: This is also called from _readAllHistoryPackets which already has mutex,
    // but we add it here in case this method is called directly
    // Sensor disable/enable is handled by the mutex system
    await _acquireHistoryMutex(device: d);
    
    try {
      final msg = await _readHistoryMessage(d,
          dataType: 0xFD,
          yy: yy,
          mm: mm,
          dd: dd,
          index: 0,
          requestedType: dataType);
      final rd = msg.data;
      if (rd.length <= 5) return const [];
      return rd.sublist(5); // one byte per packet index (1-based)
    } finally {
      // Always release mutex, even if operation fails
      _releaseHistoryMutex();
    }
  }

  Future<List<_HistoryPacket>> _readAllHistoryPackets(Hc20Device d,
      {required int dataType,
      required int yy,
      required int mm,
      required int dd}) async {
    final packets = <_HistoryPacket>[];
    try {
      final statuses = await readPacketStatuses(d,
          dataType: dataType, yy: yy, mm: mm, dd: dd);
      Hc20CloudConfig.debugPrint('HC20 DEBUG: _readAllHistoryPackets type=0x${dataType.toRadixString(16)} statusesLen=${statuses.length}');
      if (statuses.isNotEmpty) {
        int fetchedCount = 0;
        int skippedCount = 0;
        for (int i = 0; i < statuses.length; i++) {
          final st = statuses[i];
          final idx = i + 1;
          if (st == 0) {
            skippedCount++;
            if (i < 10 || i % 20 == 0) {
              Hc20CloudConfig.debugPrint('HC20 DEBUG: Skipping packet index $idx (status=0)');
            }
            continue;
          }
          try {
            Hc20CloudConfig.debugPrint('HC20 DEBUG: Fetching packet index $idx (status=$st, byte[$i]=$st)');
            final msg = await _readHistoryMessage(d,
                dataType: dataType, yy: yy, mm: mm, dd: dd, index: idx);
            packets.add(_HistoryPacket(msg.index, msg.yy, msg.mm, msg.dd, msg.data));
            fetchedCount++;
            if (fetchedCount <= 5 || fetchedCount % 10 == 0) {
              Hc20CloudConfig.debugPrint('HC20 DEBUG: Fetched packet $fetchedCount: index=${msg.index} date=${msg.yy}-${msg.mm}-${msg.dd} dataLen=${msg.data.length}');
            }
          } catch (e) {
            Hc20CloudConfig.debugPrint('HC20 DEBUG: Error fetching packet index $idx: $e');
            // Continue to next packet even if one fails
          }
        }
        Hc20CloudConfig.debugPrint('HC20 DEBUG: _readAllHistoryPackets complete: fetched=$fetchedCount skipped=$skippedCount total=${packets.length}');
        packets.sort((a, b) => a.index.compareTo(b.index));
        return packets;
      }
    } catch (e) {
      Hc20CloudConfig.debugPrint('HC20 DEBUG: Packet status method failed: $e, falling back to direct fetch');
      // fall back below if packet status unsupported
    }

    try {
      Hc20CloudConfig.debugPrint('HC20 DEBUG: Fallback: fetching packet 1 to get total...');
      final first = await _readHistoryMessage(d,
          dataType: dataType, yy: yy, mm: mm, dd: dd, index: 1);
      final total = first.total;
      Hc20CloudConfig.debugPrint('HC20 DEBUG: Fallback: total packets=$total');
      packets.add(_HistoryPacket(first.index, first.yy, first.mm, first.dd, first.data));
      for (int idx = 2; idx <= total; idx++) {
        try {
          final msg = await _readHistoryMessage(d,
              dataType: dataType, yy: yy, mm: mm, dd: dd, index: idx);
          packets.add(_HistoryPacket(msg.index, msg.yy, msg.mm, msg.dd, msg.data));
          if (idx <= 5 || idx % 10 == 0) {
            Hc20CloudConfig.debugPrint('HC20 DEBUG: Fallback fetched packet $idx: index=${msg.index}');
          }
        } catch (e) {
          Hc20CloudConfig.debugPrint('HC20 DEBUG: Error in fallback fetching packet $idx: $e');
          // Continue even if one packet fails
        }
      }
      packets.sort((a, b) => a.index.compareTo(b.index));
      Hc20CloudConfig.debugPrint('HC20 DEBUG: Fallback complete: fetched ${packets.length} packets');
      return packets;
    } catch (e) {
      Hc20CloudConfig.debugPrint('HC20 DEBUG: Fallback method also failed: $e');
      return const <_HistoryPacket>[];
    }
  }


  Future<void> disconnect(Hc20Device d, {bool forgetDevice = false}) async {
    // Emit disconnected state before clearing device info
    if (_connectedDevice != null) {
      _connectionStateController.add(Hc20ConnectionStateUpdate(
        device: _connectedDevice!,
        state: Hc20ConnectionState.disconnected,
      ));
    }
    
    // Clear last connected device if explicitly requested (manual disconnect)
    if (forgetDevice) {
      await _connectionManager.clearLastConnectedDevice();
      // Disable auto-reconnect when user manually disconnects
      _ble.disableAutoReconnect(d.id);
      Hc20CloudConfig.debugPrint('[HC20Client] Device forgotten, auto-reconnect disabled');
    }
    // Otherwise, keep last device stored for auto-reconnect (automatic disconnection)
    
    _connectedDevice = null;
    _deviceMacAddress = null;
    _sensorsEnabled = false;
    _isReconnectionAttempt = false;
    _reconnectedStateEmitted = false;
    await _tx.dispose();
    // Keep auto-reconnect enabled only if not manually disconnected
    await _ble.disconnect(d.id, keepAutoReconnect: !forgetDevice);
    await _raw.stop();
  }
  
  /// Forget the last connected device (prevents auto-reconnect)
  Future<void> forgetLastDevice() async {
    await _connectionManager.clearLastConnectedDevice();
    Hc20CloudConfig.debugPrint('[HC20Client] Last device forgotten, auto-reconnect disabled');
  }
  
  /// Dispose resources and close streams
  Future<void> dispose() async {
    await _connectionStateController.close();
    await _tx.dispose();
    _connectionManager.dispose();
  }

  Future<Hc20MsgHistory> _readHistoryMessage(Hc20Device d,
      {required int dataType,
      required int yy,
      required int mm,
      required int dd,
      required int index,
      int? requestedType}) async {
    final completer = Completer<Hc20MsgHistory>();
    late StreamSubscription sub;
    
    // ✅ FIXED: Filter notifications to only listen for history responses (0x97) and exceptions
    // This prevents 0xB0 sensor streaming notifications from being incorrectly parsed as errors
    // History request (0x17) expects response (0x97), exceptions have 0x40 bit set
    sub = _tx
        .notifications(d.id)
        .where((f) => f.func == 0x97 || (f.func & 0x40) != 0)  // Only history responses (0x97) or exceptions
        .map((f) => Hc20ResponseParser.parse(f))  // Parse only relevant frames
        .listen((m) {
      // Check if it's an exception message
      if (m is Hc20MsgException) {
        sub.cancel();
        // Convert exception to Hc20Exception and throw it
        final exception = Hc20Exception(m.code, m.msg);
        if (!completer.isCompleted) {
          completer.completeError(exception);
        }
        return;
      }
      
      // Check if it's the expected history message
      if (m is Hc20MsgHistory) {
        final msg = m;
        // For 0xFD and 0xFE, we don't check date/index matching
        if (dataType == 0xFD || dataType == 0xFE) {
          if (msg.type == dataType) {
            sub.cancel();
            completer.complete(msg);
            return;
          }
        } else {
          // For regular data types, check type and index match
          // Note: Device may return a different date than requested (e.g., if data spans days)
          // We accept the response if type and index match - the device knows the correct date
          // The SDK will use the device's returned date when decoding the data
          if (msg.type == dataType && msg.index == index) {
            // Accept response if type and index match, regardless of date
            // The device may return data for a slightly different date (e.g., if packet spans midnight)
            sub.cancel();
            completer.complete(msg);
            return;
          }
        }
      }
    }, onError: (e) {
      if (!completer.isCompleted) completer.completeError(e);
    });
    
    List<int> payload;
    if (dataType == 0xFD) {
      final t = requestedType ?? 0;
      payload = <int>[0xFD, t, yy, mm, dd];
    } else if (dataType == 0xFE) {
      payload = const <int>[0xFE];
    } else {
      payload = <int>[dataType, yy, mm, dd, index & 0xFF, (index >> 8) & 0xFF];
    }
    () async {
      try {
        await _tx.request(d.id, 0x17, payload);
      } catch (_) {}
    }();
    
    // Add timeout to prevent waiting forever
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        sub.cancel();
        if (!completer.isCompleted) {
          completer.completeError(Hc20Exception(0xC0, 'History request timeout for type=0x${dataType.toRadixString(16)} date=$yy-$mm-$dd index=$index'));
        }
        throw Hc20Exception(0xC0, 'History request timeout');
      },
    );
  }

  String _payloadJsonString(List<int> payload, {required int leading}) {
    final i0 = leading;
    final end = payload.lastIndexOf(0x00);
    final slice = end > i0 ? payload.sublist(i0, end) : payload.sublist(i0);
    return utf8.decode(slice);
  }
}
