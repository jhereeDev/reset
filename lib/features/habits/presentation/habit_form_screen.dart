import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/habit_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utilities/app_date_utils.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/habit.dart';
import '../providers/habit_providers.dart';

/// Create/edit form for a habit. [habitId] null means create.
class HabitFormScreen extends ConsumerStatefulWidget {
  const HabitFormScreen({super.key, this.habitId});

  final String? habitId;

  @override
  ConsumerState<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends ConsumerState<HabitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController(text: '1');
  final _unitController = TextEditingController();

  HabitCategory _category = HabitCategory.fitness;
  String _iconId = 'star';
  int _colorValue = AppColors.habitPalette.first.toARGB32();
  TrackingType _trackingType = TrackingType.yesNo;
  ScheduleType _scheduleType = ScheduleType.daily;
  final Set<int> _weekdays = {
    DateTime.monday,
    DateTime.wednesday,
    DateTime.friday,
  };
  int _timesPerWeek = 3;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);
  DateTime _startDate = AppDateUtils.today();

  Habit? _editing;
  bool _loaded = false;
  bool _saving = false;

  bool get _isEdit => widget.habitId != null;

  @override
  void initState() {
    super.initState();
    if (!_isEdit) _loaded = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _populateFrom(Habit habit) {
    _editing = habit;
    _nameController.text = habit.name;
    _descriptionController.text = habit.description;
    _targetController.text = habit.formatValue(habit.targetValue);
    _unitController.text = habit.unit;
    _category = habit.category;
    _iconId = habit.iconId;
    _colorValue = habit.colorValue;
    _trackingType = habit.trackingType;
    _scheduleType = habit.schedule.type;
    if (habit.schedule.weekdays.isNotEmpty) {
      _weekdays
        ..clear()
        ..addAll(habit.schedule.weekdays);
    }
    if (habit.schedule.timesPerWeek > 0) {
      _timesPerWeek = habit.schedule.timesPerWeek;
    }
    _reminderEnabled = habit.reminderMinutes != null;
    if (habit.reminderMinutes != null) {
      _reminderTime = TimeOfDay(
        hour: habit.reminderMinutes! ~/ 60,
        minute: habit.reminderMinutes! % 60,
      );
    }
    _startDate = habit.startDate;
    _loaded = true;
  }

  String get _effectiveUnit {
    if (_trackingType == TrackingType.custom ||
        _unitController.text.trim().isNotEmpty) {
      return _unitController.text.trim();
    }
    return _trackingType.defaultUnit;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final target = _trackingType.isBinary
          ? 1.0
          : double.parse(_targetController.text.replaceAll(',', '.'));

      final schedule = switch (_scheduleType) {
        ScheduleType.daily => const HabitSchedule.daily(),
        ScheduleType.weekdays => HabitSchedule.onWeekdays(Set.of(_weekdays)),
        ScheduleType.timesPerWeek => HabitSchedule.perWeek(_timesPerWeek),
      };

      final habit = Habit(
        id: _editing?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        iconId: _iconId,
        colorValue: _colorValue,
        trackingType: _trackingType,
        targetValue: target,
        unit: _effectiveUnit,
        schedule: schedule,
        reminderMinutes: _reminderEnabled
            ? _reminderTime.hour * 60 + _reminderTime.minute
            : null,
        startDate: _startDate,
        status: _editing?.status ?? HabitStatus.active,
        sortOrder:
            _editing?.sortOrder ??
            (ref.read(activeHabitsProvider).value?.length ?? 0),
        createdAt: _editing?.createdAt ?? now,
        updatedAt: now,
      );

      await ref.read(habitActionsProvider).saveHabit(habit);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && !_loaded) {
      final habit = ref.watch(habitByIdProvider(widget.habitId!));
      if (habit != null) {
        _populateFrom(habit);
      } else if (ref.watch(allHabitsProvider).hasValue) {
        return const Scaffold(
          body: AppErrorState(message: 'This habit no longer exists.'),
        );
      } else {
        return const Scaffold(body: AppLoadingState());
      }
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? AppStrings.editHabit : AppStrings.newHabit),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text(AppStrings.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.sm,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
            _label(theme, 'Icon'),
            _IconPicker(
              selected: _iconId,
              color: Color(_colorValue),
              onSelect: (id) => setState(() => _iconId = id),
            ),
            _label(theme, 'Color'),
            _ColorPicker(
              selected: _colorValue,
              onSelect: (v) => setState(() => _colorValue = v),
            ),
            _label(theme, 'Category'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in HabitCategory.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _category == c,
                    selectedColor: c.color.withValues(alpha: 0.2),
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            _label(theme, 'Tracking'),
            DropdownButtonFormField<TrackingType>(
              initialValue: _trackingType,
              items: [
                for (final t in TrackingType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (t) {
                if (t != null) setState(() => _trackingType = t);
              },
            ),
            if (!_trackingType.isBinary) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _targetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Daily target',
                      ),
                      validator: (v) {
                        if (_trackingType.isBinary) return null;
                        final parsed = double.tryParse(
                          (v ?? '').replaceAll(',', '.'),
                        );
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a number above 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        hintText: _trackingType.defaultUnit.isEmpty
                            ? 'e.g. glasses'
                            : _trackingType.defaultUnit,
                      ),
                      validator: (v) =>
                          _trackingType == TrackingType.custom &&
                              (v == null || v.trim().isEmpty)
                          ? 'Name your unit'
                          : null,
                    ),
                  ),
                ],
              ),
            ],
            _label(theme, 'Schedule'),
            SegmentedButton<ScheduleType>(
              segments: const [
                ButtonSegment(value: ScheduleType.daily, label: Text('Daily')),
                ButtonSegment(
                  value: ScheduleType.weekdays,
                  label: Text('Weekdays'),
                ),
                ButtonSegment(
                  value: ScheduleType.timesPerWeek,
                  label: Text('Per week'),
                ),
              ],
              selected: {_scheduleType},
              onSelectionChanged: (s) =>
                  setState(() => _scheduleType = s.first),
            ),
            if (_scheduleType == ScheduleType.weekdays) ...[
              const SizedBox(height: AppSpacing.md),
              _WeekdayPicker(
                selected: _weekdays,
                onToggle: (d) => setState(() {
                  if (_weekdays.contains(d) && _weekdays.length > 1) {
                    _weekdays.remove(d);
                  } else {
                    _weekdays.add(d);
                  }
                }),
              ),
            ],
            if (_scheduleType == ScheduleType.timesPerWeek) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text('Times per week', style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  IconButton(
                    onPressed: _timesPerWeek > 1
                        ? () => setState(() => _timesPerWeek--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text('$_timesPerWeek', style: theme.textTheme.titleMedium),
                  IconButton(
                    onPressed: _timesPerWeek < 7
                        ? () => setState(() => _timesPerWeek++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
            ],
            _label(theme, 'Reminder'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Daily reminder'),
                    value: _reminderEnabled,
                    onChanged: (v) => setState(() => _reminderEnabled = v),
                  ),
                  if (_reminderEnabled)
                    ListTile(
                      leading: const Icon(Icons.schedule_rounded),
                      title: const Text('Time'),
                      trailing: Text(
                        _reminderTime.format(context),
                        style: theme.textTheme.titleMedium,
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _reminderTime,
                        );
                        if (picked != null) {
                          setState(() => _reminderTime = picked);
                        }
                      },
                    ),
                ],
              ),
            ),
            _label(theme, 'Start date'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_rounded),
                title: Text(DateFormat.yMMMd().format(_startDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _startDate = AppDateUtils.dateOnly(picked));
                  }
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isEdit ? AppStrings.save : 'Create habit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
    child: Text(text, style: theme.textTheme.titleSmall),
  );
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.selected,
    required this.color,
    required this.onSelect,
  });

  final String selected;
  final Color color;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final entry in HabitIcons.all.entries)
          Semantics(
            button: true,
            label: 'Icon ${entry.key}',
            selected: entry.key == selected,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () => onSelect(entry.key),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: entry.key == selected
                      ? color.withValues(alpha: 0.18)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: entry.key == selected ? color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  entry.value,
                  color: entry.key == selected
                      ? color
                      : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final color in AppColors.habitPalette)
          Semantics(
            button: true,
            selected: color.toARGB32() == selected,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onSelect(color.toARGB32()),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: color.toARGB32() == selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 22,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onToggle});

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var day = DateTime.monday; day <= DateTime.sunday; day++)
          Semantics(
            button: true,
            selected: selected.contains(day),
            label: 'Weekday ${_labels[day - 1]}',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onToggle(day),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected.contains(day)
                      ? scheme.primary
                      : scheme.surface,
                ),
                child: Text(
                  _labels[day - 1],
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected.contains(day)
                        ? scheme.onPrimary
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
