import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:pallijob/screens/auth/welcome_screen.dart';

void main() {
  testWidgets('PalliJob welcome screen displays correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: WelcomeScreen()),
    );

    expect(find.text('Good work starts here.'), findsOneWidget);
    expect(find.text('Continue as Student'), findsOneWidget);
    expect(find.text('Continue as Employer'), findsOneWidget);
  });
}