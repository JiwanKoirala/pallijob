import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/chat/application_chat_screen.dart';
import 'package:pallijob/screens/employer/employer_applications_screen.dart';
import 'package:pallijob/screens/employer/employer_dashboard_screen.dart';

import '../../support/fake_application_chat_service.dart';

final employerApplication = EmployerApplication(
  id: 'job-1_student-1',
  jobId: 'job-1',
  jobTitle: 'Cafe Assistant',
  applicantId: 'student-1',
  status: 'pending',
  dateApplied: DateTime(2026, 11, 1),
  jobUnavailable: false,
);

void main() {
  testWidgets('shows loading state while applications are loading', (
    tester,
  ) async {
    final pending = Completer<List<EmployerApplication>>();
    await tester.pumpWidget(
      MaterialApp(
        home: EmployerApplicationsScreen(
          applicationsService: _FakeEmployerApplicationsService(pending.future),
        ),
      ),
    );

    expect(find.text('지원서를 불러오는 중'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an empty state when no applications exist', (
    tester,
  ) async {
    await _pumpApplications(tester, const []);

    expect(find.text('아직 지원서가 없습니다'), findsOneWidget);
  });

  testWidgets('shows job title, applicant ID, status, and date', (
    tester,
  ) async {
    await _pumpApplications(tester, [employerApplication]);

    expect(find.text('Cafe Assistant'), findsOneWidget);
    expect(find.text('지원자 ID'), findsOneWidget);
    expect(find.text('student-1'), findsOneWidget);
    expect(find.text('검토 중'), findsOneWidget);
    expect(find.textContaining('2026년 11월 1일'), findsOneWidget);
    expect(find.text('Chat'), findsNothing);
  });

  testWidgets('shows the applicant name on the card and in confirmation', (
    tester,
  ) async {
    const application = EmployerApplication(
      id: 'job-1_student-1',
      jobId: 'job-1',
      jobTitle: 'Cafe Assistant',
      applicantId: 'student-1',
      applicantName: '김민지',
      status: 'pending',
      dateApplied: null,
      jobUnavailable: false,
    );
    await _pumpApplications(tester, [application]);

    expect(find.text('지원자 이름'), findsOneWidget);
    expect(find.text('김민지'), findsOneWidget);
    expect(find.text('지원자 ID'), findsNothing);
    expect(find.text('student-1'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('accept-application-job-1_student-1')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('김민지님'), findsOneWidget);
  });

  testWidgets('shows an authorized Chat entry and opens its application chat', (
    tester,
  ) async {
    const application = EmployerApplication(
      id: 'job-1_student-1',
      jobId: 'job-1',
      jobTitle: 'Cafe Assistant',
      applicantId: 'student-1',
      status: 'pending',
      dateApplied: null,
      jobUnavailable: false,
      canChat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EmployerApplicationsScreen(
          applicationsService: _FakeEmployerApplicationsService(
            Future.value([application]),
          ),
          chatService: FakeApplicationChatService(
            conversation: Future.value(
              const ChatConversation(
                applicationId: 'job-1_student-1',
                jobTitle: 'Cafe Assistant',
                studentId: 'student-1',
                employerId: 'employer-1',
                currentUserId: 'employer-1',
                currentRole: ChatParticipantRole.employer,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('chat-application-job-1_student-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('메시지가 없습니다'), findsOneWidget);
    expect(find.text('메시지를 입력하세요'), findsOneWidget);
  });

  testWidgets('accepts a pending application after confirmation', (
    tester,
  ) async {
    final service = _FakeEmployerApplicationsService(
      Future.value([employerApplication]),
      onLoad: (call) => Future.value([
        call == 1 ? employerApplication : _withStatus('accepted'),
      ]),
    );
    await _pumpService(tester, service);

    await tester.tap(
      find.byKey(const ValueKey('accept-application-job-1_student-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('수락 지원서'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirm-decision-job-1_student-1')),
    );
    await tester.pumpAndSettle();

    expect(service.decisions, [
      ('job-1_student-1', EmployerApplicationDecision.accepted),
    ]);
    expect(find.text('수락'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('accept-application-job-1_student-1')),
      findsNothing,
    );
    expect(find.text('거절'), findsNothing);
  });

  testWidgets('rejects a pending application after confirmation', (
    tester,
  ) async {
    final service = _FakeEmployerApplicationsService(
      Future.value([employerApplication]),
      onLoad: (call) => Future.value([
        call == 1 ? employerApplication : _withStatus('rejected'),
      ]),
    );
    await _pumpService(tester, service);

    await tester.tap(
      find.byKey(const ValueKey('reject-application-job-1_student-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('거절 지원서'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirm-decision-job-1_student-1')),
    );
    await tester.pumpAndSettle();

    expect(service.decisions, [
      ('job-1_student-1', EmployerApplicationDecision.rejected),
    ]);
    expect(find.text('거절'), findsOneWidget);
    expect(find.text('수락'), findsNothing);
  });

  testWidgets('cancelling confirmation makes no decision', (tester) async {
    final service = _FakeEmployerApplicationsService(
      Future.value([employerApplication]),
    );
    await _pumpService(tester, service);

    await tester.tap(
      find.byKey(const ValueKey('reject-application-job-1_student-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('cancel-decision-job-1_student-1')),
    );
    await tester.pumpAndSettle();

    expect(service.decisions, isEmpty);
    expect(find.text('검토 중'), findsOneWidget);
  });

  testWidgets('offers decisions only for pending applications', (tester) async {
    const acceptedApplication = EmployerApplication(
      id: 'job-accepted_student-1',
      jobId: 'job-accepted',
      jobTitle: 'Accepted job',
      applicantId: 'student-1',
      status: 'accepted',
      dateApplied: null,
      jobUnavailable: false,
    );
    const rejectedApplication = EmployerApplication(
      id: 'job-rejected_student-1',
      jobId: 'job-rejected',
      jobTitle: 'Rejected job',
      applicantId: 'student-1',
      status: 'rejected',
      dateApplied: null,
      jobUnavailable: false,
    );
    await _pumpApplications(tester, [acceptedApplication, rejectedApplication]);

    expect(find.text('수락'), findsOneWidget);
    expect(find.text('거절'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('shows loading feedback and prevents duplicate decisions', (
    tester,
  ) async {
    final saving = Completer<void>();
    final service = _FakeEmployerApplicationsService(
      Future.value([employerApplication]),
      onUpdate: (_, _) => saving.future,
    );
    await _pumpService(tester, service);

    await tester.tap(
      find.byKey(const ValueKey('accept-application-job-1_student-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-decision-job-1_student-1')),
    );
    await tester.pump();

    expect(find.text('처리 중…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(service.decisions, hasLength(1));
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('accept-application-job-1_student-1')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('reject-application-job-1_student-1')),
          )
          .onPressed,
      isNull,
    );

    saving.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('explains permission-denied decision errors', (tester) async {
    final service = _FakeEmployerApplicationsService(
      Future.value([employerApplication]),
      onUpdate: (_, _) async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      },
    );
    await _pumpService(tester, service);

    await _chooseAndConfirm(tester, 'accept');

    expect(
      find.textContaining('처리 권한이 없습니다'),
      findsOneWidget,
    );
  });

  testWidgets('reports other decision errors', (tester) async {
    final service = _FakeEmployerApplicationsService(
      Future.value([employerApplication]),
      onUpdate: (_, _) async => throw StateError('write failed'),
    );
    await _pumpService(tester, service);

    await _chooseAndConfirm(tester, 'reject');

    expect(
      find.textContaining('지원서를 처리하지 못했습니다'),
      findsOneWidget,
    );
  });

  testWidgets('shows a missing-job notice without hiding application history', (
    tester,
  ) async {
    const application = EmployerApplication(
      id: 'job-1_student-1',
      jobId: 'job-1',
      jobTitle: '더 이상 이용할 수 없는 공고',
      applicantId: 'student-1',
      status: 'pending',
      dateApplied: null,
      jobUnavailable: true,
    );
    await _pumpApplications(tester, const [application]);

    expect(find.text('더 이상 이용할 수 없는 공고'), findsOneWidget);
    expect(
      find.text('이 채용 공고는 더 이상 이용할 수 없습니다.'),
      findsOneWidget,
    );
    expect(find.text('student-1'), findsOneWidget);
    expect(find.text('검토 중'), findsOneWidget);
    expect(find.text('날짜 정보 없음'), findsOneWidget);
  });

  testWidgets('shows permission-denied guidance and retry', (tester) async {
    final denied = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    final service = _FakeEmployerApplicationsService(
      Future.value(const <EmployerApplication>[]),
      onLoad: (call) => call == 1
          ? Future<List<EmployerApplication>>.delayed(
              Duration.zero,
              () => throw denied,
            )
          : Future.value(const <EmployerApplication>[]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EmployerApplicationsScreen(applicationsService: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('지원서를 불러오지 못했습니다'), findsOneWidget);
    expect(find.textContaining('지원서를 확인할 권한'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('아직 지원서가 없습니다'), findsOneWidget);
    expect(service.loadCalls, 2);
  });

  testWidgets('shows a signed-out state', (tester) async {
    await _pumpError(
      tester,
      const EmployerApplicationsException(
        '지원서를 확인하려면 고용주 계정으로 로그인해 주세요.',
      ),
    );

    expect(
      find.text('지원서를 확인하려면 고용주 계정으로 로그인해 주세요.'),
      findsOneWidget,
    );
  });

  testWidgets('restricts the screen to stored employer roles', (tester) async {
    await _pumpError(
      tester,
      const EmployerApplicationsException(
        '고용주 계정만 접수된 지원서를 확인할 수 있습니다.',
      ),
    );

    expect(
      find.text('고용주 계정만 접수된 지원서를 확인할 수 있습니다.'),
      findsOneWidget,
    );
  });

  testWidgets('dashboard View Applications card opens the screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EmployerDashboardScreen(
          applicationsService: _FakeEmployerApplicationsService(
            Future.value(const <EmployerApplication>[]),
          ),
        ),
      ),
    );

    await tester.tap(find.text('지원서 확인'));
    await tester.pumpAndSettle();

    expect(find.text('아직 지원서가 없습니다'), findsOneWidget);
  });
}

Future<void> _pumpApplications(
  WidgetTester tester,
  List<EmployerApplication> applications,
) async {
  await _pumpService(
    tester,
    _FakeEmployerApplicationsService(Future.value(applications)),
  );
}

Future<void> _pumpService(
  WidgetTester tester,
  _FakeEmployerApplicationsService service,
) async {
  await tester.pumpWidget(
    MaterialApp(home: EmployerApplicationsScreen(applicationsService: service)),
  );
  await tester.pumpAndSettle();
}

Future<void> _chooseAndConfirm(WidgetTester tester, String decision) async {
  await tester.tap(
    find.byKey(ValueKey('$decision-application-job-1_student-1')),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('confirm-decision-job-1_student-1')),
  );
  await tester.pumpAndSettle();
}

EmployerApplication _withStatus(String status) => EmployerApplication(
  id: employerApplication.id,
  jobId: employerApplication.jobId,
  jobTitle: employerApplication.jobTitle,
  applicantId: employerApplication.applicantId,
  status: status,
  dateApplied: employerApplication.dateApplied,
  jobUnavailable: employerApplication.jobUnavailable,
);

Future<void> _pumpError(WidgetTester tester, Object error) async {
  final result = Completer<List<EmployerApplication>>();
  await tester.pumpWidget(
    MaterialApp(
      home: EmployerApplicationsScreen(
        applicationsService: _FakeEmployerApplicationsService(result.future),
      ),
    ),
  );
  await tester.pump();
  result.completeError(error);
  await tester.pumpAndSettle();
}

class _FakeEmployerApplicationsService implements EmployerApplicationsService {
  _FakeEmployerApplicationsService(this.result, {this.onLoad, this.onUpdate});

  final Future<List<EmployerApplication>> result;
  final Future<List<EmployerApplication>> Function(int call)? onLoad;
  final Future<void> Function(
    String applicationId,
    EmployerApplicationDecision decision,
  )?
  onUpdate;
  final List<(String, EmployerApplicationDecision)> decisions = [];
  int loadCalls = 0;

  @override
  Future<List<EmployerApplication>> loadApplications() {
    loadCalls++;
    return onLoad?.call(loadCalls) ?? result;
  }

  @override
  Future<void> updateStatus(
    String applicationId,
    EmployerApplicationDecision decision,
  ) async {
    decisions.add((applicationId, decision));
    await onUpdate?.call(applicationId, decision);
  }
}
