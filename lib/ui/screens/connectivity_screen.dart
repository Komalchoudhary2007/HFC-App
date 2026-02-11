import 'package:flutter/material.dart';

class ConnectivityScreen extends StatelessWidget {
  const ConnectivityScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F0F9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Connectivity (Advanced)',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'R',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cloud Sync Active Card
              _buildCloudSyncCard(),
              
              const SizedBox(height: 16),
              
              // Uploads Section
              _buildUploadsSection(),
              
              const SizedBox(height: 24),
              
              // Account & Device Section
              _buildAccountDeviceSection(),
              
              const SizedBox(height: 24),
              
              // Connection Status Section
              _buildConnectionStatusSection(),
              
              const SizedBox(height: 24),
              
              // Time & Sync Diagnostics
              _buildTimeSyncDiagnostics(),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              _buildActionButtons(),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCloudSyncCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF923EBD), Color(0xFF9F66E1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF923EBD).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CLOUD SYNC ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Data uploading to cloud: 1 successful',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Date: 1/24/23',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '1',
                  style: TextStyle(
                    color: Color(0xFF923EBD),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F0F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.cloud_upload_outlined,
            color: Color(0xFF923EBD),
            size: 20,
          ),
        ),
        title: const Text(
          'Uploads',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        subtitle: const Text(
          'Data securely uploaded to the cloud',
          style: TextStyle(
            fontSize: 10,
            color: Colors.black54,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '1 successful',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountDeviceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Account & Device',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                icon: Icons.person_outline,
                label: 'Account',
                value: 'Ram',
                showArrow: true,
              ),
              _buildDivider(),
              _buildInfoRow(
                icon: Icons.watch_outlined,
                label: 'Device',
                value: 'HC20 Wearable',
                showArrow: true,
              ),
              _buildDivider(),
              _buildInfoRow(
                icon: Icons.devices_outlined,
                label: 'Device ID',
                value: '50:C0:F0:42:48:07',
                showInfoIcon: true,
              ),
              _buildDivider(),
              _buildInfoRow(
                icon: Icons.link,
                label: 'Linked',
                value: 'Yes',
                showCheckmark: true,
                showArrow: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Connection Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildStatusRow(
                icon: Icons.bluetooth,
                label: 'Bluetooth',
                status: 'ON',
                isConnected: true,
              ),
              _buildDivider(),
              _buildStatusRow(
                icon: Icons.wifi,
                label: 'Internet',
                status: 'Connected',
                isConnected: true,
              ),
              _buildDivider(),
              _buildStatusRow(
                icon: Icons.devices,
                label: 'Device',
                status: 'Connected',
                isConnected: true,
              ),
              _buildDivider(),
              _buildInfoRow(
                icon: Icons.access_time,
                label: 'Last Data',
                value: '23 seconds ago',
                showArrow: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSyncDiagnostics() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Time & Sync Diagnostics',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildDiagnosticRow('Last Request :', 'Success (200)', isSuccess: true),
          const SizedBox(height: 12),
          _buildDiagnosticRow('Last Checked :', '15:28'),
          const SizedBox(height: 12),
          _buildDiagnosticRow('Timestamp :', '15:28:23'),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.search,
                label: 'Scan for Devices',
                color: const Color(0xFFE1D4F0),
                textColor: const Color(0xFF923EBD),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.link_off,
                label: 'Disconnect Devices',
                color: const Color(0xFFFCE4EC),
                textColor: const Color(0xFFE91E63),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.upload_outlined,
                label: 'Send History',
                color: const Color(0xFFE1D4F0),
                textColor: const Color(0xFF923EBD),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.upload_outlined,
                label: 'Send Real time',
                color: const Color(0xFFFCE4EC),
                textColor: const Color(0xFFE91E63),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool showArrow = false,
    bool showCheckmark = false,
    bool showInfoIcon = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          if (showCheckmark)
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 18),
          if (showCheckmark) const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          if (showInfoIcon) const SizedBox(width: 6),
          if (showInfoIcon)
            const Icon(Icons.info_outline, color: Colors.black54, size: 16),
          if (showArrow) const SizedBox(width: 4),
          if (showArrow)
            const Icon(Icons.chevron_right, color: Colors.black54, size: 20),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String label,
    required String status,
    required bool isConnected,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF923EBD), size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.check_circle,
            color: isConnected ? const Color(0xFF4CAF50) : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isConnected ? const Color(0xFF4CAF50) : Colors.black,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.black54, size: 20),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRow(String label, String value, {bool isSuccess = false}) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ),
        if (isSuccess)
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
        if (isSuccess) const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSuccess ? const Color(0xFF4CAF50) : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade200,
      indent: 16,
      endIndent: 16,
    );
  }
}
