import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tutormate/app/theme/app_theme.dart';
import 'package:tutormate/app/theme/app_colors.dart';

void main() {
  group('AppTheme', () {
    test('light theme uses Material 3', () {
      final theme = AppTheme.light;
      expect(theme.useMaterial3, isTrue);
    });

    test('dark theme uses Material 3 and has dark brightness', () {
      final theme = AppTheme.dark;
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('light theme has light brightness', () {
      final theme = AppTheme.light;
      expect(theme.colorScheme.brightness, Brightness.light);
    });

    test('seed color matches navy blue', () {
      expect(AppColors.seed, const Color(0xFF1A237E));
    });

    test('secondary color matches teal', () {
      expect(AppColors.secondary, const Color(0xFF00897B));
    });

    test('accent color matches soft orange', () {
      expect(AppColors.accent, const Color(0xFFFF8A65));
    });
  });
}
