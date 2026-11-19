import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/employer/edit_job_screen.dart';
import 'package:pallijob/screens/employer/manage_jobs_screen.dart';
import 'package:pallijob/screens/student/student_job_listings_screen.dart';

void main() {
  const job = StudentJobListing(
    id: 'job-1',
    title: 'Cafe Assistant',
    description: 'Help prepare drinks and serve customers.',
    location: 'Seoul',
    requirements: 'Friendly and reliable.',
    employerId: 'employer-1',
    createdAt: null,
  );

  testWidgets('shows loading state while employer jobs are loading', (
    tester,
  ) async {
    final controller = StreamController<List<StudentJobListing>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(home: ManageJobsScreen(jobsStream: controller.stream)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading your jobs'), findsOneWidget);
  });

  testWidgets('shows an empty state when the employer has no jobs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(
          jobsStream: Stream.value(const <StudentJobListing>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You have not posted any jobs yet'), findsOneWidget);
  });

  testWidgets('shows job summaries and opens read-only details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(jobsStream: Stream.value(const [job])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cafe Assistant'), findsOneWidget);
    expect(find.text('Seoul'), findsOneWidget);
    expect(find.text('Work type not specified'), findsOneWidget);
    expect(find.text('Schedule not specified'), findsOneWidget);
    expect(
      find.text('Help prepare drinks and serve customers.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cafe Assistant'));
    await tester.pumpAndSettle();

    expect(find.text('Job Details'), findsOneWidget);
    expect(find.text('Friendly and reliable.'), findsOneWidget);
    expect(find.text('employer-1'), findsOneWidget);
  });

  testWidgets('Edit action opens a prefilled edit form', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(jobsStream: Stream.value(const [job])),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-job-job-1')));
    await tester.pumpAndSettle();

    expect(find.byType(EditJobScreen), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('edit-job-job-title')),
          )
          .controller!
          .text,
      'Cafe Assistant',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('edit-job-description')),
          )
          .controller!
          .text,
      'Help prepare drinks and serve customers.',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('edit-job-location')),
          )
          .controller!
          .text,
      'Seoul',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('edit-job-requirements')),
          )
          .controller!
          .text,
      'Friendly and reliable.',
    );
    expect(find.text('Not specified'), findsNWidgets(2));

    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-job-work-type')),
    );
    await tester.tap(find.byKey(const ValueKey('edit-job-work-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part-time').last);
    await tester.pumpAndSettle();
    expect(find.text('Part-time'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('edit-job-schedule')));
    await tester.tap(find.byKey(const ValueKey('edit-job-schedule')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekends').last);
    await tester.pumpAndSettle();
    expect(find.text('Weekends'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('edit-job-job-title')),
      '',
    );
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Job title is required.'), findsOneWidget);
  });

  testWidgets('Cancel leaves the job unchanged', (tester) async {
    var deleteCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(
          jobsStream: Stream.value(const [job]),
          deleteJob: (_) async {
            deleteCalls++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-job-job-1')));
    await tester.pumpAndSettle();

    expect(find.text('Delete job?'), findsOneWidget);
    expect(
      find.text(
        'Are you sure you want to delete "Cafe Assistant"? This cannot be undone.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('cancel-delete-job-job-1')));
    await tester.pumpAndSettle();

    expect(deleteCalls, 0);
    expect(find.text('Cafe Assistant'), findsOneWidget);
  });

  testWidgets('confirmed deletion reports success and removes the job', (
    tester,
  ) async {
    final jobsController = StreamController<List<StudentJobListing>>();
    addTearDown(jobsController.close);
    jobsController.add(const [job]);

    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(
          jobsStream: jobsController.stream,
          deleteJob: (_) async => jobsController.add(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-job-job-1')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Are you sure you want to delete "Cafe Assistant"? This cannot be undone.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('confirm-delete-job-job-1')));
    await tester.pumpAndSettle();

    expect(find.text('Job deleted successfully.'), findsOneWidget);
    expect(find.text('You have not posted any jobs yet'), findsOneWidget);
  });

  testWidgets('shows permission-denied deletion errors and keeps the job', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(
          jobsStream: Stream.value(const [job]),
          deleteJob: (_) async {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-job-job-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-job-job-1')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Firestore denied this deletion'),
      findsOneWidget,
    );
    expect(find.text('Cafe Assistant'), findsOneWidget);
  });

  testWidgets('shows progress and prevents a second delete tap', (
    tester,
  ) async {
    final deletion = Completer<void>();
    var deleteCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(
          jobsStream: Stream.value(const [job]),
          deleteJob: (_) {
            deleteCalls++;
            return deletion.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-job-job-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-job-job-1')));
    await tester.pump();

    expect(find.text('Deleting…'), findsOneWidget);
    expect(deleteCalls, 1);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('delete-job-job-1')))
          .onPressed,
      isNull,
    );

    deletion.complete();
    await tester.pumpAndSettle();
    expect(find.text('Job deleted successfully.'), findsOneWidget);
  });

  testWidgets('explains permission denied errors', (tester) async {
    final permissionError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(jobsStream: Stream.error(permissionError)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load your jobs'), findsOneWidget);
    expect(find.textContaining('do not have permission'), findsOneWidget);
  });
}
