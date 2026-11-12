import 'package:pallijob/screens/notifications/in_app_notification_service.dart';

class FakeInAppNotificationsService implements InAppNotificationsService {
  FakeInAppNotificationsService({
    List<InAppNotification> notifications = const [],
    this.onLoad,
    this.onMarkAsRead,
    this.onMarkAllAsRead,
  }) : notifications = List.of(notifications);

  final List<InAppNotification> notifications;
  final Future<List<InAppNotification>> Function(
    InAppNotificationRole role,
    int loadCall,
  )?
  onLoad;
  final Future<void> Function(String notificationId)? onMarkAsRead;
  final Future<void> Function(List<String> notificationIds)? onMarkAllAsRead;
  final List<InAppNotificationRole> requestedRoles = [];
  final List<String> markedRead = [];
  final List<List<String>> markedAllRead = [];
  int loadCalls = 0;

  @override
  Future<List<InAppNotification>> loadNotifications(
    InAppNotificationRole role,
  ) async {
    loadCalls++;
    requestedRoles.add(role);
    final result = await onLoad?.call(role, loadCalls) ?? notifications;
    return List.of(result);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await onMarkAsRead?.call(notificationId);
    markedRead.add(notificationId);
    _markRead([notificationId]);
  }

  @override
  Future<void> markAllAsRead(List<String> notificationIds) async {
    await onMarkAllAsRead?.call(notificationIds);
    markedAllRead.add(List.of(notificationIds));
    _markRead(notificationIds);
  }

  void _markRead(List<String> ids) {
    final readAt = DateTime(2026, 11, 12, 9);
    for (var index = 0; index < notifications.length; index++) {
      if (ids.contains(notifications[index].id)) {
        notifications[index] = notifications[index].copyWith(readAt: readAt);
      }
    }
  }
}
