import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmployerApplication {
  const EmployerApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.applicantId,
    required this.status,
    required this.dateApplied,
    required this.jobUnavailable,
  });

  final String id;
  final String jobId;
  final String jobTitle;
  final String applicantId;
  final String status;
  final DateTime? dateApplied;
  final bool jobUnavailable;
}

enum EmployerApplicationDecision { accepted, rejected }

abstract interface class EmployerApplicationsService {
  Future<List<EmployerApplication>> loadApplications();

  Future<void> updateStatus(
    String applicationId,
    EmployerApplicationDecision decision,
  );
}

class FirestoreEmployerApplicationsService
    implements EmployerApplicationsService {
  const FirestoreEmployerApplicationsService();

  @override
  Future<List<EmployerApplication>> loadApplications() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      throw const EmployerApplicationsException(
        'Sign in with an employer account to view applications.',
      );
    }

    final firestore = FirebaseFirestore.instance;
    final profile = await firestore.collection('users').doc(user.uid).get();
    if (profile.data()?['role'] != 'employer') {
      throw const EmployerApplicationsException(
        'Only employer accounts can view received applications.',
      );
    }
    if (auth.currentUser?.uid != user.uid) {
      throw const EmployerApplicationsException(
        'Your session changed. Please sign in again.',
      );
    }

    final jobs = await firestore
        .collection('jobs')
        .where('employerId', isEqualTo: user.uid)
        .get();
    final jobTitles = {
      for (final job in jobs.docs)
        job.id: _textValue(
          job.data()['title'],
          fallback: 'Job information unavailable',
        ),
    };
    final applicationSnapshot = await firestore
        .collection('applications')
        .where('employerId', isEqualTo: user.uid)
        .get();

    final applications = <EmployerApplication>[];
    for (final application in applicationSnapshot.docs) {
      final data = application.data();
      final jobId = _textValue(data['jobId']);
      final jobTitle = jobTitles[jobId];
      final appliedAt = data['dateApplied'];
      applications.add(
        EmployerApplication(
          id: application.id,
          jobId: jobId,
          jobTitle: jobTitle ?? 'Job no longer available',
          applicantId: _textValue(data['studentId'], fallback: 'Unknown'),
          status: _textValue(data['status'], fallback: 'Unknown'),
          dateApplied: appliedAt is Timestamp ? appliedAt.toDate() : null,
          jobUnavailable: jobTitle == null,
        ),
      );
    }

    applications.sort(
      (left, right) => (right.dateApplied ?? DateTime(0)).compareTo(
        left.dateApplied ?? DateTime(0),
      ),
    );
    return applications;
  }

  @override
  Future<void> updateStatus(
    String applicationId,
    EmployerApplicationDecision decision,
  ) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      throw const EmployerApplicationDecisionException(
        'Sign in with an employer account to update applications.',
      );
    }

    final firestore = FirebaseFirestore.instance;
    final profileReference = firestore.collection('users').doc(user.uid);
    final applicationReference = firestore
        .collection('applications')
        .doc(applicationId);

    await firestore.runTransaction((transaction) async {
      final profile = await transaction.get(profileReference);
      if (profile.data()?['role'] != 'employer') {
        throw const EmployerApplicationDecisionException(
          'Only employer accounts can update applications.',
        );
      }

      final application = await transaction.get(applicationReference);
      final data = application.data();
      if (data == null) {
        throw const EmployerApplicationDecisionException(
          'This application no longer exists.',
        );
      }
      if (data['status'] != 'pending') {
        throw const EmployerApplicationDecisionException(
          'Only pending applications can be updated.',
        );
      }
      if (data['employerId'] != user.uid) {
        throw const EmployerApplicationDecisionException(
          'You can only update applications for your own jobs.',
        );
      }

      final jobId = data['jobId'];
      if (jobId is! String || jobId.trim().isEmpty) {
        throw const EmployerApplicationDecisionException(
          'This application has invalid job information.',
        );
      }
      final job = await transaction.get(
        firestore.collection('jobs').doc(jobId),
      );
      if (job.data()?['employerId'] != user.uid) {
        throw const EmployerApplicationDecisionException(
          'You can only update applications for jobs you own.',
        );
      }
      if (auth.currentUser?.uid != user.uid) {
        throw const EmployerApplicationDecisionException(
          'Your session changed. Please sign in again.',
        );
      }

      transaction.update(applicationReference, {'status': decision.name});
    });
  }

  static String _textValue(Object? value, {String fallback = ''}) {
    if (value is! String || value.trim().isEmpty) return fallback;
    return value.trim();
  }
}

class EmployerApplicationDecisionException implements Exception {
  const EmployerApplicationDecisionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EmployerApplicationsException implements Exception {
  const EmployerApplicationsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EmployerApplicationsScreen extends StatefulWidget {
  const EmployerApplicationsScreen({super.key, this.applicationsService});

  final EmployerApplicationsService? applicationsService;

  @override
  State<EmployerApplicationsScreen> createState() =>
      _EmployerApplicationsScreenState();
}

class _EmployerApplicationsScreenState
    extends State<EmployerApplicationsScreen> {
  late Future<List<EmployerApplication>> _applicationsFuture;
  final Set<String> _updatingApplicationIds = {};

  EmployerApplicationsService get _service =>
      widget.applicationsService ??
      const FirestoreEmployerApplicationsService();

  @override
  void initState() {
    super.initState();
    _applicationsFuture = _service.loadApplications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text(
          'View Applications',
          style: TextStyle(
            color: Color(0xFF173B27),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFFF8FBF8),
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<List<EmployerApplication>>(
        future: _applicationsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _EmployerApplicationsState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load applications',
              message: _errorMessage(snapshot.error),
              action: TextButton(
                onPressed: () {
                  setState(() {
                    _applicationsFuture = _service.loadApplications();
                  });
                },
                child: const Text('Retry'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _EmployerApplicationsState(
              loading: true,
              title: 'Loading applications',
              message: 'Please wait while we load applications for your jobs.',
            );
          }

          final applications = snapshot.data ?? const <EmployerApplication>[];
          if (applications.isEmpty) {
            return const _EmployerApplicationsState(
              icon: Icons.assignment_outlined,
              title: 'No applications received yet',
              message: 'Applications for your job listings will appear here.',
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
                itemBuilder: (context, index) {
                  final application = applications[index];
                  return _EmployerApplicationCard(
                    application: application,
                    isUpdating: _updatingApplicationIds.contains(
                      application.id,
                    ),
                    onDecision: (decision) =>
                        _confirmDecision(application, decision),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDecision(
    EmployerApplication application,
    EmployerApplicationDecision decision,
  ) async {
    if (application.status != 'pending' ||
        application.jobUnavailable ||
        _updatingApplicationIds.contains(application.id)) {
      return;
    }

    final decisionLabel = decision == EmployerApplicationDecision.accepted
        ? 'Accept'
        : 'Reject';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$decisionLabel application?'),
        content: Text(
          '$decisionLabel the application from ${application.applicantId} for ${application.jobTitle}?',
        ),
        actions: [
          TextButton(
            key: ValueKey('cancel-decision-${application.id}'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: ValueKey('confirm-decision-${application.id}'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(decisionLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _saveDecision(application, decision);
  }

  Future<void> _saveDecision(
    EmployerApplication application,
    EmployerApplicationDecision decision,
  ) async {
    setState(() => _updatingApplicationIds.add(application.id));

    Object? error;
    try {
      await _service.updateStatus(application.id, decision);
    } catch (caught) {
      error = caught;
    } finally {
      if (mounted) {
        setState(() {
          _updatingApplicationIds.remove(application.id);
          if (error == null) {
            _applicationsFuture = _service.loadApplications();
          }
        });
      }
    }

    if (!mounted) return;
    final message = error == null
        ? 'Application ${decision.name}.'
        : _decisionErrorMessage(error);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error == null ? null : const Color(0xFF9B2C2C),
        ),
      );
  }

  String _decisionErrorMessage(Object error) {
    if (error is EmployerApplicationDecisionException) return error.message;
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Firestore denied this decision. Confirm you own this job, are signed in as an employer, and that the application update rules are deployed.';
    }
    if (error is FirebaseException &&
        (error.code == 'unavailable' ||
            error.code == 'network-request-failed')) {
      return 'Could not reach Firebase. Check your connection and try again.';
    }
    if (error is FirebaseException) {
      return 'A Firebase error occurred while updating the application. Please try again.';
    }
    return 'Could not update the application. Please try again. ($error)';
  }
}

class _EmployerApplicationCard extends StatelessWidget {
  const _EmployerApplicationCard({
    required this.application,
    required this.isUpdating,
    required this.onDecision,
  });

  final EmployerApplication application;
  final bool isUpdating;
  final ValueChanged<EmployerApplicationDecision> onDecision;

  @override
  Widget build(BuildContext context) {
    final dateText = application.dateApplied == null
        ? 'Date unavailable'
        : 'Submitted ${MaterialLocalizations.of(context).formatMediumDate(application.dateApplied!)}';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
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
                Text(
                  application.jobTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF173B27),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (application.jobUnavailable) ...[
                  const SizedBox(height: 5),
                  Text(
                    'This job listing is no longer available.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF647369)),
                  ),
                ],
                const SizedBox(height: 12),
                _ApplicationDetail(
                  label: 'Applicant ID',
                  value: application.applicantId,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ApplicationDetail(
                        label: 'Status',
                        value: _formatStatus(application.status),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ApplicationDetail(
                        label: 'Date applied',
                        value: dateText.replaceFirst('Submitted ', ''),
                      ),
                    ),
                  ],
                ),
                if (application.status == 'pending' &&
                    !application.jobUnavailable) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (isUpdating) ...[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Saving decision...')),
                      ] else
                        const Spacer(),
                      OutlinedButton(
                        key: ValueKey('reject-application-${application.id}'),
                        onPressed: isUpdating
                            ? null
                            : () => onDecision(
                                EmployerApplicationDecision.rejected,
                              ),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: ValueKey('accept-application-${application.id}'),
                        onPressed: isUpdating
                            ? null
                            : () => onDecision(
                                EmployerApplicationDecision.accepted,
                              ),
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplicationDetail extends StatelessWidget {
  const _ApplicationDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: const Color(0xFF647369)),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF173B27),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _formatStatus(String status) => status
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');

class _EmployerApplicationsState extends StatelessWidget {
  const _EmployerApplicationsState({
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
  if (error is EmployerApplicationsException) return error.message;
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'You do not have permission to view these applications. Verify your employer role and that the application access rules are deployed.';
  }
  if (error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'network-request-failed')) {
    return 'Check your internet connection and try again.';
  }
  if (error is FirebaseException) {
    return 'A Firebase error occurred while loading applications. Please try again.';
  }
  return 'Please try again. Your application records have not been changed.';
}
