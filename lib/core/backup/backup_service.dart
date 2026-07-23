import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/profile/data/data_export.dart';
import '../../features/profile/data/data_import.dart';
import '../../features/profile/providers/preferences_providers.dart';
import '../utilities/app_date_utils.dart';

/// Where backups live. Overridden in tests with a temp directory.
final backupDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => () async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'backups'));
  },
);

final backupServiceProvider = Provider<BackupService>(BackupService.new);

/// Most recent backup on disk, or null. Errors resolve to null so a broken
/// filesystem can never block onboarding.
final latestBackupProvider = FutureProvider<BackupInfo?>((ref) async {
  try {
    return await ref.watch(backupServiceProvider).latestBackup();
  } catch (_) {
    return null;
  }
});

class BackupInfo {
  const BackupInfo({required this.file, required this.dateKey});

  final File file;

  /// The local calendar day the backup captured, e.g. `2026-07-24`.
  final String dateKey;

  DateTime get date => AppDateUtils.parseDateKey(dateKey);
}

/// Writes a full JSON export to local app storage once per day and keeps the
/// most recent [keep] snapshots. Backups survive app updates (not uninstalls
/// on Android without allowBackup; iOS keeps app documents until uninstall).
class BackupService {
  BackupService(this._ref);

  static const keep = 7;
  static const _prefix = 'reset-backup-';

  final Ref _ref;

  Future<Directory> _dir() async {
    final dir = await _ref.read(backupDirectoryProvider)();
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Called on app start. Silently writes today's backup if it doesn't exist
  /// yet and the user has finished onboarding. Never throws.
  Future<void> runDailyBackup() async {
    try {
      if (!_ref.read(preferencesProvider).onboardingComplete) return;
      final todayKey = AppDateUtils.dateKey(DateTime.now());
      final dir = await _dir();
      final target = File(p.join(dir.path, '$_prefix$todayKey.json'));
      if (await target.exists()) return;
      await backupNow();
    } catch (e) {
      debugPrint('Daily backup skipped: $e');
    }
  }

  /// Writes a backup for today (overwriting today's earlier one) and prunes
  /// old snapshots. Returns the file written.
  Future<File> backupNow() async {
    final todayKey = AppDateUtils.dateKey(DateTime.now());
    final dir = await _dir();
    final file = File(p.join(dir.path, '$_prefix$todayKey.json'));
    final json = await exportAllData(_ref);
    await file.writeAsString(json, flush: true);
    await _prune(dir);
    return file;
  }

  Future<void> _prune(Directory dir) async {
    final backups = await _list(dir);
    if (backups.length <= keep) return;
    // _list sorts newest first; delete the tail.
    for (final old in backups.skip(keep)) {
      try {
        await old.file.delete();
      } catch (_) {}
    }
  }

  /// Newest first.
  Future<List<BackupInfo>> listBackups() async => _list(await _dir());

  Future<BackupInfo?> latestBackup() async {
    final backups = await listBackups();
    return backups.isEmpty ? null : backups.first;
  }

  Future<ImportResult> restore(BackupInfo backup, ImportMode mode) async {
    final json = await backup.file.readAsString();
    return _ref.read(dataImportServiceProvider).importJson(json, mode);
  }

  Future<List<BackupInfo>> _list(Directory dir) async {
    if (!await dir.exists()) return const [];
    final infos = <BackupInfo>[];
    await for (final item in dir.list()) {
      if (item is! File) continue;
      final name = p.basename(item.path);
      if (!name.startsWith(_prefix) || !name.endsWith('.json')) continue;
      final key = name.substring(_prefix.length, name.length - '.json'.length);
      try {
        AppDateUtils.parseDateKey(key); // validate
        infos.add(BackupInfo(file: item, dateKey: key));
      } catch (_) {}
    }
    infos.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return infos;
  }
}

/// Quick, non-parsing peek used by the onboarding restore card.
Future<int?> countHabitsInBackup(BackupInfo backup) async {
  try {
    final decoded = jsonDecode(await backup.file.readAsString());
    final habits = (decoded as Map<String, dynamic>)['habits'];
    return habits is List ? habits.length : null;
  } catch (_) {
    return null;
  }
}
