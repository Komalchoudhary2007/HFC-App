import 'package:flutter/services.dart';

/// Service to interact with the Native Kotlin HC20 Service
/// 
/// This service wraps the MethodChannel calls to control NativeHC20Service
/// which is a pure Kotlin implementation that:
/// - Scans and connects to HC20 via native BLE
/// - Parses HC20 protocol in Kotlin
/// - Sends webhooks directly from native code
/// - Works even when Flutter engine is dead (app swiped away)
/// 
/// Usage:
/// ```dart
/// // Start native HC20 service when app starts
/// await NativeHC20ServiceController.startService(
///   deviceId: 'AA:BB:CC:DD:EE:FF',
///   userPhone: '1234567890',
/// );
/// 
/// // Check if service is running
/// bool running = await NativeHC20ServiceController.isRunning();
/// 
/// // Stop when no longer needed
/// await NativeHC20ServiceController.stopService();
/// ```
class NativeHC20ServiceController {
  static const MethodChannel _channel = MethodChannel('com.hfc.app/background');
  
  /// Start the Native HC20 Service (Pure Kotlin BLE)
  /// 
  /// This starts a ForegroundService that:
  /// - Scans for HC20 devices using native Android BLE
  /// - Connects and parses HC20 protocol in Kotlin
  /// - Sends webhooks every 2 minutes
  /// - Survives app swipe-away
  /// 
  /// [deviceId] - The BLE MAC address of the HC20 device
  /// [userPhone] - The user's phone number for webhook identification
  static Future<bool> startService({
    required String deviceId,
    required String userPhone,
  }) async {
    try {
      print('🚀 [NativeHC20ServiceController] Starting Native HC20 Service');
      print('   Device: $deviceId');
      print('   Phone: $userPhone');
      
      final result = await _channel.invokeMethod('startNativeHC20Service', {
        'deviceId': deviceId,
        'userPhone': userPhone,
      });
      
      print('✅ [NativeHC20ServiceController] Service started: $result');
      return result == true;
    } catch (e) {
      print('❌ [NativeHC20ServiceController] Failed to start service: $e');
      return false;
    }
  }
  
  /// Stop the Native HC20 Service
  static Future<bool> stopService() async {
    try {
      print('🛑 [NativeHC20ServiceController] Stopping Native HC20 Service');
      
      final result = await _channel.invokeMethod('stopNativeHC20Service');
      
      print('✅ [NativeHC20ServiceController] Service stopped: $result');
      return result == true;
    } catch (e) {
      print('❌ [NativeHC20ServiceController] Failed to stop service: $e');
      return false;
    }
  }
  
  /// Check if the Native HC20 Service is running
  static Future<bool> isRunning() async {
    try {
      final result = await _channel.invokeMethod('isNativeHC20ServiceRunning');
      print('📋 [NativeHC20ServiceController] Service running: $result');
      return result == true;
    } catch (e) {
      print('❌ [NativeHC20ServiceController] Failed to check service: $e');
      return false;
    }
  }
}
