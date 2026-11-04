import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/auth/welcome_screen.dart';

void main() {
  testWidgets('shows the PalliJob welcome content and role choices', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

    expect(find.text('PalliJob'), findsOneWidget);
    expect(find.text('Find the right part-time job in Korea.'), findsOneWidget);
    expect(find.text('Continue as Student'), findsOneWidget);
    expect(find.text('Continue as Employer'), findsOneWidget);
  });

  testWidgets('opens the role-specific authentication screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

    final studentButton = find.text('Continue as Student');
    await tester.ensureVisible(studentButton);
    await tester.tap(studentButton);
    await tester.pumpAndSettle();
    expect(find.text('Create your student account'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    final employerButton = find.text('Continue as Employer');
    await tester.ensureVisible(employerButton);
    await tester.tap(employerButton);
    await tester.pumpAndSettle();
    expect(find.text('Create your employer account'), findsOneWidget);
  });
}
