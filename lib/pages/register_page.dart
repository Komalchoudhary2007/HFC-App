import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _selectedGender;
  bool _acceptedTerms = false;
  String _selectedCountryCode = '+91';
  bool _showRegistrationFields = false;
  
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
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    // First time: validate phone number only
    if (!_showRegistrationFields) {
      if (_phoneController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please enter phone number';
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
          // Check if error is "User not found" - show registration fields
          if (response.error?.contains('User not found') == true || 
              response.error?.contains('not found') == true) {
            _showRegistrationFields = true;
            _errorMessage = null;
            _successMessage = 'Please provide your details to register';
          } else {
            _errorMessage = response.error ?? 'Failed to send OTP';
          }
        }
      });
    } else {
      // Second time: validate name and email, then send OTP for registration
      if (_nameController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please enter your name';
        });
        return;
      }
      if (_emailController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please enter your email';
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

      // Send OTP with forRegistration flag
      final response = await authService.sendOTP(phone, countryCode: _selectedCountryCode, termsAccepted: _acceptedTerms, forRegistration: true);

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
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      setState(() {
        _errorMessage = 'Please accept Terms & Conditions to register';
      });
      return;
    }

    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    
    final authService = Provider.of<AuthService>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final response = await authService.register(
      phone: phone,
      otp: otp,
      name: name,
      email: email.isEmpty ? null : email,
      termsAccepted: _acceptedTerms,
    );

    setState(() {
      _isLoading = false;
    });

    if (response.success) {
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${response.user?.name ?? "User"}!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back to allow main.dart to handle the authenticated state
        Navigator.of(context).pop();
      }
    } else {
      setState(() {
        _errorMessage = response.error ?? 'Registration failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                Text(
                  'Create Account',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Register to connect your HC20 device',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Phone Number with Country Code
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
                          labelText: 'Phone Number *',
                          hintText: '9876543210',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (value.length < 6 || value.length > 15) {
                            return 'Invalid number';
                          }
                          if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                            return 'Only digits';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Terms & Conditions Checkbox (always visible)
                Row(
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _acceptedTerms = value ?? false;
                                if (_acceptedTerms) {
                                  _errorMessage = null; // Clear error when checked
                                }
                              });
                            },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showTermsDialog(),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            children: [
                              const TextSpan(text: 'I accept the '),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ' *'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Name and Email fields (shown after User not found)
                if (_showRegistrationFields && !_otpSent) ...[
                  // Name
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'John Doe',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.length < 2) {
                        return 'Name too short';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      hintText: 'john@example.com',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Invalid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                
                // OTP Input (shown after OTP sent)
                if (_otpSent) ...[
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    enabled: !_isLoading,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Enter OTP *',
                      hintText: '123456',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.length != 6) {
                        return 'Must be 6 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Name
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'John Doe',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.length < 2) {
                        return 'Name too short';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Email (optional)
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: 'Email (Optional)',
                      hintText: 'john@example.com',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Invalid email';
                        }
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
                
                // Action Button
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_otpSent ? _register : _sendOTP),
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
                          _otpSent 
                            ? 'Register' 
                            : (_showRegistrationFields ? 'Send OTP' : 'Check Number'),
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
                                  _showRegistrationFields = false;
                                  _otpController.clear();
                                  _nameController.clear();
                                  _emailController.clear();
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
                
                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Login',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
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
                'By registering and using the HFC App and HC20 device, you agree to these terms and conditions.\n\n'
                '2. Account Registration\n'
                'You must provide accurate information during registration. You are responsible for maintaining account security.\n\n'
                '3. Data Collection\n'
                'The app collects health data from your HC20 wearable device including heart rate, blood pressure, SpO2, temperature, steps, and sleep data.\n\n'
                '4. Data Usage\n'
                'Your health data is stored securely and used only for health monitoring purposes. Data is linked to your user account.\n\n'
                '5. Privacy Policy\n'
                'We respect your privacy. Your data is encrypted and only accessible to you and authorized healthcare providers. We will never share your data without consent.\n\n'
                '6. Device Association\n'
                'By connecting your HC20 device, you authorize the app to collect and store health data from the device.\n\n'
                '7. Account Security\n'
                'You are responsible for maintaining the confidentiality of your account credentials. Notify us immediately of any unauthorized access.\n\n'
                '8. Medical Disclaimer\n'
                'This app is for informational purposes only and should not replace professional medical advice, diagnosis, or treatment.\n\n'
                '9. Age Requirement\n'
                'You must be at least 18 years old to register and use this service.\n\n'
                '10. Changes to Terms\n'
                'We reserve the right to modify these terms at any time. Continued use constitutes acceptance of modified terms.\n\n'
                '11. Termination\n'
                'We reserve the right to terminate accounts that violate these terms.\n\n'
                '12. Contact\n'
                'For questions about these terms, please contact support@hireforcare.com',
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
  }
}
