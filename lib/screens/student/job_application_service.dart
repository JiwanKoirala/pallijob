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

    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (profile.data()?['role'] != 'student') {
      throw const JobApplicationException(
        'Only student accounts can apply for jobs.',
      );
    }

    if (auth.currentUser?.uid != user.uid) {
      throw const JobApplicationException(
        'Your session expired. Please sign in again.',
      );
    }

    final application = _applicationReference(jobId, user.uid);
    final jobReference = FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
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

      transaction.set(application, {
        'jobId': jobId,
        'studentId': user.uid,
        'employerId': employerId,
        'status': 'pending',
        'dateApplied': FieldValue.serverTimestamp(),
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
