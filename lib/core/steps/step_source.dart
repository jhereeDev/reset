/// Abstraction for step-count data sources.
///
/// The MVP ships with manual entry only ([ManualStepSource]). A future
/// release will add a `HealthStepSource` backed by Apple HealthKit (iOS) and
/// Android Health Connect — see the README for the integration plan. We do
/// not fake health data and we request no health permissions until that
/// integration is real.
abstract interface class StepSource {
  /// Human-readable name shown in settings ("Manual entry", "Health app").
  String get displayName;

  /// Whether this source can provide automatic step counts on this device.
  bool get isAvailable;

  /// Steps recorded for the local calendar day, or null when the source
  /// cannot provide them (manual mode always returns null — the user logs
  /// steps through the habit card instead).
  Future<int?> stepsForDate(DateTime date);
}

class ManualStepSource implements StepSource {
  const ManualStepSource();

  @override
  String get displayName => 'Manual entry';

  @override
  bool get isAvailable => true;

  @override
  Future<int?> stepsForDate(DateTime date) async => null;
}

/// Placeholder adapter for HealthKit / Health Connect.
///
/// Intentionally reports unavailable; wiring it up requires the `health`
/// package plus per-platform permission declarations, which are out of scope
/// for the offline MVP.
class HealthStepSource implements StepSource {
  const HealthStepSource();

  @override
  String get displayName => 'Health app (coming soon)';

  @override
  bool get isAvailable => false;

  @override
  Future<int?> stepsForDate(DateTime date) async => null;
}
