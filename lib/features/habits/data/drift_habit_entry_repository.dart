import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/habit.dart';
import '../domain/habit_entry.dart';
import '../domain/habit_entry_repository.dart';

class DriftHabitEntryRepository implements HabitEntryRepository {
  DriftHabitEntryRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  @override
  Stream<List<HabitEntry>> watchForDate(String dateKey) {
    final query = _db.select(_db.habitEntries)
      ..where((t) => t.dateKey.equals(dateKey));
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<HabitEntry>> watchForHabit(String habitId) {
    final query = _db.select(_db.habitEntries)
      ..where((t) => t.habitId.equals(habitId));
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<HabitEntry>> watchAll() => _db
      .select(_db.habitEntries)
      .watch()
      .map((rows) => rows.map(_toDomain).toList());

  @override
  Future<HabitEntry?> getEntry(String habitId, String dateKey) async {
    final row =
        await (_db.select(_db.habitEntries)..where(
              (t) => t.habitId.equals(habitId) & t.dateKey.equals(dateKey),
            ))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> setValue(Habit habit, String dateKey, double value) async {
    final clamped = value < 0 ? 0.0 : value;
    if (clamped == 0) {
      // A zero value is equivalent to "not logged" — remove the entry so
      // undoing a completion leaves no partial record behind.
      await (_db.delete(_db.habitEntries)..where(
            (t) => t.habitId.equals(habit.id) & t.dateKey.equals(dateKey),
          ))
          .go();
      return;
    }
    final now = DateTime.now();
    final existing = await getEntry(habit.id, dateKey);
    final completed = clamped >= habit.targetValue;
    if (existing == null) {
      await _db
          .into(_db.habitEntries)
          .insert(
            HabitEntriesCompanion.insert(
              id: _uuid.v4(),
              habitId: habit.id,
              dateKey: dateKey,
              value: clamped,
              completed: completed,
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      await (_db.update(
        _db.habitEntries,
      )..where((t) => t.id.equals(existing.id))).write(
        HabitEntriesCompanion(
          value: Value(clamped),
          completed: Value(completed),
          updatedAt: Value(now),
        ),
      );
    }
  }

  @override
  Future<void> addValue(Habit habit, String dateKey, double delta) async {
    final existing = await getEntry(habit.id, dateKey);
    await setValue(habit, dateKey, (existing?.value ?? 0) + delta);
  }

  HabitEntry _toDomain(HabitEntryRow row) => HabitEntry(
    id: row.id,
    habitId: row.habitId,
    dateKey: row.dateKey,
    value: row.value,
    completed: row.completed,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
