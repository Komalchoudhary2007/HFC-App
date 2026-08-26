import 'package:flutter/material.dart';
import 'pdf_report_screen.dart';

class ProgressReportScreen extends StatelessWidget {
  const ProgressReportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const PdfReportScreen(
      title: 'Progress Reports',
      categories: 'progress_report',
      headerIcon: Icons.trending_up_rounded,
      useStaticData: true,
    );
  }
}
