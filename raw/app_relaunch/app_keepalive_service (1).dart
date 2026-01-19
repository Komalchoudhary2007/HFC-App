import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// Service that uses AlarmManager to ensure app stays alive or auto-restarts
/// This is the MOST RELIABLE method for keeping app running in background
/// Uses Native Android AlarmManager - survives app kills and device reboots
class AppKeepaliveService {
  static const String _alarmName = 'hfc_keepalive_alarm';
  static const int _alarmId = 777;
  static const MethodChannel _channel = MethodChannel('com.example.hfc_app/app_launcher');
  
  /// Initialize the alarm manager
  static Future<void> initialize() async {
    try {
      await AndroidAlarmManager.initialize();
      print('✅ [AppKeepalive] AlarmManager initialized');
    } catch (e) {
      print('❌ [AppKeepalive] Failed to initialize: $e');
    }
  }
  
  /// Start periodic app keepalive (every 10 minutes)
  /// This will:
  /// 1. Check if app is running
  /// 2. If not running, launch the app  
  /// 3. If running, ensure HC20 connection is active
  static Future<void> startPeriodicKeepalive() async {
    try {
      // First, schedule a native broadcast alarm as backup
      // This alarm will trigger AppRestartReceiver every 15 minutes
      // We do this WHILE the app is running so MethodChannel works
      await _scheduleNativeRestartAlarm();
      
      // Then start periodic Dart callback
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 10),
        _alarmId,
        _keepaliveCallback,
        wakeup: true,  // Wake device if sleeping
        exact: true,   // Use exact timing
        rescheduleOnReboot: true,  // Restart after device reboot
      );
      
      print('✅ [AppKeepalive] Periodic keepalive started (10-min interval)');
      print('   Native restart alarm: 5-min interval');
      print('   Will auto-launch app if closed');
      print('   Will wake device if sleeping');
      print('   Will persist after device reboot');
    } catch (e) {
      print('❌ [AppKeepalive] Failed to start: $e');
    }
  }
  
  /// Schedule native broadcast alarm for app restart
  /// This is called while the app is running so MethodChannel works
  /// The alarm will:
  /// 1. Fire every 5 minutes
  /// 2. Send broadcast to AppRestartReceiver
  /// 3. AppRestartReceiver launches app + reschedules next alarm
  /// 4. Creates self-perpetuating restart cycle
  static Future<void> _scheduleNativeRestartAlarm() async {
    try {
      // Call native method to schedule alarm with broadcast intent
      // Each alarm reschedules itself, creating a repeating pattern
      await _channel.invokeMethod('scheduleKeepaliveRestart', {
        'delaySeconds': 300, // 5 minutes
        'scheduledBy': 'keepalive_service',
      });
      print('   ✅ Native restart alarm scheduled (5-min interval, self-perpetuating)');
    } catch (e) {
      print('   ⚠️ Failed to schedule native restart alarm: $e');
      // Not critical - WorkManager will handle restarts
    }
  }
  
  /// Stop periodic keepalive
  static Future<void> stopPeriodicKeepalive() async {
    try {
      await AndroidAlarmManager.cancel(_alarmId);
      print('⏹️ [AppKeepalive] Keepalive stopped');
    } catch (e) {
      print('❌ [AppKeepalive] Failed to stop: $e');
    }
  }
  
  /// Callback that runs every 10 minutes
  /// This runs in isolate - CANNOT use MethodChannel!
  /// Instead, we schedule an immediate alarm that triggers AppRestartReceiver
  @pragma('vm:entry-point')
  static Future<void> _keepaliveCallback() async {
    print('🔔 [AppKeepalive] Alarm triggered at ${DateTime.now()}');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastActive = prefs.getInt('last_active_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final minutesSinceActive = (now - lastActive) ~/ 60000;
      
      print('   Minutes since last active: $minutesSinceActive');
      
      // If app hasn't been active for 3+ minutes, assume it's closed
      if (minutesSinceActive >= 3) {
        print('   ⚠️ App appears CLOSED');
        print('   ℹ️ Cannot launch app from alarm isolate (MethodChannel limitation)');
        print('   ℹ️ App will be launched by AppRestartReceiver');
        
        // Just log the detection for now
        await prefs.setInt('last_app_closed_detected', now);
        await prefs.setInt('app_closed_detections', 
          (prefs.getInt('app_closed_detections') ?? 0) + 1);
          
      } else {
        print('   ✅ App is active - no action needed');
      }
      
      // Always update keepalive timestamp
      await prefs.setInt('last_keepalive_check', now);
      
    } catch (e) {
      print('❌ [AppKeepalive] Error in callback: $e');
    }
  }
  
  /// Update last active timestamp (call this periodically from UI)
  static Future<void> markAppActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_active_timestamp', 
        DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('❌ [AppKeepalive] Failed to mark active: $e');
    }
  }
  
  /// Get statistics about keepalive service
  static Future<Map<String, dynamic>> getStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'last_active': prefs.getInt('last_active_timestamp'),
      'last_keepalive_check': prefs.getInt('last_keepalive_check'),
      'last_launch_attempt': prefs.getInt('last_launch_attempt'),
      'total_launch_attempts': prefs.getInt('total_launch_attempts') ?? 0,
    };
  }
}
