import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum JobApplicationStatus {
  canApply,
  unauthenticated,
  studentRoleRequired,
  alreadyApplied,
}

abstract interface class JobApplicationService {
  Future<JobApplicationStatus> getStatus(String jobId);

  Future<void> apply(String jobId);
}

class FirestoreJobApplicationService implements JobApplicationService {
  const FirestoreJobApplicationService();

  // Keep the whitespace definition aligned with Firestore rules.
  static final _nameEdgeWhitespace = RegExp(
    r'^[\u0009-\u000D\u0085\uFEFF\p{Z}]+|[\u0009-\u000D\u0085\uFEFF\p{Z}]+$',
    unicode: true,
  );

  @override
  Future<JobApplicationStatus> getStatus(String jobId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return JobApplicationStatus.unauthenticated;

    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (profile.data()?['role'] != 'student') {
      return JobApplicationStatus.studentRoleRequired;
    }

    final application = await _applicationReference(jobId, user.uid).get();
    return application.exists
        ? JobApplicationStatus.alreadyApplied
        : JobApplicationStatus.canApply;
  }

  @override
  Future<void> apply(String jobId) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      throw const JobApplicationException(
        'Sign in with a student account to apply.',
      );
    }

    final firestore = FirebaseFirestore.instance;
    final profileReference = firestore.collection('users').doc(user.uid);
    final application = _applicationReference(jobId, user.uid);
    final jobReference = firestore.collection('jobs').doc(jobId);
    await firestore.runTransaction((transaction) async {
      final profile = (await transaction.get(profileReference)).data();
      if (profile?['role'] != 'student') {
        throw const JobApplicationException(
          'Only student accounts can apply for jobs.',
        );
      }
      final fullName = profile?['fullName'];
      final applicantName = fullName is String
          ? fullName.replaceAll(_nameEdgeWhitespace, '')
          : '';

      final existingApplication = await transaction.get(application);
      if (existingApplication.exists) {
        throw const JobAlreadyAppliedException();
      }

      final job = await transaction.get(jobReference);
      if (!job.exists) {
        throw const JobApplicationException('This job is no longer available.');
      }
      final employerId = job.data()?['employerId'];
      if (employerId is! String || employerId.trim().isEmpty) {
        throw const JobApplicationException(
          'This job is missing its employer information and cannot accept applications.',
        );
      }
      final jobTitle = job.data()?['title'];
      if (jobTitle is! String || jobTitle.trim().isEmpty) {
        throw const JobApplicationException(
          'This job is missing its title and cannot accept applications.',
        );
      }

      if (auth.currentUser?.uid != user.uid) {
        throw const JobApplicationException(
          'Your session expired. Please sign in again.',
        );
      }

      final notifications = firestore
          .collection('users')
          .doc(employerId)
          .collection('notifications');
      transaction.set(application, {
        'jobId': jobId,
        'studentId': user.uid,
        'employerId': employerId,
        'status': 'pending',
        'dateApplied': FieldValue.serverTimestamp(),
        if (applicantName.isNotEmpty && applicantName.runes.length <= 100)
          'applicantName': applicantName,
      });
      transaction.set(notifications.doc('new-application__${application.id}'), {
        'type': 'new_application',
        'applicationId': application.id,
        'jobTitle': jobTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'readAt': null,
      });
    });
  }

  DocumentReference<Map<String, dynamic>> _applicationReference(
    String jobId,
    String studentId,
  ) {
    return FirebaseFirestore.instance
        .collection('applications')
        .doc('${jobId}_$studentId');
  }
}

class JobApplicationException implements Exception {
  const JobApplicationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class JobAlreadyAppliedException extends JobApplicationException {
  const JobAlreadyAppliedException()
    : super('You have already applied for this job.');
}
