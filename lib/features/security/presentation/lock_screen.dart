import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/security_service.dart';

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
  final List<String> _enteredDigits = [];
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
    final colorScheme = Theme.of(context).colorScheme;
    final biometricEnabled =
        ref.watch(securitySettingsProvider).biometricEnabled;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // App icon / title
            Icon(Icons.menu_book_rounded,
                size: 64, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              'TutorMate',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter your PIN',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),

            // PIN dots
            AnimatedContainer(
              duration: const Duration(milliseconds: 50),
              transform: _shaking
                  ? (Matrix4.identity()..translateByDouble(10.0, 0, 0, 1))
                  : Matrix4.identity(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _enteredDigits.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? (_shaking
                              ? colorScheme.error
                              : colorScheme.primary)
                          : colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: filled
                            ? Colors.transparent
                            : colorScheme.outline,
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // Error message
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _error != null ? 1.0 : 0.0,
              child: Text(
                _error ?? '',
                style: TextStyle(
                    color: colorScheme.error, fontSize: 13),
              ),
            ),

            const Spacer(),

            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: _Keypad(
                onDigit: _onDigitTap,
                onDelete: _onDelete,
                onBiometric:
                    biometricEnabled ? _tryBiometric : null,
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Numeric keypad ────────────────────────────────────────────────────────────

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;

  static const _keys = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ..._keys.map((row) => _buildRow(context, row)),
        // Bottom row: biometric | 0 | delete
        Row(
          children: [
            Expanded(
              child: onBiometric != null
                  ? _KeyButton.withIcon(
                      Icons.fingerprint, onBiometric!, context)
                  : const SizedBox.shrink(),
            ),
            Expanded(child: _KeyButton('0', () => onDigit('0'), context)),
            Expanded(
              child: _KeyButton.withIcon(
                  Icons.backspace_outlined, onDelete, context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<String> digits) {
    return Row(
      children: digits
          .map((d) => Expanded(
              child: _KeyButton(d, () => onDigit(d), context)))
          .toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton(this.label, this.onTap, this.context) : icon = null;

  const _KeyButton.withIcon(IconData this.icon, this.onTap, this.context)
      : label = '';

  final String label;
  final VoidCallback onTap;
  final BuildContext context;
  final IconData? icon;

  @override
  Widget build(BuildContext ctx) {
    final colorScheme = Theme.of(ctx).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 60,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 24, color: colorScheme.onSurface)
                  : Text(
                      label,
                      style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
