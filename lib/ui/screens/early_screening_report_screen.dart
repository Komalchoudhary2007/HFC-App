import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/storage_service.dart';
import 'early_screening_detail_page.dart';

class EarlyScreeningReportScreen extends StatefulWidget {
  const EarlyScreeningReportScreen({Key? key}) : super(key: key);

  @override
  State<EarlyScreeningReportScreen> createState() => _EarlyScreeningReportScreenState();
}

class _EarlyScreeningReportScreenState extends State<EarlyScreeningReportScreen> {
  static const String _base = 'https://api.hireforcare.com/api';
  static const Color _purple = Color(0xFF532A7B);

  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<Map<String, String>> _headers() async {
    final token = await StorageService().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _fetchReports() async {
    setState(() { _loading = true; _error = null; });

    // Static data — no API call
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      _reports = [
        {'kidId': 'kid_001', 'kidName': 'Aarav Sharma', 'ageGroup': '36-48 months'},
        {'kidId': 'kid_002', 'kidName': 'Priya Patel', 'ageGroup': '24-36 months'},
        {'kidId': 'kid_003', 'kidName': 'Rohan Mehta', 'ageGroup': '48-60 months'},
      ];
      _loading = false;
    });
    return;

    // ignore: dead_code
    try {
      final h = await _headers();

      // Get userId from local storage (already saved at login — no API call needed)
      final user = await StorageService().getUser();
      final userId = user?.id?.toString() ?? '';
      print('📊 [EarlyScreening] userId from storage: $userId');

      if (userId.isEmpty) {
        setState(() { _error = 'Could not get user ID. Please log out and log in again.'; _loading = false; });
        return;
      }

      // Fetch early screening reports
      final res = await http.get(
        Uri.parse('$_base/early-screening-reports?userId=$userId'),
        headers: h,
      ).timeout(const Duration(seconds: 15));

      print('📊 [EarlyScreening] status: ${res.statusCode}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is List ? data : (data['reports'] ?? data['data'] ?? []);
        setState(() {
          _reports = List<Map<String, dynamic>>.from(list);
          _loading = false;
        });
      } else {
        throw Exception('Failed: ${res.statusCode} ${res.body.substring(0, res.body.length.clamp(0, 200))}');
      }
    } catch (e) {
      print('📊 [EarlyScreening] error: $e');
      setState(() { _error = 'Failed to load reports: $e'; _loading = false; });
    }
  }

  void _viewReport(Map<String, dynamic> report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EarlyScreeningDetailPage(
          kidId: report['kidId']?.toString() ?? '',
          kidName: report['kidName']?.toString() ?? 'Child',
          ageGroup: report['ageGroup']?.toString() ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        title: const Text('Early Screening Reports', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : _error != null ? _buildError()
          : _reports.isEmpty ? _buildEmpty()
          : _buildList(),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _fetchReports,
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
        ),
      ]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.assignment_outlined, size: 80, color: _purple.withOpacity(0.3)),
      const SizedBox(height: 16),
      const Text('No Screening Reports Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('Complete an early screening to see results here', style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
    ]),
  );

  Widget _buildList() => RefreshIndicator(
    onRefresh: _fetchReports,
    color: _purple,
    child: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (_, i) => _buildCard(_reports[i]),
    ),
  );

  Widget _buildCard(Map<String, dynamic> report) {
    final kidName = report['kidName']?.toString() ?? 'Child';
    final ageGroup = report['ageGroup']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.child_care_rounded, color: _purple, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kidName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              if (ageGroup.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(ageGroup, style: const TextStyle(fontSize: 12, color: _purple, fontWeight: FontWeight.w500)),
                ),
            ]),
          ),
          ElevatedButton(
            onPressed: () => _viewReport(report),
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('View', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
