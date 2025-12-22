import 'dart:async';
import 'package:dio/dio.dart';

/// OAuth authentication service for HC20 cloud API
class Hc20AuthService {
  final String authUrl;
  final String clientId;
  final String clientSecret;
  final String grantType;
  
  final Dio _dio;
  String? _cachedToken;
  DateTime? _tokenExpiry;
  Completer<void>? _currentRequest;

  Hc20AuthService({
    required this.authUrl,
    required this.clientId,
    required this.clientSecret,
    this.grantType = 'client_credentials',
  }) : _dio = Dio(BaseOptions(
          baseUrl: authUrl,
        ));

  /// Get a valid access token, refreshing if necessary
  Future<String> getAccessToken() async {
    // If we have a valid cached token, return it
    if (_cachedToken != null && _tokenExpiry != null) {
      final now = DateTime.now();
      // Refresh if token expires within 5 minutes
      if (now.isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
        return _cachedToken!;
      }
    }

    // If there's already a request in flight, wait for it
    if (_currentRequest != null && !_currentRequest!.isCompleted) {
      await _currentRequest!.future;
      if (_cachedToken != null) {
        return _cachedToken!;
      }
    }

    // Create a new request
    final completer = Completer<void>();
    _currentRequest = completer;

    try {
      await _refreshToken();
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
          
          // Extract expiry time if provided, otherwise assume 1 hour
          final expiresIn = data['expires_in'] as int?;
          if (expiresIn != null) {
            _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
          } else {
            // Default to 1 hour if not provided
            _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
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

  /// Clear the cached token (useful for logout or on errors)
  void clearToken() {
    _cachedToken = null;
    _tokenExpiry = null;
  }
}

