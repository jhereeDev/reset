import 'package:flutter/material.dart';

/// Locally stored user settings. Persisted via SharedPreferences.
class UserPreferences {
  const UserPreferences({
    this.displayName = '',
    this.selectedGoals = const [],
    this.reminderMinutes = 20 * 60, // 20:00
    this.generalReminderEnabled = false,
    this.weekStartDay = DateTime.monday,
    this.themeMode = ThemeMode.system,
    this.onboardingComplete = false,
  });

  final String displayName;

  /// HabitCategory enum names the user chose during onboarding.
  final List<String> selectedGoals;

  /// Preferred general reminder time, minutes since midnight.
  final int reminderMinutes;
  final bool generalReminderEnabled;

  /// DateTime.monday or DateTime.sunday.
  final int weekStartDay;
  final ThemeMode themeMode;
  final bool onboardingComplete;

  TimeOfDay get reminderTime =>
      TimeOfDay(hour: reminderMinutes ~/ 60, minute: reminderMinutes % 60);

  UserPreferences copyWith({
    String? displayName,
    List<String>? selectedGoals,
    int? reminderMinutes,
    bool? generalReminderEnabled,
    int? weekStartDay,
    ThemeMode? themeMode,
    bool? onboardingComplete,
  }) {
    return UserPreferences(
      displayName: displayName ?? this.displayName,
      selectedGoals: selectedGoals ?? this.selectedGoals,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      generalReminderEnabled:
          generalReminderEnabled ?? this.generalReminderEnabled,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      themeMode: themeMode ?? this.themeMode,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }
}
