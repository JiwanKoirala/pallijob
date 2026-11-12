import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/notifications/in_app_notification_service.dart';

void main() {
  test('tracks unread and read state without changing event identity', () {
    final unread = InAppNotification(
      id: 'message-event',
      type: InAppNotificationType.newMessage,
      applicationId: 'job-1_student-1',
      jobTitle: 'Cafe Assistant',
      createdAt: DateTime(2026, 11, 12, 9),
      readAt: null,
    );

    final read = unread.copyWith(readAt: DateTime(2026, 11, 12, 10));

    expect(unread.isRead, isFalse);
    expect(read.isRead, isTrue);
    expect(read.id, unread.id);
    expect(read.type, unread.type);
    expect(read.applicationId, unread.applicationId);
    expect(read.createdAt, unread.createdAt);
    expect(read.readAt, DateTime(2026, 11, 12, 10));
  });

  test('filters notification types according to the recipient role', () {
    expect(
      notificationTypeMatchesRole(
        InAppNotificationType.newMessage,
        InAppNotificationRole.student,
      ),
      isTrue,
    );
    expect(
      notificationTypeMatchesRole(
        InAppNotificationType.applicationAccepted,
        InAppNotificationRole.student,
      ),
      isTrue,
    );
    expect(
      notificationTypeMatchesRole(
        InAppNotificationType.applicationRejected,
        InAppNotificationRole.student,
      ),
      isTrue,
    );
    expect(
      notificationTypeMatchesRole(
        InAppNotificationType.newApplication,
        InAppNotificationRole.student,
      ),
      isFalse,
    );
    expect(
      notificationTypeMatchesRole(
        InAppNotificationType.newMessage,
        InAppNotificationRole.employer,
      ),
      isTrue,
    );
    expect(
      notificationTypeMatchesRole(
        InAppNotificationType.newApplication,
        InAppNotificationRole.employer,
      ),
      isTrue,
    );
    expect(
      notificationTypeMatchesRole(
        InAppNotificationType.applicationAccepted,
        InAppNotificationRole.employer,
      ),
      isFalse,
    );
  });
}
