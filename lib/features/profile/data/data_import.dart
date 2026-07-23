import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/utilities/app_date_utils.dart';
import '../../habits/domain/habit.dart';
import '../../habits/domain/habit_entry.dart';
import '../../reset/domain/reset_plan.dart';
import '../providers/preferences_providers.dart';

/// Thrown when the payload is not a valid Reset export.
class ImportFormatException implements Exception {
  ImportFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum ImportMode {
  /// Existing data is wiped and fully replaced by the payload.
  replace,

  /// Payload rows are combined with existing data; on conflict the row with
  /// the newer `updatedAt` wins. Entries conflict on (habit, date).
  merge,
}

class ImportResult {
  const ImportResult({
    required this.habits,
    required this.entries,
    required this.plans,
  });

  final int habits;
  final int entries;
  final int plans;

  String describe() => '$habits habits, $entries entries, $plans plans';
}

final dataImportServiceProvider = Provider<DataImportService>(
  DataImportService.new,
);

/// Restores data from the JSON produced by `exportAllData` (schema v1).
class DataImportService {
  DataImportService(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  /// Parses and validates; throws [ImportFormatException] on bad input.
  Future<ImportResult> importJson(String source, ImportMode mode) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw ImportFormatException('That is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != 'Reset') {
      throw ImportFormatException('This does not look like a Reset export.');
    }
    final version = decoded['version'];
    if (version is! int || version < 1 || version > 1) {
      throw ImportFormatException(
        'Unsupported export version "$version". This app understands '
        'version 1.',
      );
    }

    final habits = _parseHabits(decoded['habits']);
    final entries = _parseEntries(decoded['entries']);
    final plans = _parsePlans(decoded['resetPlans']);

    if (mode == ImportMode.replace) {
      await _ref.read(databaseProvider).clearAllData();
    }

    await _applyHabits(habits, mode);
    final appliedEntries = await _applyEntries(entries, habits, mode);
    await _applyPlans(plans, mode);
    await _applyPreferences(decoded['preferences']);

    return ImportResult(
      habits: habits.length,
      entries: appliedEntries,
      plans: plans.length,
    );
  }

  // ---- parsing -----------------------------------------------------------

  List<Habit> _parseHabits(Object? raw) {
    if (raw is! List) {
      throw ImportFormatException('The export is missing its habits list.');
    }
    return [
      for (final item in raw.whereType<Map<String, dynamic>>())
        Habit(
          id: (item['id'] as String?) ?? _uuid.v4(),
          name: _string(item, 'name'),
          description: item['description'] as String? ?? '',
          category:
              HabitCategory.values.asNameMap()[item['category']] ??
              HabitCategory.discipline,
          iconId: item['iconId'] as String? ?? 'star',
          colorValue: item['colorValue'] as int? ?? 0xFF5A4FF3,
          trackingType:
              TrackingType.values.asNameMap()[item['trackingType']] ??
              TrackingType.yesNo,
          targetValue: _positiveDouble(item['targetValue'], fallback: 1),
          unit: item['unit'] as String? ?? '',
          schedule: HabitSchedule(
            type:
                ScheduleType.values.asNameMap()[item['scheduleType']] ??
                ScheduleType.daily,
            weekdays: {
              for (final d in (item['weekdays'] as List? ?? const []))
                if (d is int && d >= DateTime.monday && d <= DateTime.sunday) d,
            },
            timesPerWeek: item['timesPerWeek'] as int? ?? 0,
          ),
          reminderMinutes: item['reminderMinutes'] as int?,
          startDate: _dateKey(item['startDate']),
          status:
              HabitStatus.values.asNameMap()[item['status']] ??
              HabitStatus.active,
          sortOrder: item['sortOrder'] as int? ?? 0,
          createdAt: _timestamp(item['createdAt']),
          updatedAt: _timestamp(item['updatedAt']),
        ),
    ];
  }

  List<HabitEntry> _parseEntries(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw.whereType<Map<String, dynamic>>())
        HabitEntry(
          id: (item['id'] as String?) ?? _uuid.v4(),
          habitId: _string(item, 'habitId'),
          dateKey: _string(item, 'date'),
          value: _positiveDouble(item['value'], fallback: 0),
          completed: item['completed'] as bool? ?? false,
          createdAt: _timestamp(item['createdAt']),
          updatedAt: _timestamp(item['updatedAt']),
        ),
    ];
  }

  List<ResetPlan> _parsePlans(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw.whereType<Map<String, dynamic>>())
        ResetPlan(
          id: (item['id'] as String?) ?? _uuid.v4(),
          title: _string(item, 'title'),
          description: item['description'] as String? ?? '',
          durationDays: (item['durationDays'] as int?)?.clamp(1, 365) ?? 7,
          startDate: _dateKey(item['startDate']),
          habitIds: [
            for (final id in (item['habitIds'] as List? ?? const []))
              if (id is String) id,
          ],
          status:
              ResetPlanStatus.values.asNameMap()[item['status']] ??
              ResetPlanStatus.active,
          createdAt: _timestamp(item['createdAt']),
          updatedAt: _timestamp(item['updatedAt']),
        ),
    ];
  }

  String _string(Map<String, dynamic> item, String key) {
    final value = item[key];
    if (value is! String || value.isEmpty) {
      throw ImportFormatException('A record is missing its "$key" field.');
    }
    return value;
  }

  double _positiveDouble(Object? value, {required double fallback}) {
    final parsed = value is num ? value.toDouble() : fallback;
    return parsed < 0 ? 0 : parsed;
  }

  DateTime _dateKey(Object? value) {
    if (value is String) {
      try {
        return AppDateUtils.parseDateKey(value);
      } catch (_) {}
    }
    return AppDateUtils.today();
  }

  DateTime _timestamp(Object? value) =>
      (value is String ? DateTime.tryParse(value) : null) ?? DateTime.now();

  // ---- applying ----------------------------------------------------------

  Future<void> _applyHabits(List<Habit> habits, ImportMode mode) async {
    final repo = _ref.read(habitRepositoryProvider);
    if (mode == ImportMode.replace) {
      await repo.upsertAll(habits);
      return;
    }
    for (final habit in habits) {
      final existing = await repo.getById(habit.id);
      if (existing == null || !existing.updatedAt.isAfter(habit.updatedAt)) {
        await repo.upsert(habit);
      }
    }
  }

  /// Returns the number of entries actually written. In merge mode an entry
  /// conflicts on (habit, date) — ids differ between installs — and the
  /// newer `updatedAt` wins.
  Future<int> _applyEntries(
    List<HabitEntry> entries,
    List<Habit> habits,
    ImportMode mode,
  ) async {
    final habitIds = {
      ...habits.map((h) => h.id),
      // In merge mode entries may belong to habits that already exist
      // locally but were not part of the payload.
      if (mode == ImportMode.merge)
        ...(await _ref.read(habitRepositoryProvider).watchAll().first).map(
          (h) => h.id,
        ),
    };
    final db = _ref.read(databaseProvider);
    final entryRepo = _ref.read(habitEntryRepositoryProvider);

    var written = 0;
    for (final entry in entries) {
      if (!habitIds.contains(entry.habitId)) continue; // orphan — skip
      final existing = await entryRepo.getEntry(entry.habitId, entry.dateKey);
      if (existing == null) {
        await db.importEntryRow(entry);
        written++;
      } else if (mode == ImportMode.merge &&
          entry.updatedAt.isAfter(existing.updatedAt)) {
        await db.updateEntryRow(existing.id, entry);
        written++;
      } else if (mode == ImportMode.replace) {
        // replace wiped the table first, so this branch means the payload
        // itself contained a duplicate (habit, date) — keep the first.
      }
    }
    return written;
  }

  Future<void> _applyPlans(List<ResetPlan> plans, ImportMode mode) async {
    final repo = _ref.read(resetPlanRepositoryProvider);
    for (final plan in plans) {
      await repo.insert(plan); // insertOnConflictUpdate by id
    }
  }

  Future<void> _applyPreferences(Object? raw) async {
    if (raw is! Map<String, dynamic>) return;
    final prefs = _ref.read(preferencesProvider.notifier);
    final name = raw['displayName'];
    if (name is String && name.isNotEmpty) await prefs.setDisplayName(name);
    final goals = raw['selectedGoals'];
    if (goals is List) {
      await prefs.setGoals([
        for (final g in goals)
          if (g is String && HabitCategory.values.asNameMap().containsKey(g)) g,
      ]);
    }
    final reminder = raw['reminderMinutes'];
    if (reminder is int && reminder >= 0 && reminder < 24 * 60) {
      await prefs.setReminderMinutes(reminder);
    }
    final weekStart = raw['weekStartDay'];
    if (weekStart == DateTime.monday || weekStart == DateTime.sunday) {
      await prefs.setWeekStartDay(weekStart as int);
    }
    final theme = raw['themeMode'];
    final mode = ThemeMode.values.asNameMap()[theme];
    if (mode != null) await prefs.setThemeMode(mode);
  }
}
