import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Manages the flutter_background_service lifecycle and battery optimization gating.
class BackgroundServiceManager {
  static const String _serviceEnabledKey = 'background_service_enabled';

  static BackgroundServiceManager? _instance;
  static BackgroundServiceManager get instance {
    _instance ??= BackgroundServiceManager._();
    return _instance!;
  }

  BackgroundServiceManager._();

  bool _isRunning = false;

  /// Configure the service; safe to call multiple times.
  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    try {
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: 'hc20_background_service',
          initialNotificationTitle: 'HFC App Background',
          initialNotificationContent: 'Keeping HC20 connection alive',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
      // Initialization failures should not crash the app.
    } catch (e) {
      // Log and continue
      // ignore: avoid_print
      print('[BackgroundService] Error initializing configuration: $e');
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_serviceEnabledKey) ?? false;
  }

  Future<bool> isBatteryOptimizationDisabled() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (e) {
      // ignore: avoid_print
      print('[BackgroundService] Error checking battery optimization status: $e');
      return false;
    }
  }

  Future<bool> requestBatteryOptimizationExemption() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) {
        return true;
      }
      final result = await Permission.ignoreBatteryOptimizations.request();
      return result.isGranted;
    } catch (e) {
      // ignore: avoid_print
      print('[BackgroundService] Error requesting battery optimization exemption: $e');
      return false;
    }
  }

  Future<void> ensureBatteryOptimizationDisabled() async {
    final exempted = await isBatteryOptimizationDisabled();
    if (!exempted) {
      await requestBatteryOptimizationExemption();
    }
  }

  Future<void> start() async {
    await ensureBatteryOptimizationDisabled();

    if (_isRunning) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    try {
      final service = FlutterBackgroundService();
      service.invoke('stop');
      await Future.delayed(const Duration(milliseconds: 500));

      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: 'hc20_background_service',
          initialNotificationTitle: 'HFC App Background',
          initialNotificationContent: 'Keeping HC20 connection alive',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1000));
      await service.startService();
      await Future.delayed(const Duration(milliseconds: 1500));

      _isRunning = true;
      await prefs.setBool(_serviceEnabledKey, true);
      // ignore: avoid_print
      print('[BackgroundService] Started');
    } catch (e) {
      // ignore: avoid_print
      print('[BackgroundService] Error starting service: $e');
      await prefs.setBool(_serviceEnabledKey, false);
      _isRunning = false;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_serviceEnabledKey, false);

    final service = FlutterBackgroundService();
    service.invoke('stop');

    _isRunning = false;
    // ignore: avoid_print
    print('[BackgroundService] Stopped');
  }

  Future<void> updateNotification(String title, String content) async {
    final service = FlutterBackgroundService();
    service.invoke('updateNotification', {
      'title': title,
      'content': content,
    });
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  service.on('updateNotification').listen((event) {
    if (event is Map<String, dynamic>) {
      final title = event['title'] as String? ?? 'HFC App Background';
      final content = event['content'] as String? ?? 'Keeping HC20 connection alive';
      if (service is AndroidServiceInstance) {
        try {
          service.setForegroundNotificationInfo(title: title, content: content);
        } catch (e) {
          // ignore notification errors
        }
      }
    }
  });

  service.on('stop').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (service is AndroidServiceInstance) {
      try {
        final isForeground = await service.isForegroundService();
        if (isForeground) {
          final timestamp = DateTime.now().toString().substring(11, 19);
          service.setForegroundNotificationInfo(
            title: 'HFC App Background',
            content: 'HC20 connection keepalive\nLast update: $timestamp',
          );
        }
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('background_service_enabled') ?? false;
    if (!enabled) {
      timer.cancel();
      service.stopSelf();
    }
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('background_service_enabled') ?? false;
    if (!enabled) {
      timer.cancel();
      service.stopSelf();
    }
  });

  return true;
}
