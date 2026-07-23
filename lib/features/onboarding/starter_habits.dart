import '../habits/domain/habit.dart';
import '../reset/preset_plans.dart';

/// Starter habits offered during onboarding. Reuses [PlanHabitTemplate]
/// since the shape (template → real habit) is identical.
abstract final class StarterHabits {
  static const List<PlanHabitTemplate> all = [
    PlanHabitTemplate(
      name: 'Push-ups',
      category: HabitCategory.fitness,
      iconId: 'fitness',
      trackingType: TrackingType.count,
      targetValue: 100,
    ),
    PlanHabitTemplate(
      name: 'Walk',
      category: HabitCategory.fitness,
      iconId: 'walk',
      trackingType: TrackingType.steps,
      targetValue: 10000,
    ),
    PlanHabitTemplate(
      name: 'Read one chapter',
      category: HabitCategory.mind,
      iconId: 'book',
      trackingType: TrackingType.chapters,
      targetValue: 1,
    ),
    PlanHabitTemplate(
      name: 'Listen to a podcast',
      category: HabitCategory.mind,
      iconId: 'headphones',
      trackingType: TrackingType.count,
      targetValue: 1,
      unit: 'episodes',
    ),
    PlanHabitTemplate(
      name: 'Eat fruit',
      category: HabitCategory.health,
      iconId: 'fruit',
      trackingType: TrackingType.servings,
      targetValue: 2,
    ),
    PlanHabitTemplate(
      name: 'Make the bed',
      category: HabitCategory.discipline,
      iconId: 'bed',
      trackingType: TrackingType.yesNo,
      targetValue: 1,
    ),
  ];

  /// Difficulty multipliers applied to numeric starter targets.
  static double scaleTarget(PlanHabitTemplate t, Difficulty difficulty) {
    if (t.trackingType.isBinary || t.targetValue <= 2) return t.targetValue;
    final scaled = t.targetValue * difficulty.multiplier;
    // Round to a friendly number of the same magnitude.
    if (scaled >= 1000) return (scaled / 500).round() * 500;
    if (scaled >= 20) return (scaled / 5).round() * 5;
    return scaled.roundToDouble().clamp(1, double.infinity);
  }
}

enum Difficulty {
  gentle('Gentle', 'Ease in with lighter targets', 0.5),
  steady('Steady', 'The recommended baseline', 1.0),
  allIn('All in', 'Push yourself with bigger targets', 1.5);

  const Difficulty(this.label, this.description, this.multiplier);

  final String label;
  final String description;
  final double multiplier;
}
