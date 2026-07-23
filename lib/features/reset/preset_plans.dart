import '../../core/theme/app_colors.dart';
import '../habits/domain/habit.dart';

/// A habit blueprint inside a preset plan. Converted to a real [Habit] when
/// the user starts the plan (after optional customization).
class PlanHabitTemplate {
  const PlanHabitTemplate({
    required this.name,
    required this.category,
    required this.iconId,
    required this.trackingType,
    required this.targetValue,
    String? unit,
  }) : unit = unit ?? '';

  final String name;
  final HabitCategory category;
  final String iconId;
  final TrackingType trackingType;
  final double targetValue;
  final String unit;

  String get effectiveUnit => unit.isNotEmpty ? unit : trackingType.defaultUnit;

  PlanHabitTemplate withTarget(double target) => PlanHabitTemplate(
    name: name,
    category: category,
    iconId: iconId,
    trackingType: trackingType,
    targetValue: target,
    unit: unit,
  );
}

class PresetPlan {
  const PresetPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.durationDays,
    required this.habits,
  });

  final String id;
  final String title;
  final String description;
  final int durationDays;
  final List<PlanHabitTemplate> habits;
}

abstract final class PresetPlans {
  static const List<PresetPlan> all = [
    PresetPlan(
      id: 'restart-7',
      title: '7-Day Restart',
      description:
          'One week of tiny, doable wins to get you moving again. Perfect after a rough patch.',
      durationDays: 7,
      habits: [
        PlanHabitTemplate(
          name: 'Make the bed',
          category: HabitCategory.discipline,
          iconId: 'bed',
          trackingType: TrackingType.yesNo,
          targetValue: 1,
        ),
        PlanHabitTemplate(
          name: 'Drink water',
          category: HabitCategory.health,
          iconId: 'water',
          trackingType: TrackingType.servings,
          targetValue: 8,
          unit: 'glasses',
        ),
        PlanHabitTemplate(
          name: '10-minute walk',
          category: HabitCategory.fitness,
          iconId: 'walk',
          trackingType: TrackingType.duration,
          targetValue: 10,
        ),
      ],
    ),
    PresetPlan(
      id: 'discipline-21',
      title: '21-Day Discipline Reset',
      description:
          'Three weeks to rebuild structure: move daily, read daily, and protect your sleep.',
      durationDays: 21,
      habits: [
        PlanHabitTemplate(
          name: 'Morning exercise',
          category: HabitCategory.fitness,
          iconId: 'fitness',
          trackingType: TrackingType.duration,
          targetValue: 20,
        ),
        PlanHabitTemplate(
          name: 'Read',
          category: HabitCategory.mind,
          iconId: 'book',
          trackingType: TrackingType.pages,
          targetValue: 10,
        ),
        PlanHabitTemplate(
          name: 'In bed before 11 PM',
          category: HabitCategory.discipline,
          iconId: 'sleep',
          trackingType: TrackingType.yesNo,
          targetValue: 1,
        ),
        PlanHabitTemplate(
          name: 'No social media after 9 PM',
          category: HabitCategory.discipline,
          iconId: 'no_phone',
          trackingType: TrackingType.yesNo,
          targetValue: 1,
        ),
      ],
    ),
    PresetPlan(
      id: 'better-me-30',
      title: '30-Day Better Me',
      description:
          'A full month of momentum: fitness, mind and health working together.',
      durationDays: 30,
      habits: [
        PlanHabitTemplate(
          name: 'Push-ups',
          category: HabitCategory.fitness,
          iconId: 'fitness',
          trackingType: TrackingType.count,
          targetValue: 50,
        ),
        PlanHabitTemplate(
          name: 'Walk',
          category: HabitCategory.fitness,
          iconId: 'walk',
          trackingType: TrackingType.steps,
          targetValue: 8000,
        ),
        PlanHabitTemplate(
          name: 'Read one chapter',
          category: HabitCategory.mind,
          iconId: 'book',
          trackingType: TrackingType.chapters,
          targetValue: 1,
        ),
        PlanHabitTemplate(
          name: 'Eat fruit',
          category: HabitCategory.health,
          iconId: 'fruit',
          trackingType: TrackingType.servings,
          targetValue: 2,
        ),
        PlanHabitTemplate(
          name: '10 minutes of calm',
          category: HabitCategory.mind,
          iconId: 'meditate',
          trackingType: TrackingType.duration,
          targetValue: 10,
        ),
      ],
    ),
  ];

  /// Default accent for plan habit cards, keyed by category.
  static int colorFor(HabitCategory category) => switch (category) {
    HabitCategory.fitness => AppColors.fitness.toARGB32(),
    HabitCategory.health => AppColors.health.toARGB32(),
    HabitCategory.mind => AppColors.mind.toARGB32(),
    HabitCategory.discipline => AppColors.discipline.toARGB32(),
    HabitCategory.productivity => AppColors.productivity.toARGB32(),
    HabitCategory.personalCare => AppColors.personalCare.toARGB32(),
  };
}
