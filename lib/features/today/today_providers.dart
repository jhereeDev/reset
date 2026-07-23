import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utilities/app_date_utils.dart';
import '../../core/utilities/streak_calculator.dart';
import '../habits/domain/habit.dart';
import '../habits/domain/habit_entry.dart';
import '../habits/providers/habit_providers.dart';

/// Habits that should appear on the Today list, in user order.
final todayHabitsProvider = Provider<List<Habit>>((ref) {
  final key = ref.watch(todayKeyProvider);
  final today = AppDateUtils.parseDateKey(key);
  final habits = ref.watch(activeHabitsProvider).value ?? const [];
  return habits.where((h) => h.isTrackedOn(today)).toList();
});

/// dateKey-independent lookup of today's entry per habit.
final todayEntryByHabitProvider = Provider<Map<String, HabitEntry>>((ref) {
  final entries = ref.watch(todayEntriesProvider).value ?? const [];
  return {for (final e in entries) e.habitId: e};
});

class TodayProgress {
  const TodayProgress({required this.total, required this.completed});

  final int total;
  final int completed;

  double get fraction => total == 0 ? 0 : completed / total;

  bool get allDone => total > 0 && completed == total;
}

final todayProgressProvider = Provider<TodayProgress>((ref) {
  final habits = ref.watch(todayHabitsProvider);
  final entries = ref.watch(todayEntryByHabitProvider);
  final completed = habits
      .where((h) => entries[h.id]?.completed ?? false)
      .length;
  return TodayProgress(total: habits.length, completed: completed);
});

/// Overall daily streak with freeze tokens (see OverallStreakState docs).
final overallStreakProvider = Provider<OverallStreakState>((ref) {
  final key = ref.watch(todayKeyProvider);
  final habits = ref.watch(allHabitsProvider).value ?? const [];
  final entriesByHabit = ref.watch(entriesByHabitProvider);
  return StreakCalculator.overallStreakWithFreezes(
    habits: habits,
    entriesByHabit: entriesByHabit,
    today: AppDateUtils.parseDateKey(key),
  );
});

/// Deterministic daily motivational message.
final dailyMotivationProvider = Provider<String>((ref) {
  final key = ref.watch(todayKeyProvider);
  final date = AppDateUtils.parseDateKey(key);
  final dayOfYear = AppDateUtils.daysBetween(DateTime(date.year), date);
  return AppStrings.dailyMotivations[dayOfYear %
      AppStrings.dailyMotivations.length];
});
