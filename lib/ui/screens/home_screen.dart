import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/health_data_service.dart';
import '../../services/device_status_service.dart';
import '../../services/auth_service.dart';
import '../../services/hc20_service.dart'; // NEW: Import HC20Service for stress button
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../main.dart' show HC20HomePage;
import '../widgets/appointment_booking_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  /// Show stress alert confirmation dialog with calming UI
  void _showStressAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.purple.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Calming icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.self_improvement,
                  size: 50,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Take a Deep Breath',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'You\'re not alone. Let\'s record this moment and find some quick relief.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Quick relief tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✨ Quick Relief',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTipItem('🫁', 'Box breathing: 4-4-4-4'),
                    _buildTipItem('💧', 'Drink cold water slowly'),
                    _buildTipItem('🎵', 'Listen to calming music'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();

                        // ✅ Use centralized sync handler via HC20Service
                        final hc20Service =
                            Provider.of<HC20Service>(context, listen: false);

                        // Show loading feedback
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('📊 Recording stress alert...'),
                            duration: Duration(seconds: 2),
                          ),
                        );

                        // Request stress alert via centralized handler
                        final success = await hc20Service.requestFreshData(
                            isStressAlert: true);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? '✅ Stress alert recorded successfully'
                                  : '❌ Could not record - device not connected'),
                              backgroundColor:
                                  success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Record Alert',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a tip item for the quick relief section
  static Widget _buildTipItem(String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              fontFamily: 'poppins',
            ),
          ),
        ),
      ],
    );
  }

  /// Build inspirational support banner for parents
  Widget _buildParentSupportBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF532A7B),
              Color(0xFF7B4397),
              Color(0xFF9B59B6),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF532A7B).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with heart icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'We\'re Here With You',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'poppins',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Supporting special needs parents 24/7',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                                fontFamily: 'poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Inspirational message
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.format_quote_rounded,
                              color: Colors.white.withOpacity(0.7),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Your well-being matters as much as your child\'s',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontFamily: 'poppins',
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'We continuously monitor your stress levels and provide timely support through psychologist-led interventions. You\'re not alone in this journey.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                            fontFamily: 'poppins',
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats/Features row
                  Row(
                    children: [
                      _buildBannerStat('24/7', 'Monitoring'),
                      const SizedBox(width: 12),
                      _buildBannerStat('Real-time', 'Alerts'),
                      const SizedBox(width: 12),
                      _buildBannerStat('Expert', 'Support'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final Uri url = Uri.parse('https://hireforcare.com/');
                        try {
                          await launchUrl(url,
                              mode: LaunchMode.externalApplication);
                        } catch (e) {
                          print('Could not launch URL: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF532A7B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Learn More About Our Mission',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'poppins',
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build stat item for parent support banner
  Widget _buildBannerStat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'poppins',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.85),
                fontFamily: 'poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle refresh data tap - request fresh data from device
  Future<void> _handleRefreshData(BuildContext context) async {
    final hc20Service = Provider.of<HC20Service>(context, listen: false);

    if (!hc20Service.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device not connected'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Show loading feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Syncing with device...'),
        backgroundColor: Color(0xFF532A7B),
        duration: Duration(seconds: 2),
      ),
    );

    // Request fresh data from device (triggers time sync)
    final success = await hc20Service.requestFreshData();

    // Show success/error after request
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              success ? '✓ Data refresh triggered' : '✗ Failed to refresh'),
          backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else if (hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7E2FD),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Today',
                            style: TextStyle(
                              color: Color(0xFF532A7B),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Consumer<DeviceStatusService>(
                            builder: (context, deviceStatus, child) {
                              final lastSync =
                                  deviceStatus.getLastRealtimeSyncText();
                              return Row(
                                children: [
                                  Icon(
                                    deviceStatus.isRealtimeDataStale
                                        ? Icons.warning_amber
                                        : Icons.check_circle,
                                    size: 14,
                                    color: deviceStatus.isRealtimeDataStale
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Last updated: $lastSync',
                                    style: TextStyle(
                                      color: Color(0xFF532A7B),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _handleRefreshData(context),
                                    child: Icon(
                                      Icons.refresh,
                                      size: 18,
                                      color: Color(0xFF532A7B),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stress Level Card - Responsive Design
            _buildStressLevelCard(context),

            const SizedBox(height: 24),

            // Health Summary Section - Responsive
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Health Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      fontFamily: 'poppins',
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Navigate to Vitals screen (index 2) using MainScaffold's public method
                      State? state = context
                          .findAncestorStateOfType<State<StatefulWidget>>();
                      while (state != null) {
                        if (state.widget.runtimeType.toString() ==
                            'MainScaffold') {
                          try {
                            (state as dynamic)
                                .navigateToIndex(2); // Vitals screen
                            return;
                          } catch (e) {
                            print('Navigation error: $e');
                          }
                        }
                        state = state.context
                            .findAncestorStateOfType<State<StatefulWidget>>();
                      }
                    },
                    child: Row(
                      children: [
                        Text(
                          'View all',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontFamily: 'poppins',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.black87,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Health Metrics Grid - Responsive
            _buildHealthMetricsGrid(context),

            const SizedBox(height: 24),

            _buildHealthSummarySection(context),

            const SizedBox(height: 24),

            // Inspirational Support Banner for Parents
            _buildParentSupportBanner(context),

            const SizedBox(height: 24),

            // Special Child Services Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Color(0xFFF8F1F9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Special Child Services',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 2.2,
                      children: [
                        _buildServiceCard('Occupational Therapy',
                            'assets/images/home/occupational-therapy.png'),
                        _buildServiceCard('Speech Therapy',
                            'assets/images/home/speech-therapy.png'),
                        _buildServiceCard('ABA\nTherapy',
                            'assets/images/home/aba-therapy.png'),
                        _buildServiceCard('Special Education',
                            'assets/images/home/special-education.png'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) =>
                                    const AppointmentBookingDialog(),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF532A7B),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 26, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Book Free Consultation',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Talk to a HireForCare expert about your concerns',
                            style: TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // How Therapy Works Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Color(0xFFF8F1F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How Therapy Works',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        fontFamily: 'poppins',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTherapyCard(
                            context,
                            'Online Therapy',
                            'Home session by experts',
                            'assets/images/home/online-therapy.png',
                            'https://vimeo.com/1130819420?fl=pl&fe=sh',
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildTherapyCard(
                            context,
                            'Therapy Centre',
                            'Support at our centre',
                            'assets/images/home/in-centre-therapy.png',
                            'https://hireforcare-media.s3.ap-south-1.amazonaws.com/early_screening/special-child-centre.mp4',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String status,
    String imagePath,
    Color statusBgColor,
    Color statusTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF8F1F9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusTextColor,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Image.asset(
              imagePath,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String value, String label, String imagePath) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset(imagePath, width: 28, height: 28, fit: BoxFit.contain),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(String title, String imagePath) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset(imagePath, width: 32, height: 32, fit: BoxFit.contain),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTherapyCard(BuildContext context, String title,
      String description, String imagePath, String videoUrl) {
    return GestureDetector(
      onTap: () async {
        try {
          final uri = Uri.parse(videoUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(
              uri,
              mode: LaunchMode.externalNonBrowserApplication,
            );
          } else {
            // Fallback to platform default
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
        } catch (e) {
          print('Error launching video: $e');
          // Show error to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to open video'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with play button overlay
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: Container(
                height: 80,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                    ),
                    // Play button overlay
                    Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(0xFF8C56C0).withOpacity(0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Text content
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      fontFamily: 'poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      fontFamily: 'poppins',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Responsive Stress Level Card matching Figma design
  Widget _buildStressLevelCard(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // NEW: Get data from services
    final healthData = Provider.of<HealthDataService>(context);
    final deviceStatus = Provider.of<DeviceStatusService>(context);
    final authService = Provider.of<AuthService>(context);

    // Get user name dynamically
    final userName = authService.currentUser?.name ?? 'User';

    // Calculate stress level
    final mentalStress = healthData.mentalStress ?? 0;
    final stressText =
        healthData.getStressLevelText(); // 'High', 'Moderate', 'Normal', 'Low'
    final lastSync = deviceStatus.getLastRealtimeSyncText(); // '5m ago'

    // Determine color based on stress level
    Color stressColor = const Color(0xFF2DD36F); // Green (default)
    Color backgroundColor = const Color(0xFFD4EDC5); // Light green
    if (mentalStress >= 70) {
      stressColor = Colors.red;
      backgroundColor = Colors.red.shade100;
    } else if (mentalStress >= 50) {
      stressColor = Colors.orange;
      backgroundColor = Colors.orange.shade100;
    }

    // Responsive scale factor
    double getScale() {
      if (screenWidth >= 1200) return 1.3;
      if (screenWidth >= 900) return 1.15;
      if (screenWidth >= 600) return 1.0;
      if (screenWidth >= 400) return 0.9;
      return 0.8;
    }

    final scale = getScale();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      child: Container(
        padding: EdgeInsets.all(24 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24 * scale),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16 * scale,
              offset: Offset(0, 4 * scale),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Side - Text Content
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_getGreeting()}, $userName',
                    style: TextStyle(
                      fontSize: 28 * scale,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      fontFamily: 'poppins',
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 18 * scale,
                        color: Colors.black,
                        fontFamily: 'poppins',
                      ),
                      children: [
                        TextSpan(
                          text: 'Your Stress Level ',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        TextSpan(
                          text: 'is $stressText!', // Dynamic stress text
                          style: TextStyle(
                            color: stressColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16 * scale),

                  // Progress Bar with dynamic value
                  Stack(
                    children: [
                      // Background bar
                      Container(
                        height: 44 * scale,
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(8 * scale),
                        ),
                      ),
                      // Foreground progress bar
                      FractionallySizedBox(
                        widthFactor: mentalStress / 100.0, // Dynamic value
                        child: Container(
                          height: 44 * scale,
                          decoration: BoxDecoration(
                            color: stressColor,
                            borderRadius: BorderRadius.circular(8 * scale),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$mentalStress', // Dynamic value
                            style: TextStyle(
                              fontSize: 22 * scale,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: 'poppins',
                            ),
                          ),
                        ),
                      ),
                      // Total value
                      Positioned(
                        right: 16 * scale,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Text(
                            '100',
                            style: TextStyle(
                              fontSize: 22 * scale,
                              fontWeight: FontWeight.w600,
                              color: stressColor,
                              fontFamily: 'poppins',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12 * scale),

                  // Text(
                  //   'Your stress level is higher than usual',
                  //   style: TextStyle(
                  //     fontSize: 13 * scale,
                  //     color: Colors.black87,
                  //     fontFamily: 'poppins',
                  //     fontWeight: FontWeight.w400,
                  //   ),
                  // ),

                  // SizedBox(height: 16 * scale),

                  // Feeling Stress Button
                  ElevatedButton.icon(
                    onPressed: () {
                      // Use HC20Service to request fresh data (same as stress webhook)
                      final hc20Service =
                          Provider.of<HC20Service>(context, listen: false);

                      if (!hc20Service.isConnected) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.warning_amber,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 12),
                                Text(
                                    'No device connected. Please connect your HC20 first.'),
                              ],
                            ),
                            duration: const Duration(seconds: 3),
                            backgroundColor: Colors.red.shade600,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                        return;
                      }

                      // ✅ Show the stress alert confirmation dialog first
                      // The dialog will call requestFreshData(isStressAlert: true) when confirmed
                      _showStressAlertDialog(context);
                    },
                    icon: Icon(
                      Icons.notifications_active_rounded,
                      size: 20 * scale,
                    ),
                    label: Text(
                      'I\'m Feeling Stress',
                      style: TextStyle(
                        fontSize: 15 * scale,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'poppins',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFF5F5A),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20 * scale,
                        vertical: 14 * scale,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12 * scale),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: 16 * scale),

            // Right Side - Illustration
            Flexible(
              flex: 4,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 180 * scale,
                  maxHeight: 180 * scale,
                ),
                child: Image.asset(
                  'assets/images/home/cool-mind.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Responsive Health Metrics Grid matching Figma design
  Widget _buildHealthMetricsGrid(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // NEW: Get data from service
    final healthData = Provider.of<HealthDataService>(context);

    double getScale() {
      if (screenWidth >= 1200) return 1.3;
      if (screenWidth >= 900) return 1.15;
      if (screenWidth >= 600) return 1.0;
      if (screenWidth >= 400) return 0.9;
      return 0.8;
    }

    final scale = getScale();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 8 * scale,
        mainAxisSpacing: 8 * scale,
        childAspectRatio: 1.9,
        children: [
          _buildMetricCardNew(
            context,
            'Fatigue',
            '${healthData.fatigueLevel ?? "--"}/100', // Dynamic value
            _getFatigueLevelText(healthData.fatigueLevel),
            'assets/images/home/fatigue.png',
          ),
          _buildMetricCardNew(
            context,
            'Blood Pressure',
            healthData.bloodPressure != null
                ? '${healthData.bloodPressure![0]}/${healthData.bloodPressure![1]}' // Dynamic value
                : '--/--',
            'Normal',
            'assets/images/home/bp.png',
          ),
          _buildMetricCardNew(
            context,
            'Stress Resilience',
            '${healthData.stressResistance ?? "--"}/100', // Dynamic value
            _getResilienceText(healthData.stressResistance),
            'assets/images/home/stress-resilience.png',
          ),
          _buildMetricCardNew(
            context,
            'Regulation Ability',
            '${healthData.regulationAbility ?? "--"}/100', // Dynamic value
            'Normal',
            'assets/images/home/regulation-ability.png',
          ),
        ],
      ),
    );
  }

  // Helper methods for status text
  String _getFatigueLevelText(int? fatigue) {
    if (fatigue == null) return 'Unknown';
    if (fatigue >= 70) return 'High';
    if (fatigue >= 50) return 'Moderate';
    return 'Normal';
  }

  String _getResilienceText(int? resilience) {
    if (resilience == null) return 'Unknown';
    if (resilience >= 70) return 'Excellent';
    if (resilience >= 50) return 'Good';
    return 'Fair';
  }

  Widget _buildMetricCardNew(
    BuildContext context,
    String title,
    String value,
    String status,
    String imagePath,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;

    double getScale() {
      if (screenWidth >= 1200) return 1.3;
      if (screenWidth >= 900) return 1.15;
      if (screenWidth >= 600) return 1.0;
      if (screenWidth >= 400) return 0.9;
      return 0.8;
    }

    final scale = getScale();

    return Container(
      padding: EdgeInsets.all(10 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12 * scale,
            offset: Offset(0, 4 * scale),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title at top
          Text(
            title,
            style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              fontFamily: 'poppins',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6 * scale),

          // Content row with icon on right side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: Value and Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20 * scale,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        fontFamily: 'poppins',
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * scale,
                        vertical: 3 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: status == 'Good'
                            ? Color(0xFFD4EDC5)
                            : Color(0xFFD4EDC5),
                        borderRadius: BorderRadius.circular(20 * scale),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.w600,
                          color: status == 'Good'
                              ? Color(0xFF2E7D32)
                              : Color(0xFF2E7D32),
                          fontFamily: 'poppins',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4 * scale),
              // Right side: Icon
              Container(
                constraints: BoxConstraints(
                  maxWidth: 70 * scale,
                  maxHeight: 60 * scale,
                ),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Responsive Health Summary Section matching Figma design
  Widget _buildHealthSummarySection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // NEW: Get data from service
    final healthData = Provider.of<HealthDataService>(context);

    double getScale() {
      if (screenWidth >= 1200) return 1.3;
      if (screenWidth >= 900) return 1.15;
      if (screenWidth >= 600) return 1.0;
      if (screenWidth >= 400) return 0.9;
      return 0.8;
    }

    final scale = getScale();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.all(4 * scale),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20 * scale),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12 * scale,
                    offset: Offset(0, 4 * scale),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryItemNew(
                      context,
                      '${healthData.spo2 ?? "--"}%', // Dynamic SpO2
                      'SpO₂',
                      'assets/images/home/spo2.png',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40 * scale,
                    color: Colors.grey.shade300,
                    margin: EdgeInsets.symmetric(horizontal: 6 * scale),
                  ),
                  Expanded(
                    child: _buildSummaryItemNew(
                      context,
                      _calculateSleepDuration(healthData.sleepData),
                      'Sleep',
                      'assets/images/home/sleep.png',
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(4 * scale),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20 * scale),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12 * scale,
                    offset: Offset(0, 4 * scale),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryItemNew(
                      context,
                      '${healthData.calories ?? "--"}', // Dynamic calories from real-time data
                      'kcal',
                      'assets/images/home/kcal.png',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40 * scale,
                    color: Colors.grey.shade300,
                    margin: EdgeInsets.symmetric(horizontal: 6 * scale),
                  ),
                  Expanded(
                    child: _buildSummaryItemNew(
                      context,
                      '${healthData.steps ?? "--"}', // Dynamic steps
                      'Steps',
                      'assets/images/home/steps.png',
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

  Widget _buildSummaryItemNew(
    BuildContext context,
    String value,
    String label,
    String imagePath,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;

    double getScale() {
      if (screenWidth >= 1200) return 1.3;
      if (screenWidth >= 900) return 1.15;
      if (screenWidth >= 600) return 1.0;
      if (screenWidth >= 400) return 0.9;
      return 0.8;
    }

    final scale = getScale();

    return Row(
      children: [
        Container(
          width: 44 * scale,
          height: 44 * scale,
          padding: EdgeInsets.all(4 * scale),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(width: 8 * scale),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                fontFamily: 'poppins',
              ),
            ),
            SizedBox(height: 2 * scale),
            Text(
              label,
              style: TextStyle(
                fontSize: 12 * scale,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                fontFamily: 'poppins',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Helper function to calculate sleep duration from sleep data array
  String _calculateSleepDuration(List<int>? sleepData) {
    if (sleepData == null || sleepData.isEmpty) return '--';

    // Sleep data format: [status, deep, light, rem, awake]
    // Sum elements 1-4 (deep, light, rem, awake) for total sleep (skip status at index 0)
    int totalMinutes = 0;
    if (sleepData.length >= 5) {
      // Standard format: skip status at index 0
      totalMinutes = sleepData[1] + sleepData[2] + sleepData[3] + sleepData[4];
    } else if (sleepData.length == 4) {
      // If only 4 elements, sum all (no status field)
      totalMinutes = sleepData[0] + sleepData[1] + sleepData[2] + sleepData[3];
    } else if (sleepData.length > 0) {
      // Fallback: sum all available elements
      totalMinutes = sleepData.reduce((a, b) => a + b);
    }

    if (totalMinutes == 0) return '--';

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    // Show only hours to fit in card
    if (hours > 0) {
      return '${hours}h';
    } else if (minutes > 0) {
      return '<1h';
    } else {
      return '--';
    }
  }
}
