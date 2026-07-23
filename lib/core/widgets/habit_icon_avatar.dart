import 'package:flutter/material.dart';

import '../constants/habit_icons.dart';
import '../theme/app_spacing.dart';

/// Rounded-square tinted icon used to represent a habit everywhere.
class HabitIconAvatar extends StatelessWidget {
  const HabitIconAvatar({
    super.key,
    required this.iconId,
    required this.color,
    this.size = 48,
  });

  final String iconId;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(HabitIcons.resolve(iconId), color: color, size: size * 0.54),
    );
  }
}
