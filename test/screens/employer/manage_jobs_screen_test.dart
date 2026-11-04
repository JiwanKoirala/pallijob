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

    await tester.enterText(
      find.byKey(const ValueKey('edit-job-job-title')),
      '',
    );
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Job title is required.'), findsOneWidget);
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
