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
  const secondJob = StudentJobListing(
    id: 'job-2',
    title: 'Shop Assistant',
    description: 'Help customers find products.',
    location: 'Busan',
    requirements: 'Helpful and organized.',
    employerId: 'employer-2',
    createdAt: null,
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

  const testJobs = [job, secondJob, thirdJob];

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

  testWidgets(
    'searches titles case-insensitively and trims surrounding spaces',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StudentJobListingsScreen(jobsStream: Stream.value(testJobs)),
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
        home: StudentJobListingsScreen(jobsStream: Stream.value(testJobs)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('job-location-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Busan').last);
    await tester.pumpAndSettle();

    expect(find.text('Shop Assistant'), findsOneWidget);
    expect(find.text('Delivery Driver'), findsOneWidget);
    expect(find.text('Cafe Assistant'), findsNothing);
  });

  testWidgets('combines search and location filters', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJobListingsScreen(jobsStream: Stream.value(testJobs)),
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
        home: StudentJobListingsScreen(jobsStream: Stream.value(testJobs)),
      ),
    );
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
    expect(find.byKey(const ValueKey('clear-job-filters')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('job-search-field')),
      'delivery',
    );
    await tester.pumpAndSettle();
    expect(find.text('Delivery Driver'), findsOneWidget);
  });
}
