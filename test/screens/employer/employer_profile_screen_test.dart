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

    expect(find.text('프로필을 불러오는 중'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('loads account details and keeps role read-only', (tester) async {
    await _pumpProfile(
      tester,
      _FakeEmployerProfileService(Future.value(employerProfile)),
    );

    expect(find.text('Morgan Employer'), findsOneWidget);
    expect(find.text('morgan@example.com'), findsOneWidget);
    expect(find.text('고용주'), findsOneWidget);
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

    expect(find.text('회사명을 입력해 주세요.'), findsOneWidget);
    expect(find.text('연락처를 입력해 주세요.'), findsOneWidget);
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
    expect(find.text('프로필이 수정되었습니다.'), findsOneWidget);
    expect(find.text('고용주'), findsOneWidget);
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
        '고용주 계정만 이 프로필을 확인할 수 있습니다.',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('프로필을 불러오지 못했습니다'), findsOneWidget);
    expect(
      find.text('고용주 계정만 이 프로필을 확인할 수 있습니다.'),
      findsOneWidget,
    );
    expect(find.text('다시 시도'), findsOneWidget);
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
        '프로필 수정 권한이 없습니다. Firestore 규칙에서 고용주 프로필 수정을 허용하는지 확인해 주세요.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Employer Dashboard My Profile opens the profile screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: EmployerDashboardScreen()));

    await tester.ensureVisible(find.text('내 프로필'));
    await tester.tap(find.text('내 프로필'));
    await tester.pumpAndSettle();

    expect(find.text('프로필을 불러오지 못했습니다'), findsOneWidget);
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
