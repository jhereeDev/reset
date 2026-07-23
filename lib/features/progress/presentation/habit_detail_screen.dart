import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utilities/app_date_utils.dart';
import '../../../core/utilities/streak_calculator.dart';
import '../../../core/widgets/habit_icon_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../progress_providers.dart';
import 'progress_screen.dart' show statusColor;

/// Per-habit statistics: streaks, completion rate, 7/30-day history, values.
class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(habitStatsProvider(habitId));
    if (stats == null) {
      return const Scaffold(
        body: AppErrorState(message: 'This habit no longer exists.'),
      );
    }
    final habit = stats.habit;
    final last7 = stats.recentDays.sublist(stats.recentDays.length - 7);
    final loggedDays = stats.recentDays
        .where((d) => d.value > 0)
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.habitEdit(habit.id)),
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit habit',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Row(
            children: [
              HabitIconAvatar(iconId: habit.iconId, color: habit.color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${habit.category.label} · ${habit.targetLabel}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      habit.schedule.describe(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  value: '${stats.streak.current}',
                  label: 'Current streak',
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MiniStat(
                  value: '${stats.streak.best}',
                  label: 'Best streak',
                  color: AppColors.productivity,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MiniStat(
                  value: '${(stats.completionRate * 100).round()}%',
                  label: 'Completion',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SectionHeader('Last 7 days'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final day in last7)
                    Column(
                      children: [
                        Text(
                          DateFormat.E().format(day.date).substring(0, 2),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _DayDot(day: day, size: 30),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SectionHeader('Last 30 days'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final day in stats.recentDays)
                    Tooltip(
                      message:
                          '${DateFormat.MMMd().format(day.date)} — ${habit.formatValue(day.value)}',
                      child: _DayDot(day: day, size: 22),
                    ),
                ],
              ),
            ),
          ),
          const SectionHeader('History'),
          if (loggedDays.isEmpty)
            Text(
              'No logged values in the last 30 days.',
              style: theme.textTheme.bodySmall,
            )
          else
            Card(
              child: Column(
                children: [
                  for (final day in loggedDays)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        day.status == DayStatus.complete
                            ? Icons.check_circle_rounded
                            : Icons.adjust_rounded,
                        color: statusColor(context, day.status),
                      ),
                      title: Text(DateFormat.yMMMEd().format(day.date)),
                      trailing: Text(
                        habit.trackingType.isBinary
                            ? 'Done'
                            : '${habit.formatValue(day.value)} ${habit.unitFor(day.value)}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.sm,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.size});

  final HabitDayInfo day;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isToday = AppDateUtils.isSameDay(day.date, AppDateUtils.today());
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: statusColor(context, day.status),
        border: isToday
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
      ),
    );
  }
}
