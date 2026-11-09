import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pallijob/screens/student/student_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentVisaGuidanceData {
  const StudentVisaGuidanceData({
    required this.visaStatus,
    required this.jobTitle,
    required this.jobLocation,
    required this.jobRequirements,
  });

  final String? visaStatus;
  final String jobTitle;
  final String jobLocation;
  final String jobRequirements;
}

abstract interface class StudentVisaGuidanceService {
  Future<StudentVisaGuidanceData> loadGuidance(String jobId);
}

class FirestoreStudentVisaGuidanceService
    implements StudentVisaGuidanceService {
  const FirestoreStudentVisaGuidanceService();

  @override
  Future<StudentVisaGuidanceData> loadGuidance(String jobId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const StudentVisaGuidanceException(
        'Sign in with a student account to check visa guidance.',
      );
    }

    final firestore = FirebaseFirestore.instance;
    final profile = await firestore.collection('users').doc(user.uid).get();
    if (profile.data()?['role'] != 'student') {
      throw const StudentVisaGuidanceException(
        'Only student accounts can view visa guidance.',
      );
    }
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw const StudentVisaGuidanceException(
        'Your session changed. Please sign in again.',
      );
    }

    final job = await firestore.collection('jobs').doc(jobId).get();
    if (!job.exists) {
      throw const StudentVisaGuidanceException(
        'This job is no longer available.',
        code: StudentVisaGuidanceError.jobNotFound,
      );
    }

    final profileData = profile.data()!;
    final jobData = job.data()!;
    final visaStatus = profileData['visaStatus'];
    return StudentVisaGuidanceData(
      visaStatus: visaStatus is String && visaStatus.trim().isNotEmpty
          ? visaStatus.trim()
          : null,
      jobTitle: _jobValue(jobData, 'title'),
      jobLocation: _jobValue(jobData, 'location'),
      jobRequirements: _jobValue(jobData, 'requirements'),
    );
  }

  static String _jobValue(Map<String, dynamic> data, String field) {
    final value = data[field];
    return value is String && value.trim().isNotEmpty
        ? value.trim()
        : 'Not provided';
  }
}

enum StudentVisaGuidanceError { jobNotFound }

class StudentVisaGuidanceException implements Exception {
  const StudentVisaGuidanceException(this.message, {this.code});

  final String message;
  final StudentVisaGuidanceError? code;

  @override
  String toString() => message;
}

class StudentVisaEligibilityScreen extends StatefulWidget {
  const StudentVisaEligibilityScreen({
    super.key,
    required this.jobId,
    this.guidanceService = const FirestoreStudentVisaGuidanceService(),
  });

  final String jobId;
  final StudentVisaGuidanceService guidanceService;

  @override
  State<StudentVisaEligibilityScreen> createState() =>
      _StudentVisaEligibilityScreenState();
}

class _StudentVisaEligibilityScreenState
    extends State<StudentVisaEligibilityScreen> {
  late Future<StudentVisaGuidanceData> _guidance;

  @override
  void initState() {
    super.initState();
    _guidance = widget.guidanceService.loadGuidance(widget.jobId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text(
          'Visa Eligibility Guidance',
          style: TextStyle(
            color: Color(0xFF173B27),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFFF8FBF8),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<StudentVisaGuidanceData>(
          future: _guidance,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _GuidanceState(
                loading: true,
                title: 'Loading guidance',
                message:
                    'Please wait while we check your profile and job details.',
              );
            }
            if (snapshot.hasError) {
              return _GuidanceState(
                title:
                    snapshot.error is StudentVisaGuidanceException &&
                        (snapshot.error! as StudentVisaGuidanceException)
                                .code ==
                            StudentVisaGuidanceError.jobNotFound
                    ? 'Job no longer available'
                    : 'Could not load guidance',
                message: _errorMessage(snapshot.error!),
                icon: Icons.cloud_off_outlined,
                action: TextButton(
                  onPressed: () {
                    setState(() {
                      _guidance = widget.guidanceService.loadGuidance(
                        widget.jobId,
                      );
                    });
                  },
                  child: const Text('Retry'),
                ),
              );
            }

            return _buildGuidance(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildGuidance(StudentVisaGuidanceData guidance) {
    final missingVisaStatus = guidance.visaStatus == null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 360 ? 20.0 : 28.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Check work authorization',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF173B27),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This guidance summarizes the information currently in PalliJob. It does not determine legal eligibility.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF647369),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _GuidanceCard(
                    icon: Icons.badge_outlined,
                    title: 'Visa status on your profile',
                    content: guidance.visaStatus ?? 'Not provided',
                  ),
                  if (missingVisaStatus) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEBD9A9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add your visa status to your profile for reference.',
                            style: TextStyle(
                              color: Color(0xFF5C4A1A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            key: const ValueKey('complete-student-profile'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const StudentProfileScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.person_outline_rounded),
                            label: const Text('Complete My Profile'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _GuidanceCard(
                    icon: Icons.work_outline_rounded,
                    title: 'Job title',
                    content: guidance.jobTitle,
                  ),
                  const SizedBox(height: 10),
                  _GuidanceCard(
                    icon: Icons.location_on_outlined,
                    title: 'Location',
                    content: guidance.jobLocation,
                  ),
                  const SizedBox(height: 10),
                  _GuidanceCard(
                    icon: Icons.description_outlined,
                    title: 'Requirements',
                    content: guidance.jobRequirements,
                  ),
                  const SizedBox(height: 18),
                  _InformationPanel(
                    title: 'What still needs verification',
                    message: 'A visa label and this job listing do not show every condition that may affect work authorization. Verify the current conditions for your specific status, the actual duties and work arrangement, and whether any permission or approval is required.',
                  ),
                  const SizedBox(height: 12),
                  _InformationPanel(
                    title: 'Eligibility remains unverified',
                    message: 'PalliJob does not classify this job as legally eligible, safe, or prohibited. Confirm your situation with Korean Immigration before relying on this listing for work authorization.',
                    warning: true,
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    key: const ValueKey('open-hikorea'),
                    onPressed: _openImmigrationPortal,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Check HiKorea official guidance'),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openImmigrationPortal() async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://www.hikorea.go.kr/'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _showPortalError();
      }
    } on PlatformException {
      if (mounted) _showPortalError();
    }
  }

  void _showPortalError() {
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

  static String _errorMessage(Object error) {
    if (error is StudentVisaGuidanceException) return error.message;
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Firestore denied access to your profile or this job. Sign in with a student account and try again.';
    }
    return 'We could not load your profile and job details. Check your connection and try again.';
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
    required this.icon,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5EEE7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF247545)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: const Color(0xFF647369)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF173B27),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final background = warning
        ? const Color(0xFFFFF3F0)
        : const Color(0xFFEDF4EF);
    final border = warning ? const Color(0xFFF2C8BE) : const Color(0xFFDCE8DF);
    final foreground = warning
        ? const Color(0xFF8A3020)
        : const Color(0xFF173B27);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: foreground, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _GuidanceState extends StatelessWidget {
  const _GuidanceState({
    required this.title,
    required this.message,
    this.loading = false,
    this.icon,
    this.action,
  });

  final String title;
  final String message;
  final bool loading;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator(color: Color(0xFF247545))
              else
                Icon(
                  icon ?? Icons.info_outline_rounded,
                  color: const Color(0xFF247545),
                  size: 36,
                ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF173B27),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: const Color(0xFF647369), height: 1.45),
              ),
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      ),
    );
  }
}
