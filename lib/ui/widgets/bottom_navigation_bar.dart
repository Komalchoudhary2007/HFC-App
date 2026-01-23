import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../screens/home_screen.dart';
import '../screens/vitals_screen.dart';
import '../screens/clinical_screen.dart';
import '../screens/connectivity_screen.dart';
import 'side_drawer.dart';
import 'app_top_bar.dart';
import '../../main.dart' show HC20HomePage; // Import HC20HomePage from main.dart

/// Main scaffold with bottom navigation bar, top app bar, and drawer
/// This wraps all main screens and provides consistent navigation
class MainScaffold extends StatefulWidget {
  const MainScaffold({Key? key}) : super(key: key);

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0; // Start with Device page (HC20HomePage) as default
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    const HC20HomePage(title: 'HFC App - HC20 Wearable'), // Device/Connectivity screen
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _currentIndex == 0 ? const Color(0xFFE7E2FD) : AppColors.background,
      appBar: _currentIndex != 3 ? AppTopBar(
        onLogoTap: () {
          _scaffoldKey.currentState?.openDrawer();
        },
        onDeviceIconTap: () {
          setState(() {
            _currentIndex = 3; // Navigate to Device screen
          });
        },
      ) : null, // Hide app bar on Device screen (HC20HomePage has its own)
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
            label: 'Clinical',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Vitals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth_connected),
            label: 'Device',
          ),
        ],
      ),
    );
  }
}
