import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/security_service.dart';
import 'widgets/pin_keypad.dart';

/// Screen for setting up a new PIN.
///
/// Shows two entry steps: enter PIN, then confirm PIN.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  static const int _pinLength = 4;
  final List<String> _digits = <String>[];
  String? _firstPin;
  bool _confirming = false;
  String? _error;

  String get _title => _confirming ? 'Confirm your PIN' : 'Choose a PIN';

  String get _subtitle => _confirming
      ? 'Enter the same 4-digit PIN again'
      : 'This PIN will unlock TutorMate';

  void _onDigit(String d) {
    if (_digits.length >= _pinLength) return;
    setState(() {
      _digits.add(d);
      _error = null;
    });
    if (_digits.length == _pinLength) {
      _onComplete();
    }
  }

  void _onDelete() {
    if (_digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  Future<void> _onComplete() async {
    final pin = _digits.join();
    if (!_confirming) {
      // First entry — move to confirmation step.
      setState(() {
        _firstPin = pin;
        _digits.clear();
        _confirming = true;
      });
    } else {
      // Confirmation step — verify match and save.
      if (pin == _firstPin) {
        await ref.read(securitySettingsProvider.notifier).setupPin(pin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN enabled successfully')),
          );
          context.pop();
        }
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _digits.clear();
          _firstPin = null;
          _confirming = false;
          _error = 'PINs do not match. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Set PIN')),
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
                        _title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      _StepChip(confirming: _confirming),
                      const SizedBox(height: 28),
                      PinDots(
                        length: _pinLength,
                        filled: _digits.length,
                        error: _error != null,
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
                      PinKeypad(onDigit: _onDigit, onDelete: _onDelete),
                      const SizedBox(height: 20),
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
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.lock_outline_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.confirming});

  final bool confirming;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        confirming ? 'Step 2 of 2' : 'Step 1 of 2',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
