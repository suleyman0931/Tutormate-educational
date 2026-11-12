import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/constants/app_constants.dart';

/// Reading mode: continuous scroll or single page.
enum ReadingMode {
  continuous,
  singlePage;

  String get label => this == ReadingMode.continuous
      ? 'Continuous Scroll'
      : 'Single Page';
}

/// Settings that affect the PDF reader experience.
///
/// Persisted via SharedPreferences; full customization UI comes in Phase 5.
class ReaderSettings {
  final ReadingMode mode;
  final bool showPageNumbers;
  final bool distractionFree;

  const ReaderSettings({
    this.mode = ReadingMode.continuous,
    this.showPageNumbers = true,
    this.distractionFree = false,
  });

  ReaderSettings copyWith({
    ReadingMode? mode,
    bool? showPageNumbers,
    bool? distractionFree,
  }) {
    return ReaderSettings(
      mode: mode ?? this.mode,
      showPageNumbers: showPageNumbers ?? this.showPageNumbers,
      distractionFree: distractionFree ?? this.distractionFree,
    );
  }
}

/// Manages reader settings, persisted to SharedPreferences.
class ReaderSettingsNotifier extends Notifier<ReaderSettings> {
  late SharedPreferences _prefs;

  @override
  ReaderSettings build() {
    // Return defaults immediately; async load will update.
    _load();
    return const ReaderSettings();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final modeIndex = _prefs.getInt(PrefKeys.readingMode) ?? 0;
    final showPages = _prefs.getBool(PrefKeys.showPageNumbers) ?? true;
    final distraction = _prefs.getBool(PrefKeys.distractionFree) ?? false;
    state = ReaderSettings(
      mode: ReadingMode.values[modeIndex.clamp(0, 1)],
      showPageNumbers: showPages,
      distractionFree: distraction,
    );
  }

  Future<void> setMode(ReadingMode mode) async {
    state = state.copyWith(mode: mode);
    await _prefs.setInt(PrefKeys.readingMode, mode.index);
  }

  Future<void> setShowPageNumbers(bool value) async {
    state = state.copyWith(showPageNumbers: value);
    await _prefs.setBool(PrefKeys.showPageNumbers, value);
  }

  Future<void> setDistractionFree(bool value) async {
    state = state.copyWith(distractionFree: value);
    await _prefs.setBool(PrefKeys.distractionFree, value);
  }
}

final readerSettingsProvider =
    NotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
  ReaderSettingsNotifier.new,
);
