import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/health_data_service.dart';
import '../../services/device_status_service.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../../services/hc20_data_service.dart';
import '../../services/hc20_connection_manager.dart';
import '../../services/auth_service.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/bottom_navigation_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final healthData = Provider.of<HealthDataService>(context);
    final deviceStatus = Provider.of<DeviceStatusService>(context);
    final settings = Provider.of<SettingsService>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.textWhite,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE7E2FD),
              Color(0xFFE7E2FD),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Removed _buildHeader() - using AppBar instead
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileCard(context),
                      const SizedBox(height: 16),
                      _buildDeviceStatusCard(context),
                      const SizedBox(height: 16),
                      // _buildDataSyncSection(context),
                      // const SizedBox(height: 24),
                      // _buildDeviceSection(context),
                      // const SizedBox(height: 24),
                      _buildHealthAlertsSection(context),
                      const SizedBox(height: 24),
                      _buildPreferencesSection(),
                      const SizedBox(height: 24),
                      _buildHelpSupportSection(context),
                      const SizedBox(height: 32),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF532A7B),
            Color(0xFF532A7B),
          ],
        ),
      ),
      child: const Text(
        'Setting',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontFamily: 'poppins',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final deviceStatus = Provider.of<DeviceStatusService>(context);
    final authService = Provider.of<AuthService>(context);
    final userName = authService.currentUser?.name ?? 'User';

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/profile');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE7E2FD),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE1BEE7),
                    Color(0xFFCE93D8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF7B1FA2),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontFamily: 'poppins',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deviceStatus.isConnected
                        ? 'HC20 Wearable Connected'
                        : 'HC20 Wearable Disconnected',
                    style: TextStyle(
                      color: deviceStatus.isConnected
                          ? Colors.black87
                          : Colors.red.shade700,
                      fontSize: 14,
                      fontFamily: 'poppins',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow icon for navigation
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF532A7B),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard(BuildContext context) {
    final deviceStatus = Provider.of<DeviceStatusService>(context);
    final healthData = Provider.of<HealthDataService>(context);

    final batteryLevel = healthData.batteryLevel ?? 0;
    final isConnected = deviceStatus.isConnected;

    return GestureDetector(
      onTap: () {
        // Navigate to Device screen (index 3) using MainScaffold
        Navigator.of(context).pop(); // Close settings drawer first
        context
            .findAncestorStateOfType<MainScaffoldState>()
            ?.navigateToIndex(3);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.watch,
                color: Color(0xFF7B1FA2),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HC20',
                    style: TextStyle(
                      color: Color(0xFF2D1B4E),
                      fontSize: 16,
                      fontFamily: 'poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isConnected
                              ? const Color(0xFF4CAF50)
                              : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isConnected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.6),
                          fontSize: 12,
                          fontFamily: 'poppins',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: batteryLevel > 20
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    batteryLevel > 0 ? '$batteryLevel%' : '--%',
                    style: TextStyle(
                      color: batteryLevel > 20
                          ? const Color(0xFF4CAF50)
                          : Colors.red,
                      fontSize: 14,
                      fontFamily: 'poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.battery_charging_full,
                    color: batteryLevel > 20
                        ? const Color(0xFF4CAF50)
                        : Colors.red,
                    size: 18,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Arrow icon for navigation
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSyncSection(BuildContext context) {
    final deviceStatus = Provider.of<DeviceStatusService>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF3E5F5),
            const Color(0xFFE1BEE7).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sync,
                  color: Color(0xFF7B1FA2),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Data Sync Status',
                style: TextStyle(
                  color: Color(0xFF2D1B4E),
                  fontSize: 16,
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF9C27B0).withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Realtime Sync',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.6),
                        fontSize: 12,
                        fontFamily: 'poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deviceStatus.getLastRealtimeSyncText(),
                      style: const TextStyle(
                        color: Color(0xFF2D1B4E),
                        fontSize: 15,
                        fontFamily: 'poppins',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Webhook Sync',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.6),
                        fontSize: 12,
                        fontFamily: 'poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deviceStatus.getLastWebhookSyncText(),
                      style: const TextStyle(
                        color: Color(0xFF2D1B4E),
                        fontSize: 15,
                        fontFamily: 'poppins',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (deviceStatus.isRealtimeDataStale)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Data is stale - last update was more than 10 minutes ago',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 11,
                        fontFamily: 'poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceSection(BuildContext context) {
    final deviceStatus = Provider.of<DeviceStatusService>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Device',
            style: TextStyle(
              color: Colors.black.withOpacity(0.5),
              fontSize: 13,
              fontFamily: 'poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.watch,
                color: Color(0xFF7B1FA2),
                size: 24,
              ),
            ),
            title: const Text(
              'HC20',
              style: TextStyle(
                color: Color(0xFF2D1B4E),
                fontSize: 16,
                fontFamily: 'poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              deviceStatus.isConnected ? 'Connected' : 'Disconnected',
              style: TextStyle(
                color: deviceStatus.isConnected
                    ? Colors.black.withOpacity(0.6)
                    : Colors.red.withOpacity(0.8),
                fontSize: 13,
                fontFamily: 'poppins',
                fontWeight: FontWeight.w400,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: Color(0xFF9E9E9E),
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthAlertsSection(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Health Alerts',
            style: TextStyle(
              color: Colors.black.withOpacity(0.5),
              fontSize: 13,
              fontFamily: 'poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildAlertTile(
                context: context,
                icon: Icons.psychology,
                label: 'Stress Alerts',
                value: settings.stressAlertsEnabled,
                onChanged: (val) => settings.setStressAlerts(val),
              ),
              _buildDivider(),
              _buildAlertTile(
                context: context,
                icon: Icons.battery_alert,
                label: 'Fatigue Alerts',
                value: settings.fatigueAlertsEnabled,
                onChanged: (val) => settings.setFatigueAlerts(val),
              ),
              _buildDivider(),
              _buildAlertTile(
                context: context,
                icon: Icons.favorite,
                label: 'BP Alerts',
                value: settings.bpAlertsEnabled,
                onChanged: (val) => settings.setBpAlerts(val),
              ),
              _buildDivider(),
              _buildAlertTile(
                context: context,
                icon: Icons.air,
                label: 'SpO₂ Alerts',
                value: settings.spo2AlertsEnabled,
                onChanged: (val) => settings.setSpo2Alerts(val),
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool value,
    required Function(bool) onChanged,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF7B1FA2),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF2D1B4E),
                fontSize: 15,
                fontFamily: 'poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF7B1FA2),
              activeTrackColor: const Color(0xFFCE93D8),
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.grey.shade200,
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Preferences',
            style: TextStyle(
              color: Colors.black.withOpacity(0.5),
              fontSize: 13,
              fontFamily: 'poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildPreferenceTile(
                icon: Icons.straighten,
                label: 'Distance Unit',
                value: 'km',
              ),
              _buildDivider(),
              _buildPreferenceTile(
                icon: Icons.thermostat,
                label: 'Temperature',
                value: '°C',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF7B1FA2),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF2D1B4E),
                fontSize: 15,
                fontFamily: 'poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.black.withOpacity(0.6),
              fontSize: 14,
              fontFamily: 'poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right,
            color: Color(0xFF9E9E9E),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSupportSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Help & Support',
            style: TextStyle(
              color: Colors.black.withOpacity(0.5),
              fontSize: 13,
              fontFamily: 'poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildHelpButton(
              context: context,
              icon: Icons.sync,
              label: 'Sync Settings',
              onTap: () {
                // Navigate to Device screen (index 3)
                Navigator.of(context).pop(); // Close drawer first
                context
                    .findAncestorStateOfType<MainScaffoldState>()
                    ?.navigateToIndex(3);
              },
            ),
            _buildHelpButton(
              context: context,
              icon: Icons.download,
              label: 'Download Report',
            ),
            _buildHelpButton(
              context: context,
              icon: Icons.help_outline,
              label: 'FAQ',
              onTap: () {
                // Navigate to Clinical screen (index 1)
                Navigator.of(context).pop(); // Close drawer first
                context
                    .findAncestorStateOfType<MainScaffoldState>()
                    ?.navigateToIndex(1);
              },
            ),
            _buildHelpButton(
              context: context,
              icon: Icons.contact_support,
              label: 'Contact Us',
              onTap: () {
                // Navigate to Clinical screen (index 1)
                Navigator.of(context).pop(); // Close drawer first
                context
                    .findAncestorStateOfType<MainScaffoldState>()
                    ?.navigateToIndex(1);
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildClearDataButton(context),
      ],
    );
  }

  Widget _buildHelpButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: (MediaQuery.of(context).size.width - 44) / 2,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E1EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF532A7B),
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearDataButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.shade50,
            Colors.red.shade100.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.delete_sweep,
                  color: Colors.red.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Clear All Data',
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontSize: 16,
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'This will clear all health data, sync timestamps, and settings. This action cannot be undone.',
            style: TextStyle(
              color: Colors.red.shade800,
              fontSize: 12,
              fontFamily: 'poppins',
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showClearDataDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_forever, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Clear Data',
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.cleaning_services_rounded,
                            color: Colors.red.shade700, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Clear Options',
                                style: TextStyle(
                                    fontFamily: 'poppins',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20)),
                            Text('Choose what to clear',
                                style: TextStyle(
                                    fontFamily: 'poppins',
                                    color: Colors.grey,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Option 1: Forget Device
                  _buildClearOption(
                    context: context,
                    sheetContext: sheetContext,
                    icon: Icons.watch_off_rounded,
                    iconColor: Colors.orange,
                    bgColor: Colors.orange.shade50,
                    title: 'Forget Device',
                    subtitle: 'Unpair HC20 to connect a new device',
                    onTap: () =>
                        _showForgetDeviceConfirmation(context, sheetContext),
                  ),
                  const SizedBox(height: 12),

                  // Option 2: Clear Health Data
                  _buildClearOption(
                    context: context,
                    sheetContext: sheetContext,
                    icon: Icons.favorite_border_rounded,
                    iconColor: Colors.blue,
                    bgColor: Colors.blue.shade50,
                    title: 'Clear Health Data',
                    subtitle: 'Remove vitals, HRV metrics & sync history',
                    onTap: () =>
                        _showClearHealthDataConfirmation(context, sheetContext),
                  ),
                  const SizedBox(height: 12),

                  // Option 3: Clear All (Nuclear)
                  _buildClearOption(
                    context: context,
                    sheetContext: sheetContext,
                    icon: Icons.delete_forever_rounded,
                    iconColor: Colors.red,
                    bgColor: Colors.red.shade50,
                    title: 'Clear Everything',
                    subtitle: 'Device + health data + settings (fresh start)',
                    onTap: () =>
                        _showClearAllConfirmation(context, sheetContext),
                  ),
                  const SizedBox(height: 16),

                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel',
                          style: TextStyle(
                              fontFamily: 'poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.grey.shade600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClearOption({
    required BuildContext context,
    required BuildContext sheetContext,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: bgColor, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontFamily: 'poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontFamily: 'poppins',
                            color: Colors.grey.shade600,
                            fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showForgetDeviceConfirmation(
      BuildContext context, BuildContext sheetContext) {
    Navigator.of(sheetContext).pop(); // Close bottom sheet
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.watch_off_rounded,
                  color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 12),
              const Text('Forget Device?',
                  style: TextStyle(
                      fontFamily: 'poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
            ],
          ),
          content: const Text(
            'This will unpair your HC20 device.\n\n'
            'You can then connect a different HC20 device.\n\n'
            '• Health data will be preserved\n'
            '• Settings will be preserved',
            style: TextStyle(fontFamily: 'poppins', fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel',
                  style: TextStyle(
                      color: Colors.grey.shade700,
                      fontFamily: 'poppins',
                      fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _forgetDevice(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Forget Device',
                  style: TextStyle(
                      fontFamily: 'poppins', fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void _showClearHealthDataConfirmation(
      BuildContext context, BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.favorite_border_rounded,
                  color: Colors.blue.shade700, size: 28),
              const SizedBox(width: 12),
              const Text('Clear Health Data?',
                  style: TextStyle(
                      fontFamily: 'poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
            ],
          ),
          content: const Text(
            'This will permanently delete:\n\n'
            '• All health vitals (HR, SpO2, BP, Temp)\n'
            '• HRV2 stress metrics\n'
            '• Sync timestamps\n\n'
            'Device pairing & settings will be preserved.',
            style: TextStyle(fontFamily: 'poppins', fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel',
                  style: TextStyle(
                      color: Colors.grey.shade700,
                      fontFamily: 'poppins',
                      fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _clearHealthData(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Clear Health Data',
                  style: TextStyle(
                      fontFamily: 'poppins', fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void _showClearAllConfirmation(
      BuildContext context, BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade700, size: 28),
              const SizedBox(width: 12),
              const Text('Clear Everything?',
                  style: TextStyle(
                      fontFamily: 'poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
            ],
          ),
          content: const Text(
            '⚠️ This will permanently delete:\n\n'
            '• Device pairing (HC20)\n'
            '• All health vitals data\n'
            '• HRV2 stress metrics\n'
            '• Sync timestamps\n'
            '• Alert settings\n\n'
            'This is like a fresh start. Continue?',
            style: TextStyle(fontFamily: 'poppins', fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel',
                  style: TextStyle(
                      color: Colors.grey.shade700,
                      fontFamily: 'poppins',
                      fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _clearEverything(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Clear Everything',
                  style: TextStyle(
                      fontFamily: 'poppins', fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _forgetDevice(BuildContext context) async {
    try {
      // Clear device from storage
      final storage = StorageService();
      await storage.clearDeviceData();

      // Update connection manager
      final connectionManager =
          Provider.of<HC20ConnectionManager>(context, listen: false);
      await connectionManager.forgetDevice();

      // Update device status service
      final deviceStatus =
          Provider.of<DeviceStatusService>(context, listen: false);
      deviceStatus.updateConnectionState(
          connected: false,
          deviceId: null,
          deviceName: null,
          batteryLevel: null);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Device forgotten successfully')
            ]),
            backgroundColor: Colors.orange.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _clearHealthData(BuildContext context) async {
    try {
      final healthData = Provider.of<HealthDataService>(context, listen: false);
      final hc20DataService =
          Provider.of<HC20DataService>(context, listen: false);

      await healthData.clearAllData();
      await hc20DataService.clearSyncData();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Health data cleared')
            ]),
            backgroundColor: Colors.blue.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _clearEverything(BuildContext context) async {
    try {
      final healthData = Provider.of<HealthDataService>(context, listen: false);
      final deviceStatus =
          Provider.of<DeviceStatusService>(context, listen: false);
      final settings = Provider.of<SettingsService>(context, listen: false);
      final hc20DataService =
          Provider.of<HC20DataService>(context, listen: false);
      final connectionManager =
          Provider.of<HC20ConnectionManager>(context, listen: false);
      final storage = StorageService();

      // Clear all services
      await healthData.clearAllData();
      await deviceStatus.clearAllData();
      await settings.clearAllData();
      await hc20DataService.clearSyncData();
      await connectionManager.forgetDevice();
      await storage.clearDeviceData();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('All data cleared successfully')
            ]),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
