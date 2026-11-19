import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const jobWorkTypes = <String>['Part-time', 'Full-time', 'Temporary/Contract'];
const jobSchedules = <String>['Weekdays', 'Weekends', 'Flexible'];

class StudentJobPreferences {
  const StudentJobPreferences({
    this.preferredLocation,
    this.preferredWorkType,
    this.preferredSchedule,
  });

  final String? preferredLocation;
  final String? preferredWorkType;
  final String? preferredSchedule;

  int get selectedCount => [
    preferredLocation,
    preferredWorkType,
    preferredSchedule,
  ].where((value) => value != null && value.trim().isNotEmpty).length;

  bool get isEmpty => selectedCount == 0;
}

int countPreferenceMatches({
  required StudentJobPreferences preferences,
  required String location,
  required String? workType,
  required String? schedule,
}) {
  var matches = 0;
  final preferredLocation = preferences.preferredLocation?.trim();
  final jobLocation = location.trim();
  if (preferredLocation != null &&
      preferredLocation.isNotEmpty &&
      jobLocation.isNotEmpty &&
      jobLocation.toLowerCase() != 'not provided' &&
      preferredLocation.toLowerCase() == jobLocation.toLowerCase()) {
    matches++;
  }

  if (preferences.preferredWorkType != null &&
      workType != null &&
      preferences.preferredWorkType == workType) {
    matches++;
  }
  if (preferences.preferredSchedule != null &&
      schedule != null &&
      preferences.preferredSchedule == schedule) {
    matches++;
  }
  return matches;
}

abstract interface class StudentJobPreferencesService {
  Future<StudentJobPreferences> loadPreferences();

  Future<void> savePreferences(StudentJobPreferences preferences);
}

class FirestoreStudentJobPreferencesService
    implements StudentJobPreferencesService {
  const FirestoreStudentJobPreferencesService();

  @override
  Future<StudentJobPreferences> loadPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const StudentJobPreferencesException(
        'Sign in with a student account to load matching preferences.',
      );
    }

    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (profile.data()?['role'] != 'student') {
      throw const StudentJobPreferencesException(
        'Only student accounts can use job matching preferences.',
      );
    }
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw const StudentJobPreferencesException(
        'Your session changed. Please sign in again.',
      );
    }

    final data = profile.data()!;
    final workType = _optionalString(data['preferredWorkType']);
    final schedule = _optionalString(data['preferredSchedule']);
    return StudentJobPreferences(
      preferredLocation: _optionalString(data['preferredLocation']),
      preferredWorkType: jobWorkTypes.contains(workType) ? workType : null,
      preferredSchedule: jobSchedules.contains(schedule) ? schedule : null,
    );
  }

  @override
  Future<void> savePreferences(StudentJobPreferences preferences) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      throw const StudentJobPreferencesException(
        'Sign in with a student account to save matching preferences.',
      );
    }
    if (preferences.preferredWorkType != null &&
        !jobWorkTypes.contains(preferences.preferredWorkType)) {
      throw const StudentJobPreferencesException(
        'Choose a supported work type.',
      );
    }
    if (preferences.preferredSchedule != null &&
        !jobSchedules.contains(preferences.preferredSchedule)) {
      throw const StudentJobPreferencesException(
        'Choose a supported schedule.',
      );
    }

    final profileReference = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final profile = await profileReference.get();
    if (profile.data()?['role'] != 'student') {
      throw const StudentJobPreferencesException(
        'Only student accounts can edit job matching preferences.',
      );
    }
    if (auth.currentUser?.uid != user.uid) {
      throw const StudentJobPreferencesException(
        'Your session changed. Please sign in again.',
      );
    }

    await profileReference.update({
      'preferredLocation': _optionalValue(preferences.preferredLocation),
      'preferredWorkType': _optionalValue(preferences.preferredWorkType),
      'preferredSchedule': _optionalValue(preferences.preferredSchedule),
    });
  }

  static String? _optionalString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static Object _optionalValue(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? FieldValue.delete() : trimmed;
  }
}

class StudentJobPreferencesException implements Exception {
  const StudentJobPreferencesException(this.message);

  final String message;

  @override
  String toString() => message;
}
