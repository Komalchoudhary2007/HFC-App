import 'package:flutter/material.dart';
import 'app_colors.dart';

/// App text style constants based on the HFC design
class AppTextStyles {
  // Large Headings (e.g., "Hello, Komal")
  static const TextStyle h1 = TextStyle(
    fontSize: 48,  // 5xl in React = ~48px
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  // Section Headings (e.g., "Health Summary")
  static const TextStyle h2 = TextStyle(
    fontSize: 36,  // 4xl in React = ~36px
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  
  // Card Headings (e.g., "Your Stress Level")
  static const TextStyle h3 = TextStyle(
    fontSize: 32,  // ~32px
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  
  // Sub-headings (e.g., "Fatigue", "Blood Pressure")
  static const TextStyle h4 = TextStyle(
    fontSize: 24,  // 3xl in React = ~24px
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  
  // Body Text Large (e.g., descriptions)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 20,  // 2xl in React
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  
  // Body Text Medium
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,  // base text
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  
  // Body Text Small
  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w300,
    color: AppColors.textPrimary,
  );
  
  // Large Metric Values (e.g., "62/100", "122/80")
  static const TextStyle metricValue = TextStyle(
    fontSize: 40,  // 40px in React
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFamily: 'Montserrat',  // As per React design
  );
  
  // Large Vital Values (e.g., "96%")
  static const TextStyle vitalValue = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  
  // Small Labels (e.g., "SpO2", "Sleep")
  static const TextStyle label = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w300,
    color: AppColors.textPrimary,
  );
  
  // Navigation Text
  static const TextStyle navText = TextStyle(
    fontSize: 20,  // 2xl in React
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  
  // Navigation Text Active
  static const TextStyle navTextActive = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryPurple,
  );
  
  // Button Text Large
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 32,  // 4xl in React
    fontWeight: FontWeight.w600,
    color: AppColors.textWhite,
  );
  
  // Button Text Medium
  static const TextStyle buttonMedium = TextStyle(
    fontSize: 24,  // 3xl in React
    fontWeight: FontWeight.w500,
    color: AppColors.textWhite,
  );
  
  // Status Badge Text
  static const TextStyle badgeText = TextStyle(
    fontSize: 20,  // 2xl in React
    fontWeight: FontWeight.w400,
    color: AppColors.statusGreenText,
  );
  
  // Caption Text
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w300,
    color: AppColors.textSecondary,
  );
}
