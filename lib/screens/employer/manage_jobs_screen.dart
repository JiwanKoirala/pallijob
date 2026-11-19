import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pallijob/l10n/role_aware_strings.dart';
import 'package:pallijob/screens/employer/edit_job_screen.dart';
import 'package:pallijob/screens/student/student_job_listings_screen.dart';

class ManageJobsScreen extends StatefulWidget {
  const ManageJobsScreen({super.key, this.jobsStream, this.deleteJob});

  final Stream<List<StudentJobListing>>? jobsStream;
  final Future<void> Function(StudentJobListing job)? deleteJob;

  @override
  State<ManageJobsScreen> createState() => _ManageJobsScreenState();
}

class _ManageJobsScreenState extends State<ManageJobsScreen> {
  late final String? _employerId = widget.jobsStream == null
      ? FirebaseAuth.instance.currentUser?.uid
      : null;
  late final Stream<List<StudentJobListing>>? _jobsStream = _createJobsStream();
  final Set<String> _deletingJobIds = {};

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
          '채용 공고 관리',
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
              title: '로그인 후 공고를 확인할 수 있습니다',
              message: '로그인하면 내가 등록한 채용 공고를 확인할 수 있습니다.',
            )
          : StreamBuilder<List<StudentJobListing>>(
              stream: _jobsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ManageJobsState(
                    icon: Icons.cloud_off_outlined,
                    title: '공고를 불러오지 못했습니다',
                    message: _errorMessage(snapshot.error),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _ManageJobsState(
                    loading: true,
                    title: '공고를 불러오는 중',
                    message: '등록한 채용 공고를 불러오고 있습니다.',
                  );
                }

                final jobs = snapshot.data ?? const <StudentJobListing>[];
                if (jobs.isEmpty) {
                  return const _ManageJobsState(
                    icon: Icons.work_outline_rounded,
                    title: '아직 등록한 공고가 없습니다',
                    message: '새 채용 공고를 등록하면 여기에 표시됩니다.',
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
                                  '내 채용 공고',
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
                                  builder: (_) => StudentJobDetailsScreen(
                                    job: job,
                                    isEmployerView: true,
                                  ),
                                ),
                              ),
                              onEdit: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => EditJobScreen(job: job),
                                ),
                              ),
                              isDeleting: _deletingJobIds.contains(job.id),
                              onDelete: () => _confirmDeleteJob(job),
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
      return '공고를 확인할 권한이 없습니다. 고용주 계정으로 로그인했는지, Firestore 공고 조회 규칙이 배포되었는지 확인해 주세요.';
    }
    if (error is FirebaseException &&
        (error.code == 'unavailable' ||
            error.code == 'network-request-failed')) {
      return '인터넷 연결을 확인한 후 다시 시도해 주세요.';
    }
    return '공고를 불러오는 중 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.';
  }

  Future<void> _confirmDeleteJob(StudentJobListing job) async {
    if (_deletingJobIds.contains(job.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('공고를 삭제하시겠습니까?'),
        content: Text('"${job.title}" 공고를 삭제하시겠습니까? 삭제한 공고는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            key: ValueKey('cancel-delete-job-${job.id}'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: ValueKey('confirm-delete-job-${job.id}'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9B2C2C),
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _deleteJob(job);
  }

  Future<void> _deleteJob(StudentJobListing job) async {
    if (_deletingJobIds.contains(job.id)) return;
    setState(() => _deletingJobIds.add(job.id));

    try {
      final injectedDelete = widget.deleteJob;
      if (injectedDelete != null) {
        await injectedDelete(job);
      } else {
        final auth = FirebaseAuth.instance;
        final user = auth.currentUser;
        if (user == null) {
          _showDeleteMessage('공고 소유자 계정으로 로그인해 주세요.', isError: true);
          return;
        }

        final profile = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!mounted) return;
        if (!profile.exists || profile.data()?['role'] != 'employer') {
          _showDeleteMessage('고용주 계정만 공고를 삭제할 수 있습니다.', isError: true);
          return;
        }

        final jobReference = FirebaseFirestore.instance
            .collection('jobs')
            .doc(job.id);
        final jobSnapshot = await jobReference.get();
        if (!mounted) return;
        if (!jobSnapshot.exists) {
          _showDeleteMessage('이 채용 공고는 더 이상 존재하지 않습니다.', isError: true);
          return;
        }
        if (jobSnapshot.data()?['employerId'] != user.uid ||
            job.employerId != user.uid) {
          _showDeleteMessage('내 계정으로 등록한 공고만 삭제할 수 있습니다.', isError: true);
          return;
        }
        if (auth.currentUser?.uid != user.uid) {
          _showDeleteMessage('로그인 세션이 만료되었습니다. 다시 로그인해 주세요.', isError: true);
          return;
        }

        await jobReference.delete();
      }

      if (!mounted) return;
      _showDeleteMessage('채용 공고가 삭제되었습니다.', isError: false);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showDeleteMessage(_deleteErrorMessage(error), isError: true);
    } catch (_) {
      if (!mounted) return;
      _showDeleteMessage('공고를 삭제하지 못했습니다. 다시 시도해 주세요.', isError: true);
    } finally {
      if (mounted) setState(() => _deletingJobIds.remove(job.id));
    }
  }

  String _deleteErrorMessage(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        '삭제 권한이 없습니다. 내 계정으로 등록한 공고인지, 공고 삭제 규칙이 배포되었는지 확인해 주세요.',
      'not-found' => '이 채용 공고는 더 이상 존재하지 않습니다.',
      'unavailable' || 'network-request-failed' =>
        'Firebase에 연결할 수 없습니다. 네트워크를 확인한 후 다시 시도해 주세요.',
      _ => '공고를 삭제하지 못했습니다. 다시 시도해 주세요.',
    };
  }

  void _showDeleteMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFF9B2C2C) : null,
        ),
      );
  }
}

class _EmployerJobCard extends StatelessWidget {
  const _EmployerJobCard({
    required this.job,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.isDeleting,
  });

  final StudentJobListing job;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF173B27),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    job.workType == null
                        ? '근무 형태 미지정'
                        : const RoleAwareStrings(isEmployer: true)
                              .workType(job.workType!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF536359),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    job.schedule == null
                        ? '근무 일정 미지정'
                        : const RoleAwareStrings(isEmployer: true)
                              .schedule(job.schedule!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF536359),
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
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: const Color(0xFF647369), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  key: ValueKey('edit-job-${job.id}'),
                  onPressed: isDeleting ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('수정'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF247545),
                  ),
                ),
                TextButton.icon(
                  key: ValueKey('delete-job-${job.id}'),
                  onPressed: isDeleting ? null : onDelete,
                  icon: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  label: Text(isDeleting ? '삭제 중…' : '삭제'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF9B2C2C),
                  ),
                ),
              ],
            ),
          ],
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
