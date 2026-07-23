import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utilities/app_date_utils.dart';
import '../../core/utilities/streak_calculator.dart';
import '../habits/domain/habit.dart';
import '../habits/domain/habit_entry.dart';
import '../habits/providers/habit_providers.dart';
import '../profile/providers/preferences_providers.dart';
import '../today/today_providers.dart';

class DayInfo {
  const DayInfo({required this.date, required this.status});

  final DateTime date;
  final DayStatus status;
}

/// Status for each day of the current week (respecting week-start pref).
/// Days rescued by a streak-freeze token render as [DayStatus.frozen].
final currentWeekDaysProvider = Provider<List<DayInfo>>((ref) {
  final todayKey = ref.watch(todayKeyProvider);
  final today = AppDateUtils.parseDateKey(todayKey);
  final weekStartDay = ref.watch(
    preferencesProvider.select((p) => p.weekStartDay),
  );
  final habits = ref.watch(allHabitsProvider).value ?? const <Habit>[];
  final entriesByHabit = ref.watch(entriesByHabitProvider);
  final frozen = ref.watch(overallStreakProvider).frozenDayKeys;

  final weekStart = AppDateUtils.startOfWeek(today, weekStartDay);
  return [
    for (var i = 0; i < 7; i++)
      DayInfo(
        date: weekStart.add(Duration(days: i)),
        status:
            frozen.contains(
              AppDateUtils.dateKey(weekStart.add(Duration(days: i))),
            )
            ? DayStatus.frozen
            : StreakCalculator.dayStatus(
                day: weekStart.add(Duration(days: i)),
                today: today,
                habits: habits,
                entriesByHabit: entriesByHabit,
              ),
      ),
  ];
});

/// Fraction of due habit-days completed so far this week (0..1).
final weekCompletionProvider = Provider<double>((ref) {
  final todayKey = ref.watch(todayKeyProvider);
  final today = AppDateUtils.parseDateKey(todayKey);
  final weekStartDay = ref.watch(
    preferencesProvider.select((p) => p.weekStartDay),
  );
  final habits = ref.watch(allHabitsProvider).value ?? const <Habit>[];
  final entriesByHabit = ref.watch(entriesByHabitProvider);

  final weekStart = AppDateUtils.startOfWeek(today, weekStartDay);
  var due = 0;
  var done = 0;
  for (var i = 0; i < 7; i++) {
    final day = weekStart.add(Duration(days: i));
    if (AppDateUtils.daysBetween(today, day) > 0) break;
    final key = AppDateUtils.dateKey(day);
    for (final habit in habits) {
      final completed = entriesByHabit[habit.id]?[key]?.completed ?? false;
      if (habit.isDueOn(day)) {
        due++;
        if (completed) done++;
      } else if (completed) {
        // Flexible completions count as bonus wins.
        due++;
        done++;
      }
    }
  }
  return due == 0 ? 0 : done / due;
});

/// Completed habit-day counts per day of the current week, for the bar chart.
final weeklyCompletionCountsProvider = Provider<List<int>>((ref) {
  final days = ref.watch(currentWeekDaysProvider);
  final entriesByHabit = ref.watch(entriesByHabitProvider);
  return [
    for (final day in days)
      entriesByHabit.values
          .where(
            (byDate) =>
                byDate[AppDateUtils.dateKey(day.date)]?.completed ?? false,
          )
          .length,
  ];
});

final totalCompletedActionsProvider = Provider<int>((ref) {
  final entries = ref.watch(allEntriesProvider).value ?? const [];
  return entries.where((e) => e.completed).length;
});

/// Detailed statistics for one habit.
class HabitStats {
  const HabitStats({
    required this.habit,
    required this.streak,
    required this.completionRate,
    required this.completedDays,
    required this.recentDays,
  });

  final Habit habit;
  final StreakResult streak;

  /// Completed scheduled days / scheduled days since start (0..1). For
  /// flexible habits: completed days / expected days (quota × weeks).
  final double completionRate;

  final int completedDays;

  /// Most recent 30 days, oldest first.
  final List<HabitDayInfo> recentDays;
}

class HabitDayInfo {
  const HabitDayInfo({
    required this.date,
    required this.status,
    required this.value,
  });

  final DateTime date;
  final DayStatus status;
  final double value;
}

final habitStatsProvider = Provider.family<HabitStats?, String>((ref, habitId) {
  final habit = ref.watch(habitByIdProvider(habitId));
  if (habit == null) return null;

  final todayKey = ref.watch(todayKeyProvider);
  final today = AppDateUtils.parseDateKey(todayKey);
  final weekStartDay = ref.watch(
    preferencesProvider.select((p) => p.weekStartDay),
  );
  final entries =
      ref.watch(entriesByHabitProvider)[habitId] ??
      const <String, HabitEntry>{};

  final streak = StreakCalculator.habitStreak(
    habit: habit,
    entries: entries,
    today: today,
    weekStartDay: weekStartDay,
  );

  final start = AppDateUtils.dateOnly(habit.startDate);
  final daysSinceStart = AppDateUtils.daysBetween(start, today) + 1;

  var scheduled = 0;
  var completedScheduled = 0;
  var completedTotal = 0;
  if (daysSinceStart > 0) {
    for (var i = 0; i < daysSinceStart; i++) {
      final day = start.add(Duration(days: i));
      final completed = entries[AppDateUtils.dateKey(day)]?.completed ?? false;
      if (completed) completedTotal++;
      if (habit.schedule.isDueOn(day)) {
        scheduled++;
        if (completed) completedScheduled++;
      }
    }
  }

  double completionRate;
  if (habit.schedule.type == ScheduleType.timesPerWeek) {
    final weeks = (daysSinceStart / 7).ceil().clamp(1, 1 << 30);
    final expected = weeks * habit.schedule.timesPerWeek;
    completionRate = expected == 0
        ? 0
        : (completedTotal / expected).clamp(0, 1);
  } else {
    completionRate = scheduled == 0 ? 0 : completedScheduled / scheduled;
  }

  final recentDays = <HabitDayInfo>[];
  for (var i = 29; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    final entry = entries[AppDateUtils.dateKey(day)];
    final DayStatus status;
    if (AppDateUtils.daysBetween(start, day) < 0) {
      status = DayStatus.rest; // before the habit existed
    } else if (entry?.completed ?? false) {
      status = DayStatus.complete;
    } else if ((entry?.value ?? 0) > 0) {
      status = DayStatus.partial;
    } else if (!habit.schedule.isDueOn(day)) {
      status = DayStatus.rest;
    } else {
      // Today renders with a distinct outline in the UI, so an empty today
      // reads as "not yet" rather than "missed".
      status = DayStatus.missed;
    }
    recentDays.add(
      HabitDayInfo(date: day, status: status, value: entry?.value ?? 0),
    );
  }

  return HabitStats(
    habit: habit,
    streak: streak,
    completionRate: completionRate,
    completedDays: completedTotal,
    recentDays: recentDays,
  );
});
