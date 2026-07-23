import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../core/utilities/app_date_utils.dart';
import '../habits/domain/habit.dart';
import '../habits/providers/habit_providers.dart';
import 'domain/reset_plan.dart';
import 'preset_plans.dart';

final activePlanProvider = StreamProvider<ResetPlan?>(
  (ref) => ref.watch(resetPlanRepositoryProvider).watchActivePlan(),
);

/// Derived statistics for the active plan.
class ResetPlanStats {
  const ResetPlanStats({
    required this.plan,
    required this.dayNumber,
    required this.remainingDays,
    required this.successfulDays,
    required this.overallProgress,
    required this.todayCompleted,
    required this.todayTotal,
    required this.isFinished,
  });

  final ResetPlan plan;
  final int dayNumber;
  final int remainingDays;

  /// Days so far on which every plan habit was completed.
  final int successfulDays;

  /// Completed habit-days / total habit-days elapsed, 0..1.
  final double overallProgress;

  final int todayCompleted;
  final int todayTotal;
  final bool isFinished;
}

final activePlanStatsProvider = Provider<ResetPlanStats?>((ref) {
  final plan = ref.watch(activePlanProvider).value;
  if (plan == null) return null;

  final todayKey = ref.watch(todayKeyProvider);
  final today = AppDateUtils.parseDateKey(todayKey);
  final entriesByHabit = ref.watch(entriesByHabitProvider);

  final planHabitIds = plan.habitIds.toSet();
  bool completedOn(String habitId, String dateKey) =>
      entriesByHabit[habitId]?[dateKey]?.completed ?? false;

  final elapsedDays = plan.isFinishedBy(today)
      ? plan.durationDays
      : plan.dayNumberOn(today);

  var successfulDays = 0;
  var completedHabitDays = 0;
  for (var i = 0; i < elapsedDays; i++) {
    final key = AppDateUtils.dateKey(plan.startDate.add(Duration(days: i)));
    var done = 0;
    for (final id in planHabitIds) {
      if (completedOn(id, key)) done++;
    }
    completedHabitDays += done;
    if (planHabitIds.isNotEmpty && done == planHabitIds.length) {
      successfulDays++;
    }
  }

  final totalHabitDays = planHabitIds.length * elapsedDays;
  var todayDone = 0;
  for (final id in planHabitIds) {
    if (completedOn(id, todayKey)) todayDone++;
  }

  return ResetPlanStats(
    plan: plan,
    dayNumber: plan.dayNumberOn(today),
    remainingDays: plan.remainingDaysOn(today),
    successfulDays: successfulDays,
    overallProgress: totalHabitDays == 0
        ? 0
        : completedHabitDays / totalHabitDays,
    todayCompleted: todayDone,
    todayTotal: planHabitIds.length,
    isFinished: plan.isFinishedBy(today),
  );
});

final resetActionsProvider = Provider<ResetActions>(ResetActions.new);

class ResetActions {
  ResetActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  /// Creates real habits from the (possibly customized) templates and starts
  /// the plan today. Returns the created plan id.
  Future<String> startPlan(
    PresetPlan preset,
    List<PlanHabitTemplate> chosenHabits,
  ) async {
    final now = DateTime.now();
    final today = AppDateUtils.dateOnly(now);
    final existing = _ref.read(activeHabitsProvider).value ?? const <Habit>[];
    var sortOrder = existing.length;

    final habits = <Habit>[
      for (final t in chosenHabits)
        Habit(
          id: _uuid.v4(),
          name: t.name,
          category: t.category,
          iconId: t.iconId,
          colorValue: PresetPlans.colorFor(t.category),
          trackingType: t.trackingType,
          targetValue: t.targetValue,
          unit: t.effectiveUnit,
          schedule: const HabitSchedule.daily(),
          startDate: today,
          sortOrder: sortOrder++,
          createdAt: now,
          updatedAt: now,
        ),
    ];

    final plan = ResetPlan(
      id: _uuid.v4(),
      title: preset.title,
      description: preset.description,
      durationDays: preset.durationDays,
      startDate: today,
      habitIds: habits.map((h) => h.id).toList(),
      createdAt: now,
      updatedAt: now,
    );

    await _ref.read(habitRepositoryProvider).upsertAll(habits);
    await _ref.read(resetPlanRepositoryProvider).insert(plan);
    return plan.id;
  }

  /// Ends the plan. Habits stay active so progress isn't lost; the user can
  /// archive them individually.
  Future<void> endPlan(ResetPlan plan, {required bool completed}) => _ref
      .read(resetPlanRepositoryProvider)
      .setStatus(
        plan.id,
        completed ? ResetPlanStatus.completed : ResetPlanStatus.ended,
      );
}
