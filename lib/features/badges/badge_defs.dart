import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utilities/app_date_utils.dart';
import '../../core/utilities/streak_calculator.dart';
import '../habits/domain/habit.dart';
import '../habits/domain/habit_entry.dart';
import '../reset/domain/reset_plan.dart';

/// A milestone trophy. Unlock state is *derived* from data, never stored —
/// only the "already celebrated" flag is persisted (see badge_providers).
class Badge {
  const Badge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

abstract final class BadgeCatalog {
  static const List<Badge> all = [
    Badge(
      id: 'first_win',
      title: 'First Win',
      description: 'Complete your first habit',
      icon: Icons.emoji_events_rounded,
      color: AppColors.success,
    ),
    Badge(
      id: 'streak_3',
      title: 'Kindling',
      description: 'A 3-day streak',
      icon: Icons.local_fire_department_rounded,
      color: AppColors.warning,
    ),
    Badge(
      id: 'streak_7',
      title: 'On Fire',
      description: 'A full week of showing up',
      icon: Icons.whatshot_rounded,
      color: AppColors.fitness,
    ),
    Badge(
      id: 'streak_21',
      title: 'Habit Forged',
      description: 'A 21-day streak',
      icon: Icons.build_circle_rounded,
      color: AppColors.discipline,
    ),
    Badge(
      id: 'streak_30',
      title: 'Unstoppable',
      description: 'A 30-day streak',
      icon: Icons.rocket_launch_rounded,
      color: AppColors.mind,
    ),
    Badge(
      id: 'streak_100',
      title: 'Legend',
      description: 'A 100-day streak',
      icon: Icons.workspace_premium_rounded,
      color: AppColors.productivity,
    ),
    Badge(
      id: 'wins_100',
      title: 'Century',
      description: '100 total completions',
      icon: Icons.military_tech_rounded,
      color: AppColors.health,
    ),
    Badge(
      id: 'wins_500',
      title: 'Machine',
      description: '500 total completions',
      icon: Icons.bolt_rounded,
      color: AppColors.primaryBright,
    ),
    Badge(
      id: 'wins_1000',
      title: 'Force of Nature',
      description: '1,000 total completions',
      icon: Icons.landscape_rounded,
      color: AppColors.personalCare,
    ),
    Badge(
      id: 'plan_done',
      title: 'Full Reset',
      description: 'Complete a Reset plan',
      icon: Icons.restart_alt_rounded,
      color: AppColors.primary,
    ),
    Badge(
      id: 'fresh_start',
      title: 'Fresh Start',
      description: 'Came back after a break — that takes guts',
      icon: Icons.self_improvement_rounded,
      color: AppColors.health,
    ),
    Badge(
      id: 'dawn_patrol',
      title: 'Dawn Patrol',
      description: 'Completed a habit before 8 AM',
      icon: Icons.wb_twilight_rounded,
      color: AppColors.productivity,
    ),
  ];

  static Badge byId(String id) => all.firstWhere((b) => b.id == id);
}

/// Pure unlock evaluation — deterministic given the data, cheap enough to
/// run on every data change.
abstract final class BadgeEngine {
  static Set<String> unlocked({
    required List<Habit> habits,
    required Map<String, Map<String, HabitEntry>> entriesByHabit,
    required List<ResetPlan> plans,
    required DateTime today,
  }) {
    final ids = <String>{};

    final completed = <HabitEntry>[
      for (final byDate in entriesByHabit.values)
        for (final e in byDate.values)
          if (e.completed) e,
    ];

    if (completed.isNotEmpty) ids.add('first_win');
    if (completed.length >= 100) ids.add('wins_100');
    if (completed.length >= 500) ids.add('wins_500');
    if (completed.length >= 1000) ids.add('wins_1000');

    // Freeze-aware so the badge streak always matches the displayed streak.
    final best = StreakCalculator.overallStreakWithFreezes(
      habits: habits,
      entriesByHabit: entriesByHabit,
      today: today,
    ).best;
    if (best >= 3) ids.add('streak_3');
    if (best >= 7) ids.add('streak_7');
    if (best >= 21) ids.add('streak_21');
    if (best >= 30) ids.add('streak_30');
    if (best >= 100) ids.add('streak_100');

    if (plans.any((p) => p.status == ResetPlanStatus.completed)) {
      ids.add('plan_done');
    }

    // Fresh Start: a completed day after a gap of 3+ empty days. The badge
    // celebrates coming back, not the streak itself.
    final completedDays =
        completed
            .map((e) => e.dateKey)
            .toSet()
            .map(AppDateUtils.parseDateKey)
            .toList()
          ..sort();
    for (var i = 1; i < completedDays.length; i++) {
      if (AppDateUtils.daysBetween(completedDays[i - 1], completedDays[i]) >=
          4) {
        ids.add('fresh_start');
        break;
      }
    }

    // Dawn Patrol: any completion logged before 08:00 local time.
    if (completed.any((e) => e.updatedAt.hour < 8)) ids.add('dawn_patrol');

    return ids;
  }
}
