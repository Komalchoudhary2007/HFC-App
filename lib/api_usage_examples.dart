// ============================================================
// HFC APP - API SERVICE USAGE EXAMPLES
// ============================================================
// This file shows how to use the API service in your Flutter code
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';

// ============================================================
// 1. AUTHENTICATION EXAMPLES
// ============================================================

// Example 1: Send OTP to phone number
Future<void> exampleSendOTP(BuildContext context) async {
  final authService = Provider.of<AuthService>(context, listen: false);
  
  final response = await authService.sendOTP('9876543210');
  
  if (response.success) {
    print('✅ OTP sent successfully!');
    print('OTP ID: ${response.otpId}');
  } else {
    print('❌ Failed: ${response.error}');
  }
}

// Example 2: Verify OTP and login
Future<void> exampleVerifyOTP(BuildContext context) async {
  final authService = Provider.of<AuthService>(context, listen: false);
  
  final response = await authService.verifyOTP('9876543210', '123456');
  
  if (response.success) {
    print('✅ Login successful!');
    print('User: ${response.user?.name}');
    print('Token: ${response.token}');
    // Navigation happens automatically via Provider
  } else {
    print('❌ Login failed: ${response.error}');
  }
}

// Example 3: Register new user
Future<void> exampleRegister(BuildContext context) async {
  final authService = Provider.of<AuthService>(context, listen: false);
  
  final response = await authService.register(
    phone: '9876543210',
    otp: '123456',
    name: 'John Doe',
    email: 'john@example.com',
    age: 25,
    gender: 'Male',
  );
  
  if (response.success) {
    print('✅ Registration successful!');
    print('User ID: ${response.user?.id}');
  } else {
    print('❌ Registration failed: ${response.error}');
  }
}

// Example 4: Get current user
void exampleGetCurrentUser(BuildContext context) {
  final authService = Provider.of<AuthService>(context, listen: false);
  final user = authService.currentUser;
  
  if (user != null) {
    print('Current user: ${user.name}');
    print('Phone: ${user.phone}');
    print('Email: ${user.email}');
    print('User ID: ${user.id}');
  } else {
    print('No user logged in');
  }
}

// Example 5: Refresh user profile
Future<void> exampleRefreshProfile(BuildContext context) async {
  final authService = Provider.of<AuthService>(context, listen: false);
  
  await authService.refreshProfile();
  
  print('✅ Profile refreshed!');
  print('Updated user: ${authService.currentUser?.name}');
}

// Example 6: Logout user
Future<void> exampleLogout(BuildContext context) async {
  final authService = Provider.of<AuthService>(context, listen: false);
  
  await authService.logout();
  
  print('✅ Logged out successfully!');
  // App will automatically navigate to login page
}

// ============================================================
// 2. HC20 DEVICE MANAGEMENT EXAMPLES
// ============================================================

// Example 7: Associate device with user
Future<void> exampleAssociateDevice(BuildContext context) async {
  final apiService = ApiService();
  final authService = Provider.of<AuthService>(context, listen: false);
  final user = authService.currentUser;
  
  if (user == null) {
    print('❌ No user logged in');
    return;
  }
  
  final response = await apiService.associateDevice(
    'B20_50C0F00132F8', // Device ID
    user.id,            // User ID
    deviceName: 'My HC20 Watch',
  );
  
  if (response['success'] == true) {
    print('✅ Device associated!');
    print('Updated ${response['updatedRecords']} records');
  } else {
    print('❌ Association failed: ${response['error']}');
  }
}

// Example 8: Get user's HC20 data
Future<void> exampleGetHealthData(BuildContext context) async {
  final apiService = ApiService();
  
  final response = await apiService.getHC20Data(
    latest: true,
    limit: 10,
  );
  
  if (response.success) {
    print('✅ Got ${response.count} health records');
    
    for (final record in response.data) {
      print('Record ID: ${record.id}');
      print('Heart Rate: ${record.heartRate}');
      print('SpO2: ${record.spO2}');
      print('Blood Pressure: ${record.systolic}/${record.diastolic}');
      print('Steps: ${record.steps}');
      print('---');
    }
  } else {
    print('❌ Failed to get data: ${response.error}');
  }
}

// Example 9: Get device-specific data with date range
Future<void> exampleGetDeviceData(BuildContext context) async {
  final apiService = ApiService();
  
  final response = await apiService.getDeviceData(
    'B20_50C0F00132F8',
    limit: 50,
    startDate: '2026-01-01',
    endDate: '2026-01-05',
  );
  
  if (response.success) {
    print('✅ Got ${response.data.length} records');
    print('Total records: ${response.pagination?.total}');
    print('Pages: ${response.pagination?.totalPages}');
  } else {
    print('❌ Failed: ${response.error}');
  }
}

// ============================================================
// 3. AUTHENTICATION STATE LISTENING
// ============================================================

// Example 10: Listen to auth state changes in UI
class ExampleAuthWidget extends StatelessWidget {
  const ExampleAuthWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (authService.isLoading) {
          return const CircularProgressIndicator();
        }
        
        if (authService.isAuthenticated) {
          final user = authService.currentUser!;
          return Column(
            children: [
              Text('Welcome, ${user.name}!'),
              Text('Phone: ${user.phone}'),
              ElevatedButton(
                onPressed: () => authService.logout(),
                child: const Text('Logout'),
              ),
            ],
          );
        } else {
          return const Text('Please login');
        }
      },
    );
  }
}

// ============================================================
// 4. ERROR HANDLING EXAMPLES
// ============================================================

// Example 11: Comprehensive error handling
Future<void> exampleWithErrorHandling(BuildContext context) async {
  final authService = Provider.of<AuthService>(context, listen: false);
  
  try {
    final response = await authService.verifyOTP('9876543210', '123456');
    
    if (response.success) {
      // Success
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Login successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // API returned error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${response.error ?? "Login failed"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    // Network or unexpected error
    print('❌ Unexpected error: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Network error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ============================================================
// 5. STORAGE EXAMPLES
// ============================================================

// Example 12: Direct storage access (not recommended - use AuthService)
Future<void> exampleDirectStorage() async {
  final storage = StorageService();
  
  // Check if logged in
  final isLoggedIn = await storage.isLoggedIn();
  print('Logged in: $isLoggedIn');
  
  // Get stored token
  final token = await storage.getToken();
  print('Token: $token');
  
  // Get stored user
  final user = await storage.getUser();
  print('User: ${user?.name}');
  
  // Get device info
  final deviceId = await storage.getDeviceId();
  final deviceName = await storage.getDeviceName();
  print('Device: $deviceName ($deviceId)');
}

// ============================================================
// 6. COMPLETE LOGIN FLOW EXAMPLE
// ============================================================

class ExampleLoginFlow extends StatefulWidget {
  const ExampleLoginFlow({super.key});

  @override
  State<ExampleLoginFlow> createState() => _ExampleLoginFlowState();
}

class _ExampleLoginFlowState extends State<ExampleLoginFlow> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Phone input
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            
            // OTP input (shown after OTP sent)
            if (_otpSent)
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(labelText: 'OTP'),
                keyboardType: TextInputType.number,
              ),
            
            const SizedBox(height: 16),
            
            // Send OTP / Verify button
            ElevatedButton(
              onPressed: _otpSent ? _verifyOTP : _sendOTP,
              child: Text(_otpSent ? 'Verify OTP' : 'Send OTP'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendOTP() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final phone = _phoneController.text;
    
    final response = await authService.sendOTP(phone);
    
    if (response.success) {
      setState(() => _otpSent = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.error}')),
        );
      }
    }
  }

  Future<void> _verifyOTP() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final phone = _phoneController.text;
    final otp = _otpController.text;
    
    final response = await authService.verifyOTP(phone, otp);
    
    if (response.success) {
      // Navigation handled automatically by Provider
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome, ${response.user?.name}!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.error}')),
        );
      }
    }
  }
}

// ============================================================
// 7. TEST MODE EXAMPLES
// ============================================================

// Example 13: Testing with test credentials
Future<void> exampleTestLogin(BuildContext context) async {
  final authService = Provider.of<AuthService>(context, listen: false);
  
  // Use test credentials
  const testPhone = '9999999999';
  const testOTP = '123456';
  
  // Send OTP
  await authService.sendOTP(testPhone);
  
  // Verify with test OTP
  final response = await authService.verifyOTP(testPhone, testOTP);
  
  if (response.success) {
    print('✅ Test login successful!');
  }
}

// ============================================================
// 8. CUSTOM API CALLS
// ============================================================

// Example 14: Make custom API call with authentication
Future<void> exampleCustomApiCall() async {
  final apiService = ApiService();
  // Access the HTTP client via dio or http package
  // Token is automatically included in headers
}

// ============================================================
// END OF EXAMPLES
// ============================================================
