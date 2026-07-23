import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/habit_icon_avatar.dart';
import '../../../core/widgets/state_views.dart';
import '../../habits/domain/habit.dart';
import '../preset_plans.dart';
import '../reset_providers.dart';

/// Preview a preset plan; toggle habits and tweak targets before starting.
class PlanPreviewScreen extends ConsumerStatefulWidget {
  const PlanPreviewScreen({super.key, required this.presetId});

  final String presetId;

  @override
  ConsumerState<PlanPreviewScreen> createState() => _PlanPreviewScreenState();
}

class _PlanPreviewScreenState extends ConsumerState<PlanPreviewScreen> {
  late final PresetPlan? _preset = PresetPlans.all
      .where((p) => p.id == widget.presetId)
      .cast<PresetPlan?>()
      .firstOrNull;

  late final List<bool> _enabled = List.filled(
    _preset?.habits.length ?? 0,
    true,
  );
  late final List<double> _targets = [
    for (final h in _preset?.habits ?? <PlanHabitTemplate>[]) h.targetValue,
  ];
  bool _starting = false;

  Future<void> _start() async {
    final preset = _preset;
    if (preset == null || _starting) return;
    final chosen = <PlanHabitTemplate>[
      for (var i = 0; i < preset.habits.length; i++)
        if (_enabled[i]) preset.habits[i].withTarget(_targets[i]),
    ];
    if (chosen.isEmpty) return;
    setState(() => _starting = true);
    try {
      await ref.read(resetActionsProvider).startPlan(preset, chosen);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = _preset;
    if (preset == null) {
      return const Scaffold(body: AppErrorState(message: 'Unknown plan.'));
    }
    final theme = Theme.of(context);
    final anyEnabled = _enabled.contains(true);

    return Scaffold(
      appBar: AppBar(title: Text(preset.title)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: FilledButton(
            onPressed: anyEnabled && !_starting ? _start : null,
            child: _starting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text('Start ${preset.durationDays}-day plan'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Text(preset.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tune the plan to fit your life — turn habits off or adjust the amounts.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < preset.habits.length; i++)
            _TemplateTile(
              template: preset.habits[i],
              enabled: _enabled[i],
              target: _targets[i],
              onToggle: (v) => setState(() => _enabled[i] = v),
              onTargetChanged: (v) => setState(() => _targets[i] = v),
            ),
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.enabled,
    required this.target,
    required this.onToggle,
    required this.onTargetChanged,
  });

  final PlanHabitTemplate template;
  final bool enabled;
  final double target;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = template.trackingType.quickIncrement(target);
    final targetText = target == target.roundToDouble()
        ? '${target.toInt()}'
        : '$target';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Row(
                children: [
                  HabitIconAvatar(
                    iconId: template.iconId,
                    color: template.category.color,
                    size: 42,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(template.name, style: theme.textTheme.titleMedium),
                        Text(
                          template.trackingType.isBinary
                              ? template.category.label
                              : '${template.category.label} · $targetText ${pluralizedUnit(template.effectiveUnit, target)} daily',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(value: enabled, onChanged: onToggle),
                ],
              ),
              if (enabled && !template.trackingType.isBinary)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: target - step >= 1
                          ? () => onTargetChanged(target - step)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      tooltip: 'Decrease target',
                    ),
                    Text(
                      '$targetText ${pluralizedUnit(template.effectiveUnit, target)}',
                      style: theme.textTheme.titleSmall,
                    ),
                    IconButton(
                      onPressed: () => onTargetChanged(target + step),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      tooltip: 'Increase target',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
