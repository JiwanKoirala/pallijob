import 'package:flutter/material.dart';

class RoleAwareStrings {
  const RoleAwareStrings({required this.isEmployer});

  final bool isEmployer;

  String text({required String english, required String korean}) {
    return isEmployer ? korean : english;
  }

  String workType(String value) {
    if (!isEmployer) return value;
    return switch (value) {
      'Part-time' => '시간제',
      'Full-time' => '전일제',
      'Temporary/Contract' => '임시/계약직',
      _ => value,
    };
  }

  String schedule(String value) {
    if (!isEmployer) return value;
    return switch (value) {
      'Weekdays' => '평일',
      'Weekends' => '주말',
      'Flexible' => '유연 근무',
      _ => value,
    };
  }

  String mediumDate(BuildContext context, DateTime date) {
    if (isEmployer) return '${date.year}년 ${date.month}월 ${date.day}일';
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  String fullDate(BuildContext context, DateTime date) {
    if (isEmployer) return '${date.year}년 ${date.month}월 ${date.day}일';
    return MaterialLocalizations.of(context).formatFullDate(date);
  }

  String timeOfDay(BuildContext context, DateTime date) {
    if (isEmployer) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(date));
  }
}
