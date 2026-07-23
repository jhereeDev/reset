import '../../features/habits/domain/habit.dart';
import '../../features/habits/domain/habit_entry.dart';
import 'app_date_utils.dart';

/// Streak and day-status rules.
///
/// ## Per-habit streak
/// - Only *scheduled* days count. Non-scheduled days neither extend nor break
///   a streak — they are skipped.
/// - Today never breaks a streak while it is still incomplete (the day isn't
///   over yet); it extends the streak once completed.
/// - Flexible (`timesPerWeek`) habits: every completed day extends the streak.
///   An incomplete day is forgiven when its week met the weekly quota (or is
///   the still-running current week); otherwise the streak ends there.
///
/// ## Overall daily streak
/// A day is *successful* when every habit strictly due that day (daily or
/// weekday schedules) was completed. Days with no due habits are neutral and
/// skipped. Flexible habits can never break a day — they only add completions.
/// The overall streak is the number of consecutive successful days ending
/// today (or yesterday, while today is still in progress).
class StreakResult {
  const StreakResult({required this.current, required this.best});

  final int current;
  final int best;
}

enum DayStatus { complete, partial, missed, future, rest }

abstract final class StreakCalculator {
  /// [entries] maps dateKey -> entry for a single habit.
  static StreakResult habitStreak({
    required Habit habit,
    required Map<String, HabitEntry> entries,
    required DateTime today,
    int weekStartDay = DateTime.monday,
  }) {
    final start = AppDateUtils.dateOnly(habit.startDate);
    final end = AppDateUtils.dateOnly(today);
    if (AppDateUtils.daysBetween(start, end) < 0) {
      return const StreakResult(current: 0, best: 0);
    }

    bool completedOn(DateTime day) =>
        entries[AppDateUtils.dateKey(day)]?.completed ?? false;

    bool weekMetQuota(DateTime day) {
      final weekStart = AppDateUtils.startOfWeek(day, weekStartDay);
      var count = 0;
      for (var i = 0; i < 7; i++) {
        if (completedOn(weekStart.add(Duration(days: i)))) count++;
      }
      return count >= habit.schedule.timesPerWeek;
    }

    final isFlexible = habit.schedule.type == ScheduleType.timesPerWeek;
    final currentWeekStart = AppDateUtils.startOfWeek(end, weekStartDay);

    // Current streak: walk backward from today.
    var current = 0;
    for (
      var day = end;
      AppDateUtils.daysBetween(start, day) >= 0;
      day = day.subtract(const Duration(days: 1))
    ) {
      if (completedOn(day)) {
        if (isFlexible || habit.schedule.isDueOn(day)) current++;
        continue;
      }
      if (AppDateUtils.isSameDay(day, end)) continue; // today still open
      if (isFlexible) {
        final inCurrentWeek = !AppDateUtils.startOfWeek(
          day,
          weekStartDay,
        ).isBefore(currentWeekStart);
        if (inCurrentWeek || weekMetQuota(day)) continue;
        break;
      }
      if (!habit.schedule.isDueOn(day)) continue; // rest day
      break;
    }

    // Best streak: walk forward, tracking the longest run under the same rules.
    var best = 0;
    var run = 0;
    for (
      var day = start;
      AppDateUtils.daysBetween(day, end) >= 0;
      day = day.add(const Duration(days: 1))
    ) {
      if (completedOn(day)) {
        run++;
        if (run > best) best = run;
        continue;
      }
      if (AppDateUtils.isSameDay(day, end)) continue;
      if (isFlexible) {
        final inCurrentWeek = !AppDateUtils.startOfWeek(
          day,
          weekStartDay,
        ).isBefore(currentWeekStart);
        if (inCurrentWeek || weekMetQuota(day)) continue;
        run = 0;
        continue;
      }
      if (!habit.schedule.isDueOn(day)) continue;
      run = 0;
    }
    if (current > best) best = current;

    return StreakResult(current: current, best: best);
  }

  /// Overall streak across all habits.
  ///
  /// [entriesByHabit] maps habitId -> (dateKey -> entry). [habits] should
  /// include archived/paused habits too; a habit only counts on days it was
  /// active and due (status changes are not backdated, so we use the habit's
  /// current status — an accepted MVP simplification).
  static StreakResult overallStreak({
    required List<Habit> habits,
    required Map<String, Map<String, HabitEntry>> entriesByHabit,
    required DateTime today,
  }) {
    final end = AppDateUtils.dateOnly(today);
    final starts = habits
        .map((h) => AppDateUtils.dateOnly(h.startDate))
        .toList(growable: false);
    if (starts.isEmpty) return const StreakResult(current: 0, best: 0);
    var earliest = starts.first;
    for (final s in starts) {
      if (s.isBefore(earliest)) earliest = s;
    }

    bool? daySuccessful(DateTime day) {
      var due = 0;
      var done = 0;
      for (final habit in habits) {
        if (!habit.isDueOn(day)) continue;
        due++;
        final entry = entriesByHabit[habit.id]?[AppDateUtils.dateKey(day)];
        if (entry?.completed ?? false) done++;
      }
      if (due == 0) return null; // neutral day
      return done == due;
    }

    var current = 0;
    for (
      var day = end;
      AppDateUtils.daysBetween(earliest, day) >= 0;
      day = day.subtract(const Duration(days: 1))
    ) {
      final success = daySuccessful(day);
      if (success == null) continue;
      if (success) {
        current++;
        continue;
      }
      if (AppDateUtils.isSameDay(day, end)) continue;
      break;
    }

    var best = 0;
    var run = 0;
    for (
      var day = earliest;
      AppDateUtils.daysBetween(day, end) >= 0;
      day = day.add(const Duration(days: 1))
    ) {
      final success = daySuccessful(day);
      if (success == null) continue;
      if (success) {
        run++;
        if (run > best) best = run;
      } else if (!AppDateUtils.isSameDay(day, end)) {
        run = 0;
      }
    }
    if (current > best) best = current;

    return StreakResult(current: current, best: best);
  }

  /// Status of a calendar day for history views.
  static DayStatus dayStatus({
    required DateTime day,
    required DateTime today,
    required List<Habit> habits,
    required Map<String, Map<String, HabitEntry>> entriesByHabit,
  }) {
    if (AppDateUtils.daysBetween(today, day) > 0) return DayStatus.future;

    var due = 0;
    var done = 0;
    var flexibleDone = 0;
    final key = AppDateUtils.dateKey(day);
    for (final habit in habits) {
      final completed = entriesByHabit[habit.id]?[key]?.completed ?? false;
      if (habit.isDueOn(day)) {
        due++;
        if (completed) done++;
      } else if (completed) {
        flexibleDone++;
      }
    }

    if (due == 0) {
      return flexibleDone > 0 ? DayStatus.complete : DayStatus.rest;
    }
    if (done == due) return DayStatus.complete;
    if (done > 0 || flexibleDone > 0) return DayStatus.partial;
    return DayStatus.missed;
  }
}
