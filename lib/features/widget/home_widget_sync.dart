import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../app/providers.dart';
import '../today/today_providers.dart';

/// Pushes today's progress to the Android home-screen widget whenever the
/// underlying data changes. Invisible; a no-op on other platforms and in
/// tests (every plugin call is guarded).
class HomeWidgetSyncListener extends ConsumerStatefulWidget {
  const HomeWidgetSyncListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HomeWidgetSyncListener> createState() =>
      _HomeWidgetSyncListenerState();
}

class _HomeWidgetSyncListenerState
    extends ConsumerState<HomeWidgetSyncListener> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _push());
  }

  void _schedulePush() {
    // Coalesce bursts of provider updates into one write per frame.
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _push();
    });
  }

  Future<void> _push() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final todayKey = ref.read(todayKeyProvider);
      final progress = ref.read(todayProgressProvider);
      final habits = ref.read(todayHabitsProvider);
      final entries = ref.read(todayEntryByHabitProvider);
      final streak = ref.read(overallStreakProvider);

      final lines = [
        for (final habit in habits.take(3))
          '${(entries[habit.id]?.completed ?? false) ? '✓' : '○'}  '
              '${habit.name}',
      ].join('\n');

      await HomeWidget.saveWidgetData<String>('widget_date', todayKey);
      await HomeWidget.saveWidgetData<int>('widget_done', progress.completed);
      await HomeWidget.saveWidgetData<int>('widget_total', progress.total);
      await HomeWidget.saveWidgetData<String>('widget_lines', lines);
      await HomeWidget.saveWidgetData<String>(
        'widget_streak',
        streak.current > 0 ? '🔥 ${streak.current}' : '',
      );
      await HomeWidget.updateWidget(androidName: 'ResetWidgetProvider');
    } catch (e) {
      // Widget updates must never affect the app proper.
      debugPrint('Home widget sync skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(todayProgressProvider, (_, _) => _schedulePush())
      ..listen(todayHabitsProvider, (_, _) => _schedulePush())
      ..listen(todayKeyProvider, (_, _) => _schedulePush());
    return widget.child;
  }
}
