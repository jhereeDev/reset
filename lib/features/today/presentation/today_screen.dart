import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/state_views.dart';
import '../../habits/providers/habit_providers.dart';
import '../../profile/providers/preferences_providers.dart';
import '../today_providers.dart';
import 'widgets/habit_card.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(activeHabitsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-habit',
        onPressed: () => context.push(AppRoutes.habitNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text(AppStrings.addHabit),
      ),
      body: SafeArea(
        child: habitsAsync.when(
          loading: () => const AppLoadingState(),
          error: (e, _) => AppErrorState(
            message: 'Could not load your habits.',
            onRetry: () => ref.invalidate(activeHabitsProvider),
          ),
          data: (_) => const _TodayBody(),
        ),
      ),
    );
  }
}

class _TodayBody extends ConsumerWidget {
  const _TodayBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(todayHabitsProvider);
    final entries = ref.watch(todayEntryByHabitProvider);
    final todayKey = ref.watch(todayKeyProvider);

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: _TodayHeader()),
        if (habits.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.self_improvement_rounded,
              title: AppStrings.nothingToday,
              message: AppStrings.nothingTodayHint,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              0,
              AppSpacing.screen,
              96,
            ),
            sliver: SliverReorderableList(
              itemCount: habits.length,
              onReorderItem: (oldIndex, newIndex) {
                final ids = habits.map((h) => h.id).toList();
                final id = ids.removeAt(oldIndex);
                ids.insert(newIndex, id);
                ref.read(habitActionsProvider).reorder(ids);
              },
              itemBuilder: (context, index) {
                final habit = habits[index];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(habit.id),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: HabitCard(
                      habit: habit,
                      entry: entries[habit.id],
                      dateKey: todayKey,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _TodayHeader extends ConsumerWidget {
  const _TodayHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = ref.watch(preferencesProvider.select((p) => p.displayName));
    final motivation = ref.watch(dailyMotivationProvider);
    final progress = ref.watch(todayProgressProvider);
    final streak = ref.watch(overallStreakProvider);

    final now = DateTime.now();
    final greeting = switch (now.hour) {
      < 12 => AppStrings.goodMorning,
      < 18 => AppStrings.goodAfternoon,
      _ => AppStrings.goodEvening,
    };

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? greeting : '$greeting, $name',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat.yMMMMEEEEd().format(now),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => context.push(AppRoutes.habits),
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Manage habits',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                ProgressRing(
                  progress: progress.fraction,
                  size: 84,
                  strokeWidth: 9,
                  color: Colors.white,
                  trackColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(
                    '${progress.completed}/${progress.total}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress.allDone ? AppStrings.allDoneToday : motivation,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              streak.current == 1
                                  ? '1 day streak'
                                  : '${streak.current} day streak',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
