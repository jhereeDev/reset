import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reset/app/providers.dart';
import 'package:reset/core/backup/backup_service.dart';
import 'package:reset/core/database/app_database.dart';
import 'package:reset/core/notifications/notification_service.dart';
import 'package:reset/features/habits/domain/habit.dart';
import 'package:reset/features/profile/data/data_export.dart';
import 'package:reset/features/profile/data/data_import.dart';
import 'package:shared_preferences/shared_preferences.dart';

Habit makeHabit({
  String id = 'h1',
  String name = 'Push-ups',
  double target = 100,
  DateTime? updatedAt,
}) {
  final now = DateTime(2026, 7, 1, 12);
  return Habit(
    id: id,
    name: name,
    category: HabitCategory.fitness,
    iconId: 'fitness',
    colorValue: 0xFFF97316,
    trackingType: TrackingType.count,
    targetValue: target,
    unit: 'reps',
    schedule: const HabitSchedule.daily(),
    startDate: DateTime(2026, 7, 1),
    createdAt: now,
    updatedAt: updatedAt ?? now,
  );
}

Future<ProviderContainer> makeContainer(Directory backupDir) async {
  SharedPreferences.setMockInitialValues({'prefs.onboardingComplete': true});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      notificationServiceProvider.overrideWithValue(NoopNotificationService()),
      backupDirectoryProvider.overrideWithValue(() async => backupDir),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await db.close();
  });
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reset_backup_test');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('export/import round-trip', () {
    test('replace import reproduces habits, entries and completion', () async {
      final source = await makeContainer(tempDir);
      final habit = makeHabit();
      await source.read(habitRepositoryProvider).upsert(habit);
      await source
          .read(habitEntryRepositoryProvider)
          .setValue(habit, '2026-07-01', 100);
      await source
          .read(habitEntryRepositoryProvider)
          .setValue(habit, '2026-07-02', 40);

      final json = await exportAllData(source.read(_refProvider));

      final target = await makeContainer(tempDir);
      final result = await target
          .read(dataImportServiceProvider)
          .importJson(json, ImportMode.replace);

      expect(result.habits, 1);
      expect(result.entries, 2);

      final imported = await target.read(habitRepositoryProvider).getById('h1');
      expect(imported!.name, 'Push-ups');
      expect(imported.targetValue, 100);

      final entry = await target
          .read(habitEntryRepositoryProvider)
          .getEntry('h1', '2026-07-01');
      expect(entry!.completed, isTrue);
      expect(entry.value, 100);
    });

    test('merge keeps the newer of conflicting entries', () async {
      final container = await makeContainer(tempDir);
      final habit = makeHabit();
      await container.read(habitRepositoryProvider).upsert(habit);
      // Local entry logged at 12:00 with value 40.
      await container
          .read(habitEntryRepositoryProvider)
          .setValue(habit, '2026-07-01', 40);

      // Imported payload has an OLDER entry (value 10) and a NEWER one for
      // another day.
      final payload = '''
{"app":"Reset","version":1,
 "habits":[],
 "entries":[
   {"id":"e-old","habitId":"h1","date":"2026-07-01","value":10,
    "completed":false,
    "createdAt":"2020-01-01T00:00:00.000",
    "updatedAt":"2020-01-01T00:00:00.000"},
   {"id":"e-new","habitId":"h1","date":"2026-07-02","value":100,
    "completed":true,
    "createdAt":"2030-01-01T00:00:00.000",
    "updatedAt":"2030-01-01T00:00:00.000"}
 ],
 "resetPlans":[]}
''';
      await container
          .read(dataImportServiceProvider)
          .importJson(payload, ImportMode.merge);

      final kept = await container
          .read(habitEntryRepositoryProvider)
          .getEntry('h1', '2026-07-01');
      expect(kept!.value, 40, reason: 'older imported entry must not win');

      final added = await container
          .read(habitEntryRepositoryProvider)
          .getEntry('h1', '2026-07-02');
      expect(added!.value, 100);
    });

    test('orphan entries and invalid payloads are rejected safely', () async {
      final container = await makeContainer(tempDir);

      expect(
        () => container
            .read(dataImportServiceProvider)
            .importJson('not json', ImportMode.merge),
        throwsA(isA<ImportFormatException>()),
      );
      expect(
        () => container
            .read(dataImportServiceProvider)
            .importJson('{"app":"Other","version":1}', ImportMode.merge),
        throwsA(isA<ImportFormatException>()),
      );

      // Orphan entry (no such habit) is skipped, not an error.
      final result = await container
          .read(dataImportServiceProvider)
          .importJson(
            '{"app":"Reset","version":1,"habits":[],'
            '"entries":[{"id":"x","habitId":"ghost","date":"2026-07-01",'
            '"value":5,"completed":false}],"resetPlans":[]}',
            ImportMode.merge,
          );
      expect(result.entries, 0);
    });
  });

  group('backup service', () {
    test('backupNow writes a restorable file and prunes to 7', () async {
      final container = await makeContainer(tempDir);
      final habit = makeHabit();
      await container.read(habitRepositoryProvider).upsert(habit);

      // Seed 9 stale backups.
      for (var i = 1; i <= 9; i++) {
        final day = i.toString().padLeft(2, '0');
        File(
          '${tempDir.path}/reset-backup-2026-06-$day.json',
        ).writeAsStringSync('{}');
      }

      final service = container.read(backupServiceProvider);
      await service.backupNow();

      final backups = await service.listBackups();
      expect(backups.length, BackupService.keep);
      // Newest first: today's real backup leads.
      expect(backups.first.file.path, contains('reset-backup-2026-07'));

      final restored = await makeContainer(tempDir);
      final result = await restored
          .read(backupServiceProvider)
          .restore(backups.first, ImportMode.replace);
      expect(result.habits, 1);
    });

    test('runDailyBackup writes once per day', () async {
      final container = await makeContainer(tempDir);
      final service = container.read(backupServiceProvider);

      await service.runDailyBackup();
      final first = await service.listBackups();
      expect(first.length, 1);
      final firstModified = first.single.file.lastModifiedSync();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await service.runDailyBackup();
      final second = await service.listBackups();
      expect(second.length, 1);
      expect(
        second.single.file.lastModifiedSync(),
        firstModified,
        reason: 'second run same day must be a no-op',
      );
    });
  });
}

/// Bridges ProviderContainer to the Ref-taking helpers.
final _refProvider = Provider<Ref>((ref) => ref);
