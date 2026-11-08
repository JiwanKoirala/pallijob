import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentApplication {
  const StudentApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.location,
    required this.status,
    required this.dateApplied,
  });

  final String id;
  final String jobId;
  final String jobTitle;
  final String location;
  final String status;
  final DateTime? dateApplied;
}

abstract interface class StudentApplicationsService {
  Future<List<StudentApplication>> loadApplications();
}

class FirestoreStudentApplicationsService
    implements StudentApplicationsService {
  const FirestoreStudentApplicationsService();

  @override
  Future<List<StudentApplication>> loadApplications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const StudentApplicationsException(
        'Sign in with a student account to view your applications.',
      );
    }

    final firestore = FirebaseFirestore.instance;
    final profile = await firestore.collection('users').doc(user.uid).get();
    if (profile.data()?['role'] != 'student') {
      throw const StudentApplicationsException(
        'Only student accounts can view applications.',
      );
    }
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw const StudentApplicationsException(
        'Your session changed. Please sign in again.',
      );
    }

    final applicationSnapshot = await firestore
        .collection('applications')
        .where('studentId', isEqualTo: user.uid)
        .get();

    final applications = await Future.wait(
      applicationSnapshot.docs.map((document) async {
        final data = document.data();
        final jobId = _stringValue(data['jobId']);
        final job = jobId.isEmpty
            ? null
            : await firestore.collection('jobs').doc(jobId).get();
        final jobData = job?.data();
        final isMissingJob = job == null || !job.exists;
        final dateValue = data['dateApplied'];

        return StudentApplication(
          id: document.id,
          jobId: jobId,
          jobTitle: isMissingJob
              ? 'Job no longer available'
              : _textField(
                  jobData,
                  'title',
                  fallback: 'Job information unavailable',
                ),
          location: isMissingJob
              ? 'Listing unavailable'
              : _textField(jobData, 'location', fallback: 'Not provided'),
          status: _stringValue(data['status'], fallback: 'Unknown'),
          dateApplied: dateValue is Timestamp ? dateValue.toDate() : null,
        );
      }),
    );

    applications.sort(
      (left, right) => (right.dateApplied ?? DateTime(0)).compareTo(
        left.dateApplied ?? DateTime(0),
      ),
    );
    return applications;
  }

  static String _stringValue(Object? value, {String fallback = ''}) {
    if (value is! String || value.trim().isEmpty) return fallback;
    return value.trim();
  }

  static String _textField(
    Map<String, dynamic>? data,
    String key, {
    required String fallback,
  }) {
    return _stringValue(data?[key], fallback: fallback);
  }
}

class StudentApplicationsException implements Exception {
  const StudentApplicationsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StudentApplicationsScreen extends StatefulWidget {
  const StudentApplicationsScreen({
    super.key,
    this.applicationsService = const FirestoreStudentApplicationsService(),
  });

  final StudentApplicationsService applicationsService;

  @override
  State<StudentApplicationsScreen> createState() =>
      _StudentApplicationsScreenState();
}

class _StudentApplicationsScreenState extends State<StudentApplicationsScreen> {
  late Future<List<StudentApplication>> _applicationsFuture;

  @override
  void initState() {
    super.initState();
    _applicationsFuture = widget.applicationsService.loadApplications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text(
          'My Applications',
          style: TextStyle(
            color: Color(0xFF173B27),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFFF8FBF8),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh applications',
            onPressed: _refreshApplications,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<StudentApplication>>(
        future: _applicationsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ApplicationsState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load applications',
              message: _errorMessage(snapshot.error),
              action: TextButton(
                onPressed: () {
                  setState(() {
                    _applicationsFuture = widget.applicationsService
                        .loadApplications();
                  });
                },
                child: const Text('Retry'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ApplicationsState(
              loading: true,
              title: 'Loading applications',
              message: 'Please wait while we load your applications.',
            );
          }

          final applications = snapshot.data ?? const <StudentApplication>[];
          if (applications.isEmpty) {
            return const _ApplicationsState(
              icon: Icons.assignment_outlined,
              title: 'No applications yet',
              message: 'Applications you submit for jobs will appear here.',
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth < 360
                  ? 20.0
                  : 28.0;
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  20,
                  horizontalPadding,
                  32,
                ),
                itemCount: applications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _ApplicationCard(application: applications[index]),
              );
            },
          );
        },
      ),
    );
  }

  void _refreshApplications() {
    setState(() {
      _applicationsFuture = widget.applicationsService.loadApplications();
    });
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application});

  final StudentApplication application;

  @override
  Widget build(BuildContext context) {
    final dateText = application.dateApplied == null
        ? 'Date unavailable'
        : 'Applied ${MaterialLocalizations.of(context).formatMediumDate(application.dateApplied!)}';

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5EEE7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.work_outline_rounded,
                  color: Color(0xFF247545),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    application.jobTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF173B27),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusLabel(status: application.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF64816D),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    application.location,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: const Color(0xFF647369)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              dateText,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFF647369)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF247545),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ApplicationsState extends StatelessWidget {
  const _ApplicationsState({
    required this.title,
    required this.message,
    this.icon,
    this.loading = false,
    this.action,
  });

  final String title;
  final String message;
  final IconData? icon;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator(color: Color(0xFF247545))
              else
                Icon(icon, color: const Color(0xFF247545), size: 42),
              const SizedBox(height: 20),
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

String _errorMessage(Object? error) {
  if (error is StudentApplicationsException) return error.message;
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'You do not have permission to view these applications. Sign in with the student account that submitted them and make sure the application list rules are deployed.';
  }
  if (error is FirebaseException) {
    return 'A Firebase error occurred while loading applications. Please try again.';
  }
  return 'Please try again. Your application history has not been changed.';
}
