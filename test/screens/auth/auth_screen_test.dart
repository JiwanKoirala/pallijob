import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/auth/auth_screen.dart';

void main() {
  testWidgets('student registration shows student-specific fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthScreen(role: 'Student')),
    );

    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Business name'), findsNothing);
  });

  testWidgets('employer registration shows employer-specific fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthScreen(role: 'Employer')),
    );

    expect(find.text('Business name'), findsOneWidget);
    expect(find.text('Employer full name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Full name'), findsNothing);
  });

  testWidgets('login mode only asks for email and password', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthScreen(role: 'Student')),
    );

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Full name'), findsNothing);
    expect(find.text('Confirm password'), findsNothing);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('registration validates required fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthScreen(role: 'Employer')),
    );

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Business name is required.'), findsOneWidget);
    expect(find.text('Employer full name is required.'), findsOneWidget);
    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(find.text('Confirm password is required.'), findsOneWidget);
  });
}
