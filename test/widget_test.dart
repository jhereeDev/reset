import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reset/app/app.dart';
import 'package:reset/app/providers.dart';
import 'package:reset/core/database/app_database.dart';
import 'package:reset/core/notifications/notification_service.dart';
import 'package:reset/core/utilities/app_date_utils.dart';
import 'package:reset/features/habits/domain/habit.dart';
import 'package:shared_preferences/shared_preferences.dart';

Habit makeHabit(String id, String name, TrackingType type, double target) {
  final now = DateTime.now();
  return Habit(
    id: id,
    name: name,
    category: HabitCategory.discipline,
    iconId: 'bed',
    colorValue: 0xFF3B82F6,
    trackingType: type,
    targetValue: target,
    unit: type.defaultUnit,
    schedule: const HabitSchedule.daily(),
    startDate: AppDateUtils.today(),
    createdAt: now,
    updatedAt: now,
  );
}

// Note: this test uses bounded pump() calls instead of pumpAndSettle —
// the screen hosts indefinitely-animating implicit animations while streams
// warm up, which makes pumpAndSettle spin until its 10-minute timeout.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('Today flow: see habit, complete it, progress updates', (
    tester,
  ) async {
    // Phone-sized viewport: the default 800x600 crams the layout enough that
    // floating snackbars overlap the habit card's tap targets.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'prefs.onboardingComplete': true,
      'prefs.displayName': 'Sam',
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          NoopNotificationService(),
        ),
      ],
    );

    final habit = makeHabit('h1', 'Make the bed', TrackingType.yesNo, 1);
    await container.read(habitRepositoryProvider).upsert(habit);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const ResetApp()),
    );
    await settle(tester);

    // Today screen shows greeting and the habit card with 0/1 progress.
    expect(find.textContaining('Sam'), findsOneWidget);
    expect(find.text('Make the bed'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);

    // Complete the habit via its check control.
    await tester.tap(find.bySemanticsLabel('Mark Make the bed as done'));
    await settle(tester);

    expect(find.text('1/1'), findsOneWidget);

    // First completion unlocks the "First Win" trophy — dismiss the dialog.
    expect(find.text('Trophy unlocked!'), findsOneWidget);
    expect(find.text('First Win'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Keep going 💪'));
    await settle(tester);
    await settle(tester);
    expect(find.text('Trophy unlocked!'), findsNothing);

    // Completion is reversible: toggling the check control undoes it.
    await tester.tap(find.bySemanticsLabel('Mark Make the bed as not done'));
    await settle(tester);
    expect(find.text('0/1'), findsOneWidget);

    // Let the snackbar's display timer elapse fully before teardown.
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);

    // Tear down inside the test body: unmount the tree, dispose the container
    // (cancels the midnight-rollover timer before the pending-timer check),
    // flush drift's cleanup microtasks, then close the database with real
    // async — drift's close() never completes inside the fake-async zone.
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
    container.dispose();
    await settle(tester);
    await tester.runAsync(db.close);
  });
}
