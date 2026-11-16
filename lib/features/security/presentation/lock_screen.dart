import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/security_service.dart';
import 'widgets/pin_keypad.dart';

/// Full-screen lock screen shown when PIN lock is enabled.
///
/// Shows a numeric PIN keypad and optionally a biometric prompt.
/// On successful auth, sets [appLockedProvider] to false.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final List<String> _enteredDigits = <String>[];
  static const int _pinLength = 4;
  bool _shaking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Attempt biometric immediately if enabled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometric();
    });
  }

  Future<void> _tryBiometric() async {
    final svc = ref.read(securityServiceProvider);
    final biometricEnabled = await svc.isBiometricEnabled();
    if (!biometricEnabled) return;
    final authenticated = await svc.authenticateWithBiometrics();
    if (authenticated && mounted) {
      _unlock();
    }
  }

  void _onDigitTap(String digit) {
    if (_enteredDigits.length >= _pinLength) return;
    setState(() {
      _enteredDigits.add(digit);
      _error = null;
    });
    if (_enteredDigits.length == _pinLength) {
      _verifyPin();
    }
  }

  void _onDelete() {
    if (_enteredDigits.isEmpty) return;
    setState(() => _enteredDigits.removeLast());
  }

  Future<void> _verifyPin() async {
    final svc = ref.read(securityServiceProvider);
    final pin = _enteredDigits.join();
    final valid = await svc.verifyPin(pin);
    if (!mounted) return;
    if (valid) {
      _unlock();
    } else {
      _shake();
    }
  }

  void _unlock() {
    ref.read(appLockedProvider.notifier).state = false;
    ref.read(securityServiceProvider).recordActivity();
  }

  void _shake() {
    setState(() {
      _enteredDigits.clear();
      _shaking = true;
      _error = 'Incorrect PIN. Try again.';
    });
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _shaking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool biometricEnabled = ref
        .watch(securitySettingsProvider)
        .biometricEnabled;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const Spacer(),
                      const _BrandBadge(),
                      const SizedBox(height: 20),
                      Text(
                        'TutorMate',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter your PIN to continue',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 30),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 50),
                        transform: _shaking
                            ? (Matrix4.identity()
                                ..translateByDouble(10.0, 0, 0, 1))
                            : Matrix4.identity(),
                        child: PinDots(
                          length: _pinLength,
                          filled: _enteredDigits.length,
                          error: _shaking,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 24,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _error != null ? 1.0 : 0.0,
                          child: Text(
                            _error ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      PinKeypad(
                        onDigit: _onDigitTap,
                        onDelete: _onDelete,
                        onBiometric: biometricEnabled ? _tryBiometric : null,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Your library is protected',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_stories_rounded,
        color: Colors.white,
        size: 38,
      ),
    );
  }
}
