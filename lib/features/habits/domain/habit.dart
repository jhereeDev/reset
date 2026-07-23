import 'dart:ui';

import '../../../core/theme/app_colors.dart';
import '../../../core/utilities/app_date_utils.dart';

enum HabitCategory {
  fitness('Fitness'),
  health('Health'),
  mind('Mind'),
  discipline('Discipline'),
  productivity('Productivity'),
  personalCare('Personal care');

  const HabitCategory(this.label);

  final String label;

  Color get color => switch (this) {
    HabitCategory.fitness => AppColors.fitness,
    HabitCategory.health => AppColors.health,
    HabitCategory.mind => AppColors.mind,
    HabitCategory.discipline => AppColors.discipline,
    HabitCategory.productivity => AppColors.productivity,
    HabitCategory.personalCare => AppColors.personalCare,
  };
}

enum TrackingType {
  yesNo('Yes / no', ''),
  count('Count', 'reps'),
  duration('Duration', 'min'),
  steps('Steps', 'steps'),
  pages('Pages', 'pages'),
  chapters('Chapters', 'chapters'),
  servings('Servings', 'servings'),
  custom('Custom unit', '');

  const TrackingType(this.label, this.defaultUnit);

  final String label;
  final String defaultUnit;

  bool get isBinary => this == TrackingType.yesNo;

  /// Sensible step for the quick-add button, given a target.
  double quickIncrement(double target) => switch (this) {
    TrackingType.yesNo => 1,
    TrackingType.steps => 500,
    TrackingType.duration => 5,
    TrackingType.count => target >= 50 ? 10 : (target >= 10 ? 5 : 1),
    _ => 1,
  };
}

/// Singular forms of the built-in plural units, shown when the value is 1
/// ("1 chapter", not "1 chapters"). Unknown/custom units pass through as-is —
/// guessing a singular for arbitrary user text would mangle words like
/// "glasses" → "glasse".
const Map<String, String> _singularUnits = {
  'reps': 'rep',
  'steps': 'step',
  'pages': 'page',
  'chapters': 'chapter',
  'servings': 'serving',
  'episodes': 'episode',
  'glasses': 'glass',
};

String pluralizedUnit(String unit, double value) =>
    value == 1 ? (_singularUnits[unit] ?? unit) : unit;

enum ScheduleType { daily, weekdays, timesPerWeek }

enum HabitStatus { active, paused, archived }

/// When a habit is expected to be done.
///
/// - [ScheduleType.daily]: due every day.
/// - [ScheduleType.weekdays]: due on [weekdays] (DateTime.monday..sunday).
/// - [ScheduleType.timesPerWeek]: flexible — the user picks which days; the
///   weekly quota is [timesPerWeek]. Flexible habits are never "due" on a
///   specific day, so they cannot cause a missed day (see StreakCalculator).
class HabitSchedule {
  const HabitSchedule.daily()
    : type = ScheduleType.daily,
      weekdays = const {},
      timesPerWeek = 0;

  const HabitSchedule.onWeekdays(this.weekdays)
    : type = ScheduleType.weekdays,
      timesPerWeek = 0;

  const HabitSchedule.perWeek(this.timesPerWeek)
    : type = ScheduleType.timesPerWeek,
      weekdays = const {};

  const HabitSchedule({
    required this.type,
    this.weekdays = const {},
    this.timesPerWeek = 0,
  });

  final ScheduleType type;

  /// DateTime.monday (1) .. DateTime.sunday (7).
  final Set<int> weekdays;

  final int timesPerWeek;

  /// Whether the habit is strictly scheduled (due) on [date].
  bool isDueOn(DateTime date) => switch (type) {
    ScheduleType.daily => true,
    ScheduleType.weekdays => weekdays.contains(date.weekday),
    ScheduleType.timesPerWeek => false,
  };

  /// Whether the habit should appear in the Today list on [date].
  /// Flexible habits always appear so the user can log them any day.
  bool appearsOn(DateTime date) =>
      type == ScheduleType.timesPerWeek || isDueOn(date);

  String describe() => switch (type) {
    ScheduleType.daily => 'Every day',
    ScheduleType.weekdays =>
      weekdays.length == 7
          ? 'Every day'
          : (List<int>.from(weekdays)..sort())
                .map(
                  (d) => const [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ][d - 1],
                )
                .join(', '),
    ScheduleType.timesPerWeek => '$timesPerWeek× per week',
  };
}

class Habit {
  const Habit({
    required this.id,
    required this.name,
    this.description = '',
    required this.category,
    required this.iconId,
    required this.colorValue,
    required this.trackingType,
    required this.targetValue,
    required this.unit,
    required this.schedule,
    this.reminderMinutes,
    required this.startDate,
    this.status = HabitStatus.active,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final HabitCategory category;
  final String iconId;
  final int colorValue;
  final TrackingType trackingType;
  final double targetValue;
  final String unit;
  final HabitSchedule schedule;

  /// Reminder time as minutes since midnight, or null for no reminder.
  final int? reminderMinutes;

  /// Local date (midnight) the habit starts counting from.
  final DateTime startDate;

  final HabitStatus status;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Color get color => Color(colorValue);

  bool get isActive => status == HabitStatus.active;

  /// Active on [date]: started, not paused/archived, and shown that day.
  bool isTrackedOn(DateTime date) =>
      isActive &&
      AppDateUtils.daysBetween(startDate, date) >= 0 &&
      schedule.appearsOn(date);

  bool isDueOn(DateTime date) =>
      isActive &&
      AppDateUtils.daysBetween(startDate, date) >= 0 &&
      schedule.isDueOn(date);

  String formatValue(double value) {
    if (trackingType.isBinary) return value >= 1 ? 'Done' : 'Not yet';
    final v = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return v;
  }

  /// The unit label appropriate for [value] ("chapter" vs "chapters").
  String unitFor(double value) => pluralizedUnit(unit, value);

  String get targetLabel => trackingType.isBinary
      ? 'Complete once'
      : '${formatValue(targetValue)} ${unitFor(targetValue)}';

  Habit copyWith({
    String? name,
    String? description,
    HabitCategory? category,
    String? iconId,
    int? colorValue,
    TrackingType? trackingType,
    double? targetValue,
    String? unit,
    HabitSchedule? schedule,
    int? Function()? reminderMinutes,
    DateTime? startDate,
    HabitStatus? status,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      iconId: iconId ?? this.iconId,
      colorValue: colorValue ?? this.colorValue,
      trackingType: trackingType ?? this.trackingType,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      schedule: schedule ?? this.schedule,
      reminderMinutes: reminderMinutes != null
          ? reminderMinutes()
          : this.reminderMinutes,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
