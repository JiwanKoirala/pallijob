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

    expect(find.text('회사명'), findsOneWidget);
    expect(find.text('담당자 성함'), findsOneWidget);
    expect(find.text('이메일'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('비밀번호 확인'), findsOneWidget);
    expect(find.text('성함'), findsNothing);
    expect(find.text('고용주 계정 만들기'), findsOneWidget);
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

    await tester.ensureVisible(find.text('계정 만들기'));
    await tester.tap(find.text('계정 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('회사명은 필수 입력 항목입니다.'), findsOneWidget);
    expect(find.text('담당자 성함은 필수 입력 항목입니다.'), findsOneWidget);
    expect(find.text('이메일은 필수 입력 항목입니다.'), findsOneWidget);
    expect(find.text('비밀번호는 필수 입력 항목입니다.'), findsOneWidget);
    expect(find.text('비밀번호 확인은 필수 입력 항목입니다.'), findsOneWidget);
  });

  testWidgets('employer login mode is Korean while student auth stays English', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthScreen(role: 'Employer')),
    );

    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();

    expect(find.text('다시 오신 것을 환영합니다'), findsOneWidget);
    expect(find.text('이메일'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('로그인'), findsNWidgets(2));
  });
}
