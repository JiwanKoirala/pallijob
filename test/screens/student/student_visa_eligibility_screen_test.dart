import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/student/job_application_service.dart';
import 'package:pallijob/screens/student/student_job_listings_screen.dart';
import 'package:pallijob/screens/student/student_visa_eligibility_screen.dart';

const guidanceData = StudentVisaGuidanceData(
  visaStatus: 'D-2',
  jobTitle: 'Cafe Assistant',
  jobLocation: 'Seoul',
  jobRequirements: 'Friendly and reliable.',
);

const guidanceJob = StudentJobListing(
  id: 'job-1',
  title: 'Cafe Assistant',
  description: 'Help prepare drinks and serve customers.',
  location: 'Seoul',
  requirements: 'Friendly and reliable.',
  employerId: 'employer-1',
  createdAt: null,
);

void main() {
  testWidgets('shows visa status and the selected job details', (tester) async {
    final service = _FakeVisaGuidanceService(Future.value(guidanceData));
    await _pumpGuidance(tester, service);

    expect(service.requestedJobId, 'job-1');
    expect(find.text('D-2'), findsOneWidget);
    expect(find.text('Cafe Assistant'), findsOneWidget);
    expect(find.text('Seoul'), findsOneWidget);
    expect(find.text('Friendly and reliable.'), findsOneWidget);
    expect(find.text('Eligibility remains unverified'), findsOneWidget);
    expect(
      find.textContaining('does not determine legal eligibility'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('open-hikorea')), findsOneWidget);
    expect(find.text('https://www.hikorea.go.kr/'), findsOneWidget);
  });

  testWidgets('prompts students with missing visa status to complete profile', (
    tester,
  ) async {
    const dataWithoutVisa = StudentVisaGuidanceData(
      visaStatus: null,
      jobTitle: 'Cafe Assistant',
      jobLocation: 'Seoul',
      jobRequirements: 'Friendly and reliable.',
    );
    await _pumpGuidance(
      tester,
      _FakeVisaGuidanceService(Future.value(dataWithoutVisa)),
    );

    expect(find.text('Visa status on your profile'), findsOneWidget);
    expect(find.text('Not provided'), findsOneWidget);
    expect(find.text('Complete My Profile'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('complete-student-profile')),
    );
    await tester.tap(find.byKey(const ValueKey('complete-student-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Could not load profile'), findsOneWidget);
  });

  testWidgets('shows loading state before profile and job data is ready', (
    tester,
  ) async {
    final pending = Completer<StudentVisaGuidanceData>();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentVisaEligibilityScreen(
          jobId: 'job-1',
          guidanceService: _FakeVisaGuidanceService(pending.future),
        ),
      ),
    );

    expect(find.text('Loading guidance'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows a permission-denied state for profile or job reads', (
    tester,
  ) async {
    final pending = Completer<StudentVisaGuidanceData>();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentVisaEligibilityScreen(
          jobId: 'job-1',
          guidanceService: _FakeVisaGuidanceService(pending.future),
        ),
      ),
    );
    pending.completeError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load guidance'), findsOneWidget);
    expect(find.textContaining('Firestore denied access'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('handles a job that no longer exists', (tester) async {
    final pending = Completer<StudentVisaGuidanceData>();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentVisaEligibilityScreen(
          jobId: 'deleted-job',
          guidanceService: _FakeVisaGuidanceService(pending.future),
        ),
      ),
    );
    pending.completeError(
      const StudentVisaGuidanceException(
        'This job is no longer available.',
        code: StudentVisaGuidanceError.jobNotFound,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Job no longer available'), findsOneWidget);
    expect(find.text('This job is no longer available.'), findsOneWidget);
  });

  testWidgets('shows a retryable error for other read failures', (
    tester,
  ) async {
    final pending = Completer<StudentVisaGuidanceData>();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentVisaEligibilityScreen(
          jobId: 'job-1',
          guidanceService: _FakeVisaGuidanceService(pending.future),
        ),
      ),
    );
    pending.completeError(StateError('network unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load guidance'), findsOneWidget);
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('job details opens guidance without disabling applications', (
    tester,
  ) async {
    final guidanceService = _FakeVisaGuidanceService(
      Future.value(guidanceData),
    );
    final applicationService = _FakeApplicationService();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobDetailsScreen(
          job: guidanceJob,
          applicationService: applicationService,
          visaGuidanceService: guidanceService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('apply-for-job')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('check-visa-eligibility')),
    );
    await tester.tap(find.byKey(const ValueKey('check-visa-eligibility')));
    await tester.pumpAndSettle();

    expect(find.text('Visa Eligibility Guidance'), findsOneWidget);
    expect(find.text('Cafe Assistant'), findsOneWidget);
    expect(guidanceService.requestedJobId, 'job-1');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('apply-for-job')), findsOneWidget);
    expect(applicationService.applyCalls, 0);
  });

  testWidgets('rejects a non-student role from guidance data service', (
    tester,
  ) async {
    final pending = Completer<StudentVisaGuidanceData>();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentVisaEligibilityScreen(
          jobId: 'job-1',
          guidanceService: _FakeVisaGuidanceService(pending.future),
        ),
      ),
    );
    pending.completeError(
      const StudentVisaGuidanceException(
        'Only student accounts can view visa guidance.',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Only student accounts can view visa guidance.'),
      findsOneWidget,
    );
    expect(find.text('Eligibility remains unverified'), findsNothing);
  });
}

Future<void> _pumpGuidance(
  WidgetTester tester,
  StudentVisaGuidanceService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StudentVisaEligibilityScreen(
        jobId: 'job-1',
        guidanceService: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeVisaGuidanceService implements StudentVisaGuidanceService {
  _FakeVisaGuidanceService(this.result);

  final Future<StudentVisaGuidanceData> result;
  String? requestedJobId;

  @override
  Future<StudentVisaGuidanceData> loadGuidance(String jobId) {
    requestedJobId = jobId;
    return result;
  }
}

class _FakeApplicationService implements JobApplicationService {
  int applyCalls = 0;

  @override
  Future<JobApplicationStatus> getStatus(String jobId) async {
    return JobApplicationStatus.canApply;
  }

  @override
  Future<void> apply(String jobId) async {
    applyCalls++;
  }
}
