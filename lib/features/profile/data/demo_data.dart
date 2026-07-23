import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utilities/app_date_utils.dart';
import '../../habits/domain/habit.dart';
import '../../reset/domain/reset_plan.dart';

/// Development helper: seeds a realistic data set — active habits, a 7-day
/// mixed history, and an in-flight reset plan. Debug builds only (the button
/// is wrapped in kDebugMode).
Future<void> loadDemoData(Ref ref) async {
  const uuid = Uuid();
  final now = DateTime.now();
  final today = AppDateUtils.today();

  Habit make(
    String name,
    HabitCategory category,
    String iconId,
    TrackingType type,
    double target, {
    String? unit,
    int order = 0,
    HabitSchedule schedule = const HabitSchedule.daily(),
  }) => Habit(
    id: uuid.v4(),
    name: name,
    category: category,
    iconId: iconId,
    colorValue: switch (category) {
      HabitCategory.fitness => AppColors.fitness.toARGB32(),
      HabitCategory.health => AppColors.health.toARGB32(),
      HabitCategory.mind => AppColors.mind.toARGB32(),
      HabitCategory.discipline => AppColors.discipline.toARGB32(),
      HabitCategory.productivity => AppColors.productivity.toARGB32(),
      HabitCategory.personalCare => AppColors.personalCare.toARGB32(),
    },
    trackingType: type,
    targetValue: target,
    unit: unit ?? type.defaultUnit,
    schedule: schedule,
    startDate: today.subtract(const Duration(days: 8)),
    sortOrder: order,
    createdAt: now.subtract(const Duration(days: 8)),
    updatedAt: now,
  );

  final pushups = make(
    'Push-ups',
    HabitCategory.fitness,
    'fitness',
    TrackingType.count,
    100,
    order: 0,
  );
  final steps = make(
    'Walk',
    HabitCategory.fitness,
    'walk',
    TrackingType.steps,
    10000,
    order: 1,
  );
  final reading = make(
    'Read one chapter',
    HabitCategory.mind,
    'book',
    TrackingType.chapters,
    1,
    order: 2,
  );
  final fruit = make(
    'Eat fruit',
    HabitCategory.health,
    'fruit',
    TrackingType.servings,
    2,
    order: 3,
  );
  final bed = make(
    'Make the bed',
    HabitCategory.discipline,
    'bed',
    TrackingType.yesNo,
    1,
    order: 4,
  );

  final habits = [pushups, steps, reading, fruit, bed];
  await ref.read(habitRepositoryProvider).upsertAll(habits);

  // Seven days of varied history: some full, some partial, one missed day.
  final entryRepo = ref.read(habitEntryRepositoryProvider);
  final valuesByDayOffset = <int, Map<String, double>>{
    // offset 0 = today (partially done), 1 = yesterday, ...
    0: {pushups.id: 40, steps.id: 6420, fruit.id: 1, bed.id: 1},
    1: {
      pushups.id: 100,
      steps.id: 11200,
      reading.id: 1,
      fruit.id: 2,
      bed.id: 1,
    },
    2: {pushups.id: 100, steps.id: 9800, reading.id: 1, fruit.id: 2, bed.id: 1},
    3: {pushups.id: 60, steps.id: 4200, bed.id: 1},
    4: {}, // a fully missed day — supportive UX must handle this
    5: {
      pushups.id: 100,
      steps.id: 12000,
      reading.id: 1,
      fruit.id: 3,
      bed.id: 1,
    },
    6: {
      pushups.id: 100,
      steps.id: 10500,
      reading.id: 1,
      fruit.id: 2,
      bed.id: 1,
    },
  };
  final habitById = {for (final h in habits) h.id: h};
  for (final entry in valuesByDayOffset.entries) {
    final key = AppDateUtils.dateKey(today.subtract(Duration(days: entry.key)));
    for (final value in entry.value.entries) {
      await entryRepo.setValue(habitById[value.key]!, key, value.value);
    }
  }

  // An in-flight 21-day plan covering three of the habits, started 8 days ago.
  final plan = ResetPlan(
    id: uuid.v4(),
    title: '21-Day Discipline Reset',
    description: 'Demo plan seeded for development.',
    durationDays: 21,
    startDate: today.subtract(const Duration(days: 8)),
    habitIds: [pushups.id, reading.id, bed.id],
    createdAt: now.subtract(const Duration(days: 8)),
    updatedAt: now,
  );
  await ref.read(resetPlanRepositoryProvider).insert(plan);
}
