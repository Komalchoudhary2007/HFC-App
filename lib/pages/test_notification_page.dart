import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class TestNotificationPage extends StatefulWidget {
  final String? deviceId;
  final String? deviceName;
  
  const TestNotificationPage({
    Key? key,
    this.deviceId,
    this.deviceName,
  }) : super(key: key);

  @override
  State<TestNotificationPage> createState() => _TestNotificationPageState();
}

class _TestNotificationPageState extends State<TestNotificationPage> {
  final ApiService _apiService = ApiService();
  String _statusMessage = 'Ready to test';
  bool _isSending = false;

  Future<void> _sendNotification() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    
    if (user == null) {
      setState(() {
        _statusMessage = '❌ Error: Please login first';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (widget.deviceId == null || widget.deviceName == null) {
      setState(() {
        _statusMessage = '❌ Error: Please connect to a device first';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect to a device first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isSending = true;
      _statusMessage = 'Sending test notification...';
    });
    
    try {
      print('📱 ========================================');
      print('📱 TEST NOTIFICATION PAGE');
      print('📱 User: ${user.name}');
      print('📱 Phone: ${user.phone}');
      print('📱 Device: ${widget.deviceName} (${widget.deviceId})');
      print('📱 ========================================');
      
      final response = await _apiService.sendDisconnectNotification(
        phone: user.phone,
        deviceId: widget.deviceId!,
        deviceName: widget.deviceName!,
      );
      
      if (response['success'] == true) {
        setState(() {
          _isSending = false;
          _statusMessage = '✅ Test notification sent successfully to ${user.phone}!';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WhatsApp notification sent to ${user.phone}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        
        print('✅ SUCCESS: ${response['message']}');
      } else {
        setState(() {
          _isSending = false;
          _statusMessage = '❌ Failed: ${response['error'] ?? 'Unknown error'}';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${response['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        
        print('❌ FAILED: ${response['error']}');
      }
    } catch (e) {
      setState(() {
        _isSending = false;
        _statusMessage = '❌ Error: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      
      print('❌ EXCEPTION: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test WhatsApp Notification'),
        backgroundColor: Colors.orange,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.5),
                        spreadRadius: 5,
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                const Text(
                  'Test WhatsApp Notification',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Description
                Text(
                  'Send a test device disconnect notification to WhatsApp',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Status Info Cards
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          icon: Icons.person,
                          label: 'User',
                          value: user?.name ?? 'Not logged in',
                          isValid: user != null,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          icon: Icons.phone,
                          label: 'Phone',
                          value: user?.phone ?? 'N/A',
                          isValid: user != null,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          icon: Icons.devices,
                          label: 'Device',
                          value: widget.deviceName ?? 'Not connected',
                          isValid: widget.deviceId != null,
                        ),
                        if (widget.deviceId != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'ID: ${widget.deviceId}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Status Message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _statusMessage.contains('✅')
                        ? Colors.green.shade50
                        : _statusMessage.contains('❌')
                            ? Colors.red.shade50
                            : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _statusMessage.contains('✅')
                          ? Colors.green
                          : _statusMessage.contains('❌')
                              ? Colors.red
                              : Colors.blue,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _statusMessage.contains('✅')
                            ? Icons.check_circle
                            : _statusMessage.contains('❌')
                                ? Icons.error
                                : Icons.info,
                        color: _statusMessage.contains('✅')
                            ? Colors.green
                            : _statusMessage.contains('❌')
                                ? Colors.red
                                : Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Send Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: (user != null && widget.deviceId != null && !_isSending)
                        ? _sendNotification
                        : null,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, size: 24),
                    label: Text(
                      _isSending ? 'Sending...' : 'Send Test Notification',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Requirements
                if (user == null || widget.deviceId == null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.amber),
                            SizedBox(width: 8),
                            Text(
                              'Requirements',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (user == null)
                          const Text('• Please login first'),
                        if (widget.deviceId == null)
                          const Text('• Please connect to a device first'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isValid,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: isValid ? Colors.green : Colors.grey,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isValid ? Colors.black87 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Icon(
          isValid ? Icons.check_circle : Icons.cancel,
          color: isValid ? Colors.green : Colors.red,
          size: 20,
        ),
      ],
    );
  }
}
