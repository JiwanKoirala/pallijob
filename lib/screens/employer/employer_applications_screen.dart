import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pallijob/l10n/role_aware_strings.dart';
import 'package:pallijob/screens/chat/application_chat_screen.dart';

class EmployerApplication {
  const EmployerApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.applicantId,
    required this.status,
    required this.dateApplied,
    required this.jobUnavailable,
    this.applicantName,
    this.canChat = false,
    this.canDecide = true,
  });

  final String id;
  final String jobId;
  final String jobTitle;
  final String applicantId;
  final String? applicantName;
  final String status;
  final DateTime? dateApplied;
  final bool jobUnavailable;
  final bool canChat;
  final bool canDecide;

  String? get displayName {
    final name = applicantName?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  String get applicantLabel =>
      displayName ?? (applicantId.isEmpty ? '지원자 정보 없음' : applicantId);
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
        '지원서를 확인하려면 고용주 계정으로 로그인해 주세요.',
      );
    }

    final firestore = FirebaseFirestore.instance;
    final profile = await firestore.collection('users').doc(user.uid).get();
    if (profile.data()?['role'] != 'employer') {
      throw const EmployerApplicationsException('고용주 계정만 접수된 지원서를 확인할 수 있습니다.');
    }
    if (auth.currentUser?.uid != user.uid) {
      throw const EmployerApplicationsException(
        '로그인 세션이 변경되었습니다. 다시 로그인해 주세요.',
      );
    }

    final jobs = await firestore
        .collection('jobs')
        .where('employerId', isEqualTo: user.uid)
        .get();
    final jobTitles = {
      for (final job in jobs.docs)
        job.id: _textValue(job.data()['title'], fallback: '공고 정보 없음'),
    };
    final jobOwners = {
      for (final job in jobs.docs) job.id: job.data()['employerId'],
    };
    final applicationsById =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    final employerApplications = await firestore
        .collection('applications')
        .where('employerId', isEqualTo: user.uid)
        .get();
    for (final application in employerApplications.docs) {
      applicationsById[application.id] = application;
    }

    final applicationsByJob = await Future.wait(
      jobs.docs.map(
        (job) => firestore
            .collection('applications')
            .where('jobId', isEqualTo: job.id)
            .get(),
      ),
    );
    for (final query in applicationsByJob) {
      for (final application in query.docs) {
        applicationsById[application.id] = application;
      }
    }

    final applications = <EmployerApplication>[];
    for (final application in applicationsById.values) {
      final data = application.data();
      final jobId = _textValue(data['jobId']);
      final jobTitle = jobTitles[jobId];
      final actualEmployerId = jobOwners[jobId];
      final applicantId = _textValue(data['studentId']);
      final applicantName = data['applicantName'];
      final ownershipMatches =
          actualEmployerId != null &&
          (!data.containsKey('employerId') ||
              data['employerId'] == actualEmployerId);
      final appliedAt = data['dateApplied'];
      applications.add(
        EmployerApplication(
          id: application.id,
          jobId: jobId,
          jobTitle: jobTitle ?? '더 이상 이용할 수 없는 공고',
          applicantId: applicantId,
          applicantName: applicantName is String ? applicantName : null,
          status: _textValue(data['status']),
          dateApplied: appliedAt is Timestamp ? appliedAt.toDate() : null,
          jobUnavailable: jobTitle == null,
          canChat:
              ownershipMatches &&
              applicantId.isNotEmpty &&
              applicantId != user.uid,
          canDecide: ownershipMatches,
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
        '지원서를 처리하려면 고용주 계정으로 로그인해 주세요.',
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
          '고용주 계정만 지원서를 처리할 수 있습니다.',
        );
      }

      final application = await transaction.get(applicationReference);
      final data = application.data();
      if (data == null) {
        throw const EmployerApplicationDecisionException(
          '이 지원서는 더 이상 존재하지 않습니다.',
        );
      }
      if (data['status'] != 'pending') {
        throw const EmployerApplicationDecisionException(
          '검토 중인 지원서만 처리할 수 있습니다.',
        );
      }
      final studentId = data['studentId'];
      if (studentId is! String || studentId.trim().isEmpty) {
        throw const EmployerApplicationDecisionException('지원자 정보가 올바르지 않습니다.');
      }
      final jobId = data['jobId'];
      if (jobId is! String || jobId.trim().isEmpty) {
        throw const EmployerApplicationDecisionException(
          '지원서의 공고 정보가 올바르지 않습니다.',
        );
      }
      final job = await transaction.get(
        firestore.collection('jobs').doc(jobId),
      );
      if (job.data()?['employerId'] != user.uid ||
          (data.containsKey('employerId') &&
              data['employerId'] != job.data()?['employerId'])) {
        throw const EmployerApplicationDecisionException(
          '내가 등록한 공고의 지원서만 처리할 수 있습니다.',
        );
      }
      if (auth.currentUser?.uid != user.uid) {
        throw const EmployerApplicationDecisionException(
          '로그인 세션이 변경되었습니다. 다시 로그인해 주세요.',
        );
      }
      final jobTitle = job.data()?['title'];
      if (jobTitle is! String || jobTitle.trim().isEmpty) {
        throw const EmployerApplicationDecisionException(
          '공고 제목이 없어 지원서를 처리할 수 없습니다.',
        );
      }

      final notificationReference = firestore
          .collection('users')
          .doc(studentId)
          .collection('notifications')
          .doc('status__${decision.name}__$applicationId');
      transaction.update(applicationReference, {
        'status': decision.name,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationReference, {
        'type': 'application_${decision.name}',
        'applicationId': applicationId,
        'jobTitle': jobTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'readAt': null,
      });
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
  const EmployerApplicationsScreen({
    super.key,
    this.applicationsService,
    this.chatService,
  });

  final EmployerApplicationsService? applicationsService;
  final ApplicationChatService? chatService;

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
          '지원서 확인',
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
              title: '지원서를 불러오지 못했습니다',
              message: _errorMessage(snapshot.error),
              action: TextButton(
                onPressed: () {
                  setState(() {
                    _applicationsFuture = _service.loadApplications();
                  });
                },
                child: const Text('다시 시도'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _EmployerApplicationsState(
              loading: true,
              title: '지원서를 불러오는 중',
              message: '등록한 공고의 지원 내역을 불러오고 있습니다.',
            );
          }

          final applications = snapshot.data ?? const <EmployerApplication>[];
          if (applications.isEmpty) {
            return const _EmployerApplicationsState(
              icon: Icons.assignment_outlined,
              title: '아직 지원서가 없습니다',
              message: '채용 공고에 지원서가 접수되면 여기에 표시됩니다.',
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
                    onChat: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ApplicationChatScreen(
                          applicationId: application.id,
                          uiRole: ChatParticipantRole.employer,
                          chatService:
                              widget.chatService ??
                              const FirestoreApplicationChatService(),
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
        ? '수락'
        : '거절';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$decisionLabel 지원서'),
        content: Text(
          '${application.applicantLabel}님의 "${application.jobTitle}" 지원을 $decisionLabel하시겠습니까?',
        ),
        actions: [
          TextButton(
            key: ValueKey('cancel-decision-${application.id}'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
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
        ? '지원서를 ${decision == EmployerApplicationDecision.accepted ? '수락' : '거절'}했습니다.'
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
      return '처리 권한이 없습니다. 내 공고의 지원서인지, 고용주 계정으로 로그인했는지, 지원서 변경 규칙이 배포되었는지 확인해 주세요.';
    }
    if (error is FirebaseException &&
        (error.code == 'unavailable' ||
            error.code == 'network-request-failed')) {
      return 'Firebase에 연결할 수 없습니다. 네트워크를 확인한 후 다시 시도해 주세요.';
    }
    if (error is FirebaseException) {
      return '지원서를 처리하지 못했습니다. 다시 시도해 주세요.';
    }
    return '지원서를 처리하지 못했습니다. 다시 시도해 주세요.';
  }
}

class _EmployerApplicationCard extends StatelessWidget {
  const _EmployerApplicationCard({
    required this.application,
    required this.isUpdating,
    required this.onDecision,
    required this.onChat,
  });

  final EmployerApplication application;
  final bool isUpdating;
  final ValueChanged<EmployerApplicationDecision> onDecision;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    const strings = RoleAwareStrings(isEmployer: true);
    final dateText = application.dateApplied == null
        ? '날짜 정보 없음'
        : strings.mediumDate(context, application.dateApplied!);

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
                    '이 채용 공고는 더 이상 이용할 수 없습니다.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF647369)),
                  ),
                ],
                const SizedBox(height: 12),
                _ApplicationDetail(
                  label: application.displayName == null ? '지원자 ID' : '지원자 이름',
                  value: application.applicantLabel,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ApplicationDetail(
                        label: '상태',
                        value: _formatStatus(application.status),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ApplicationDetail(label: '지원일', value: dateText),
                    ),
                  ],
                ),
                if (application.canChat) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: ValueKey('chat-application-${application.id}'),
                    onPressed: onChat,
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('채팅'),
                  ),
                ],
                if (application.status == 'pending' &&
                    application.canDecide &&
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
                        const Expanded(child: Text('처리 중…')),
                      ] else
                        const Spacer(),
                      OutlinedButton(
                        key: ValueKey('reject-application-${application.id}'),
                        onPressed: isUpdating
                            ? null
                            : () => onDecision(
                                EmployerApplicationDecision.rejected,
                              ),
                        child: const Text('거절'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: ValueKey('accept-application-${application.id}'),
                        onPressed: isUpdating
                            ? null
                            : () => onDecision(
                                EmployerApplicationDecision.accepted,
                              ),
                        child: const Text('수락'),
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

String _formatStatus(String status) => switch (status) {
  'pending' => '검토 중',
  'accepted' => '수락',
  'rejected' => '거절',
  _ => '알 수 없음',
};

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
    return '지원서를 확인할 권한이 없습니다. 고용주 계정으로 로그인했는지, 지원서 조회 규칙이 배포되었는지 확인해 주세요.';
  }
  if (error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'network-request-failed')) {
    return '인터넷 연결을 확인한 후 다시 시도해 주세요.';
  }
  if (error is FirebaseException) {
    return '지원서를 불러오지 못했습니다. 다시 시도해 주세요.';
  }
  return '오류가 발생했습니다. 지원서 기록은 변경되지 않았습니다. 다시 시도해 주세요.';
}
