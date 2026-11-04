import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/employer/employer_dashboard_screen.dart';
import 'package:pallijob/screens/employer/post_job_screen.dart';

void main() {
  testWidgets('Post Job dashboard card opens the posting form', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EmployerDashboardScreen()));

    await tester.tap(find.text('Post Job'));
    await tester.pumpAndSettle();

    expect(find.text('Create a job listing'), findsOneWidget);
  });

  testWidgets('shows required-field validation without submitting', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PostJobScreen()));

    expect(find.text('Job title'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Requirements'), findsOneWidget);

    await tester.ensureVisible(find.text('Post Job'));
    await tester.tap(find.text('Post Job'));
    await tester.pumpAndSettle();

    expect(find.text('Job title is required.'), findsOneWidget);
    expect(find.text('Description is required.'), findsOneWidget);
    expect(find.text('Location is required.'), findsOneWidget);
    expect(find.text('Requirements is required.'), findsOneWidget);
  });
}
