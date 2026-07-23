/// One habit's logged value for one local calendar day.
///
/// [dateKey] is the canonical `yyyy-MM-dd` local-date key (see AppDateUtils),
/// unique per habit — a day can never have two entries for the same habit.
class HabitEntry {
  const HabitEntry({
    required this.id,
    required this.habitId,
    required this.dateKey,
    required this.value,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String habitId;
  final String dateKey;

  /// Logged amount. Always >= 0; for yes/no habits 0 or 1.
  final double value;

  /// True when [value] reached the habit's target at the time of logging.
  final bool completed;

  final DateTime createdAt;
  final DateTime updatedAt;

  HabitEntry copyWith({double? value, bool? completed, DateTime? updatedAt}) =>
      HabitEntry(
        id: id,
        habitId: habitId,
        dateKey: dateKey,
        value: value ?? this.value,
        completed: completed ?? this.completed,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
