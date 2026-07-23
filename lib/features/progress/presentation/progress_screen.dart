import 'package:fl_chart/fl_chart.dart';
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
import '../../habits/providers/habit_providers.dart';
import '../../today/today_providers.dart';
import '../progress_providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(allHabitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: habitsAsync.when(
        loading: () => const AppLoadingState(),
        error: (e, _) =>
            AppErrorState(onRetry: () => ref.invalidate(allHabitsProvider)),
        data: (habits) {
          if (habits.isEmpty) {
            return const AppEmptyState(
              icon: Icons.insights_rounded,
              title: 'Nothing to chart yet',
              message:
                  'Once you start completing habits, your progress will show up here.',
            );
          }
          return const _ProgressBody();
        },
      ),
    );
  }
}

class _ProgressBody extends ConsumerWidget {
  const _ProgressBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final streak = ref.watch(overallStreakProvider);
    final weekCompletion = ref.watch(weekCompletionProvider);
    final totalCompleted = ref.watch(totalCompletedActionsProvider);
    final habits = ref.watch(activeHabitsProvider).value ?? const [];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: AppColors.warning,
                value: '${streak.current}',
                label: 'Current streak',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                icon: Icons.emoji_events_rounded,
                iconColor: AppColors.productivity,
                value: '${streak.best}',
                label: 'Best streak',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.pie_chart_rounded,
                iconColor: AppColors.primary,
                value: '${(weekCompletion * 100).round()}%',
                label: 'This week',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_rounded,
                iconColor: AppColors.success,
                value: '$totalCompleted',
                label: 'Total wins',
              ),
            ),
          ],
        ),
        const SectionHeader('This week'),
        const _WeekCalendar(),
        const SizedBox(height: AppSpacing.md),
        const _WeeklyBarChart(),
        const SizedBox(height: AppSpacing.sm),
        const _StatusLegend(),
        const SectionHeader('By habit'),
        if (habits.isEmpty)
          Text(
            'No active habits. Resume or create one to keep tracking.',
            style: theme.textTheme.bodySmall,
          ),
        for (final habit in habits) _HabitProgressTile(habitId: habit.id),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: theme.textTheme.headlineSmall),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

Color statusColor(BuildContext context, DayStatus status) {
  final theme = Theme.of(context);
  return switch (status) {
    DayStatus.complete => AppColors.success,
    DayStatus.partial => AppColors.warning,
    DayStatus.missed => AppColors.danger.withValues(alpha: 0.55),
    DayStatus.future => theme.dividerColor,
    DayStatus.rest => theme.dividerColor.withValues(alpha: 0.35),
    DayStatus.frozen => const Color(0xFF38BDF8), // ice blue — streak freeze
  };
}

class _WeekCalendar extends ConsumerWidget {
  const _WeekCalendar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final days = ref.watch(currentWeekDaysProvider);
    final today = AppDateUtils.today();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final day in days)
              Column(
                children: [
                  Text(
                    DateFormat.E().format(day.date).substring(0, 2),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor(context, day.status).withValues(
                        alpha: day.status == DayStatus.rest ? 0.3 : 0.9,
                      ),
                      border: AppDateUtils.isSameDay(day.date, today)
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Text(
                      '${day.date.day}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color:
                            day.status == DayStatus.future ||
                                day.status == DayStatus.rest
                            ? theme.textTheme.bodyMedium?.color
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBarChart extends ConsumerWidget {
  const _WeeklyBarChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final counts = ref.watch(weeklyCompletionCountsProvider);
    final days = ref.watch(currentWeekDaysProvider);
    final maxCount = counts
        .fold<int>(0, (m, c) => c > m ? c : m)
        .clamp(1, 1 << 30);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxCount + 1,
              barTouchData: BarTouchData(enabled: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= days.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          DateFormat.E()
                              .format(days[index].date)
                              .substring(0, 2),
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < counts.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: counts[i].toDouble(),
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                        color: counts[i] == 0
                            ? theme.dividerColor
                            : AppColors.primary,
                        gradient: counts[i] == 0
                            ? null
                            : const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryBright,
                                ],
                              ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget dot(DayStatus status, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor(context, status),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.center,
      children: [
        dot(DayStatus.complete, 'Complete'),
        dot(DayStatus.partial, 'Partial'),
        dot(DayStatus.missed, 'Missed'),
        dot(DayStatus.frozen, 'Frozen'),
        dot(DayStatus.future, 'Upcoming'),
      ],
    );
  }
}

class _HabitProgressTile extends ConsumerWidget {
  const _HabitProgressTile({required this.habitId});

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(habitStatsProvider(habitId));
    if (stats == null) return const SizedBox.shrink();
    final habit = stats.habit;
    final last7 = stats.recentDays.sublist(stats.recentDays.length - 7);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.push(AppRoutes.habitDetail(habitId)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                HabitIconAvatar(
                  iconId: habit.iconId,
                  color: habit.color,
                  size: 42,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '🔥 ${stats.streak.current} · ${(stats.completionRate * 100).round()}% completion',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final day in last7)
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor(context, day.status),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
