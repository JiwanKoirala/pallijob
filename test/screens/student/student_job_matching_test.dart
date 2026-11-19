import 'package:flutter_test/flutter_test.dart';
import 'package:pallijob/screens/student/student_job_matching.dart';

void main() {
  test('counts matches for all selected preference dimensions', () {
    const preferences = StudentJobPreferences(
      preferredLocation: 'Seoul',
      preferredWorkType: 'Part-time',
      preferredSchedule: 'Weekdays',
    );

    expect(
      countPreferenceMatches(
        preferences: preferences,
        location: ' seoul ',
        workType: 'Part-time',
        schedule: 'Weekdays',
      ),
      3,
    );
  });

  test('counts partial matches and treats missing job values as unknown', () {
    const preferences = StudentJobPreferences(
      preferredLocation: 'Seoul',
      preferredWorkType: 'Full-time',
      preferredSchedule: 'Weekends',
    );

    expect(
      countPreferenceMatches(
        preferences: preferences,
        location: 'Busan',
        workType: null,
        schedule: 'Weekends',
      ),
      1,
    );
  });

  test('counts no matches without hiding or changing a job', () {
    const preferences = StudentJobPreferences(
      preferredLocation: 'Seoul',
      preferredWorkType: 'Full-time',
      preferredSchedule: 'Weekends',
    );

    expect(
      countPreferenceMatches(
        preferences: preferences,
        location: 'Not provided',
        workType: null,
        schedule: null,
      ),
      0,
    );
    expect(
      countPreferenceMatches(
        preferences: const StudentJobPreferences(),
        location: 'Seoul',
        workType: 'Part-time',
        schedule: 'Weekdays',
      ),
      0,
    );
  });
}
