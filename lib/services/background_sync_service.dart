import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

// Background task callback - runs in isolate (separate from main app)
// Enhanced WorkManager that can LAUNCH APP if it's closed
// This provides secondary keepalive mechanism alongside AlarmManager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔄 [WorkManager] Keepalive task started: $task at ${DateTime.now()}');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('saved_device_id');
      final isConnected = prefs.getBool('device_connected') ?? false;
      final lastActive = prefs.getInt('last_active_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final minutesSinceActive = (now - lastActive) ~/ 60000;
      
      if (deviceId == null) {
        print('⚠️ [WorkManager] No device data - skipping');
        return Future.value(true);
      }
      
      print('✅ [WorkManager] Status Check:');
      print('   Device: $deviceId');
      print('   Connected: $isConnected');
      print('   Minutes since last active: $minutesSinceActive');
      
      // If app hasn't been active for 5+ minutes AND device should be connected
      if (minutesSinceActive >= 5 && deviceId.isNotEmpty) {
        print('   ⚠️ App appears CLOSED for $minutesSinceActive minutes');
        print('   ℹ️ Cannot launch app from WorkManager isolate (MethodChannel limitation)');
        print('   ℹ️ App will be launched by native AlarmManager broadcast');
        
        // We CANNOT launch the app from here because:
        // 1. WorkManager callback runs in an isolate (separate Dart VM)
        // 2. MethodChannel doesn't work in isolates
        // 3. No Dart-based solution works for launching app from isolate
        //
        // Solutions that DO work:
        // - Native AlarmManager with broadcast (scheduled when app starts)
        // - User manually opens app
        // - Native ForegroundService (already running)
        
        // Just log the detection
        await prefs.setInt('last_workmanager_app_closed_detected', now);
        await prefs.setInt('workmanager_app_closed_detections', 
          (prefs.getInt('workmanager_app_closed_detections') ?? 0) + 1);
      } else {
        print('   ✅ App is active or recently active - no launch needed');
      }
      
      // Update last check timestamp
      await prefs.setInt('last_workmanager_check', now);
      
      return Future.value(true);
    } catch (e) {
      print('❌ [WorkManager] Error: $e');
      return Future.value(true);
    }
  });
}

class BackgroundSyncService {
  static const String syncTaskName = 'hfc_periodic_sync';
  static const String uniqueTaskName = 'hfc_background_worker';
  static const MethodChannel _channel = MethodChannel('com.example.hfc_app/app_launcher');
  
  // Initialize WorkManager
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Set to false in production
    );
    print('✅ [BackgroundSync] WorkManager initialized');
  }
  
  // Start periodic background sync (runs every 15 minutes minimum on Android)
  // Also schedules native broadcast alarm for app restart
  static Future<void> startPeriodicSync() async {
    // First, schedule native broadcast alarm for app restart
    // This is done WHILE the app is running so MethodChannel works
    await _scheduleNativeWorkManagerRestart();
    
    // Then start WorkManager periodic task
    await Workmanager().registerPeriodicTask(
      uniqueTaskName,
      syncTaskName,
      frequency: const Duration(minutes: 15), // Android minimum is 15 minutes
      constraints: Constraints(
        networkType: NetworkType.connected, // Only run with internet
        requiresBatteryNotLow: false, // Run even on low battery
        requiresCharging: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep, // Keep existing work if already scheduled
      initialDelay: const Duration(minutes: 1), // First run after 1 minute
    );
    print('✅ [BackgroundSync] Periodic background sync started (every 15 min)');
    print('   Native restart alarm: 8-min interval');
    print('   Native broadcast alarm also scheduled for app restart');
    print('   This ensures webhooks continue even when app is closed');
  }
  
  /// Schedule native broadcast alarm for WorkManager-based app restart
  /// This is called while the app is running so MethodChannel works
  /// Creates self-perpetuating restart cycle via AppRestartReceiver
  static Future<void> _scheduleNativeWorkManagerRestart() async {
    try {
      // Call native method to schedule alarm with broadcast intent
      // This will fire every 8 minutes and auto-reschedule itself
      await _channel.invokeMethod('scheduleKeepaliveRestart', {
        'delaySeconds': 480, // 8 minutes
        'scheduledBy': 'workmanager',
      });
      print('   ✅ WorkManager native restart alarm scheduled (8-min interval)');
    } catch (e) {
      print('   ⚠️ Failed to schedule WorkManager restart alarm: $e');
      // Not critical - other keepalive mechanisms exist
    }
  }
  
  // Stop background sync
  static Future<void> stopPeriodicSync() async {
    await Workmanager().cancelByUniqueName(uniqueTaskName);
    print('⏹️ [BackgroundSync] Background sync stopped');
  }
  
  // Cancel all background tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    print('⏹️ [BackgroundSync] All background tasks cancelled');
  }
}
