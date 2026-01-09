import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'storage_service.dart';

class ApiService {
  // Base URL - change for production/development
  static const String baseUrl = 'https://api.hireforcare.com';
  // static const String baseUrl = 'http://localhost:4000'; // For local testing
  
  final StorageService _storage = StorageService();

  // Get headers with auth token
  Future<Map<String, String>> _getHeaders({bool includeAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (includeAuth) {
      final token = await _storage.getToken();
      print('🔑 Getting auth token: ${token != null ? "Found (${token.length} chars)" : "NOT FOUND"}');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        print('✅ Authorization header added');
      } else {
        print('❌ WARNING: Auth required but no token found!');
      }
    }
    
    return headers;
  }

  // Handle API errors
  Map<String, dynamic> _handleError(http.Response response) {
    print('❌ API Error: ${response.statusCode}');
    print('   Body: ${response.body}');
    
    try {
      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'error': errorData['error'] ?? errorData['message'] ?? 'Request failed',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        'statusCode': response.statusCode,
      };
    }
  }

  // ============================================================
  // AUTHENTICATION ENDPOINTS
  // ============================================================

  /// Send OTP to phone number
  Future<AuthResponse> sendOTP(String phone, {String countryCode = '+91', bool termsAccepted = true, bool forRegistration = false}) async {
    try {
      print('📞 Sending OTP to: $countryCode$phone (forRegistration: $forRegistration)');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/send-otp'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'phone': phone,
          'countryCode': countryCode,
          'termsAccepted': termsAccepted,
          'forRegistration': forRegistration,
        }),
      );

      print('📥 Response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ OTP sent successfully');
        
        // Backend returns {message: "...", results: [...]} without success field
        // Create proper AuthResponse with success=true
        return AuthResponse(
          success: true,
          message: data['message'] as String? ?? 'OTP sent successfully',
        );
      } else {
        final errorData = _handleError(response);
        return AuthResponse(
          success: false,
          error: errorData['error'] as String,
        );
      }
    } catch (e) {
      print('❌ Send OTP error: $e');
      return AuthResponse(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  /// Verify OTP and login
  Future<AuthResponse> verifyOTP(
    String phone,
    String otp, {
    Map<String, dynamic>? deviceInfo,
    bool termsAccepted = true,
  }) async {
    try {
      print('🔐 Verifying OTP for: $phone');
      
      final body = <String, dynamic>{
        'phone': phone,
        'otp': otp,
      };
      
      if (deviceInfo != null) {
        body['deviceInfo'] = deviceInfo;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/verify-otp'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      print('📥 Response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ OTP verified successfully');
        print('📦 Response data keys: ${data.keys.toList()}');
        print('🔑 Token present: ${data.containsKey('token')}');
        print('👤 User present: ${data.containsKey('user')}');
        
        // Save token and user data
        if (data['token'] != null) {
          print('💾 Saving token: ${data['token'].toString().substring(0, 20)}...');
          await _storage.saveToken(data['token']);
          print('✅ Token saved');
        } else {
          print('❌ WARNING: No token in response! Keys: ${data.keys.toList()}');
        }
        if (data['user'] != null) {
          print('💾 Saving user: ${data['user']['name']}');
          await _storage.saveUser(User.fromJson(data['user']));
          print('✅ User saved');
        } else {
          print('❌ WARNING: No user in response!');
        }
        
        return AuthResponse.fromJson(data);
      } else {
        final errorData = _handleError(response);
        return AuthResponse(
          success: false,
          error: errorData['error'] as String,
        );
      }
    } catch (e) {
      print('❌ Verify OTP error: $e');
      return AuthResponse(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  /// Register new user
  Future<AuthResponse> register({
    required String phone,
    required String otp,
    required String name,
    String? email,
    int? age,
    String? gender,
    bool termsAccepted = true,
  }) async {
    try {
      print('📝 Registering user: $name');
      
      final body = <String, dynamic>{
        'phone': phone,
        'otp': otp,
        'name': name,
        'password': '123456', // Default password
      };
      
      if (email != null) body['email'] = email;
      if (age != null) body['age'] = age;
      if (gender != null) body['gender'] = gender;

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      print('📥 Response: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ Registration successful');
        
        // Save token and user data
        if (data['token'] != null) {
          await _storage.saveToken(data['token']);
        }
        if (data['user'] != null) {
          await _storage.saveUser(User.fromJson(data['user']));
        }
        
        return AuthResponse.fromJson(data);
      } else {
        final errorData = _handleError(response);
        return AuthResponse(
          success: false,
          error: errorData['error'] as String,
        );
      }
    } catch (e) {
      print('❌ Registration error: $e');
      return AuthResponse(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  /// Get user profile
  Future<AuthResponse> getUserProfile() async {
    try {
      print('👤 Fetching user profile');
      
      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: await _getHeaders(includeAuth: true),
      );

      print('📥 Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Profile fetched successfully');
        
        // Update local user data
        if (data['user'] != null) {
          await _storage.saveUser(User.fromJson(data['user']));
        }
        
        return AuthResponse.fromJson(data);
      } else {
        final errorData = _handleError(response);
        return AuthResponse(
          success: false,
          error: errorData['error'] as String,
        );
      }
    } catch (e) {
      print('❌ Get profile error: $e');
      return AuthResponse(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  /// Logout user
  Future<bool> logout() async {
    try {
      print('🚪 Logging out');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/logout'),
        headers: await _getHeaders(includeAuth: true),
      );

      print('📥 Response: ${response.statusCode}');
      
      // Clear local data regardless of API response
      await _storage.clearAuth();
      
      if (response.statusCode == 200) {
        print('✅ Logout successful');
        return true;
      } else {
        print('⚠️ Logout API failed, but local data cleared');
        return true;
      }
    } catch (e) {
      print('❌ Logout error: $e');
      // Still clear local data
      await _storage.clearAuth();
      return true;
    }
  }

  // ============================================================
  // HC20 DEVICE ENDPOINTS
  // ============================================================

  /// Associate HC20 device with user
  Future<Map<String, dynamic>> associateDevice(
    String deviceId,
    String userId, {
    String? deviceName,
  }) async {
    try {
      print('🔗 Associating device: $deviceId with user: $userId');
      
      final body = {
        'userId': userId,
        'deviceType': 'HC20',
      };
      
      if (deviceName != null) {
        body['deviceName'] = deviceName;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/api/hc20-data/$deviceId/user'),
        headers: await _getHeaders(includeAuth: true),
        body: jsonEncode(body),
      );

      print('📥 Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Device associated successfully');
        print('   Updated records: ${data['updatedRecords']}');
        
        // Save device info locally
        await _storage.saveDeviceId(deviceId);
        if (deviceName != null) {
          await _storage.saveDeviceName(deviceName);
        }
        
        return data;
      } else {
        return _handleError(response);
      }
    } catch (e) {
      print('❌ Associate device error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Get user's HC20 data
  Future<HC20DataResponse> getHC20Data({
    bool latest = true,
    int limit = 100,
    int page = 1,
    String? startDate,
    String? endDate,
  }) async {
    try {
      print('📊 Fetching HC20 data (latest: $latest, limit: $limit)');
      
      // Build query parameters
      final queryParams = <String, String>{
        'latest': latest.toString(),
        'limit': limit.toString(),
        'page': page.toString(),
      };
      
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      
      final uri = Uri.parse('$baseUrl/api/hc20-data').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(includeAuth: true),
      );

      print('📥 Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ HC20 data fetched: ${data['count']} records');
        return HC20DataResponse.fromJson(data);
      } else {
        final errorData = _handleError(response);
        return HC20DataResponse(
          success: false,
          data: [],
          count: 0,
          error: errorData['error'] as String,
        );
      }
    } catch (e) {
      print('❌ Get HC20 data error: $e');
      return HC20DataResponse(
        success: false,
        data: [],
        count: 0,
        error: 'Network error: $e',
      );
    }
  }

  /// Get device-specific data
  Future<HC20DataResponse> getDeviceData(
    String deviceId, {
    int limit = 50,
    int page = 1,
    String? startDate,
    String? endDate,
  }) async {
    try {
      print('📊 Fetching data for device: $deviceId');
      
      // Build query parameters
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'page': page.toString(),
      };
      
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      
      final uri = Uri.parse('$baseUrl/api/hc20-data/$deviceId').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(includeAuth: true),
      );

      print('📥 Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Device data fetched: ${data['data']?.length ?? 0} records');
        return HC20DataResponse.fromJson(data);
      } else {
        final errorData = _handleError(response);
        return HC20DataResponse(
          success: false,
          data: [],
          count: 0,
          error: errorData['error'] as String,
        );
      }
    } catch (e) {
      print('❌ Get device data error: $e');
      return HC20DataResponse(
        success: false,
        data: [],
        count: 0,
        error: 'Network error: $e',
      );
    }
  }

  // ============================================================
  // NOTIFICATION ENDPOINTS
  // ============================================================

  /// Send device disconnect notification via WhatsApp
  Future<Map<String, dynamic>> sendDisconnectNotification({
    required String phone,
    required String deviceId,
    String? deviceName,
  }) async {
    try {
      print('📱 Sending disconnect notification to: $phone');
      print('   Device: $deviceId ($deviceName)');
      
      final body = {
        'phone': phone,
        'deviceId': deviceId,
        'deviceName': deviceName ?? 'HC20 Device',
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/device-disconnect'),
        headers: await _getHeaders(includeAuth: true),
        body: jsonEncode(body),
      );

      print('📥 Response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ Notification sent successfully');
        return {
          'success': true,
          'message': data['message'] ?? 'Notification sent',
          'messageId': data['messageId'],
        };
      } else {
        return _handleError(response);
      }
    } catch (e) {
      print('❌ Send notification error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}
