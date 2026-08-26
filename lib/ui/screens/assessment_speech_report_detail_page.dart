import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/storage_service.dart';

class AssessmentSpeechReportDetailPage extends StatefulWidget {
  final Map<String, dynamic> report;
  const AssessmentSpeechReportDetailPage({Key? key, required this.report}) : super(key: key);
  @override
  State<AssessmentSpeechReportDetailPage> createState() => _AssessmentSpeechReportDetailPageState();
}

// ─── Parsed speech report sections ───────────────────────────────────────────
class _SpeechReportSections {
  final Map<String, List<String>> background;
  final List<String> observationDuring;
  final Map<String, _SpeechDomain> observationResults; // dynamic keys A-J or 1-10
  final List<String> strengths;
  final List<String> keyAreas;
  final List<String> clinicalOutcome;
  final List<String> therapyPlan;
  final List<String> recommendations;
  const _SpeechReportSections({
    required this.background, required this.observationDuring,
    required this.observationResults, required this.strengths,
    required this.keyAreas, required this.clinicalOutcome,
    required this.therapyPlan, required this.recommendations,
  });
}

class _SpeechDomain {
  final String key;
  final String title;
  final String content;
  const _SpeechDomain({required this.key, required this.title, required this.content});
}

_SpeechReportSections _parseSpeechReportContent(String raw) {
  final lines = raw
      .replaceAll('\r\n', '\n').replaceAll('\r', '\n')
      .split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  final Map<String, List<String>> bg = {
    'prenatal': [], 'medical': [], 'developmental': [], 'therapy': [], 'family': []
  };
  final List<String> obsDuring = [], strengths = [], keyAreas = [],
      clinicalOutcome = [], therapyPlan = [], recommendations = [];
  final Map<String, _SpeechDomain> obsResults = {};

  String currentSection = '';
  final List<String> buf = [];
  String bgCat = '';

  // ── heading detectors ──────────────────────────────────────────────────────
  bool isBgCatHeader(String ln) =>
      RegExp(r'^prenatal\s*\/?.*postnatal.*$', caseSensitive: false).hasMatch(ln) ||
      RegExp(r'^medical\s+history\s*:?\s*$', caseSensitive: false).hasMatch(ln) ||
      RegExp(r'^developmental\s+history\s*:?\s*$', caseSensitive: false).hasMatch(ln) ||
      RegExp(r'^therapy\s*\/?.*education.*$', caseSensitive: false).hasMatch(ln) ||
      RegExp(r'^family\s*\/?.*social.*$', caseSensitive: false).hasMatch(ln);

  bool isSectionHeading(String ln) {
    if (isBgCatHeader(ln)) return false;
    // ***SECTION*** markers (speech template style)
    if (RegExp(r'^\*{3,}[^*]+\*{3,}$').hasMatch(ln)) return true;
    // ALL CAPS headers
    final base = ln.replaceAll(RegExp(r':$'), '');
    final isAllCaps = RegExp(r'^[A-Z\s&:()\[\]\/\-]+$').hasMatch(base) &&
        ln.length < 150 && ln.length > 3 &&
        !RegExp(r'^\d+$').hasMatch(ln) &&
        !RegExp(r'^[A-Z]\.\s').hasMatch(ln) &&
        !RegExp(r'^\d+\.\s').hasMatch(ln);
    if (isAllCaps) return true;
    // Named section keywords
    return RegExp(
      r'^(REASON FOR REFERRAL|BACKGROUND\s+INFORMATION|OBSERVATION\s+DURING|OBSERVATION\s*(&|AND)\s*RESULTS|AREAS\s+OF\s+STRENGTHS|KEY\s+AREAS|CLINICAL\s+OUTCOME|THERAPY\s+PLAN|RECOMMENDATIONS)',
      caseSensitive: false,
    ).hasMatch(ln.replaceAll(RegExp(r'\s+'), ' '));
  }

  // ── background flush ───────────────────────────────────────────────────────
  void flushBg(List<String> lines) {
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final lower = t.toLowerCase();
      if (isBgCatHeader(t)) {
        if (RegExp(r'prenatal|natal|postnatal', caseSensitive: false).hasMatch(lower)) bgCat = 'prenatal';
        else if (lower.contains('medical')) bgCat = 'medical';
        else if (RegExp(r'developmental|development', caseSensitive: false).hasMatch(lower)) bgCat = 'developmental';
        else if (RegExp(r'therapy|education', caseSensitive: false).hasMatch(lower)) bgCat = 'therapy';
        else if (RegExp(r'family|social', caseSensitive: false).hasMatch(lower)) bgCat = 'family';
        continue;
      }
      final clean = t.replaceAll(RegExp(r'^[\-•*]\s*'), '').replaceAll(RegExp(r'^\d+\.\s*'), '');
      if (clean.isEmpty) continue;
      final lc = clean.toLowerCase();
      String cat;
      if (bgCat.isNotEmpty) {
        cat = bgCat;
      } else if (lc.contains('birth') || lc.contains('pregnancy') || lc.contains('delivery') || lc.contains('gestation') || lc.contains('prenatal')) {
        cat = 'prenatal';
      } else if (lc.contains('seizure') || lc.contains('surgery') || lc.contains('hospitalization') || lc.contains('illness') || lc.contains('medication')) {
        cat = 'medical';
      } else if (lc.contains('milestone') || lc.contains('walking') || lc.contains('talking') || lc.contains('development') || lc.contains('crawl')) {
        cat = 'developmental';
      } else if (lc.contains('therapy') || lc.contains('school') || lc.contains('education') || lc.contains('class')) {
        cat = 'therapy';
      } else if (lc.contains('family') || lc.contains('sibling') || lc.contains('parent') || lc.contains('social')) {
        cat = 'family';
      } else {
        cat = 'medical';
      }
      bg[cat]!.add(clean);
    }
  }

  // ── speech observation results flush (dynamic keys + titles) ──────────────
  void flushObsResults(List<String> lines) {
    String key = '';
    String title = '';
    final Map<String, List<String>> sub = {};
    final Map<String, String> titleMap = {};

    for (final line in lines) {
      final t = line.trim()
          .replaceAll(RegExp(r'^\*+|\*+$'), '')
          .replaceAll('**', '')
          .trim();
      if (t.isEmpty) continue;
      // Match: "A. Voice & Fluency: content" or "1. Domain Title: content"
      final m = RegExp(r'^([A-Z]|\d+)\.\s+([^:]+):\s*(.*)$').firstMatch(t);
      if (m != null) {
        key = m.group(1)!;
        title = m.group(2)!.trim();
        final afterColon = m.group(3)!.trim();
        sub[key] = [];
        titleMap[key] = title;
        if (afterColon.isNotEmpty) sub[key]!.add(afterColon);
      } else if (key.isNotEmpty && t.isNotEmpty) {
        final cleaned = t.replaceAll(RegExp(r'^[\-•*]\s*'), '');
        if (cleaned.isNotEmpty) sub[key]!.add(cleaned);
      }
    }

    // Sort keys: numbers numerically, letters alphabetically
    final sortedKeys = sub.keys.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a);
        final bNum = int.tryParse(b);
        if (aNum != null && bNum != null) return aNum.compareTo(bNum);
        if (aNum != null) return -1;
        if (bNum != null) return 1;
        return a.compareTo(b);
      });

    for (final k in sortedKeys) {
      obsResults[k] = _SpeechDomain(
        key: k,
        title: titleMap[k] ?? 'Domain $k',
        content: sub[k]!.join(' '),
      );
    }
  }

  // ── section flush ──────────────────────────────────────────────────────────
  void flush() {
    if (currentSection.isEmpty || buf.isEmpty) return;
    // Strip *** markers for comparison
    final sec = currentSection.replaceAll(RegExp(r'^\*+|\*+$'), '').trim().toUpperCase();

    if (sec.contains('BACKGROUND INFORMATION')) {
      flushBg(buf);
    } else if (sec.contains('OBSERVATION DURING') || (sec.contains('OBSERVATION') && sec.contains('ASSESSMENT') && !sec.contains('RESULT'))) {
      // Check if content has domain markers → results, else → during
      final hasDomains = buf.any((l) => RegExp(r'^(?:\*\*)?([A-Z]|\d+)\.\s+').hasMatch(l.trim()));
      if (hasDomains) {
        flushObsResults(buf);
      } else {
        obsDuring.addAll(buf);
      }
    } else if (sec.contains('OBSERVATION') && (sec.contains('RESULT') || sec.contains('DOMAIN'))) {
      flushObsResults(buf);
    } else if (sec.contains('AREAS OF STRENGTHS') || sec.contains('STRENGTHS')) {
      strengths.addAll(buf.map((l) => l.replaceAll(RegExp(r'^[\-•*]\s*'), '')));
    } else if (sec.contains('KEY AREAS') || sec.contains('AREAS FOR SUPPORT')) {
      keyAreas.addAll(buf.map((l) => l.replaceAll(RegExp(r'^[\-•*]\s*'), '')));
    } else if (sec.contains('CLINICAL OUTCOME')) {
      clinicalOutcome.addAll(buf);
    } else if (sec.contains('THERAPY PLAN')) {
      therapyPlan.addAll(buf.map((l) => l.replaceAll(RegExp(r'^[\-•*]\s*'), '')));
    } else if (sec.contains('RECOMMENDATION')) {
      recommendations.addAll(buf);
    }
    buf.clear();
    currentSection = '';
  }

  // ── main parse loop ────────────────────────────────────────────────────────
  for (final ln in lines) {
    if (isSectionHeading(ln)) {
      flush();
      currentSection = ln;
    } else if (currentSection.isNotEmpty) {
      buf.add(ln);
    }
  }
  flush();

  return _SpeechReportSections(
    background: bg, observationDuring: obsDuring,
    observationResults: obsResults, strengths: strengths,
    keyAreas: keyAreas, clinicalOutcome: clinicalOutcome,
    therapyPlan: therapyPlan, recommendations: recommendations,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class _AssessmentSpeechReportDetailPageState extends State<AssessmentSpeechReportDetailPage> {
  static const String _base = 'https://api.hireforcare.com/api';
  static const Color _purple = Color(0xFF532A7B);

  Map<String, dynamic>? get _report => widget.report;

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'speech_report': return 'Speech Therapy';
      case 'ot_report': return 'Occupational Therapy';
      case 'aba_report': return 'ABA Therapy';
      case 'special_education_report': return 'Special Education';
      case 'therapy_plan': return 'Therapy Plan';
      case 'progress_report': return 'Progress Report';
      default: return cat.replaceAll('_', ' ');
    }
  }

  String _formatDate(String? d) {
    if (d == null || d.isEmpty) return '';
    try {
      final dt = DateTime.parse(d);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) { return d; }
  }

  Future<void> _openPdf() async {
    final id = _report?['id']?.toString() ?? '';
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
    final title = _report?['title']?.toString() ?? 'Report';
    final content = _report?['reportContent']?.toString() ??
        _report?['content']?.toString() ??
        _report?['rawContent']?.toString() ??
        _report?['body']?.toString() ?? '';
    final sections = _parseSpeechReportContent(content);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: _purple,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _openPdf,
            icon: const Icon(Icons.open_in_new, color: Colors.white, size: 16),
            label: const Text('Open PDF', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          _buildPage1(),
          ..._buildContentSections(sections),
          _buildFooter(),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  // ============================================================================
  // PAGE 1 — Hero + Client Info + Reason for Referral
  // ============================================================================
  Widget _buildPage1() {
    final r = _report ?? {};
    final therapyType = r['therapyType']?.toString() ??
        r['assessmentType']?.toString() ??
        _categoryLabel(r['category']?.toString() ?? '');
    final childName = r['childName']?.toString() ?? '[CHILD NAME]';
    final age = r['age']?.toString() ?? r['childAge']?.toString() ?? '[AGE]';
    final gender = r['gender']?.toString() ?? '[GENDER]';
    final dob = _formatDate(r['dateOfBirth']?.toString() ?? r['childDOB']?.toString());
    final assessmentDate = _formatDate(r['dateOfAssessment']?.toString() ?? r['assessmentDate']?.toString() ?? r['createdAt']?.toString());
    final therapist = r['therapist']?.toString() ?? r['assessor']?.toString() ?? '[THERAPIST / ASSESSOR]';
    final description = r['description']?.toString() ?? '';
    final referralReason = r['reasonForReferral']?.toString() ?? r['referralReason']?.toString() ?? (description.isNotEmpty ? description : '[REASON FOR REFERRAL]');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHero(therapyType: therapyType),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildClientInfo(childName: childName, age: age, gender: gender,
              dob: dob.isNotEmpty ? dob : '[DATE OF BIRTH]',
              assessmentDate: assessmentDate.isNotEmpty ? assessmentDate : '[DATE OF ASSESSMENT]',
              therapist: therapist),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildReasonForReferral(text: referralReason),
        ),
        const SizedBox(height: 22),
      ]),
    );
  }

  // ── Hero banner ─────────────────────────────────────────────────────────────
  Widget _buildHero({required String therapyType}) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Branding bar
        Container(
          padding: const EdgeInsets.fromLTRB(30, 24, 30, 22),
          color: const Color(0xFFFBF9FE),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Image.network(
                'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/therapy-plan/occupational-therapy/hireforcare-left.png',
                height: 45, fit: BoxFit.contain, alignment: Alignment.centerLeft,
                errorBuilder: (_, __, ___) => const Text('HIREFORCARE',
                    style: TextStyle(color: Color(0xFF3B247A), fontSize: 21, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 7),
              const Text('SPECIAL CHILD CENTRE',
                  style: TextStyle(color: Color(0xFF3B247A), fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
              const SizedBox(height: 2),
              const Text('THERAPY THAT BUILDS FUTURE',
                  style: TextStyle(color: Color(0xFFFF7964), fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            ])),
            const SizedBox(width: 10),
            Container(width: 42, height: 52,
                decoration: BoxDecoration(color: const Color(0xFFF2EBFA), borderRadius: BorderRadius.circular(14))),
          ]),
        ),
        // Purple gradient hero — speech header image
        Container(
          height: 280,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft, end: Alignment.centerRight,
              colors: [Color(0xFF35105D), Color(0xFF4A176B), Color(0xFF3B247A)],
            ),
          ),
          child: LayoutBuilder(builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 430;
            return Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 28, top: 44, right: isSmall ? 120 : 160,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(therapyType, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: isSmall ? 29 : 35, fontWeight: FontWeight.w800, height: 1.02)),
                  const SizedBox(height: 7),
                  Text('Assessment Report', maxLines: 2,
                      style: TextStyle(color: Colors.white, fontSize: isSmall ? 25 : 31, fontWeight: FontWeight.w700, height: 1.05)),
                  const SizedBox(height: 18),
                  const Text('Comprehensive Communication Evaluation', maxLines: 2,
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.2)),
                  const SizedBox(height: 16),
                  Container(width: 95, height: 2, color: const Color(0xFFFF7964)),
                ]),
              ),
              Positioned(
                right: isSmall ? -35 : -18, top: isSmall ? 32 : 18,
                child: SizedBox(
                  width: isSmall ? 200 : 245, height: isSmall ? 200 : 245,
                  child: Stack(alignment: Alignment.center, children: [
                    Container(width: isSmall ? 200 : 245, height: isSmall ? 200 : 245,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 9))),
                    Container(width: isSmall ? 181 : 222, height: isSmall ? 181 : 222,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFB88ADE), width: 2))),
                    ClipOval(child: SizedBox(
                      width: isSmall ? 166 : 205, height: isSmall ? 166 : 205,
                      child: _buildHeroImage(),
                    )),
                    Positioned(top: 0, right: 8, child: Container(width: 17, height: 17,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4A176B)))),
                    Positioned(bottom: 0, left: 42, child: Container(width: 17, height: 17,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4A176B)))),
                  ]),
                ),
              ),
            ]);
          }),
        ),
      ]),
    );
  }

  Widget _buildHeroImage() {
    final r = _report ?? {};
    final url = r['heroImage']?.toString() ?? r['assessmentImage']?.toString();
    if (url != null && url.isNotEmpty) {
      return Image.network(url, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _heroPlaceholder());
    }
    // Speech-specific hero image from S3
    return Image.network(
      'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/speech-therapy-assessment.jpg',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _heroPlaceholder(),
    );
  }

  Widget _heroPlaceholder() => Container(
    color: const Color(0xFFEDE4F5),
    alignment: Alignment.center,
    child: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF8A63A8), size: 50),
  );

  // ── Client Information ───────────────────────────────────────────────────────
  Widget _buildClientInfo({
    required String childName, required String age, required String gender,
    required String dob, required String assessmentDate, required String therapist,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: const Border(bottom: BorderSide(color: Color(0xFF10B981), width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          Expanded(child: _infoTile('Child Name', childName)),
          const SizedBox(width: 8),
          Expanded(child: _infoTile('Age', age)),
          const SizedBox(width: 8),
          Expanded(child: _infoTile('Gender', gender)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _infoTile('Date of Birth', dob)),
          const SizedBox(width: 8),
          Expanded(child: _infoTile('Date of Assessment', assessmentDate)),
          const SizedBox(width: 8),
          Expanded(child: _infoTile('Therapist / Assessor', therapist)),
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
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF3B247A))),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 11, color: Color(0xFF1F2937))),
    ]),
  );

  // ── Reason for Referral ──────────────────────────────────────────────────────
  Widget _buildReasonForReferral({required String text}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7FE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2C9F0), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF1E4FA),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
          ),
          child: const Row(children: [
            Icon(Icons.assignment_outlined, color: Color(0xFF4A176B), size: 18),
            SizedBox(width: 7),
            Text('REASON FOR REFERRAL',
                style: TextStyle(color: Color(0xFF4A176B), fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 1),
                child: Text('•', style: TextStyle(color: Color(0xFF353241), fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(width: 9),
            Expanded(child: Text(text,
                style: const TextStyle(color: Color(0xFF3E3A47), fontSize: 13.5, height: 1.55))),
          ]),
        ),
      ]),
    );
  }

  // ============================================================================
  // CONTENT SECTIONS
  // ============================================================================
  List<Widget> _buildContentSections(_SpeechReportSections s) {
    return [
      _buildBackgroundInformation(s.background),
      if (s.observationDuring.isNotEmpty) _buildObservationDuring(s.observationDuring),
      if (s.observationResults.isNotEmpty) _buildObservationResults(s.observationResults),
      if (s.strengths.isNotEmpty) _buildBulletSection(
        title: 'Areas of Strengths',
        iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/areas.png',
        items: s.strengths,
        bgColor: const Color(0xFFF9F5FF),
        borderColor: const Color(0xFFF0E1FF),
        headerColor: const Color(0xFFF1E4FA),
      ),
      if (s.keyAreas.isNotEmpty) _buildBulletSection(
        title: 'Key Areas to Support and Growth',
        iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/key-areas.png',
        items: s.keyAreas,
        bgColor: const Color(0xFFF0FDF8),
        borderColor: const Color(0xFFD1FAE5),
        headerColor: const Color(0xFFD1FAE5),
        titleColor: const Color(0xFF059669),
      ),
      if (s.clinicalOutcome.isNotEmpty) _buildParaSection(
        title: 'Clinical Outcome',
        iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/clinical.png',
        lines: s.clinicalOutcome,
      ),
      if (s.therapyPlan.isNotEmpty) _buildBulletSection(
        title: 'Therapy Plan: Goals and Action Steps',
        iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/therapy-plan.png',
        items: s.therapyPlan,
        bgColor: const Color(0xFFFBF7FE),
        borderColor: const Color(0xFFF0E1FF),
        headerColor: const Color(0xFFF1E4FA),
      ),
      if (s.recommendations.isNotEmpty) _buildParaSection(
        title: 'Recommendations',
        lines: s.recommendations,
      ),
    ];
  }

  // ── shared card + header ─────────────────────────────────────────────────────
  Widget _sectionCard({required Widget child, Color borderColor = const Color(0xFFF0E1FF)}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }

  Widget _sectionHeader({required String title, String? iconUrl,
      Color bgColor = const Color(0xFFF1E4FA), Color titleColor = const Color(0xFF37115B)}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: bgColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8))),
      child: Row(children: [
        if (iconUrl != null) ...[
          Image.network(iconUrl, width: 22, height: 22, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.article_outlined, size: 18, color: Color(0xFF37115B))),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(title.toUpperCase(),
            style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3))),
      ]),
    );
  }

  // ── Background Information ───────────────────────────────────────────────────
  Widget _buildBackgroundInformation(Map<String, List<String>> bg) {
    Widget bgCard(String key, String label) {
      final items = bg[key] ?? [];
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F0FF), borderRadius: BorderRadius.circular(8),
            border: const Border(left: BorderSide(color: Color(0xFFFF5F59), width: 3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Color(0xFF37115B), fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (items.isEmpty)
              const Text('No information provided',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontStyle: FontStyle.italic))
            else
              ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(item, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 12, height: 1.5)),
              )),
          ]),
        ),
      );
    }

    return _sectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHeader(title: 'Background Information',
            iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/background.png'),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              bgCard('prenatal', 'Prenatal / Natal / Postnatal'), const SizedBox(width: 10),
              bgCard('medical', 'Medical History'),
            ]),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              bgCard('developmental', 'Developmental History'), const SizedBox(width: 10),
              bgCard('therapy', 'Therapy / Education'),
            ]),
            const SizedBox(height: 10),
            Row(children: [bgCard('family', 'Family / Social')]),
          ]),
        ),
      ]),
    );
  }

  // ── Observation During Assessment ────────────────────────────────────────────
  Widget _buildObservationDuring(List<String> lines) {
    return _sectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHeader(title: 'Observation During Assessment',
            iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/observation.png'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(l, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13, height: 1.55)),
            )).toList()),
        ),
      ]),
    );
  }

  // ── Observation & Results — speech dynamic domains ───────────────────────────
  Widget _buildObservationResults(Map<String, _SpeechDomain> results) {
    // Map key → icon number (A=1, B=2 … or numeric keys directly)
    String iconUrl(String key) {
      final num = int.tryParse(key);
      if (num != null) {
        final n = num.clamp(1, 10);
        return 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/$n.png';
      }
      // Letter keys: A=1, B=2 … J=10
      final idx = key.codeUnitAt(0) - 'A'.codeUnitAt(0) + 1;
      final n = idx.clamp(1, 10);
      return 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/$n.png';
    }

    Widget domainCell(_SpeechDomain d) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F0FF), borderRadius: BorderRadius.circular(8),
            border: const Border(left: BorderSide(color: Color(0xFF37115B), width: 3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Image.network(iconUrl(d.key), width: 28, height: 28, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.record_voice_over_outlined, size: 22, color: Color(0xFF37115B))),
            const SizedBox(height: 5),
            Text('${d.key}. ${d.title}',
                style: const TextStyle(color: Color(0xFF37115B), fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            d.content.isEmpty
                ? const Text('No data provided',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontStyle: FontStyle.italic))
                : Text(d.content, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 12, height: 1.5)),
          ]),
        ),
      );
    }

    // Build pairs from sorted keys
    final keys = results.keys.toList();
    final List<List<String>> pairs = [];
    for (int i = 0; i < keys.length; i += 2) {
      pairs.add([keys[i], if (i + 1 < keys.length) keys[i + 1]]);
    }

    return _sectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHeader(title: 'Observation & Results',
            iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/observation-results.png'),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: pairs.map((pair) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                domainCell(results[pair[0]]!),
                const SizedBox(width: 10),
                if (pair.length > 1)
                  domainCell(results[pair[1]]!)
                else
                  const Expanded(child: SizedBox()),
              ]),
            )).toList(),
          ),
        ),
      ]),
    );
  }

  // ── Bullet list section ──────────────────────────────────────────────────────
  Widget _buildBulletSection({
    required String title, String? iconUrl, required List<String> items,
    Color bgColor = const Color(0xFFFBF7FE),
    Color borderColor = const Color(0xFFF0E1FF),
    Color headerColor = const Color(0xFFF1E4FA),
    Color titleColor = const Color(0xFF37115B),
  }) {
    return _sectionCard(
      borderColor: borderColor,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHeader(title: title, iconUrl: iconUrl, bgColor: headerColor, titleColor: titleColor),
        Container(
          color: bgColor,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 5),
                    child: Container(width: 6, height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: titleColor))),
                const SizedBox(width: 9),
                Expanded(child: Text(item,
                    style: const TextStyle(color: Color(0xFF2B1F39), fontSize: 13, height: 1.5))),
              ]),
            )).toList()),
        ),
      ]),
    );
  }

  // ── Paragraph section ────────────────────────────────────────────────────────
  Widget _buildParaSection({required String title, String? iconUrl, required List<String> lines}) {
    return _sectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHeader(title: title, iconUrl: iconUrl),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(l, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13, height: 1.55)),
            )).toList()),
        ),
      ]),
    );
  }

  // ============================================================================
  // FOOTER
  // ============================================================================
  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF111827), Color(0xFF374151), Color(0xFF111827)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          // Top row: Founders | Services | Team
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: _footerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _founderItem('https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/home/hfcfounder1@2x.png', 'Rajat Vij', 'CEO & Founder'),
              const SizedBox(height: 10),
              _founderItem('https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/home/hfcfounder@2x.png', 'Ram Niwas', 'CTO & Founder'),
              const SizedBox(height: 8),
              const Text('Born From Personal Experience, Built For You',
                  style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 9, fontWeight: FontWeight.w500)),
            ]))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _footerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('OUR SERVICES', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...['Occupational Therapy','Speech Therapy','Behavioral Therapy','ABA Therapy','Special Education']
                  .map((s) => Padding(padding: const EdgeInsets.only(bottom: 3),
                      child: Text('• $s', style: const TextStyle(color: Colors.white, fontSize: 9.5)))),
            ]))),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: _footerCard(color: const Color(0xFF4B5563), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(children: [
                _teamMember('https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/home/dr.neha.png', 'Dr. Neha', 'Occupational Therapist'),
                const SizedBox(height: 6),
                _teamMember('https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/home/dr.priyanjali.png', 'Priyanjali', 'ABA & Special Edu.'),
                const SizedBox(height: 6),
                _teamMember('https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/home/dr.milii.png', 'Milli Ghosh', 'Speech Therapist'),
              ])),
              const SizedBox(width: 8),
              Expanded(child: Column(children: [
                _teamMember('https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/home/dr.manjeet.png', 'Manjeet', 'PhysioTherapist'),
                const SizedBox(height: 6),
                _teamMember('https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/home/dr.naveenn.png', 'Dr. Naveen', 'Occupational Therapist'),
                const SizedBox(height: 6),
                _teamMember('https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/home/navya.png', 'Navya Bharti', 'Language Pathologist'),
              ])),
            ]))),
          ]),
          const SizedBox(height: 8),
          // Bottom row: Contact | Logo | Shark Tank | Tests
          _footerCard(child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _contactItem('📞', '7688860000'), const SizedBox(width: 14),
                _contactItem('💬', '7665553554'),
              ]),
              const SizedBox(height: 5),
              _contactItem('✉️', 'info@hireforcare.com'),
              const SizedBox(height: 5),
              _contactItem('📍', 'Tenex Tower, Sector 116, Noida'),
            ])),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Image.network(
                'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/therapy-plan/occupational-therapy/hfc-footer.png',
                width: 100, height: 44, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text('HireForCare',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
              const SizedBox(height: 4),
              const Text('f  ig  in  tw  yt', style: TextStyle(color: Colors.white70, fontSize: 8)),
            ]),
            const SizedBox(width: 10),
            Column(children: [
              const Text('AS SEEN ON', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Image.network(
                'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/therapy-plan/occupational-therapy/Shark-Tank.png',
                width: 70, height: 38, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(width: 70, height: 38)),
            ]),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DIAGNOSIS TESTS', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Wrap(spacing: 8, runSpacing: 2,
                children: ['ISAA','ATON','MISIC','SFBT','DP3','VABS','VSMT','CBCL','NIMH','ANS','ANXIETY','CONNERS']
                    .map((t) => Text('• $t', style: const TextStyle(color: Colors.white, fontSize: 8))).toList()),
            ]),
          ])),
        ]),
      ),
    );
  }

  Widget _footerCard({required Widget child, Color color = const Color(0xFF374151)}) =>
      Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)), child: child);

  Widget _founderItem(String imgUrl, String name, String role) => Row(children: [
    ClipRRect(borderRadius: BorderRadius.circular(4),
        child: Image.network(imgUrl, width: 30, height: 30, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(width: 30, height: 30,
                decoration: BoxDecoration(color: const Color(0xFF4B5563), borderRadius: BorderRadius.circular(4)),
                child: const Icon(Icons.person, color: Colors.white54, size: 18)))),
    const SizedBox(width: 8),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      Text(role, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9)),
    ]),
  ]);

  Widget _teamMember(String imgUrl, String name, String role) => Row(children: [
    ClipOval(child: Image.network(imgUrl, width: 22, height: 22, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(width: 22, height: 22,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF6B7280)),
            child: const Icon(Icons.person, color: Colors.white54, size: 14)))),
    const SizedBox(width: 6),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
      Text(role, style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 8)),
    ])),
  ]);

  Widget _contactItem(String icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(icon, style: const TextStyle(fontSize: 10)),
    const SizedBox(width: 4),
    Text(text, style: const TextStyle(color: Colors.white, fontSize: 10)),
  ]);
}
