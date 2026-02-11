import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/health_data_service.dart';
import '../../services/device_status_service.dart';
import '../../services/hc20_service.dart';  // NEW: Import HC20Service for data refresh

class VitalsScreen extends StatelessWidget {
  const VitalsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final deviceStatus = Provider.of<DeviceStatusService>(context);
    
    return Container(
      decoration: const BoxDecoration(color: Color(0xFFE7E2FD)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Last Sync Indicator with Tap-to-Refresh
            GestureDetector(
              onTap: () => _handleRefreshData(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: deviceStatus.isRealtimeDataStale 
                      ? const Color(0xFFFFF3E0) 
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: deviceStatus.isRealtimeDataStale 
                        ? Colors.orange.withOpacity(0.3) 
                        : Colors.green.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      deviceStatus.isRealtimeDataStale ? Icons.warning_amber : Icons.check_circle,
                      color: deviceStatus.isRealtimeDataStale ? Colors.orange : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Last updated: ${deviceStatus.getLastRealtimeSyncText()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'poppins',
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.refresh,
                      color: deviceStatus.isRealtimeDataStale ? Colors.orange : Colors.green,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildVitalsCard(context),
            const SizedBox(height: 16),
            _buildTemperatureCard(context),
            const SizedBox(height: 16),
            _buildSleepDataCard(context),
            const SizedBox(height: 16),
            _buildHRVMetricsCard(context),
            const SizedBox(height: 16),
            _buildHRV2MetricsCard(context),
            const SizedBox(height: 16),
            _buildEnvironmentalCard(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Handle refresh data when user taps the Last Sync indicator
  Future<void> _handleRefreshData(BuildContext context) async {
    // Get HC20Service to request fresh data
    final hc20Service = Provider.of<HC20Service>(context, listen: false);
    
    // Check if device is connected
    if (!hc20Service.isConnected) {
      // Show error snackbar if not connected
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('No device connected. Please connect your HC20 first.'),
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
    
    // Show loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Syncing with device...'),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF532A7B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
    
    // Request fresh data from the device (triggers time sync)
    final success = await hc20Service.requestFreshData();
    
    // Show result
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(success ? 'Data refresh triggered!' : 'Failed to refresh. Please try again.'),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: success ? Colors.green.shade600 : Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // Get responsive scale factor based on screen width
  double _getScaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 1.4; // Extra large screens
    if (width >= 900) return 1.2;  // Large screens
    if (width >= 600) return 1.0;  // Medium screens
    return 0.9; // Small screens
  }

  Widget _buildVitalsCard(BuildContext context) {
    final scale = _getScaleFactor(context);
    final healthData = Provider.of<HealthDataService>(context);
    
    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: ShapeDecoration(
        color: const Color(0xFFF8F1F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * scale),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 4,
            offset: Offset(0, 4),
            spreadRadius: 0,
          )
        ],
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          // Calculate circle size based on available width
          // Make it smaller to fit alongside the grid
          final availableWidth = constraints.maxWidth;
          final screenWidth = MediaQuery.of(context).size.width;
          final baseSize = screenWidth <= 360 ? 110.0 : (availableWidth < 500 ? 140.0 : (availableWidth < 700 ? 160.0 : 180.0));
          final circleSize = baseSize * scale;
          
          // Always use horizontal layout
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCircularHeartRate(circleSize, scale, healthData), 
              SizedBox(width: 16 * scale),
              Expanded(
                child: _buildStatsGrid(context, scale, healthData),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCircularHeartRate(double size, double scale, HealthDataService healthData) {
    final heartRate = healthData.heartRate ?? 0;
    final spo2 = healthData.spo2 ?? 0;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF9C27B0).withOpacity(0.15),
                const Color(0xFFE91E63).withOpacity(0.15),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9C27B0).withOpacity(0.3),
                blurRadius: 20 * scale,
                spreadRadius: 2 * scale,
                offset: Offset(0, 8 * scale),
              ),
            ],
          ),
          child: Container(
            margin: EdgeInsets.all(8 * scale),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.8),
                ],
              ),
              border: Border.all(
                width: 3 * scale,
                color: Colors.white,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite,
                  color: const Color(0xFFE91E63),
                  size: size * 0.22,
                ),
                SizedBox(height: 8 * scale),
                Text(
                  heartRate > 0 ? '$heartRate' : '--',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: size * 0.25,
                    fontFamily: 'poppins',
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                Text(
                  'bpm',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: size * 0.08,
                    fontFamily: 'poppins',
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 4 * scale),
                CustomPaint(
                  size: Size(size * 0.4, size * 0.1),
                  painter: ECGWavePainter(),
                ),
              ],
            ),
          ),
        ),
        // Floating SpO2 Badge
        Positioned(
          top: -8 * scale,
          left: -8 * scale,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20 * scale),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8 * scale,
                  offset: Offset(0, 4 * scale),
                ),
              ],
            ),
            child: Text(
              spo2 > 0 ? '$spo2% SpO₂' : '--% SpO₂',
              style: TextStyle(
                color: const Color(0xFF9C27B0),
                fontSize: size * 0.065,
                fontFamily: 'poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context, double scale, HealthDataService healthData) {
    // Get dynamic values from service
    final rri = healthData.rri != null 
        ? '${healthData.rri} ms' 
        : '-- ms';
    final bloodPressure = healthData.bloodPressure != null 
        ? '${healthData.bloodPressure![0]}/${healthData.bloodPressure![1]}' 
        : '--/--';
    final steps = healthData.steps != null ? '${healthData.steps}' : '--';
    final distance = healthData.distance != null ? '${healthData.distance}m' : '--m';
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8 * scale,
      crossAxisSpacing: 8 * scale,
      childAspectRatio: 1.8,
      children: [
        _buildStatCard(context, rri, 'RRI', Icons.favorite_border, scale),
        _buildStatCard(context, bloodPressure, 'Blood Pressure', Icons.monitor_heart, scale),
        _buildStatCard(context, steps, 'Steps', Icons.directions_walk, scale),
        _buildStatCard(context, distance, 'Distance', Icons.straighten, scale),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label, IconData icon, double scale) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth <= 360;
    
    return Container(
      padding: EdgeInsets.all(6 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFFEEE9FF),
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.08),
            blurRadius: 8 * scale,
            offset: Offset(0, 3 * scale),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: isSmallScreen ? 10 * scale : 12 * scale,
                    fontFamily: 'poppins',
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                icon,
                color: const Color(0xFF9C27B0).withOpacity(0.6),
                size: isSmallScreen ? 14 * scale : 16 * scale,
              ),
            ],
          ),
          SizedBox(height: 2 * scale),
          Text(
            label,
            style: TextStyle(
              color: Colors.black.withOpacity(0.6),
              fontSize: isSmallScreen ? 8 * scale : 10 * scale,
              fontFamily: 'poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Removed _buildMetricCard - replaced with _buildStatCard

  Widget _buildEnvironmentalCard(BuildContext context) {
    final scale = _getScaleFactor(context);
    final healthData = Provider.of<HealthDataService>(context);
    
    // Get barometric pressure and wear status
    final baroPressure = healthData.barometricPressure;
    final wearStatus = healthData.wearStatus;
    
    return Container(
      padding: EdgeInsets.all(20 * scale),  
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * scale),
        ),
        shadows: [
          BoxShadow(
            color: const Color(0x3F000000),
            blurRadius: 4 * scale,
            offset: Offset(0, 4 * scale),
            spreadRadius: 0,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Environmental',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18 * scale,
              fontFamily: 'poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16 * scale),
          Container(
            height: 1.5,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 20 * scale),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Barometric Pressure',   
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14 * scale,  
                        fontFamily: 'poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8 * scale),
                    Text(
                      baroPressure != null ? '$baroPressure Pa' : '-- Pa',
                      style: TextStyle(
                        color: const Color(0xFF2D1B4E),
                        fontSize: 16 * scale,
                        fontFamily: 'poppins',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1.5,
                height: 60 * scale,
                color: Colors.grey.shade300,
                margin: EdgeInsets.symmetric(horizontal: 16 * scale),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wear Status',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14 * scale,
                        fontFamily: 'poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8 * scale),
                    Text(
                      wearStatus != null 
                        ? (wearStatus == 1 ? 'Worn' : 'Not Worn')
                        : '--',
                      style: TextStyle(
                        color: const Color(0xFF532A7B),
                        fontSize: 16 * scale,
                        fontFamily: 'poppins',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepDataCard(BuildContext context) {
    final scale = _getScaleFactor(context);
    final healthData = Provider.of<HealthDataService>(context);
    
    // Get sleep data: [status, deep, light, rem, awake]
    final sleepData = healthData.sleepData ?? [0, 0, 0, 0, 0];
    
    // Calculate total duration (skip status at index 0, sum indices 1-4)
    int totalMinutes = 0;
    if (sleepData.length >= 5) {
      totalMinutes = sleepData[1] + sleepData[2] + sleepData[3] + sleepData[4];
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final durationText = totalMinutes > 0 ? '${hours}h ${minutes}min' : '--';
    
    // Get individual sleep stages (indices 1-4)
    final deepSleep = sleepData.length >= 5 ? sleepData[1] : 0;
    final lightSleep = sleepData.length >= 5 ? sleepData[2] : 0;
    final remSleep = sleepData.length >= 5 ? sleepData[3] : 0;
    final awake = sleepData.length >= 5 ? sleepData[4] : 0;
    
    // Ensure flex values are at least 1 to avoid rendering errors
    final deepFlex = deepSleep > 0 ? deepSleep : 1;
    final lightFlex = lightSleep > 0 ? lightSleep : 1;
    final remFlex = remSleep > 0 ? remSleep : 1;
    final awakeFlex = awake > 0 ? awake : 1;
    
    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: ShapeDecoration(
        color: const Color(0xFFF8F1F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * scale),
        ),
        shadows: [
          BoxShadow(
            color: const Color(0x3F000000),
            blurRadius: 4 * scale,
            offset: Offset(0, 4 * scale),
            spreadRadius: 0,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sleep Data',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18 * scale,
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),  
              Text(   
                durationText,
                style: TextStyle( 
                  color: Colors.black,
                  fontSize: 20 * scale,
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w600,
                ),  
              ),
            ],
          ),
          SizedBox(height: 20 * scale),
          Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 20 * scale),
          ClipRRect(
            borderRadius: BorderRadius.circular(4 * scale),
            child: Row(
              children: [
                Expanded(
                  flex: deepFlex,
                  child: Container(
                    height: 24 * scale,
                    color: const Color(0xFF8DABEA),
                  ),
                ),
                Expanded(
                  flex: lightFlex,
                  child: Container(
                    height: 24 * scale,
                    color: const Color(0xFFB0C1E6),
                  ),
                ),
                Expanded(
                  flex: remFlex,
                  child: Container(
                    height: 24 * scale,
                    color: const Color(0xFFEDCBEB),
                  ),
                ),
                Expanded(
                  flex: awakeFlex,
                  child: Container(
                    height: 24 * scale,
                    color: const Color(0xFFDDDDDD),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSleepStage(
                const Color(0xFF8DABEA),
                'Deep Sleep',
                '$deepSleep min',
                scale,
              ),
              _buildSleepStage(
                const Color(0xFFB0C1E6),
                'Light Sleep',
                '$lightSleep min',
                scale,
              ),
              _buildSleepStage(
                const Color(0xFFEDCBEB),
                'REM Sleep',
                '$remSleep min',
                scale,
              ),
              _buildSleepStage(
                const Color(0xFFDDDDDD),
                'Awake',
                '$awake min',
                scale,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepStage(Color color, String label, String duration, double scale) {
    return Column(
      children: [
        Container(
          width: 20 * scale,
          height: 20 * scale,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4 * scale),
          ),
        ),
        SizedBox(height: 8 * scale),
        Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: 10 * scale,
            fontFamily: 'poppins',
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4 * scale),
        Text(
          duration,
          style: TextStyle(
            color: Colors.black,
            fontSize: 16 * scale,
            fontFamily: 'poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHRVMetricsCard(BuildContext context) {
    final scale = _getScaleFactor(context);
    final healthData = Provider.of<HealthDataService>(context);
    
    // Get dynamic HRV values
    final sdnn = healthData.sdnn ?? 0;
    final totalPower = healthData.totalPower ?? 0;
    final lowFrequency = healthData.lowFrequency ?? 0;
    final highFrequency = healthData.highFrequency ?? 0;
    final veryLowFrequency = healthData.veryLowFrequency ?? 0;
    
    return Container(
      padding: EdgeInsets.all(24 * scale),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF5F0FF),
            const Color(0xFFEDE7FF),
          ],
        ),
        borderRadius: BorderRadius.circular(24 * scale),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.1),
            blurRadius: 20 * scale,
            offset: Offset(0, 8 * scale),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HRV Metrics',
            style: TextStyle(
              color: const Color(0xFF2D1B4E),
              fontSize: 18 * scale,
              fontFamily: 'poppins',
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12 * scale),
          Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF9C27B0).withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SizedBox(height: 18 * scale),
          
          // Top Row: SDNN and Total Power in one box
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'SDNN',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.7),
                  fontSize: 14 * scale,
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 16 * scale),
              Text(
                sdnn > 0 ? '$sdnn' : '--',
                style: TextStyle(
                  color: const Color(0xFF2E7D32),
                  fontSize: 14 * scale,
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 40 * scale),
              Text(
                'Total Power',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.7),
                  fontSize: 14 * scale,
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 16 * scale),
              Text(
                totalPower > 0 ? '$totalPower' : '--',
                style: TextStyle(
                  color: const Color(0xFF2E7D32),
                  fontSize: 14 * scale,
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 20 * scale),
          
          // Bottom Row: Three Pill Cards in One Row
          Row(
            children: [
              Expanded(child: _buildCompactPillCard(
                'Low Frequency',
                lowFrequency > 0 ? '$lowFrequency' : '--',
                scale
              )),
              SizedBox(width: 8 * scale),
              Expanded(child: _buildCompactPillCard(
                'High Frequency',
                highFrequency > 0 ? '$highFrequency' : '--',
                scale
              )),
              SizedBox(width: 8 * scale),
              Expanded(child: _buildCompactPillCard(
                'Very Low Frequency',
                veryLowFrequency > 0 ? '$veryLowFrequency' : '--',
                scale
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPillCard(String label, String value, double scale) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * scale),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.1),
            blurRadius: 6 * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
      ),
      child: Column(
        children: [
          // Purple Header Tab
          Container(
            padding: EdgeInsets.symmetric(vertical: 6 * scale, horizontal: 8 * scale),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF9C27B0),
                  Color(0xFF7B1FA2),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14 * scale),
                topRight: Radius.circular(14 * scale),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9 * scale,
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Light Body
          Container(
            padding: EdgeInsets.symmetric(vertical: 10 * scale, horizontal: 6 * scale),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFCE4EC).withOpacity(0.7),
                  const Color(0xFFF3E5F5).withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(14 * scale),
                bottomRight: Radius.circular(14 * scale),
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    color: const Color(0xFF2D1B4E),
                    fontSize: 14 * scale,
                    fontFamily: 'poppins',
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

  Widget _buildHRV2MetricsCard(BuildContext context) {
    final scale = _getScaleFactor(context);
    final healthData = Provider.of<HealthDataService>(context);
    
    // Get dynamic HRV2 values
    final mentalStress = healthData.mentalStress ?? 0;
    final fatigue = healthData.fatigueLevel ?? 0;
    final stressResistance = healthData.stressResistance ?? 0;
    final regulationAbility = healthData.regulationAbility ?? 0;
    
    return Container(
      padding: EdgeInsets.all(24 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EDFF),
        borderRadius: BorderRadius.circular(24 * scale),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.1),
            blurRadius: 20 * scale,
            offset: Offset(0, 8 * scale),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HRV2 Metrics',
            style: TextStyle(
              color: const Color(0xFF2D1B4E),
              fontSize: 18 * scale,
              fontFamily: 'poppins',
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12 * scale),
          Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF9C27B0).withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SizedBox(height: 20 * scale),
          // All 4 rings in one row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCompactCircularRing(
                'Mental\nStress', 
                mentalStress > 0 ? '$mentalStress' : '--', 
                const Color(0xFFC084FC), 
                mentalStress / 100.0, 
                scale
              ),
              _buildCompactCircularRing(
                'Fatigue', 
                fatigue > 0 ? '$fatigue' : '--', 
                const Color(0xFFF59E0B), 
                fatigue / 100.0, 
                scale
              ),
              _buildCompactCircularRing(
                'Stress\nResistance', 
                stressResistance > 0 ? '$stressResistance' : '--', 
                const Color(0xFF22C55E), 
                stressResistance / 100.0, 
                scale
              ),
              _buildCompactCircularRing(
                'Regulation\nAbility', 
                regulationAbility > 0 ? '$regulationAbility' : '--', 
                const Color(0xFFA855F7), 
                regulationAbility / 100.0, 
                scale
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCircularRing(String label, String value, Color ringColor, double progress, double scale) {
    // Increase base size for larger screens
    double baseSize;
    if (scale >= 1.4) {
      baseSize = 90.0;  // Extra large screens
    } else if (scale >= 1.2) {
      baseSize = 80.0;  // Large screens
    } else if (scale >= 1.0) {
      baseSize = 70.0;  // Medium screens
    } else {
      baseSize = 60.0;  // Small screens
    }
    final ringSize = baseSize * scale;
    return Column(
      children: [
        Container(
          width: ringSize,
          height: ringSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ringColor.withOpacity(0.12),
                blurRadius: 8 * scale,
                offset: Offset(0, 2 * scale),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background circle
              Center(
                child: Container(
                  width: ringSize,
                  height: ringSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: ringColor.withOpacity(0.2),
                      width: 1.5 * scale,
                    ),
                  ),
                ),
              ),
              // Progress ring
              Center(
                child: SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: CustomPaint(
                    painter: CircularRingPainter(
                      progress: progress,
                      ringColor: ringColor,
                      strokeWidth: 6 * scale,
                    ),
                  ),
                ),
              ),
              // Center value
              Center(
                child: Text(
                  value,
                  style: TextStyle(
                    color: const Color(0xFF2D1B4E),
                    fontSize: 22 * scale,
                    fontFamily: 'poppins',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 6 * scale),
        SizedBox(
          width: ringSize,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.7),
              fontSize: 8 * scale,
              fontFamily: 'poppins',
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemperatureCard(BuildContext context) {
    final scale = _getScaleFactor(context);
    final healthData = Provider.of<HealthDataService>(context);
    
    // Get temperature array: [wrist, ambient, body]
    final tempArray = healthData.temperatureArray;
    
    String handTempStr = '--°C';
    String envTempStr = '--°C';
    String bodyTempStr = '--°C';
    
    if (tempArray != null && tempArray.length >= 3) {
      handTempStr = '${tempArray[0].toStringAsFixed(1)}°C';
      envTempStr = '${tempArray[1].toStringAsFixed(1)}°C';
      bodyTempStr = '${tempArray[2].toStringAsFixed(1)}°C';
    }
    
    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * scale),
        ),
        shadows: [
          BoxShadow(
            color: const Color(0x1A000000),
            blurRadius: 8 * scale,
            offset: Offset(0, 2 * scale),
            spreadRadius: 0,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Temperature',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18 * scale,
              fontFamily: 'poppins',
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12 * scale),
          Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey.shade300,
                  Colors.grey.shade200,
                  Colors.grey.shade100,
                ],
              ),
            ),
          ),
          SizedBox(height: 20 * scale),
          Row(
            children: [
              Expanded(child: _buildTempCard('Hand Temp', handTempStr, scale)),
              SizedBox(width: 12 * scale),
              Expanded(child: _buildTempCard('Env Temp', envTempStr, scale)),
              SizedBox(width: 12 * scale),
              Expanded(child: _buildTempCard('Body Temp', bodyTempStr, scale)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTempCard(String label, String value, double scale) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * scale),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.08),
            blurRadius: 6 * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
      ),
      child: Column(
        children: [
          // Purple Header
          Container(
            padding: EdgeInsets.symmetric(vertical: 10 * scale, horizontal: 12 * scale),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF9C27B0),
                  Color(0xFFBA68C8),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14 * scale),
                topRight: Radius.circular(14 * scale),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13 * scale,
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Light Pink/Lavender Body
          Container(
            padding: EdgeInsets.symmetric(vertical: 16 * scale, horizontal: 12 * scale),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFE1BEE7).withOpacity(0.5),
                  const Color(0xFFF3E5F5).withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(14 * scale),
                bottomRight: Radius.circular(14 * scale),
              ),
            ),
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: 20 * scale,
                  fontFamily: 'poppins',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for ECG wave line
class ECGWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE91E63)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    path.moveTo(0, centerY);
    path.lineTo(width * 0.2, centerY);
    path.lineTo(width * 0.25, centerY - height * 0.3);
    path.lineTo(width * 0.3, centerY + height * 0.5);
    path.lineTo(width * 0.35, centerY - height * 0.2);
    path.lineTo(width * 0.4, centerY);
    path.lineTo(width * 0.55, centerY);
    path.lineTo(width * 0.6, centerY - height * 0.3);
    path.lineTo(width * 0.65, centerY + height * 0.5);
    path.lineTo(width * 0.7, centerY - height * 0.2);
    path.lineTo(width * 0.75, centerY);
    path.lineTo(width, centerY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Custom painter for circular ring progress indicator
class CircularRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final double strokeWidth;

  CircularRingPainter({
    required this.progress,
    required this.ringColor,
    this.strokeWidth = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw the progress arc
    final progressPaint = Paint()
      ..color = ringColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -90 * 3.14159 / 180;
    final sweepAngle = 2 * 3.14159 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
