import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utilities/app_date_utils.dart';
import '../domain/habit.dart';
import '../domain/habit_entry.dart';

final activeHabitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(habitRepositoryProvider).watchActive(),
);

final allHabitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(habitRepositoryProvider).watchAll(),
);

final habitByIdProvider = Provider.family<Habit?, String>((ref, id) {
  final habits = ref.watch(allHabitsProvider).value ?? const [];
  for (final h in habits) {
    if (h.id == id) return h;
  }
  return null;
});

final todayEntriesProvider = StreamProvider<List<HabitEntry>>((ref) {
  final key = ref.watch(todayKeyProvider);
  return ref.watch(habitEntryRepositoryProvider).watchForDate(key);
});

final allEntriesProvider = StreamProvider<List<HabitEntry>>(
  (ref) => ref.watch(habitEntryRepositoryProvider).watchAll(),
);

/// habitId -> (dateKey -> entry). Empty while loading.
final entriesByHabitProvider = Provider<Map<String, Map<String, HabitEntry>>>((
  ref,
) {
  final entries = ref.watch(allEntriesProvider).value ?? const [];
  final map = <String, Map<String, HabitEntry>>{};
  for (final e in entries) {
    (map[e.habitId] ??= {})[e.dateKey] = e;
  }
  return map;
});

final habitActionsProvider = Provider<HabitActions>(HabitActions.new);

/// Write-side operations for habits and entries. Keeps notification
/// scheduling in sync with data changes and enforces business rules
/// (no negative values, no future completions).
class HabitActions {
  HabitActions(this._ref);

  final Ref _ref;

  Future<void> saveHabit(Habit habit) async {
    await _ref.read(habitRepositoryProvider).upsert(habit);
    final notifications = _ref.read(notificationServiceProvider);
    if (habit.reminderMinutes != null && habit.isActive) {
      await notifications.requestPermission();
      await notifications.scheduleHabitReminder(habit);
    } else {
      await notifications.cancelHabitReminder(habit.id);
    }
  }

  Future<void> setStatus(Habit habit, HabitStatus status) async {
    await _ref.read(habitRepositoryProvider).setStatus(habit.id, status);
    if (status == HabitStatus.active && habit.reminderMinutes != null) {
      await _ref
          .read(notificationServiceProvider)
          .scheduleHabitReminder(habit.copyWith(status: status));
    } else {
      await _ref
          .read(notificationServiceProvider)
          .cancelHabitReminder(habit.id);
    }
  }

  Future<void> deleteHabit(Habit habit) async {
    await _ref.read(notificationServiceProvider).cancelHabitReminder(habit.id);
    await _ref.read(habitRepositoryProvider).delete(habit.id);
  }

  Future<void> reorder(List<String> orderedIds) =>
      _ref.read(habitRepositoryProvider).reorder(orderedIds);

  bool _isFuture(String dateKey) =>
      dateKey.compareTo(AppDateUtils.dateKey(DateTime.now())) > 0;

  /// Sets an absolute value for a day. Ignored for future dates.
  Future<void> setValue(Habit habit, String dateKey, double value) async {
    if (_isFuture(dateKey)) return;
    await _ref
        .read(habitEntryRepositoryProvider)
        .setValue(habit, dateKey, value);
  }

  Future<void> addValue(Habit habit, String dateKey, double delta) async {
    if (_isFuture(dateKey)) return;
    await _ref
        .read(habitEntryRepositoryProvider)
        .addValue(habit, dateKey, delta);
  }

  /// Marks a yes/no habit done, or completes a numeric habit at its target.
  Future<void> complete(Habit habit, String dateKey) =>
      setValue(habit, dateKey, habit.targetValue);

  /// Reverts a completion (or any logged value) for the day.
  Future<void> clearEntry(Habit habit, String dateKey) =>
      setValue(habit, dateKey, 0);
}
