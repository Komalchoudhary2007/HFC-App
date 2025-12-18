/// SDK Configuration for Testing
/// 
/// This file allows switching between the old SDK (hc20) and new SDK (hc20_new)
/// for testing purposes without breaking existing functionality.
/// 
/// USAGE:
/// 1. Change USE_NEW_SDK to true to test the new SDK
/// 2. Change USE_NEW_SDK to false to use the stable old SDK
/// 3. Run `flutter pub get` after changing the SDK
/// 4. Run the app and test all features

class SdkConfig {
  /// Set to true to use the new SDK (hc20_new v1.0.2)
  /// Set to false to use the old stable SDK (hc20 v1.0.0)
  /// 
  /// When testing new SDK, verify:
  /// - Device connection and auto-sensor enabling
  /// - Background sync activation
  /// - Historical data retrieval
  /// - Webhook data transmission
  /// - All existing features work as expected
  static const bool USE_NEW_SDK = false;
  
  /// SDK version information
  static String get currentSdkVersion => USE_NEW_SDK ? '1.0.2 (NEW)' : '1.0.0 (STABLE)';
  
  /// Features available in new SDK
  static const Map<String, bool> newSdkFeatures = {
    'Auto Background Sync': true,
    'Auto Enable Sensors': true,
    'Dev/Production Toggle': true,
    'Improved Raw Sensor Handling': true,
  };
  
  /// Get feature availability description
  static String getFeatureDescription() {
    if (!USE_NEW_SDK) {
      return 'Using STABLE SDK (v1.0.0) - All current features working';
    }
    
    StringBuffer desc = StringBuffer('Using NEW SDK (v1.0.2) with:\n');
    newSdkFeatures.forEach((feature, enabled) {
      desc.write('  ✓ $feature\n');
    });
    return desc.toString();
  }
}
