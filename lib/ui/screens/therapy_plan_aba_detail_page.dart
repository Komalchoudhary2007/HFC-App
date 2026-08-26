import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../services/storage_service.dart';

class TherapyPlanAbaDetailPage extends StatefulWidget {
  final Map<String, dynamic> report;
  const TherapyPlanAbaDetailPage({Key? key, required this.report}) : super(key: key);

  @override
  State<TherapyPlanAbaDetailPage> createState() => _TherapyPlanAbaDetailPageState();
}

class _TherapyPlanAbaDetailPageState extends State<TherapyPlanAbaDetailPage> {
  static const String _base = 'https://api.hireforcare.com/api';
  static const Color _purple = Color(0xFF3B247A);
  static const Color _coral = Color(0xFFFF7964);

  Map<String, dynamic>? _data;
  bool _loading = true;

  Map<String, dynamic> get _r => widget.report;

  @override
  void initState() {
    super.initState();
    _fetchTherapyData();
  }

  Future<void> _fetchTherapyData() async {
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
        final fetched = json['data'] != null
            ? Map<String, dynamic>.from(json['data'] as Map)
            : null;
        setState(() { _data = fetched ?? _staticData(); _loading = false; });
      } else {
        setState(() { _data = _staticData(); _loading = false; });
      }
    } catch (_) {
      setState(() { _data = _staticData(); _loading = false; });
    }
  }

  Map<String, dynamic> _staticData() => {
    'childName': _r['title']?.toString() ?? 'Child Name',
    'parentName': 'Parent / Guardian',
    'age': 'N/A',
    'gender': 'N/A',
    'dob': 'N/A',
    'diagnosis': _r['description']?.toString() ?? 'Autism Spectrum Disorder',
    'therapistName': 'ABA Therapist',
    'joiningDate': 'N/A',
    'sessionFrequency': 'N/A',
    'advisedSessions': 'N/A',
    'sessionsTaken': 'N/A',
    'progressReports': 'N/A',
    'mode': 'In-Person',
    'goals': [
      {
        'number': 1,
        'title': 'Social Communication',
        'subDomain': 'Joint Attention & Eye Contact',
        'observation': 'Child rarely initiates eye contact and does not follow pointing gestures.',
        'shortTerm': 'Maintain eye contact for 3 seconds during structured interactions in 4/5 trials.',
        'longTerm': 'Spontaneously initiate joint attention with peers and adults across settings.',
        'relevance': 'Joint attention is foundational for language development and social learning.',
      },
      {
        'number': 2,
        'title': 'Behavior Regulation',
        'subDomains': [
          {
            'subDomain': 'Tantrum Reduction',
            'observation': 'Child exhibits tantrums (crying, floor-dropping) 4–6 times per session when demands are placed.',
            'shortTerm': 'Reduce tantrum frequency to 2 or fewer per session using functional communication training.',
            'longTerm': 'Use words or AAC device to express frustration independently across all settings.',
            'relevance': 'Reducing challenging behavior increases learning opportunities and social inclusion.',
          },
          {
            'subDomain': 'Waiting & Transitions',
            'observation': 'Child struggles to wait for preferred items and resists activity transitions.',
            'shortTerm': 'Wait for preferred item for 30 seconds with visual support in 3/5 trials.',
            'longTerm': 'Transition between activities independently using a visual schedule.',
            'relevance': 'Waiting and transition skills are critical for school readiness and daily routines.',
          },
        ],
      },
    ],
    'approaches': [
      {'title': 'Discrete Trial Training (DTT)', 'description': 'Structured teaching method breaking down complex skills into smaller, teachable units with clear prompts and reinforcement.'},
      {'title': 'Natural Environment Training (NET)', 'description': 'Teaching in natural settings using everyday activities and child-led interests to promote generalization of skills.'},
      {'title': 'Positive Behavior Support', 'description': 'Focus on reinforcing desired behaviors and teaching functional replacement behaviors to reduce challenging behaviors.'},
      {'title': 'Task Analysis & Chaining', 'description': 'Breaking complex skills into sequential steps and teaching them systematically through forward or backward chaining.'},
      {'title': 'Pivotal Response Training (PRT)', 'description': 'Targeting pivotal areas of development like motivation and self-initiation to produce widespread improvements.'},
      {'title': 'Parent Training & Collaboration', 'description': 'Empowering families with ABA strategies for consistent implementation across home and community settings.'},
    ],
    'notes': 'Consistent implementation and positive reinforcement will enhance therapy progress and support the child\'s behavioral and developmental goals.\n\nRegular communication between behavior analyst and family ensures alignment on goals and strategies. Progress will be monitored through data collection and therapy plan adjusted as needed based on the child\'s response and skill acquisition trajectory.',
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('ABA Therapy Plan',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _buildHeader(),
                  _buildDiagnosisBox(),
                  const SizedBox(height: 16),
                  _buildChildInfoCard(),
                  const SizedBox(height: 16),
                  _buildGoalsSection(),
                  _buildApproachesSection(),
                  _buildNotesSection(),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
    );
  }

  // ── SECTION 1: Header ─────────────────────────────────────────────────────

  Widget _buildHeader() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12), topRight: Radius.circular(12),
      ),
      child: Container(
        color: _purple,
        padding: const EdgeInsets.all(28),
        child: Stack(children: [
          Positioned(
            top: 0, right: 0,
            child: SizedBox(
              width: 150, height: 65,
              child: Image.network(
                'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/therapy-plan/occupational-therapy/hireforcare-left.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 160),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ABA Therapy Plan',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Special Child Centre By HireForCare',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 16),
              _headerRow(Icons.phone, '7688860000'),
              const SizedBox(height: 4),
              _headerRow(Icons.email_outlined, 'info@hireforcare.com'),
              const SizedBox(height: 4),
              _headerRow(Icons.location_on_outlined, '2nd Floor, Tenex Tower, Sector 116, Noida'),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _headerRow(IconData icon, String text) => Row(children: [
    Icon(icon, color: Colors.white70, size: 13),
    const SizedBox(width: 6),
    Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11))),
  ]);

  // ── SECTION 2: Diagnosis Box ──────────────────────────────────────────────

  Widget _buildDiagnosisBox() {
    final diagnosis = _data?['diagnosis']?.toString() ?? 'N/A';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12),
        ),
        border: Border(bottom: BorderSide(color: _coral, width: 4)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Primary Concern / Diagnosis:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _purple)),
        const SizedBox(height: 8),
        Text(diagnosis, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.6)),
      ]),
    );
  }

  // ── SECTION 3: Child Info Card ────────────────────────────────────────────

  Widget _buildChildInfoCard() {
    final d = _data ?? {};
    final childName = d['childName']?.toString() ?? 'N/A';
    final gender = d['gender']?.toString() ?? 'N/A';
    final guardian = d['parentName']?.toString() ?? 'N/A';
    final dob = d['dob']?.toString() ?? 'N/A';
    final age = d['age']?.toString() ?? 'N/A';
    final therapist = d['therapistName']?.toString() ?? 'N/A';
    final joiningDate = d['joiningDate']?.toString() ?? _formatDate(_r['createdAt']?.toString());
    final sessionFreq = d['sessionFrequency']?.toString() ?? 'N/A';
    final advisedSessions = d['advisedSessions']?.toString() ?? 'N/A';
    final sessionsTaken = d['sessionsTaken']?.toString() ?? 'N/A';
    final progressReports = d['progressReports']?.toString() ?? 'N/A';
    final mode = d['mode']?.toString() ?? 'N/A';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(childName.toUpperCase(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _purple, letterSpacing: 0.5)),
        const SizedBox(height: 20),
        _infoGrid([_infoItem('Gender', gender), _infoItem('Guardian', guardian), _infoItem('DOB', '$dob ($age)')]),
        const Divider(height: 20, color: Color(0xFFE5E7EB)),
        _infoGrid([_infoItem('Therapist', therapist), _infoItem('Joining Date', joiningDate), _infoItem('Session Frequency', sessionFreq)]),
        const Divider(height: 20, color: Color(0xFFE5E7EB)),
        _infoGrid([_infoItem('Advised Sessions', advisedSessions), _infoItem('Sessions Taken', sessionsTaken), _infoItem('Progress Reports', progressReports)]),
        const Divider(height: 20, color: Color(0xFFE5E7EB)),
        _infoGrid([_infoItem('Mode', mode), const SizedBox.shrink(), const SizedBox.shrink()]),
      ]),
    );
  }

  Widget _infoGrid(List<Widget> items) => Row(children: [
    Expanded(child: items[0]), Expanded(child: items[1]), Expanded(child: items[2]),
  ]);

  Widget _infoItem(String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: RichText(text: TextSpan(children: [
      TextSpan(text: '$label: ',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _purple)),
      TextSpan(text: value,
          style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
    ])),
  );

  // ── SECTION 4: Goals ──────────────────────────────────────────────────────

  Widget _buildGoalsSection() {
    final rawGoals = _data?['goals'];
    if (rawGoals == null || rawGoals is! List || rawGoals.isEmpty) return const SizedBox.shrink();
    final goals = List<Map<String, dynamic>>.from(
      rawGoals.map((g) => Map<String, dynamic>.from(g as Map))
    );
    return Column(children: goals.map((g) => _buildGoalCard(g)).toList());
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    final number = goal['number']?.toString() ?? '';
    final title = goal['title']?.toString() ?? '';
    final rawSubDomains = goal['subDomains'];
    final subDomains = rawSubDomains is List
        ? List<Map<String, dynamic>>.from(rawSubDomains.map((s) => Map<String, dynamic>.from(s as Map)))
        : <Map<String, dynamic>>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$number. $title',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _purple)),
        Container(margin: const EdgeInsets.symmetric(vertical: 10), height: 3, color: _coral),
        if (subDomains.isNotEmpty)
          ...subDomains.map((sd) => _buildSubDomainBlock(sd)).toList()
        else
          _buildGoalColumns(
            observation: goal['observation']?.toString() ?? '',
            shortTerm: goal['shortTerm']?.toString() ?? '',
            longTerm: goal['longTerm']?.toString() ?? '',
            relevance: goal['relevance']?.toString() ?? '',
            subDomainLabel: goal['subDomain']?.toString() ?? '',
          ),
      ]),
    );
  }

  Widget _buildSubDomainBlock(Map<String, dynamic> sd) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _subDomainBadge(sd['subDomain']?.toString() ?? ''),
      const SizedBox(height: 10),
      _buildGoalColumns(
        observation: sd['observation']?.toString() ?? '',
        shortTerm: sd['shortTerm']?.toString() ?? '',
        longTerm: sd['longTerm']?.toString() ?? '',
        relevance: sd['relevance']?.toString() ?? '',
        subDomainLabel: '',
      ),
      const Divider(height: 24, color: Color(0xFFE5E7EB)),
    ]);
  }

  Widget _subDomainBadge(String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD4CC)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _coral)),
    );
  }

  Widget _buildGoalColumns({
    required String observation, required String shortTerm,
    required String longTerm, required String relevance,
    required String subDomainLabel,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (subDomainLabel.isNotEmpty) ...[
        _subDomainBadge(subDomainLabel),
        const SizedBox(height: 12),
      ],
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _goalBox('OBSERVATION (BASELINE)', observation,
            Icons.visibility_outlined, const Color(0xFFF0F9FF), const Color(0xFF0EA5E9))),
        const SizedBox(width: 10),
        Expanded(child: _goalBox('SHORT-TERM GOAL (1 MONTH)', shortTerm,
            Icons.flag_outlined, const Color(0xFFF0FDF4), const Color(0xFF22C55E))),
      ]),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _goalBox('LONG-TERM GOAL (6 MONTHS)', longTerm,
            Icons.emoji_events_outlined, const Color(0xFFFFFBEB), const Color(0xFFF59E0B))),
        const SizedBox(width: 10),
        Expanded(child: _goalBox('RELEVANCE', relevance,
            Icons.lightbulb_outline_rounded, const Color(0xFFFDF4FF), const Color(0xFFA855F7))),
      ]),
    ]);
  }

  Widget _goalBox(String title, String content, IconData icon, Color bgColor, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: accentColor),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(title,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: accentColor, letterSpacing: 0.4))),
        ]),
        const SizedBox(height: 8),
        Text(content.isNotEmpty ? content : '—',
            style: const TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.6)),
      ]),
    );
  }

  // ── SECTION 5: Approaches ─────────────────────────────────────────────────

  Widget _buildApproachesSection() {
    final rawApproaches = _data?['approaches'];
    if (rawApproaches == null || rawApproaches is! List || rawApproaches.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFDBEAFE), Color(0xFFFAE8FF), Color(0xFFE0E7FF)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8B4FE)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.track_changes_rounded, color: _purple, size: 22),
          SizedBox(width: 10),
          Text('ABA Approaches and Strategies',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _purple)),
        ]),
        const SizedBox(height: 12),
        ...rawApproaches.asMap().entries.map((entry) {
          final idx = entry.key;
          final a = entry.value;
          final title = a is Map ? (a['title']?.toString() ?? '') : a.toString();
          final desc = a is Map ? (a['description']?.toString() ?? '') : '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${idx + 1}. $title',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _purple)),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF1F2937), height: 1.6)),
              ],
            ]),
          );
        }).toList(),
      ]),
    );
  }

  // ── SECTION 6: Notes ──────────────────────────────────────────────────────

  Widget _buildNotesSection() {
    final notes = _data?['notes']?.toString() ?? '';
    if (notes.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.description_outlined, color: _purple, size: 22),
          SizedBox(width: 10),
          Text('Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _purple)),
        ]),
        const SizedBox(height: 14),
        Text(notes, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.8)),
      ]),
    );
  }
}
