import 'package:flutter/material.dart';
import '../widgets/appointment_booking_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class ClinicalScreen extends StatelessWidget {
  const ClinicalScreen({Key? key}) : super(key: key);

  // Brand colors
  static const Color _primaryPurple = Color(0xFF532A7B);
  static const Color _accentPurple = Color(0xFF7B4397);
  static const Color _lightPurple = Color(0xFFE7E2FD);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7E2FD),
      child: SingleChildScrollView(
        padding: EdgeInsets.zero, // Remove default padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBanner(),
            const SizedBox(height: 16),
            _buildOurExpertsSection(context),
            const SizedBox(height: 32),
            _buildServicesSection(context),
            const SizedBox(height: 32),
            _buildBookButton(context),
            const SizedBox(height: 32),
            // _buildScreeningSection(context),
            // const SizedBox(height: 32),
            _buildScreeningCTA(context),
            const SizedBox(height: 32),
            _buildTestimonialsSection(context),
            const SizedBox(height: 32),
            _buildContactSection(context),
            const SizedBox(height: 32), // Space for bottom nav
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
                    onPressed: () async {
                      final Uri url = Uri.parse('https://hireforcare.com/en');
                      try {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open website')),
                        );
                      }
                    },
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

  Widget _buildScreeningCTA(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative elements
            Positioned(
              right: -20,
              top: -20,
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
              left: -30,
              bottom: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '🎯 Free Assessment',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Early Development\nScreening',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Identify concerns early & get expert-guided next steps',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _launchUrl('https://hireforcare.com/en'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF667eea),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Start Now',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Image.asset(
                      'assets/images/clinic/early-screening.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.child_care_rounded,
                            size: 60,
                            color: Colors.white,
                          ),
                        );
                      },
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

  Widget _buildTestimonialsSection(BuildContext context) {
    final testimonials = [
      {
        'name': 'Priya M.',
        'text': 'The therapists here truly understand our children. My son has made incredible progress!',
        'rating': 5,
      },
      {
        'name': 'Rahul S.',
        'text': 'Professional, caring, and effective. Highly recommend for any parent seeking support.',
        'rating': 5,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'What Parents Say',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D2D2D),
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: testimonials.length,
            itemBuilder: (context, index) {
              final t = testimonials[index];
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_primaryPurple, _accentPurple],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              (t['name'] as String)[0],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t['name'] as String,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: List.generate(
                                  t['rating'] as int,
                                  (i) => const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.format_quote_rounded, color: _lightPurple, size: 30),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Text(
                        t['text'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
      {'title': 'Occupational\nTherapy', 'subtitle': 'Daily life skills &\nmotor development', 'image': 'assets/images/clinic/ot-clinic.png'},
      {'title': 'Speech\nTherapy', 'subtitle': 'Speech skills &\nlanguage development', 'image': 'assets/images/clinic/speech-clinic.png'},
      {'title': 'ABA\nTherapy', 'subtitle': 'Behavioral support &\nskill building', 'image': 'assets/images/clinic/aba-clinic.png'},
      {'title': 'Special\nEducation', 'subtitle': 'Learning support &\nacademic development', 'image': 'assets/images/clinic/specialed-clinic.png'},
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
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AppointmentBookingDialog(),
          );
        },
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

  Widget _buildContactSection(BuildContext context) {
    final scale = _getScaleFactor(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF532A7B),
              const Color(0xFF7B1FA2),
            ],
          ),
          borderRadius: BorderRadius.circular(24 * scale),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF532A7B).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(24 * scale),
              child: Column(
                children: [
                  Icon(
                    Icons.support_agent,
                    size: 48 * scale,
                    color: Colors.white,
                  ),
                  SizedBox(height: 12 * scale),
                  Text(
                    'Get In Touch',
                    style: TextStyle(
                      fontSize: 24 * scale,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'poppins',
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  Text(
                    'We\'re here to help you every step of the way',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.9),
                      fontFamily: 'poppins',
                    ),
                  ),
                ],
              ),
            ),

            // Contact Cards
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 16 * scale),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24 * scale),
                  bottomRight: Radius.circular(24 * scale),
                ),
              ),
              child: Column(
                children: [
                  // Quick Contact Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildContactButton(
                          context,
                          scale,
                          'Call',
                          Icons.phone,
                          const Color(0xFF4CAF50),
                          () => _launchUrl('tel:7688860000'),
                        ),
                      ),
                      SizedBox(width: 12 * scale),
                      Expanded(
                        child: _buildContactButton(
                          context,
                          scale,
                          'WhatsApp',
                            Icons.chat,
                          const Color(0xFF25D366),
                          () => _launchUrl('https://wa.me/917665553554'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16 * scale),

                  // Company Info
                  Container(
                    padding: EdgeInsets.all(16 * scale),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16 * scale),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HireForCare Pvt. Ltd.',
                          style: TextStyle(
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF532A7B),
                            fontFamily: 'poppins',
                          ),
                        ),
                        SizedBox(height: 12 * scale),
                        _buildInfoRow(context, scale, Icons.location_on, 'Andheri East, Mumbai - 400059'),
                        SizedBox(height: 8 * scale),
                        _buildInfoRow(context, scale, Icons.email, 'info@hireforcare.com'),
                        SizedBox(height: 8 * scale),
                        _buildInfoRow(context, scale, Icons.phone, '7688860000'),
                      ],
                    ),
                  ),
                  SizedBox(height: 16 * scale),

                  // Social Media & Map
                  Row(
                    children: [
                      // Social Media
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Follow Us',
                              style: TextStyle(
                                fontSize: 14 * scale,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                fontFamily: 'poppins',
                              ),
                            ),
                            SizedBox(height: 12 * scale),
                            Row(
                              children: [
                                _buildSocialIcon(context, scale, 'assets/icons/facebook.png', 
                                  () => _launchUrl('https://www.facebook.com/HireForCare/')),
                                SizedBox(width: 8 * scale),
                                _buildSocialIcon(context, scale, 'assets/icons/twitter.png', 
                                  () => _launchUrl('https://x.com/hireforcare')),
                                SizedBox(width: 8 * scale),
                                _buildSocialIcon(context, scale, 'assets/icons/linkedin.png', 
                                  () => _launchUrl('https://www.linkedin.com/company/hireforcare-private-limited/')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16 * scale),
                      // Map Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _launchUrl('https://www.google.com/maps?ll=28.569012,77.394978&z=16&t=m&hl=en&gl=IN&mapclient=embed&cid=9247350351208576211'),
                          icon: Icon(Icons.map, size: 20 * scale),
                          label: Text(
                            'View on Map',
                            style: TextStyle(
                              fontSize: 12 * scale,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'poppins',
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF532A7B),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16 * scale,
                              vertical: 12 * scale,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12 * scale),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactButton(BuildContext context, double scale, String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16 * scale),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32 * scale),
            SizedBox(height: 8 * scale),
            Text(
              label,
              style: TextStyle(
                fontSize: 14 * scale,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: 'poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, double scale, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18 * scale, color: const Color(0xFF532A7B)),
        SizedBox(width: 8 * scale),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12 * scale,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
              fontFamily: 'poppins',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(BuildContext context, double scale, String assetPath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40 * scale,
        height: 40 * scale,
        decoration: BoxDecoration(
          color: const Color(0xFF532A7B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: const Color(0xFF532A7B).withOpacity(0.3)),
        ),
        child: Center(
          child: Image.asset(
            assetPath,
            width: 24 * scale,
            height: 24 * scale,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to icons if images not found
              IconData fallbackIcon = Icons.public;
              if (assetPath.contains('facebook')) fallbackIcon = Icons.facebook;
              if (assetPath.contains('twitter')) fallbackIcon = Icons.flutter_dash;
              if (assetPath.contains('linkedin')) fallbackIcon = Icons.business;
              
              return Icon(
                fallbackIcon,
                size: 24 * scale,
                color: const Color(0xFF532A7B),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Could not launch $urlString');
    }
  }
}
