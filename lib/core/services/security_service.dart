import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/constants/app_constants.dart';

/// Manages PIN setup, verification, biometric authentication, and auto-lock.
class SecurityService {
  SecurityService();

  final LocalAuthentication _auth = LocalAuthentication();

  // ── PIN ────────────────────────────────────────────────────────────────────

  /// Returns true if PIN lock is enabled.
  Future<bool> isPinEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefKeys.pinEnabled) ?? false;
  }

  /// Enables PIN by hashing [pin] with a random salt and persisting it.
  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.pinHash, hash);
    await prefs.setString(PrefKeys.pinSalt, salt);
    await prefs.setBool(PrefKeys.pinEnabled, true);
  }

  /// Disables PIN lock and removes stored credentials.
  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefKeys.pinHash);
    await prefs.remove(PrefKeys.pinSalt);
    await prefs.setBool(PrefKeys.pinEnabled, false);
  }

  /// Returns true if [pin] matches the stored PIN hash.
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(PrefKeys.pinHash);
    final salt = prefs.getString(PrefKeys.pinSalt);
    if (storedHash == null || salt == null) return false;
    return _hashPin(pin, salt) == storedHash;
  }

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  // ── Biometric ──────────────────────────────────────────────────────────────

  /// Returns true if biometric authentication is enabled by the user.
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefKeys.biometricEnabled) ?? false;
  }

  /// Sets whether biometric authentication is enabled.
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.biometricEnabled, enabled);
  }

  /// Returns true if the device supports biometric authentication.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Attempts biometric authentication. Returns true on success.
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to open TutorMate',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  // ── Auto-lock ──────────────────────────────────────────────────────────────

  /// Returns the auto-lock timeout in minutes (0 = disabled).
  Future<int> getAutoLockMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(PrefKeys.autoLockMinutes) ?? 5;
  }

  /// Sets the auto-lock timeout in minutes (0 = disabled).
  Future<void> setAutoLockMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefKeys.autoLockMinutes, minutes);
  }

  /// Records the current timestamp as the last active time.
  Future<void> recordActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        PrefKeys.lastActiveTimestamp, DateTime.now().millisecondsSinceEpoch);
  }

  /// Returns true if the auto-lock timeout has elapsed since last activity.
  Future<bool> shouldAutoLock() async {
    final pinEnabled = await isPinEnabled();
    if (!pinEnabled) return false;

    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(PrefKeys.autoLockMinutes) ?? 5;
    if (minutes == 0) return false;

    final lastActive = prefs.getInt(PrefKeys.lastActiveTimestamp);
    if (lastActive == null) return true;

    final elapsed =
        DateTime.now().millisecondsSinceEpoch - lastActive;
    return elapsed > minutes * 60 * 1000;
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

/// Tracks whether the app is currently locked.
final appLockedProvider = StateProvider<bool>((ref) => false);

/// Security settings state for the settings UI.
class SecuritySettings {
  final bool pinEnabled;
  final bool biometricEnabled;
  final bool biometricAvailable;
  final int autoLockMinutes;

  const SecuritySettings({
    this.pinEnabled = false,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.autoLockMinutes = 5,
  });

  SecuritySettings copyWith({
    bool? pinEnabled,
    bool? biometricEnabled,
    bool? biometricAvailable,
    int? autoLockMinutes,
  }) =>
      SecuritySettings(
        pinEnabled: pinEnabled ?? this.pinEnabled,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        biometricAvailable: biometricAvailable ?? this.biometricAvailable,
        autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      );
}

class SecuritySettingsNotifier extends Notifier<SecuritySettings> {
  @override
  SecuritySettings build() {
    _load();
    return const SecuritySettings();
  }

  SecurityService get _svc => ref.read(securityServiceProvider);

  Future<void> _load() async {
    final pinEnabled = await _svc.isPinEnabled();
    final biometricEnabled = await _svc.isBiometricEnabled();
    final biometricAvailable = await _svc.isBiometricAvailable();
    final autoLockMinutes = await _svc.getAutoLockMinutes();
    state = SecuritySettings(
      pinEnabled: pinEnabled,
      biometricEnabled: biometricEnabled,
      biometricAvailable: biometricAvailable,
      autoLockMinutes: autoLockMinutes,
    );
  }

  Future<void> setupPin(String pin) async {
    await _svc.setPin(pin);
    state = state.copyWith(pinEnabled: true);
  }

  Future<void> removePin() async {
    await _svc.removePin();
    await _svc.setBiometricEnabled(false);
    state = state.copyWith(pinEnabled: false, biometricEnabled: false);
  }

  Future<void> setBiometric(bool enabled) async {
    await _svc.setBiometricEnabled(enabled);
    state = state.copyWith(biometricEnabled: enabled);
  }

  Future<void> setAutoLock(int minutes) async {
    await _svc.setAutoLockMinutes(minutes);
    state = state.copyWith(autoLockMinutes: minutes);
  }
}

final securitySettingsProvider =
    NotifierProvider<SecuritySettingsNotifier, SecuritySettings>(
  SecuritySettingsNotifier.new,
);
