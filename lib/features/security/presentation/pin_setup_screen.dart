import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/security_service.dart';

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
  final List<String> _digits = [];
  String? _firstPin;
  bool _confirming = false;
  String? _error;

  String get _title =>
      _confirming ? 'Confirm PIN' : 'Enter New PIN';

  String get _subtitle =>
      _confirming ? 'Re-enter to confirm' : 'Choose a 4-digit PIN';

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Set PIN')),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(_title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(_subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    )),
            const SizedBox(height: 32),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (i) {
                final filled = i < _digits.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? colorScheme.primary
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

            const SizedBox(height: 16),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _error != null ? 1.0 : 0.0,
              child: Text(
                _error ?? '',
                style: TextStyle(color: colorScheme.error, fontSize: 13),
              ),
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: _Keypad(
                onDigit: _onDigit,
                onDelete: _onDelete,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onDelete});
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  static const _keys = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ..._keys.map((row) => Row(
              children: row
                  .map((d) => Expanded(
                      child: _KeyBtn(d, () => onDigit(d))))
                  .toList(),
            )),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            Expanded(child: _KeyBtn('0', () => onDigit('0'))),
            Expanded(
              child: _KeyBtn.icon(Icons.backspace_outlined, onDelete),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyBtn extends StatelessWidget {
  const _KeyBtn(this.label, this.onTap) : icon = null;
  const _KeyBtn.icon(this.icon, this.onTap) : label = '';

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
