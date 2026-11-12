import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutormate/core/services/security_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SecurityService PIN', () {
    test('isPinEnabled returns false by default', () async {
      final svc = SecurityService();
      expect(await svc.isPinEnabled(), isFalse);
    });

    test('setPin enables PIN and verifyPin returns true for correct PIN', () async {
      final svc = SecurityService();
      await svc.setPin('1234');
      expect(await svc.isPinEnabled(), isTrue);
      expect(await svc.verifyPin('1234'), isTrue);
    });

    test('verifyPin returns false for wrong PIN', () async {
      final svc = SecurityService();
      await svc.setPin('1234');
      expect(await svc.verifyPin('9999'), isFalse);
    });

    test('two different PINs hash differently', () async {
      final svc1 = SecurityService();
      final svc2 = SecurityService();
      await svc1.setPin('1111');
      await svc2.setPin('2222');
      // After svc2 sets its PIN, svc1's hash is overwritten — that is by
      // design (single-device storage). Just verify the hash changes.
      expect(await svc2.verifyPin('2222'), isTrue);
      expect(await svc2.verifyPin('1111'), isFalse);
    });

    test('removePin disables PIN', () async {
      final svc = SecurityService();
      await svc.setPin('5678');
      await svc.removePin();
      expect(await svc.isPinEnabled(), isFalse);
      expect(await svc.verifyPin('5678'), isFalse);
    });

    test('PIN is not stored in plaintext', () async {
      final svc = SecurityService();
      await svc.setPin('1234');
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('pin_hash') ?? '';
      expect(stored, isNot('1234'));
      expect(stored.length, greaterThan(10));
    });
  });

  group('SecurityService auto-lock', () {
    test('getAutoLockMinutes returns 5 by default', () async {
      final svc = SecurityService();
      expect(await svc.getAutoLockMinutes(), 5);
    });

    test('setAutoLockMinutes persists the value', () async {
      final svc = SecurityService();
      await svc.setAutoLockMinutes(10);
      expect(await svc.getAutoLockMinutes(), 10);
    });

    test('shouldAutoLock returns false when PIN is disabled', () async {
      final svc = SecurityService();
      // PIN is not enabled, so shouldAutoLock should be false regardless.
      expect(await svc.shouldAutoLock(), isFalse);
    });
  });

  group('SecurityService biometric settings', () {
    test('isBiometricEnabled returns false by default', () async {
      final svc = SecurityService();
      expect(await svc.isBiometricEnabled(), isFalse);
    });

    test('setBiometricEnabled persists the setting', () async {
      final svc = SecurityService();
      await svc.setBiometricEnabled(true);
      expect(await svc.isBiometricEnabled(), isTrue);
      await svc.setBiometricEnabled(false);
      expect(await svc.isBiometricEnabled(), isFalse);
    });
  });
}
