import 'reset_plan.dart';

abstract interface class ResetPlanRepository {
  Stream<ResetPlan?> watchActivePlan();

  Stream<List<ResetPlan>> watchAll();

  Future<void> insert(ResetPlan plan);

  Future<void> setStatus(String id, ResetPlanStatus status);

  Future<void> delete(String id);
}
