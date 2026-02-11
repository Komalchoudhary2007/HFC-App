import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../services/health_data_service.dart';
import '../../services/device_status_service.dart';
import '../../services/hc20_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final healthData = Provider.of<HealthDataService>(context);
    final deviceStatus = Provider.of<DeviceStatusService>(context);
    final hc20Service = Provider.of<HC20Service>(context);
    final user = authService.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.textWhite,
      ),
      backgroundColor: const Color(0xFFE9E3F5), // Light lavender background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Profile Header Card
              _buildProfileCard(user?.name ?? 'Guest'),
              const SizedBox(height: 16),
              // Profile Details & Connected Device Card
              _buildDetailsCard(
                context,
                user,
                healthData,
                deviceStatus,
                hc20Service,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(String userName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Edit Profile Button
          Align(
            alignment: Alignment.topRight,
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(
                Icons.edit,
                size: 16,
                color: Color(0xFF532A7B),
              ),
              label: const Text(
                'Edit Profile',
                style: TextStyle(
                  color: Color(0xFF532A7B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                'https://api.dicebear.com/7.x/avataaars/png?seed=$userName',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF532A7B),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            userName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F1F1F),
            ),
          ),
          const SizedBox(height: 4),
          // Subtitle
          const Text(
            'Parent using HC20',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(
    BuildContext context,
    dynamic user,
    HealthDataService healthData,
    DeviceStatusService deviceStatus,
    HC20Service hc20Service,
  ) {
    final isConnected = hc20Service.isConnected;
    final deviceName = hc20Service.connectedDevice?.name ?? 'HC20 Wearable';
    final batteryLevel = healthData.batteryLevel ?? 0;
    final connectionStatus = hc20Service.getConnectionStatus();
    final lastSyncText = deviceStatus.getLastRealtimeSyncText();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Details Section
          const Text(
            'Profile Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F1F1F),
            ),
          ),
          const SizedBox(height: 20),
          // Email Row
          _buildInfoRow(
            icon: Icons.email_outlined,
            iconColor: const Color(0xFF532A7B),
            label: 'Email',
            value: user?.email ?? 'Not set',
          ),
          const SizedBox(height: 16),
          // Phone Row
          _buildInfoRow(
            icon: Icons.phone_outlined,
            iconColor: const Color(0xFF532A7B),
            label: 'Phone Number',
            value: user?.phone ?? 'Not set',
          ),
          const SizedBox(height: 24),
          // Divider
          const Divider(height: 1),
          const SizedBox(height: 24),
          // Connected Device Section
          const Text(
            'Connected Device',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F1F1F),
            ),
          ),
          const SizedBox(height: 16),
          // Device Details
          _buildDeviceRow('Device Name', deviceName),
          const SizedBox(height: 12),
          _buildDeviceRow(
            'Status',
            connectionStatus,
            isStatus: true,
            isConnected: isConnected,
          ),
          const SizedBox(height: 12),
          _buildDeviceRow('Battery', batteryLevel > 0 ? '$batteryLevel %' : '--'),
          const SizedBox(height: 12),
          _buildDeviceRow('Last Sync', lastSyncText),
          const SizedBox(height: 20),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isConnected
                      ? () => _handleSyncNow(context, hc20Service)
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: isConnected ? const Color(0xFF532A7B) : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Sync Now',
                    style: TextStyle(
                      color: isConnected ? const Color(0xFF532A7B) : Colors.grey.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: isConnected
                      ? () => _handleDisconnect(context)
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: isConnected ? Colors.red.shade300 : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Disconnect',
                    style: TextStyle(
                      color: isConnected ? Colors.red.shade600 : Colors.grey.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Footer Text
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
                children: [
                  TextSpan(text: 'Your data is securely synced with '),
                  TextSpan(
                    text: 'HireForCare',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                  TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F1F1F),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceRow(String label, String value, {bool isStatus = false, bool isConnected = false}) {
    // Determine status color based on connection state
    Color statusColor = const Color(0xFF10B981); // Green by default
    if (isStatus) {
      if (value.contains('Disconnected')) {
        statusColor = Colors.red;
      } else if (value.contains('Stale') || value.contains('No Data')) {
        statusColor = Colors.orange;
      }
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        Row(
          children: [
            if (isStatus)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isStatus ? statusColor : const Color(0xFF1F1F1F),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  void _handleSyncNow(BuildContext context, HC20Service hc20Service) {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Syncing data from device...'),
          ],
        ),
        backgroundColor: const Color(0xFF532A7B),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
    
    // Success message after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Data synced successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    });
  }
  
  void _handleDisconnect(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Disconnect Device?',
                style: TextStyle(
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to disconnect from the HC20 device?\n\n'
            'You will need to reconnect manually to receive health data.',
            style: TextStyle(
              fontFamily: 'poppins',
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                
                // Navigate to HC20 device screen to disconnect
                // The actual disconnect happens in main.dart
                Navigator.of(context).pop(); // Go back from profile
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Go to Device screen to disconnect'),
                      ],
                    ),
                    backgroundColor: Colors.orange.shade600,
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Disconnect',
                style: TextStyle(
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
