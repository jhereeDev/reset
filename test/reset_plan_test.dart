import 'package:flutter_test/flutter_test.dart';
import 'package:reset/features/reset/domain/reset_plan.dart';

void main() {
  ResetPlan makePlan({int duration = 21}) => ResetPlan(
    id: 'p1',
    title: 'Test plan',
    description: '',
    durationDays: duration,
    startDate: DateTime(2026, 7, 1),
    habitIds: const ['a', 'b'],
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 1),
  );

  group('reset plan day math', () {
    test('day number is 1-based and clamped', () {
      final plan = makePlan();
      expect(plan.dayNumberOn(DateTime(2026, 7, 1)), 1);
      expect(plan.dayNumberOn(DateTime(2026, 7, 10)), 10);
      expect(plan.dayNumberOn(DateTime(2026, 7, 21)), 21);
      // Past the end: clamped to the final day.
      expect(plan.dayNumberOn(DateTime(2026, 8, 15)), 21);
      // Before the start: clamped to day 1.
      expect(plan.dayNumberOn(DateTime(2026, 6, 20)), 1);
    });

    test('remaining days counts down to zero and stays there', () {
      final plan = makePlan();
      expect(plan.remainingDaysOn(DateTime(2026, 7, 1)), 20);
      expect(plan.remainingDaysOn(DateTime(2026, 7, 21)), 0);
      expect(plan.remainingDaysOn(DateTime(2026, 8, 1)), 0);
    });

    test('end date is inclusive', () {
      final plan = makePlan(duration: 7);
      expect(plan.endDate, DateTime(2026, 7, 7));
      expect(plan.isFinishedBy(DateTime(2026, 7, 7)), isFalse);
      expect(plan.isFinishedBy(DateTime(2026, 7, 8)), isTrue);
    });
  });
}
