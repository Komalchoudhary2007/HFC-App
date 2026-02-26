import 'package:hc20/src/raw/auth_service.dart';
import 'persistent_token_storage.dart';

/// Enhanced OAuth service with persistent disk caching and smart refresh
/// Implements all OAuth optimization strategies
class EnhancedOAuthService {
  final String clientId;
  final String clientSecret;
  final String authUrl;
  final String grantType;
  
  // In-memory cache (fast access)
  String? _cachedToken;
  DateTime? _tokenExpiry;
  
  // Persistent storage (survives app restarts)
  final PersistentTokenStorage _persistentStorage = PersistentTokenStorage();
  
  // Prevent concurrent OAuth requests
  Future<String>? _currentRequest;
  
  EnhancedOAuthService({
    required this.clientId,
    required this.clientSecret,
    required this.authUrl,
    this.grantType = 'client_credentials',
  });

  /// Get a valid OAuth token (checks memory → disk → server)
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    print('\n🔐 OAuth Token Request (forceRefresh: $forceRefresh)');
    
    // If there's already a request in flight, wait for it
    if (_currentRequest != null) {
      print('⏳ Waiting for existing OAuth request...');
      return await _currentRequest!;
    }
    
    // Start new request
    _currentRequest = _getAccessTokenInternal(forceRefresh: forceRefresh);
    
    try {
      final token = await _currentRequest!;
      return token;
    } finally {
      _currentRequest = null;
    }
  }
  
  Future<String> _getAccessTokenInternal({bool forceRefresh = false}) async {
    // Step 1: Check memory cache first (fastest)
    if (!forceRefresh && _cachedToken != null && _tokenExpiry != null) {
      final now = DateTime.now();
      // Refresh 15 minutes before expiry (3x more buffer than SDK's 5 min)
      if (now.isBefore(_tokenExpiry!.subtract(const Duration(minutes: 15)))) {
        final remaining = _tokenExpiry!.difference(now);
        print('✅ Using cached token from MEMORY (expires in ${remaining.inMinutes} min)');
        return _cachedToken!;
      } else {
        print('⏰ Token in memory expires soon, will refresh');
      }
    }
    
    // Step 2: Check disk cache (survives app restarts)
    if (!forceRefresh) {
      final tokenData = await _persistentStorage.loadToken();
      if (tokenData != null && tokenData.isValid()) {
        // Load from disk to memory
        _cachedToken = tokenData.accessToken;
        _tokenExpiry = tokenData.expiryTime;
        print('✅ Loaded token from DISK to memory (expires in ${tokenData.timeRemaining().inMinutes} min)');
        return _cachedToken!;
      }
    }
    
    // Step 3: Request new token from server
    print('🌐 Requesting new token from OAuth server...');
    final newToken = await _requestTokenFromServer();
    return newToken;
  }
  
  /// Request new token from OAuth server
  Future<String> _requestTokenFromServer() async {
    try {
      // Use HC20 SDK's existing auth service
      final authService = Hc20AuthService(
        authUrl: authUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        grantType: grantType,
      );
      
      final token = await authService.getAccessToken();
      
      // The SDK stores expiry internally, we need to extract it
      // Since SDK uses 1 hour default, we'll use that
      final expiryTime = DateTime.now().add(const Duration(hours: 1));
      
      // Save to both memory and disk
      _cachedToken = token;
      _tokenExpiry = expiryTime;
      
      await _persistentStorage.saveToken(
        accessToken: token,
        expiryTime: expiryTime,
        tokenType: 'Bearer',
      );
      
      print('✅ New token obtained from server (expires: ${expiryTime.toLocal()})');
      return token;
      
    } catch (e) {
      print('❌ OAuth request failed: $e');
      
      // Check if it's a 500 error (server error)
      if (e.toString().contains('500')) {
        print('⚠️ Server error (500) - NOT clearing cached token');
        // Don't clear token on server errors - it might still be valid
        // Return cached token if available (better than nothing)
        if (_cachedToken != null) {
          print('⚠️ Returning cached token despite server error');
          return _cachedToken!;
        }
      }
      
      rethrow;
    }
  }
  
  /// Clear token from both memory and disk
  /// ONLY call on logout or 401 (invalid credentials)
  Future<void> clearToken({required ClearReason reason}) async {
    print('\n🗑️ Clearing OAuth token (reason: ${reason.name})');
    
    switch (reason) {
      case ClearReason.logout:
      case ClearReason.invalidCredentials:
        // Clear from both memory and disk
        _cachedToken = null;
        _tokenExpiry = null;
        await _persistentStorage.clearToken();
        print('✅ Token cleared from memory and disk');
        break;
        
      case ClearReason.serverError:
      case ClearReason.networkTimeout:
      case ClearReason.appBackground:
      case ClearReason.deviceDisconnect:
        // DO NOT clear token - it might still be valid
        print('⚠️ NOT clearing token for ${reason.name} (token may still be valid)');
        break;
    }
  }
  
  /// Proactively refresh token if it's expiring soon
  /// Call this periodically when app is active
  Future<void> proactiveRefresh() async {
    if (_tokenExpiry == null) return;
    
    final now = DateTime.now();
    final timeUntilExpiry = _tokenExpiry!.difference(now);
    
    // Refresh if less than 15 minutes remaining
    if (timeUntilExpiry.inMinutes < 15) {
      print('⏰ Proactive refresh: Token expires in ${timeUntilExpiry.inMinutes} min');
      try {
        await getAccessToken(forceRefresh: true);
      } catch (e) {
        print('⚠️ Proactive refresh failed: $e');
        // Don't throw - this is background refresh
      }
    }
  }
  
  /// Get token status for debugging
  Future<String> getTokenStatus() async {
    final memoryStatus = _cachedToken != null 
        ? 'Memory: ${_tokenExpiry != null ? _tokenExpiry!.difference(DateTime.now()).inMinutes : '?'} min remaining'
        : 'Memory: empty';
    
    final diskToken = await _persistentStorage.loadToken();
    final diskStatus = diskToken != null
        ? 'Disk: ${diskToken.timeRemaining().inMinutes} min remaining'
        : 'Disk: empty';
    
    return '$memoryStatus | $diskStatus';
  }
}

/// Reasons for clearing OAuth token
enum ClearReason {
  logout,              // User logged out - CLEAR TOKEN ✅
  invalidCredentials,  // 401 error - CLEAR TOKEN ✅
  serverError,         // 500 error - KEEP TOKEN ❌
  networkTimeout,      // Network timeout - KEEP TOKEN ❌
  appBackground,       // App went to background - KEEP TOKEN ❌
  deviceDisconnect,    // Device disconnected - KEEP TOKEN ❌
}
