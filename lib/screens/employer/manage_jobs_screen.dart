import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pallijob/screens/employer/edit_job_screen.dart';
import 'package:pallijob/screens/student/student_job_listings_screen.dart';

class ManageJobsScreen extends StatefulWidget {
  const ManageJobsScreen({super.key, this.jobsStream});

  final Stream<List<StudentJobListing>>? jobsStream;

  @override
  State<ManageJobsScreen> createState() => _ManageJobsScreenState();
}

class _ManageJobsScreenState extends State<ManageJobsScreen> {
  late final String? _employerId = widget.jobsStream == null
      ? FirebaseAuth.instance.currentUser?.uid
      : null;
  late final Stream<List<StudentJobListing>>? _jobsStream = _createJobsStream();

  Stream<List<StudentJobListing>>? _createJobsStream() {
    final suppliedStream = widget.jobsStream;
    if (suppliedStream != null) {
      return suppliedStream.map(_sortByCreatedAt);
    }

    final employerId = _employerId;
    if (employerId == null) return null;

    return FirebaseFirestore.instance
        .collection('jobs')
        .where('employerId', isEqualTo: employerId)
        .snapshots()
        .map(
          (snapshot) => _sortByCreatedAt(
            snapshot.docs
                .map(StudentJobListing.fromDocument)
                .toList(growable: true),
          ),
        );
  }

  List<StudentJobListing> _sortByCreatedAt(List<StudentJobListing> jobs) {
    final sortedJobs = List<StudentJobListing>.of(jobs);
    sortedJobs.sort((first, second) {
      final firstDate = first.createdAt;
      final secondDate = second.createdAt;
      if (firstDate == null) return secondDate == null ? 0 : 1;
      if (secondDate == null) return -1;
      return secondDate.compareTo(firstDate);
    });
    return sortedJobs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text(
          'Manage Jobs',
          style: TextStyle(
            color: Color(0xFF173B27),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFFF8FBF8),
        surfaceTintColor: Colors.transparent,
      ),
      body: _jobsStream == null
          ? const _ManageJobsState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in to view your jobs',
              message: 'Your posted jobs are available after you sign in.',
            )
          : StreamBuilder<List<StudentJobListing>>(
              stream: _jobsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ManageJobsState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load your jobs',
                    message: _errorMessage(snapshot.error),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _ManageJobsState(
                    loading: true,
                    title: 'Loading your jobs',
                    message: 'Please wait while we load your listings.',
                  );
                }

                final jobs = snapshot.data ?? const <StudentJobListing>[];
                if (jobs.isEmpty) {
                  return const _ManageJobsState(
                    icon: Icons.work_outline_rounded,
                    title: 'You have not posted any jobs yet',
                    message: 'Jobs you post will appear here.',
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
                      itemCount: jobs.length + 1,
                      separatorBuilder: (_, index) =>
                          SizedBox(height: index == 0 ? 16 : 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Your job listings',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: const Color(0xFF173B27),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                              ),
                            ),
                          );
                        }

                        final job = jobs[index - 1];
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: _EmployerJobCard(
                              job: job,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      StudentJobDetailsScreen(job: job),
                                ),
                              ),
                              onEdit: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => EditJobScreen(job: job),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  String _errorMessage(Object? error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'You do not have permission to view your job listings. Check that you are signed in and the Firestore job read rules are deployed.';
    }
    if (error is FirebaseException &&
        (error.code == 'unavailable' ||
            error.code == 'network-request-failed')) {
      return 'Check your internet connection and try again.';
    }
    return 'Something went wrong while loading your jobs. Please try again later.';
  }
}

class _EmployerJobCard extends StatelessWidget {
  const _EmployerJobCard({
    required this.job,
    required this.onTap,
    required this.onEdit,
  });

  final StudentJobListing job;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5EEE7)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF173B27),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF247545),
                            size: 17,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              job.location,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFF647369)),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF247545),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        job.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF647369),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: ValueKey('edit-job-${job.id}'),
                tooltip: 'Edit ${job.title}',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF247545)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManageJobsState extends StatelessWidget {
  const _ManageJobsState({
    required this.title,
    required this.message,
    this.icon,
    this.loading = false,
  });

  final String title;
  final String message;
  final IconData? icon;
  final bool loading;

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
            ],
          ),
        ),
      ),
    );
  }
}
