import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utilities/app_date_utils.dart';
import '../providers/preferences_providers.dart';

/// Serializes all local data to a JSON string the user can copy/back up.
Future<String> exportAllData(Ref ref) async {
  final habits = await ref.read(habitRepositoryProvider).watchAll().first;
  final entries = await ref.read(habitEntryRepositoryProvider).watchAll().first;
  final plans = await ref.read(resetPlanRepositoryProvider).watchAll().first;
  final prefs = ref.read(preferencesProvider);

  final payload = {
    'app': 'Reset',
    'version': 1,
    'preferences': {
      'displayName': prefs.displayName,
      'selectedGoals': prefs.selectedGoals,
      'reminderMinutes': prefs.reminderMinutes,
      'weekStartDay': prefs.weekStartDay,
      'themeMode': prefs.themeMode.name,
    },
    'habits': [
      for (final h in habits)
        {
          'id': h.id,
          'name': h.name,
          'description': h.description,
          'category': h.category.name,
          'iconId': h.iconId,
          'colorValue': h.colorValue,
          'trackingType': h.trackingType.name,
          'targetValue': h.targetValue,
          'unit': h.unit,
          'scheduleType': h.schedule.type.name,
          'weekdays': h.schedule.weekdays.toList(),
          'timesPerWeek': h.schedule.timesPerWeek,
          'reminderMinutes': h.reminderMinutes,
          'startDate': AppDateUtils.dateKey(h.startDate),
          'status': h.status.name,
          'sortOrder': h.sortOrder,
          'createdAt': h.createdAt.toIso8601String(),
          'updatedAt': h.updatedAt.toIso8601String(),
        },
    ],
    'entries': [
      for (final e in entries)
        {
          'id': e.id,
          'habitId': e.habitId,
          'date': e.dateKey,
          'value': e.value,
          'completed': e.completed,
          'createdAt': e.createdAt.toIso8601String(),
          'updatedAt': e.updatedAt.toIso8601String(),
        },
    ],
    'resetPlans': [
      for (final p in plans)
        {
          'id': p.id,
          'title': p.title,
          'description': p.description,
          'durationDays': p.durationDays,
          'startDate': AppDateUtils.dateKey(p.startDate),
          'endDate': AppDateUtils.dateKey(p.endDate),
          'habitIds': p.habitIds,
          'status': p.status.name,
        },
    ],
  };

  return const JsonEncoder.withIndent('  ').convert(payload);
}
