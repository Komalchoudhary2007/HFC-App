import 'package:flutter/material.dart';

class ClinicalScreen extends StatelessWidget {
  const ClinicalScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7E2FD),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBanner(),
            const SizedBox(height: 24),
            _buildOurExpertsSection(context),
            const SizedBox(height: 32),
            _buildServicesSection(context),
            const SizedBox(height: 32),
            _buildBookButton(context),
            const SizedBox(height: 32),
            _buildScreeningSection(context),
            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  // Get responsive scale factor
  double _getScaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 1.3;
    if (width >= 900) return 1.15;
    if (width >= 600) return 1.0;
    if (width >= 400) return 0.9;
    return 0.85;
  }

  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: Image.asset(
        'assets/images/clinic/clinic-banner.png',
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF532A7B),
                  const Color(0xFF7B1FA2),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: const Center(
              child: Text(
                'Banner Image',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScreeningSection(BuildContext context) {
    final scale = _getScaleFactor(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      child: Container(
        padding: EdgeInsets.all(10 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24 * scale),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left side - Illustration
            Expanded(
              flex: 4,
              child: Image.asset(
                'assets/images/clinic/early-screening.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200 * scale,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7E2FD),
                      borderRadius: BorderRadius.circular(16 * scale),
                    ),
                    child: Icon(
                      Icons.child_care,
                      size: 80 * scale,
                      color: const Color(0xFF532A7B),
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: 32 * scale),
            // Right side - Content
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Early Development Screening',
                    style: TextStyle(
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF532A7B),
                      fontFamily: 'poppins',
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  Text(
                    'Identify development concerns early and\nget expert-guided next steps',
                    style: TextStyle(
                      fontSize: 10 * scale,
                      fontWeight: FontWeight.w400,
                      color: Colors.black87,
                      fontFamily: 'poppins',
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF532A7B),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * scale,
                        vertical: 0,
                      ),
                      minimumSize: Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8 * scale),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Start Now',
                      style: TextStyle(
                        fontSize: 10 * scale,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'poppins',
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

  Widget _buildOurExpertsSection(BuildContext context) {
    final scale = _getScaleFactor(context);
    
    final experts = [
      {
        'name': 'Dr. Neha Srivastava',
        'title': 'Occupational therapist',
        'experience': '11+ y experience',
        'image': 'assets/images/clinic/nehaprofile.png',
      },
      {
        'name': 'Dr. Naveen Bharti',
        'title': 'Occupational Therapist',
        'experience': '3+ y experience',
        'image': 'assets/images/clinic/naveenprofile.png',
      },
      {
        'name': 'Mili Ghosh',
        'title': 'Speech therapist lead',
        'experience': '8+ y experience',
        'image': 'assets/images/clinic/milliprofile.png',
      },
      {
        'name': 'Dr. Priyanjali Rai',
        'title': 'ABA & Special Ed Lead',
        'experience': '5+ y experience',
        'image': 'assets/images/clinic/priyanjaliprofile.png',
      },
      {
        'name': 'Navya Rathi',
        'title': 'Language Pathologist',
        'experience': '4+ y experience',
        'image': 'assets/images/clinic/navyaprofile.png',
      },
      {
        'name': 'Dr. Manjeet',
        'title': 'PhysioTherapist',
        'experience': '3+ y experience',
        'image': 'assets/images/clinic/manjeetprofile.png',
      },
    ];
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Our Experts',
            style: TextStyle(
              fontSize: 18 * scale,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              fontFamily: 'poppins',
            ),
          ),
          SizedBox(height: 16 * scale),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12 * scale,
            crossAxisSpacing: 12 * scale,
            childAspectRatio: 2.2,
            children: experts.map((expert) => _buildExpertCard(
              context,
              scale,
              expert['name']!,
              expert['title']!,
              expert['experience']!,
              expert['image']!,
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpertCard(BuildContext context, double scale, String name, String title, String experience, String imagePath) {
    return Container(
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
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
            width: 48 * scale,
            height: 48 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
                onError: (error, stackTrace) {},
              ),
              color: const Color(0xFFE1BEE7),
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    fontFamily: 'poppins',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2 * scale),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                    fontFamily: 'poppins',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4 * scale),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * scale,
                    vertical: 3 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1BEE7),
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                  child: Text(
                    experience,
                    style: TextStyle(
                      fontSize: 9 * scale,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7B1FA2),
                      fontFamily: 'poppins',
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

  Widget _buildServicesSection(BuildContext context) {
    final scale = _getScaleFactor(context);
    
    final services = [
      {'title': 'Occupational\nTherapy', 'subtitle': 'Explore more info &\nclick here', 'image': 'assets/images/clinic/ot-clinic.png'},
      {'title': 'Speech\nTherapy', 'subtitle': 'Explore more info &\nclick here', 'image': 'assets/images/clinic/speech-clinic.png'},
      {'title': 'ABA\nTherapy', 'subtitle': 'Explore more info &\nclick here', 'image': 'assets/images/clinic/aba-clinic.png'},
      {'title': 'Special\nEducation', 'subtitle': 'Explore more info &\nclick here', 'image': 'assets/images/clinic/specialed-clinic.png'},
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services',
            style: TextStyle(
              fontSize: 18 * scale,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              fontFamily: 'poppins',
            ),
          ),
          SizedBox(height: 18 * scale),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 10 * scale,
            crossAxisSpacing: 10 * scale,
            childAspectRatio: 0.6,
            children: services.map((service) => _buildServiceCard(
              context,
              scale,
              service['title']!,
              service['subtitle']!,
              service['image']!,
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, double scale, String title, String subtitle, String imagePath) {
    return Container(
      padding: EdgeInsets.all(6 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48 * scale,
            height: 48 * scale,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12 * scale),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFE8E1EB),
                    child: Icon(
                      Icons.health_and_safety,
                      size: 40 * scale,
                      color: const Color(0xFF7B1FA2),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 12 * scale),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10 * scale,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              fontFamily: 'poppins',
              height: 1.2,
            ),
          ),
          SizedBox(height: 4 * scale),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8 * scale,
              fontWeight: FontWeight.w400,
              color: Colors.black54,
              fontFamily: 'poppins',
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookButton(BuildContext context) {
    final scale = _getScaleFactor(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF532A7B),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: 32 * scale,
            vertical: 16 * scale,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * scale),
          ),
          elevation: 4,
        ),
        child: Text(
          'Book Free Consultation',
          style: TextStyle(
            fontSize: 16 * scale,
            fontWeight: FontWeight.w700,
            fontFamily: 'poppins',
          ),
        ),
      ),
    );
  }
}
