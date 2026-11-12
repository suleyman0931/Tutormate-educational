import 'package:flutter/material.dart';

/// Central color palette for TutorMate.
///
/// Material Design 3 with:
/// - Primary: Deep Navy Blue
/// - Secondary: Teal
/// - Accent (Tertiary): Soft Orange
class AppColors {
  AppColors._();

  // Primary – Deep Navy Blue
  static const Color primary = Color(0xFF1A237E);
  static const Color primaryLight = Color(0xFF534FBA);
  static const Color primaryDark = Color(0xFF000080);

  // Secondary – Teal
  static const Color secondary = Color(0xFF00897B);
  static const Color secondaryLight = Color(0xFF4DB6AC);
  static const Color secondaryDark = Color(0xFF005B54);

  // Accent / Tertiary – Soft Orange
  static const Color accent = Color(0xFFFF8A65);
  static const Color accentLight = Color(0xFFFFB199);
  static const Color accentDark = Color(0xFFC75B39);

  // Light theme backgrounds
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);

  // Dark theme backgrounds
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);

  // Seed color used to derive the full ColorScheme
  static const Color seed = Color(0xFF1A237E);
}
