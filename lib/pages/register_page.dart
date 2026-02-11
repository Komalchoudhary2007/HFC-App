import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
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
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Brand colors
  static const Color _primaryPurple = Color(0xFF532A7B);
  static const Color _lightPurple = Color(0xFFE7E2FD);
  static const Color _accentPurple = Color(0xFF7B4397);
  
  // Popular country codes
  final List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'name': '🇮🇳 India'},
    {'code': '+1', 'name': '🇺🇸 USA/Canada'},
    {'code': '+44', 'name': '🇬🇧 UK'},
    {'code': '+971', 'name': '🇦🇪 UAE'},
    {'code': '+61', 'name': '🇦🇺 Australia'},
    {'code': '+65', 'name': '🇸🇬 Singapore'},
    {'code': '+66', 'name': '🇹🇭 Thailand'},
    {'code': '+60', 'name': '🇲🇾 Malaysia'},
    {'code': '+94', 'name': '🇱🇰 Sri Lanka'},
    {'code': '+92', 'name': '🇵🇰 Pakistan'},
    {'code': '+880', 'name': '🇧🇩 Bangladesh'},
    {'code': '+977', 'name': '🇳🇵 Nepal'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _animationController.dispose();
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
          _successMessage = 'OTP sent to your WhatsApp number';
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
          _successMessage = 'OTP sent to your WhatsApp number';
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _primaryPurple,
              _accentPurple,
              _lightPurple.withOpacity(0.3),
              Colors.white,
            ],
            stops: const [0.0, 0.2, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              _buildAppBar(),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildRegisterCard(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            ),
          ),
          const Expanded(
            child: Text(
              'Create Account',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRegisterCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryPurple.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Icon
            Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_lightPurple, _lightPurple.withOpacity(0.5)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 35,
                  color: _primaryPurple,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Join HFC Family',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start monitoring your health journey',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            
            // Progress Indicator
            _buildProgressIndicator(),
            const SizedBox(height: 24),
            
            // Step 1: Phone Number
            _buildSectionTitle(
              icon: Icons.phone_android,
              title: 'Phone Number',
              subtitle: 'Enter your WhatsApp number',
            ),
            const SizedBox(height: 12),
            _buildPhoneInput(),
            
            const SizedBox(height: 16),
            
            // Terms Checkbox
            _buildTermsCheckbox(),
            
            const SizedBox(height: 16),
            
            // Step 2: Registration Fields (shown after User not found)
            if (_showRegistrationFields && !_otpSent) ...[
              _buildSectionTitle(
                icon: Icons.person_outline,
                title: 'Personal Details',
                subtitle: 'Tell us about yourself',
              ),
              const SizedBox(height: 12),
              _buildNameInput(),
              const SizedBox(height: 12),
              _buildEmailInput(required: true),
              const SizedBox(height: 16),
            ],
            
            // Step 3: OTP and Registration Fields
            if (_otpSent) ...[
              _buildSectionTitle(
                icon: Icons.lock_outline,
                title: 'Verification',
                subtitle: 'Enter the code sent to WhatsApp',
              ),
              const SizedBox(height: 12),
              _buildOtpInput(),
              const SizedBox(height: 16),
              
              _buildSectionTitle(
                icon: Icons.badge_outlined,
                title: 'Your Profile',
                subtitle: 'Complete your registration',
              ),
              const SizedBox(height: 12),
              _buildNameInput(),
              const SizedBox(height: 12),
              _buildEmailInput(required: false),
              const SizedBox(height: 16),
            ],
            
            // Messages
            if (_successMessage != null) _buildSuccessMessage(),
            if (_errorMessage != null) _buildErrorMessage(),
            
            const SizedBox(height: 8),
            
            // Action Button
            _buildActionButton(),
            
            // Resend/Change
            if (_otpSent) _buildResendSection(),
            
            const SizedBox(height: 20),
            
            // Login Link
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProgressIndicator() {
    int currentStep = 1;
    if (_showRegistrationFields && !_otpSent) currentStep = 2;
    if (_otpSent) currentStep = 3;
    
    return Row(
      children: [
        _buildProgressStep(1, 'Phone', currentStep >= 1),
        _buildProgressLine(currentStep >= 2),
        _buildProgressStep(2, 'Details', currentStep >= 2),
        _buildProgressLine(currentStep >= 3),
        _buildProgressStep(3, 'Verify', currentStep >= 3),
      ],
    );
  }
  
  Widget _buildProgressStep(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? _primaryPurple : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? _primaryPurple : Colors.grey[500],
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
  
  Widget _buildProgressLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isActive ? _primaryPurple : Colors.grey[200],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _lightPurple,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primaryPurple, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPhoneInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[200]!)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCountryCode,
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600], size: 20),
                items: _countryCodes.map((country) {
                  return DropdownMenuItem<String>(
                    value: country['code'],
                    child: Text(country['code']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  );
                }).toList(),
                onChanged: !_otpSent && !_isLoading
                    ? (value) => setState(() => _selectedCountryCode = value!)
                    : null,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              enabled: !_otpSent && !_isLoading,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: 'Enter phone number',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                if (value.length < 6 || value.length > 15) return 'Invalid';
                if (!RegExp(r'^[0-9]+$').hasMatch(value)) return 'Digits only';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNameInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextFormField(
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        enabled: !_isLoading,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Full Name',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.person_outline, color: Colors.grey[500], size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Required';
          if (value.length < 2) return 'Name too short';
          return null;
        },
      ),
    );
  }
  
  Widget _buildEmailInput({required bool required}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        enabled: !_isLoading,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: required ? 'Email Address' : 'Email (Optional)',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[500], size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) return 'Required';
          if (value != null && value.isNotEmpty) {
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Invalid email';
            }
          }
          return null;
        },
      ),
    );
  }
  
  Widget _buildOtpInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryPurple.withOpacity(0.3)),
      ),
      child: TextFormField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        enabled: !_isLoading,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 12,
          color: _primaryPurple,
        ),
        decoration: const InputDecoration(
          hintText: '• • • • • •',
          hintStyle: TextStyle(color: Colors.grey, letterSpacing: 8),
          border: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Required';
          if (value.length != 6) return 'Enter 6 digits';
          return null;
        },
      ),
    );
  }
  
  Widget _buildTermsCheckbox() {
    return InkWell(
      onTap: _isLoading ? null : () => setState(() {
        _acceptedTerms = !_acceptedTerms;
        if (_acceptedTerms) _errorMessage = null;
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _acceptedTerms ? _primaryPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: _acceptedTerms ? _primaryPurple : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: _acceptedTerms
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _showTermsDialog,
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: TextStyle(
                          color: _primaryPurple,
                          fontWeight: FontWeight.w600,
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
      ),
    );
  }
  
  Widget _buildSuccessMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.green[100]!.withOpacity(0.5)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _successMessage!,
              style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[50]!, Colors.red[100]!.withOpacity(0.5)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: const Icon(Icons.close, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton() {
    String buttonText = 'Check Number';
    if (_showRegistrationFields && !_otpSent) buttonText = 'Send OTP';
    if (_otpSent) buttonText = 'Complete Registration';
    
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(colors: [_primaryPurple, _accentPurple]),
        boxShadow: [
          BoxShadow(
            color: _primaryPurple.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : (_otpSent ? _register : _sendOTP),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
      ),
    );
  }
  
  Widget _buildResendSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
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
            child: Text(
              'Change Number',
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Container(
            width: 1,
            height: 14,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 6),
          ),
          TextButton(
            onPressed: _isLoading ? null : _sendOTP,
            child: const Text(
              'Resend OTP',
              style: TextStyle(color: _primaryPurple, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            'Sign In',
            style: TextStyle(
              color: _primaryPurple,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_primaryPurple, _accentPurple]),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.description_outlined, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Terms & Conditions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTermsSection('1. Acceptance of Terms',
                          'By registering and using the HFC App and HC20 device, you agree to these terms and conditions.'),
                      _buildTermsSection('2. Account Registration',
                          'You must provide accurate information during registration. You are responsible for maintaining account security.'),
                      _buildTermsSection('3. Data Collection',
                          'The app collects health data from your HC20 wearable device including heart rate, blood pressure, SpO2, temperature, steps, and sleep data.'),
                      _buildTermsSection('4. Data Usage',
                          'Your health data is stored securely and used only for health monitoring purposes. Data is linked to your user account.'),
                      _buildTermsSection('5. Privacy Policy',
                          'We respect your privacy. Your data is encrypted and only accessible to you and authorized healthcare providers. We will never share your data without consent.'),
                      _buildTermsSection('6. Device Association',
                          'By connecting your HC20 device, you authorize the app to collect and store health data from the device.'),
                      _buildTermsSection('7. Account Security',
                          'You are responsible for maintaining the confidentiality of your account credentials. Notify us immediately of any unauthorized access.'),
                      _buildTermsSection('8. Medical Disclaimer',
                          'This app is for informational purposes only and should not replace professional medical advice, diagnosis, or treatment.'),
                      _buildTermsSection('9. Age Requirement',
                          'You must be at least 18 years old to register and use this service.'),
                      _buildTermsSection('10. Contact',
                          'For questions about these terms, please contact support@hireforcare.com'),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey[400]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _acceptedTerms = true);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryPurple,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _primaryPurple),
          ),
          const SizedBox(height: 3),
          Text(
            content,
            style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
          ),
        ],
      ),
    );
  }
}
