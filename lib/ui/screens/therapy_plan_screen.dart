import 'package:flutter/material.dart';
import 'pdf_report_screen.dart';

class TherapyPlanScreen extends StatelessWidget {
  const TherapyPlanScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const PdfReportScreen(
      title: 'Therapy Plan',
      categories: 'therapy_plan',
      headerIcon: Icons.calendar_today_outlined,
      useStaticData: true,
    );
  }
}
