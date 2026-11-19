import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/employer/employer_dashboard_screen.dart';
import 'package:pallijob/screens/employer/post_job_screen.dart';

void main() {
  testWidgets('posting dashboard card opens the Korean posting form', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: EmployerDashboardScreen()));

    await tester.tap(find.text('채용 공고 등록'));
    await tester.pumpAndSettle();

    expect(find.text('채용 공고 작성'), findsOneWidget);
  });

  testWidgets('shows required-field validation without submitting', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PostJobScreen()));

    expect(find.text('공고 제목'), findsOneWidget);
    expect(find.text('상세 설명'), findsOneWidget);
    expect(find.text('근무 지역'), findsOneWidget);
    expect(find.text('지원 요건'), findsOneWidget);
    expect(find.text('근무 형태'), findsOneWidget);

    await tester.ensureVisible(find.text('공고 등록'));
    await tester.tap(find.text('공고 등록'));
    await tester.pumpAndSettle();

    expect(find.text('공고 제목은 필수 입력 항목입니다.'), findsOneWidget);
    expect(find.text('상세 설명은 필수 입력 항목입니다.'), findsOneWidget);
    expect(find.text('근무 지역은 필수 입력 항목입니다.'), findsOneWidget);
    expect(find.text('지원 요건은 필수 입력 항목입니다.'), findsOneWidget);
    expect(find.text('근무 형태를 선택해 주세요.'), findsOneWidget);
    expect(find.text('근무 일정은 필수 입력 항목입니다.'), findsNothing);
  });

  testWidgets('employer can select a work type when creating a job', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PostJobScreen()));

    await tester.ensureVisible(
      find.byKey(const ValueKey('post-job-work-type')),
    );
    await tester.tap(find.byKey(const ValueKey('post-job-work-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('임시/계약직').last);
    await tester.pumpAndSettle();

    expect(find.text('임시/계약직'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<String?>>(
            find.byKey(const ValueKey('post-job-work-type')),
          )
          .initialValue,
      'Temporary/Contract',
    );
  });

  testWidgets('schedule is optional and offers the approved choices', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PostJobScreen()));

    final scheduleField = find.byKey(const ValueKey('post-job-schedule'));
    await tester.ensureVisible(scheduleField);
    await tester.tap(scheduleField);
    await tester.pumpAndSettle();

    expect(find.text('선택 안 함'), findsNWidgets(2));
    expect(find.text('평일'), findsOneWidget);
    expect(find.text('주말'), findsOneWidget);
    expect(find.text('유연 근무'), findsOneWidget);

    await tester.tap(find.text('유연 근무').last);
    await tester.pumpAndSettle();
    expect(find.text('유연 근무'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<String?>>(
            find.byKey(const ValueKey('post-job-schedule')),
          )
          .initialValue,
      'Flexible',
    );
  });
}
