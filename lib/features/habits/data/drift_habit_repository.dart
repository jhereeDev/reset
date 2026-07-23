import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utilities/app_date_utils.dart';
import '../domain/habit.dart';
import '../domain/habit_repository.dart';

class DriftHabitRepository implements HabitRepository {
  DriftHabitRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Habit>> watchAll() {
    final query = _db.select(_db.habits)
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<Habit>> watchActive() {
    final query = _db.select(_db.habits)
      ..where((t) => t.status.equalsValue(HabitStatus.active))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<Habit?> getById(String id) async {
    final row = await (_db.select(
      _db.habits,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> upsert(Habit habit) =>
      _db.into(_db.habits).insertOnConflictUpdate(_toRow(habit));

  @override
  Future<void> upsertAll(List<Habit> habits) => _db.batch((batch) {
    batch.insertAllOnConflictUpdate(_db.habits, habits.map(_toRow));
  });

  @override
  Future<void> setStatus(String id, HabitStatus status) =>
      (_db.update(_db.habits)..where((t) => t.id.equals(id))).write(
        HabitsCompanion(
          status: Value(status),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> reorder(List<String> orderedIds) => _db.transaction(() async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (_db.update(_db.habits)..where((t) => t.id.equals(orderedIds[i])))
          .write(HabitsCompanion(sortOrder: Value(i)));
    }
  });

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.habits)..where((t) => t.id.equals(id))).go();

  Habit _toDomain(HabitRow row) {
    return Habit(
      id: row.id,
      name: row.name,
      description: row.description,
      category: row.category,
      iconId: row.iconId,
      colorValue: row.colorValue,
      trackingType: row.trackingType,
      targetValue: row.targetValue,
      unit: row.unit,
      schedule: HabitSchedule(
        type: row.scheduleType,
        weekdays: row.weekdays.isEmpty
            ? const {}
            : row.weekdays.split(',').map(int.parse).toSet(),
        timesPerWeek: row.timesPerWeek,
      ),
      reminderMinutes: row.reminderMinutes,
      startDate: AppDateUtils.parseDateKey(row.startDateKey),
      status: row.status,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  HabitsCompanion _toRow(Habit habit) {
    return HabitsCompanion.insert(
      id: habit.id,
      name: habit.name,
      description: Value(habit.description),
      category: habit.category,
      iconId: habit.iconId,
      colorValue: habit.colorValue,
      trackingType: habit.trackingType,
      targetValue: habit.targetValue,
      unit: habit.unit,
      scheduleType: habit.schedule.type,
      weekdays: Value(habit.schedule.weekdays.join(',')),
      timesPerWeek: Value(habit.schedule.timesPerWeek),
      reminderMinutes: Value(habit.reminderMinutes),
      startDateKey: AppDateUtils.dateKey(habit.startDate),
      status: habit.status,
      sortOrder: Value(habit.sortOrder),
      createdAt: habit.createdAt,
      updatedAt: habit.updatedAt,
    );
  }
}
