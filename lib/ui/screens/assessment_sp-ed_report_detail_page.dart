import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/storage_service.dart';

class AssessmentSpEdReportDetailPage extends StatefulWidget {
  final Map<String, dynamic> report;
  const AssessmentSpEdReportDetailPage({Key? key, required this.report}) : super(key: key);
  @override
  State<AssessmentSpEdReportDetailPage> createState() => _AssessmentSpEdReportDetailPageState();
}

// ─── Parsed Sp.Ed sections ────────────────────────────────────────────────────
class _SpEdSection {
  final String title;
  final List<String> lines;
  const _SpEdSection({required this.title, required this.lines});
}

class _SpEdReportSections {
  final List<String> background;
  final List<String> observationDuring;
  final List<String> behavioralObservations;
  final List<String> clinicalImpressions;
  final List<String> proceduresUsed;
  final List<String> recommendations;
  final List<_SpEdSection> genericSections;
  const _SpEdReportSections({
    required this.background, required this.observationDuring,
    required this.behavioralObservations, required this.clinicalImpressions,
    required this.proceduresUsed, required this.recommendations,
    required this.genericSections,
  });
}

// ─── Parser — mirrors specialEducationReportTemplate.ts ──────────────────────
_SpEdReportSections _parseSpEdReportContent(String raw) {
  final lines = raw
      .replaceAll('\r\n', '\n').replaceAll('\r', '\n')
      .split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  final List<String> background = [], obsDuring = [], behavioral = [],
      clinical = [], procedures = [], recommendations = [];
  final List<_SpEdSection> generic = [];

  String currentSection = '';
  final List<String> buf = [];

  bool isHeader(String ln) =>
      ln.endsWith(':') && ln.length < 100 && RegExp(r'^[A-Z]').hasMatch(ln);

  void flush() {
    if (buf.isEmpty) return;
    final sec = currentSection.toLowerCase();
    final cleanLines = buf
        .map((l) => l.replaceAll(RegExp(r'^[\-•*]\s*'), ''))
        .where((l) => l.isNotEmpty).toList();

    if (sec.contains('client information')) {
      // skip — shown in header
    } else if (sec.contains('background')) {
      background.addAll(cleanLines);
    } else if (sec.contains('observation during')) {
      obsDuring.addAll(buf);
    } else if (sec.contains('behavioral observation') ||
        (sec.contains('observation') && sec.contains('result'))) {
      behavioral.addAll(buf);
    } else if (sec.contains('clinical impression') ||
        sec.contains('diagnosis') || sec.contains('summary')) {
      clinical.addAll(buf);
    } else if (sec.contains('procedure') || sec.contains('assessment tool')) {
      procedures.addAll(cleanLines);
    } else if (sec.contains('recommendation')) {
      recommendations.addAll(cleanLines);
    } else if (currentSection.isNotEmpty) {
      generic.add(_SpEdSection(title: currentSection, lines: buf.toList()));
    }
    buf.clear();
    currentSection = '';
  }

  for (final ln in lines) {
    if (isHeader(ln)) {
      flush();
      currentSection = ln.replaceAll(RegExp(r':$'), '').trim();
    } else {
      buf.add(ln);
    }
  }
  flush();

  return _SpEdReportSections(
    background: background, observationDuring: obsDuring,
    behavioralObservations: behavioral, clinicalImpressions: clinical,
    proceduresUsed: procedures, recommendations: recommendations,
    genericSections: generic,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class _AssessmentSpEdReportDetailPageState extends State<AssessmentSpEdReportDetailPage> {
  static const String _base = 'https://api.hireforcare.com/api';
  static const Color _purple = Color(0xFF532A7B);

  Map<String, dynamic>? get _r => widget.report;

  String _fmt(String? d) {
    if (d == null || d.isEmpty) return '';
    try {
      final dt = DateTime.parse(d);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) { return d; }
  }

  String _catLabel(String cat) {
    switch (cat) {
      case 'special_education_report': return 'Special Education';
      case 'aba_report': return 'ABA Therapy';
      case 'speech_report': return 'Speech Therapy';
      case 'ot_report': return 'Occupational Therapy';
      default: return cat.replaceAll('_', ' ');
    }
  }

  Future<void> _openPdf() async {
    final id = _r?['id']?.toString() ?? '';
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
    final title = _r?['title']?.toString() ?? 'Report';
    final content = _r?['reportContent']?.toString() ??
        _r?['content']?.toString() ??
        _r?['rawContent']?.toString() ??
        _r?['body']?.toString() ?? '';
    final s = _parseSpEdReportContent(content);

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
          ..._buildContentSections(s),
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
    final therapyType = _r?['therapyType']?.toString() ?? _catLabel(_r?['category']?.toString() ?? '');
    final childName = _r?['childName']?.toString() ?? '[CHILD NAME]';
    final age       = _r?['age']?.toString() ?? '[AGE]';
    final gender    = _r?['gender']?.toString() ?? '[GENDER]';
    final dob       = _fmt(_r?['dateOfBirth']?.toString() ?? _r?['childDOB']?.toString());
    final asmtDate  = _fmt(_r?['dateOfAssessment']?.toString() ?? _r?['assessmentDate']?.toString() ?? _r?['createdAt']?.toString());
    final therapist = _r?['therapist']?.toString() ?? _r?['assessor']?.toString() ?? '[THERAPIST]';
    final license   = _r?['licenseNumber']?.toString() ?? '';
    final desc      = _r?['description']?.toString() ?? '';
    final referral  = _r?['reasonForReferral']?.toString() ?? _r?['referralReason']?.toString() ?? (desc.isNotEmpty ? desc : '[REASON FOR REFERRAL]');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHero(therapyType: therapyType),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildClientInfo(childName: childName, age: age, gender: gender,
              dob: dob.isNotEmpty ? dob : '[DATE OF BIRTH]',
              asmtDate: asmtDate.isNotEmpty ? asmtDate : '[DATE OF ASSESSMENT]',
              therapist: therapist, license: license),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildReasonForReferral(text: referral),
        ),
        const SizedBox(height: 22),
      ]),
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────────────────
  Widget _buildHero({required String therapyType}) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(30, 24, 30, 22),
          color: const Color(0xFFFBF9FE),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Image.network(
                'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/therapy-plan/occupational-therapy/hireforcare-left.png',
                height: 45, fit: BoxFit.contain, alignment: Alignment.centerLeft,
                errorBuilder: (_, __, ___) => const Text('HIREFORCARE',
                    style: TextStyle(color: Color(0xFF3B247A), fontSize: 21, fontWeight: FontWeight.w800))),
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
        Container(
          height: 280,
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
                colors: [Color(0xFF35105D), Color(0xFF4A176B), Color(0xFF3B247A)]),
          ),
          child: LayoutBuilder(builder: (context, constraints) {
            final small = constraints.maxWidth < 430;
            return Stack(clipBehavior: Clip.none, children: [
              Positioned(left: 28, top: 44, right: small ? 120 : 160,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(therapyType, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: small ? 29 : 35, fontWeight: FontWeight.w800, height: 1.02)),
                  const SizedBox(height: 7),
                  Text('Assessment Report', maxLines: 2,
                      style: TextStyle(color: Colors.white, fontSize: small ? 25 : 31, fontWeight: FontWeight.w700, height: 1.05)),
                  const SizedBox(height: 18),
                  const Text('Comprehensive Educational Evaluation', maxLines: 2,
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.2)),
                  const SizedBox(height: 16),
                  Container(width: 95, height: 2, color: const Color(0xFFFF7964)),
                ]),
              ),
              Positioned(right: small ? -35 : -18, top: small ? 32 : 18,
                child: SizedBox(width: small ? 200 : 245, height: small ? 200 : 245,
                  child: Stack(alignment: Alignment.center, children: [
                    Container(width: small ? 200 : 245, height: small ? 200 : 245,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 9))),
                    Container(width: small ? 181 : 222, height: small ? 181 : 222,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFB88ADE), width: 2))),
                    ClipOval(child: SizedBox(width: small ? 166 : 205, height: small ? 166 : 205, child: _buildHeroImage())),
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
    final url = _r?['heroImage']?.toString() ?? _r?['assessmentImage']?.toString();
    if (url != null && url.isNotEmpty) {
      return Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _heroPlaceholder());
    }
    // Sp.Ed-specific hero image
    return Image.network(
      'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/special-education/special-education-assessment.png',
      fit: BoxFit.cover, errorBuilder: (_, __, ___) => _heroPlaceholder());
  }

  Widget _heroPlaceholder() => Container(
    color: const Color(0xFFEDE4F5), alignment: Alignment.center,
    child: const Icon(Icons.school_rounded, color: Color(0xFF8A63A8), size: 50));

  // ── Client Info ──────────────────────────────────────────────────────────────
  Widget _buildClientInfo({
    required String childName, required String age, required String gender,
    required String dob, required String asmtDate,
    required String therapist, required String license,
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
          Expanded(child: _infoTile('Date of Assessment', asmtDate)),
          const SizedBox(width: 8),
          Expanded(child: _infoTile('Therapist / Assessor', therapist)),
        ]),
        if (license.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _infoTile('Pre License Number', license)),
          ]),
        ],
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
        color: const Color(0xFFFBF7FE), borderRadius: BorderRadius.circular(10),
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
  List<Widget> _buildContentSections(_SpEdReportSections s) {
    return [
      if (s.background.isNotEmpty) _buildBackground(s.background),
      if (s.observationDuring.isNotEmpty) _buildParaSection(
        title: 'Observation During Assessment',
        iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/observation.png',
        lines: s.observationDuring,
      ),
      if (s.behavioralObservations.isNotEmpty) _buildParaSection(
        title: 'Behavioral Observations',
        iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/observation-results.png',
        lines: s.behavioralObservations,
      ),
      if (s.clinicalImpressions.isNotEmpty) _buildParaSection(
        title: 'Clinical Impressions',
        iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/clinical.png',
        lines: s.clinicalImpressions,
      ),
      if (s.proceduresUsed.isNotEmpty) _buildBulletSection(
        title: 'Procedures Used (Assessment Tools)',
        iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/observation-results.png',
        items: s.proceduresUsed,
      ),
      if (s.recommendations.isNotEmpty) _buildBulletSection(
        title: 'Recommendations',
        items: s.recommendations,
      ),
      for (final g in s.genericSections) _buildParaSection(title: g.title, lines: g.lines),
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

  // ── Background — bullet list ─────────────────────────────────────────────────
  Widget _buildBackground(List<String> items) {
    return _sectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHeader(title: 'Background Information',
            iconUrl: 'https://hireforcare-media.s3.ap-south-1.amazonaws.com/images/report/speech-assessment/background.png'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(margin: const EdgeInsets.only(top: 6), width: 6, height: 6,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF5F59))),
                const SizedBox(width: 10),
                Expanded(child: Text(item,
                    style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13, height: 1.6))),
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
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13, height: 1.6)),
            )).toList()),
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
    Color dotColor = const Color(0xFF37115B),
  }) {
    return _sectionCard(
      borderColor: borderColor,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHeader(title: title, iconUrl: iconUrl, bgColor: headerColor),
        Container(
          color: bgColor,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 5),
                    child: Container(width: 6, height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor))),
                const SizedBox(width: 9),
                Expanded(child: Text(item,
                    style: const TextStyle(color: Color(0xFF2B1F39), fontSize: 13, height: 1.5))),
              ]),
            )).toList()),
        ),
      ]),
    );
  }

  // ============================================================================
  // FOOTER — Sp.Ed diagnosis tests
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
            // Sp.Ed-specific diagnosis tests (same as ABA per template)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DIAGNOSIS TESTS', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Wrap(spacing: 8, runSpacing: 2,
                children: ['CBCL','VABS','ADOS-2','ADI-R','VB-MAPP','ABLLS-R','PEAK','AFLS','SRS','ABC','CARS-2','PEP-3']
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
