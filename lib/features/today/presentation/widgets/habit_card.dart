import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/habit_icon_avatar.dart';
import '../../../habits/domain/habit.dart';
import '../../../habits/domain/habit_entry.dart';
import '../../../habits/providers/habit_providers.dart';
import 'value_entry_sheet.dart';

/// A habit row on the Today screen: progress, quick add, and completion.
class HabitCard extends ConsumerStatefulWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.entry,
    required this.dateKey,
  });

  final Habit habit;
  final HabitEntry? entry;
  final String dateKey;

  @override
  ConsumerState<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends ConsumerState<HabitCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  double get _value => widget.entry?.value ?? 0;

  bool get _completed => widget.entry?.completed ?? false;

  void _celebrate(double previousValue) {
    HapticFeedback.lightImpact();
    _pulse.forward(from: 0);
    final messenger = ScaffoldMessenger.of(context);
    final cheer =
        AppStrings.completionCheers[math.Random().nextInt(
          AppStrings.completionCheers.length,
        )];
    final habit = widget.habit;
    final dateKey = widget.dateKey;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(cheer),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: AppStrings.undo,
          onPressed: () => ref
              .read(habitActionsProvider)
              .setValue(habit, dateKey, previousValue),
        ),
      ),
    );
  }

  Future<void> _setValue(double value) async {
    final wasCompleted = _completed;
    final previousValue = _value;
    await ref
        .read(habitActionsProvider)
        .setValue(widget.habit, widget.dateKey, value);
    if (!mounted) return;
    if (!wasCompleted && value >= widget.habit.targetValue) {
      _celebrate(previousValue);
    }
  }

  Future<void> _quickAdd() => _setValue(
    _value + widget.habit.trackingType.quickIncrement(widget.habit.targetValue),
  );

  Future<void> _toggleBinary() async {
    if (_completed) {
      HapticFeedback.selectionClick();
      await ref
          .read(habitActionsProvider)
          .clearEntry(widget.habit, widget.dateKey);
    } else {
      await _setValue(widget.habit.targetValue);
    }
  }

  Future<void> _openEntrySheet() async {
    final habit = widget.habit;
    final result = await showValueEntrySheet(
      context,
      habit: habit,
      currentValue: _value,
    );
    if (result != null) {
      await _setValue(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habit = widget.habit;
    final progress = habit.trackingType.isBinary
        ? (_completed ? 1.0 : 0.0)
        : (habit.targetValue <= 0
              ? 0.0
              : (_value / habit.targetValue).clamp(0.0, 1.0));

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(_pulse.value);
        final bump = _pulse.isAnimating
            ? 1 + 0.03 * math.sin(t * math.pi)
            : 1.0;
        return Transform.scale(scale: bump, child: child);
      },
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: habit.trackingType.isBinary ? _toggleBinary : _openEntrySheet,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _completed
                    ? AppColors.success.withValues(alpha: 0.55)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
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
                            habit.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              decoration: _completed
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: theme.textTheme.bodySmall?.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle(),
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _trailingControl(theme),
                  ],
                ),
                if (!habit.trackingType.isBinary) ...[
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: progress),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: habit.color.withValues(alpha: 0.12),
                        color: _completed ? AppColors.success : habit.color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final habit = widget.habit;
    if (habit.trackingType.isBinary) {
      return '${habit.category.label} · ${habit.schedule.describe()}';
    }
    return '${habit.category.label} · ${habit.formatValue(_value)} / ${habit.formatValue(habit.targetValue)} ${habit.unitFor(habit.targetValue)}';
  }

  Widget _trailingControl(ThemeData theme) {
    final habit = widget.habit;
    if (habit.trackingType.isBinary || _completed) {
      return Semantics(
        button: true,
        label: _completed
            ? 'Mark ${habit.name} as not done'
            : 'Mark ${habit.name} as done',
        child: InkResponse(
          onTap: _toggleBinary,
          radius: 28,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _completed
                  ? AppColors.success
                  : habit.color.withValues(alpha: 0.12),
              border: _completed
                  ? null
                  : Border.all(
                      color: habit.color.withValues(alpha: 0.4),
                      width: 2,
                    ),
            ),
            child: Icon(
              Icons.check_rounded,
              color: _completed ? Colors.white : habit.color,
            ),
          ),
        ),
      );
    }
    final increment = habit.trackingType.quickIncrement(habit.targetValue);
    final label = increment == increment.roundToDouble()
        ? increment.toInt().toString()
        : increment.toString();
    return Semantics(
      button: true,
      label: 'Add $label ${habit.unit} to ${habit.name}',
      child: SizedBox(
        height: 44,
        child: FilledButton.tonal(
          onPressed: _quickAdd,
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 44),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            backgroundColor: habit.color.withValues(alpha: 0.14),
            foregroundColor: habit.color,
          ),
          child: Text('+$label'),
        ),
      ),
    );
  }
}
