import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/state_views.dart';
import '../preset_plans.dart';
import '../reset_providers.dart';

class ResetScreen extends ConsumerWidget {
  const ResetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(activePlanProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.resetTitle)),
      body: planAsync.when(
        loading: () => const AppLoadingState(),
        error: (e, _) =>
            AppErrorState(onRetry: () => ref.invalidate(activePlanProvider)),
        data: (plan) =>
            plan == null ? const _PlanPicker() : const _ActivePlanView(),
      ),
    );
  }
}

class _PlanPicker extends StatelessWidget {
  const _PlanPicker();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Text(AppStrings.resetIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        for (final preset in PresetPlans.all)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: () => context.push(AppRoutes.planPreview(preset.id)),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Text(
                              '${preset.durationDays} days',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(preset.title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        preset.description,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '${preset.habits.length} habits included',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActivePlanView extends ConsumerWidget {
  const _ActivePlanView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(activePlanStatsProvider);
    if (stats == null) return const AppLoadingState();
    final plan = stats.plan;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            children: [
              Text(
                plan.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ProgressRing(
                progress: stats.overallProgress,
                size: 132,
                strokeWidth: 12,
                color: Colors.white,
                trackColor: Colors.white.withValues(alpha: 0.25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Day ${stats.dayNumber}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'of ${plan.durationDays}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _PlanStat(
                    label: 'Days left',
                    value: '${stats.remainingDays}',
                  ),
                  _PlanStat(
                    label: 'Strong days',
                    value: '${stats.successfulDays}',
                  ),
                  _PlanStat(
                    label: 'Today',
                    value: '${stats.todayCompleted}/${stats.todayTotal}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (stats.isFinished)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Text(
                    'You made it to the end! 🎉',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'However many days you completed, you showed up — and that\'s what matters. Finish the plan to keep your habits going on their own.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () => ref
                        .read(resetActionsProvider)
                        .endPlan(plan, completed: true),
                    child: const Text('Complete plan'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.personalCare,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      AppStrings.missedDaySupport,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your plan habits live on the Today tab — complete them there.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton(
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'End this plan?',
                message:
                    'Your habits and history stay — only the plan tracking stops. You can start a new plan anytime.',
                confirmLabel: 'End plan',
              );
              if (confirmed) {
                await ref
                    .read(resetActionsProvider)
                    .endPlan(plan, completed: false);
              }
            },
            child: const Text('End plan early'),
          ),
        ],
      ],
    );
  }
}

class _PlanStat extends StatelessWidget {
  const _PlanStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}
