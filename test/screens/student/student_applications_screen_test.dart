import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/student/student_applications_screen.dart';
import 'package:pallijob/screens/student/student_dashboard_screen.dart';

final pendingApplication = StudentApplication(
  id: 'job-1_student-1',
  jobId: 'job-1',
  jobTitle: 'Cafe Assistant',
  location: 'Seoul',
  status: 'pending',
  dateApplied: DateTime(2026, 11, 1),
);

void main() {
  testWidgets('shows loading state while applications are loading', (
    tester,
  ) async {
    final pending = Completer<List<StudentApplication>>();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentApplicationsScreen(
          applicationsService: _FakeStudentApplicationsService(pending.future),
        ),
      ),
    );

    expect(find.text('Loading applications'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no applications', (
    tester,
  ) async {
    await _pumpApplications(tester, const []);

    expect(find.text('No applications yet'), findsOneWidget);
    expect(
      find.text('Applications you submit for jobs will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('shows job details, pending status, and application date', (
    tester,
  ) async {
    await _pumpApplications(tester, [pendingApplication]);

    expect(find.text('Cafe Assistant'), findsOneWidget);
    expect(find.text('Seoul'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.textContaining('Nov'), findsOneWidget);
  });

  testWidgets('shows a graceful unavailable listing for a deleted job', (
    tester,
  ) async {
    const application = StudentApplication(
      id: 'deleted-job_student-1',
      jobId: 'deleted-job',
      jobTitle: 'Job no longer available',
      location: 'Listing unavailable',
      status: 'pending',
      dateApplied: null,
    );
    await _pumpApplications(tester, const [application]);

    expect(find.text('Job no longer available'), findsOneWidget);
    expect(find.text('Listing unavailable'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Date unavailable'), findsOneWidget);
  });

  testWidgets('explains permission-denied errors and can retry', (
    tester,
  ) async {
    final denied = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    final service = _FakeStudentApplicationsService(
      Future.value(const <StudentApplication>[]),
      onLoad: (loadCall) => loadCall == 1
          ? Future<List<StudentApplication>>.delayed(
              Duration.zero,
              () => throw denied,
            )
          : Future.value(const <StudentApplication>[]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StudentApplicationsScreen(applicationsService: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load applications'), findsOneWidget);
    expect(find.textContaining('do not have permission'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No applications yet'), findsOneWidget);
    expect(service.loadCalls, 2);
  });

  testWidgets('shows an access restriction for non-student accounts', (
    tester,
  ) async {
    await _pumpApplications(
      tester,
      const [],
      error: const StudentApplicationsException(
        'Only student accounts can view applications.',
      ),
    );

    expect(
      find.text('Only student accounts can view applications.'),
      findsOneWidget,
    );
  });

  testWidgets('dashboard My Applications card opens the screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StudentDashboardScreen()));

    await tester.tap(find.text('My Applications'));
    await tester.pumpAndSettle();

    expect(find.text('My Applications'), findsOneWidget);
    expect(find.text('Could not load applications'), findsOneWidget);
  });
}

Future<void> _pumpApplications(
  WidgetTester tester,
  List<StudentApplication> applications, {
  Object? error,
}) async {
  final result = Completer<List<StudentApplication>>();
  await tester.pumpWidget(
    MaterialApp(
      home: StudentApplicationsScreen(
        applicationsService: _FakeStudentApplicationsService(result.future),
      ),
    ),
  );
  await tester.pump();
  if (error == null) {
    result.complete(applications);
  } else {
    result.completeError(error);
  }
  await tester.pumpAndSettle();
}

class _FakeStudentApplicationsService implements StudentApplicationsService {
  _FakeStudentApplicationsService(this.result, {this.onLoad});

  final Future<List<StudentApplication>> result;
  final Future<List<StudentApplication>> Function(int loadCall)? onLoad;
  int loadCalls = 0;

  @override
  Future<List<StudentApplication>> loadApplications() {
    loadCalls++;
    return onLoad?.call(loadCalls) ?? result;
  }
}
