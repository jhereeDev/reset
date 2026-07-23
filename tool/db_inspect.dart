// Dev-only helper: `dart run tool/db_inspect.dart <path-to-db>` prints the
// habits, entry counts, and plans inside a Reset database file (e.g. one
// pulled from a device with `adb exec-out run-as ... cat`).
//
// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final db = sqlite3.open(args[0]);

  print('--- habits ---');
  for (final row in db.select(
    'SELECT id, name, start_date_key, status, sort_order FROM habits ORDER BY start_date_key, sort_order',
  )) {
    print(
      '${row['start_date_key']}  ${row['name']}  (${row['status']}, order ${row['sort_order']}, id ${(row['id'] as String).substring(0, 8)})',
    );
  }
  print('--- entries per habit ---');
  for (final row in db.select(
    'SELECT h.name, h.start_date_key, COUNT(e.id) AS n FROM habits h LEFT JOIN habit_entries e ON e.habit_id = h.id GROUP BY h.id ORDER BY h.start_date_key',
  )) {
    print('${row['start_date_key']}  ${row['name']}: ${row['n']} entries');
  }
  print('--- reset plans ---');
  for (final row in db.select(
    'SELECT title, start_date_key, status FROM reset_plans',
  )) {
    print('${row['start_date_key']}  ${row['title']}  ${row['status']}');
  }
  db.close();
}
