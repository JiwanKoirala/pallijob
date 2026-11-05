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
  final result = Completer<List<EmployerApplication>>();
  await tester.pumpWidget(
    MaterialApp(
      home: EmployerApplicationsScreen(
        applicationsService: _FakeEmployerApplicationsService(result.future),
      ),
    ),
  );
  await tester.pump();
  result.complete(applications);
  await tester.pumpAndSettle();
}

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
  _FakeEmployerApplicationsService(this.result, {this.onLoad});

  final Future<List<EmployerApplication>> result;
  final Future<List<EmployerApplication>> Function(int call)? onLoad;
  int loadCalls = 0;

  @override
  Future<List<EmployerApplication>> loadApplications() {
    loadCalls++;
    return onLoad?.call(loadCalls) ?? result;
  }
}
