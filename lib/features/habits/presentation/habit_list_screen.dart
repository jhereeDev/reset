import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/habit_icon_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/habit.dart';
import '../providers/habit_providers.dart';

/// Manage all habits: reorder active ones, pause, archive, delete, edit.
class HabitListScreen extends ConsumerWidget {
  const HabitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(allHabitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your habits')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-habit-list',
        onPressed: () => context.push(AppRoutes.habitNew),
        child: const Icon(Icons.add_rounded),
      ),
      body: habitsAsync.when(
        loading: () => const AppLoadingState(),
        error: (e, _) =>
            AppErrorState(onRetry: () => ref.invalidate(allHabitsProvider)),
        data: (habits) {
          if (habits.isEmpty) {
            return AppEmptyState(
              icon: Icons.checklist_rounded,
              title: 'No habits yet',
              message: 'Create your first habit and start building momentum.',
              actionLabel: AppStrings.addHabit,
              onAction: () => context.push(AppRoutes.habitNew),
            );
          }
          final active = habits
              .where((h) => h.status == HabitStatus.active)
              .toList();
          final paused = habits
              .where((h) => h.status == HabitStatus.paused)
              .toList();
          final archived = habits
              .where((h) => h.status == HabitStatus.archived)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              0,
              AppSpacing.screen,
              96,
            ),
            children: [
              if (active.isNotEmpty) ...[
                const SectionHeader('Active — hold & drag to reorder'),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: true,
                  itemCount: active.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final ids = active.map((h) => h.id).toList();
                    final id = ids.removeAt(oldIndex);
                    ids.insert(newIndex, id);
                    ref.read(habitActionsProvider).reorder(ids);
                  },
                  itemBuilder: (context, index) => _HabitTile(
                    key: ValueKey(active[index].id),
                    habit: active[index],
                  ),
                ),
              ],
              if (paused.isNotEmpty) ...[
                const SectionHeader('Paused'),
                for (final h in paused) _HabitTile(habit: h),
              ],
              if (archived.isNotEmpty) ...[
                const SectionHeader('Archived'),
                for (final h in archived) _HabitTile(habit: h),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HabitTile extends ConsumerWidget {
  const _HabitTile({super.key, required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final actions = ref.read(habitActionsProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          leading: HabitIconAvatar(
            iconId: habit.iconId,
            color: habit.color,
            size: 42,
          ),
          title: Text(habit.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${habit.category.label} · ${habit.targetLabel} · ${habit.schedule.describe()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          onTap: () => context.push(AppRoutes.habitEdit(habit.id)),
          trailing: PopupMenuButton<String>(
            tooltip: 'Habit options',
            onSelected: (value) async {
              switch (value) {
                case 'edit':
                  context.push(AppRoutes.habitEdit(habit.id));
                case 'pause':
                  actions.setStatus(habit, HabitStatus.paused);
                case 'resume':
                  actions.setStatus(habit, HabitStatus.active);
                case 'archive':
                  actions.setStatus(habit, HabitStatus.archived);
                case 'delete':
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Delete "${habit.name}"?',
                    message:
                        'This removes the habit and its entire history. Archiving keeps the history instead.',
                  );
                  if (confirmed) await actions.deleteHabit(habit);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (habit.status == HabitStatus.active)
                const PopupMenuItem(value: 'pause', child: Text('Pause'))
              else
                const PopupMenuItem(value: 'resume', child: Text('Resume')),
              if (habit.status != HabitStatus.archived)
                const PopupMenuItem(value: 'archive', child: Text('Archive')),
              const PopupMenuItem(value: 'delete', child: Text('Delete…')),
            ],
          ),
        ),
      ),
    );
  }
}
