import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pallijob/screens/auth/welcome_screen.dart';
import 'package:pallijob/screens/employer/employer_applications_screen.dart';
import 'package:pallijob/screens/employer/employer_profile_screen.dart';
import 'package:pallijob/screens/employer/manage_jobs_screen.dart';
import 'package:pallijob/screens/employer/post_job_screen.dart';
import 'package:pallijob/screens/notifications/in_app_notification_service.dart';
import 'package:pallijob/screens/notifications/in_app_notifications_screen.dart';

class EmployerDashboardScreen extends StatelessWidget {
  const EmployerDashboardScreen({
    super.key,
    this.applicationsService,
    this.notificationsService,
  });

  final EmployerApplicationsService? applicationsService;
  final InAppNotificationsService? notificationsService;

  static const _modules = [
    _DashboardModule(
      action: _DashboardAction.postJob,
      title: '채용 공고 등록',
      description: '새로운 채용 공고를 작성합니다',
      icon: Icons.add_circle_outline_rounded,
    ),
    _DashboardModule(
      action: _DashboardAction.manageJobs,
      title: '채용 공고 관리',
      description: '등록한 채용 공고를 확인하고 수정합니다',
      icon: Icons.work_outline_rounded,
    ),
    _DashboardModule(
      action: _DashboardAction.viewApplications,
      title: '지원서 확인',
      description: '학생들의 지원 내역을 확인합니다',
      icon: Icons.assignment_outlined,
    ),
    _DashboardModule(
      action: _DashboardAction.notifications,
      title: '알림',
      description: '새 지원서와 학생 메시지를 확인합니다',
      icon: Icons.notifications_none_rounded,
    ),
    _DashboardModule(
      action: _DashboardAction.messages,
      title: '메시지',
      description: '대화 기능은 준비 중입니다',
      icon: Icons.chat_bubble_outline_rounded,
    ),
    _DashboardModule(
      action: _DashboardAction.myProfile,
      title: '내 프로필',
      description: '고용주 프로필을 관리합니다',
      icon: Icons.person_outline_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text(
          'PalliJob',
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
            tooltip: '로그아웃',
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
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
                        '고용주님, 환영합니다!',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF173B27),
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '오늘 어떤 업무를 진행하시겠어요?',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF647369),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      for (final module in _modules) ...[
                        _ModuleCard(
                          module: module,
                          onTap: switch (module.action) {
                            _DashboardAction.postJob =>
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PostJobScreen(),
                                ),
                              ),
                            _DashboardAction.manageJobs =>
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ManageJobsScreen(),
                                ),
                              ),
                            _DashboardAction.viewApplications =>
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => EmployerApplicationsScreen(
                                    applicationsService: applicationsService,
                                  ),
                                ),
                              ),
                            _DashboardAction.notifications =>
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => InAppNotificationsScreen(
                                    role: InAppNotificationRole.employer,
                                    notificationsService:
                                        notificationsService ??
                                        const FirestoreInAppNotificationsService(),
                                  ),
                                ),
                              ),
                            _DashboardAction.myProfile =>
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const EmployerProfileScreen(),
                                ),
                              ),
                            _DashboardAction.messages => null,
                          },
                        ),
                        if (module != _modules.last) const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃하지 못했습니다. 다시 시도해 주세요.')),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }
}

class _DashboardModule {
  const _DashboardModule({
    required this.action,
    required this.title,
    required this.description,
    required this.icon,
  });

  final _DashboardAction action;
  final String title;
  final String description;
  final IconData icon;
}

enum _DashboardAction {
  postJob,
  manageJobs,
  viewApplications,
  notifications,
  messages,
  myProfile,
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, this.onTap});

  final _DashboardModule module;
  final VoidCallback? onTap;

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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4ED),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  module.icon,
                  color: const Color(0xFF247545),
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF173B27),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      module.description,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFF647369)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      onTap == null ? '준비 중' : '눌러서 열기',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF247545),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF247545),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
