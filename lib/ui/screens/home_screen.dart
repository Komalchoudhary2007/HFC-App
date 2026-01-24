import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

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
                      Text(
                        'Synced with 1800s diff',
                        style: TextStyle(
                          color: Color(0xFF532A7B),
                          fontSize: 12,
                        ),
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
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      fontFamily: 'poppins',
                    ),
                  ),
                  Row(
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
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Health Metrics Grid - Responsive
            _buildHealthMetricsGrid(context),

            const SizedBox(height: 24),

            _buildHealthSummarySection(context),

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
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 2.2,
                      children: [
                        _buildServiceCard('Occupational Therapy', 'assets/images/home/occupational-therapy.png'),
                        _buildServiceCard('Speech Therapy', 'assets/images/home/speech-therapy.png'),
                        _buildServiceCard('ABA\nTherapy', 'assets/images/home/aba-therapy.png'),
                        _buildServiceCard('Special Education', 'assets/images/home/special-education.png'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF532A7B),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Book Free Consultation',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                            'Online Therapy',
                            'Home session by experts',
                            'assets/images/home/online-therapy.png',
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildTherapyCard(
                            'In-Centre Therapy',
                            'Support at our centre',
                            'assets/images/home/in-centre-therapy.png',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 100), // Space for bottom nav
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

  Widget _buildTherapyCard(String title, String description, String imagePath) {
    return Container(
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
    );
  }

  // Responsive Stress Level Card matching Figma design
  Widget _buildStressLevelCard(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
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
                    'Hello, Komal',
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
                          text: 'is Cool!',
                          style: TextStyle(
                            color: Color(0xFF2DD36F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16 * scale),
                  
                  // Progress Bar
                  Stack(
                    children: [
                      // Background bar
                      Container(
                        height: 44 * scale,
                        decoration: BoxDecoration(
                          color: Color(0xFFD4EDC5),
                          borderRadius: BorderRadius.circular(8 * scale),
                        ),
                      ),
                      // Foreground progress bar
                      FractionallySizedBox(
                        widthFactor: 0.51,
                        child: Container(
                          height: 44 * scale,
                          decoration: BoxDecoration(
                            color: Color(0xFF2DD36F),
                            borderRadius: BorderRadius.circular(8 * scale),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '51',
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
                              color: Color(0xFF2DD36F),
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
                    onPressed: () {},
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
            '62/100',
            'Normal',
            'assets/images/home/fatigue.png',
          ),
          _buildMetricCardNew(
            context,
            'Blood Pressure',
            '122/80',
            'Normal',
            'assets/images/home/bp.png',
          ),
          _buildMetricCardNew(
            context,
            'Stress Resilience',
            '72/100',
            'Good',
            'assets/images/home/stress-resilience.png',
          ),
          _buildMetricCardNew(
            context,
            'Regulation Ability',
            '70/100',
            'Normal',
            'assets/images/home/regulation-ability.png',
          ),
        ],
      ),
    );
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
                          '96%',
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
                          '7 h',
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
                          '1421',
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
                          '7 h',
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
}
