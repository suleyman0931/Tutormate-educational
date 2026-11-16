import 'package:flutter/material.dart';

/// A row of PIN entry dots.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.length,
    required this.filled,
    this.error = false,
  });

  final int length;
  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (int index) {
        final bool isFilled = index < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? (error ? colorScheme.error : colorScheme.primary)
                : colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: isFilled ? Colors.transparent : colorScheme.outline,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }
}

/// Numeric keypad used by the lock and PIN setup screens.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;

  static const List<List<String>> _rows = <List<String>>[
    <String>['1', '2', '3'],
    <String>['4', '5', '6'],
    <String>['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final List<String> row in _rows)
          Row(
            children: [
              for (final String digit in row)
                Expanded(
                  child: _PinKey(label: digit, onTap: () => onDigit(digit)),
                ),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: onBiometric != null
                  ? _PinKey(
                      icon: Icons.fingerprint_rounded,
                      onTap: onBiometric!,
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: _PinKey(label: '0', onTap: () => onDigit('0')),
            ),
            Expanded(
              child: _PinKey(icon: Icons.backspace_outlined, onTap: onDelete),
            ),
          ],
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({this.label, this.icon, required this.onTap})
    : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(5),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 58,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 23, color: colorScheme.onSurfaceVariant)
                  : Text(
                      label!,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
