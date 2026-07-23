import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/app_database.dart';
import '../core/notifications/notification_service.dart';
import '../core/steps/step_source.dart';
import '../core/utilities/app_date_utils.dart';
import '../features/habits/data/drift_habit_entry_repository.dart';
import '../features/habits/data/drift_habit_repository.dart';
import '../features/habits/domain/habit_entry_repository.dart';
import '../features/habits/domain/habit_repository.dart';
import '../features/reset/data/drift_reset_plan_repository.dart';
import '../features/reset/domain/reset_plan_repository.dart';

/// Overridden in main() with the preloaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main()'),
);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => DriftHabitRepository(ref.watch(databaseProvider)),
);

final habitEntryRepositoryProvider = Provider<HabitEntryRepository>(
  (ref) => DriftHabitEntryRepository(ref.watch(databaseProvider)),
);

final resetPlanRepositoryProvider = Provider<ResetPlanRepository>(
  (ref) => DriftResetPlanRepository(ref.watch(databaseProvider)),
);

/// Overridden with [NoopNotificationService] in tests.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => LocalNotificationService(),
);

final stepSourceProvider = Provider<StepSource>(
  (ref) => const ManualStepSource(),
);

/// Today's canonical date key. Re-evaluates itself just after local midnight
/// so the Today screen rolls over without a restart.
final todayKeyProvider = Provider<String>((ref) {
  final now = DateTime.now();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(
    nextMidnight.difference(now) + const Duration(seconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return AppDateUtils.dateKey(now);
});
