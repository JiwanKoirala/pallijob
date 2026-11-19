import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/student/job_application_service.dart';
import 'package:pallijob/screens/student/student_job_matching.dart';
import 'package:pallijob/screens/student/student_job_listings_screen.dart';

const job = StudentJobListing(
  id: 'job-1',
  title: 'Cafe Assistant',
  description: 'Help prepare drinks and serve customers.',
  location: 'Seoul',
  requirements: 'Friendly and reliable.',
  employerId: 'employer-1',
  createdAt: null,
  workType: 'Part-time',
  schedule: 'Weekdays',
);
const secondJob = StudentJobListing(
  id: 'job-2',
  title: 'Shop Assistant',
  description: 'Help customers find products.',
  location: 'Busan',
  requirements: 'Helpful and organized.',
  employerId: 'employer-2',
  createdAt: null,
  workType: 'Full-time',
  schedule: 'Weekends',
);
const thirdJob = StudentJobListing(
  id: 'job-3',
  title: 'Delivery Driver',
  description: 'Deliver local orders.',
  location: 'Busan',
  requirements: 'Valid driver license.',
  employerId: 'employer-3',
  createdAt: null,
);
const fourthJob = StudentJobListing(
  id: 'job-4',
  title: 'Temporary Cleaner',
  description: 'Help clean a local office.',
  location: 'Busan',
  requirements: 'Reliable and punctual.',
  employerId: 'employer-4',
  createdAt: null,
  workType: 'Temporary/Contract',
  schedule: 'Flexible',
);

const testJobs = [job, secondJob, thirdJob, fourthJob];

void main() {
  testWidgets('shows loading state while jobs are loading', (tester) async {
    final controller = StreamController<List<StudentJobListing>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(
          jobsStream: controller.stream,
          preferencesService: _FakeStudentJobPreferencesService(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading jobs'), findsOneWidget);
  });

  testWidgets('shows an empty state when no jobs exist', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(
          jobsStream: Stream.value(const <StudentJobListing>[]),
          preferencesService: _FakeStudentJobPreferencesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No jobs available yet'), findsOneWidget);
  });

  testWidgets('lists jobs and opens their complete details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(
          jobsStream: Stream.value(const [job]),
          applicationService: _FakeJobApplicationService(),
          preferencesService: _FakeStudentJobPreferencesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cafe Assistant'), findsOneWidget);
    expect(find.text('Seoul'), findsOneWidget);
    expect(find.text('Part-time'), findsOneWidget);
    expect(find.text('Schedule: Weekdays'), findsOneWidget);
    expect(
      find.text('Help prepare drinks and serve customers.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cafe Assistant'));
    await tester.pumpAndSettle();

    expect(find.text('Job Details'), findsOneWidget);
    expect(find.text('Friendly and reliable.'), findsOneWidget);
    expect(find.text('employer-1'), findsOneWidget);
    expect(find.text('Work type'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Weekdays'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget);
  });

  testWidgets('explains permission denied errors', (tester) async {
    final permissionError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(
          jobsStream: Stream.error(permissionError),
          preferencesService: _FakeStudentJobPreferencesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load jobs'), findsOneWidget);
    expect(find.textContaining('do not have permission'), findsOneWidget);
  });

  testWidgets(
    'searches titles case-insensitively and trims surrounding spaces',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StudentJobListingsScreen(
            jobsStream: Stream.value(testJobs),
            preferencesService: _FakeStudentJobPreferencesService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('job-search-field')),
        '  cAfE  ',
      );
      await tester.pumpAndSettle();

      expect(find.text('Cafe Assistant'), findsOneWidget);
      expect(find.text('Shop Assistant'), findsNothing);
      expect(find.text('Delivery Driver'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('job-search-field')),
        '  sEoUl  ',
      );
      await tester.pumpAndSettle();

      expect(find.text('Cafe Assistant'), findsOneWidget);
      expect(find.text('Shop Assistant'), findsNothing);
      expect(find.text('Delivery Driver'), findsNothing);
    },
  );

  testWidgets('filters jobs by selected location', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(
          jobsStream: Stream.value(testJobs),
          preferencesService: _FakeStudentJobPreferencesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('job-location-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Busan').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.text('Shop Assistant'), findsOneWidget);
    expect(find.text('Delivery Driver'), findsOneWidget);
    expect(find.text('Cafe Assistant'), findsNothing);
  });

  testWidgets('filters jobs by selected work type', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(
          jobsStream: Stream.value(testJobs),
          preferencesService: _FakeStudentJobPreferencesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('job-work-type-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full-time').last);
    await tester.pumpAndSettle();

    expect(find.text('Shop Assistant'), findsOneWidget);
    expect(find.text('Cafe Assistant'), findsNothing);
    expect(find.text('Delivery Driver'), findsNothing);
  });

  testWidgets('legacy jobs remain visible under All Types', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(
          jobsStream: Stream.value([thirdJob]),
          preferencesService: _FakeStudentJobPreferencesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delivery Driver'));

    expect(find.text('Delivery Driver'), findsOneWidget);
    expect(find.text('Work type not specified'), findsOneWidget);
  });

  testWidgets('filters jobs by all advertised schedule values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(
          jobsStream: Stream.value(testJobs),
          preferencesService: _FakeStudentJobPreferencesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scheduleFilter = find.byKey(const ValueKey('job-schedule-filter'));
    for (final (schedule, expectedTitle) in [
      ('Weekdays', 'Cafe Assistant'),
      ('Weekends', 'Shop Assistant'),
      ('Flexible', 'Temporary Cleaner'),
    ]) {
      await tester.tap(scheduleFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text(schedule).last);
      await tester.pumpAndSettle();

      expect(find.text(expectedTitle), findsOneWidget);
      for (final otherTitle in [
        'Cafe Assistant',
        'Shop Assistant',
        'Delivery Driver',
        'Temporary Cleaner',
      ]) {
        if (otherTitle != expectedTitle) {
          expect(find.text(otherTitle), findsNothing);
        }
      }
    }
  });

  testWidgets('combines work type with search and location filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(
          jobsStream: Stream.value(testJobs),
          preferencesService: _FakeStudentJobPreferencesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('job-search-field')),
      'assistant',
    );
    await tester.tap(find.byKey(const ValueKey('job-location-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Busan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('job-work-type-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full-time').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('job-schedule-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekends').last);
    await tester.pumpAndSettle();

    expect(find.text('Shop Assistant'), findsOneWidget);
    expect(find.text('Cafe Assistant'), findsNothing);
    expect(find.text('Delivery Driver'), findsNothing);
    expect(find.text('Temporary Cleaner'), findsNothing);
  });

  testWidgets('combines search and location filters', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(
          jobsStream: Stream.value(testJobs),
          preferencesService: _FakeStudentJobPreferencesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('job-search-field')),
      'assistant',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('job-location-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Busan').last);
    await tester.pumpAndSettle();

    expect(find.text('Shop Assistant'), findsOneWidget);
    expect(find.text('Cafe Assistant'), findsNothing);
    expect(find.text('Delivery Driver'), findsNothing);
  });

  testWidgets('clears search and location filters', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(
          jobsStream: Stream.value(testJobs),
          preferencesService: _FakeStudentJobPreferencesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('job-work-type-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part-time').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('job-schedule-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flexible').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('job-search-field')),
      'no match',
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching jobs'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clear-job-filters')));
    await tester.pumpAndSettle();

    expect(find.text('No matching jobs'), findsNothing);
    expect(find.text('All Locations'), findsOneWidget);
    expect(find.text('All Types'), findsOneWidget);
    expect(find.text('All Schedules'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-job-filters')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('job-search-field')),
      'delivery',
    );
    await tester.pumpAndSettle();
    expect(find.text('Delivery Driver'), findsOneWidget);
  });

  testWidgets('saves and edits optional job matching preferences', (
    tester,
  ) async {
    final service = _FakeStudentJobPreferencesService();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(
          jobsStream: Stream.value(testJobs),
          preferencesService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('job-matching-preferences')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('preferred-job-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Busan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preferred-job-work-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full-time').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preferred-job-schedule')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekends').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-job-preferences')),
    );
    await tester.tap(find.byKey(const ValueKey('save-job-preferences')));
    await tester.pumpAndSettle();

    expect(service.savedPreferences?.preferredLocation, 'Busan');
    expect(service.savedPreferences?.preferredWorkType, 'Full-time');
    expect(service.savedPreferences?.preferredSchedule, 'Weekends');
    expect(find.text('Matching preferences saved.'), findsOneWidget);
    expect(find.text('Matches 3 of 3 preferences'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, 160));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('preferred-job-work-type')),
    );
    await tester.tap(find.byKey(const ValueKey('preferred-job-work-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part-time').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-job-preferences')),
    );
    await tester.tap(find.byKey(const ValueKey('save-job-preferences')));
    await tester.pumpAndSettle();

    expect(service.savedPreferences?.preferredWorkType, 'Part-time');
    expect(service.saveCalls, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(
          jobsStream: Stream.value(testJobs),
          preferencesService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('job-matching-preferences')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DropdownButtonFormField<String?>>(
            find.byKey(const ValueKey('preferred-job-location')),
          )
          .initialValue,
      'Busan',
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String?>>(
            find.byKey(const ValueKey('preferred-job-work-type')),
          )
          .initialValue,
      'Part-time',
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String?>>(
            find.byKey(const ValueKey('preferred-job-schedule')),
          )
          .initialValue,
      'Weekends',
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('preferred-job-location')),
    );
    await tester.tap(find.byKey(const ValueKey('preferred-job-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No preference').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-job-preferences')),
    );
    await tester.tap(find.byKey(const ValueKey('save-job-preferences')));
    await tester.pumpAndSettle();

    expect(service.savedPreferences?.preferredLocation, isNull);
    expect(service.savedPreferences?.preferredWorkType, 'Part-time');
    expect(service.savedPreferences?.preferredSchedule, 'Weekends');
  });

  testWidgets(
    'no saved preferences preserve listing order and omit indicators',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StudentJobListingsScreen(
            jobsStream: Stream.value(testJobs),
            preferencesService: _FakeStudentJobPreferencesService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Optional — no preferences selected'), findsOneWidget);
      expect(find.textContaining('Matches '), findsNothing);
      expect(find.text('Cafe Assistant'), findsOneWidget);
    },
  );

  testWidgets('manual filters are preserved and matches sort visible jobs', (
    tester,
  ) async {
    final service = _FakeStudentJobPreferencesService(
      initialPreferences: const StudentJobPreferences(
        preferredLocation: 'Busan',
        preferredWorkType: 'Full-time',
        preferredSchedule: 'Weekends',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(
          jobsStream: Stream.value(testJobs),
          preferencesService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('job-location-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Busan').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -1800));
    await tester.pumpAndSettle();

    expect(find.text('Cafe Assistant'), findsNothing);
    expect(find.text('Shop Assistant'), findsOneWidget);
    expect(find.text('Delivery Driver'), findsOneWidget);
    expect(find.text('Temporary Cleaner'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Shop Assistant')).dy,
      lessThan(tester.getTopLeft(find.text('Delivery Driver')).dy),
    );
    expect(find.text('Matches 3 of 3 preferences'), findsOneWidget);
    expect(find.text('Matches 1 of 3 preferences'), findsWidgets);
  });

  testWidgets('student can cancel application confirmation', (tester) async {
    final service = _FakeJobApplicationService();
    await _pumpJobDetails(tester, service);

    await tester.ensureVisible(find.byKey(const ValueKey('apply-for-job')));
    await tester.tap(find.byKey(const ValueKey('apply-for-job')));
    await tester.pumpAndSettle();

    expect(find.text('Apply for this job?'), findsOneWidget);
    expect(
      find.text('Submit an application for "Cafe Assistant"?'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('cancel-job-application')));
    await tester.pumpAndSettle();

    expect(service.applyCalls, 0);
    expect(find.byKey(const ValueKey('apply-for-job')), findsOneWidget);
  });

  testWidgets('successful application changes the button to Applied', (
    tester,
  ) async {
    final service = _FakeJobApplicationService();
    await _pumpJobDetails(tester, service);

    await tester.ensureVisible(find.byKey(const ValueKey('apply-for-job')));
    await tester.tap(find.byKey(const ValueKey('apply-for-job')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-job-application')));
    await tester.pumpAndSettle();

    expect(service.applyCalls, 1);
    expect(find.text('Applied'), findsOneWidget);
    expect(find.text('Application submitted successfully.'), findsOneWidget);
  });

  testWidgets('recognizes an existing application on revisit', (tester) async {
    final service = _FakeJobApplicationService(
      status: JobApplicationStatus.alreadyApplied,
    );
    await _pumpJobDetails(tester, service);

    expect(find.text('Applied'), findsOneWidget);
    expect(find.byKey(const ValueKey('apply-for-job')), findsNothing);
    expect(service.applyCalls, 0);
  });

  testWidgets('duplicate application race reports already applied', (
    tester,
  ) async {
    final service = _FakeJobApplicationService(
      onApply: (_) async => throw const JobAlreadyAppliedException(),
    );
    await _pumpJobDetails(tester, service);

    await tester.ensureVisible(find.byKey(const ValueKey('apply-for-job')));
    await tester.tap(find.byKey(const ValueKey('apply-for-job')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-job-application')));
    await tester.pumpAndSettle();

    expect(find.text('You have already applied for this job.'), findsOneWidget);
    expect(find.text('Applied'), findsOneWidget);
  });

  testWidgets('unauthenticated and non-student accounts cannot apply', (
    tester,
  ) async {
    for (final status in [
      JobApplicationStatus.unauthenticated,
      JobApplicationStatus.studentRoleRequired,
    ]) {
      final service = _FakeJobApplicationService(status: status);
      await _pumpJobDetails(tester, service);

      expect(find.byKey(const ValueKey('apply-for-job')), findsNothing);
      expect(find.text('Apply for Job'), findsOneWidget);
      expect(service.applyCalls, 0);

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('permission-denied application errors are explained', (
    tester,
  ) async {
    final service = _FakeJobApplicationService(
      onApply: (_) async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      },
    );
    await _pumpJobDetails(tester, service);

    await tester.ensureVisible(find.byKey(const ValueKey('apply-for-job')));
    await tester.tap(find.byKey(const ValueKey('apply-for-job')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-job-application')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your application was denied'), findsOneWidget);
    expect(find.byKey(const ValueKey('apply-for-job')), findsOneWidget);
  });
}

Future<void> _pumpJobDetails(
  WidgetTester tester,
  JobApplicationService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StudentJobDetailsScreen(job: job, applicationService: service),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeJobApplicationService implements JobApplicationService {
  _FakeJobApplicationService({
    this.status = JobApplicationStatus.canApply,
    this.onApply,
  });

  final JobApplicationStatus status;
  final Future<void> Function(String jobId)? onApply;
  int applyCalls = 0;

  @override
  Future<JobApplicationStatus> getStatus(String jobId) async => status;

  @override
  Future<void> apply(String jobId) async {
    applyCalls++;
    await onApply?.call(jobId);
  }
}

class _FakeStudentJobPreferencesService
    implements StudentJobPreferencesService {
  _FakeStudentJobPreferencesService({
    this.initialPreferences = const StudentJobPreferences(),
  });

  final StudentJobPreferences initialPreferences;
  StudentJobPreferences? savedPreferences;
  int saveCalls = 0;

  @override
  Future<StudentJobPreferences> loadPreferences() async =>
      savedPreferences ?? initialPreferences;

  @override
  Future<void> savePreferences(StudentJobPreferences preferences) async {
    saveCalls++;
    savedPreferences = preferences;
  }
}
