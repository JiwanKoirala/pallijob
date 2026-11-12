import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/employer/employer_dashboard_screen.dart';
import 'package:pallijob/screens/notifications/in_app_notification_service.dart';
import 'package:pallijob/screens/notifications/in_app_notifications_screen.dart';
import 'package:pallijob/screens/student/student_dashboard_screen.dart';

import '../../support/fake_application_chat_service.dart';
import '../../support/fake_in_app_notifications_service.dart';

final _createdAt = DateTime(2026, 11, 12, 9);

InAppNotification _notification({
  required String id,
  required InAppNotificationType type,
  DateTime? readAt,
}) {
  return InAppNotification(
    id: id,
    type: type,
    applicationId: 'job-1_student-1',
    jobTitle: 'Cafe Assistant',
    createdAt: _createdAt,
    readAt: readAt,
  );
}

void main() {
  testWidgets('shows a loading state while notifications load', (tester) async {
    final pending = Completer<List<InAppNotification>>();
    await tester.pumpWidget(
      MaterialApp(
        home: InAppNotificationsScreen(
          role: InAppNotificationRole.student,
          notificationsService: FakeInAppNotificationsService(
            onLoad: (_, _) => pending.future,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Loading notifications'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('You’re all caught up'), findsOneWidget);
  });

  testWidgets('shows an empty state and allows refreshing', (tester) async {
    final service = FakeInAppNotificationsService();
    await _pumpNotifications(tester, InAppNotificationRole.employer, service);

    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(
      find.text('New application and message updates will appear here.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(service.loadCalls, 2);
  });

  testWidgets('shows student employer-message and decision notifications', (
    tester,
  ) async {
    final service = FakeInAppNotificationsService(
      notifications: [
        _notification(
          id: 'message-event',
          type: InAppNotificationType.newMessage,
        ),
        _notification(
          id: 'accepted-event',
          type: InAppNotificationType.applicationAccepted,
          readAt: _createdAt,
        ),
        _notification(
          id: 'rejected-event',
          type: InAppNotificationType.applicationRejected,
        ),
      ],
    );
    await _pumpNotifications(tester, InAppNotificationRole.student, service);

    expect(service.requestedRoles, [InAppNotificationRole.student]);
    expect(find.text('New message from employer'), findsOneWidget);
    expect(find.text('Application accepted'), findsOneWidget);
    expect(find.text('Application rejected'), findsOneWidget);
    expect(find.text('Unread'), findsNWidgets(2));
    expect(find.textContaining('Cafe Assistant'), findsNWidgets(3));
    expect(find.textContaining('job-1_student-1'), findsNWidgets(3));
  });

  testWidgets('shows employer new-application and student-message alerts', (
    tester,
  ) async {
    final service = FakeInAppNotificationsService(
      notifications: [
        _notification(
          id: 'application-event',
          type: InAppNotificationType.newApplication,
        ),
        _notification(
          id: 'message-event',
          type: InAppNotificationType.newMessage,
          readAt: _createdAt,
        ),
      ],
    );
    await _pumpNotifications(tester, InAppNotificationRole.employer, service);

    expect(service.requestedRoles, [InAppNotificationRole.employer]);
    expect(find.text('New job application'), findsOneWidget);
    expect(find.text('New message from student'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);
  });

  testWidgets('marks an unread notification as read before navigating', (
    tester,
  ) async {
    final service = FakeInAppNotificationsService(
      notifications: [
        _notification(
          id: 'message-event',
          type: InAppNotificationType.newMessage,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: InAppNotificationsScreen(
          role: InAppNotificationRole.student,
          notificationsService: service,
          destinationBuilder: (notification) =>
              Scaffold(body: Text('Opened ${notification.applicationId}')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notification-message-event')));
    await tester.pumpAndSettle();

    expect(service.markedRead, ['message-event']);
    expect(find.text('Opened job-1_student-1'), findsOneWidget);
  });

  testWidgets('message notifications open the matching application chat', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InAppNotificationsScreen(
          role: InAppNotificationRole.student,
          notificationsService: FakeInAppNotificationsService(
            notifications: [
              _notification(
                id: 'message-event',
                type: InAppNotificationType.newMessage,
              ),
            ],
          ),
          chatService: FakeApplicationChatService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notification-message-event')));
    await tester.pumpAndSettle();

    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.text('Write a message'), findsOneWidget);
  });

  testWidgets(
    'application notifications open the matching role application screen',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InAppNotificationsScreen(
            role: InAppNotificationRole.employer,
            notificationsService: FakeInAppNotificationsService(
              notifications: [
                _notification(
                  id: 'application-event',
                  type: InAppNotificationType.newApplication,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('notification-application-event')),
      );
      await tester.pumpAndSettle();

      expect(find.text('View Applications'), findsOneWidget);
    },
  );

  testWidgets('marks all visible unread notifications as read', (tester) async {
    final service = FakeInAppNotificationsService(
      notifications: [
        _notification(
          id: 'application-event',
          type: InAppNotificationType.newApplication,
        ),
        _notification(
          id: 'message-event',
          type: InAppNotificationType.newMessage,
        ),
        _notification(
          id: 'read-event',
          type: InAppNotificationType.newApplication,
          readAt: _createdAt,
        ),
      ],
    );
    await _pumpNotifications(tester, InAppNotificationRole.employer, service);

    await tester.tap(find.text('Mark all as read (2)'));
    await tester.pumpAndSettle();

    expect(service.markedAllRead, [
      ['application-event', 'message-event'],
    ]);
    expect(find.text('Unread'), findsNothing);
    expect(find.text('Mark all as read'), findsNothing);
  });

  testWidgets('shows permission-denied errors and retries', (tester) async {
    final denied = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    final service = FakeInAppNotificationsService(
      onLoad: (_, call) => call == 1
          ? Future<List<InAppNotification>>.error(denied)
          : Future.value(const []),
    );
    await _pumpNotifications(tester, InAppNotificationRole.student, service);

    expect(find.text('Could not load notifications'), findsOneWidget);
    expect(
      find.text('You do not have permission to access these notifications.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(service.loadCalls, 2);
  });

  testWidgets('does not navigate when marking a notification read fails', (
    tester,
  ) async {
    final service = FakeInAppNotificationsService(
      notifications: [
        _notification(
          id: 'message-event',
          type: InAppNotificationType.newMessage,
        ),
      ],
      onMarkAsRead: (_) => Future<void>.error(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: InAppNotificationsScreen(
          role: InAppNotificationRole.student,
          notificationsService: service,
          destinationBuilder: (_) =>
              const Scaffold(body: Text('Should not navigate')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notification-message-event')));
    await tester.pumpAndSettle();

    expect(find.text('Should not navigate'), findsNothing);
    expect(find.text('Unread'), findsOneWidget);
    expect(
      find.text('You do not have permission to access these notifications.'),
      findsOneWidget,
    );
  });

  testWidgets('student dashboard opens the student notifications feed', (
    tester,
  ) async {
    final service = FakeInAppNotificationsService();
    await tester.pumpWidget(
      MaterialApp(home: StudentDashboardScreen(notificationsService: service)),
    );

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(service.requestedRoles, [InAppNotificationRole.student]);
  });

  testWidgets('employer dashboard opens the employer notifications feed', (
    tester,
  ) async {
    final service = FakeInAppNotificationsService();
    await tester.pumpWidget(
      MaterialApp(home: EmployerDashboardScreen(notificationsService: service)),
    );

    await tester.ensureVisible(find.text('Notifications'));
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(service.requestedRoles, [InAppNotificationRole.employer]);
  });
}

Future<void> _pumpNotifications(
  WidgetTester tester,
  InAppNotificationRole role,
  InAppNotificationsService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: InAppNotificationsScreen(role: role, notificationsService: service),
    ),
  );
  await tester.pumpAndSettle();
}
