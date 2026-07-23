import 'package:flutter_test/flutter_test.dart';
import 'package:reset/core/utilities/app_date_utils.dart';
import 'package:reset/features/badges/badge_defs.dart';
import 'package:reset/features/habits/domain/habit.dart';
import 'package:reset/features/habits/domain/habit_entry.dart';
import 'package:reset/features/reset/domain/reset_plan.dart';

Habit makeHabit({String id = 'h1'}) {
  final now = DateTime(2026, 7, 1);
  return Habit(
    id: id,
    name: 'Habit',
    category: HabitCategory.fitness,
    iconId: 'star',
    colorValue: 0xFF000000,
    trackingType: TrackingType.yesNo,
    targetValue: 1,
    unit: '',
    schedule: const HabitSchedule.daily(),
    startDate: DateTime(2026, 6, 1),
    createdAt: now,
    updatedAt: now,
  );
}

HabitEntry entry(
  String habitId,
  DateTime day, {
  bool completed = true,
  DateTime? loggedAt,
}) => HabitEntry(
  id: '$habitId-${AppDateUtils.dateKey(day)}',
  habitId: habitId,
  dateKey: AppDateUtils.dateKey(day),
  value: 1,
  completed: completed,
  createdAt: loggedAt ?? day.add(const Duration(hours: 12)),
  updatedAt: loggedAt ?? day.add(const Duration(hours: 12)),
);

Map<String, Map<String, HabitEntry>> byHabit(List<HabitEntry> entries) {
  final map = <String, Map<String, HabitEntry>>{};
  for (final e in entries) {
    (map[e.habitId] ??= {})[e.dateKey] = e;
  }
  return map;
}

void main() {
  final today = DateTime(2026, 7, 20);

  Set<String> run({
    List<Habit>? habits,
    List<HabitEntry> entries = const [],
    List<ResetPlan> plans = const [],
  }) => BadgeEngine.unlocked(
    habits: habits ?? [makeHabit()],
    entriesByHabit: byHabit(entries),
    plans: plans,
    today: today,
  );

  test('no data unlocks nothing', () {
    expect(run(), isEmpty);
  });

  test('first completion unlocks first_win only (afternoon log)', () {
    final ids = run(entries: [entry('h1', DateTime(2026, 7, 19))]);
    expect(ids, contains('first_win'));
    expect(ids, isNot(contains('streak_3')));
    expect(ids, isNot(contains('dawn_patrol')));
  });

  test('streak badges track best overall streak', () {
    final entries = [
      for (var i = 0; i < 7; i++)
        entry('h1', DateTime(2026, 7, 10).add(Duration(days: i))),
    ];
    final ids = run(entries: entries);
    expect(ids, containsAll(['streak_3', 'streak_7']));
    expect(ids, isNot(contains('streak_21')));
  });

  test('fresh_start requires a gap of at least 4 days', () {
    final close = run(
      entries: [
        entry('h1', DateTime(2026, 7, 10)),
        entry('h1', DateTime(2026, 7, 13)), // 3-day gap — not enough
      ],
    );
    expect(close, isNot(contains('fresh_start')));

    final comeback = run(
      entries: [
        entry('h1', DateTime(2026, 7, 10)),
        entry('h1', DateTime(2026, 7, 14)), // 4-day gap — welcome back
      ],
    );
    expect(comeback, contains('fresh_start'));
  });

  test('dawn_patrol unlocks for a pre-8AM completion', () {
    final ids = run(
      entries: [
        entry(
          'h1',
          DateTime(2026, 7, 19),
          loggedAt: DateTime(2026, 7, 19, 6, 30),
        ),
      ],
    );
    expect(ids, contains('dawn_patrol'));
  });

  test('plan_done requires a completed plan, not an active one', () {
    ResetPlan plan(ResetPlanStatus status) => ResetPlan(
      id: 'p-${status.name}',
      title: 'Plan',
      description: '',
      durationDays: 7,
      startDate: DateTime(2026, 7, 1),
      habitIds: const ['h1'],
      status: status,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );
    expect(run(plans: [plan(ResetPlanStatus.active)]), isEmpty);
    expect(
      run(plans: [plan(ResetPlanStatus.completed)]),
      contains('plan_done'),
    );
  });

  test('win-count badges use total completed entries', () {
    final entries = [
      for (var i = 0; i < 100; i++)
        entry('h1', DateTime(2026, 1, 1).add(Duration(days: i))),
    ];
    final ids = run(entries: entries);
    expect(ids, contains('wins_100'));
    expect(ids, isNot(contains('wins_500')));
  });

  test('every catalog id is reachable and unique', () {
    final ids = BadgeCatalog.all.map((b) => b.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'duplicate badge id');
    for (final id in ids) {
      expect(() => BadgeCatalog.byId(id), returnsNormally);
    }
  });
}
