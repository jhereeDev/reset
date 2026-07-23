import 'package:flutter/material.dart';

/// Central color tokens for the Reset design system.
///
/// Never reference raw hex values inside feature widgets — add a token here.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFF5A4FF3); // electric indigo
  static const Color primaryBright = Color(0xFF8B5CF6); // violet accent
  static const Color onPrimary = Colors.white;

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryBright],
  );

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Neutral surfaces — light
  static const Color backgroundLight = Color(0xFFF6F6FA);
  static const Color surfaceLight = Colors.white;
  static const Color textPrimaryLight = Color(0xFF1B1B22);
  static const Color textSecondaryLight = Color(0xFF6E6E7A);

  // Neutral surfaces — dark
  static const Color backgroundDark = Color(0xFF131318);
  static const Color surfaceDark = Color(0xFF1D1D26);
  static const Color textPrimaryDark = Color(0xFFF2F2F7);
  static const Color textSecondaryDark = Color(0xFF9E9EAB);

  // Category accents
  static const Color fitness = Color(0xFFF97316);
  static const Color health = Color(0xFF10B981);
  static const Color mind = Color(0xFF8B5CF6);
  static const Color discipline = Color(0xFF3B82F6);
  static const Color productivity = Color(0xFFF59E0B);
  static const Color personalCare = Color(0xFFEC4899);

  /// Selectable colors for custom habits.
  static const List<Color> habitPalette = [
    primary,
    primaryBright,
    fitness,
    health,
    mind,
    discipline,
    productivity,
    personalCare,
    Color(0xFF14B8A6), // teal
    Color(0xFF64748B), // slate
  ];
}
