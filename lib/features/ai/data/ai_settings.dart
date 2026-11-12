import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/constants/app_constants.dart';

/// User-configurable settings for the Gemini-powered study assistant.
class AiSettings {
  static const String defaultModel = 'gemini-3.5-flash';

  final String apiKey;
  final String model;

  const AiSettings({
    this.apiKey = '',
    this.model = defaultModel,
  });

  bool get isConfigured => apiKey.trim().isNotEmpty;

  AiSettings copyWith({String? apiKey, String? model}) {
    return AiSettings(
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }
}

/// Loads and persists Gemini settings in SharedPreferences.
///
/// The API key never leaves the device except when calling the Gemini API
/// directly from the app.
class AiSettingsNotifier extends Notifier<AiSettings> {
  static const String _bundledKeyAsset = 'assets/config/gemini_key.txt';

  @override
  AiSettings build() {
    _load();
    return const AiSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var apiKey = prefs.getString(PrefKeys.geminiApiKey) ?? '';
    final model =
        prefs.getString(PrefKeys.geminiModel) ?? AiSettings.defaultModel;

    // Seed the key from the local-only config file exactly once. After that,
    // an explicitly cleared key is never re-seeded.
    final alreadyInitialized =
        prefs.getBool(PrefKeys.geminiKeyInitialized) ?? false;
    if (!alreadyInitialized) {
      if (apiKey.trim().isEmpty) {
        apiKey = await _loadBundledKey();
        if (apiKey.isNotEmpty) {
          await prefs.setString(PrefKeys.geminiApiKey, apiKey);
        }
      }
      await prefs.setBool(PrefKeys.geminiKeyInitialized, true);
    }

    state = AiSettings(apiKey: apiKey, model: model);
  }

  /// Supports an optional local-only key file that is git-ignored, so the app
  /// can work out of the box without a key being committed to source control.
  Future<String> _loadBundledKey() async {
    const compileTimeKey = String.fromEnvironment('GEMINI_API_KEY');
    if (compileTimeKey.trim().isNotEmpty) return compileTimeKey.trim();

    try {
      final bundled = await rootBundle.loadString(_bundledKeyAsset);
      return bundled.trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> setApiKey(String apiKey) async {
    final cleaned = apiKey.trim();
    state = state.copyWith(apiKey: cleaned);
    final prefs = await SharedPreferences.getInstance();
    if (cleaned.isEmpty) {
      await prefs.remove(PrefKeys.geminiApiKey);
    } else {
      await prefs.setString(PrefKeys.geminiApiKey, cleaned);
    }
    await prefs.setBool(PrefKeys.geminiKeyInitialized, true);
  }

  Future<void> setModel(String model) async {
    final cleaned =
        model.trim().isEmpty ? AiSettings.defaultModel : model.trim();
    state = state.copyWith(model: cleaned);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.geminiModel, cleaned);
  }
}

final aiSettingsProvider =
    NotifierProvider<AiSettingsNotifier, AiSettings>(AiSettingsNotifier.new);
