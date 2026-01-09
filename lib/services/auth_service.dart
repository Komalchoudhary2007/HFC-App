import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storage = StorageService();

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthService() {
    _checkAuthStatus();
  }

  /// Check if user is already authenticated
  Future<void> _checkAuthStatus() async {
    try {
      _setLoading(true);
      
      final isLoggedIn = await _storage.isLoggedIn();
      if (isLoggedIn) {
        final user = await _storage.getUser();
        if (user != null) {
          _currentUser = user;
          _isAuthenticated = true;
        }
      }
    } catch (e) {
      _isAuthenticated = false;
    } finally {
      _setLoading(false);
    }
  }

  /// Send OTP to phone number
  Future<AuthResponse> sendOTP(String phone, {String countryCode = '+91', bool termsAccepted = true, bool forRegistration = false}) async {
    try {
      _setLoading(true);
      _clearError();
      
      final response = await _apiService.sendOTP(phone, countryCode: countryCode, termsAccepted: termsAccepted, forRegistration: forRegistration);
      
      if (!response.success) {
        _setError(response.error ?? 'Failed to send OTP');
      }
      
      return response;
    } catch (e) {
      _setError('Network error: $e');
      return AuthResponse(success: false, error: e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Verify OTP and login
  Future<AuthResponse> verifyOTP(String phone, String otp, {bool termsAccepted = true}) async {
    try {
      _setLoading(true);
      _clearError();
      
      final response = await _apiService.verifyOTP(phone, otp, termsAccepted: termsAccepted);
      
      if (response.success && response.user != null) {
        _currentUser = response.user;
        _isAuthenticated = true;
        print('✅ Login successful: ${response.user!.name}');
        notifyListeners();
      } else {
        _setError(response.error ?? 'Login failed');
      }
      
      return response;
    } catch (e) {
      _setError('Network error: $e');
      return AuthResponse(success: false, error: e.toString());
    } finally {
      _setLoading(false);
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
      _setLoading(true);
      _clearError();
      
      final response = await _apiService.register(
        phone: phone,
        otp: otp,
        name: name,
        email: email,
        age: age,
        gender: gender,
        termsAccepted: termsAccepted,
      );
      
      if (response.success && response.user != null) {
        _currentUser = response.user;
        _isAuthenticated = true;
        print('✅ Registration successful: ${response.user!.name}');
        notifyListeners();
      } else {
        _setError(response.error ?? 'Registration failed');
      }
      
      return response;
    } catch (e) {
      _setError('Network error: $e');
      return AuthResponse(success: false, error: e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh user profile
  Future<void> refreshProfile() async {
    try {
      _setLoading(true);
      
      final response = await _apiService.getUserProfile();
      
      if (response.success && response.user != null) {
        _currentUser = response.user;
        notifyListeners();
      }
    } catch (e) {
      print('❌ Refresh profile error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      _setLoading(true);
      
      await _apiService.logout();
      
      _currentUser = null;
      _isAuthenticated = false;
      _clearError();
      
      print('✅ Logged out successfully');
      notifyListeners();
    } catch (e) {
      print('❌ Logout error: $e');
      // Still clear local state
      _currentUser = null;
      _isAuthenticated = false;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
