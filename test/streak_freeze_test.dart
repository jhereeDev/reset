import 'package:flutter_test/flutter_test.dart';
import 'package:reset/core/utilities/app_date_utils.dart';
import 'package:reset/core/utilities/streak_calculator.dart';
import 'package:reset/features/habits/domain/habit.dart';
import 'package:reset/features/habits/domain/habit_entry.dart';

Habit makeHabit({DateTime? startDate}) {
  final now = DateTime(2026, 6, 1);
  return Habit(
    id: 'h1',
    name: 'Habit',
    category: HabitCategory.fitness,
    iconId: 'star',
    colorValue: 0xFF000000,
    trackingType: TrackingType.yesNo,
    targetValue: 1,
    unit: '',
    schedule: const HabitSchedule.daily(),
    startDate: startDate ?? DateTime(2026, 6, 1),
    createdAt: now,
    updatedAt: now,
  );
}

/// Builds entries for the habit: success on every listed day.
Map<String, Map<String, HabitEntry>> completedOn(List<DateTime> days) => {
  'h1': {
    for (final d in days)
      AppDateUtils.dateKey(d): HabitEntry(
        id: 'e-${AppDateUtils.dateKey(d)}',
        habitId: 'h1',
        dateKey: AppDateUtils.dateKey(d),
        value: 1,
        completed: true,
        createdAt: d,
        updatedAt: d,
      ),
  },
};

/// Consecutive days starting at [start].
List<DateTime> daysFrom(DateTime start, int count) => [
  for (var i = 0; i < count; i++) start.add(Duration(days: i)),
];

void main() {
  OverallStreakState run({
    required List<DateTime> completed,
    required DateTime today,
    DateTime? startDate,
  }) => StreakCalculator.overallStreakWithFreezes(
    habits: [makeHabit(startDate: startDate)],
    entriesByHabit: completedOn(completed),
    today: today,
  );

  test('7 consecutive successful days earn one token', () {
    final start = DateTime(2026, 6, 1);
    final state = run(
      completed: daysFrom(start, 7),
      today: DateTime(2026, 6, 7),
      startDate: start,
    );
    expect(state.current, 7);
    expect(state.freezeTokens, 1);
    expect(state.frozenDayKeys, isEmpty);
  });

  test('six days earn nothing', () {
    final start = DateTime(2026, 6, 1);
    final state = run(
      completed: daysFrom(start, 6),
      today: DateTime(2026, 6, 6),
      startDate: start,
    );
    expect(state.freezeTokens, 0);
  });

  test('a token auto-covers a missed day and the streak survives', () {
    final start = DateTime(2026, 6, 1);
    // 7 successes, June 8 missed, then 3 more successes.
    final state = run(
      completed: [...daysFrom(start, 7), ...daysFrom(DateTime(2026, 6, 9), 3)],
      today: DateTime(2026, 6, 11),
      startDate: start,
    );
    expect(state.frozenDayKeys, {'2026-06-08'});
    expect(state.freezeTokens, 0, reason: 'the one token was spent');
    expect(state.current, 10, reason: '7 + 3; the frozen day adds nothing');
  });

  test('without a token, a missed day resets the streak', () {
    final start = DateTime(2026, 6, 1);
    // Only 5 successes (no token earned), June 6 missed, then 3 successes.
    final state = run(
      completed: [...daysFrom(start, 5), ...daysFrom(DateTime(2026, 6, 7), 3)],
      today: DateTime(2026, 6, 9),
      startDate: start,
    );
    expect(state.frozenDayKeys, isEmpty);
    expect(state.current, 3);
    expect(state.best, 5);
  });

  test('tokens cap at 3', () {
    final start = DateTime(2026, 6, 1);
    // 35 consecutive successes would earn 5 tokens without the cap.
    final state = run(
      completed: daysFrom(start, 35),
      today: DateTime(2026, 7, 5),
      startDate: start,
    );
    expect(state.freezeTokens, StreakCalculator.maxTokens);
  });

  test('consecutive missed days drain tokens then break', () {
    final start = DateTime(2026, 6, 1);
    // 14 successes = 2 tokens; then 3 missed days; then 2 successes.
    final state = run(
      completed: [
        ...daysFrom(start, 14),
        ...daysFrom(DateTime(2026, 6, 18), 2),
      ],
      today: DateTime(2026, 6, 19),
      startDate: start,
    );
    // June 15 + 16 frozen; June 17 breaks (no tokens left).
    expect(state.frozenDayKeys, {'2026-06-15', '2026-06-16'});
    expect(state.current, 2);
    expect(state.best, 14);
  });

  test('an open today neither spends a token nor breaks the streak', () {
    final start = DateTime(2026, 6, 1);
    final state = run(
      completed: daysFrom(start, 7),
      today: DateTime(2026, 6, 8), // today has no entry yet
      startDate: start,
    );
    expect(state.current, 7);
    expect(state.freezeTokens, 1, reason: 'today must not consume the token');
  });
}
