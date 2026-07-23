import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reset/core/database/app_database.dart';
import 'package:reset/features/habits/data/drift_habit_entry_repository.dart';
import 'package:reset/features/habits/data/drift_habit_repository.dart';
import 'package:reset/features/habits/domain/habit.dart';
import 'package:reset/features/reset/data/drift_reset_plan_repository.dart';
import 'package:reset/features/reset/domain/reset_plan.dart';

Habit makeHabit({String id = 'h1', double target = 10, int sortOrder = 0}) {
  final now = DateTime(2026, 7, 1);
  return Habit(
    id: id,
    name: 'Push-ups',
    category: HabitCategory.fitness,
    iconId: 'fitness',
    colorValue: 0xFFF97316,
    trackingType: TrackingType.count,
    targetValue: target,
    unit: 'reps',
    schedule: const HabitSchedule.daily(),
    startDate: DateTime(2026, 7, 1),
    sortOrder: sortOrder,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late AppDatabase db;
  late DriftHabitRepository habits;
  late DriftHabitEntryRepository entries;
  late DriftResetPlanRepository plans;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    habits = DriftHabitRepository(db);
    entries = DriftHabitEntryRepository(db);
    plans = DriftResetPlanRepository(db);
  });

  tearDown(() async => db.close());

  group('habit repository', () {
    test('upsert, read back and delete', () async {
      final habit = makeHabit();
      await habits.upsert(habit);

      final loaded = await habits.getById('h1');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Push-ups');
      expect(loaded.schedule.type, ScheduleType.daily);
      expect(loaded.targetValue, 10);

      await habits.delete('h1');
      expect(await habits.getById('h1'), isNull);
    });

    test('watchActive excludes paused and archived habits', () async {
      await habits.upsert(makeHabit(id: 'a'));
      await habits.upsert(makeHabit(id: 'b'));
      await habits.setStatus('b', HabitStatus.paused);

      final active = await habits.watchActive().first;
      expect(active.map((h) => h.id), ['a']);

      final all = await habits.watchAll().first;
      expect(all.length, 2);
    });

    test('reorder persists new sort order', () async {
      await habits.upsert(makeHabit(id: 'a', sortOrder: 0));
      await habits.upsert(makeHabit(id: 'b', sortOrder: 1));
      await habits.reorder(['b', 'a']);

      final active = await habits.watchActive().first;
      expect(active.map((h) => h.id), ['b', 'a']);
    });

    test('deleting a habit cascades to its entries', () async {
      final habit = makeHabit();
      await habits.upsert(habit);
      await entries.setValue(habit, '2026-07-01', 5);
      await habits.delete(habit.id);
      expect(await entries.watchAll().first, isEmpty);
    });
  });

  group('entry repository — progress rules', () {
    test('completion flips when the target is reached or exceeded', () async {
      final habit = makeHabit(target: 10);
      await habits.upsert(habit);

      await entries.setValue(habit, '2026-07-01', 9);
      var entry = await entries.getEntry(habit.id, '2026-07-01');
      expect(entry!.completed, isFalse);

      await entries.setValue(habit, '2026-07-01', 10);
      entry = await entries.getEntry(habit.id, '2026-07-01');
      expect(entry!.completed, isTrue);

      await entries.setValue(habit, '2026-07-01', 25);
      entry = await entries.getEntry(habit.id, '2026-07-01');
      expect(entry!.completed, isTrue);
      expect(entry.value, 25);
    });

    test('one entry per habit per day (no duplicates)', () async {
      final habit = makeHabit();
      await habits.upsert(habit);
      await entries.setValue(habit, '2026-07-01', 3);
      await entries.setValue(habit, '2026-07-01', 7);
      final all = await entries.watchAll().first;
      expect(all.length, 1);
      expect(all.single.value, 7);
    });

    test('addValue accumulates and never goes negative', () async {
      final habit = makeHabit(target: 10);
      await habits.upsert(habit);

      await entries.addValue(habit, '2026-07-01', 4);
      await entries.addValue(habit, '2026-07-01', 4);
      var entry = await entries.getEntry(habit.id, '2026-07-01');
      expect(entry!.value, 8);

      // Correcting by more than the logged amount clamps at zero
      // (a zero value removes the entry entirely).
      await entries.addValue(habit, '2026-07-01', -100);
      entry = await entries.getEntry(habit.id, '2026-07-01');
      expect(entry, isNull);
    });

    test('a completion can be undone', () async {
      final habit = makeHabit(target: 10);
      await habits.upsert(habit);
      await entries.setValue(habit, '2026-07-01', 10);
      expect(
        (await entries.getEntry(habit.id, '2026-07-01'))!.completed,
        isTrue,
      );

      await entries.setValue(habit, '2026-07-01', 0);
      expect(await entries.getEntry(habit.id, '2026-07-01'), isNull);
    });
  });

  group('reset plan repository', () {
    test('active plan stream and status changes', () async {
      final plan = ResetPlan(
        id: 'p1',
        title: '7-Day Restart',
        description: 'test',
        durationDays: 7,
        startDate: DateTime(2026, 7, 1),
        habitIds: const ['a', 'b'],
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      );
      await plans.insert(plan);

      var active = await plans.watchActivePlan().first;
      expect(active!.id, 'p1');
      expect(active.habitIds, ['a', 'b']);
      expect(active.endDate, DateTime(2026, 7, 7));

      await plans.setStatus('p1', ResetPlanStatus.completed);
      active = await plans.watchActivePlan().first;
      expect(active, isNull);
    });
  });
}
