import 'package:flutter_test/flutter_test.dart';
import 'package:reset/core/utilities/app_date_utils.dart';
import 'package:reset/core/utilities/streak_calculator.dart';
import 'package:reset/features/habits/domain/habit.dart';
import 'package:reset/features/habits/domain/habit_entry.dart';

Habit makeHabit({
  String id = 'h1',
  HabitSchedule schedule = const HabitSchedule.daily(),
  double target = 1,
  DateTime? startDate,
}) {
  final now = DateTime(2026, 7, 1);
  return Habit(
    id: id,
    name: 'Test',
    category: HabitCategory.fitness,
    iconId: 'star',
    colorValue: 0xFF000000,
    trackingType: TrackingType.count,
    targetValue: target,
    unit: 'reps',
    schedule: schedule,
    startDate: startDate ?? DateTime(2026, 7, 1),
    createdAt: now,
    updatedAt: now,
  );
}

HabitEntry entry(String habitId, DateTime day, double value, bool completed) =>
    HabitEntry(
      id: '$habitId-${AppDateUtils.dateKey(day)}',
      habitId: habitId,
      dateKey: AppDateUtils.dateKey(day),
      value: value,
      completed: completed,
      createdAt: day,
      updatedAt: day,
    );

Map<String, HabitEntry> completedOn(String habitId, List<DateTime> days) => {
  for (final d in days) AppDateUtils.dateKey(d): entry(habitId, d, 1, true),
};

void main() {
  group('habit streak — daily schedule', () {
    test('counts consecutive completed days ending today', () {
      final habit = makeHabit();
      final today = DateTime(2026, 7, 10);
      final entries = completedOn('h1', [
        DateTime(2026, 7, 8),
        DateTime(2026, 7, 9),
        DateTime(2026, 7, 10),
      ]);
      final result = StreakCalculator.habitStreak(
        habit: habit,
        entries: entries,
        today: today,
      );
      expect(result.current, 3);
      expect(result.best, 3);
    });

    test('incomplete today does not break the streak', () {
      final habit = makeHabit();
      final today = DateTime(2026, 7, 10);
      final entries = completedOn('h1', [
        DateTime(2026, 7, 8),
        DateTime(2026, 7, 9),
      ]);
      final result = StreakCalculator.habitStreak(
        habit: habit,
        entries: entries,
        today: today,
      );
      expect(result.current, 2);
    });

    test('a missed past day breaks the current streak', () {
      final habit = makeHabit();
      final today = DateTime(2026, 7, 10);
      final entries = completedOn('h1', [
        DateTime(2026, 7, 5),
        DateTime(2026, 7, 6),
        DateTime(2026, 7, 7),
        // 8th missed
        DateTime(2026, 7, 9),
        DateTime(2026, 7, 10),
      ]);
      final result = StreakCalculator.habitStreak(
        habit: habit,
        entries: entries,
        today: today,
      );
      expect(result.current, 2);
      expect(result.best, 3);
    });
  });

  group('habit streak — weekday schedule', () {
    test('non-scheduled days do not break the streak', () {
      // Mon/Wed/Fri habit. 2026-07-06 is a Monday.
      final habit = makeHabit(
        schedule: const HabitSchedule.onWeekdays({
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        }),
      );
      final today = DateTime(2026, 7, 13); // Monday
      final entries = completedOn('h1', [
        DateTime(2026, 7, 6), // Mon
        DateTime(2026, 7, 8), // Wed
        DateTime(2026, 7, 10), // Fri
        DateTime(2026, 7, 13), // Mon
      ]);
      final result = StreakCalculator.habitStreak(
        habit: habit,
        entries: entries,
        today: today,
      );
      expect(result.current, 4);
    });

    test('a missed scheduled day breaks the streak', () {
      final habit = makeHabit(
        schedule: const HabitSchedule.onWeekdays({
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        }),
      );
      final today = DateTime(2026, 7, 13); // Monday
      final entries = completedOn('h1', [
        DateTime(2026, 7, 6), // Mon
        // Wed 7/8 missed
        DateTime(2026, 7, 10), // Fri
        DateTime(2026, 7, 13), // Mon
      ]);
      final result = StreakCalculator.habitStreak(
        habit: habit,
        entries: entries,
        today: today,
      );
      expect(result.current, 2);
    });
  });

  group('habit streak — times per week', () {
    test('gap days inside a quota-met week do not break the streak', () {
      final habit = makeHabit(
        schedule: const HabitSchedule.perWeek(3),
        startDate: DateTime(2026, 6, 22),
      );
      // Week of Mon 2026-06-29: completed Mon/Wed/Fri (quota 3 met).
      // Current week (Mon 7/6): completed Mon 7/6, today Tue 7/7.
      final today = DateTime(2026, 7, 7);
      final entries = completedOn('h1', [
        DateTime(2026, 6, 29),
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 3),
        DateTime(2026, 7, 6),
      ]);
      final result = StreakCalculator.habitStreak(
        habit: habit,
        entries: entries,
        today: today,
        weekStartDay: DateTime.monday,
      );
      expect(result.current, 4);
    });

    test('a week that failed its quota ends the streak', () {
      final habit = makeHabit(
        schedule: const HabitSchedule.perWeek(3),
        startDate: DateTime(2026, 6, 22),
      );
      // Week of 6/22: only 1 completion (quota failed).
      // Week of 6/29 onward: full completions.
      final today = DateTime(2026, 7, 2);
      final entries = completedOn('h1', [
        DateTime(2026, 6, 24),
        DateTime(2026, 6, 29),
        DateTime(2026, 6, 30),
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 2),
      ]);
      final result = StreakCalculator.habitStreak(
        habit: habit,
        entries: entries,
        today: today,
        weekStartDay: DateTime.monday,
      );
      expect(result.current, 4);
    });
  });

  group('overall streak', () {
    test('all due habits complete extends; flexible habits cannot break', () {
      final daily = makeHabit(id: 'daily');
      final flexible = makeHabit(
        id: 'flex',
        schedule: const HabitSchedule.perWeek(2),
      );
      final today = DateTime(2026, 7, 10);
      final entriesByHabit = {
        'daily': completedOn('daily', [
          DateTime(2026, 7, 8),
          DateTime(2026, 7, 9),
          DateTime(2026, 7, 10),
        ]),
        // Flexible habit has no completions at all — must not break days.
        'flex': <String, HabitEntry>{},
      };
      final result = StreakCalculator.overallStreak(
        habits: [daily, flexible],
        entriesByHabit: entriesByHabit,
        today: today,
      );
      expect(result.current, 3);
    });

    test('one incomplete due habit breaks the day', () {
      final a = makeHabit(id: 'a');
      final b = makeHabit(id: 'b');
      final today = DateTime(2026, 7, 10);
      final entriesByHabit = {
        'a': completedOn('a', [DateTime(2026, 7, 9), DateTime(2026, 7, 10)]),
        'b': completedOn('b', [DateTime(2026, 7, 10)]), // missed the 9th
      };
      final result = StreakCalculator.overallStreak(
        habits: [a, b],
        entriesByHabit: entriesByHabit,
        today: today,
      );
      expect(result.current, 1);
    });
  });

  group('day status', () {
    test('distinguishes complete, partial, missed, future', () {
      final a = makeHabit(id: 'a');
      final b = makeHabit(id: 'b');
      final today = DateTime(2026, 7, 10);
      final entriesByHabit = {
        'a': completedOn('a', [DateTime(2026, 7, 9), DateTime(2026, 7, 8)]),
        'b': completedOn('b', [DateTime(2026, 7, 8)]),
      };

      DayStatus statusOn(DateTime day) => StreakCalculator.dayStatus(
        day: day,
        today: today,
        habits: [a, b],
        entriesByHabit: entriesByHabit,
      );

      expect(statusOn(DateTime(2026, 7, 8)), DayStatus.complete);
      expect(statusOn(DateTime(2026, 7, 9)), DayStatus.partial);
      expect(statusOn(DateTime(2026, 7, 7)), DayStatus.missed);
      expect(statusOn(DateTime(2026, 7, 11)), DayStatus.future);
    });
  });

  group('schedule', () {
    test('isDueOn respects each schedule type', () {
      const daily = HabitSchedule.daily();
      const weekdays = HabitSchedule.onWeekdays({DateTime.saturday});
      const flexible = HabitSchedule.perWeek(3);
      final saturday = DateTime(2026, 7, 11);
      final sunday = DateTime(2026, 7, 12);

      expect(daily.isDueOn(saturday), isTrue);
      expect(weekdays.isDueOn(saturday), isTrue);
      expect(weekdays.isDueOn(sunday), isFalse);
      expect(flexible.isDueOn(saturday), isFalse);
      expect(flexible.appearsOn(saturday), isTrue);
    });

    test('habit not tracked before its start date', () {
      final habit = makeHabit(startDate: DateTime(2026, 7, 10));
      expect(habit.isTrackedOn(DateTime(2026, 7, 9)), isFalse);
      expect(habit.isTrackedOn(DateTime(2026, 7, 10)), isTrue);
    });
  });

  group('date utils', () {
    test('dateKey round-trips and is timezone-shift safe', () {
      final date = DateTime(2026, 7, 22, 23, 59);
      expect(AppDateUtils.dateKey(date), '2026-07-22');
      expect(AppDateUtils.parseDateKey('2026-07-22'), DateTime(2026, 7, 22));
    });

    test('startOfWeek honors week start preference', () {
      final wednesday = DateTime(2026, 7, 22);
      expect(
        AppDateUtils.startOfWeek(wednesday, DateTime.monday),
        DateTime(2026, 7, 20),
      );
      expect(
        AppDateUtils.startOfWeek(wednesday, DateTime.sunday),
        DateTime(2026, 7, 19),
      );
    });
  });
}
