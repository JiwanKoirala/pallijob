import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/employer/edit_job_screen.dart';
import 'package:pallijob/screens/employer/manage_jobs_screen.dart';
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

  testWidgets('shows loading state while employer jobs are loading', (
    tester,
  ) async {
    final controller = StreamController<List<StudentJobListing>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(home: ManageJobsScreen(jobsStream: controller.stream)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('공고를 불러오는 중'), findsOneWidget);
  });

  testWidgets('shows an empty state when the employer has no jobs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(
          jobsStream: Stream.value(const <StudentJobListing>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('아직 등록한 공고가 없습니다'), findsOneWidget);
  });

  testWidgets('shows job summaries and opens read-only details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(jobsStream: Stream.value(const [job])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cafe Assistant'), findsOneWidget);
    expect(find.text('Seoul'), findsOneWidget);
    expect(find.text('근무 형태 미지정'), findsOneWidget);
    expect(find.text('근무 일정 미지정'), findsOneWidget);
    expect(
      find.text('Help prepare drinks and serve customers.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cafe Assistant'));
    await tester.pumpAndSettle();

    expect(find.text('공고 상세 정보'), findsOneWidget);
    expect(find.text('Friendly and reliable.'), findsOneWidget);
    expect(find.text('employer-1'), findsOneWidget);
    expect(find.text('Apply for Job'), findsNothing);
    expect(find.text('Check Visa Eligibility'), findsNothing);
  });

  testWidgets('Edit action opens a prefilled edit form', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(jobsStream: Stream.value(const [job])),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-job-job-1')));
    await tester.pumpAndSettle();

    expect(find.byType(EditJobScreen), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('edit-job-공고-제목')),
          )
          .controller!
          .text,
      'Cafe Assistant',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('edit-job-상세-설명')),
          )
          .controller!
          .text,
      'Help prepare drinks and serve customers.',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('edit-job-근무-지역')),
          )
          .controller!
          .text,
      'Seoul',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('edit-job-지원-요건')),
          )
          .controller!
          .text,
      'Friendly and reliable.',
    );
    expect(find.text('선택 안 함'), findsNWidgets(2));

    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-job-work-type')),
    );
    await tester.tap(find.byKey(const ValueKey('edit-job-work-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시간제').last);
    await tester.pumpAndSettle();
    expect(find.text('시간제'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<String?>>(
            find.byKey(const ValueKey('edit-job-work-type')),
          )
          .initialValue,
      'Part-time',
    );

    await tester.ensureVisible(find.byKey(const ValueKey('edit-job-schedule')));
    await tester.tap(find.byKey(const ValueKey('edit-job-schedule')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('주말').last);
    await tester.pumpAndSettle();
    expect(find.text('주말'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<String?>>(
            find.byKey(const ValueKey('edit-job-schedule')),
          )
          .initialValue,
      'Weekends',
    );

    await tester.enterText(
      find.byKey(const ValueKey('edit-job-공고-제목')),
      '',
    );
    await tester.ensureVisible(find.text('변경 사항 저장'));
    await tester.tap(find.text('변경 사항 저장'));
    await tester.pumpAndSettle();

    expect(find.text('공고 제목은 필수 입력 항목입니다.'), findsOneWidget);
  });

  testWidgets('취소하면 공고가 변경되지 않는다', (tester) async {
    var deleteCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(
          jobsStream: Stream.value(const [job]),
          deleteJob: (_) async {
            deleteCalls++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-job-job-1')));
    await tester.pumpAndSettle();

    expect(find.text('공고를 삭제하시겠습니까?'), findsOneWidget);
    expect(
      find.text(
        '"Cafe Assistant" 공고를 삭제하시겠습니까? 삭제한 공고는 복구할 수 없습니다.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('cancel-delete-job-job-1')));
    await tester.pumpAndSettle();

    expect(deleteCalls, 0);
    expect(find.text('Cafe Assistant'), findsOneWidget);
  });

  testWidgets('confirmed deletion reports success and removes the job', (
    tester,
  ) async {
    final jobsController = StreamController<List<StudentJobListing>>();
    addTearDown(jobsController.close);
    jobsController.add(const [job]);

    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(
          jobsStream: jobsController.stream,
          deleteJob: (_) async => jobsController.add(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-job-job-1')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '"Cafe Assistant" 공고를 삭제하시겠습니까? 삭제한 공고는 복구할 수 없습니다.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('confirm-delete-job-job-1')));
    await tester.pumpAndSettle();

    expect(find.text('채용 공고가 삭제되었습니다.'), findsOneWidget);
    expect(find.text('아직 등록한 공고가 없습니다'), findsOneWidget);
  });

  testWidgets('shows permission-denied deletion errors and keeps the job', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(
          jobsStream: Stream.value(const [job]),
          deleteJob: (_) async {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-job-job-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-job-job-1')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('삭제 권한이 없습니다'),
      findsOneWidget,
    );
    expect(find.text('Cafe Assistant'), findsOneWidget);
  });

  testWidgets('shows progress and prevents a second delete tap', (
    tester,
  ) async {
    final deletion = Completer<void>();
    var deleteCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(
          jobsStream: Stream.value(const [job]),
          deleteJob: (_) {
            deleteCalls++;
            return deletion.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-job-job-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-job-job-1')));
    await tester.pump();

    expect(find.text('삭제 중…'), findsOneWidget);
    expect(deleteCalls, 1);
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('delete-job-job-1')))
          .onPressed,
      isNull,
    );

    deletion.complete();
    await tester.pumpAndSettle();
    expect(find.text('채용 공고가 삭제되었습니다.'), findsOneWidget);
  });

  testWidgets('explains permission denied errors', (tester) async {
    final permissionError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ManageJobsScreen(jobsStream: Stream.error(permissionError)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('공고를 불러오지 못했습니다'), findsOneWidget);
    expect(find.textContaining('공고를 확인할 권한'), findsOneWidget);
  });
}
