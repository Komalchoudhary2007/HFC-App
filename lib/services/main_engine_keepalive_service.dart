import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to keep the main Flutter engine running in the background
/// instead of using a separate HeadlessFlutter engine.
/// 
/// This approach is MORE RELIABLE because:
/// 1. HC20 SDK connection stays alive (no re-scanning/reconnecting)
/// 2. All BLE permissions already granted
/// 3. All state is preserved
/// 4. ForegroundService prevents Android from killing the app
/// 
/// When user swipes away:
/// - App moves to background (doesn't close)
/// - ForegroundService keeps CPU awake
/// - HC20 connection continues streaming data
/// - Webhooks keep sending
class MainEngineKeepAliveService {
  static const MethodChannel _channel = MethodChannel('com.hfc.app/main_engine_keepalive');
  
  static bool _isKeepAliveActive = false;
  static bool _isInBackground = false;
  
  /// Whether keep-alive mode is currently active
  static bool get isKeepAliveActive => _isKeepAliveActive;
  
  /// Whether the app is currently in the background
  static bool get isInBackground => _isInBackground;
  
  /// Initialize the keep-alive service
  static Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid) {
      print('⚠️ MainEngineKeepAlive: Only supported on Android');
      return;
    }
    
    try {
      // Set up handler for native -> Flutter messages
      _channel.setMethodCallHandler(_handleNativeCall);
      print('✅ MainEngineKeepAliveService initialized');
    } catch (e) {
      print('⚠️ MainEngineKeepAliveService init error: $e');
    }
  }
  
  /// Handle calls from native code
  static Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onKeepAliveStarted':
        _isKeepAliveActive = true;
        print('✅ [MainEngineKeepAlive] Keep-alive mode STARTED by native');
        return true;
        
      case 'onKeepAliveStopped':
        _isKeepAliveActive = false;
        print('✅ [MainEngineKeepAlive] Keep-alive mode STOPPED by native');
        return true;
        
      case 'onTaskRemoved':
        // App was swiped away from recents
        print('🔄 [MainEngineKeepAlive] App swiped away - keeping engine alive!');
        _isInBackground = true;
        return true;
        
      default:
        throw PlatformException(
          code: 'NOT_IMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
    }
  }
  
  /// Start keep-alive mode - call this when app goes to background
  /// and HC20 is connected
  static Future<bool> startKeepAlive({
    required String deviceId,
    String? userPhone,
    int? currentHeartRate,
    int? currentSpO2,
    double? currentTemperature,
    int? batteryLevel,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    
    if (_isKeepAliveActive) {
      print('ℹ️ [MainEngineKeepAlive] Already active');
      return true;
    }
    
    try {
      print('🚀 [MainEngineKeepAlive] Starting keep-alive for device: $deviceId');
      
      final result = await _channel.invokeMethod<bool>('startKeepAlive', {
        'deviceId': deviceId,
        'userPhone': userPhone ?? '',
        'heartRate': currentHeartRate ?? 0,
        'spo2': currentSpO2 ?? 0,
        'temperature': currentTemperature ?? 0.0,
        'batteryLevel': batteryLevel ?? 0,
      });
      
      _isKeepAliveActive = result ?? false;
      print('✅ [MainEngineKeepAlive] Started: $_isKeepAliveActive');
      return _isKeepAliveActive;
    } catch (e) {
      print('❌ [MainEngineKeepAlive] Start error: $e');
      return false;
    }
  }
  
  /// Stop keep-alive mode - call this when app comes to foreground
  static Future<bool> stopKeepAlive() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    
    if (!_isKeepAliveActive) {
      print('ℹ️ [MainEngineKeepAlive] Already stopped');
      return true;
    }
    
    try {
      print('🛑 [MainEngineKeepAlive] Stopping keep-alive mode');
      
      final result = await _channel.invokeMethod<bool>('stopKeepAlive');
      
      _isKeepAliveActive = !(result ?? true);
      _isInBackground = false;
      print('✅ [MainEngineKeepAlive] Stopped: ${!_isKeepAliveActive}');
      return !_isKeepAliveActive;
    } catch (e) {
      print('❌ [MainEngineKeepAlive] Stop error: $e');
      return false;
    }
  }
  
  /// Update the notification with current health data
  /// Call this periodically to keep notification fresh
  static Future<void> updateHealthData({
    int? heartRate,
    int? spo2,
    double? temperature,
    int? batteryLevel,
    int? steps,
    List<int>? bloodPressure,
  }) async {
    if (kIsWeb || !Platform.isAndroid || !_isKeepAliveActive) return;
    
    try {
      await _channel.invokeMethod('updateHealthData', {
        'heartRate': heartRate ?? 0,
        'spo2': spo2 ?? 0,
        'temperature': temperature ?? 0.0,
        'batteryLevel': batteryLevel ?? 0,
        'steps': steps ?? 0,
        'bpSystolic': bloodPressure?.isNotEmpty == true ? bloodPressure![0] : 0,
        'bpDiastolic': bloodPressure != null && bloodPressure.length == 2 ? bloodPressure[1] : 0,
      });
    } catch (e) {
      print('⚠️ [MainEngineKeepAlive] Update health data error: $e');
    }
  }
  
  /// Mark app as in background
  static void markInBackground() {
    _isInBackground = true;
    print('📱 [MainEngineKeepAlive] App marked as in background');
  }
  
  /// Mark app as in foreground
  static void markInForeground() {
    _isInBackground = false;
    print('📱 [MainEngineKeepAlive] App marked as in foreground');
  }
  
  /// Check if app should stay alive (connected to HC20)
  static Future<bool> shouldKeepAlive() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>('shouldKeepAlive');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
