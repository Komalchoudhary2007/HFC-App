import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class VitalsScreen extends StatelessWidget {
  const VitalsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFFE7E2FD)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVitalsCard(context),
            const SizedBox(height: 16),
            _buildEnvironmentalCard(context),
            const SizedBox(height: 16),
            _buildSleepDataCard(context),
            const SizedBox(height: 16),
            _buildHRVMetricsCard(context),
            const SizedBox(height: 16),
            _buildHRV2MetricsCard(context),
            const SizedBox(height: 16),
            _buildTemperatureCard(context),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
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
              _buildCircularHeartRate(circleSize, scale), 
              SizedBox(width: 16 * scale),
              Expanded(
                child: _buildStatsGrid(context, scale),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCircularHeartRate(double size, double scale) {
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
                  '79',
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
              '96% SpO₂',
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

  Widget _buildStatsGrid(BuildContext context, double scale) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8 * scale,
      crossAxisSpacing: 8 * scale,
      childAspectRatio: 1.8,
      children: [
        _buildStatCard(context, '31.5°C', 'Temperature', Icons.thermostat_outlined, scale),
        _buildStatCard(context, '122/80', 'Blood Pressure', Icons.favorite_border, scale),
        _buildStatCard(context, '898', 'Steps', Icons.directions_walk, scale),
        _buildStatCard(context, '31%', 'Battery', Icons.battery_charging_full, scale),
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
                      '96868 Pa',
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
                      'Worn',
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
                '3h 2min',
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
                  flex: 48,
                  child: Container(
                    height: 24 * scale,
                    color: const Color(0xFF8DABEA),
                  ),
                ),
                Expanded(
                  flex: 138,
                  child: Container(
                    height: 24 * scale,
                    color: const Color(0xFFB0C1E6),
                  ),
                ),
                Expanded(
                  flex: 34,
                  child: Container(
                    height: 24 * scale,
                    color: const Color(0xFFEDCBEB),
                  ),
                ),
                Expanded(
                  flex: 2,
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
                '48 min',
                scale,
              ),
              _buildSleepStage(
                const Color(0xFFB0C1E6),
                'Light Sleep',
                '138 min',
                scale,
              ),
              _buildSleepStage(
                const Color(0xFFEDCBEB),
                'REM Sleep',
                '34 min',
                scale,
              ),
              _buildSleepStage(
                const Color(0xFFDDDDDD),
                'Awake',
                '2 min',
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
                '45,960',
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
                '4,233,783',
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
              Expanded(child: _buildCompactPillCard('Low Frequency', '777,621', scale)),
              SizedBox(width: 8 * scale),
              Expanded(child: _buildCompactPillCard('High Frequency', '1,515,727', scale)),
              SizedBox(width: 8 * scale),
              Expanded(child: _buildCompactPillCard('Very Low Frequency', '1,623,215', scale)),
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
              _buildCompactCircularRing('Mental\nStress', '46', const Color(0xFFC084FC), 0.46, scale),
              _buildCompactCircularRing('Fatigue', '39', const Color(0xFFF59E0B), 0.39, scale),
              _buildCompactCircularRing('Stress\nResistance', '62', const Color(0xFF22C55E), 0.62, scale),
              _buildCompactCircularRing('Regulation\nAbility', '47', const Color(0xFFA855F7), 0.47, scale),
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
              fontSize: 22 * scale,
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
              Expanded(child: _buildTempCard('Hand Temp', '31.62°C', scale)),
              SizedBox(width: 12 * scale),
              Expanded(child: _buildTempCard('Env Temp', '29.62°C', scale)),
              SizedBox(width: 12 * scale),
              Expanded(child: _buildTempCard('Body Temp', '36.09°C', scale)),
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
