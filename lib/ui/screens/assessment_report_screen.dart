import 'package:flutter/material.dart';
import 'pdf_report_screen.dart';

class AssessmentReportScreen extends StatelessWidget {
  const AssessmentReportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const PdfReportScreen(
      title: 'Assessment Reports',
      categories: 'speech_report,ot_report,aba_report,special_education_report',
      headerIcon: Icons.assignment_outlined,
      useStaticData: true,
    );
  }
}
