import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utilities/app_date_utils.dart';
import '../../../core/widgets/habit_icon_avatar.dart';
import '../../habits/domain/habit.dart';
import '../../profile/providers/preferences_providers.dart';
import '../../reset/preset_plans.dart';
import '../starter_habits.dart';

/// Five-step onboarding: welcome/name → goals → difficulty → starter habits
/// (with adjustable targets) → reminder time.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  static const _stepCount = 5;

  int _step = 0;
  final Set<HabitCategory> _goals = {};
  Difficulty _difficulty = Difficulty.steady;
  late final Map<int, bool> _selectedStarters = {
    for (var i = 0; i < StarterHabits.all.length; i++) i: i < 3,
  };
  late final Map<int, double> _targets = {};
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _wantsReminder = true;
  bool _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  double _targetFor(int index) =>
      _targets[index] ??
      StarterHabits.scaleTarget(StarterHabits.all[index], _difficulty);

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final today = AppDateUtils.dateOnly(now);
      const uuid = Uuid();
      final reminderMinutes = _reminderTime.hour * 60 + _reminderTime.minute;

      final habits = <Habit>[];
      var order = 0;
      for (var i = 0; i < StarterHabits.all.length; i++) {
        if (_selectedStarters[i] != true) continue;
        final t = StarterHabits.all[i];
        habits.add(
          Habit(
            id: uuid.v4(),
            name: t.name,
            category: t.category,
            iconId: t.iconId,
            colorValue: PresetPlans.colorFor(t.category),
            trackingType: t.trackingType,
            targetValue: _targetFor(i),
            unit: t.effectiveUnit,
            schedule: const HabitSchedule.daily(),
            startDate: today,
            sortOrder: order++,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      await ref.read(habitRepositoryProvider).upsertAll(habits);

      final prefs = ref.read(preferencesProvider.notifier);
      await prefs.setDisplayName(_nameController.text);
      await prefs.setGoals(_goals.map((g) => g.name).toList());
      await prefs.setReminderMinutes(reminderMinutes);
      if (_wantsReminder) {
        await prefs.setGeneralReminderEnabled(true);
      }
      await prefs.completeOnboarding();
      // The router redirects to Today automatically once onboarding is done.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.lg,
                AppSpacing.screen,
                0,
              ),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      onPressed: () => _goTo(_step - 1),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: AppStrings.back,
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / _stepCount,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomeStep(nameController: _nameController),
                  _GoalsStep(
                    selected: _goals,
                    onToggle: (c) => setState(() {
                      _goals.contains(c) ? _goals.remove(c) : _goals.add(c);
                    }),
                  ),
                  _DifficultyStep(
                    selected: _difficulty,
                    onSelect: (d) => setState(() {
                      _difficulty = d;
                      _targets.clear(); // re-derive targets from difficulty
                    }),
                  ),
                  _StartersStep(
                    selected: _selectedStarters,
                    targetFor: _targetFor,
                    onToggle: (i) => setState(
                      () => _selectedStarters[i] =
                          !(_selectedStarters[i] ?? false),
                    ),
                    onTargetChanged: (i, v) => setState(() => _targets[i] = v),
                  ),
                  _ReminderStep(
                    time: _reminderTime,
                    enabled: _wantsReminder,
                    onToggle: (v) => setState(() => _wantsReminder = v),
                    onPick: (t) => setState(() => _reminderTime = t),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : () {
                          if (_step < _stepCount - 1) {
                            _goTo(_step + 1);
                          } else {
                            _finish();
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(
                          _step < _stepCount - 1
                              ? AppStrings.next
                              : AppStrings.getStarted,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen,
        vertical: AppSpacing.xl,
      ),
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(subtitle, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xl),
        child,
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.nameController});

  final TextEditingController nameController;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Welcome to ${AppStrings.appName} 👋',
      subtitle:
          '${AppStrings.tagline}\n\nThis takes under a minute. What should we call you?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.restart_alt_rounded,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Rebuild yourself with simple daily actions.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your name (optional)',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsStep extends StatelessWidget {
  const _GoalsStep({required this.selected, required this.onToggle});

  final Set<HabitCategory> selected;
  final ValueChanged<HabitCategory> onToggle;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'What do you want to improve?',
      subtitle: 'Pick as many as you like — you can change this later.',
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final category in HabitCategory.values)
            FilterChip(
              label: Text(category.label),
              avatar: selected.contains(category)
                  ? null
                  : Icon(Icons.circle, size: 12, color: category.color),
              selected: selected.contains(category),
              onSelected: (_) => onToggle(category),
              selectedColor: category.color.withValues(alpha: 0.2),
              checkmarkColor: category.color,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
            ),
        ],
      ),
    );
  }
}

class _DifficultyStep extends StatelessWidget {
  const _DifficultyStep({required this.selected, required this.onSelect});

  final Difficulty selected;
  final ValueChanged<Difficulty> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StepScaffold(
      title: 'How hard do you want to go?',
      subtitle: 'This scales the suggested targets. No wrong answer.',
      child: Column(
        children: [
          for (final d in Difficulty.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  onTap: () => onSelect(d),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Icon(
                          d == selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: d == selected
                              ? theme.colorScheme.primary
                              : theme.dividerColor,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.label, style: theme.textTheme.titleMedium),
                              Text(
                                d.description,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StartersStep extends StatelessWidget {
  const _StartersStep({
    required this.selected,
    required this.targetFor,
    required this.onToggle,
    required this.onTargetChanged,
  });

  final Map<int, bool> selected;
  final double Function(int) targetFor;
  final ValueChanged<int> onToggle;
  final void Function(int, double) onTargetChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StepScaffold(
      title: 'Pick your starter habits',
      subtitle: 'Adjust the amounts to fit your life. Add more anytime.',
      child: Column(
        children: [
          for (var i = 0; i < StarterHabits.all.length; i++)
            _StarterTile(
              template: StarterHabits.all[i],
              isSelected: selected[i] ?? false,
              target: targetFor(i),
              onToggle: () => onToggle(i),
              onTargetChanged: (v) => onTargetChanged(i, v),
              theme: theme,
            ),
        ],
      ),
    );
  }
}

class _StarterTile extends StatelessWidget {
  const _StarterTile({
    required this.template,
    required this.isSelected,
    required this.target,
    required this.onToggle,
    required this.onTargetChanged,
    required this.theme,
  });

  final PlanHabitTemplate template;
  final bool isSelected;
  final double target;
  final VoidCallback onToggle;
  final ValueChanged<double> onTargetChanged;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final step = template.trackingType.quickIncrement(target);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onToggle,
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
                          Text(
                            template.name,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            template.category.label,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => onToggle(),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
                if (isSelected && !template.trackingType.isBinary) ...[
                  const SizedBox(height: AppSpacing.sm),
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
                        '${target == target.roundToDouble() ? target.toInt() : target} ${pluralizedUnit(template.effectiveUnit, target)}',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderStep extends StatelessWidget {
  const _ReminderStep({
    required this.time,
    required this.enabled,
    required this.onToggle,
    required this.onPick,
  });

  final TimeOfDay time;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final ValueChanged<TimeOfDay> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StepScaffold(
      title: 'A gentle daily nudge?',
      subtitle:
          'We\'ll send one friendly reminder a day. You can turn this off anytime.',
      child: Card(
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Daily reminder'),
              value: enabled,
              onChanged: onToggle,
            ),
            if (enabled)
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Reminder time'),
                trailing: Text(
                  time.format(context),
                  style: theme.textTheme.titleMedium,
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: time,
                  );
                  if (picked != null) onPick(picked);
                },
              ),
          ],
        ),
      ),
    );
  }
}
