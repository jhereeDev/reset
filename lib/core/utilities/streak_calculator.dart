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

enum DayStatus { complete, partial, missed, future, rest, frozen }

/// Overall streak enriched with the streak-freeze mechanic.
///
/// Every [StreakCalculator.tokenEvery] consecutive successful days earn one
/// freeze token (capped at [StreakCalculator.maxTokens]). When a past due
/// day was missed and a token is available, the token is consumed
/// automatically: the day becomes *frozen* — it doesn't extend the streak,
/// but it doesn't break it either. Supportive by design: one bad day never
/// undoes a good run. Fully derived from history — no stored state.
class OverallStreakState {
  const OverallStreakState({
    required this.current,
    required this.best,
    required this.freezeTokens,
    required this.frozenDayKeys,
  });

  final int current;
  final int best;

  /// Unspent freeze tokens as of today.
  final int freezeTokens;

  /// Days that were saved by a token, as dateKeys.
  final Set<String> frozenDayKeys;

  StreakResult get streak => StreakResult(current: current, best: best);
}

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

  static const tokenEvery = 7;
  static const maxTokens = 3;

  /// Overall streak with the freeze mechanic applied (see
  /// [OverallStreakState]). Single forward replay from the earliest habit
  /// start date; deterministic given the data.
  static OverallStreakState overallStreakWithFreezes({
    required List<Habit> habits,
    required Map<String, Map<String, HabitEntry>> entriesByHabit,
    required DateTime today,
  }) {
    const empty = OverallStreakState(
      current: 0,
      best: 0,
      freezeTokens: 0,
      frozenDayKeys: {},
    );
    final end = AppDateUtils.dateOnly(today);
    if (habits.isEmpty) return empty;
    var earliest = AppDateUtils.dateOnly(habits.first.startDate);
    for (final h in habits) {
      final s = AppDateUtils.dateOnly(h.startDate);
      if (s.isBefore(earliest)) earliest = s;
    }
    if (AppDateUtils.daysBetween(earliest, end) < 0) return empty;

    bool? daySuccessful(DateTime day) {
      var due = 0;
      var done = 0;
      for (final habit in habits) {
        if (!habit.isDueOn(day)) continue;
        due++;
        final entry = entriesByHabit[habit.id]?[AppDateUtils.dateKey(day)];
        if (entry?.completed ?? false) done++;
      }
      if (due == 0) return null;
      return done == due;
    }

    var run = 0;
    var best = 0;
    var tokens = 0;
    var sinceEarn = 0;
    final frozen = <String>{};

    for (
      var day = earliest;
      AppDateUtils.daysBetween(day, end) >= 0;
      day = day.add(const Duration(days: 1))
    ) {
      final success = daySuccessful(day);
      if (success == null) continue; // nothing due — neutral
      if (success) {
        run++;
        if (run > best) best = run;
        sinceEarn++;
        if (sinceEarn == tokenEvery) {
          if (tokens < maxTokens) tokens++;
          sinceEarn = 0;
        }
      } else if (AppDateUtils.isSameDay(day, end)) {
        // Today is still open — never breaks, never costs a token.
      } else if (tokens > 0) {
        tokens--;
        frozen.add(AppDateUtils.dateKey(day));
        // Run survives but doesn't grow; progress toward the next token
        // pauses rather than resetting.
      } else {
        run = 0;
        sinceEarn = 0;
      }
    }

    return OverallStreakState(
      current: run,
      best: best,
      freezeTokens: tokens,
      frozenDayKeys: frozen,
    );
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
