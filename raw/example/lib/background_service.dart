import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Background service manager for HC20 sensor streaming and upload
/// This service keeps sensor streaming active even when the app is in the background
class BackgroundServiceManager {
  static const String _serviceEnabledKey = 'background_service_enabled';
  
  static BackgroundServiceManager? _instance;
  static BackgroundServiceManager get instance {
    _instance ??= BackgroundServiceManager._();
    return _instance!;
  }
  
  BackgroundServiceManager._();
  
  bool _isRunning = false;
  
  /// Initialize the background service
  /// This should be called once at app startup
  Future<void> initialize() async {
    final service = FlutterBackgroundService();
    
    try {
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: 'hc20_background_service',
          initialNotificationTitle: 'HC20 Sensor Streaming',
          initialNotificationContent: 'Streaming IMU, PPG, and GSR data to cloud',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
      print('[BackgroundService] Configuration initialized successfully');
    } catch (e) {
      print('[BackgroundService] Error initializing configuration: $e');
      // Don't throw - initialization failure shouldn't crash the app
    }
  }
  
  /// Check if background service is enabled
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_serviceEnabledKey) ?? false;
  }
  
  /// Check if battery optimization is disabled for this app
  /// Returns true if battery optimization is disabled (exempted), false otherwise
  /// On non-Android platforms, always returns true
  Future<bool> isBatteryOptimizationDisabled() async {
    if (kIsWeb) return true;
    
    try {
      // Check if we're on Android
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (e) {
      print('[BackgroundService] Error checking battery optimization status: $e');
      // If we can't check, assume it's not disabled (safer assumption)
      return false;
    }
  }
  
  /// Request battery optimization exemption
  /// This is critical for preventing Android from killing the app after 15 minutes
  /// Returns true if the request was successful or already granted, false otherwise
  /// On non-Android platforms, always returns true
  /// 
  /// IMPORTANT: This will show a system dialog to the user asking them to allow
  /// the app to ignore battery optimization. The user must grant this permission
  /// for the background service to work reliably on Android.
  Future<bool> requestBatteryOptimizationExemption() async {
    if (kIsWeb) return true;
    
    try {
      // Check current status first
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) {
        print('[BackgroundService] Battery optimization already disabled');
        return true;
      }
      
      // Request permission
      print('[BackgroundService] Requesting battery optimization exemption...');
      final result = await Permission.ignoreBatteryOptimizations.request();
      
      if (result.isGranted) {
        print('[BackgroundService] Battery optimization exemption granted');
        return true;
      } else {
        print('[BackgroundService] Battery optimization exemption denied. The app may be killed after ~15 minutes in background.');
        print('[BackgroundService] User should manually disable battery optimization in Settings > Apps > [App Name] > Battery > Battery Optimization');
        return false;
      }
    } catch (e) {
      print('[BackgroundService] Error requesting battery optimization exemption: $e');
      return false;
    }
  }
  
  /// Start the background service
  /// Note: The actual sensor streaming should be started separately using Hc20Client
  /// This service just keeps the app alive in the background
  /// 
  /// On Android: The service will automatically start as foreground service
  /// with notification when isForegroundMode: true is set in configuration.
  /// On iOS: Uses background modes declared in Info.plist.
  /// 
  /// IMPORTANT: This method will NOT throw exceptions. If the service fails to start
  /// (e.g., due to notification channel issues on Android), the app will continue
  /// running normally. The background service is optional.
  /// 
  /// WARNING: On some Android devices, starting a foreground service can crash the app
  /// if the notification channel isn't properly set up. This is a known issue with
  /// the flutter_background_service plugin on certain Android versions/devices.
  /// If you experience crashes, disable the background service toggle.
  /// Ensure battery optimization is disabled (called independently or before starting service)
  /// This should be called when device connects to ensure battery optimization is disabled
  /// before the background service needs to run
  Future<void> ensureBatteryOptimizationDisabled() async {
    // Check and print battery optimization status BEFORE requesting exemption
    // This is critical to prevent Android from killing the app after 15 minutes
    final isBatteryOptimizationDisabled = await this.isBatteryOptimizationDisabled();
    print('[BackgroundService] Battery optimization status: ${isBatteryOptimizationDisabled ? "DISABLED (exempted)" : "ENABLED (not exempted)"}');
    
    // Request battery optimization exemption if not already disabled
    // The user will see a system dialog asking them to allow this
    final batteryOptimized = await requestBatteryOptimizationExemption();
    if (!batteryOptimized) {
      print('[BackgroundService] WARNING: Battery optimization is still enabled. The app may be killed after ~15 minutes in background.');
      print('[BackgroundService] Please disable battery optimization in Settings > Apps > [App Name] > Battery > Battery Optimization');
    } else {
      print('[BackgroundService] Battery optimization exemption is active. App should not be killed in background.');
    }
  }
  
  Future<void> start() async {
    // Always check battery optimization status, even if service is already running
    // This ensures it's checked when device connects and service auto-starts
    await ensureBatteryOptimizationDisabled();
    
    if (_isRunning) {
      print('[BackgroundService] Already running');
      return;
    }
    
    // Save state first (before attempting to start)
    final prefs = await SharedPreferences.getInstance();
    
    // Try to stop any existing service first to avoid conflicts
    // This helps if the service was in a bad state from a previous crash
    try {
      final service = FlutterBackgroundService();
      service.invoke('stop');
      // Wait longer to ensure the service is fully stopped
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {
      // Ignore errors when stopping - service might not be running
    }
    
    // Start the service
    // The plugin will automatically handle foreground service setup on Android
    // when isForegroundMode: true is configured
    final service = FlutterBackgroundService();
    try {
      // Ensure service is configured before starting
      // Re-configuring helps ensure notification channel is ready on some devices
      try {
        await service.configure(
          androidConfiguration: AndroidConfiguration(
            onStart: onStart,
            autoStart: false,
            isForegroundMode: true,
            notificationChannelId: 'hc20_background_service',
            initialNotificationTitle: 'HC20 Sensor Streaming',
            initialNotificationContent: 'Streaming IMU, PPG, and GSR data to cloud',
            foregroundServiceNotificationId: 888,
          ),
          iosConfiguration: IosConfiguration(
            autoStart: false,
            onForeground: onStart,
            onBackground: onIosBackground,
          ),
        );
        // Wait longer to ensure configuration is fully applied and notification channel is created
        // Android 15 requires proper notification channel setup before starting foreground service
        await Future.delayed(const Duration(milliseconds: 1000));
      } catch (configError) {
        print('[BackgroundService] Warning: Re-configuration failed, but continuing: $configError');
        // Continue anyway - service might already be configured
      }
      
      // Try to start the service
      // On Android, this will attempt to start as foreground service
      // The plugin handles notification channel creation automatically
      // However, on some devices/Android versions, this can still fail and crash
      // The crash happens in native code, so we can't catch it here
      print('[BackgroundService] Attempting to start service...');
      await service.startService();
      
      // Wait longer to see if the service actually starts successfully
      // The native crash happens asynchronously, so we can't catch it directly
      // If the service crashes, the app will be killed by Android
      print('[BackgroundService] Service start() returned, waiting to verify...');
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Only mark as running if we got here without crashing
      // If the service crashed, the app would have been killed by now
      _isRunning = true;
      await prefs.setBool(_serviceEnabledKey, true);
      print('[BackgroundService] Started successfully');
    } catch (e) {
      print('[BackgroundService] Error starting service: $e');
      print('[BackgroundService] Service failed to start, but app will continue');
      // Reset state on failure
      await prefs.setBool(_serviceEnabledKey, false);
      _isRunning = false;
      // Don't rethrow - allow app to continue even if background service fails
      // The service is optional and sensors can still work without it
      // On some Android devices, foreground service notification setup can fail
      // but this shouldn't crash the entire app
    }
  }
  
  /// Stop the background service
  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }
    
    // Save state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_serviceEnabledKey, false);
    
    // Stop the service
    final service = FlutterBackgroundService();
    service.invoke('stop');
    
    _isRunning = false;
    
    print('[BackgroundService] Stopped');
  }
  
  /// Update notification content
  Future<void> updateNotification(String title, String content) async {
    final service = FlutterBackgroundService();
    service.invoke('updateNotification', {
      'title': title,
      'content': content,
    });
  }
}

/// Background service entry point
/// 
/// On Android: This runs as a foreground service with notification
/// On iOS: This runs with background modes (bluetooth-central, etc.)
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  // Note: The plugin automatically sets the service as foreground when isForegroundMode: true
  // We don't need to call setAsForegroundService() manually here
  // If notification setup fails, it will fail during startService() and be caught there
  
  // Handle notification updates (Android only)
  service.on('updateNotification').listen((event) {
    if (event is Map<String, dynamic>) {
      final title = event['title'] as String? ?? 'HC20 Sensor Streaming';
      final content = event['content'] as String? ?? 'Streaming data to cloud';
      if (service is AndroidServiceInstance) {
        try {
          service.setForegroundNotificationInfo(
            title: title,
            content: content,
          );
        } catch (e) {
          // Ignore notification errors - service can continue without updates
          print('[BackgroundService] Error updating notification: $e');
        }
      }
    }
  });
  
  // Handle stop command
  service.on('stop').listen((event) {
    service.stopSelf();
  });
  
  // Keep the service alive and update notification periodically
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (service is AndroidServiceInstance) {
      try {
        // Only update notification if service is running as foreground
        // The plugin handles the initial foreground service setup automatically
        final isForeground = await service.isForegroundService();
        if (isForeground) {
          final timestamp = DateTime.now().toString().substring(11, 19);
          service.setForegroundNotificationInfo(
            title: 'HC20 Sensor Streaming',
            content: 'Streaming IMU, PPG, and GSR data to cloud\nLast update: $timestamp',
          );
        }
      } catch (e) {
        // Ignore notification errors - service can continue without notification updates
        // This prevents crashes from notification issues
        // Errors are expected if notification channel isn't set up yet
      }
    }
    // Note: iOS doesn't support foreground notifications in the same way
    // iOS relies on background modes declared in Info.plist
    
    // Check if service should stop
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('background_service_enabled') ?? false;
    if (!enabled) {
      timer.cancel();
      service.stopSelf();
    }
  });
}

/// iOS background handler
/// iOS has stricter background execution limits than Android
/// Background modes must be declared in Info.plist:
/// - bluetooth-central: for maintaining BLE connections
/// - fetch: for background data fetching/upload
/// - processing: for background data processing
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  // On iOS, we can keep the service running but with limitations:
  // - BLE connections can be maintained with bluetooth-central mode
  // - Background execution time is limited (typically ~30 seconds after app goes to background)
  // - The system may suspend the app after this period
  // - When the app is woken up (e.g., by BLE events), we can continue processing
  
  // Set up periodic task to keep service alive
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    // Check if service should stop
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('background_service_enabled') ?? false;
    if (!enabled) {
      timer.cancel();
      service.stopSelf();
    }
  });
  
  return true;
}

