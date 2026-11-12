import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum InAppNotificationRole { student, employer }

enum InAppNotificationType {
  newApplication,
  applicationAccepted,
  applicationRejected,
  newMessage,
}

class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.type,
    required this.applicationId,
    required this.jobTitle,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final InAppNotificationType type;
  final String applicationId;
  final String jobTitle;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  InAppNotification copyWith({DateTime? readAt}) => InAppNotification(
    id: id,
    type: type,
    applicationId: applicationId,
    jobTitle: jobTitle,
    createdAt: createdAt,
    readAt: readAt ?? this.readAt,
  );
}

abstract interface class InAppNotificationsService {
  Future<List<InAppNotification>> loadNotifications(InAppNotificationRole role);

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead(List<String> notificationIds);
}

class FirestoreInAppNotificationsService implements InAppNotificationsService {
  const FirestoreInAppNotificationsService({this.auth, this.firestore});

  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  FirebaseAuth get _firebaseAuth => auth ?? FirebaseAuth.instance;
  FirebaseFirestore get _database => firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<InAppNotification>> loadNotifications(
    InAppNotificationRole role,
  ) async {
    final userId = await _verifiedUserId(role);
    final snapshot = await _database
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return List.unmodifiable(
      snapshot.docs
          .map(_notificationFromDocument)
        .where(
          (notification) =>
              notificationTypeMatchesRole(notification.type, role),
        ),
    );
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const InAppNotificationsException(
        'Sign in to view your notifications.',
      );
    }
    await _database
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'readAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> markAllAsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const InAppNotificationsException(
        'Sign in to view your notifications.',
      );
    }
    if (notificationIds.length > 100) {
      throw const InAppNotificationsException(
        'Refresh notifications before marking them as read.',
      );
    }

    final notifications = _database
        .collection('users')
        .doc(user.uid)
        .collection('notifications');
    final batch = _database.batch();
    for (final notificationId in notificationIds) {
      batch.update(notifications.doc(notificationId), {
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<String> _verifiedUserId(InAppNotificationRole role) async {
    final auth = _firebaseAuth;
    final user = auth.currentUser;
    if (user == null) {
      throw const InAppNotificationsException(
        'Sign in to view your notifications.',
      );
    }
    final profile = await _database.collection('users').doc(user.uid).get();
    final expectedRole = role == InAppNotificationRole.student
        ? 'student'
        : 'employer';
    if (profile.data()?['role'] != expectedRole) {
      throw InAppNotificationsException(
        'Only $expectedRole accounts can view these notifications.',
      );
    }
    if (auth.currentUser?.uid != user.uid) {
      throw const InAppNotificationsException(
        'Your session changed. Please sign in again.',
      );
    }
    return user.uid;
  }

  InAppNotification _notificationFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final type = switch (data['type']) {
      'new_application' => InAppNotificationType.newApplication,
      'application_accepted' => InAppNotificationType.applicationAccepted,
      'application_rejected' => InAppNotificationType.applicationRejected,
      'new_message' => InAppNotificationType.newMessage,
      _ => null,
    };
    final applicationId = data['applicationId'];
    final jobTitle = data['jobTitle'];
    final createdAt = data['createdAt'];
    final readAt = data['readAt'];
    if (type == null ||
        applicationId is! String ||
        applicationId.trim().isEmpty ||
        jobTitle is! String ||
        jobTitle.trim().isEmpty ||
        createdAt is! Timestamp ||
        (readAt != null && readAt is! Timestamp)) {
      throw const FormatException('A notification has invalid fields.');
    }
    return InAppNotification(
      id: document.id,
      type: type,
      applicationId: applicationId,
      jobTitle: jobTitle,
      createdAt: createdAt.toDate(),
      readAt: readAt is Timestamp ? readAt.toDate() : null,
    );
  }

}

bool notificationTypeMatchesRole(
  InAppNotificationType type,
  InAppNotificationRole role,
) {
  return switch ((role, type)) {
    (InAppNotificationRole.student, InAppNotificationType.newMessage) ||
    (InAppNotificationRole.student, InAppNotificationType.applicationAccepted) ||
    (InAppNotificationRole.student, InAppNotificationType.applicationRejected) ||
    (InAppNotificationRole.employer, InAppNotificationType.newMessage) ||
    (InAppNotificationRole.employer, InAppNotificationType.newApplication) =>
      true,
    _ => false,
  };
}

class InAppNotificationsException implements Exception {
  const InAppNotificationsException(this.message);

  final String message;

  @override
  String toString() => message;
}
