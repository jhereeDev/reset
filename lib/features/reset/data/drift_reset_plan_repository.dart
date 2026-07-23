import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utilities/app_date_utils.dart';
import '../domain/reset_plan.dart';
import '../domain/reset_plan_repository.dart';

class DriftResetPlanRepository implements ResetPlanRepository {
  DriftResetPlanRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<ResetPlan?> watchActivePlan() {
    final query = _db.select(_db.resetPlans)
      ..where((t) => t.status.equalsValue(ResetPlanStatus.active))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(1);
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _toDomain(row),
    );
  }

  @override
  Stream<List<ResetPlan>> watchAll() {
    final query = _db.select(_db.resetPlans)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<void> insert(ResetPlan plan) => _db
      .into(_db.resetPlans)
      .insertOnConflictUpdate(
        ResetPlansCompanion.insert(
          id: plan.id,
          title: plan.title,
          description: plan.description,
          durationDays: plan.durationDays,
          startDateKey: AppDateUtils.dateKey(plan.startDate),
          endDateKey: AppDateUtils.dateKey(plan.endDate),
          habitIds: plan.habitIds.join(','),
          status: plan.status,
          createdAt: plan.createdAt,
          updatedAt: plan.updatedAt,
        ),
      );

  @override
  Future<void> setStatus(String id, ResetPlanStatus status) =>
      (_db.update(_db.resetPlans)..where((t) => t.id.equals(id))).write(
        ResetPlansCompanion(
          status: Value(status),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.resetPlans)..where((t) => t.id.equals(id))).go();

  ResetPlan _toDomain(ResetPlanRow row) => ResetPlan(
    id: row.id,
    title: row.title,
    description: row.description,
    durationDays: row.durationDays,
    startDate: AppDateUtils.parseDateKey(row.startDateKey),
    habitIds: row.habitIds.isEmpty ? const [] : row.habitIds.split(','),
    status: row.status,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
