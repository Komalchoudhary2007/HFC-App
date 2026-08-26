import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/storage_service.dart';

class AssessmentReportDetailPage extends StatefulWidget {
  final Map<String, dynamic> report;

  const AssessmentReportDetailPage({Key? key, required this.report}) : super(key: key);

  @override
  State<AssessmentReportDetailPage> createState() => _AssessmentReportDetailPageState();
}

// ─── Parsed report sections ───────────────────────────────────────────────────
class _ReportSections {
  final Map<String, List<String>> background; // prenatal/medical/developmental/therapy/family
  final List<String> observationDuring;
  final Map<String, String> observationResults; // A–L
  final List<String> strengths;
  final List<String> keyAreas;
  final List<String> clinicalOutcome;
  final List<String> therapyPlan;
  final List<String> recommendations;
  const _ReportSections({
    required this.background, required this.observationDuring,
    required this.observationResults, required this.strengths,
    required this.keyAreas, required this.clinicalOutcome,
    required this.therapyPlan, required this.recommendations,
  });
}

_ReportSections _parseReportContent(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n')
      .split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  final Map<String, List<String>> bg = {
    'prenatal': [], 'medical': [], 'developmental': [], 'therapy': [], 'family': []
  };
  final List<String> obsDuring = [], strengths = [], keyAreas = [],
      clinicalOutcome = [], therapyPlan = [], recommendations = [];
  final Map<String, String> obsResults = {};

  String currentSection = '';
  final List<String> buf = [];
  String bgCat = '';

  bool _isBgCatHeader(String ln) {
    return RegExp(r'^prenatal\s*\/?\s*natal\s*\/?\s*postnatal\s*(history)?\s*:?\s*$', caseSensitive: false).hasMatch(ln) ||
        RegExp(r'^medical\s+history\s*:?\s*$', caseSensitive: false).hasMatch(ln) ||
        RegExp(r'^developmental\s+history\s*:?\s*$', caseSensitive: false).hasMatch(ln) ||
        RegExp(r'^therapy\s*\/?\s*education\s*(history)?\s*:?\s*$', caseSensitive: false).hasMatch(ln) ||
        RegExp(r'^family\s*\/?\s*social\s*(history)?\s*:?\s*$', caseSensitive: false).hasMatch(ln);
  }

  bool _isHeading(String ln) {
    if (_isBgCatHeader(ln)) return false;
    final norm = ln.replaceAll(RegExp(r'\s+'), ' ');
    return (ln.length < 120 && RegExp(r'^[A-Z0-9 &\/\-,]{3,}$').hasMatch(ln) && ln == ln.toUpperCase()) ||
        RegExp(r'^(REASON FOR REFERRAL|BACKGROUND\s+INFORMATION|OBSERVATION\s+DURING\s+ASSESSMENT|OBSERVATION\s*(&|AND)\s*RESULTS|AREAS\s+OF\s+STRENGTHS|KEY\s+AREAS\s+TO\s+SUPPORT|CLINICAL\s+OUTCOME|THERAPY\s+PLAN|RECOMMENDATIONS)',
            caseSensitive: false).hasMatch(norm) ||
        ln.endsWith(':');
  }

  void _flushBg(List<String> lines) {
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final lower = t.toLowerCase();
      if (_isBgCatHeader(t)) {
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
      } else if (RegExp(r'^medical\s+history:', caseSensitive: false).hasMatch(lc)) {
        cat = 'medical';
      } else if (RegExp(r'^prenatal|^natal|^postnatal', caseSensitive: false).hasMatch(lc)) {
        cat = 'prenatal';
      } else if (RegExp(r'^developmental\s+history:', caseSensitive: false).hasMatch(lc)) {
        cat = 'developmental';
      } else if (RegExp(r'^therapy|^education', caseSensitive: false).hasMatch(lc)) {
        cat = 'therapy';
      } else if (RegExp(r'^family|^social', caseSensitive: false).hasMatch(lc)) {
        cat = 'family';
      } else if (!RegExp(r'diagnosed\s+with|diagnosis\s+of|syndrome', caseSensitive: false).hasMatch(lc) &&
          RegExp(r'prenatal|nicu|preterm|birth|apgar|pregnancy|maternal|labor|delivery|neonatal|gestational|cesarean|prematur', caseSensitive: false).hasMatch(lc)) {
        cat = 'prenatal';
      } else if (RegExp(r'occupational\s+therapy|speech\s+therapy|special\s+education|receiving.*therapy|enrolled\s+in|formal\s+education', caseSensitive: false).hasMatch(lc)) {
        cat = 'therapy';
      } else if (RegExp(r'diagnosed\s+with|diagnosis\s+of|syndrome|illness|medication|treatment|surgery|hospitalization', caseSensitive: false).hasMatch(lc)) {
        cat = 'medical';
      } else if (RegExp(r'developmental\s+delay|milestone|motor|walking|sitting|crawling|babbling|head\s+control', caseSensitive: false).hasMatch(lc)) {
        cat = 'developmental';
      } else if (RegExp(r'resides\s+in|supportive\s+home|primary\s+caregiver|screen\s+time|daily\s+routine|solitary\s+play', caseSensitive: false).hasMatch(lc)) {
        cat = 'family';
      } else {
        cat = 'developmental';
      }
      bg[cat]!.add(clean);
    }
  }

  void _flushObsResults(List<String> lines) {
    String key = '';
    final Map<String, List<String>> sub = {};
    for (final line in lines) {
      final m = RegExp(r'^([A-L])\.\s*(.+)').firstMatch(line);
      if (m != null) {
        key = m.group(1)!;
        sub[key] = [m.group(2)!];
      } else if (key.isNotEmpty && line.trim().isNotEmpty) {
        sub[key]!.add(line.trim());
      }
    }
    sub.forEach((k, v) => obsResults[k] = v.join(' '));
  }

  void flush() {
    if (currentSection.isEmpty || buf.isEmpty) return;
    final sec = currentSection.toUpperCase();
    if (sec.contains('BACKGROUND INFORMATION')) {
      _flushBg(buf);
    } else if (sec.contains('OBSERVATION DURING ASSESSMENT')) {
      obsDuring.addAll(buf);
    } else if (RegExp(r'OBSERVATION\s*(&|AND)\s*RESULTS', caseSensitive: false).hasMatch(sec)) {
      _flushObsResults(buf);
    } else if (sec.contains('AREAS OF STRENGTHS')) {
      strengths.addAll(buf.map((l) => l.replaceAll(RegExp(r'^[\-•*]\s*'), '')));
    } else if (RegExp(r'KEY AREAS TO SUPPORT|AREAS TO SUPPORT AND GROWTH', caseSensitive: false).hasMatch(sec)) {
      keyAreas.addAll(buf.map((l) => l.replaceAll(RegExp(r'^[\-•*]\s*'), '')));
    } else if (sec.contains('CLINICAL OUTCOME')) {
      clinicalOutcome.addAll(buf);
    } else if (RegExp(r'THERAPY PLAN|GOALS AND ACTION STEPS', caseSensitive: false).hasMatch(sec)) {
      therapyPlan.addAll(buf.map((l) => l.replaceAll(RegExp(r'^[\-•*]\s*'), '')));
    } else if (RegExp(r'RECOMMENDATIONS?', caseSensitive: false).hasMatch(sec)) {
      recommendations.addAll(buf);
    }
    buf.clear();
    currentSection = '';
  }

  for (final ln in lines) {
    if (_isHeading(ln)) {
      flush();
      currentSection = ln;
    } else if (currentSection.isNotEmpty) {
      buf.add(ln);
    }
  }
  flush();

  return _ReportSections(
    background: bg, observationDuring: obsDuring,
    observationResults: obsResults, strengths: strengths,
    keyAreas: keyAreas, clinicalOutcome: clinicalOutcome,
    therapyPlan: therapyPlan, recommendations: recommendations,
  );
}
// ─────────────────────────────────────────────────────────────────────────────

class _AssessmentReportDetailPageState extends State<AssessmentReportDetailPage> {
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final d = DateTime.parse(dateStr);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) { return dateStr; }
  }

  Future<void> _openPdf() async {
    final id = _report?['id']?.toString() ?? '';
    final token = await StorageService().getToken();
    final url = token != null
        ? '$_base/pdf-uploads/$id/download?token=${Uri.encodeComponent(token)}'
        : '$_base/pdf-uploads/$id/download';
    final uri = Uri.parse(url);
    await launchUrl(uri,
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
    final sections = _parseReportContent(content);

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
          _buildAssessmentReportPage1(),
          ..._buildContentSections(sections),
          _buildFooter(),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  // ============================================================================
  // DYNAMIC ASSESSMENT REPORT — PAGE 1
  // ============================================================================

  Widget _buildAssessmentReportPage1() {
    final report = _report ?? {};

    final therapyType =
        report['therapyType']?.toString() ??
        report['assessmentType']?.toString() ??
        report['serviceType']?.toString() ??
        _categoryLabel(report['category']?.toString() ?? '');

    final childName = report['childName']?.toString() ?? '[CHILD NAME]';
    final age = report['age']?.toString() ?? report['childAge']?.toString() ?? '[AGE]';
    final gender = report['gender']?.toString() ?? '[GENDER]';
    final dob = _formatDate(report['dateOfBirth']?.toString() ?? report['childDOB']?.toString());
    final assessmentDate = _formatDate(
        report['dateOfAssessment']?.toString() ??
        report['assessmentDate']?.toString() ??
        report['createdAt']?.toString());
    final therapist =
        report['therapist']?.toString() ??
        report['assessor']?.toString() ??
        report['evaluator']?.toString() ??
        '[THERAPIST / ASSESSOR]';
    final description = report['description']?.toString() ?? '';
    final referralReason =
        report['reasonForReferral']?.toString() ??
        report['referralReason']?.toString() ??
        (description.isNotEmpty ? description : '[REASON FOR REFERRAL]');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildDynamicAssessmentHero(therapyType: therapyType),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildDynamicClientInformation(
            childName: childName, age: age, gender: gender,
            dob: dob.isNotEmpty ? dob : '[DATE OF BIRTH]',
            assessmentDate: assessmentDate.isNotEmpty ? assessmentDate : '[DATE OF ASSESSMENT]',
            therapist: therapist,
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildDynamicReasonForReferral(text: referralReason),
        ),
        const SizedBox(height: 22),
      ]),
    );
  }

  // ============================================================================
  // HERO
  // ============================================================================

  Widget _buildDynamicAssessmentHero({required String therapyType}) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12), topRight: Radius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // HIRE FOR CARE BRANDING
        Container(
          padding: const EdgeInsets.fromLTRB(30, 24, 30, 22),
          color: const Color(0xFFFBF9FE),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              ]),
            ),
            const SizedBox(width: 10),
            Container(
              width: 42, height: 52,
              decoration: BoxDecoration(color: const Color(0xFFF2EBFA), borderRadius: BorderRadius.circular(14)),
            ),
          ]),
        ),

        // MAIN HERO
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

              // TITLE
              Positioned(
                left: 28, top: 44, right: isSmall ? 120 : 160,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(therapyType,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: isSmall ? 29 : 35, fontWeight: FontWeight.w800, height: 1.02)),
                  const SizedBox(height: 7),
                  Text('Assessment Report',
                      maxLines: 2,
                      style: TextStyle(color: Colors.white, fontSize: isSmall ? 25 : 31, fontWeight: FontWeight.w700, height: 1.05)),
                  const SizedBox(height: 18),
                  const Text('Comprehensive Developmental Evaluation',
                      maxLines: 2,
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.2)),
                  const SizedBox(height: 16),
                  Container(width: 95, height: 2, color: const Color(0xFFFF7964)),
                ]),
              ),

              // CIRCULAR VISUAL
              Positioned(
                right: isSmall ? -35 : -18, top: isSmall ? 32 : 18,
                child: SizedBox(
                  width: isSmall ? 200 : 245, height: isSmall ? 200 : 245,
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                      width: isSmall ? 200 : 245, height: isSmall ? 200 : 245,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 9)),
                    ),
                    Container(
                      width: isSmall ? 181 : 222, height: isSmall ? 181 : 222,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFB88ADE), width: 2)),
                    ),
                    ClipOval(
                      child: SizedBox(
                        width: isSmall ? 166 : 205, height: isSmall ? 166 : 205,
                        child: _buildAssessmentHeroImage(),
                      ),
                    ),
                    Positioned(top: 0, right: 8,
                        child: Container(width: 17, height: 17,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4A176B)))),
                    Positioned(bottom: 0, left: 42,
                        child: Container(width: 17, height: 17,
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

  // ============================================================================
  // HERO IMAGE
  // ============================================================================

  Widget _buildAssessmentHeroImage() {
    final report = _report ?? {};
    final dynamicImageUrl =
        report['heroImage']?.toString() ??
        report['assessmentImage']?.toString() ??
        report['therapistChildImage']?.toString();

    if (dynamicImageUrl != null && dynamicImageUrl.isNotEmpty) {
      return Image.network(dynamicImageUrl, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _assessmentImagePlaceholder());
    }

    return Image.asset('assets/images/assessment_report_hero.png', fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _assessmentImagePlaceholder());
  }

  Widget _assessmentImagePlaceholder() {
    return Container(
      color: const Color(0xFFEDE4F5),
      alignment: Alignment.center,
      child: const Icon(Icons.person_outline_rounded, color: Color(0xFF8A63A8), size: 50),
    );
  }

  // ============================================================================
  // CLIENT INFORMATION
  // ============================================================================

  Widget _buildDynamicClientInformation({
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

  // ============================================================================
  // REASON FOR REFERRAL
  // ============================================================================

  Widget _buildDynamicReasonForReferral({required String text}) {
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
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Text('•', style: TextStyle(color: Color(0xFF353241), fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(text,
                  style: const TextStyle(color: Color(0xFF3E3A47), fontSize: 13.5, height: 1.55)),
            ),
          ]),
        ),
      ]),
    );
  }

  // ============================================================================
  // CONTENT SECTIONS — built from parsed reportContent
  // ============================================================================

  List<Widget> _buildContentSections(_ReportSections s) {
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

  Widget _sectionCard({required Widget child, Color borderColor = const Color(0xFFF0E1FF)}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }

  Widget _sectionHeader({
    required String title,
    String? iconUrl,
    Color bgColor = const Color(0xFFF1E4FA),
    Color titleColor = const Color(0xFF37115B),
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
      ),
      child: Row(children: [
        if (iconUrl != null) ...[
          Image.network(iconUrl, width: 22, height: 22, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.article_outlined, size: 18, color: Color(0xFF37115B))),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(title.toUpperCase(),
              style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
        ),
      ]),
    );
  }

  // ============================================================================
  // BACKGROUND INFORMATION
  // ============================================================================

  Widget _buildBackgroundInformation(Map<String, List<String>> bg) {
    Widget bgCard(String key, String label) {
      final items = bg[key] ?? [];
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F0FF),
            borderRadius: BorderRadius.circular(8),
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
        _sectionHeader(
          title: 'Background Information',
          iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/background.png',
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              bgCard('prenatal', 'Prenatal / Natal / Postnatal'),
              const SizedBox(width: 10),
              bgCard('medical', 'Medical History'),
            ]),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              bgCard('developmental', 'Developmental History'),
              const SizedBox(width: 10),
              bgCard('therapy', 'Therapy / Education'),
            ]),
            const SizedBox(height: 10),
            Row(children: [bgCard('family', 'Family / Social')]),
          ]),
        ),
      ]),
    );
  }

  // ============================================================================
  // OBSERVATION DURING ASSESSMENT
  // ============================================================================

  Widget _buildObservationDuring(List<String> lines) {
    return _sectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHeader(
          title: 'Observation During Assessment',
          iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/observation.png',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(l, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13, height: 1.55)),
            )).toList(),
          ),
        ),
      ]),
    );
  }

  // ============================================================================
  // OBSERVATION & RESULTS  (A-L two-column grid)
  // ============================================================================

  Widget _buildObservationResults(Map<String, String> results) {
    const titles = {
      'A': 'Sensory Processing',       'B': 'Gross Motor Skills',
      'C': 'Fine Motor Skills',        'D': 'Visual-Motor Integration',
      'E': 'Visual-Perceptual Skills', 'F': 'Bilateral Coordination',
      'G': 'Social & Communication',   'H': 'Cognitive Skills',
      'I': 'Activities of Daily Living (ADLs)', 'J': 'Play & Social Interaction',
      'K': 'Attention, Regulation & Executive Function',
      'L': 'Generalisation & Functional Understanding',
    };
    const baseUrl = 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/ot-assessment/';
    const pairs = [['A','B'],['C','D'],['E','F'],['G','H'],['I','J'],['K','L']];

    Widget cell(String key) {
      final content = results[key] ?? '';
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F0FF),
            borderRadius: BorderRadius.circular(8),
            border: const Border(left: BorderSide(color: Color(0xFF37115B), width: 3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Image.network('$baseUrl$key.png', width: 28, height: 28, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.assignment_outlined, size: 22, color: Color(0xFF37115B))),
            const SizedBox(height: 5),
            Text('$key. ${titles[key] ?? ''}',
                style: const TextStyle(color: Color(0xFF37115B), fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            content.isEmpty
                ? const Text('No data provided',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontStyle: FontStyle.italic))
                : Text(content, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 12, height: 1.5)),
          ]),
        ),
      );
    }

    return _sectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHeader(
          title: 'Observation & Results',
          iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/observation-results.png',
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: pairs.map((pair) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                cell(pair[0]), const SizedBox(width: 10), cell(pair[1]),
              ]),
            )).toList(),
          ),
        ),
      ]),
    );
  }

  // ============================================================================
  // BULLET LIST SECTION  (Strengths / Key Areas / Therapy Plan)
  // ============================================================================

  Widget _buildBulletSection({
    required String title,
    String? iconUrl,
    required List<String> items,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(width: 6, height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: titleColor)),
                ),
                const SizedBox(width: 9),
                Expanded(child: Text(item,
                    style: const TextStyle(color: Color(0xFF2B1F39), fontSize: 13, height: 1.5))),
              ]),
            )).toList(),
          ),
        ),
      ]),
    );
  }

  // ============================================================================
  // PARAGRAPH SECTION  (Clinical Outcome / Recommendations)
  // ============================================================================

  Widget _buildParaSection({
    required String title,
    String? iconUrl,
    required List<String> lines,
  }) {
    return _sectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHeader(title: title, iconUrl: iconUrl),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(l, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13, height: 1.55)),
            )).toList(),
          ),
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
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF374151), Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 2,
              child: _footerCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _founderItem(
                    imgUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/home/hfcfounder1@2x.png',
                    name: 'Rajat Vij', role: 'CEO & Founder',
                  ),
                  const SizedBox(height: 10),
                  _founderItem(
                    imgUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/home/hfcfounder@2x.png',
                    name: 'Ram Niwas', role: 'CTO & Founder',
                  ),
                  const SizedBox(height: 8),
                  const Text('Born From Personal Experience, Built For You',
                      style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 9, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _footerCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('OUR SERVICES',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...['Occupational Therapy','Speech Therapy','Behavioral Therapy','ABA Therapy','Special Education']
                      .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('• $s', style: const TextStyle(color: Colors.white, fontSize: 9.5)),
                      )),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _footerCard(
                color: const Color(0xFF4B5563),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          _footerCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                flex: 3,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _contactItem('📞', '7688860000'),
                    const SizedBox(width: 14),
                    _contactItem('💬', '7665553554'),
                  ]),
                  const SizedBox(height: 5),
                  _contactItem('✉️', 'info@hireforcare.com'),
                  const SizedBox(height: 5),
                  _contactItem('📍', 'Tenex Tower, Sector 116, Noida'),
                ]),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Image.network(
                  'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/therapy-plan/occupational-therapy/hfc-footer.png',
                  width: 100, height: 44, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text('HireForCare',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
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
                  errorBuilder: (_, __, ___) => const SizedBox(width: 70, height: 38),
                ),
              ]),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('DIAGNOSIS TESTS',
                    style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8, runSpacing: 2,
                  children: ['ISAA','ATON','MISIC','SFBT','DP3','VABS','VSMT','CBCL','NIMH','ANS','ANXIETY','CONNERS']
                      .map((t) => Text('• $t', style: const TextStyle(color: Colors.white, fontSize: 8)))
                      .toList(),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _footerCard({required Widget child, Color color = const Color(0xFF374151)}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: child,
    );
  }

  Widget _founderItem({required String imgUrl, required String name, required String role}) {
    return Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(imgUrl, width: 30, height: 30, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: const Color(0xFF4B5563), borderRadius: BorderRadius.circular(4)),
                child: const Icon(Icons.person, color: Colors.white54, size: 18))),
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        Text(role, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9)),
      ]),
    ]);
  }

  Widget _teamMember(String imgUrl, String name, String role) {
    return Row(children: [
      ClipOval(
        child: Image.network(imgUrl, width: 22, height: 22, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF6B7280)),
                child: const Icon(Icons.person, color: Colors.white54, size: 14))),
      ),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
        Text(role, style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 8)),
      ])),
    ]);
  }

  Widget _contactItem(String icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 10)),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.white, fontSize: 10)),
    ]);
  }
}
