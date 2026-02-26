import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistent OAuth token storage with encryption
/// Stores tokens securely on disk to survive app restarts
class PersistentTokenStorage {
  static const String _tokenKey = 'hc20_oauth_token';
  static const String _expiryKey = 'hc20_oauth_expiry';
  static const String _tokenTypeKey = 'hc20_oauth_token_type';
  
  final FlutterSecureStorage _storage;
  
  PersistentTokenStorage() : _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Save token to encrypted disk storage
  Future<void> saveToken({
    required String accessToken,
    required DateTime expiryTime,
    String tokenType = 'Bearer',
  }) async {
    try {
      await _storage.write(key: _tokenKey, value: accessToken);
      await _storage.write(key: _expiryKey, value: expiryTime.toIso8601String());
      await _storage.write(key: _tokenTypeKey, value: tokenType);
      
      print('✅ Token saved to disk (expires: ${expiryTime.toLocal()})');
    } catch (e) {
      print('⚠️ Failed to save token to disk: $e');
    }
  }

  /// Load token from encrypted disk storage
  /// Returns null if token doesn't exist or is expired
  Future<TokenData?> loadToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final expiryStr = await _storage.read(key: _expiryKey);
      final tokenType = await _storage.read(key: _tokenTypeKey) ?? 'Bearer';
      
      if (token == null || expiryStr == null) {
        print('ℹ️ No token found on disk');
        return null;
      }
      
      final expiry = DateTime.parse(expiryStr);
      final now = DateTime.now();
      
      // Check if token is still valid (with 15-minute safety buffer)
      if (now.isAfter(expiry.subtract(const Duration(minutes: 15)))) {
        print('⚠️ Token on disk expired or expiring soon (expiry: ${expiry.toLocal()})');
        await clearToken(); // Clean up expired token
        return null;
      }
      
      print('✅ Loaded valid token from disk (expires: ${expiry.toLocal()})');
      return TokenData(
        accessToken: token,
        expiryTime: expiry,
        tokenType: tokenType,
      );
    } catch (e) {
      print('⚠️ Failed to load token from disk: $e');
      return null;
    }
  }

  /// Clear token from disk storage
  /// Call on logout or 401 errors
  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _expiryKey);
      await _storage.delete(key: _tokenTypeKey);
      print('✅ Token cleared from disk');
    } catch (e) {
      print('⚠️ Failed to clear token from disk: $e');
    }
  }

  /// Check if we have a valid token on disk
  Future<bool> hasValidToken() async {
    final token = await loadToken();
    return token != null;
  }
}

/// Token data structure
class TokenData {
  final String accessToken;
  final DateTime expiryTime;
  final String tokenType;
  
  TokenData({
    required this.accessToken,
    required this.expiryTime,
    this.tokenType = 'Bearer',
  });
  
  /// Check if token is still valid (with 15-minute safety buffer)
  bool isValid() {
    final now = DateTime.now();
    return now.isBefore(expiryTime.subtract(const Duration(minutes: 15)));
  }
  
  /// Time remaining until token expires
  Duration timeRemaining() {
    return expiryTime.difference(DateTime.now());
  }
  
  @override
  String toString() {
    return 'TokenData(expires: ${expiryTime.toLocal()}, valid: ${isValid()}, remaining: ${timeRemaining().inMinutes} min)';
  }
}
