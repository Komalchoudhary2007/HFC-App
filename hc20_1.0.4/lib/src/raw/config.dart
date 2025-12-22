/// Environment configuration for HC20 cloud API
/// 
/// This class contains internal configuration values used by the plugin.
/// The `authUrl` and `baseUrl` are always used from this config.
/// Clients must provide their own `clientId` and `clientSecret` via [Hc20Config].
class Hc20CloudConfig {
  /// Development mode flag. When true, uses development API endpoints.
  /// When false, uses production API endpoints.
  static bool isDevelopment = false;
  
  /// Base URL for the HC20 wearable API (production)
  static const String _productionBaseUrl = 'http://out-licensing.zensorium-labs.com/api/v1/hc20-wearable-api';
  
  /// Base URL for the HC20 wearable API (development)
  static const String _developmentBaseUrl = 'http://out-licensing-dev.zensorium-labs.com/api/v1/hc20-wearable-api';
  
  /// Base URL for the HC20 wearable API (returns development or production based on [isDevelopment])
  static String get baseUrl => isDevelopment ? _developmentBaseUrl : _productionBaseUrl;
  
  /// OAuth authentication URL
  static const String authUrl = 'https://auth.zensorium-labs.com/api/login/oauth/access_token';
  
  /// OAuth grant type
  static const String grantType = 'client_credentials';
  
  /// Batch size for uploading raw sensor data
  static const int batchSize = 50;
  
  /// Data transfer flag (default: 0)
  static const int dataTransferFlag = 0;
  
  /// Debug logging flag. When true, enables all print statements for debugging.
  /// When false, all debug print statements are disabled.
  static bool debugLog = false;
  
  /// Helper function to conditionally print debug messages based on [debugLog] flag.
  /// Only prints if [debugLog] is true.
  static void debugPrint(Object? message) {
    if (debugLog) {
      print(message);
    }
  }
}

