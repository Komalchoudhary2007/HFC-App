import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OAuth authentication service for HC20 cloud API.
/// Persists the access token and only requests a new one when the current token is expired
/// (or within 5 minutes of expiry). Tokens are stored per credential (authUrl + clientId).
class Hc20AuthService {
  static const _refreshBuffer = Duration(minutes: 5);

  final String authUrl;
  final String clientId;
  final String clientSecret;
  final String grantType;
  
  final Dio _dio;
  String? _cachedToken;
  DateTime? _tokenExpiry;
  Completer<void>? _currentRequest;
  SharedPreferences? _prefs;
  String? _storageKeyPrefix;

  Hc20AuthService({
    required this.authUrl,
    required this.clientId,
    required this.clientSecret,
    this.grantType = 'client_credentials',
  }) : _dio = Dio(BaseOptions(
          baseUrl: authUrl,
        )) {
    _storageKeyPrefix = 'hc20_oauth_${Object.hash(authUrl, clientId).toRadixString(16)}';
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String get _keyToken => '${_storageKeyPrefix}_token';
  String get _keyExpiry => '${_storageKeyPrefix}_expiry';

  /// Returns true if [expiry] is still valid (now is before expiry - buffer).
  bool _isValidExpiry(DateTime expiry) {
    final now = DateTime.now();
    return now.isBefore(expiry.subtract(_refreshBuffer));
  }

  /// Load persisted token if present and not expired. Updates in-memory cache.
  Future<bool> _loadPersistedToken() async {
    final prefs = await _getPrefs();
    final token = prefs.getString(_keyToken);
    final expiryMs = prefs.getInt(_keyExpiry);
    if (token == null || token.isEmpty || expiryMs == null) return false;
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
    if (!_isValidExpiry(expiry)) return false;
    _cachedToken = token;
    _tokenExpiry = expiry;
    return true;
  }

  Future<void> _persistToken() async {
    if (_cachedToken == null || _tokenExpiry == null) return;
    final prefs = await _getPrefs();
    await prefs.setString(_keyToken, _cachedToken!);
    await prefs.setInt(_keyExpiry, _tokenExpiry!.millisecondsSinceEpoch);
  }

  /// Get a valid access token. Uses in-memory cache, then persisted token; only requests a new token when expired.
  Future<String> getAccessToken() async {
    // 1) Valid in-memory token (not expired and not within 5 min of expiry)
    if (_cachedToken != null && _tokenExpiry != null && _isValidExpiry(_tokenExpiry!)) {
      return _cachedToken!;
    }

    // 2) Wait if another request is already refreshing
    if (_currentRequest != null && !_currentRequest!.isCompleted) {
      await _currentRequest!.future;
      if (_cachedToken != null) return _cachedToken!;
    }

    // 3) Try persisted token (e.g. after restart or new client instance)
    if (await _loadPersistedToken()) return _cachedToken!;

    // 4) Request new token and persist it
    final completer = Completer<void>();
    _currentRequest = completer;
    try {
      await _refreshToken();
      await _persistToken();
      completer.complete();
      return _cachedToken!;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _currentRequest = null;
    }
  }

  /// Refresh the access token from the OAuth endpoint
  Future<void> _refreshToken() async {
    try {
      // Encode as URL-encoded form data
      final formData = Uri(queryParameters: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': grantType,
      }).query; // This gives us the encoded string without the '?'
      
      final response = await _dio.post(
        '',
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data.containsKey('access_token')) {
          _cachedToken = data['access_token'] as String;
          
          // Use expires_in from response (seconds, e.g. 604800 = 7 days).
          final expiresIn = data['expires_in'];
          if (expiresIn is int && expiresIn > 0) {
            _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
          } else {
            throw Exception('Invalid response format: missing or invalid expires_in');
          }
        } else {
          throw Exception('Invalid response format: missing access_token');
        }
      } else {
        throw Exception(
          'Authentication failed: ${response.statusCode} - ${response.data}',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        'Authentication request failed: ${e.message}',
      );
    }
  }

  /// Clear the cached and persisted token (e.g. on 401 so next request fetches a new one).
  Future<void> clearToken() async {
    _cachedToken = null;
    _tokenExpiry = null;
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyExpiry);
    } catch (_) {
      // Ignore storage errors when clearing
    }
  }
}

