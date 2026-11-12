import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF173B27),
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: const Color(0xFFF8FBF8),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh notifications',
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
              title: 'Could not load notifications',
              message: _errorMessage(snapshot.error),
              icon: Icons.cloud_off_outlined,
              action: TextButton(
                onPressed: _refresh,
                child: const Text('Retry'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _NotificationsState(
              loading: true,
              title: 'Loading notifications',
              message: 'Please wait while we load your notifications.',
            );
          }

          final notifications = snapshot.data ?? const <InAppNotification>[];
          _loadedNotifications = List<InAppNotification>.of(notifications);
          if (notifications.isEmpty) {
            return _NotificationsState(
              title: 'You’re all caught up',
              message: 'New application and message updates will appear here.',
              icon: Icons.notifications_none_rounded,
              action: TextButton(
                onPressed: _refresh,
                child: const Text('Refresh'),
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
                          ? const Text('Marking as read…')
                          : Text('Mark all as read (${unread.length})'),
                    ),
                  );
                }
                final notification =
                    notifications[index - (unread.isEmpty ? 0 : 1)];
                return _NotificationCard(
                  notification: notification,
                  role: widget.role,
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
      ..showSnackBar(SnackBar(content: Text(_errorMessage(error))));
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.role,
    required this.isUpdating,
    required this.onTap,
  });

  final InAppNotification notification;
  final InAppNotificationRole role;
  final bool isUpdating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = _notificationTitle(notification.type, role);
    final time = MaterialLocalizations.of(context)
        .formatFullDate(notification.createdAt.toLocal());
    final timeOfDay = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(notification.createdAt.toLocal()));

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
                        if (!notification.isRead) const _UnreadIndicator(),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${notification.jobTitle} · Application ${notification.applicationId}',
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
  const _UnreadIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Unread',
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
) {
  return switch (type) {
    InAppNotificationType.newApplication => 'New job application',
    InAppNotificationType.applicationAccepted => 'Application accepted',
    InAppNotificationType.applicationRejected => 'Application rejected',
    InAppNotificationType.newMessage =>
      role == InAppNotificationRole.student
          ? 'New message from employer'
          : 'New message from student',
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

String _errorMessage(Object? error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'You do not have permission to access these notifications.';
  }
  if (error is InAppNotificationsException) return error.message;
  if (error is FirebaseException) {
    return 'A Firebase error occurred. Please check your connection and try again.';
  }
  return 'Could not load notifications. Please try again.';
}
