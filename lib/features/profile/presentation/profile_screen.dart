import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/section_header.dart';
import 'package:intl/intl.dart';

import '../../../core/backup/backup_service.dart';
import '../../badges/badge_defs.dart' as defs;
import '../../badges/badge_providers.dart';
import '../../habits/domain/habit.dart';
import '../data/data_export.dart';
import '../data/data_import.dart';
import '../data/demo_data.dart';
import '../providers/preferences_providers.dart';

final _exportProvider = FutureProvider.autoDispose<String>(exportAllData);

final _demoDataProvider = Provider(
  (ref) =>
      () => loadDemoData(ref),
);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _nameDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = ref.watch(preferencesProvider);
    final controller = ref.read(preferencesProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navProfile)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.xxl,
        ),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  prefs.displayName.isEmpty
                      ? '🙂'
                      : prefs.displayName.characters.first.toUpperCase(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              title: Text(
                prefs.displayName.isEmpty ? 'Add your name' : prefs.displayName,
                style: theme.textTheme.titleMedium,
              ),
              subtitle: const Text('Tap to edit'),
              onTap: () => _editName(context, ref),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Builder(
              builder: (context) {
                final unlocked = ref.watch(unlockedBadgesProvider).length;
                final total = defs.BadgeCatalog.all.length;
                return ListTile(
                  leading: const Icon(Icons.emoji_events_rounded),
                  title: const Text('Trophies'),
                  subtitle: Text('$unlocked of $total unlocked'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.trophies),
                );
              },
            ),
          ),
          const SectionHeader('Your goals'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final category in HabitCategory.values)
                FilterChip(
                  label: Text(category.label),
                  selected: prefs.selectedGoals.contains(category.name),
                  selectedColor: category.color.withValues(alpha: 0.2),
                  checkmarkColor: category.color,
                  onSelected: (selected) {
                    final goals = List<String>.from(prefs.selectedGoals);
                    selected
                        ? goals.add(category.name)
                        : goals.remove(category.name);
                    controller.setGoals(goals);
                  },
                ),
            ],
          ),
          const SectionHeader('Reminders'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Daily check-in reminder'),
                  subtitle: const Text(
                    'One gentle nudge per day. No spam, ever.',
                  ),
                  value: prefs.generalReminderEnabled,
                  onChanged: controller.setGeneralReminderEnabled,
                ),
                if (prefs.generalReminderEnabled)
                  ListTile(
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('Reminder time'),
                    trailing: Text(
                      prefs.reminderTime.format(context),
                      style: theme.textTheme.titleMedium,
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: prefs.reminderTime,
                      );
                      if (picked != null) {
                        controller.setReminderMinutes(
                          picked.hour * 60 + picked.minute,
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
          const SectionHeader('Preferences'),
          Card(
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.calendar_view_week_rounded,
                  label: 'Week starts on',
                  control: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: DateTime.monday, label: Text('Mon')),
                      ButtonSegment(value: DateTime.sunday, label: Text('Sun')),
                    ],
                    selected: {prefs.weekStartDay},
                    onSelectionChanged: (s) =>
                        controller.setWeekStartDay(s.first),
                  ),
                ),
                _SettingRow(
                  icon: Icons.dark_mode_rounded,
                  label: 'Theme',
                  control: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('Auto'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {prefs.themeMode},
                    onSelectionChanged: (s) => controller.setThemeMode(s.first),
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text(AppStrings.exportData),
                  subtitle: const Text('Copy all data as JSON'),
                  onTap: () => _export(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('Import data'),
                  subtitle: const Text('Paste a Reset export to restore it'),
                  onTap: () => _import(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_backup_restore_rounded),
                  title: const Text('Backups'),
                  subtitle: const Text('Automatic daily snapshots on device'),
                  onTap: () => _showBackups(context, ref),
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    AppStrings.resetAppData,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () => _resetAppData(context, ref),
                ),
                if (kDebugMode)
                  ListTile(
                    leading: const Icon(Icons.science_outlined),
                    title: const Text('Load demo data (dev)'),
                    onTap: () async {
                      await ref.read(_demoDataProvider)();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Demo data loaded')),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text(AppStrings.about),
              onTap: () => context.push(AppRoutes.about),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    // Guard against double-taps: a second tap used to open a stacked copy of
    // this dialog and dispose a TextEditingController that the closing
    // dialog's exit animation was still using, crashing the element tree.
    if (_nameDialogOpen) return;
    _nameDialogOpen = true;
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (context) =>
            _NameDialog(initialName: ref.read(preferencesProvider).displayName),
      );
      if (name != null) {
        await ref.read(preferencesProvider.notifier).setDisplayName(name);
      }
    } finally {
      _nameDialogOpen = false;
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final summary = await showDialog<String>(
      context: context,
      builder: (context) => const _ImportDialog(),
    );
    if (summary != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Imported $summary')));
    }
  }

  Future<void> _showBackups(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _BackupsSheet(),
      );

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final json = await ref.read(_exportProvider.future);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.exportData),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: Text(
              json,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.done),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAppData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '${AppStrings.resetAppData}?',
      message: AppStrings.resetAppDataWarning,
      confirmLabel: 'Delete everything',
    );
    if (!confirmed) return;

    final notifications = ref.read(notificationServiceProvider);
    await notifications.cancelDailyReminder();
    final habits = await ref.read(habitRepositoryProvider).watchAll().first;
    for (final habit in habits) {
      await notifications.cancelHabitReminder(habit.id);
    }
    await ref.read(databaseProvider).clearAllData();
    await ref.read(preferencesProvider.notifier).resetAll();
    // Router redirects back to onboarding via the preferences listener.
  }
}

/// Label-above-control layout so segmented buttons never squeeze the label.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.control,
  });

  final IconData icon;
  final String label;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: AppSpacing.md),
              Text(label, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(width: double.infinity, child: control),
        ],
      ),
    );
  }
}

/// Owns its text controller so it is disposed by the route's own lifecycle,
/// safely after the dialog's exit animation has finished.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initialName});

  final String initialName;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text(AppStrings.save),
        ),
      ],
    );
  }
}

/// Paste-JSON import dialog with a merge/replace choice.
class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog();

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  final _controller = TextEditingController();
  ImportMode _mode = ImportMode.merge;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(dataImportServiceProvider)
          .importJson(_controller.text, _mode);
      if (!mounted) return;
      Navigator.of(context).pop(result.describe());
    } on ImportFormatException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Import failed — the data may be corrupted.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import data'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Paste the exported JSON here…',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<ImportMode>(
              segments: const [
                ButtonSegment(
                  value: ImportMode.merge,
                  label: Text('Merge'),
                  tooltip: 'Combine with existing data; newer entries win',
                ),
                ButtonSegment(
                  value: ImportMode.replace,
                  label: Text('Replace'),
                  tooltip: 'Wipe current data first',
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            if (_mode == ImportMode.replace) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Replace deletes everything currently in the app first.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _run,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Import'),
        ),
      ],
    );
  }
}

/// Bottom sheet listing on-device backups with restore actions.
class _BackupsSheet extends ConsumerWidget {
  const _BackupsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final backupsAsync = ref.watch(_backupListProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backups', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reset snapshots your data once a day and keeps the last '
              '${BackupService.keep}. Backups live only on this device.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            backupsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'Could not read backups.',
                style: theme.textTheme.bodySmall,
              ),
              data: (backups) => backups.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Text(
                        'No backups yet — one is created automatically each '
                        'day, or make one now.',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : Column(
                      children: [
                        for (final b in backups)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.description_outlined),
                            title: Text(DateFormat.yMMMEd().format(b.date)),
                            trailing: TextButton(
                              onPressed: () => _restore(context, ref, b),
                              child: const Text('Restore'),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ref.read(backupServiceProvider).backupNow();
                  ref.invalidate(_backupListProvider);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Backup created')),
                  );
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Back up now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    BackupInfo backup,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Restore this backup?',
      message:
          'Data from ${DateFormat.yMMMd().format(backup.date)} will be merged '
          'into the app. Nothing is deleted; newer entries win conflicts.',
      confirmLabel: 'Restore',
      destructive: false,
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(backupServiceProvider)
          .restore(backup, ImportMode.merge);
      messenger.showSnackBar(
        SnackBar(content: Text('Restored ${result.describe()}')),
      );
    } on ImportFormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not restore: ${e.message}')),
      );
    }
  }
}

final _backupListProvider = FutureProvider.autoDispose<List<BackupInfo>>(
  (ref) => ref.watch(backupServiceProvider).listBackups(),
);
