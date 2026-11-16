import 'package:flutter/material.dart';

/// Central color palette and design tokens for TutorMate.
///
/// The brand stays anchored on deep navy, teal, and soft orange while the
/// surrounding scale leans on calm, cool neutrals for a professional finish.
class AppColors {
  AppColors._();

  // Primary – Deep Navy Blue
  static const Color primary = Color(0xFF1A237E);
  static const Color primaryLight = Color(0xFF3D4CB3);
  static const Color primaryDark = Color(0xFF0D1545);

  // Secondary – Teal
  static const Color secondary = Color(0xFF00897B);
  static const Color secondaryLight = Color(0xFF4DB6AC);
  static const Color secondaryDark = Color(0xFF005B54);

  // Accent / Tertiary – Soft Orange
  static const Color accent = Color(0xFFFF8A65);
  static const Color accentLight = Color(0xFFFFB199);
  static const Color accentDark = Color(0xFFC75B39);

  // Supporting accents
  static const Color violet = Color(0xFF6C5CE7);
  static const Color amber = Color(0xFFB26A00);
  static const Color slate = Color(0xFF546E7A);
  static const Color rose = Color(0xFFC2185B);

  // Light theme neutrals
  static const Color lightBackground = Color(0xFFF7F8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLow = Color(0xFFF2F4FA);
  static const Color lightSurfaceHigh = Color(0xFFE9ECF4);
  static const Color lightOutline = Color(0xFFE1E4ED);
  static const Color lightText = Color(0xFF171A24);
  static const Color lightTextVariant = Color(0xFF5B6072);

  // Dark theme neutrals
  static const Color darkBackground = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF161A22);
  static const Color darkSurfaceLow = Color(0xFF1B202A);
  static const Color darkSurfaceHigh = Color(0xFF242B38);
  static const Color darkOutline = Color(0xFF2E3547);
  static const Color darkText = Color(0xFFF1F3F9);
  static const Color darkTextVariant = Color(0xFFA7AFC2);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF0B1240),
      Color(0xFF1A237E),
      Color(0xFF3547A8),
    ],
  );

  // Seed color used to derive the full ColorScheme
  static const Color seed = Color(0xFF1A237E);
}
