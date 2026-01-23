import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.textWhite,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person,
              size: 64,
              color: AppColors.primaryPurple,
            ),
            const SizedBox(height: 16),
            Text(
              'Profile Screen',
              style: AppTextStyles.h2.copyWith(color: AppColors.primaryPurple),
            ),
          ],
        ),
      ),
      backgroundColor: AppColors.background,
    );
  }
}
