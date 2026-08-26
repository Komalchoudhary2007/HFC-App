import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/auth_service.dart';
import '../screens/video_library_screen.dart';
import '../screens/early_screening_report_screen.dart';
import '../screens/assessment_report_screen.dart';
import '../screens/therapy_plan_screen.dart';
import '../screens/progress_report_screen.dart';
import 'package:provider/provider.dart';

/// SideDrawer (formerly AppDrawer) - Navigation drawer with user profile and menu items
class SideDrawer extends StatelessWidget {
  final String currentRoute;
  
  const SideDrawer({
    Key? key,
    this.currentRoute = '/',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Drawer(
      child: Container(
        color: AppColors.whiteBackground,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Drawer Header with purple gradient
            Container(
              height: AppDimensions.drawerHeaderHeight,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.chartGradient,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.whiteBackground,
                    child: Text(
                      user?.name[0].toUpperCase() ?? 'U',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'User',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.textWhite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.phone ?? '',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textWhite,
                    ),
                  ),
                ],
              ),
            ),
            
            // Main Navigation Items
            _buildDrawerItem(
              context,
              icon: Icons.bluetooth_connected,
              title: 'Device Management',
              route: '/hc20',
              subtitle: 'Connect HC20 device',
            ),
            
            const Divider(),

            // _buildDrawerItem(
            //   context,
            //   icon: Icons.home,
            //   title: 'Home',
            //   route: '/home',
            //   subtitle: 'Dashboard',
            // ),
            // _buildDrawerItem(
            //   context,
            //   icon: Icons.medical_services,
            //   title: 'Clinical',
            //   route: '/clinical',
            //   subtitle: 'Clinical data',
            // ),
            // _buildDrawerItem(
            //   context,
            //   icon: Icons.favorite,
            //   title: 'Vitals',
            //   route: '/vitals',
            //   subtitle: 'Vital signs',
            // ),
            
            const Divider(),

            // Patient Pages
            _buildDrawerPageItem(
              context,
              icon: Icons.video_library_rounded,
              title: 'Video Library',
              page: const VideoLibraryScreen(),
            ),
            _buildDrawerPageItem(
              context,
              icon: Icons.child_care_rounded,
              title: 'Early Screening Reports',
              page: const EarlyScreeningReportScreen(),
            ),
            _buildDrawerPageItem(
              context,
              icon: Icons.assignment_outlined,
              title: 'Assessment Reports',
              page: const AssessmentReportScreen(),
            ),
            _buildDrawerPageItem(
              context,
              icon: Icons.calendar_today_outlined,
              title: 'Therapy Plan',
              page: const TherapyPlanScreen(),
            ),
            _buildDrawerPageItem(
              context,
              icon: Icons.trending_up_rounded,
              title: 'Progress Reports',
              page: const ProgressReportScreen(),
            ),

            const Divider(),

            _buildDrawerItem(
              context,
              icon: Icons.person,
              title: 'Profile',
              route: '/profile',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.settings,
              title: 'Settings',
              route: '/settings',
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await authService.logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Navigates by pushing a new page (for screens outside the main route map)
  Widget _buildDrawerPageItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget page,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: AppDimensions.iconL),
      title: Text(title, style: AppTextStyles.navText),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    String? subtitle,
  }) {
    final isSelected = currentRoute == route;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primaryPurple : AppColors.textSecondary,
        size: AppDimensions.iconL,
      ),
      title: Text(
        title,
        style: isSelected 
          ? AppTextStyles.navTextActive 
          : AppTextStyles.navText,
      ),
      subtitle: subtitle != null ? Text(
        subtitle,
        style: AppTextStyles.caption,
      ) : null,
      selected: isSelected,
      selectedTileColor: AppColors.primaryPurpleOpacity,
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (!isSelected) {
          Navigator.pushNamed(context, route);
        }
      },
    );
  }
}
