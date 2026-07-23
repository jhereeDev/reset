import 'habit.dart';

/// Abstract so a future cloud-synced implementation can replace the local one.
abstract interface class HabitRepository {
  Stream<List<Habit>> watchAll();

  /// Active habits ordered by sortOrder.
  Stream<List<Habit>> watchActive();

  Future<Habit?> getById(String id);

  Future<void> upsert(Habit habit);

  Future<void> upsertAll(List<Habit> habits);

  Future<void> setStatus(String id, HabitStatus status);

  /// Persists the given order of active habit ids.
  Future<void> reorder(List<String> orderedIds);

  /// Deletes the habit. Entries are kept or removed by the caller's policy;
  /// this implementation cascades (full delete was explicitly confirmed).
  Future<void> delete(String id);
}
