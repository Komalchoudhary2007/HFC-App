import 'package:flutter/material.dart';

/// App color constants based on the HFC brand design
class AppColors {
  // Primary Brand Colors (from React design)
  static const Color primaryPurple = Color(0xFF532A7B);  // Main brand color
  static const Color primaryPurpleLight = Color(0xFF6D3699);  // Hover state
  static const Color primaryPurpleOpacity = Color(0x998C56C0);  // 60% opacity
  
  // Background Colors
  static const Color background = Color(0xFFE7E2FD);  // Light purple background
  static const Color cardBackground = Color(0xFFF8F1F9);  // Card background
  static const Color whiteBackground = Color(0xFFFFFFFF);
  static const Color bottomNavBackground = Color(0xFFFDF8FE);
  
  // Status Colors
  static const Color statusGreen = Color(0xFF1DB50F);  // Cool/Good status
  static const Color statusGreenLight = Color(0xFFD0EFD3);  // Green badge background
  static const Color statusGreenText = Color(0xFF3D7244);  // Green badge text
  static const Color statusRed = Color(0xFFFF5F5A);  // Stress/Alert button
  static const Color statusOrange = Color(0xFFFF9800);  // Warning
  
  // Vital Signs Colors (for health metrics)
  static const Color heartRateRed = Color(0xFFE53935);
  static const Color spo2Blue = Color(0xFF1E88E5);
  static const Color temperatureOrange = Color(0xFFFF6F00);
  static const Color stepsGreen = Color(0xFF43A047);
  
  // Connection Status Colors
  static const Color connected = Color(0xFF4CAF50);
  static const Color connecting = Color(0xFFFF9800);
  static const Color disconnected = Color(0xFF9E9E9E);
  static const Color error = Color(0xFFF44336);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF7376AA);  // Navigation text
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textHint = Color(0xFFBDBDBD);
  
  // Chart Colors
  static const List<Color> chartGradient = [
    Color(0xFF532A7B),
    Color(0xFF8C56C0),
  ];
}
