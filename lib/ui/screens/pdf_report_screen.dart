import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../services/storage_service.dart';
import 'assessment_report_detail_page.dart';
import 'assessment_speech_report_detail_page.dart';
import 'assessment_aba_report_detail_page.dart';
import 'assessment_sp-ed_report_detail_page.dart';
import 'therapy_plan_ot_detail_page.dart';
import 'therapy_plan_speech_detail_page.dart';
import 'therapy_plan_aba_detail_page.dart';
import 'therapy_plan_sp-ed_detail_page.dart';
import 'progress_report_detail_page.dart';
import 'pdf_viewer_page.dart'
    if (dart.library.io) 'pdf_viewer_page_stub.dart';

const List<Map<String, dynamic>> _kStaticReports = [
  {
    'id': '1',
    'title': 'Speech Therapy Assessment - Q1 2025',
    'category': 'speech_report',
    'createdAt': '2025-01-15T10:00:00Z',
    'therapyType': 'Speech Therapy',
    'childName': 'Aarav Sharma',
    'age': '5 years 3 months',
    'gender': 'Male',
    'dateOfBirth': '2019-10-12',
    'dateOfAssessment': '2025-01-15',
    'therapist': 'Navya Rathi',
    'reasonForReferral': 'Aarav was referred for evaluation due to concerns regarding speech delay, delayed milestones, difficulties with attention, and reported speech regression.',
    'reportContent': '''BACKGROUND INFORMATION
Prenatal / Natal / Postnatal History:
Full-term normal delivery. Birth weight 3.2 kg. No NICU admission. Birth cry was present.
Medical History:
No current medical concerns. No ongoing medication. No history of hospitalization.
Developmental History:
Delayed speech milestones noted. First words at 2.5 years. Walking achieved at 14 months. Developmental delay evident in expressive language.
Therapy / Education:
Currently receiving speech therapy for the past 6 months. Enrolled in mainstream preschool.
Family / Social:
Resides in a supportive home environment. Primary caregiver is mother. Screen time approximately 2 hours per day.

OBSERVATION DURING ASSESSMENT
Aarav was cooperative during the assessment session. He maintained eye contact intermittently and responded to his name consistently. Attention span was limited to approximately 3-5 minutes on structured tasks. He demonstrated interest in picture books and responded well to visual cues.

OBSERVATION & RESULTS
A. Sensory processing appeared within functional limits. No significant hypersensitivity observed during the session.
B. Gross motor skills are age-appropriate. Aarav walked, ran, and climbed stairs without difficulty.
C. Fine motor skills showed mild delays. Pencil grip was immature and cutting skills were emerging.
D. Visual-motor integration was below age expectations. Difficulty copying simple shapes observed.
E. Visual-perceptual skills were functional for age with some difficulty in figure-ground discrimination.
F. Bilateral coordination was adequate for most age-appropriate tasks.
G. Social communication was limited. Aarav used single words and occasional two-word phrases to communicate needs.
H. Cognitive skills appeared within low-average range based on task performance.
I. Activities of daily living showed age-appropriate independence in feeding and basic dressing with assistance.
J. Play skills were primarily solitary and functional. Limited symbolic play observed.
K. Attention and regulation required frequent redirection. Aarav benefited from structured routines.
L. Generalisation of learned skills was inconsistent across settings.

AREAS OF STRENGTHS
- Good eye contact and social smile
- Responds consistently to name
- Strong visual memory for familiar objects
- Cooperative and motivated during play-based activities
- Good gross motor skills

KEY AREAS TO SUPPORT AND GROWTH
- Expressive language development and vocabulary expansion
- Articulation and speech clarity
- Attention and task persistence
- Fine motor skill development
- Social communication and peer interaction

CLINICAL OUTCOME
Aarav presents with expressive language delay and mild articulation difficulties consistent with his age and developmental history. He demonstrates good potential for progress with targeted speech therapy intervention. Early and consistent intervention is recommended to support optimal communication development.

THERAPY PLAN
- Intensive speech therapy 3 sessions per week focusing on expressive language
- Vocabulary building through play-based activities
- Articulation therapy targeting age-appropriate phonemes
- Parent training and home program implementation
- Monthly progress review and goal updating

RECOMMENDATIONS
It is recommended that Aarav continue with regular speech therapy sessions. Parents are encouraged to implement home practice activities as guided by the therapist. A review assessment is recommended in 3 months to evaluate progress and update therapy goals accordingly.''',
  },
  {
    'id': '2',
    'title': 'Occupational Therapy Assessment Report',
    'category': 'ot_report',
    'createdAt': '2025-02-20T10:00:00Z',
    'therapyType': 'Occupational Therapy',
    'childName': 'Priya Patel',
    'age': '4 years 7 months',
    'gender': 'Female',
    'dateOfBirth': '2020-07-08',
    'dateOfAssessment': '2025-02-20',
    'therapist': 'Dr. Neha Singh',
    'reasonForReferral': 'Priya was referred for occupational therapy assessment due to concerns about fine motor delays, sensory processing difficulties, and challenges with daily self-care activities.',
    'reportContent': '''BACKGROUND INFORMATION
Prenatal / Natal / Postnatal History:
Full-term delivery via LSCS. Birth weight 2.9 kg. No complications reported post-delivery.
Medical History:
Diagnosed with mild sensory processing disorder. No ongoing medication.
Developmental History:
Milestones generally within range. Fine motor delays noted from age 3. Difficulty with self-care tasks.
Therapy / Education:
Receiving occupational therapy for 4 months. Enrolled in preschool with additional support.
Family / Social:
Supportive home environment. Parents actively involved in therapy. Daily routine is structured.

OBSERVATION DURING ASSESSMENT
Priya was initially hesitant but warmed up quickly. She demonstrated tactile sensitivity during sensory activities. Attention was adequate for short structured tasks. She was motivated by praise and preferred visual demonstrations.

OBSERVATION & RESULTS
A. Sensory processing showed hypersensitivity to tactile input and mild vestibular seeking behaviours.
B. Gross motor skills were age-appropriate. Balance and coordination were functional.
C. Fine motor skills showed delays. Tripod grasp was emerging. Difficulty with buttons and zippers.
D. Visual-motor integration was below age level. Difficulty with bead stringing and shape matching.
E. Visual-perceptual skills showed difficulty with spatial relationships and form constancy.
F. Bilateral coordination showed mild difficulty with tasks requiring two-hand coordination.
G. Social communication was age-appropriate. Priya engaged well with the therapist.
H. Cognitive skills appeared within average range.
I. Activities of daily living showed dependence in dressing and grooming tasks.
J. Play skills were age-appropriate with good imaginative play observed.
K. Attention and regulation were adequate with sensory breaks provided.
L. Generalisation was emerging with consistent practice at home.

AREAS OF STRENGTHS
- Good social engagement and communication
- Age-appropriate gross motor skills
- Strong imaginative play skills
- Motivated and responsive to positive reinforcement
- Good cognitive abilities

KEY AREAS TO SUPPORT AND GROWTH
- Fine motor skill development
- Sensory processing and regulation
- Self-care and daily living skills
- Visual-motor integration
- Bilateral coordination

CLINICAL OUTCOME
Priya presents with fine motor delays and sensory processing difficulties that impact her daily functioning and self-care independence. With targeted occupational therapy intervention and home program support, significant improvement is anticipated.

THERAPY PLAN
- Sensory integration therapy 2 sessions per week
- Fine motor skill activities including threading, cutting, and manipulation tasks
- Self-care skill training for dressing and grooming
- Home sensory diet program
- Parent education and coaching

RECOMMENDATIONS
Continued occupational therapy is strongly recommended. A sensory diet should be implemented at home and school. Review in 3 months to assess progress and modify goals as needed.''',
  },
  {
    'id': '3',
    'title': 'ABA Therapy Assessment - March 2025',
    'category': 'aba_report',
    'createdAt': '2025-03-10T10:00:00Z',
    'therapyType': 'ABA Therapy',
    'childName': 'Rohan Mehta',
    'age': '6 years 2 months',
    'gender': 'Male',
    'dateOfBirth': '2019-01-05',
    'dateOfAssessment': '2025-03-10',
    'therapist': 'Priyanjali Gupta',
    'reasonForReferral': 'Rohan was referred for ABA therapy assessment due to concerns regarding behavioral challenges, difficulty following instructions, limited social interaction with peers, and repetitive behaviors. The assessment aims to identify functional behavior patterns and develop targeted intervention strategies.',
    'licenseNumber': 'ABA-2025-0312',
    'reportContent': '''Background Information:
Rohan is a 6-year-old male diagnosed with Autism Spectrum Disorder (ASD) Level 2. He resides with both parents and one older sibling. Full-term delivery with no perinatal complications. Developmental delays were noted at 18 months. He began early intervention at age 2. Currently enrolled in a special education program. Parents report significant challenges with transitions, following multi-step instructions, and peer interaction. Screen time is approximately 3 hours per day. Sleep is reported as inconsistent.

Observation During Assessment:
Rohan was brought to the assessment centre by his mother. He entered the room without protest but required verbal prompting to sit. Eye contact was fleeting and inconsistent throughout the session. He engaged briefly with preferred toys (spinning objects, stacking blocks) but did not initiate joint attention. Vocal behaviour was limited to echolalia and occasional single-word requests. He demonstrated stereotypic hand-flapping when transitioning between activities. Compliance with structured tasks was approximately 40% without reinforcement.

Behavioral Observations:
Rohan displayed several behaviours consistent with ASD including restricted and repetitive behaviours, limited functional communication, and difficulty with social reciprocity. He responded to his name approximately 3 out of 10 trials. Manding (requesting) was observed for preferred items using single words. Tacting (labelling) was limited to 5-6 familiar objects. Listener responding was emerging for simple one-step instructions with visual support. Self-injurious behaviour (mild head-hitting) was observed twice during non-preferred task demands.

Clinical Impressions:
Based on the assessment findings, Rohan presents with significant deficits in verbal behaviour, social communication, and adaptive functioning consistent with ASD Level 2. His behavioural profile indicates the need for intensive ABA intervention targeting functional communication, reduction of problem behaviours, and skill acquisition across verbal operants. Strengths include motivation for preferred items, emerging imitation skills, and good gross motor abilities.

Procedures Used:
Verbal Behavior Milestones Assessment and Placement Program (VB-MAPP)
Assessment of Basic Language and Learning Skills - Revised (ABLLS-R)
Vineland Adaptive Behavior Scales (VABS-3)
Functional Behavior Assessment (FBA)
Direct observation across structured and unstructured settings
Parent interview and developmental history

Recommendations:
Intensive ABA therapy recommended at 20-25 hours per week
Functional Communication Training (FCT) to replace problem behaviours
Discrete Trial Training (DTT) for skill acquisition across verbal operants
Natural Environment Teaching (NET) to promote generalisation
Parent training and coaching sessions bi-weekly
Collaboration with special education team for school-based goals
Review assessment in 6 months to evaluate progress and update treatment plan''',
  },
  {
    'id': '4',
    'title': 'Special Education Assessment Report',
    'category': 'special_education_report',
    'createdAt': '2025-04-05T10:00:00Z',
    'therapyType': 'Special Education',
    'childName': 'Ananya Verma',
    'age': '7 years 1 month',
    'gender': 'Female',
    'dateOfBirth': '2018-03-20',
    'dateOfAssessment': '2025-04-05',
    'therapist': 'Sunita Rao',
    'reasonForReferral': 'Ananya was referred for special education assessment due to academic difficulties, challenges with reading comprehension, and difficulty retaining learned concepts. Teachers reported she requires additional support in classroom settings and benefits from individualized instruction strategies.',
    'licenseNumber': 'SPED-2025-0405',
    'reportContent': '''Background Information:
Ananya is a 7-year-old female diagnosed with Specific Learning Disability (SLD) in reading and written expression. She resides with both parents and one younger sibling. Full-term normal delivery with no perinatal complications. Developmental milestones were within normal limits. Academic difficulties were first noted in Grade 1. She is currently enrolled in Grade 2 at a mainstream school. Parents report significant challenges with reading fluency, spelling, and written tasks. She attends tuition support twice a week. No history of hearing or vision problems. Sleep and appetite are reported as normal.

Observation During Assessment:
Ananya was cooperative and friendly throughout the assessment. She required frequent encouragement to persist with challenging tasks. Attention was adequate for preferred activities but reduced during reading and writing tasks. She demonstrated good verbal communication skills and was able to express herself clearly. Frustration was observed during phonological tasks. She responded positively to praise and tangible rewards.

Behavioral Observations:
Ananya demonstrated age-appropriate social skills and peer interaction. She followed instructions well and maintained appropriate classroom behaviour during structured tasks. Pencil grip was functional but writing speed was notably slow. She frequently erased and rewrote letters, suggesting awareness of errors. Oral language skills were a relative strength compared to written language. She showed avoidance behaviours when presented with reading passages.

Clinical Impressions:
Based on the assessment findings, Ananya presents with a profile consistent with Specific Learning Disability in reading (dyslexia) and written expression. Phonological processing deficits, slow reading fluency, and spelling difficulties are the primary areas of concern. Her cognitive abilities are within the average range, indicating that her academic difficulties are not attributable to intellectual disability. With appropriate educational support and evidence-based interventions, significant improvement is anticipated.

Procedures Used:
Wechsler Intelligence Scale for Children - Fifth Edition (WISC-V)
Woodcock-Johnson Tests of Achievement - Fourth Edition (WJ-IV)
Comprehensive Test of Phonological Processing - Second Edition (CTOPP-2)
Gray Oral Reading Tests - Fifth Edition (GORT-5)
Beery-Buktenica Developmental Test of Visual-Motor Integration (Beery VMI)
Parent and teacher interview
Classroom observation

Recommendations:
Multisensory reading instruction using structured literacy approach (Orton-Gillingham based)
Individualized Education Program (IEP) with accommodations for extended time
Small group or one-on-one reading intervention 3-4 times per week
Assistive technology support including text-to-speech tools
Regular progress monitoring every 6-8 weeks
Parent training on home reading support strategies
Coordination with classroom teacher for curriculum modifications
Re-evaluation in 12 months to assess progress and update educational plan''',
  },
  {
    'id': '5',
    'title': 'Therapy Plan - Occupational Therapy',
    'category': 'therapy_plan',
    'createdAt': '2025-01-10T10:00:00Z',
    'therapyType': 'Occupational Therapy',
    'childName': 'Priya Patel',
    'age': '4 years 7 months',
    'gender': 'Female',
    'dateOfBirth': '2020-07-08',
    'dateOfAssessment': '2025-01-10',
    'therapist': 'Dr. Neha Singh',
    'reasonForReferral': 'Individualized therapy plan designed to address fine motor skill development, sensory integration, and daily living activities over a 3-month period.',
  },
  {
    'id': '6',
    'title': 'Therapy Plan - Speech Therapy',
    'category': 'therapy_plan',
    'createdAt': '2025-03-01T10:00:00Z',
    'therapyType': 'Speech Therapy',
    'childName': 'Aarav Sharma',
    'age': '5 years 3 months',
    'gender': 'Male',
    'dateOfBirth': '2019-10-12',
    'dateOfAssessment': '2025-03-01',
    'therapist': 'Navya Rathi',
    'reasonForReferral': 'Structured speech therapy plan focusing on expressive language, articulation, and vocabulary building through play-based intervention techniques.',
  },
  {
    'id': '7',
    'title': 'Therapy Plan - Special Education',
    'category': 'therapy_plan',
    'createdAt': '2025-04-10T10:00:00Z',
    'therapyType': 'Special Education',
    'childName': 'Ananya Verma',
    'age': '7 years 1 month',
    'gender': 'Female',
    'dateOfBirth': '2018-03-20',
    'dateOfAssessment': '2025-04-10',
    'therapist': 'Sunita Rao',
    'reasonForReferral': 'Individualized special education therapy plan targeting academic skill development, reading fluency, and learning strategies through structured multisensory intervention.',
  },
  {
    'id': '8',
    'title': 'Therapy Plan - ABA Therapy',
    'category': 'therapy_plan',
    'createdAt': '2025-03-15T10:00:00Z',
    'therapyType': 'ABA Therapy',
    'childName': 'Rohan Mehta',
    'age': '6 years 2 months',
    'gender': 'Male',
    'dateOfBirth': '2018-11-20',
    'dateOfAssessment': '2025-03-15',
    'therapist': 'Priyanjali',
    'reasonForReferral': 'Structured ABA therapy plan targeting social communication, behavior regulation, and adaptive skills through evidence-based behavioral intervention techniques.',
  },
  {
    'id': '9',
    'title': 'Progress Report - January 2025',
    'category': 'progress_report',
    'createdAt': '2025-01-31T10:00:00Z',
    'therapyType': 'Progress Report',
    'childName': 'Aarav Sharma',
    'age': '5 years 3 months',
    'gender': 'Male',
    'dateOfBirth': '2019-10-12',
    'dateOfAssessment': '2025-01-31',
    'therapist': 'Navya Rathi',
    'reasonForReferral': 'Monthly progress report documenting improvements in speech clarity, vocabulary expansion, and social communication skills. Aarav has shown significant progress in labelling objects and following two-step instructions.',
  },
  {
    'id': '10',
    'title': 'Progress Report - February 2025',
    'category': 'progress_report',
    'createdAt': '2025-02-28T10:00:00Z',
    'therapyType': 'Progress Report',
    'childName': 'Aarav Sharma',
    'age': '5 years 4 months',
    'gender': 'Male',
    'dateOfBirth': '2019-10-12',
    'dateOfAssessment': '2025-02-28',
    'therapist': 'Navya Rathi',
    'reasonForReferral': 'February progress report highlighting continued gains in expressive language, improved attention span during therapy sessions, and emerging ability to engage in short conversational exchanges with peers.',
  },
];

/// Reusable PDF report screen — used by Assessment, Therapy Plan, Progress Report
class PdfReportScreen extends StatefulWidget {
  final String title;
  final String categories;
  final IconData headerIcon;
  final bool useStaticData;

  const PdfReportScreen({
    Key? key,
    required this.title,
    required this.categories,
    required this.headerIcon,
    this.useStaticData = false,
  }) : super(key: key);

  @override
  State<PdfReportScreen> createState() => _PdfReportScreenState();
}

class _PdfReportScreenState extends State<PdfReportScreen> {
  static const String _base = 'https://api.hireforcare.com/api';
  static const Color _purple = Color(0xFF532A7B);

  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String? _error;
  String? _downloadingId;

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

    // Use static data if flag is set
    if (widget.useStaticData) {
      await Future.delayed(const Duration(milliseconds: 400));
      final cats = widget.categories.split(',');
      final filtered = _kStaticReports
          .where((r) => cats.contains(r['category']))
          .toList();
      setState(() { _reports = filtered; _loading = false; });
      return;
    }

    try {
      final h = await _headers();
      final res = await http.get(
        Uri.parse('$_base/pdf-uploads/my-reports?categories=${widget.categories}'),
        headers: h,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final uploads = data['uploads'] ?? data['data'] ?? [];
        setState(() {
          _reports = List<Map<String, dynamic>>.from(uploads);
          _loading = false;
        });
      } else if (res.statusCode == 401) {
        setState(() { _error = 'Session expired. Please log in again.'; _loading = false; });
      } else {
        throw Exception('Failed: ${res.statusCode}');
      }
    } catch (e) {
      setState(() { _error = 'Failed to load reports. Please try again.'; _loading = false; });
    }
  }

  Future<void> _openReport(Map<String, dynamic> report) async {
    final category = report['category']?.toString() ?? '';
    Widget page;
    if (category == 'therapy_plan') {
      final therapyType = report['therapyType']?.toString() ?? '';
      if (therapyType == 'Speech Therapy') {
        page = TherapyPlanSpeechDetailPage(report: report);
      } else if (therapyType == 'ABA Therapy') {
        page = TherapyPlanAbaDetailPage(report: report);
      } else if (therapyType == 'Special Education') {
        page = TherapyPlanSpEdDetailPage(report: report);
      } else {
        page = TherapyPlanDetailPage(report: report);
      }
    } else if (category == 'speech_report') {
      page = AssessmentSpeechReportDetailPage(report: report);
    } else if (category == 'aba_report') {
      page = AssessmentAbaReportDetailPage(report: report);
    } else if (category == 'special_education_report') {
      page = AssessmentSpEdReportDetailPage(report: report);
    } else if (category == 'progress_report') {
      page = ProgressReportDetailPage(report: report);
    } else {
      page = AssessmentReportDetailPage(report: report);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _downloadReport(Map<String, dynamic> report) async {
    final id = report['id']?.toString() ?? '';
    setState(() => _downloadingId = id);
    try {
      final token = await StorageService().getToken();
      final url = token != null
          ? '$_base/pdf-uploads/$id/download?token=${Uri.encodeComponent(token)}'
          : '$_base/pdf-uploads/$id/download';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) { return dateStr; }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'therapy_plan': return const Color(0xFF532A7B);
      case 'progress_report': return const Color(0xFF10B981);
      case 'speech_report': return const Color(0xFF3B82F6);
      case 'ot_report': return const Color(0xFF10B981);
      case 'aba_report': return const Color(0xFF06B6D4);
      case 'special_education_report': return const Color(0xFFF59E0B);
      default: return Colors.grey;
    }
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'therapy_plan': return 'Therapy Plan';
      case 'progress_report': return 'Progress Report';
      case 'speech_report': return 'Speech Report';
      case 'ot_report': return 'OT Report';
      case 'aba_report': return 'ABA Report';
      case 'special_education_report': return 'Special Education';
      default: return cat;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
      Icon(widget.headerIcon, size: 80, color: _purple.withOpacity(0.3)),
      const SizedBox(height: 16),
      Text('No ${widget.title} Yet', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('Your reports will appear here once uploaded', style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
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
    final id = report['id']?.toString() ?? '';
    final title = report['title']?.toString() ?? 'Untitled';
    final category = report['category']?.toString() ?? '';
    final date = report['createdAt']?.toString();
    final isDownloading = _downloadingId == id;
    final catColor = _categoryColor(category);

    return GestureDetector(
      onTap: () => _openReport(report),
      child: Container(
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
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_categoryLabel(category),
                        style: TextStyle(fontSize: 11, color: catColor, fontWeight: FontWeight.w600)),
                  ),
                  if (date != null && date.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(_formatDate(date), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ]),
                const SizedBox(height: 8),
                Text(
                  'Tap to view details',
                  style: TextStyle(fontSize: 11, color: _purple.withOpacity(0.7), fontWeight: FontWeight.w500),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            // View button
            GestureDetector(
              onTap: () => _openReport(report),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.visibility_rounded, color: _purple, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            // Download button
            GestureDetector(
              onTap: isDownloading ? null : () => _downloadReport(report),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isDownloading ? Colors.grey.shade200 : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isDownloading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2, color: _purple),
                      )
                    : const Icon(Icons.download_rounded, color: Colors.green, size: 22),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
