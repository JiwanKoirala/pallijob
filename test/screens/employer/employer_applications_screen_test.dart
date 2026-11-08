import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/employer/employer_applications_screen.dart';
import 'package:pallijob/screens/employer/employer_dashboard_screen.dart';

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

    expect(find.text('Loading applications'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an empty state when no applications exist', (
    tester,
  ) async {
    await _pumpApplications(tester, const []);

    expect(find.text('No applications received yet'), findsOneWidget);
  });

  testWidgets('shows job title, applicant ID, status, and date', (
    tester,
  ) async {
    await _pumpApplications(tester, [employerApplication]);

    expect(find.text('Cafe Assistant'), findsOneWidget);
    expect(find.text('Applicant ID'), findsOneWidget);
    expect(find.text('student-1'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.textContaining('Nov'), findsOneWidget);
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

    await tester.tap(find.byKey(const ValueKey('accept-application-job-1_student-1')));
    await tester.pumpAndSettle();
    expect(find.text('Accept application?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-decision-job-1_student-1')));
    await tester.pumpAndSettle();

    expect(
      service.decisions,
      [
        (
          'job-1_student-1',
          EmployerApplicationDecision.accepted,
        ),
      ],
    );
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Reject'), findsNothing);
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
    expect(find.text('Reject application?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirm-decision-job-1_student-1')),
    );
    await tester.pumpAndSettle();

    expect(
      service.decisions,
      [
        (
          'job-1_student-1',
          EmployerApplicationDecision.rejected,
        ),
      ],
    );
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Reject'), findsNothing);
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
    expect(find.text('Pending'), findsOneWidget);
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
    await _pumpApplications(tester, [
      acceptedApplication,
      rejectedApplication,
    ]);

    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
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

    expect(find.text('Saving decision...'), findsOneWidget);
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

    expect(find.textContaining('Firestore denied this decision'), findsOneWidget);
  });

  testWidgets('reports other decision errors', (tester) async {
    final service = _FakeEmployerApplicationsService(
      Future.value([employerApplication]),
      onUpdate: (_, _) async => throw StateError('write failed'),
    );
    await _pumpService(tester, service);

    await _chooseAndConfirm(tester, 'reject');

    expect(find.textContaining('Could not update the application'), findsOneWidget);
  });

  testWidgets('shows a missing-job notice without hiding application history', (
    tester,
  ) async {
    const application = EmployerApplication(
      id: 'job-1_student-1',
      jobId: 'job-1',
      jobTitle: 'Job no longer available',
      applicantId: 'student-1',
      status: 'pending',
      dateApplied: null,
      jobUnavailable: true,
    );
    await _pumpApplications(tester, const [application]);

    expect(find.text('Job no longer available'), findsOneWidget);
    expect(
      find.text('This job listing is no longer available.'),
      findsOneWidget,
    );
    expect(find.text('student-1'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Date unavailable'), findsOneWidget);
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

    expect(find.text('Could not load applications'), findsOneWidget);
    expect(find.textContaining('do not have permission'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No applications received yet'), findsOneWidget);
    expect(service.loadCalls, 2);
  });

  testWidgets('shows a signed-out state', (tester) async {
    await _pumpError(
      tester,
      const EmployerApplicationsException(
        'Sign in with an employer account to view applications.',
      ),
    );

    expect(
      find.text('Sign in with an employer account to view applications.'),
      findsOneWidget,
    );
  });

  testWidgets('restricts the screen to stored employer roles', (tester) async {
    await _pumpError(
      tester,
      const EmployerApplicationsException(
        'Only employer accounts can view received applications.',
      ),
    );

    expect(
      find.text('Only employer accounts can view received applications.'),
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

    await tester.tap(find.text('View Applications'));
    await tester.pumpAndSettle();

    expect(find.text('No applications received yet'), findsOneWidget);
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
    MaterialApp(
      home: EmployerApplicationsScreen(
        applicationsService: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _chooseAndConfirm(WidgetTester tester, String decision) async {
  await tester.tap(
    find.byKey(
      ValueKey('$decision-application-job-1_student-1'),
    ),
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
  _FakeEmployerApplicationsService(
    this.result, {
    this.onLoad,
    this.onUpdate,
  });

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
