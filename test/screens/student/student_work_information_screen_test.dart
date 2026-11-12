import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/student/student_dashboard_screen.dart';
import 'package:pallijob/screens/student/student_work_information_screen.dart';

void main() {
  testWidgets('student dashboard opens Work Information and FAQ', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StudentDashboardScreen()));

    await tester.ensureVisible(find.text('Work Information & FAQ'));
    await tester.tap(find.text('Work Information & FAQ'));
    await tester.pumpAndSettle();

    expect(find.byType(StudentWorkInformationScreen), findsOneWidget);
    expect(find.text('Work Information & FAQ'), findsOneWidget);
  });

  testWidgets('FAQ answers expand and collapse', (tester) async {
    await _pumpScreen(tester);

    const question = 'Can students with D-2 or D-4 status work part-time?';
    await tester.scrollUntilVisible(
      find.text(question),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text(question), findsOneWidget);
    expect(
      find.textContaining('Rules can depend on your exact status'),
      findsNothing,
    );

    await tester.tap(find.text(question));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Rules can depend on your exact status'),
      findsOneWidget,
    );
    expect(
      find.textContaining('university international office'),
      findsWidgets,
    );

    await tester.ensureVisible(find.text(question));
    await tester.tap(find.text(question));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Rules can depend on your exact status'),
      findsNothing,
    );
  });

  testWidgets('HiKorea action launches the existing official URL', (
    tester,
  ) async {
    Uri? openedUri;
    await _pumpScreen(
      tester,
      launchExternal: (uri) async {
        openedUri = uri;
        return true;
      },
    );

    expect(find.text('https://www.hikorea.go.kr/'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-work-info-hikorea')));
    await tester.pumpAndSettle();

    expect(openedUri, StudentWorkInformationScreen.hiKoreaUri);
    expect(openedUri.toString(), 'https://www.hikorea.go.kr/');
  });

  testWidgets('shows an error and fallback link when HiKorea cannot open', (
    tester,
  ) async {
    await _pumpScreen(tester, launchExternal: (_) async => false);

    await tester.tap(find.byKey(const ValueKey('open-work-info-hikorea')));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not open HiKorea. Visit https://www.hikorea.go.kr/'),
      findsOneWidget,
    );
  });

  testWidgets('shows immigration and informational-only disclaimers', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Important: confirm before working'), findsOneWidget);
    expect(
      find.textContaining('PalliJob does not determine legal eligibility'),
      findsOneWidget,
    );
    expect(find.text('Immigration Contact Center'), findsOneWidget);
    expect(find.textContaining('Call 1345'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('About this information'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('About this information'), findsOneWidget);
    expect(
      find.textContaining(
        'does not automatically assess, approve, or guarantee',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  ExternalResourceLauncher? launchExternal,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StudentWorkInformationScreen(launchExternal: launchExternal),
    ),
  );
  await tester.pumpAndSettle();
}
