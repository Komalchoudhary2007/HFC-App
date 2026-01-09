import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Secure storage for sensitive data
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Keys for storage
  static const String _keyAuthToken = 'auth_token';
  static const String _keyUser = 'user_data';
  static const String _keyDeviceId = 'device_id';
  static const String _keyDeviceName = 'device_name';

  // Save authentication token
  Future<void> saveToken(String token) async {
    print('💾 Saving token: ${token.length} chars');
    // Save to BOTH secure storage AND SharedPreferences as backup
    try {
      await _secureStorage.write(key: _keyAuthToken, value: token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backup_$_keyAuthToken', token);
      
      // Verify save
      final verify = await _secureStorage.read(key: _keyAuthToken);
      if (verify == null) {
        throw Exception('Failed to save token to secure storage');
      }
      print('✅ Token saved to both secure storage and SharedPreferences');
    } catch (e) {
      // If secure storage fails, at least save to SharedPreferences
      print('⚠️ Secure storage failed, using SharedPreferences backup: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backup_$_keyAuthToken', token);
      print('✅ Token saved to SharedPreferences backup');
    }
  }

  // Get authentication token
  Future<String?> getToken() async {
    try {
      // Try secure storage first
      final token = await _secureStorage.read(key: _keyAuthToken);
      if (token != null) {
        print('🔑 Token retrieved from secure storage: ${token.length} chars');
        return token;
      }
      
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final backupToken = prefs.getString('backup_$_keyAuthToken');
      if (backupToken != null) {
        print('🔑 Token retrieved from SharedPreferences backup: ${backupToken.length} chars');
        return backupToken;
      }
      
      print('❌ No token found in either storage');
      return null;
    } catch (e) {
      // If secure storage fails, try SharedPreferences
      print('⚠️ Secure storage read failed, trying backup: $e');
      final prefs = await SharedPreferences.getInstance();
      final backupToken = prefs.getString('backup_$_keyAuthToken');
      if (backupToken != null) {
        print('🔑 Token retrieved from SharedPreferences backup: ${backupToken.length} chars');
      } else {
        print('❌ No token in backup either');
      }
      return backupToken;
    }
  }

  // Save user data
  Future<void> saveUser(User user) async {
    final userJson = jsonEncode(user.toJson());
    try {
      // Save to both secure storage AND SharedPreferences
      await _secureStorage.write(key: _keyUser, value: userJson);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backup_$_keyUser', userJson);
      print('✅ User data saved: ${user.name}');
    } catch (e) {
      // Fallback to SharedPreferences only
      print('⚠️ Secure storage failed, using SharedPreferences: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backup_$_keyUser', userJson);
    }
  }

  // Get user data
  Future<User?> getUser() async {
    try {
      // Try secure storage first
      final userJson = await _secureStorage.read(key: _keyUser);
      if (userJson != null) {
        return User.fromJson(jsonDecode(userJson));
      }
      
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final backupJson = prefs.getString('backup_$_keyUser');
      if (backupJson != null) {
        return User.fromJson(jsonDecode(backupJson));
      }
    } catch (e) {
      print('❌ Error reading user data: $e');
      // Try SharedPreferences backup
      try {
        final prefs = await SharedPreferences.getInstance();
        final backupJson = prefs.getString('backup_$_keyUser');
        if (backupJson != null) {
          return User.fromJson(jsonDecode(backupJson));
        }
      } catch (e2) {
        print('❌ Backup also failed: $e2');
      }
    }
    return null;
  }

  // Save device ID
  // Save device name
  Future<void> saveDeviceName(String deviceName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceName, deviceName);
  }
  // Get device name
  Future<String?> getDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceName);
  }


  // Save HC20 device ID for auto-reconnect
  Future<void> saveDeviceId(String deviceId) async {
    try {
      // Save to both secure storage AND SharedPreferences
      await _secureStorage.write(key: _keyDeviceId, value: deviceId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backup_$_keyDeviceId', deviceId);
      print('💾 Device ID saved for auto-reconnect: $deviceId');
    } catch (e) {
      print('⚠️ Error saving device ID: $e');
      // Fallback to SharedPreferences only
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backup_$_keyDeviceId', deviceId);
    }
  }

  // Get saved HC20 device ID
  Future<String?> getSavedDeviceId() async {
    try {
      // Try secure storage first
      final deviceId = await _secureStorage.read(key: _keyDeviceId);
      if (deviceId != null) {
        return deviceId;
      }
      
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('backup_$_keyDeviceId');
    } catch (e) {
      print('⚠️ Error reading device ID: $e');
      // Try SharedPreferences backup
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('backup_$_keyDeviceId');
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Clear all authentication data (logout)
  Future<void> clearAuth() async {
    await _secureStorage.delete(key: _keyAuthToken);
    await _secureStorage.delete(key: _keyUser);
    
    // Also clear backups
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('backup_$_keyAuthToken');
    await prefs.remove('backup_$_keyUser');
    
    print('✅ Authentication data cleared');
  }

  // Clear all data including device info
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    print('✅ All data cleared');
  }
}
