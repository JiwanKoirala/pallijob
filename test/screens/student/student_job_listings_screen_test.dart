import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('shows loading state while jobs are loading', (tester) async {
    final controller = StreamController<List<StudentJobListing>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(jobsStream: controller.stream),
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No jobs available yet'), findsOneWidget);
  });

  testWidgets('lists jobs and opens their complete details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(jobsStream: Stream.value(const [job])),
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load jobs'), findsOneWidget);
    expect(find.textContaining('do not have permission'), findsOneWidget);
  });
}
