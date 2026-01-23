import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hc20/hc20.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global HC20 connection service that persists across navigation
/// This ensures the device stays connected even when switching screens
class HC20Service extends ChangeNotifier {
  static final HC20Service _instance = HC20Service._internal();
  factory HC20Service() => _instance;
  HC20Service._internal();

  // HC20 client and device state
  Hc20Client? _client;
  Hc20Device? _connectedDevice;
  bool _isConnected = false;
  
  // Real-time data state
  int? _heartRate;
  int? _spo2;
  String? _bloodPressure;  // ✅ Changed from List<int>? to String? to match UI format "120/80"
  double? _temperature;
  int? _batteryLevel;
  int? _steps;
  DateTime? _lastDataReceived;
  
  // Subscriptions (kept alive across navigation)
  StreamSubscription? _realtimeSubscription;
  Timer? _dataRefreshTimer;
  Timer? _connectionMonitor;
  
  // Getters
  Hc20Client? get client => _client;
  Hc20Device? get connectedDevice => _connectedDevice;
  bool get isConnected => _isConnected;
  int? get heartRate => _heartRate;
  int? get spo2 => _spo2;
  String? get bloodPressure => _bloodPressure;  // ✅ Changed from List<int>? to String?
  double? get temperature => _temperature;
  int? get batteryLevel => _batteryLevel;
  int? get steps => _steps;
  DateTime? get lastDataReceived => _lastDataReceived;
  
  /// Initialize HC20 client
  Future<void> initializeClient() async {
    if (_client != null) return; // Already initialized
    
    try {
      _client = await Hc20Client.create(
        config: Hc20Config(
          clientId: 'Ep8FyjJ1BrvFdW2DdYgQJhX8lM4Gy5j1',
          clientSecret: 'ac8c34f2c30466954c4da4c995885107fabc33d8',
        ),
      );
      print('✅ [HC20Service] Client initialized globally');
    } catch (e) {
      print('❌ [HC20Service] Client initialization failed: $e');
      rethrow;
    }
  }
  
  /// Connect to device (called from device management page)
  Future<void> connectToDevice(Hc20Device device) async {
    if (_client == null) {
      throw Exception('HC20 client not initialized');
    }
    
    try {
      print('🔌 [HC20Service] Connecting to ${device.name}...');
      
      await _client!.connect(device);
      _connectedDevice = device;
      _isConnected = true;
      
      // Save device for auto-reconnect
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_device_id', device.id);
      await prefs.setBool('device_connected', true);
      
      print('✅ [HC20Service] Connected to ${device.name}');
      notifyListeners();
      
      // Start real-time data stream
      _startRealtimeStream();
      
    } catch (e) {
      print('❌ [HC20Service] Connection failed: $e');
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }
  
  /// Disconnect device
  Future<void> disconnect() async {
    print('🔌 [HC20Service] Disconnecting...');
    
    _realtimeSubscription?.cancel();
    _dataRefreshTimer?.cancel();
    _connectionMonitor?.cancel();
    
    _isConnected = false;
    _connectedDevice = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('device_connected', false);
    
    notifyListeners();
    print('✅ [HC20Service] Disconnected');
  }
  
  /// Start real-time data stream (internal)
  void _startRealtimeStream() {
    if (_client == null || _connectedDevice == null) return;
    
    print('🚀 [HC20Service] Starting real-time data stream (persistent)...');
    
    // Cancel existing subscription
    _realtimeSubscription?.cancel();
    
    // Subscribe to real-time data
    _realtimeSubscription = _client!.realtimeV2(_connectedDevice!).listen(
      (data) {
        // Update state - use correct property names from Hc20RealtimeV2
        _heartRate = data.heart;  // ✅ Correct property name
        _spo2 = data.spo2;
        // BP is List<int>? [systolic, diastolic]
        _bloodPressure = data.bp != null && data.bp!.length >= 2 
            ? '${data.bp![0]}/${data.bp![1]}' 
            : null;
        // Temperature is List<int>? [hand, env, body] (x100)
        _temperature = data.temperature != null && data.temperature!.length >= 3
            ? (data.temperature![2] / 100.0)  // body temp
            : null;
        // Battery is Hc20BatteryInfo? with .percent property
        _batteryLevel = data.battery?.percent;
        // Steps is in basicData List<int>? [steps, calories, distance]
        _steps = data.basicData != null && data.basicData!.isNotEmpty
            ? data.basicData![0]
            : null;
        _lastDataReceived = DateTime.now();
        
        // Notify listeners (updates UI across all screens)
        notifyListeners();
        
        print('📊 [HC20Service] Data: HR=$_heartRate SpO2=$_spo2 Temp=$_temperature Batt=$_batteryLevel');
      },
      onError: (error) {
        print('❌ [HC20Service] Stream error: $error');
      },
    );
    
    print('✅ [HC20Service] Real-time stream active - will persist across navigation');
  }
  
  /// Get connection status for CustomAppBar
  String getConnectionStatus() {
    if (!_isConnected || _connectedDevice == null) {
      return 'Disconnected';
    }
    
    // Check data freshness
    if (_lastDataReceived == null) {
      return 'Connected (No Data)';
    }
    
    final age = DateTime.now().difference(_lastDataReceived!).inSeconds;
    if (age > 300) {
      return 'Connected (Stale)';
    }
    
    return 'Connected';
  }
  
  /// Clean up (only when app is completely closed)
  @override
  void dispose() {
    print('🛑 [HC20Service] Disposing global service...');
    _realtimeSubscription?.cancel();
    _dataRefreshTimer?.cancel();
    _connectionMonitor?.cancel();
    super.dispose();
  }
}
