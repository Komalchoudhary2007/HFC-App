import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/storage_service.dart';

class EarlyScreeningDetailPage extends StatefulWidget {
  final String kidId;
  final String kidName;
  final String ageGroup;

  const EarlyScreeningDetailPage({
    Key? key,
    required this.kidId,
    required this.kidName,
    required this.ageGroup,
  }) : super(key: key);

  @override
  State<EarlyScreeningDetailPage> createState() => _EarlyScreeningDetailPageState();
}

class _EarlyScreeningDetailPageState extends State<EarlyScreeningDetailPage> {
  static const String _base = 'https://api.hireforcare.com/api';
  static const Color _purple = Color(0xFF532A7B);

  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<Map<String, String>> _headers() async {
    final token = await StorageService().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _fetchReport() async {
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      _report = {
        'childName': widget.kidName,
        'childDOB': '2021-03-15',
        'ageInMonths': 43,
        'questionAgeGroup': widget.ageGroup.isNotEmpty ? widget.ageGroup : '39-45 months',
        'generatedAt': '2025-06-06T05:57:16Z',
        'overallStatus': 'Attention',
        'categories': {
          'Communication': {
            'answers': [
              {'number': 1, 'response': 'yes', 'score': 10},
              {'number': 2, 'response': 'no', 'score': 0},
              {'number': 3, 'response': 'yes', 'score': 10},
              {'number': 4, 'response': 'yes', 'score': 10},
              {'number': 5, 'response': 'yes', 'score': 10},
              {'number': 6, 'response': 'yes', 'score': 10},
            ],
            'total': 50, 'max': 60, 'cutoff': 27, 'monitor': 38, 'status': 'On Track',
          },
          'Gross Motor': {
            'answers': [
              {'number': 1, 'response': 'no', 'score': 0},
              {'number': 2, 'response': 'yes', 'score': 10},
              {'number': 3, 'response': 'no', 'score': 0},
              {'number': 4, 'response': 'no', 'score': 0},
              {'number': 5, 'response': 'no', 'score': 0},
              {'number': 6, 'response': 'yes', 'score': 10},
            ],
            'total': 20, 'max': 60, 'cutoff': 36, 'monitor': 45, 'status': 'Attention',
          },
          'Fine Motor': {
            'answers': [
              {'number': 1, 'response': 'yes', 'score': 10},
              {'number': 2, 'response': 'yes', 'score': 10},
              {'number': 3, 'response': 'no', 'score': 0},
              {'number': 4, 'response': 'yes', 'score': 10},
              {'number': 5, 'response': 'yes', 'score': 10},
              {'number': 6, 'response': 'sometimes', 'score': 5},
            ],
            'total': 45, 'max': 60, 'cutoff': 20, 'monitor': 33, 'status': 'On Track',
          },
          'Problem Solving': {
            'answers': [
              {'number': 1, 'response': 'yes', 'score': 10},
              {'number': 2, 'response': 'yes', 'score': 10},
              {'number': 3, 'response': 'sometimes', 'score': 5},
              {'number': 4, 'response': 'no', 'score': 0},
              {'number': 5, 'response': 'yes', 'score': 10},
              {'number': 6, 'response': 'yes', 'score': 10},
            ],
            'total': 45, 'max': 60, 'cutoff': 28, 'monitor': 39, 'status': 'Monitor',
          },
          'Personal Social': {
            'answers': [
              {'number': 1, 'response': 'yes', 'score': 10},
              {'number': 2, 'response': 'yes', 'score': 10},
              {'number': 3, 'response': 'yes', 'score': 10},
              {'number': 4, 'response': 'no', 'score': 0},
              {'number': 5, 'response': 'yes', 'score': 10},
              {'number': 6, 'response': 'yes', 'score': 10},
            ],
            'total': 50, 'max': 60, 'cutoff': 31, 'monitor': 41, 'status': 'On Track',
          },
        },
        'overall': {
          'status': 'Attention',
          'flaggedCount': 5,
          'answers': [
            {'number': 1, 'response': 'yes', 'flagged': true, 'question': 'Does the child respond to their name?'},
            {'number': 2, 'response': 'no', 'flagged': true, 'question': 'Can the child jump with both feet?'},
            {'number': 3, 'response': 'yes', 'flagged': false, 'question': 'Does the child use 2-word phrases?'},
            {'number': 4, 'response': 'no', 'flagged': true, 'question': 'Can the child kick a ball forward?'},
            {'number': 5, 'response': 'sometimes', 'flagged': true, 'question': 'Does the child play with other children?'},
            {'number': 6, 'response': 'yes', 'flagged': false, 'question': 'Can the child draw a circle?'},
            {'number': 7, 'response': 'no', 'flagged': true, 'question': 'Does the child follow 2-step instructions?'},
          ],
        },
        'recommendations': {
          'Gross Motor': {
            'level': 'attention',
            'title': 'Gross Motor Activities (Strength & Coordination)',
            'activities': [
              {'name': 'Jumping & Balancing', 'description': 'Create engaging obstacle courses and incorporate playful hopping games to build balance and coordination.'},
              {'name': 'Kicking & Throwing Balls', 'description': 'Engage in enjoyable ball activities to develop and strengthen coordination skills.'},
              {'name': 'Dancing to Music', 'description': 'Support physical development by encouraging movement and action songs.'},
            ],
          },
        },
        'ai_recommendation': '${widget.kidName} would benefit from focused attention on gross motor development. Try movement-based activities daily for 4 weeks, starting with easier variations and gradually increasing the challenge as confidence grows.',
      };
      _loading = false;
    });
  }

  Widget _headerContact(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: Colors.white70, size: 13),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11))),
    ],
  );

  Widget _childMeta(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Expanded(
        child: Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3B247A))),
      ),
    ],
  );

  int _calcPct(Map<String, dynamic> categories) {
    if (categories.isEmpty) return 0;
    num totalScore = 0, maxTotal = 0;
    for (final c in categories.values) {
      if (c is Map) {
        totalScore += (c['total'] ?? 0) as num;
        maxTotal += (c['max'] ?? 0) as num;
      }
    }
    return maxTotal > 0 ? (totalScore / maxTotal * 100).round() : 0;
  }

  String _formatDOB(String? dob) {
    if (dob == null || dob.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(dob);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) { return dob; }
  }

  String _formatAge(dynamic months) {
    if (months == null) return 'N/A';
    final m = (months as num).toInt();
    final y = m ~/ 12;
    final rem = m % 12;
    if (y == 0) return '$rem months';
    return '$y yr $rem mo';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(dateStr);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) { return dateStr; }
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('on track') || s.contains('typical') || s.contains('normal')) return const Color(0xFF10B981);
    if (s.contains('monitor')) return const Color(0xFFF59E0B);
    if (s.contains('attention') || s.contains('concern') || s.contains('delay')) return Colors.red;
    return _purple;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        title: Text(widget.kidName,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: _purple,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : _error != null ? _buildError()
          : _buildSinglePage(),
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
          onPressed: _fetchReport,
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
        ),
      ]),
    ),
  );

  Widget _buildSinglePage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewSection(),
          const Divider(height: 1, thickness: 1),
          _buildCategoriesSection(),
          const Divider(height: 1, thickness: 1),
          _buildProfileSection(),
          const Divider(height: 1, thickness: 1),
          _buildQuestionResponseTracker(),
          const Divider(height: 1, thickness: 1),
          _buildOverallConcerns(),
          _buildRecommendedActivities(),
          _buildAiInsights(),
          _buildNextSteps(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Overview ──────────────────────────────────────────────────────────────

  Widget _buildOverviewSection() {
    final report = _report!;
    final status = report['overall_status']?.toString() ?? report['overallStatus']?.toString() ?? 'Unknown';
    final categories = Map<String, dynamic>.from(report['categories'] ?? {});
    final rawOverall = report['overall'];
    final overallList = rawOverall is List ? rawOverall : (rawOverall is Map ? (rawOverall['answers'] ?? []) : []);
    final overall = List<Map<String, dynamic>>.from(
      (overallList as List).map((e) => Map<String, dynamic>.from(e as Map))
    );
    final statusColor = _statusColor(status);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header card
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: const Color(0xFF3B247A),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/therapy-plan/occupational-therapy/header-bg.png',
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.65),
                    colorBlendMode: BlendMode.darken,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    width: 120,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B247A).withOpacity(0.4),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                    child: Image.network(
                      'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/therapy-plan/occupational-therapy/hireforcare-left.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 140, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Development Screening Report',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Special Child Centre By HireForCare',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 14),
                      _headerContact(Icons.phone, '7688860000'),
                      const SizedBox(height: 4),
                      _headerContact(Icons.email_outlined, 'info@hireforcare.com'),
                      const SizedBox(height: 4),
                      _headerContact(Icons.location_on_outlined, '2nd Floor, Tenex Tower, Sector 116, Noida'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Child info + score ring
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report['childName']?.toString() ?? widget.kidName,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF3B247A)),
                          ),
                          const SizedBox(height: 12),
                          _childMeta('DOB', _formatDOB(report['childDOB']?.toString())),
                          const SizedBox(height: 6),
                          _childMeta('Age', _formatAge(report['ageInMonths'])),
                          const SizedBox(height: 6),
                          _childMeta('Age Group',
                              report['questionAgeGroup']?.toString() ??
                              report['recommendationAgeGroup']?.toString() ??
                              widget.ageGroup),
                          const SizedBox(height: 6),
                          _childMeta('Generated', _formatDate(report['generatedAt']?.toString())),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      children: [
                        SizedBox(
                          width: 90, height: 90,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(90, 90),
                                painter: _ScoreRingPainter(pct: _calcPct(categories), color: statusColor),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${_calcPct(categories)}%',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3B247A))),
                                  const Text('Score', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Text(status,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(height: 4, color: const Color(0xFFFF7964)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4 Summary Cards
        _buildSummaryCards(categories),
        const SizedBox(height: 16),

        // Flagged items
        if (overall.isNotEmpty) ...[
          Row(children: [
            Icon(Icons.flag_rounded, color: Colors.orange.shade600, size: 18),
            const SizedBox(width: 6),
            Text('Flagged Items (${overall.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          ...overall.map((item) {
            final question = item['question']?.toString() ?? '';
            final ans = item['ans']?.toString() ?? item['response']?.toString() ?? '';
            final additional = item['additional']?.toString() ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (question.isNotEmpty)
                  Text(question, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(ans,
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                  ),
                  if (additional.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(child: Text(additional,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ]),
              ]),
            );
          }),
        ],
      ]),
    );
  }

  // ── Summary Cards ─────────────────────────────────────────────────────────

  Widget _buildSummaryCards(Map<String, dynamic> categories) {
    int total = 0, onTrack = 0, monitor = 0, attention = 0;
    for (final val in categories.values) {
      if (val is Map) {
        total++;
        final s = (val['status']?.toString() ?? '').toLowerCase();
        if (s.contains('on track') || s.contains('typical') || s.contains('normal')) onTrack++;
        else if (s.contains('monitor')) monitor++;
        else if (s.contains('attention') || s.contains('concern') || s.contains('delay')) attention++;
      }
    }

    return Column(children: [
      Row(children: [
        _summaryCard('Total Domains', total.toString(), Icons.grid_view_rounded,
            const Color(0xFFF3EEFF), _purple),
        const SizedBox(width: 8),
        _summaryCard('On Track', onTrack.toString(), Icons.check_circle_outline_rounded,
            const Color(0xFFECFDF5), const Color(0xFF10B981)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _summaryCard('Monitor', monitor.toString(), Icons.warning_amber_rounded,
            const Color(0xFFFFFBEB), const Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        _summaryCard('Attention', attention.toString(), Icons.error_outline_rounded,
            const Color(0xFFFFF1F2), Colors.red),
      ]),
    ]);
  }

  Widget _summaryCard(String label, String value, IconData icon, Color bgColor, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }
 
  // ── Development Profile (Radar Chart) ────────────────────────────────

  Widget _buildProfileSection() {
    final categories = Map<String, dynamic>.from(_report?['categories'] ?? {});
    if (categories.isEmpty) return const SizedBox.shrink();

    final labels = <String>[];
    final values = <double>[];
    for (final e in categories.entries) {
      if (e.value is Map) {
        final total = ((e.value['total'] ?? 0) as num).toDouble();
        final max   = ((e.value['max']   ?? 1) as num).toDouble();
        labels.add(e.key);
        values.add(max > 0 ? (total / max).clamp(0.0, 1.0) : 0.0);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.radar, color: _purple, size: 18),
          const SizedBox(width: 6),
          const Text('Development Profile',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 300, height: 300,
            child: CustomPaint(
              painter: _RadarChartPainter(labels: labels, values: values),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Widget _buildCategoriesSection() {
    final categories = Map<String, dynamic>.from(_report?['categories'] ?? {});

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bar_chart_rounded, color: _purple, size: 18),
          const SizedBox(width: 6),
          const Text('Development Domain Scores',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          Text('No category data available', style: TextStyle(color: Colors.grey.shade600))
        else ...[
          // Overall Response card
          _buildOverallResponseCard(categories),
          const SizedBox(height: 12),
          // Per-domain cards
          ...categories.entries.map((e) {
            final val = e.value;
            int total = 0, max = 1;
            String catStatus = '', cutoff = '-', monitor = '-';
            int yes = 0, no = 0, sometimes = 0;
            if (val is Map) {
              total     = ((val['total']   ?? 0) as num).toInt();
              max       = ((val['max']     ?? 1) as num).toInt();
              catStatus = val['status']?.toString()  ?? '';
              cutoff    = val['cutoff']?.toString()  ?? '-';
              monitor   = val['monitor']?.toString() ?? '-';
              final answers = val['answers'] is List ? val['answers'] as List : [];
              for (final a in answers) {
                final r = (a['response'] ?? a['ans'] ?? '').toString().toLowerCase();
                if (r == 'yes') yes++;
                else if (r == 'no') no++;
                else if (r == 'sometimes') sometimes++;
              }
            }
            final pct = max > 0 ? (total / max).clamp(0.0, 1.0).toDouble() : 0.0;
            final pctInt = (pct * 100).round();
            final color = _statusColor(catStatus.isNotEmpty ? catStatus
                : (pct >= 0.7 ? 'attention' : pct >= 0.4 ? 'monitor' : 'on track'));
            final label = catStatus.isNotEmpty ? catStatus
                : (pct >= 0.7 ? 'Concern' : pct >= 0.4 ? 'Monitor' : 'On Track');

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.35), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Row 1: icon + name + status badge
                Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.category_rounded, color: color, size: 17),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.key,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                  ),
                ]),
                const SizedBox(height: 10),
                // Row 2: score + percentage
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text.rich(TextSpan(
                    text: 'Score: ',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    children: [TextSpan(
                      text: '$total/$max',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                    )],
                  )),
                  Text('$pctInt%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                ]),
                const SizedBox(height: 6),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 8,
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Bottom 4 stats
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(children: [
                    _domainStat(cutoff, 'Cutoff', Colors.grey.shade700),
                    _domainStat(monitor, 'Monitor', Colors.grey.shade700),
                    _domainStat(yes.toString(), 'Yes', Colors.green),
                    _domainStat(
                      sometimes > 0 ? '$no / ${sometimes}S' : no.toString(),
                      sometimes > 0 ? 'No/S' : 'No',
                      Colors.red,
                    ),
                  ]),
                ),
              ]),
            );
          }).toList(),
        ],
      ]),
    );
  }

  Widget _buildOverallResponseCard(Map<String, dynamic> categories) {
    int totalScore = 0, maxTotal = 0, yes = 0, no = 0, sometimes = 0;
    for (final val in categories.values) {
      if (val is Map) {
        totalScore += ((val['total'] ?? 0) as num).toInt();
        maxTotal  += ((val['max']   ?? 0) as num).toInt();
        final answers = val['answers'] is List ? val['answers'] as List : [];
        for (final a in answers) {
          final r = (a['response'] ?? a['ans'] ?? '').toString().toLowerCase();
          if (r == 'yes') yes++;
          else if (r == 'no') no++;
          else if (r == 'sometimes') sometimes++;
        }
      }
    }
    final pct = maxTotal > 0 ? (totalScore / maxTotal).clamp(0.0, 1.0).toDouble() : 0.0;
    final pctInt = (pct * 100).round();
    final overallStatus = _report?['overall_status']?.toString() ?? _report?['overallStatus']?.toString() ?? 'Unknown';
    final color = _statusColor(overallStatus);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.analytics_rounded, color: color, size: 17),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Text('Overall Response',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(overallStatus, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text.rich(TextSpan(
            text: 'Score: ',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            children: [TextSpan(
              text: '$totalScore/$maxTotal',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
            )],
          )),
          Text('$pctInt%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
          child: Row(children: [
            _domainStat(categories.length.toString(), 'Domains', Colors.grey.shade700),
            _domainStat(yes.toString(), 'Yes', Colors.green),
            _domainStat(no.toString(), 'No', Colors.red),
            _domainStat(sometimes.toString(), 'Sometimes', Colors.orange),
          ]),
        ),
      ]),
    );
  }

  Widget _domainStat(String value, String label, Color color) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]),
  );


  // ── Question Response Tracker ─────────────────────────────────────────────

  Widget _buildQuestionResponseTracker() {
    final categories = Map<String, dynamic>.from(_report?['categories'] ?? {});
    if (categories.isEmpty) return const SizedBox.shrink();

    final catNames = categories.keys.toList();
    final maxQs = catNames.map((c) {
      final answers = categories[c]?['answers'];
      return answers is List ? answers.length : 0;
    }).fold(0, (a, b) => a > b ? a : b);

    if (maxQs == 0) return const SizedBox.shrink();

    Widget ansCell(String response) {
      final r = response.toLowerCase();
      final isYes = r == 'yes';
      final isSometimes = r == 'sometimes';
      final label = isYes ? 'Y' : isSometimes ? 'S' : 'N';
      final bg = isYes ? Colors.green.shade100 : isSometimes ? Colors.orange.shade100 : Colors.red.shade100;
      final fg = isYes ? Colors.green.shade700 : isSometimes ? Colors.orange.shade700 : Colors.red.shade700;
      return Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Center(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg))),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.table_chart_rounded, color: _purple, size: 18),
          const SizedBox(width: 6),
          const Text('Question Response Tracker',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                columnWidths: const {0: FlexColumnWidth()},
              border: TableBorder(
                horizontalInside: BorderSide(color: Colors.grey.shade100),
                bottom: BorderSide(color: Colors.grey.shade100),
              ),
              children: [
                // Header row
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text('Domain',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                    ),
                    ...List.generate(maxQs, (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Text('Q${i + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                    )),
                  ],
                ),
                // Domain rows
                ...catNames.map((cat) {
                  final val = categories[cat];
                  final answers = val is Map && val['answers'] is List
                      ? List<Map<String, dynamic>>.from((val['answers'] as List).map((a) => Map<String, dynamic>.from(a as Map)))
                      : <Map<String, dynamic>>[];
                  final catStatus = val is Map ? (val['status']?.toString() ?? '') : '';
                  final color = _statusColor(catStatus);

                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (catStatus.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(catStatus,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                            ),
                          const SizedBox(height: 3),
                          Text(cat,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                        ]),
                      ),
                      ...List.generate(maxQs, (qi) {
                        if (qi >= answers.length) return const SizedBox(width: 36, height: 36);
                        final r = answers[qi]['response']?.toString() ?? answers[qi]['ans']?.toString() ?? '';
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: ansCell(r),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ],
            ),
            ),
          ),
          ),
        ),
      ]),
    );
  }

  // ── Overall Developmental Concerns ───────────────────────────────────────

  Widget _buildOverallConcerns() {
    final overall = _report?['overall'];
    if (overall == null || overall is! Map) return const SizedBox.shrink();
    final answers = overall['answers'] is List ? overall['answers'] as List : [];
    if (answers.isEmpty) return const SizedBox.shrink();
    final flaggedCount = (overall['flaggedCount'] ?? 0) as int;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.flag_rounded, color: _purple, size: 18),
          const SizedBox(width: 6),
          const Expanded(child: Text('Overall Developmental Concerns',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(20)),
            child: Text('$flaggedCount flagged',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Flagged responses indicate areas of potential concern',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: answers.map<Widget>((ans) {
              final a = Map<String, dynamic>.from(ans as Map);
              final isFlagged = a['flagged'] == true;
              final response = a['response']?.toString() ?? '';
              final number = a['number']?.toString() ?? '';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isFlagged ? Colors.red.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isFlagged ? Colors.red.shade200 : Colors.grey.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isFlagged ? Icons.flag_rounded : Icons.circle_outlined,
                      size: 13, color: isFlagged ? Colors.red.shade500 : Colors.grey.shade400),
                  const SizedBox(width: 5),
                  Text('Q$number',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(width: 6),
                  Text(response.toUpperCase(),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // ── Recommended Activities ────────────────────────────────────────────────

  Widget _buildRecommendedActivities() {
    final recs = _report?['recommendations'];
    if (recs == null || recs is! Map || recs.isEmpty) return const SizedBox.shrink();

    final actIcons = [Icons.emoji_events_rounded, Icons.track_changes_rounded,
        Icons.bolt_rounded, Icons.star_rounded, Icons.favorite_rounded, Icons.wb_sunny_rounded];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.extension_rounded, color: _purple, size: 18),
          SizedBox(width: 6),
          Text('Recommended Activities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        ...(recs as Map).entries.map<Widget>((entry) {
          final rec = entry.value as Map;
          final level = rec['level']?.toString() ?? '';
          final title = rec['title']?.toString() ?? entry.key as String;
          final activities = rec['activities'] is List ? rec['activities'] as List : [];
          final tip = rec['tip']?.toString() ?? '';
          final isAttention = level == 'attention';
          final levelBg = isAttention ? Colors.red.shade50 : Colors.orange.shade50;
          final levelBorder = isAttention ? Colors.red.shade200 : Colors.orange.shade200;
          final levelText = isAttention ? Colors.red.shade700 : Colors.orange.shade700;

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: levelBg, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: levelBorder),
                ),
                child: Text(level, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: levelText)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)))),
            ]),
            const SizedBox(height: 10),
            ...activities.asMap().entries.map<Widget>((e) {
              final act = e.value as Map;
              final name = act['name']?.toString() ?? '';
              final desc = act['description']?.toString() ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: const Color(0xFFF3EEFF), borderRadius: BorderRadius.circular(10)),
                    child: Icon(actIcons[e.key % actIcons.length], color: _purple, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                    const SizedBox(height: 4),
                    Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.5)),
                  ])),
                ]),
              );
            }).toList(),
            if (tip.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(child: Text(tip,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic))),
                ]),
              ),
          ]);
        }).toList(),
      ]),
    );
  }

  // ── AI Development Insights ───────────────────────────────────────────────

  Widget _buildAiInsights() {
    final ai = _report?['ai_recommendation']?.toString() ?? '';
    if (ai.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFF5F3FF), Colors.white, Color(0xFFEEF2FF)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDD6FE)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF3B247A), Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            const Text('AI Development Insights',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF3B247A))),
          ]),
          const SizedBox(height: 10),
          Text('\u201c$ai\u201d',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.6, fontStyle: FontStyle.italic)),
        ]),
      ),
    );
  }

  // ── Next Recommended Steps ────────────────────────────────────────────────

  Widget _buildNextSteps() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.directions_walk_rounded, color: _purple, size: 18),
          SizedBox(width: 6),
          Text('Next Recommended Steps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _nextStepCard(
            icon: Icons.medical_services_outlined,
            iconBg: Colors.red.shade50, iconColor: Colors.red,
            title: 'Clinical Assessment',
            desc: 'Schedule a free professional assessment for domains requiring attention',
          )),
          const SizedBox(width: 10),
          Expanded(child: _nextStepCard(
            icon: Icons.repeat_rounded,
            iconBg: Colors.green.shade50, iconColor: Colors.green,
            title: 'Daily Practice',
            desc: 'Engage in 15-20 minutes of targeted activities daily for consistent progress',
          )),
          const SizedBox(width: 10),
          Expanded(child: _nextStepCard(
            icon: Icons.calendar_month_rounded,
            iconBg: const Color(0xFFEFF6FF), iconColor: _purple,
            title: 'Re-screen in 2 Months',
            desc: 'Complete the next screening to track developmental progress over time',
          )),
        ]),
      ]),
    );
  }

  Widget _nextStepCard({required IconData icon, required Color iconBg, required Color iconColor,
      required String title, required String desc}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
        const SizedBox(height: 4),
        Text(desc, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, height: 1.4)),
      ]),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  const _RadarChartPainter({required this.labels, required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final n = labels.length;
    final maxR = size.width / 2 - 44;
    const levels = 5;

    Offset pt(int i, double r) {
      final a = (2 * math.pi * i / n) - math.pi / 2;
      return Offset(cx + r * math.cos(a), cy + r * math.sin(a));
    }

    final gridPaint = Paint()
      ..color = const Color(0xFF3B247A).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Grid rings
    for (int l = 1; l <= levels; l++) {
      final path = Path();
      for (int i = 0; i < n; i++) {
        final p = pt(i, maxR * l / levels);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Axis lines
    for (int i = 0; i < n; i++) {
      canvas.drawLine(Offset(cx, cy), pt(i, maxR), gridPaint);
    }

    // Data polygon
    final dataPath = Path();
    for (int i = 0; i < n; i++) {
      final p = pt(i, maxR * values[i]);
      i == 0 ? dataPath.moveTo(p.dx, p.dy) : dataPath.lineTo(p.dx, p.dy);
    }
    dataPath.close();
    canvas.drawPath(dataPath, Paint()
      ..color = const Color(0xFF3B247A).withOpacity(0.12)
      ..style = PaintingStyle.fill);
    canvas.drawPath(dataPath, Paint()
      ..color = const Color(0xFF3B247A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round);

    // Points
    for (int i = 0; i < n; i++) {
      final p = pt(i, maxR * values[i]);
      canvas.drawCircle(p, 5, Paint()..color = const Color(0xFFFF7964));
      canvas.drawCircle(p, 5, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }

    // Labels
    for (int i = 0; i < n; i++) {
      final p = pt(i, maxR + 22);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 72);
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2));
    }

    // Tick labels
    for (int l = 1; l <= levels; l++) {
      final tp = TextPainter(
        text: TextSpan(
          text: '${l * 20}',
          style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx + 3, cy - maxR * l / levels - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarChartPainter old) => false;
}

class _ScoreRingPainter extends CustomPainter {
  final int pct;
  final Color color;
  const _ScoreRingPainter({required this.pct, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 8;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    paint.color = Colors.grey.shade200;
    canvas.drawCircle(Offset(cx, cy), r, paint);

    paint.color = color;
    final sweep = 2 * 3.14159265 * (pct / 100.0);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -3.14159265 / 2,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.pct != pct;
}
