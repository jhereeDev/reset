/// Date helpers used across the app.
///
/// All persisted dates use a local-timezone `yyyy-MM-dd` string key
/// ([dateKey]) so an entry can never be duplicated by timezone or DST shifts:
/// the key is derived once from the device's local calendar date.
library;

abstract final class AppDateUtils {
  /// Formats a date as its canonical storage key, e.g. `2026-07-22`.
  static String dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses a key produced by [dateKey] back into a local midnight DateTime.
  static DateTime parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Truncates to local midnight.
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime today() => dateOnly(DateTime.now());

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Whole days from [from] to [to] (negative if [to] is earlier).
  ///
  /// Uses date-only arithmetic so DST transitions cannot skew the count.
  static int daysBetween(DateTime from, DateTime to) =>
      dateOnly(to).difference(dateOnly(from)).inDays;

  /// The first day of the week containing [date].
  ///
  /// [weekStartDay] is a `DateTime.monday`..`DateTime.sunday` constant.
  static DateTime startOfWeek(DateTime date, int weekStartDay) {
    final d = dateOnly(date);
    final diff = (d.weekday - weekStartDay + 7) % 7;
    return d.subtract(Duration(days: diff));
  }
}
