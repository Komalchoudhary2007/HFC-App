import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../screens/home_screen.dart';
import '../screens/vitals_screen.dart';
import '../screens/clinical_screen.dart';
import '../screens/connectivity_screen.dart';
import 'side_drawer.dart';
import 'app_top_bar.dart';
import '../../main.dart'
    show HC20HomePage; // Import HC20HomePage from main.dart

/// Main scaffold with bottom navigation bar, top app bar, and drawer
/// This wraps all main screens and provides consistent navigation
class MainScaffold extends StatefulWidget {
  const MainScaffold({Key? key}) : super(key: key);

  @override
  State<MainScaffold> createState() => MainScaffoldState();
}

class MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0; // Start with Device page (HC20HomePage) as default
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Public method to navigate to a specific tab index
  /// Can be called from child widgets using:
  /// context.findAncestorStateOfType<MainScaffoldState>()?.navigateToIndex(2);
  void navigateToIndex(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  // Screen titles for app bar
  final List<String> _titles = [
    'Home',
    'Clinical',
    'Vitals',
    'Device',
  ];

  // List of screens for bottom navigation
  final List<Widget> _screens = [
    const HomeScreen(),
    const ClinicalScreen(),
    const VitalsScreen(),
    const HC20HomePage(
        title: 'HFC App - HC20 Wearable'), // Device/Connectivity screen
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _showExitConfirmation(context);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor:
            _currentIndex == 0 ? const Color(0xFFE7E2FD) : AppColors.background,
        appBar: AppTopBar(
          onLogoTap: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          onDeviceIconTap: () {
            setState(() {
              _currentIndex = 3; // Navigate to Device screen
            });
          },
        ), // AppBar now shows on ALL screens including Device screen
        drawer: const SideDrawer(currentRoute: '/'),
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primaryPurple,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medical_services),
              label: 'Support',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Vitals',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.watch),
              label: 'Device',
            ),
          ],
        ),
      ),
    );
  }

  /// Show exit confirmation dialog with health-focused messaging
  Future<void> _showExitConfirmation(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF532A7B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.favorite,
                  color: Color(0xFF532A7B), size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Keep Monitoring?',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF532A7B)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF532A7B).withOpacity(0.05),
                    const Color(0xFF7B4BA8).withOpacity(0.05)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFF532A7B).withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.monitor_heart,
                          color: Colors.red.shade400, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Continuous health monitoring helps detect stress early',
                          style: TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.notifications_active,
                          color: Colors.orange.shade400, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Get instant alerts when vitals need attention',
                          style: TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Closing the app will pause health data collection.',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Column(
            children: [
              // Large "Stay Connected" button (primary action)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop('minimize'),
                  icon: const Icon(Icons.favorite_border, size: 24),
                  label: const Text(
                    'Stay Connected',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF532A7B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Exit App text below the button
              GestureDetector(
                onTap: () => Navigator.of(context).pop('exit'),
                child: Text(
                  'Exit App',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (result == 'minimize') {
      // Minimize app to background (like pressing home button - keeps running)
      // Using platform channel to call moveTaskToBack on Android
      const platform = MethodChannel('com.hfc.app/background');
      try {
        await platform.invokeMethod('moveToBackground');
      } catch (e) {
        // Fallback: just close the dialog and stay in app
        debugPrint('⚠️ Could not minimize: $e');
      }
    } else if (result == 'exit') {
      // Actually exit the app
      SystemNavigator.pop();
    }
    // If dismissed or null, do nothing (stay in app)
  }
}
