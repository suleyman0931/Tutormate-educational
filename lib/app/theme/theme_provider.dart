import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/constants/app_constants.dart';

/// Manages [ThemeMode] with persistence to [SharedPreferences].
///
/// 0 = light, 1 = dark, 2 = system (default).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  late SharedPreferences _prefs;

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system; // initial default while loading
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final index = _prefs.getInt(PrefKeys.themeMode) ?? 2;
    state = _fromIndex(index);
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefKeys.themeMode, _toIndex(mode));
  }

  static ThemeMode _fromIndex(int index) {
    switch (index) {
      case 0:
        return ThemeMode.light;
      case 1:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static int _toIndex(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 0;
      case ThemeMode.dark:
        return 1;
      case ThemeMode.system:
        return 2;
    }
  }
}

/// The app-wide theme mode provider — replaces the simple StateProvider in
/// app.dart with a persistent version.
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
