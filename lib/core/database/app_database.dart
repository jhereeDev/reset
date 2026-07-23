import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/habits/domain/habit.dart';
import '../../features/reset/domain/reset_plan.dart';

part 'app_database.g.dart';

@DataClassName('HabitRow')
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get category => textEnum<HabitCategory>()();
  TextColumn get iconId => text()();
  IntColumn get colorValue => integer()();
  TextColumn get trackingType => textEnum<TrackingType>()();
  RealColumn get targetValue => real()();
  TextColumn get unit => text()();
  TextColumn get scheduleType => textEnum<ScheduleType>()();

  /// Comma-separated DateTime weekday ints, e.g. "1,3,5".
  TextColumn get weekdays => text().withDefault(const Constant(''))();
  IntColumn get timesPerWeek => integer().withDefault(const Constant(0))();
  IntColumn get reminderMinutes => integer().nullable()();
  TextColumn get startDateKey => text()();
  TextColumn get status => textEnum<HabitStatus>()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('HabitEntryRow')
class HabitEntries extends Table {
  TextColumn get id => text()();
  TextColumn get habitId =>
      text().references(Habits, #id, onDelete: KeyAction.cascade)();
  TextColumn get dateKey => text()();
  RealColumn get value => real()();
  BoolColumn get completed => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {habitId, dateKey},
  ];
}

@DataClassName('ResetPlanRow')
class ResetPlans extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  IntColumn get durationDays => integer()();
  TextColumn get startDateKey => text()();
  TextColumn get endDateKey => text()();

  /// Comma-separated habit ids.
  TextColumn get habitIds => text()();
  TextColumn get status => textEnum<ResetPlanStatus>()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Habits, HabitEntries, ResetPlans])
class AppDatabase extends _$AppDatabase {
  /// Test constructor — pass e.g. `NativeDatabase.memory()`.
  AppDatabase(super.e);

  AppDatabase.open() : super(driftDatabase(name: 'reset_app'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(habitEntries).go();
      await delete(resetPlans).go();
      await delete(habits).go();
    });
  }
}
