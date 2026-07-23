import '../../../core/utilities/app_date_utils.dart';

enum ResetPlanStatus { active, completed, ended }

/// A time-boxed fresh-start program built from a small set of habits.
class ResetPlan {
  const ResetPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.durationDays,
    required this.startDate,
    required this.habitIds,
    this.status = ResetPlanStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final int durationDays;

  /// Local date (midnight) of day 1.
  final DateTime startDate;
  final List<String> habitIds;
  final ResetPlanStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Last day of the plan (inclusive).
  DateTime get endDate => startDate.add(Duration(days: durationDays - 1));

  /// 1-based day number for [date], clamped to [1, durationDays].
  int dayNumberOn(DateTime date) {
    final raw = AppDateUtils.daysBetween(startDate, date) + 1;
    return raw.clamp(1, durationDays);
  }

  bool isFinishedBy(DateTime date) =>
      AppDateUtils.daysBetween(startDate, date) + 1 > durationDays;

  int remainingDaysOn(DateTime date) =>
      (durationDays - dayNumberOn(date)).clamp(0, durationDays);

  ResetPlan copyWith({ResetPlanStatus? status, DateTime? updatedAt}) =>
      ResetPlan(
        id: id,
        title: title,
        description: description,
        durationDays: durationDays,
        startDate: startDate,
        habitIds: habitIds,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
