import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:pallijob/screens/auth/auth_screen.dart';
import 'package:pallijob/screens/auth/welcome_screen.dart';

void main() {
  testWidgets('PalliJob welcome screen displays correctly', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

    expect(find.text('Good work starts here.'), findsOneWidget);
    expect(find.text('Continue as Student'), findsOneWidget);
    expect(find.text('고용주로 계속하기'), findsOneWidget);
  });

  testWidgets(
    'Korean employer entry opens the localized employer auth screen',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

      await tester.ensureVisible(find.text('고용주로 계속하기'));
      await tester.tap(find.text('고용주로 계속하기'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('고용주 계정 만들기'), findsOneWidget);
      expect(find.text('회사명'), findsOneWidget);
    },
  );
}
