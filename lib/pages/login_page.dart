import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _acceptedTerms = false;
  String _selectedCountryCode = '+91';
  
  // Popular country codes
  final List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'name': '🇮🇳 India'},
    {'code': '+1', 'name': '🇺🇸 USA/Canada'},
    {'code': '+44', 'name': '🇬🇧 UK'},
    {'code': '+971', 'name': '🇦🇪 UAE'},
    {'code': '+61', 'name': '🇦🇺 Australia'},
    {'code': '+65', 'name': '🇸🇬 Singapore'},
    {'code': '+60', 'name': '🇲🇾 Malaysia'},
    {'code': '+94', 'name': '🇱🇰 Sri Lanka'},
    {'code': '+92', 'name': '🇵🇰 Pakistan'},
    {'code': '+880', 'name': '🇧🇩 Bangladesh'},
    {'code': '+977', 'name': '🇳🇵 Nepal'},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      setState(() {
        _errorMessage = 'Please accept Terms & Conditions to continue';
      });
      return;
    }

    final phone = _phoneController.text.trim();
    final authService = Provider.of<AuthService>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final response = await authService.sendOTP(phone, countryCode: _selectedCountryCode, termsAccepted: _acceptedTerms);

    setState(() {
      _isLoading = false;
      if (response.success) {
        _otpSent = true;
        _successMessage = 'OTP sent to your phone number';
      } else {
        _errorMessage = response.error ?? 'Failed to send OTP';
      }
    });
  }

  Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    final authService = Provider.of<AuthService>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final response = await authService.verifyOTP(phone, otp, termsAccepted: _acceptedTerms);

    setState(() {
      _isLoading = false;
    });

    if (response.success) {
      // Check if token was saved
      final storage = StorageService();
      final savedToken = await storage.getToken();
      
      // Navigation handled by main.dart's auth listener
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, ${response.user?.name ?? "User"}!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Show debug info if no token was saved
        if (savedToken == null || savedToken.isEmpty) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('⚠️ Debug: Token Not Saved'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Login was successful but token was not saved.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        const Text('Backend Response:'),
                        const SizedBox(height: 8),
                        Text(
                          'Token in response: ${response.token != null ? "YES" : "NO"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (response.token != null)
                          Text(
                            'Token value: ${response.token!.substring(0, min(30, response.token!.length))}...',
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          'This means the backend API did not return an authentication token.',
                          style: TextStyle(fontSize: 11, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          });
        }
      }
    } else {
      setState(() {
        _errorMessage = response.error ?? 'Invalid OTP';
      });
    }
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                
                // App Logo/Title
                Icon(
                  Icons.watch,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'HFC App',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'HC20 Wearable Health Tracker',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Phone Number Input with Country Code
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Country Code Dropdown
                    Container(
                      width: 120,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCountryCode,
                        decoration: InputDecoration(
                          labelText: 'Code',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                        isExpanded: true,
                        items: _countryCodes.map((country) {
                          return DropdownMenuItem<String>(
                            value: country['code'],
                            child: Text(
                              country['code']!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: !_otpSent && !_isLoading
                            ? (value) {
                                setState(() {
                                  _selectedCountryCode = value!;
                                });
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Phone Number Field
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        enabled: !_otpSent && !_isLoading,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '9876543210',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter phone number';
                          }
                          if (value.length < 6 || value.length > 15) {
                            return 'Invalid phone number';
                          }
                          if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                            return 'Only digits allowed';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // OTP Input (shown after OTP sent)
                if (_otpSent) ...[
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    enabled: !_isLoading,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Enter OTP',
                      hintText: '123456',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter OTP';
                      }
                      if (value.length != 6) {
                        return 'OTP must be 6 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Success Message
                if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Terms & Conditions Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      onChanged: (value) {
                        setState(() {
                          _acceptedTerms = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showTermsDialog,
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87),
                            children: [
                              const TextSpan(text: 'I accept the '),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Action Button
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_otpSent ? _verifyOTP : _sendOTP),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _otpSent ? 'Verify OTP & Login' : 'Send OTP',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                
                const SizedBox(height: 16),
                
                // Resend OTP / Change Number
                if (_otpSent) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _otpSent = false;
                                  _otpController.clear();
                                  _errorMessage = null;
                                  _successMessage = null;
                                });
                              },
                        child: const Text('Change Number'),
                      ),
                      const Text(' | '),
                      TextButton(
                        onPressed: _isLoading ? null : _sendOTP,
                        child: const Text('Resend OTP'),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: _goToRegister,
                      child: const Text(
                        'Register',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Test Credentials Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Test Credentials',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Phone: 9999999999\nOTP: 123456',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'HFC App - Terms of Service',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '1. Acceptance of Terms\n'
                'By using the HFC App and HC20 device, you agree to these terms and conditions.\n\n'
                '2. Data Collection\n'
                'The app collects health data from your HC20 wearable device including heart rate, blood pressure, SpO2, temperature, steps, and sleep data.\n\n'
                '3. Data Usage\n'
                'Your health data is stored securely and used only for health monitoring purposes. Data is linked to your user account.\n\n'
                '4. Privacy\n'
                'We respect your privacy. Your data is encrypted and only accessible to you and authorized healthcare providers.\n\n'
                '5. Device Association\n'
                'By connecting your HC20 device, you authorize the app to collect and store health data from the device.\n\n'
                '6. Account Security\n'
                'You are responsible for maintaining the confidentiality of your account credentials.\n\n'
                '7. Medical Disclaimer\n'
                'This app is for informational purposes only and should not replace professional medical advice.\n\n'
                '8. Changes to Terms\n'
                'We reserve the right to modify these terms at any time. Continued use constitutes acceptance of modified terms.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _acceptedTerms = true;
              });
              Navigator.pop(context);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }}
