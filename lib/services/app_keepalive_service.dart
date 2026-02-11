import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// Service that uses AlarmManager to ensure app stays alive or auto-restarts
/// This is the MOST RELIABLE method for keeping app running in background
/// Uses Native Android AlarmManager - survives app kills and device reboots
@pragma('vm:entry-point')
class AppKeepaliveService {
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
  
  /// Save sync intervals to SharedPreferences so native code can read them
  /// Call this when app starts or when intervals change
  /// @param realtimeInterval - realtime sync interval in minutes
  /// @param reconnectInterval - reconnect attempt interval in minutes
  @pragma('vm:entry-point')
  static Future<void> saveIntervalsToNative({
    required int realtimeInterval,
    required int reconnectInterval,
  }) async {
    try {
      print('🔧 [AppKeepalive] ========== SAVING INTERVALS TO NATIVE ==========');
      print('🔧 [AppKeepalive] realtimeInterval: $realtimeInterval min');
      print('🔧 [AppKeepalive] reconnectInterval: $reconnectInterval min');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('realtime_interval_minutes', realtimeInterval);
      await prefs.setInt('reconnect_interval_minutes', reconnectInterval);
      
      // Verify saved values
      final savedRealtime = prefs.getInt('realtime_interval_minutes');
      final savedReconnect = prefs.getInt('reconnect_interval_minutes');
      print('🔧 [AppKeepalive] Verified saved values - realtime: $savedRealtime, reconnect: $savedReconnect');
      print('✅ [AppKeepalive] Intervals saved successfully!');
      print('🔧 [AppKeepalive] ================================================');
    } catch (e) {
      print('❌ [AppKeepalive] Failed to save intervals: $e');
    }
  }
  
  /// Start periodic app keepalive (every 5 minutes)
  /// This will:
  /// 1. Check if app is running
  /// 2. If not running, launch the app  
  /// 3. If running, ensure HC20 connection is active
  static Future<void> startPeriodicKeepalive() async {
    try {
      // Schedule native broadcast alarm (the ONLY alarm we need)
      // This alarm will trigger AppRestartReceiver every 5 minutes
      // We do this WHILE the app is running so MethodChannel works
      await _scheduleNativeRestartAlarm();
      
      // ❌ REMOVED: AndroidAlarmManager.periodic() 
      // Reason: It creates a 3rd Flutter engine (isolate) which:
      // - Cannot use MethodChannel to launch app (isolate limitation)
      // - Interferes with BLE connection (multiple engines conflict)
      // - Wastes battery (useless background engine)
      // Native broadcast alarm is sufficient for app relaunch
      
      print('✅ [AppKeepalive] Periodic keepalive started (native alarm only)');
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
      // NOTE: This is just initial fallback - dynamic scheduling will override this
      //       after device connects (after_realtime_sync) or reconnect fails (after_reconnect_fail)
      await _channel.invokeMethod('scheduleKeepaliveRestart', {
        'delaySeconds': 600, // 10 minutes (initial fallback, will be overwritten by dynamic scheduling)
        'scheduledBy': 'keepalive_service',
      });
      print('   ✅ Native restart alarm scheduled (5-min initial, will be overwritten by dynamic scheduling)');
    } catch (e) {
      print('   ⚠️ Failed to schedule native restart alarm: $e');
      // Not critical - WorkManager will handle restarts
    }
  }
  
  /// Schedule next alarm dynamically based on connection state
  /// Called after realtime sync (connected) or reconnect failure (disconnected)
  /// 
  /// @param delayMinutes - delay in minutes before next alarm fires
  /// @param reason - why this alarm was scheduled (for logging)
  @pragma('vm:entry-point')
  static Future<void> scheduleNextAlarm({
    required int delayMinutes,
    required String reason,
  }) async {
    try {
      final delaySeconds = delayMinutes * 60;
      print('⏰ [AppKeepalive] ========== SCHEDULING NEXT ALARM ==========');
      print('⏰ [AppKeepalive] Reason: $reason');
      print('⏰ [AppKeepalive] Delay: $delayMinutes min ($delaySeconds sec)');
      print('⏰ [AppKeepalive] Expected fire time: ${DateTime.now().add(Duration(minutes: delayMinutes))}');
      
      // Update last_active_timestamp so WorkManager knows app is alive
      await markAppActive();
      
      await _channel.invokeMethod('scheduleKeepaliveRestart', {
        'delaySeconds': delaySeconds,
        'scheduledBy': reason,
      });
      
      print('✅ [AppKeepalive] Alarm scheduled successfully!');
      print('⏰ [AppKeepalive] ==========================================');
    } catch (e) {
      print('⚠️ [AppKeepalive] Failed to schedule next alarm: $e');
    }
  }
  
  /// Stop periodic keepalive
  static Future<void> stopPeriodicKeepalive() async {
    try {
      // Note: Since we removed AndroidAlarmManager.periodic(), 
      // this is now a no-op. Native alarms are cancelled via native code.
      print('⏹️ [AppKeepalive] Keepalive stop requested (native alarms handled by native code)');
    } catch (e) {
      print('❌ [AppKeepalive] Failed to stop: $e');
    }
  }
  
  /// Update last active timestamp (call this periodically from UI)
  /// This tells WorkManager and native code that app is still alive
  @pragma('vm:entry-point')
  static Future<void> markAppActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('last_active_timestamp', now);
      print('✅ [AppKeepalive] Updated last_active_timestamp: ${DateTime.now()}');
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
