import 'package:flutter/material.dart';

// Stub — PdfViewerPage web implementation not available on mobile
// Mobile uses url_launcher instead
class PdfViewerPage extends StatelessWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerPage({Key? key, required this.pdfUrl, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
