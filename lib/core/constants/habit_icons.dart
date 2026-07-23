import 'package:flutter/material.dart';

/// Registry mapping stable string ids to Material icons.
///
/// Habits persist the id, never the codepoint, so icon changes across Flutter
/// versions can't corrupt stored data.
abstract final class HabitIcons {
  static const String fallbackId = 'star';

  static const Map<String, IconData> all = {
    'fitness': Icons.fitness_center_rounded,
    'walk': Icons.directions_walk_rounded,
    'run': Icons.directions_run_rounded,
    'bike': Icons.directions_bike_rounded,
    'book': Icons.menu_book_rounded,
    'headphones': Icons.headphones_rounded,
    'fruit': Icons.restaurant_rounded,
    'bed': Icons.bed_rounded,
    'water': Icons.water_drop_rounded,
    'meditate': Icons.self_improvement_rounded,
    'sleep': Icons.bedtime_rounded,
    'no_phone': Icons.phonelink_erase_rounded,
    'timer': Icons.timer_rounded,
    'write': Icons.edit_rounded,
    'code': Icons.code_rounded,
    'art': Icons.brush_rounded,
    'music': Icons.music_note_rounded,
    'heart': Icons.favorite_rounded,
    'brain': Icons.psychology_rounded,
    'checklist': Icons.checklist_rounded,
    'sun': Icons.wb_sunny_rounded,
    'leaf': Icons.eco_rounded,
    'star': Icons.star_rounded,
    'bolt': Icons.bolt_rounded,
  };

  static IconData resolve(String id) => all[id] ?? all[fallbackId]!;
}
