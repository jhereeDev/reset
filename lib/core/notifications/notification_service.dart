import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/habits/domain/habit.dart';

/// Abstraction over local notifications so the app keeps working when the
/// plugin is unavailable (tests, denied permission, unsupported platform).
abstract interface class NotificationService {
  Future<void> init();

  /// Returns true if permission is granted (or not required).
  Future<bool> requestPermission();

  Future<void> scheduleHabitReminder(Habit habit);

  Future<void> cancelHabitReminder(String habitId);

  /// General daily nudge at [minutesSinceMidnight].
  Future<void> scheduleDailyReminder(int minutesSinceMidnight);

  Future<void> cancelDailyReminder();
}

/// No-op implementation used in tests and as a safe fallback.
class NoopNotificationService implements NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleHabitReminder(Habit habit) async {}

  @override
  Future<void> cancelHabitReminder(String habitId) async {}

  @override
  Future<void> scheduleDailyReminder(int minutesSinceMidnight) async {}

  @override
  Future<void> cancelDailyReminder() async {}
}

class LocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _generalId = 0;

  /// Stable per-habit notification id derived from the habit's uuid.
  static int habitNotificationId(String habitId) =>
      1000 + (habitId.hashCode & 0x3FFFFFFF);

  @override
  Future<void> init() async {
    try {
      tz_data.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name.identifier));
      } catch (_) {
        // Fall back to the package default (UTC); reminders still fire,
        // possibly offset — better than crashing on exotic timezone ids.
      }
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: initSettings);
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
      _ready = false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> scheduleHabitReminder(Habit habit) async {
    final minutes = habit.reminderMinutes;
    if (!_ready || minutes == null || !habit.isActive) {
      await cancelHabitReminder(habit.id);
      return;
    }
    try {
      await _plugin.zonedSchedule(
        id: habitNotificationId(habit.id),
        title: habit.name,
        body:
            'A little progress today: ${habit.targetLabel}. You\'ve got this!',
        scheduledDate: _nextInstanceOf(minutes),
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Could not schedule reminder for ${habit.name}: $e');
    }
  }

  @override
  Future<void> cancelHabitReminder(String habitId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: habitNotificationId(habitId));
    } catch (_) {}
  }

  @override
  Future<void> scheduleDailyReminder(int minutesSinceMidnight) async {
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id: _generalId,
        title: 'Time for a reset check-in',
        body: 'A few small wins are waiting for you today.',
        scheduledDate: _nextInstanceOf(minutesSinceMidnight),
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Could not schedule daily reminder: $e');
    }
  }

  @override
  Future<void> cancelDailyReminder() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _generalId);
    } catch (_) {}
  }

  NotificationDetails _details() => const NotificationDetails(
    android: AndroidNotificationDetails(
      'reset_reminders',
      'Habit reminders',
      channelDescription: 'Daily reminders for your habits',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  tz.TZDateTime _nextInstanceOf(int minutesSinceMidnight) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutesSinceMidnight ~/ 60,
      minutesSinceMidnight % 60,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
