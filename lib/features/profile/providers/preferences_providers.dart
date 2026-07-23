import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/user_preferences.dart';

final preferencesProvider =
    NotifierProvider<PreferencesController, UserPreferences>(
      PreferencesController.new,
    );

class PreferencesController extends Notifier<UserPreferences> {
  static const _kName = 'prefs.displayName';
  static const _kGoals = 'prefs.selectedGoals';
  static const _kReminder = 'prefs.reminderMinutes';
  static const _kGeneralReminder = 'prefs.generalReminderEnabled';
  static const _kWeekStart = 'prefs.weekStartDay';
  static const _kTheme = 'prefs.themeMode';
  static const _kOnboarded = 'prefs.onboardingComplete';

  @override
  UserPreferences build() {
    final sp = ref.watch(sharedPreferencesProvider);
    return UserPreferences(
      displayName: sp.getString(_kName) ?? '',
      selectedGoals: sp.getStringList(_kGoals) ?? const [],
      reminderMinutes: sp.getInt(_kReminder) ?? 20 * 60,
      generalReminderEnabled: sp.getBool(_kGeneralReminder) ?? false,
      weekStartDay: sp.getInt(_kWeekStart) ?? DateTime.monday,
      themeMode:
          ThemeMode.values.asNameMap()[sp.getString(_kTheme)] ??
          ThemeMode.system,
      onboardingComplete: sp.getBool(_kOnboarded) ?? false,
    );
  }

  Future<void> _persist(UserPreferences p) async {
    state = p;
    final sp = ref.read(sharedPreferencesProvider);
    await sp.setString(_kName, p.displayName);
    await sp.setStringList(_kGoals, p.selectedGoals);
    await sp.setInt(_kReminder, p.reminderMinutes);
    await sp.setBool(_kGeneralReminder, p.generalReminderEnabled);
    await sp.setInt(_kWeekStart, p.weekStartDay);
    await sp.setString(_kTheme, p.themeMode.name);
    await sp.setBool(_kOnboarded, p.onboardingComplete);
  }

  Future<void> setDisplayName(String name) =>
      _persist(state.copyWith(displayName: name.trim()));

  Future<void> setGoals(List<String> goals) =>
      _persist(state.copyWith(selectedGoals: goals));

  Future<void> setThemeMode(ThemeMode mode) =>
      _persist(state.copyWith(themeMode: mode));

  Future<void> setWeekStartDay(int day) =>
      _persist(state.copyWith(weekStartDay: day));

  Future<void> setReminderMinutes(int minutes) async {
    await _persist(state.copyWith(reminderMinutes: minutes));
    await _syncGeneralReminder();
  }

  Future<void> setGeneralReminderEnabled(bool enabled) async {
    await _persist(state.copyWith(generalReminderEnabled: enabled));
    await _syncGeneralReminder();
  }

  Future<void> _syncGeneralReminder() async {
    final notifications = ref.read(notificationServiceProvider);
    if (state.generalReminderEnabled) {
      await notifications.requestPermission();
      await notifications.scheduleDailyReminder(state.reminderMinutes);
    } else {
      await notifications.cancelDailyReminder();
    }
  }

  Future<void> completeOnboarding() =>
      _persist(state.copyWith(onboardingComplete: true));

  /// Wipes preferences (used by "Reset app data").
  Future<void> resetAll() async {
    final sp = ref.read(sharedPreferencesProvider);
    for (final key in [
      _kName,
      _kGoals,
      _kReminder,
      _kGeneralReminder,
      _kWeekStart,
      _kTheme,
      _kOnboarded,
    ]) {
      await sp.remove(key);
    }
    state = const UserPreferences();
  }
}
