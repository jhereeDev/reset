import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utilities/app_date_utils.dart';
import '../habits/providers/habit_providers.dart';
import '../reset/domain/reset_plan.dart';
import 'badge_defs.dart';

/// All reset plans (any status) — badge evaluation needs completed ones.
final allPlansProvider = StreamProvider<List<ResetPlan>>(
  (ref) => ref.watch(resetPlanRepositoryProvider).watchAll(),
);

/// Badge ids currently unlocked, derived live from data.
final unlockedBadgesProvider = Provider<Set<String>>((ref) {
  final todayKey = ref.watch(todayKeyProvider);
  final habits = ref.watch(allHabitsProvider).value ?? const [];
  final entriesByHabit = ref.watch(entriesByHabitProvider);
  final plans = ref.watch(allPlansProvider).value ?? const [];
  return BadgeEngine.unlocked(
    habits: habits,
    entriesByHabit: entriesByHabit,
    plans: plans,
    today: AppDateUtils.parseDateKey(todayKey),
  );
});

/// Badge ids the user has already been congratulated for. Persisted so each
/// trophy is celebrated exactly once.
final seenBadgesProvider = NotifierProvider<SeenBadgesController, Set<String>>(
  SeenBadgesController.new,
);

class SeenBadgesController extends Notifier<Set<String>> {
  static const _key = 'badges.seen';

  @override
  Set<String> build() {
    final sp = ref.watch(sharedPreferencesProvider);
    return (sp.getStringList(_key) ?? const []).toSet();
  }

  Future<void> markSeen(Iterable<String> ids) async {
    state = {...state, ...ids};
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_key, state.toList());
  }
}

/// Unlocked but not yet celebrated.
final newBadgesProvider = Provider<Set<String>>((ref) {
  final unlocked = ref.watch(unlockedBadgesProvider);
  final seen = ref.watch(seenBadgesProvider);
  return unlocked.difference(seen);
});
