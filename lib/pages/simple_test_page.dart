import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

/// SUPER SIMPLE TEST PAGE - NOTHING CAN GO WRONG
class SimpleTestPage extends StatefulWidget {
  const SimpleTestPage({Key? key}) : super(key: key);

  @override
  State<SimpleTestPage> createState() => _SimpleTestPageState();
}

class _SimpleTestPageState extends State<SimpleTestPage> {
  final ApiService _apiService = ApiService();
  String _result = '';
  bool _sending = false;

  Future<void> _test() async {
    setState(() {
      _sending = true;
      _result = 'Testing...';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user == null) {
        setState(() {
          _sending = false;
          _result = 'ERROR: Not logged in';
        });
        return;
      }

      // Use dummy device for testing
      final response = await _apiService.sendDisconnectNotification(
        phone: user.phone,
        deviceId: 'TEST-DEVICE-001',
        deviceName: 'Test Device',
      );

      setState(() {
        _sending = false;
        _result = response['success'] == true
            ? 'SUCCESS! Check WhatsApp: ${user.phone}'
            : 'FAILED: ${response['error']}';
      });
    } catch (e) {
      setState(() {
        _sending = false;
        _result = 'ERROR: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'NOTIFICATION TEST',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _sending ? null : _test,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                ),
                child: Text(
                  _sending ? 'SENDING...' : 'SEND TEST',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 40),
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _result.isEmpty ? 'Press button to test' : _result,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
