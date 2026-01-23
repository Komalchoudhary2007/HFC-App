import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class VitalsScreen extends StatelessWidget {
  const VitalsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite,
            size: 64,
            color: AppColors.heartRateRed,
          ),
          const SizedBox(height: 16),
          Text(
            'Vitals Screen',
            style: AppTextStyles.h2.copyWith(color: AppColors.primaryPurple),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your vital signs UI here',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
