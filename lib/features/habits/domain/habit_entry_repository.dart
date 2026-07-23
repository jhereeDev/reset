import 'habit.dart';
import 'habit_entry.dart';

abstract interface class HabitEntryRepository {
  Stream<List<HabitEntry>> watchForDate(String dateKey);

  Stream<List<HabitEntry>> watchForHabit(String habitId);

  Stream<List<HabitEntry>> watchAll();

  Future<HabitEntry?> getEntry(String habitId, String dateKey);

  /// Sets the absolute value for a habit on a date.
  ///
  /// Values are clamped to >= 0. Completion is recomputed against the habit's
  /// target. Setting 0 removes the entry (used for undo).
  Future<void> setValue(Habit habit, String dateKey, double value);

  /// Adds [delta] (may be negative to correct mistakes) to the current value.
  Future<void> addValue(Habit habit, String dateKey, double delta);
}
