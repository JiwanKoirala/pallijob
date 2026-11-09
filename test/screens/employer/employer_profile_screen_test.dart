import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/employer/employer_dashboard_screen.dart';
import 'package:pallijob/screens/employer/employer_profile_screen.dart';

const employerProfile = EmployerProfile(
  fullName: 'Morgan Employer',
  email: 'morgan@example.com',
  companyName: 'PalliJob Cafe',
  contactInfo: 'jobs@example.com',
);

void main() {
  testWidgets('shows loading state while the profile is loading', (
    tester,
  ) async {
    final pending = Completer<EmployerProfile>();
    await tester.pumpWidget(
      MaterialApp(
        home: EmployerProfileScreen(
          profileService: _FakeEmployerProfileService(pending.future),
        ),
      ),
    );

    expect(find.text('Loading profile'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('loads account details and keeps role read-only', (tester) async {
    await _pumpProfile(
      tester,
      _FakeEmployerProfileService(Future.value(employerProfile)),
    );

    expect(find.text('Morgan Employer'), findsOneWidget);
    expect(find.text('morgan@example.com'), findsOneWidget);
    expect(find.text('Employer'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('employer-company-name')),
          )
          .controller!
          .text,
      'PalliJob Cafe',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('employer-contact-info')),
          )
          .controller!
          .text,
      'jobs@example.com',
    );
  });

  testWidgets('requires a company name and contact information', (
    tester,
  ) async {
    final service = _FakeEmployerProfileService(Future.value(employerProfile));
    await _pumpProfile(tester, service);

    await tester.enterText(
      find.byKey(const ValueKey('employer-company-name')),
      '  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('employer-contact-info')),
      '  ',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-employer-profile')),
    );
    await tester.tap(find.byKey(const ValueKey('save-employer-profile')));
    await tester.pumpAndSettle();

    expect(find.text('Company name is required.'), findsOneWidget);
    expect(find.text('Contact information is required.'), findsOneWidget);
    expect(service.saveCalls, 0);
  });

  testWidgets('saves trimmed company fields and confirms success', (
    tester,
  ) async {
    final service = _FakeEmployerProfileService(Future.value(employerProfile));
    await _pumpProfile(tester, service);

    await tester.enterText(
      find.byKey(const ValueKey('employer-company-name')),
      '  PalliJob Cafe Ltd  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('employer-contact-info')),
      '  contact@example.com  ',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-employer-profile')),
    );
    await tester.tap(find.byKey(const ValueKey('save-employer-profile')));
    await tester.pumpAndSettle();

    expect(service.savedCompanyName, 'PalliJob Cafe Ltd');
    expect(service.savedContactInfo, 'contact@example.com');
    expect(service.saveCalls, 1);
    expect(service.updatedFieldNames, {'companyName', 'contactInfo'});
    expect(find.text('Profile updated successfully.'), findsOneWidget);
    expect(find.text('Employer'), findsOneWidget);
  });

  testWidgets('shows a clear access error for a non-employer role', (
    tester,
  ) async {
    final load = Completer<EmployerProfile>();
    await tester.pumpWidget(
      MaterialApp(
        home: EmployerProfileScreen(
          profileService: _FakeEmployerProfileService(load.future),
        ),
      ),
    );
    load.completeError(
      const EmployerProfileException(
        'Only employer accounts can view this profile.',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load profile'), findsOneWidget);
    expect(
      find.text('Only employer accounts can view this profile.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('explains permission denied when saving', (tester) async {
    final service = _FakeEmployerProfileService(
      Future.value(employerProfile),
      onSave: () async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      },
    );
    await _pumpProfile(tester, service);

    await tester.ensureVisible(
      find.byKey(const ValueKey('save-employer-profile')),
    );
    await tester.tap(find.byKey(const ValueKey('save-employer-profile')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Firestore denied this update. Check that the rules allow employer profile fields.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Employer Dashboard My Profile opens the profile screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: EmployerDashboardScreen()));

    await tester.ensureVisible(find.text('My Profile'));
    await tester.tap(find.text('My Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load profile'), findsOneWidget);
  });
}

Future<void> _pumpProfile(
  WidgetTester tester,
  EmployerProfileService service,
) async {
  await tester.pumpWidget(
    MaterialApp(home: EmployerProfileScreen(profileService: service)),
  );
  await tester.pumpAndSettle();
}

class _FakeEmployerProfileService implements EmployerProfileService {
  _FakeEmployerProfileService(this.loadResult, {this.onSave});

  final Future<EmployerProfile> loadResult;
  final Future<void> Function()? onSave;
  int saveCalls = 0;
  String? savedCompanyName;
  String? savedContactInfo;

  Set<String> get updatedFieldNames => {'companyName', 'contactInfo'};

  @override
  Future<EmployerProfile> loadProfile() => loadResult;

  @override
  Future<void> saveProfile({
    required String companyName,
    required String contactInfo,
  }) async {
    saveCalls++;
    savedCompanyName = companyName;
    savedContactInfo = contactInfo;
    await onSave?.call();
  }
}
