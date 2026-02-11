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

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _acceptedTerms = false;
  String _selectedCountryCode = '+91';
  
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
    _animationController.dispose();
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
        _successMessage = 'OTP sent to your WhatsApp number';
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
            stops: const [0.0, 0.25, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Top Section with Logo
                _buildHeader(),
                
                // Login Card
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildLoginCard(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
      child: Column(
        children: [
          // Logo Container
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/images/hfc-logo-icon.png',
                // 'assets/icons/app_icon.png',
                width: 70,
                height: 70,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.watch_rounded,
                  size: 50,
                  color: _primaryPurple,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to continue monitoring your health',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoginCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
            // Phone Number Section
            _buildSectionTitle(
              icon: Icons.phone_android,
              title: 'Phone Number',
              subtitle: 'We\'ll send OTP via WhatsApp',
            ),
            const SizedBox(height: 16),
            _buildPhoneInput(),
            
            const SizedBox(height: 20),
            
            // OTP Section (shown after OTP sent)
            if (_otpSent) ...[
              _buildSectionTitle(
                icon: Icons.lock_outline,
                title: 'Verification Code',
                subtitle: 'Enter the 6-digit code sent to your WhatsApp',
              ),
              const SizedBox(height: 16),
              _buildOtpInput(),
              const SizedBox(height: 20),
            ],
            
            // Messages
            if (_successMessage != null) _buildSuccessMessage(),
            if (_errorMessage != null) _buildErrorMessage(),
            
            // Terms Checkbox
            _buildTermsCheckbox(),
            
            const SizedBox(height: 24),
            
            // Action Button
            _buildActionButton(),
            
            // Resend/Change Number
            if (_otpSent) _buildResendSection(),
            
            const SizedBox(height: 24),
            
            // Divider
            _buildDivider(),
            
            const SizedBox(height: 20),
            
            // Register Link
            _buildRegisterLink(),
          ],
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _lightPurple,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primaryPurple, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Country Code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCountryCode,
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                items: _countryCodes.map((country) {
                  return DropdownMenuItem<String>(
                    value: country['code'],
                    child: Text(
                      country['code']!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: !_otpSent && !_isLoading
                    ? (value) => setState(() => _selectedCountryCode = value!)
                    : null,
              ),
            ),
          ),
          // Phone Field
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              enabled: !_otpSent && !_isLoading,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: 'Enter phone number',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
  
  Widget _buildOtpInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
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
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Required';
          if (value.length != 6) return 'Enter 6 digits';
          return null;
        },
      ),
    );
  }
  
  Widget _buildSuccessMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.green[100]!.withOpacity(0.5)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _successMessage!,
              style: TextStyle(
                color: Colors.green[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[50]!, Colors.red[100]!.withOpacity(0.5)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTermsCheckbox() {
    return InkWell(
      onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _acceptedTerms ? _primaryPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _acceptedTerms ? _primaryPurple : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: _acceptedTerms
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _showTermsDialog,
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
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
  
  Widget _buildActionButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [_primaryPurple, _accentPurple],
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryPurple.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : (_otpSent ? _verifyOTP : _sendOTP),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _otpSent ? 'Verify & Login' : 'Send OTP',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
      ),
    );
  }
  
  Widget _buildResendSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
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
            child: Text(
              'Change Number',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          TextButton(
            onPressed: _isLoading ? null : _sendOTP,
            child: const Text(
              'Resend OTP',
              style: TextStyle(
                color: _primaryPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'New to HFC?',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300])),
      ],
    );
  }
  
  Widget _buildRegisterLink() {
    return OutlinedButton(
      onPressed: _goToRegister,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: _primaryPurple.withOpacity(0.5), width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_outlined, color: _primaryPurple),
          SizedBox(width: 8),
          Text(
            'Create New Account',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _primaryPurple,
            ),
          ),
        ],
      ),
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
                  gradient: LinearGradient(
                    colors: [_primaryPurple, _accentPurple],
                  ),
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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
                          'By using the HFC App and HC20 device, you agree to these terms and conditions.'),
                      _buildTermsSection('2. Data Collection',
                          'The app collects health data from your HC20 wearable device including heart rate, blood pressure, SpO2, temperature, steps, and sleep data.'),
                      _buildTermsSection('3. Data Usage',
                          'Your health data is stored securely and used only for health monitoring purposes. Data is linked to your user account.'),
                      _buildTermsSection('4. Privacy',
                          'We respect your privacy. Your data is encrypted and only accessible to you and authorized healthcare providers.'),
                      _buildTermsSection('5. Device Association',
                          'By connecting your HC20 device, you authorize the app to collect and store health data from the device.'),
                      _buildTermsSection('6. Account Security',
                          'You are responsible for maintaining the confidentiality of your account credentials.'),
                      _buildTermsSection('7. Medical Disclaimer',
                          'This app is for informational purposes only and should not replace professional medical advice.'),
                      _buildTermsSection('8. Changes to Terms',
                          'We reserve the right to modify these terms at any time. Continued use constitutes acceptance of modified terms.'),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Accept',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: _primaryPurple,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
