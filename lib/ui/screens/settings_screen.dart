import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.textWhite,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings,
              size: 64,
              color: AppColors.primaryPurple,
            ),
            const SizedBox(height: 16),
            Text(
              'Settings Screen',
              style: AppTextStyles.h2.copyWith(color: AppColors.primaryPurple),
            ),
          ],
        ),
      ),
      backgroundColor: AppColors.background,
    );
  }
}
