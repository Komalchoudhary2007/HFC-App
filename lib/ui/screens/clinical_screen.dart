import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ClinicalScreen extends StatelessWidget {
  const ClinicalScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services,
            size: 64,
            color: AppColors.primaryPurple,
          ),
          const SizedBox(height: 16),
          Text(
            'Clinical Screen',
            style: AppTextStyles.h2.copyWith(color: AppColors.primaryPurple),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your clinical data UI here',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
