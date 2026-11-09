import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/student/student_dashboard_screen.dart';
import 'package:pallijob/screens/student/student_profile_screen.dart';

const studentProfile = StudentProfile(
  fullName: 'Alex Student',
  email: 'alex@example.com',
  visaStatus: 'D-2',
  languages: ['English', 'Korean'],
);

void main() {
  testWidgets('shows loading state while the profile is loading', (
    tester,
  ) async {
    final pending = Completer<StudentProfile>();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentProfileScreen(
          profileService: _FakeStudentProfileService(pending.future),
        ),
      ),
    );

    expect(find.text('Loading profile'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('loads existing details and shows role as read-only', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      _FakeStudentProfileService(Future.value(studentProfile)),
    );

    expect(find.text('Alex Student'), findsOneWidget);
    expect(find.text('alex@example.com'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.byKey(const ValueKey('student-visa-status')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('student-visa-status')),
          )
          .controller!
          .text,
      'D-2',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('student-languages')),
          )
          .controller!
          .text,
      'English, Korean',
    );
    expect(find.text('Role'), findsNothing);
  });

  testWidgets('requires visa status and at least one language', (tester) async {
    final service = _FakeStudentProfileService(Future.value(studentProfile));
    await _pumpProfile(tester, service);

    await tester.enterText(
      find.byKey(const ValueKey('student-visa-status')),
      '  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('student-languages')),
      ' , ',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-student-profile')),
    );
    await tester.tap(find.byKey(const ValueKey('save-student-profile')));
    await tester.pumpAndSettle();

    expect(find.text('Visa status is required.'), findsOneWidget);
    expect(
      find.text('Enter a language for each comma-separated value.'),
      findsOneWidget,
    );
    expect(service.saveCalls, 0);
  });

  testWidgets('saves trimmed editable fields only and confirms success', (
    tester,
  ) async {
    final service = _FakeStudentProfileService(Future.value(studentProfile));
    await _pumpProfile(tester, service);

    await tester.enterText(
      find.byKey(const ValueKey('student-visa-status')),
      '  D-2 student  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('student-languages')),
      ' English , Korean ',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-student-profile')),
    );
    await tester.tap(find.byKey(const ValueKey('save-student-profile')));
    await tester.pumpAndSettle();

    expect(service.savedVisaStatus, 'D-2 student');
    expect(service.savedLanguages, ['English', 'Korean']);
    expect(service.saveCalls, 1);
    expect(find.text('Profile updated successfully.'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
  });

  testWidgets('does not expose role as editable or include it in updates', (
    tester,
  ) async {
    final service = _FakeStudentProfileService(Future.value(studentProfile));
    await _pumpProfile(tester, service);
    expect(find.text('Account type'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    await tester.ensureVisible(
      find.byKey(const ValueKey('save-student-profile')),
    );
    await tester.tap(find.byKey(const ValueKey('save-student-profile')));
    await tester.pumpAndSettle();
    expect(service.updatedFieldNames, {'visaStatus', 'languages'});
  });

  testWidgets('shows a clear access error for a non-student role', (
    tester,
  ) async {
    final load = Completer<StudentProfile>();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentProfileScreen(
          profileService: _FakeStudentProfileService(load.future),
        ),
      ),
    );
    load.completeError(
      const StudentProfileException(
        'Only student accounts can view this profile.',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load profile'), findsOneWidget);
    expect(
      find.text('Only student accounts can view this profile.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('explains permission denied when saving', (tester) async {
    final service = _FakeStudentProfileService(
      Future.value(studentProfile),
      onSave: () async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      },
    );
    await _pumpProfile(tester, service);

    await tester.ensureVisible(
      find.byKey(const ValueKey('save-student-profile')),
    );
    await tester.tap(find.byKey(const ValueKey('save-student-profile')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Firestore denied this update. Check that the rules allow student profile fields.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('dashboard My Profile card opens the profile screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StudentDashboardScreen()));

    await tester.ensureVisible(find.text('My Profile'));
    await tester.tap(find.text('My Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load profile'), findsOneWidget);
  });
}

Future<void> _pumpProfile(
  WidgetTester tester,
  StudentProfileService service,
) async {
  await tester.pumpWidget(
    MaterialApp(home: StudentProfileScreen(profileService: service)),
  );
  await tester.pumpAndSettle();
}

class _FakeStudentProfileService implements StudentProfileService {
  _FakeStudentProfileService(this.loadResult, {this.onSave});

  final Future<StudentProfile> loadResult;
  final Future<void> Function()? onSave;
  int saveCalls = 0;
  String? savedVisaStatus;
  List<String>? savedLanguages;

  Set<String> get updatedFieldNames => {'visaStatus', 'languages'};

  @override
  Future<StudentProfile> loadProfile() => loadResult;

  @override
  Future<void> saveProfile({
    required String visaStatus,
    required List<String> languages,
  }) async {
    saveCalls++;
    savedVisaStatus = visaStatus;
    savedLanguages = languages;
    await onSave?.call();
  }
}
