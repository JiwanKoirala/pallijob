import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pallijob/l10n/role_aware_strings.dart';
import 'package:pallijob/screens/chat/application_chat_screen.dart';
import 'package:pallijob/screens/employer/employer_applications_screen.dart';
import 'package:pallijob/screens/notifications/in_app_notification_service.dart';
import 'package:pallijob/screens/student/student_applications_screen.dart';

typedef NotificationDestinationBuilder = Widget Function(
  InAppNotification notification,
);

class InAppNotificationsScreen extends StatefulWidget {
  const InAppNotificationsScreen({
    required this.role,
    super.key,
    this.notificationsService = const FirestoreInAppNotificationsService(),
    this.chatService,
    this.destinationBuilder,
  });

  final InAppNotificationRole role;
  final InAppNotificationsService notificationsService;
  final ApplicationChatService? chatService;
  final NotificationDestinationBuilder? destinationBuilder;

  @override
  State<InAppNotificationsScreen> createState() =>
      _InAppNotificationsScreenState();
}

class _InAppNotificationsScreenState extends State<InAppNotificationsScreen> {
  late Future<List<InAppNotification>> _notificationsFuture;
  final Set<String> _updatingIds = {};
  bool _isMarkingAll = false;

  RoleAwareStrings get _notificationStrings => RoleAwareStrings(
    isEmployer: widget.role == InAppNotificationRole.employer,
  );

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final strings = _notificationStrings;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: Text(
          strings.text(english: 'Notifications', korean: '알림'),
          style: TextStyle(
            color: Color(0xFF173B27),
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: const Color(0xFFF8FBF8),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: strings.text(
              english: 'Refresh notifications',
              korean: '알림 새로고침',
            ),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<InAppNotification>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _NotificationsState(
              title: strings.text(
                english: 'Could not load notifications',
                korean: '알림을 불러오지 못했습니다',
              ),
              message: _errorMessage(snapshot.error, strings),
              icon: Icons.cloud_off_outlined,
              action: TextButton(
                onPressed: _refresh,
                child: Text(strings.text(english: 'Retry', korean: '다시 시도')),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _NotificationsState(
              loading: true,
              title: strings.text(
                english: 'Loading notifications',
                korean: '알림을 불러오는 중',
              ),
              message: strings.text(
                english: 'Please wait while we load your notifications.',
                korean: '알림을 불러오고 있습니다.',
              ),
            );
          }

          final notifications = snapshot.data ?? const <InAppNotification>[];
          _loadedNotifications = List<InAppNotification>.of(notifications);
          if (notifications.isEmpty) {
            return _NotificationsState(
              title: strings.text(
                english: 'You’re all caught up',
                korean: '새로운 알림이 없습니다',
              ),
              message: strings.text(
                english:
                    'New application and message updates will appear here.',
                korean: '새 지원서와 메시지 알림이 여기에 표시됩니다.',
              ),
              icon: Icons.notifications_none_rounded,
              action: TextButton(
                onPressed: _refresh,
                child: Text(strings.text(english: 'Refresh', korean: '새로고침')),
              ),
            );
          }

          final unread = notifications.where((item) => !item.isRead).toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: notifications.length + (unread.isEmpty ? 0 : 1),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (unread.isNotEmpty && index == 0) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isMarkingAll
                          ? null
                          : () => _markAllAsRead(unread),
                      child: _isMarkingAll
                          ? Text(
                              strings.text(
                                english: 'Marking as read…',
                                korean: '읽음으로 표시 중…',
                              ),
                            )
                          : Text(
                              strings.text(
                                english: 'Mark all as read (${unread.length})',
                                korean: '모두 읽음으로 표시 (${unread.length})',
                              ),
                            ),
                    ),
                  );
                }
                final notification =
                    notifications[index - (unread.isEmpty ? 0 : 1)];
                return _NotificationCard(
                  notification: notification,
                  role: widget.role,
                  strings: strings,
                  isUpdating: _updatingIds.contains(notification.id),
                  onTap: () => _openNotification(notification),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<List<InAppNotification>> _loadNotifications() =>
      widget.notificationsService.loadNotifications(widget.role);

  Future<void> _refresh() async {
    final future = _loadNotifications();
    setState(() {
      _notificationsFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder renders the failure state for the refreshed request.
    }
  }

  Future<void> _markAllAsRead(List<InAppNotification> unread) async {
    if (_isMarkingAll || unread.isEmpty) return;
    setState(() => _isMarkingAll = true);
    try {
      await widget.notificationsService.markAllAsRead(
        unread.map((notification) => notification.id).toList(),
      );
      if (!mounted) return;
      final readAt = DateTime.now();
      setState(() {
        _notificationsFuture = Future.value(
          unread.fold<List<InAppNotification>>(_currentNotifications(), (
            notifications,
            notification,
          ) {
            final index = notifications.indexWhere(
              (item) => item.id == notification.id,
            );
            if (index >= 0) {
              notifications[index] = notifications[index].copyWith(
                readAt: readAt,
              );
            }
            return notifications;
          }),
        );
      });
    } catch (error) {
      if (mounted) _showReadError(error);
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  Future<void> _openNotification(InAppNotification notification) async {
    if (_updatingIds.contains(notification.id)) return;
    if (!notification.isRead) {
      setState(() => _updatingIds.add(notification.id));
      try {
        await widget.notificationsService.markAsRead(notification.id);
        if (!mounted) return;
        final current = _currentNotifications();
        final index = current.indexWhere((item) => item.id == notification.id);
        if (index >= 0) {
          current[index] = current[index].copyWith(readAt: DateTime.now());
        }
        setState(() {
          _notificationsFuture = Future.value(current);
        });
      } catch (error) {
        if (mounted) _showReadError(error);
        return;
      } finally {
        if (mounted) setState(() => _updatingIds.remove(notification.id));
      }
    }

    if (!mounted) return;
    final destination =
        widget.destinationBuilder?.call(notification) ??
        _destinationFor(notification);
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => destination));
  }

  Widget _destinationFor(InAppNotification notification) {
    if (notification.type == InAppNotificationType.newMessage) {
      return ApplicationChatScreen(
        applicationId: notification.applicationId,
        uiRole: widget.role == InAppNotificationRole.student
            ? ChatParticipantRole.student
            : ChatParticipantRole.employer,
        chatService:
            widget.chatService ?? const FirestoreApplicationChatService(),
      );
    }
    return widget.role == InAppNotificationRole.student
        ? const StudentApplicationsScreen()
        : const EmployerApplicationsScreen();
  }

  List<InAppNotification> _currentNotifications() {
    return List<InAppNotification>.of(_loadedNotifications);
  }

  List<InAppNotification> _loadedNotifications = [];

  void _showReadError(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(_errorMessage(error, _notificationStrings))),
      );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.role,
    required this.strings,
    required this.isUpdating,
    required this.onTap,
  });

  final InAppNotification notification;
  final InAppNotificationRole role;
  final RoleAwareStrings strings;
  final bool isUpdating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = _notificationTitle(notification.type, role, strings);
    final localTime = notification.createdAt.toLocal();
    final time = strings.fullDate(context, localTime);
    final timeOfDay = strings.timeOfDay(context, localTime);

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: notification.isRead
              ? const Color(0xFFE5EEE7)
              : const Color(0xFF9BC8A8),
        ),
      ),
      child: InkWell(
        key: ValueKey('notification-${notification.id}'),
        onTap: isUpdating ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _notificationIcon(notification.type),
                color: const Color(0xFF247545),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: const Color(0xFF173B27),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (!notification.isRead)
                          _UnreadIndicator(
                            label: strings.text(
                              english: 'Unread',
                              korean: '읽지 않음',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      strings.text(
                        english:
                            '${notification.jobTitle} · Application ${notification.applicationId}',
                        korean:
                            '${notification.jobTitle} · 지원서 ${notification.applicationId}',
                      ),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFF647369)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$time · $timeOfDay',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: const Color(0xFF647369)),
                    ),
                  ],
                ),
              ),
              if (isUpdating) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadIndicator extends StatelessWidget {
  const _UnreadIndicator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Color(0xFF247545),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NotificationsState extends StatelessWidget {
  const _NotificationsState({
    required this.title,
    required this.message,
    this.icon,
    this.loading = false,
    this.action,
  });

  final String title;
  final String message;
  final IconData? icon;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const CircularProgressIndicator(color: Color(0xFF247545))
            else
              Icon(icon, color: const Color(0xFF247545), size: 42),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF173B27),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

String _notificationTitle(
  InAppNotificationType type,
  InAppNotificationRole role,
  RoleAwareStrings strings,
) {
  return switch (type) {
    InAppNotificationType.newApplication => strings.text(
      english: 'New job application',
      korean: '새로운 채용 지원서',
    ),
    InAppNotificationType.applicationAccepted => strings.text(
      english: 'Application accepted',
      korean: '지원서가 수락되었습니다',
    ),
    InAppNotificationType.applicationRejected => strings.text(
      english: 'Application rejected',
      korean: '지원서가 거절되었습니다',
    ),
    InAppNotificationType.newMessage =>
      role == InAppNotificationRole.student
          ? strings.text(
              english: 'New message from employer',
              korean: '고용주에게 새 메시지가 왔습니다',
            )
          : strings.text(
              english: 'New message from student',
              korean: '학생에게 새 메시지가 왔습니다',
            ),
  };
}

IconData _notificationIcon(InAppNotificationType type) {
  return switch (type) {
    InAppNotificationType.newApplication => Icons.assignment_outlined,
    InAppNotificationType.applicationAccepted => Icons.check_circle_outline,
    InAppNotificationType.applicationRejected => Icons.highlight_off_outlined,
    InAppNotificationType.newMessage => Icons.chat_bubble_outline_rounded,
  };
}

String _errorMessage(Object? error, RoleAwareStrings strings) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return strings.text(
      english: 'You do not have permission to access these notifications.',
      korean: '알림을 확인할 권한이 없습니다.',
    );
  }
  if (error is InAppNotificationsException) {
    return strings.text(english: error.message, korean: error.koreanMessage);
  }
  if (error is FirebaseException) {
    return strings.text(
      english: 'A Firebase error occurred. Please check your connection and try again.',
      korean: 'Firebase 오류가 발생했습니다. 네트워크를 확인한 후 다시 시도해 주세요.',
    );
  }
  return strings.text(
    english: 'Could not load notifications. Please try again.',
    korean: '알림을 불러오지 못했습니다. 다시 시도해 주세요.',
  );
}
