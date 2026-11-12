import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalResourceLauncher = Future<bool> Function(Uri uri);

class StudentWorkInformationScreen extends StatefulWidget {
  const StudentWorkInformationScreen({super.key, this.launchExternal});

  static final Uri hiKoreaUri = Uri.parse('https://www.hikorea.go.kr/');

  final ExternalResourceLauncher? launchExternal;

  @override
  State<StudentWorkInformationScreen> createState() =>
      _StudentWorkInformationScreenState();
}

class _StudentWorkInformationScreenState
    extends State<StudentWorkInformationScreen> {
  bool _isOpeningHiKorea = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text(
          'Work Information & FAQ',
          style: TextStyle(
            color: Color(0xFF173B27),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFFF8FBF8),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const _InformationPanel(
            title: 'Important: confirm before working',
            message: 'This page is general information, not legal advice. A D-2 or D-4 status alone does not confirm that a particular job is permitted. Check the current rules and any required permission or restrictions for your exact status and situation before starting work. PalliJob does not determine legal eligibility.',
            warning: true,
          ),
          const SizedBox(height: 24),
          Text(
            'Official immigration guidance',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF173B27),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'For current requirements, consult Korean Immigration and your '
            'university international office. Ask about your individual visa '
            'status, the actual work, and any permission or restrictions that '
            'may apply.',
            style: TextStyle(color: Color(0xFF536359), height: 1.5),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('open-work-info-hikorea'),
            onPressed: _isOpeningHiKorea ? null : _openHiKorea,
            icon: _isOpeningHiKorea
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_new_rounded),
            label: Text(
              _isOpeningHiKorea
                  ? 'Opening HiKorea…'
                  : 'Open official HiKorea guidance',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF247545),
              side: const BorderSide(color: Color(0xFF247545)),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const SelectableText(
            'https://www.hikorea.go.kr/',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF247545),
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(height: 14),
          const _InformationPanel(
            title: 'Immigration Contact Center',
            message:
                'Call 1345 for immigration information. For advice about your '
                'specific case, provide accurate details and follow the '
                'guidance from Korean Immigration.',
          ),
          const SizedBox(height: 28),
          Text(
            'Frequently asked questions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF173B27),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const _FaqTile(
            question: 'Can students with D-2 or D-4 status work part-time?',
            answer:
                'Rules can depend on your exact status and circumstances. '
                'Do not assume that a student status automatically permits '
                'work. Confirm with Korean Immigration and your university '
                'international office whether work is permitted and what '
                'conditions or prior permission may apply to you.',
          ),
          const _FaqTile(
            question: 'How do I check whether a job is allowed for me?',
            answer:
                'Ask your university international office and Korean '
                'Immigration about your current status, the job duties, and '
                'the work arrangement. Confirm any restrictions and required '
                'steps before accepting or starting the job. PalliJob cannot '
                'make this legal determination.',
          ),
          const _FaqTile(
            question: 'Where can I get official immigration information?',
            answer:
                'Use the official HiKorea information linked above, contact '
                'the Immigration Contact Center at 1345, and consult your '
                'university international office for guidance about your '
                'student circumstances.',
          ),
          const _FaqTile(
            question: 'How do I apply for a job in PalliJob?',
            answer:
                'Open Search Jobs, choose a listing to review its details, '
                'then use the apply action and confirm your application. '
                'Submitting an application in PalliJob does not verify '
                'immigration permission to work.',
          ),
          const _FaqTile(
            question: 'How do I track applications and contact employers?',
            answer:
                'Open My Applications to review your submitted applications '
                'and their status. When chat is available for an application, '
                'open its Chat entry to contact the employer. You can also '
                'use Notifications to review new messages and application '
                'updates.',
          ),
          const SizedBox(height: 16),
          const _InformationPanel(
            title: 'About this information',
            message:
                'PalliJob provides general information and job-search tools '
                'only. It does not automatically assess, approve, or guarantee '
                'legal eligibility for any job. Immigration requirements can '
                'change; verify them with official sources before acting.',
            warning: true,
          ),
        ],
      ),
    );
  }

  Future<void> _openHiKorea() async {
    setState(() => _isOpeningHiKorea = true);
    try {
      final launch = widget.launchExternal ?? _launchExternal;
      final opened = await launch(StudentWorkInformationScreen.hiKoreaUri);
      if (!opened && mounted) _showLaunchError();
    } on PlatformException {
      if (mounted) _showLaunchError();
    } finally {
      if (mounted) setState(() => _isOpeningHiKorea = false);
    }
  }

  Future<bool> _launchExternal(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showLaunchError() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open HiKorea. Visit https://www.hikorea.go.kr/',
          ),
        ),
      );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            color: Color(0xFF173B27),
            fontWeight: FontWeight.w600,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            answer,
            style: const TextStyle(color: Color(0xFF536359), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _InformationPanel extends StatelessWidget {
  const _InformationPanel({
    required this.title,
    required this.message,
    this.warning = false,
  });

  final String title;
  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFF8A5A13) : const Color(0xFF247545);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFF8E8) : Colors.white,
        border: Border.all(
          color: warning ? const Color(0xFFEAD8AD) : const Color(0xFFDCE8DF),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF536359), height: 1.5),
          ),
        ],
      ),
    );
  }
}
