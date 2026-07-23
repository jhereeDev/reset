import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../habits/domain/habit.dart';

/// Bottom sheet for entering an exact value for a numeric habit.
/// Resolves with the new absolute value, or null when dismissed.
Future<double?> showValueEntrySheet(
  BuildContext context, {
  required Habit habit,
  required double currentValue,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _ValueEntrySheet(habit: habit, currentValue: currentValue),
  );
}

class _ValueEntrySheet extends StatefulWidget {
  const _ValueEntrySheet({required this.habit, required this.currentValue});

  final Habit habit;
  final double currentValue;

  @override
  State<_ValueEntrySheet> createState() => _ValueEntrySheetState();
}

class _ValueEntrySheetState extends State<_ValueEntrySheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentValue == 0
        ? ''
        : widget.habit.formatValue(widget.currentValue),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (parsed == null || parsed < 0) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habit = widget.habit;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screen,
        right: AppSpacing.screen,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(habit.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Target: ${habit.targetLabel} · logged today: ${habit.formatValue(widget.currentValue)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Total ${habit.unit} today',
              helperText: 'Enter the total for today (not just what to add).',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              if (widget.currentValue > 0)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(0.0),
                  child: const Text('Clear today'),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(AppStrings.cancel),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: _submit,
                child: const Text(AppStrings.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
