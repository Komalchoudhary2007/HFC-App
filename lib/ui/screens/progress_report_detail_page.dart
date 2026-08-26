import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../services/storage_service.dart';

class ProgressReportDetailPage extends StatefulWidget {
  final Map<String, dynamic> report;
  const ProgressReportDetailPage({Key? key, required this.report}) : super(key: key);

  @override
  State<ProgressReportDetailPage> createState() => _ProgressReportDetailPageState();
}

class _ProgressReportDetailPageState extends State<ProgressReportDetailPage> {
  static const String _base = 'https://api.hireforcare.com/api';
  static const Color _purple = Color(0xFF3B247A);
  static const Color _coral = Color(0xFFFF7964);
  static const Color _green = Color(0xFF10B981);

  Map<String, dynamic>? _data;
  bool _loading = true;

  Map<String, dynamic> get _r => widget.report;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final id = _r['id']?.toString() ?? '';
      final token = await StorageService().getToken();
      final res = await http.get(
        Uri.parse('$_base/pdf-uploads/$id/therapy-data'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final fetched = json['data'] != null ? Map<String, dynamic>.from(json['data'] as Map) : null;
        setState(() { _data = fetched ?? _staticData(); _loading = false; });
      } else {
        setState(() { _data = _staticData(); _loading = false; });
      }
    } catch (_) {
      setState(() { _data = _staticData(); _loading = false; });
    }
  }

  Map<String, dynamic> _staticData() => {
    'childName': _r['childName']?.toString() ?? 'Shreyansh Rohde',
    'therapist': _r['therapist']?.toString() ?? 'Neha Srivastava',
    'gender': 'Male',
    'diagnosis': 'ASD',
    'dob': '7 Aug 2020',
    'joiningDate': '15 Sept 2025',
    'age': '5 yr 3 months',
    'nextReview': '15 Dec 2025',
    'therapyType': _r['therapyType']?.toString() ?? 'Occupational Therapy',
    'reportPeriod': '15 Sept - 15 Nov',
    'frequency': '3 sessions/week',
    'duration': '1 month to 6 months',
    'dateOfPlan': '15 Nov 2025',
    'participation': {'Excellent': 5, 'Better': 3, 'Good': 1, 'Poor': 0},
    'totalSessions': 9,
    'progressAreas': [
      {'label': 'Attention & Response', 'percent': 75, 'color': 0xFF8B5CF6, 'before': '< 2 min engagement', 'current': '5-6 min with prompts'},
      {'label': 'Communication & Social', 'percent': 80, 'color': 0xFF3B82F6, 'before': 'Minimal eye contact', 'current': 'Greetings with prompts'},
      {'label': 'Motor Skills', 'percent': 70, 'color': 0xFF10B981, 'before': 'Poor balance, no jumping', 'current': 'Jumping with support'},
      {'label': 'Social Interaction', 'percent': 65, 'color': 0xFF6366F1, 'before': 'Avoidant of peers', 'current': 'Tolerates proximity'},
      {'label': 'Daily Activities', 'percent': 60, 'color': 0xFFF59E0B, 'before': 'Fully dependent', 'current': 'Partial independence'},
    ],
    'skills': [
      {
        'title': 'Joint Attention',
        'subtitle': 'Focus and shared attention skills',
        'status': 'A*',
        'statusLabel': 'Achieved',
        'statusColor': 0xFFFEF9C3,
        'statusTextColor': 0xFF854D0E,
        'baseline': 'Shreyansh looks at objects/persons briefly, with inconsistent initiation.',
        'shortTerm': 'Shreyansh will attend to 5 different objects for 3-5 seconds with no more than two verbal/gestural prompts across four out of five sessions.',
        'longTerm': 'Shreyansh will sustain attention for 5-7 objects for 7 seconds independently.',
        'notes': 'Shreyansh initiated joint attention for 3-5 objects for 1-2 seconds when interested, showing consistent response to cues.',
        'notesColor': 0xFFFFF7ED,
        'notesTitleColor': 0xFFC2410C,
        'chartLines': [
          {'label': 'Joint attention',   'color': 0xFF8B5CF6, 'points': [2.0, 3.0, 3.0, 4.0, 4.0]},
          {'label': 'Eye contact',       'color': 0xFFEF4444, 'points': [1.0, 2.0, 2.0, 3.0, 3.0]},
          {'label': 'Turn-taking',       'color': 0xFF22C55E, 'points': [1.0, 2.0, 3.0, 3.0, 4.0]},
        ],
      },
      {
        'title': 'Eye Contact',
        'subtitle': 'Visual engagement and connection skills',
        'status': 'PA*',
        'statusLabel': 'Partial',
        'statusColor': 0xFFFFEDD5,
        'statusTextColor': 0xFF9A3412,
        'baseline': 'Shreyansh has limited eye contact (1-2 seconds) and avoids it during play.',
        'shortTerm': 'Shreyansh will maintain 2-3 seconds of spontaneous eye contact during greetings and structured play, across four out of five daily interactions.',
        'longTerm': 'Shreyansh will maintain 5-6 seconds of consistent eye contact across settings.',
        'notes': 'Shreyansh is able to maintain 2-3 seconds of eye contact when interested or with prompts, showing increased duration with adult direction.',
        'notesColor': 0xFFFFEDD5,
        'notesTitleColor': 0xFFC2410C,
        'chartLines': [
          {'label': 'Eye contact',        'color': 0xFF8B5CF6, 'points': [1.0, 2.0, 2.0, 3.0, 3.0]},
          {'label': 'Social interaction', 'color': 0xFFEF4444, 'points': [1.0, 1.0, 2.0, 2.0, 3.0]},
          {'label': 'Peer engagement',    'color': 0xFF22C55E, 'points': [1.0, 1.0, 2.0, 3.0, 3.0]},
        ],
      },
      {
        'title': 'Command Following',
        'subtitle': 'Understanding and following instructions',
        'status': 'PA*',
        'statusLabel': 'Partial',
        'statusColor': 0xFFFFEDD5,
        'statusTextColor': 0xFF9A3412,
        'baseline': 'Shreyansh has difficulty following simple, 1-step instructions.',
        'shortTerm': 'Shreyansh will accurately follow one different 1-step commands with no more than one verbal prompt, in five out of seven opportunities per session.',
        'longTerm': 'Shreyansh will follow one-step commands independently across environments.',
        'notes': 'Shreyansh follows 1-step commands 40% consistently with verbal prompts, demonstrating emerging ability to process simple directions.',
        'notesColor': 0xFFFFEDD5,
        'notesTitleColor': 0xFFC2410C,
        'chartLines': [
          {'label': 'Command following',  'color': 0xFF8B5CF6, 'points': [1.0, 2.0, 2.0, 3.0, 3.0]},
          {'label': 'Auditory attention', 'color': 0xFFEF4444, 'points': [2.0, 2.0, 3.0, 3.0, 4.0]},
          {'label': 'Sustained attention','color': 0xFF22C55E, 'points': [1.0, 2.0, 2.0, 3.0, 3.0]},
        ],
      },
      {
        'title': 'Gross Motor / Sitting Tolerance',
        'subtitle': 'Large muscle control and sitting endurance',
        'status': 'PA*',
        'statusLabel': 'Partial',
        'statusColor': 0xFFFFEDD5,
        'statusTextColor': 0xFF9A3412,
        'baseline': 'Shreyansh has poor balance and sitting tolerance is low (~3-4 min).',
        'shortTerm': 'Shreyansh will initiate jumping for crossing one hurdle and sit for 6 consecutive minutes during a structured task with no more than two prompts.',
        'longTerm': 'Shreyansh will sit for 10 minutes in structured activity and demonstrate improved balance and gross motor coordination.',
        'notes': 'Shreyansh initiates jumping with support from up to down; can walk up and sits 4-5 minutes with prompts.',
        'notesColor': 0xFFFFEDD5,
        'notesTitleColor': 0xFFC2410C,
        'chartLines': [
          {'label': 'Balance',          'color': 0xFF8B5CF6, 'points': [2.0, 2.0, 3.0, 3.0, 4.0]},
          {'label': 'Locomotor skills', 'color': 0xFFEF4444, 'points': [1.0, 2.0, 2.0, 3.0, 4.0]},
          {'label': 'Sitting tolerance','color': 0xFF22C55E, 'points': [2.0, 3.0, 3.0, 4.0, 4.0]},
          {'label': 'Postural control', 'color': 0xFFF59E0B, 'points': [2.0, 2.0, 3.0, 3.0, 3.0]},
        ],
      },
      {
        'title': 'Attention and Focus',
        'subtitle': 'Sustained attention and concentration skills',
        'status': 'A*',
        'statusLabel': 'Achieved',
        'statusColor': 0xFFFEF9C3,
        'statusTextColor': 0xFF854D0E,
        'baseline': 'Shreyansh is distractible, avoids tabletop tasks, and has <2 min focus.',
        'shortTerm': 'Shreyansh will improve attention span to 5-6 consecutive minutes during structured table-top tasks, requiring no more than three redirection prompts.',
        'longTerm': 'Shreyansh will sustain attention for 7-8 minutes with reduced prompts in learning/play.',
        'notes': 'Shreyansh completes table-top activity from start to end for 5-6 min with prompts, showing significant improvement in sustained focus.',
        'notesColor': 0xFFFEF9C3,
        'notesTitleColor': 0xFF854D0E,
        'chartLines': [
          {'label': 'Initiating attention',  'color': 0xFF8B5CF6, 'points': [2.0, 3.0, 4.0, 5.0, 5.0]},
          {'label': 'Completing tasks',      'color': 0xFFEF4444, 'points': [2.0, 3.0, 3.0, 4.0, 5.0]},
          {'label': 'Attention endurance',   'color': 0xFF22C55E, 'points': [1.0, 2.0, 3.0, 4.0, 4.0]},
          {'label': 'Reducing distractions', 'color': 0xFFF59E0B, 'points': [2.0, 2.0, 3.0, 3.0, 4.0]},
        ],
      },
    ],
    'improvements': 'Shreyansh shows better engagement during sessions, initiates greetings in approximately 50% of opportunities, demonstrates improved fine motor control such as fixing blocks and pegs, displays increased sensory awareness, and has begun initiating jumping independently.',
    'challenges': 'Shreyansh displays sensory-seeking behavior such as knee walking, shows low independence in ADLs, requires verbal prompting for maintaining eye contact and following commands, and demonstrates inconsistent social participation during interactions.',
    'focusAreas': 'Shreyansh requires support in sensory modulation, needs improved independence in ADLs—especially brushing, benefits from structured peer interaction, and is working toward sustaining attention for longer durations of about 7–8 minutes.',
    'therapistNote': 'Advise to provide structured sensory breaks (e.g., heavy work) before seated tasks to help Shreyansh maintain focus. Encourage independence by allowing him to initiate before assisting. Your consistency is greatly supporting his progress.',
  };

  String _formatDate(String? d) {
    if (d == null || d.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(d);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) { return d; }
  }

  Future<void> _openPdf() async {
    final id = _r['id']?.toString() ?? '';
    final token = await StorageService().getToken();
    final url = token != null
        ? '$_base/pdf-uploads/$id/download?token=${Uri.encodeComponent(token)}'
        : '$_base/pdf-uploads/$id/download';
    await launchUrl(Uri.parse(url),
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data ?? _staticData();
    final therapyType = d['therapyType']?.toString() ?? 'Occupational Therapy';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text('$therapyType Progress Report',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: _purple,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _openPdf,
            icon: const Icon(Icons.open_in_new, color: Colors.white, size: 16),
            label: const Text('PDF', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _buildHeader(d),
                _buildClientInfo(d),
                const SizedBox(height: 16),
                _buildSessionAndParticipation(d),
                const SizedBox(height: 16),
                _buildParentSummary(d),
                const SizedBox(height: 16),
                _buildSkillsSection(d),
                const SizedBox(height: 16),
                _buildProgressOverview(d),
                const SizedBox(height: 24),
              ]),
            ),
    );
  }

  // ── SECTION 1: Header ────────────────────────────────────────────────────

  Widget _buildHeader(Map<String, dynamic> d) {
    final therapyType = d['therapyType']?.toString() ?? 'Occupational Therapy';
    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      child: Container(
        color: _purple,
        padding: const EdgeInsets.all(24),
        child: Stack(children: [
          Positioned(
            top: 0, right: 0,
            child: SizedBox(
              width: 140, height: 60,
              child: Image.network(
                'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/therapy-plan/occupational-therapy/hireforcare-left.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 150),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$therapyType Progress Report',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Special Child Centre By HireForCare',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 14),
              _hRow(Icons.phone, '7688860000  |  info@hireforcare.com'),
              const SizedBox(height: 4),
              _hRow(Icons.location_on_outlined, '2nd Floor, Tenex Tower, Sector 116, Noida'),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _hRow(IconData icon, String text) => Row(children: [
    Icon(icon, color: Colors.white70, size: 13),
    const SizedBox(width: 6),
    Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11))),
  ]);

  // ── SECTION 2: Client Info ────────────────────────────────────────────────

  Widget _buildClientInfo(Map<String, dynamic> d) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: _green, width: 4)),
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Expanded(child: _infoTile('Client Name', d['childName']?.toString() ?? 'N/A')),
          const SizedBox(width: 8),
          Expanded(child: _infoTile('Gender', d['gender']?.toString() ?? 'N/A')),
          const SizedBox(width: 8),
          Expanded(child: _infoTile('Date of Birth', d['dob']?.toString() ?? 'N/A')),
          const SizedBox(width: 8),
          Expanded(child: _infoTile('Age', d['age']?.toString() ?? 'N/A')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _infoTile('Therapist', d['therapist']?.toString() ?? 'N/A')),
          const SizedBox(width: 8),
          Expanded(child: _infoTile('Diagnosis', d['diagnosis']?.toString() ?? 'N/A')),
          const SizedBox(width: 8),
          Expanded(child: _infoTile('Date of Joining', d['joiningDate']?.toString() ?? _formatDate(_r['createdAt']?.toString()))),
          const SizedBox(width: 8),
          Expanded(child: _infoTile('Next Review', d['nextReview']?.toString() ?? 'N/A')),
        ]),
      ]),
    );
  }

  Widget _infoTile(String label, String value) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _purple)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 11, color: Color(0xFF1F2937))),
    ]),
  );

  // ── SECTION 3: Session Details + Participation ────────────────────────────

  Widget _buildSessionAndParticipation(Map<String, dynamic> d) {
    return Column(children: [
      _buildSessionDetails(d),
      const SizedBox(height: 12),
      _buildParticipation(d),
    ]);
  }

  Widget _buildSessionDetails(Map<String, dynamic> d) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
          ),
          child: const Row(children: [
            Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Session Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _sessionRow('Date of Plan', d['dateOfPlan']?.toString() ?? 'N/A', const Color(0xFFF9FAFB)),
            _sessionRow('Report Period', d['reportPeriod']?.toString() ?? 'N/A', const Color(0xFFEFF6FF)),
            _sessionRow('Frequency', d['frequency']?.toString() ?? 'N/A', const Color(0xFFF0FDF4)),
            _sessionRow('Duration', d['duration']?.toString() ?? 'N/A', const Color(0xFFFAF5FF)),
          ]),
        ),
      ]),
    );
  }

  Widget _sessionRow(String label, String value, Color bg) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
    ]),
  );

  Widget _buildParticipation(Map<String, dynamic> d) {
    final participation = d['participation'] as Map? ?? {'Excellent': 5, 'Better': 3, 'Good': 1, 'Poor': 0};
    final total = (d['totalSessions'] as int?) ?? 9;
    final bars = [
      {'label': 'Excellent', 'color': const Color(0xFF8B5CF6)},
      {'label': 'Better',    'color': const Color(0xFF532A7B)},
      {'label': 'Good',      'color': const Color(0xFF2D1B69)},
      {'label': 'Poor',      'color': const Color(0xFF6B21A8)},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2D1B69), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
          ),
          child: const Row(children: [
            Icon(Icons.bar_chart_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Participation Level', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2D1B69), Color(0xFF8B5CF6)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Participation ($total Sessions)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF9FB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE9ECEF)),
              ),
              child: Column(
                children: bars.map((b) {
                  final label = b['label'] as String;
                  final color = b['color'] as Color;
                  final count = (participation[label] as int?) ?? 0;
                  final pct = total > 0 ? count / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      SizedBox(
                        width: 64,
                        child: Text(label, textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Stack(children: [
                          Container(height: 32, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.2)))),
                          FractionallySizedBox(
                            widthFactor: pct.clamp(0.05, 1.0),
                            child: Container(
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [color, color.withOpacity(0.85)]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 8),
                              child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── SECTION 4: Parent Summary ─────────────────────────────────────────────

  Widget _buildParentSummary(Map<String, dynamic> d) {
    final areas = (d['progressAreas'] as List?) ?? [];
    final avg = areas.isEmpty ? 0 : (areas.map((a) => a['percent'] as int).reduce((a, b) => a + b) / areas.length).round();
    final excellent = areas.where((a) => (a['percent'] as int) >= 70).length;
    final good = areas.where((a) => (a['percent'] as int) >= 60 && (a['percent'] as int) < 70).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: _purple,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
          ),
          child: const Row(children: [
            Icon(Icons.bar_chart_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Parent Summary - Progress Analytics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Overall Development Progress',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Progress bars
              Expanded(
                flex: 2,
                child: Column(
                  children: areas.map<Widget>((a) {
                    final label = a['label'] as String;
                    final pct = (a['percent'] as int);
                    final color = Color(a['color'] as int);
                    final before = a['before'] as String;
                    final current = a['current'] as String;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border(left: BorderSide(color: color, width: 4)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1F2937))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                            child: Text('$pct%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 6,
                            backgroundColor: color.withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(child: RichText(text: TextSpan(children: [
                            TextSpan(text: 'Before: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                            TextSpan(text: before, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                          ]))),
                          const SizedBox(width: 8),
                          Expanded(child: RichText(text: TextSpan(children: [
                            TextSpan(text: 'Current: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                            TextSpan(text: current, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                          ]))),
                        ]),
                      ]),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 12),
              // Stats column
              SizedBox(
                width: 120,
                child: Column(children: [
                  // Overall circle
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: Column(children: [
                      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.track_changes_rounded, size: 14, color: Color(0xFF7C3AED)),
                        SizedBox(width: 4),
                        Text('Overall', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF5B21B6))),
                      ]),
                      const SizedBox(height: 10),
                      Stack(alignment: Alignment.center, children: [
                        SizedBox(
                          width: 72, height: 72,
                          child: CircularProgressIndicator(
                            value: avg / 100,
                            strokeWidth: 7,
                            backgroundColor: const Color(0xFFE5E7EB),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                          ),
                        ),
                        Text('$avg%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF5B21B6))),
                      ]),
                      const SizedBox(height: 8),
                      const Text('Avg Improvement', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Color(0xFF7C3AED))),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  // Distribution
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Icon(Icons.bar_chart_rounded, size: 13, color: Color(0xFF1D4ED8)),
                        SizedBox(width: 4),
                        Text('Distribution', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF))),
                      ]),
                      const SizedBox(height: 8),
                      _distRow('Excellent (70%+)', '$excellent skills', const Color(0xFF1D4ED8)),
                      const SizedBox(height: 4),
                      _distRow('Good (60-70%)', '$good skills', const Color(0xFF1D4ED8)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  // Next focus
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Icon(Icons.check_circle_outline_rounded, size: 13, color: Color(0xFF15803D)),
                        SizedBox(width: 4),
                        Text('Next Focus', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF166534))),
                      ]),
                      const SizedBox(height: 6),
                      _focusItem('Increase attention span'),
                      _focusItem('Improve ADL independence'),
                      _focusItem('Enhance peer interaction'),
                      _focusItem('Strengthen motor skills'),
                    ]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _distRow(String label, String value, Color color) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 9, color: color))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(value, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
      ),
    ],
  );

  Widget _focusItem(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.arrow_right_rounded, size: 12, color: Color(0xFF16A34A)),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 9, color: Color(0xFF15803D)))),
    ]),
  );

  // ── SECTION 5: Skills Assessment ─────────────────────────────────────────

  Widget _buildSkillsSection(Map<String, dynamic> d) {
    final skills = (d['skills'] as List?) ?? [];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: _purple,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
          ),
          child: const Row(children: [
            Icon(Icons.show_chart_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Skills Assessment Progress', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: skills.map<Widget>((s) => _buildSkillCard(s)).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildSkillCard(Map<String, dynamic> s) {
    final statusColor = Color(s['statusColor'] as int? ?? 0xFFFEF9C3);
    final statusTextColor = Color(s['statusTextColor'] as int? ?? 0xFF854D0E);
    final notesColor = Color(s['notesColor'] as int? ?? 0xFFFFF7ED);
    final notesTitleColor = Color(s['notesTitleColor'] as int? ?? 0xFFC2410C);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title row
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s['title']?.toString() ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              const SizedBox(height: 2),
              Text(s['subtitle']?.toString() ?? '',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
            child: Text('${s['status']} (${s['statusLabel']})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusTextColor)),
          ),
        ]),
        const SizedBox(height: 12),
        // 3 cards vertically
        _skillBox('Baseline', s['baseline']?.toString() ?? '', const Color(0xFFF9FAFB), const Color(0xFF374151)),
        const SizedBox(height: 8),
        _skillBox('Short-Term Goal', s['shortTerm']?.toString() ?? '', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
        const SizedBox(height: 8),
        _skillBox('Long-Term Goal', s['longTerm']?.toString() ?? '', const Color(0xFFF0FDF4), const Color(0xFF15803D)),
        const SizedBox(height: 10),
        // Performance Over Time chart
        _buildPerformanceChart(s),
        const SizedBox(height: 10),
        // Progress Notes
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: notesColor, borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Progress Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: notesTitleColor)),
            const SizedBox(height: 4),
            Text(s['notes']?.toString() ?? '',
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.5)),
          ]),
        ),
      ]),
    );
  }

  Widget _skillBox(String title, String content, Color bg, Color titleColor) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: titleColor)),
      const SizedBox(height: 6),
      Text(content, style: const TextStyle(fontSize: 11, color: Color(0xFF374151), height: 1.5)),
    ]),
  );

  // ── SECTION 6: Progress Overview ─────────────────────────────────────────

  Widget _buildProgressOverview(Map<String, dynamic> d) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: _purple,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
          ),
          child: const Row(children: [
            Icon(Icons.trending_up_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Progress Overview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _overviewCard(
              icon: Icons.trending_up_rounded,
              title: 'Areas of Improvement',
              content: d['improvements']?.toString() ?? '',
              borderColor: _green,
              bgColor: const Color(0xFFF0FDF4),
              titleColor: const Color(0xFF166534),
              textColor: const Color(0xFF15803D),
            ),
            const SizedBox(height: 12),
            _overviewCard(
              icon: Icons.warning_amber_rounded,
              title: 'Current Challenges',
              content: d['challenges']?.toString() ?? '',
              borderColor: const Color(0xFFF97316),
              bgColor: const Color(0xFFFFF7ED),
              titleColor: const Color(0xFF9A3412),
              textColor: const Color(0xFFC2410C),
            ),
            const SizedBox(height: 12),
            _overviewCard(
              icon: Icons.track_changes_rounded,
              title: 'Focus Areas for Next Sessions',
              content: d['focusAreas']?.toString() ?? '',
              borderColor: const Color(0xFF3B82F6),
              bgColor: const Color(0xFFEFF6FF),
              titleColor: const Color(0xFF1E40AF),
              textColor: const Color(0xFF1D4ED8),
            ),
            const SizedBox(height: 12),
            // Therapist note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(10),
                border: const Border(left: BorderSide(color: _purple, width: 4)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.message_rounded, size: 16, color: _purple),
                  SizedBox(width: 6),
                  Text("Therapist's Note for Parents",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _purple)),
                ]),
                const SizedBox(height: 8),
                Text(d['therapistNote']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6D28D9), height: 1.6)),
                const SizedBox(height: 10),
                const Divider(color: Color(0xFFDDD6FE)),
                const SizedBox(height: 6),
                const Text('Warm Regards,', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _purple)),
                const Text('HireForCare Pvt. Ltd.', style: TextStyle(fontSize: 12, color: Color(0xFF6D28D9))),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Performance Over Time Chart ─────────────────────────────────────────

  Widget _buildPerformanceChart(Map<String, dynamic> s) {
    final rawLines = s['chartLines'] as List?;
    if (rawLines == null || rawLines.isEmpty) return const SizedBox.shrink();

    final lines = rawLines.cast<Map>();
    final xLabels = ['W1', 'W2', 'W3', 'W4', 'W5'];

    final lineBarsData = lines.asMap().entries.map((entry) {
      final line = entry.value;
      final color = Color(line['color'] as int);
      final pts = (line['points'] as List).asMap().entries.map((e) =>
          FlSpot(e.key.toDouble(), (e.value as num).toDouble())).toList();
      return LineChartBarData(
        spots: pts,
        isCurved: true,
        color: color,
        barWidth: 2.5,
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius: 4, color: color, strokeWidth: 1.5, strokeColor: Colors.white,
          ),
        ),
        belowBarData: BarAreaData(show: false),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Performance Over Time — ${s['title']}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _purple)),
          ),
          const Text('Score: 0 (Poor) → 6 (Excellent)',
              style: TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: LineChart(
            LineChartData(
              minY: 0, maxY: 6,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 2,
                getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF1F3F5), strokeWidth: 1),
              ),
              borderData: FlBorderData(
                show: true,
                border: const Border(
                  left: BorderSide(color: Color(0xFFDEE2E6), width: 1.5),
                  bottom: BorderSide(color: Color(0xFFDEE2E6), width: 1.5),
                  right: BorderSide.none,
                  top: BorderSide.none,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, reservedSize: 22, interval: 2,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}',
                        style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF))),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, reservedSize: 16, interval: 1,
                      getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= xLabels.length) return const SizedBox.shrink();
                      return Text(xLabels[i], style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF)));
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: lineBarsData,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Legend
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE9ECEF)),
          ),
          child: Wrap(
            spacing: 16, runSpacing: 6,
            children: lines.map((line) {
              final color = Color(line['color'] as int);
              final label = line['label'] as String;
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF495057))),
              ]);
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _overviewCard({
    required IconData icon, required String title, required String content,
    required Color borderColor, required Color bgColor,
    required Color titleColor, required Color textColor,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      border: Border(left: BorderSide(color: borderColor, width: 4)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: titleColor),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor)),
      ]),
      const SizedBox(height: 6),
      Text(content, style: TextStyle(fontSize: 12, color: textColor, height: 1.6)),
    ]),
  );
}
