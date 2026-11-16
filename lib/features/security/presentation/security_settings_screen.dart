import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/security_service.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/settings_section.dart';

/// Security settings: PIN toggle, biometric toggle, and auto-lock timer.
class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SecuritySettings settings = ref.watch(securitySettingsProvider);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('App Lock')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _StatusCard(settings: settings),

          SettingsSection(
            title: 'PIN Lock',
            children: [
              SettingsSwitchTile(
                icon: Icons.pin_outlined,
                color: colorScheme.primary,
                title: 'Enable PIN Lock',
                subtitle: settings.pinEnabled
                    ? 'App is protected with a 4-digit PIN'
                    : 'Secure the app with a 4-digit PIN',
                value: settings.pinEnabled,
                onChanged: (enabled) async {
                  if (enabled) {
                    context.push(AppRoutes.pinSetup);
                    return;
                  }
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Disable PIN Lock?',
                    message:
                        'This will remove your PIN and disable app protection.',
                    confirmLabel: 'Disable',
                    destructive: true,
                  );
                  if (confirmed) {
                    await ref
                        .read(securitySettingsProvider.notifier)
                        .removePin();
                  }
                },
              ),
              if (settings.pinEnabled)
                SettingsActionTile(
                  icon: Icons.password_rounded,
                  color: AppColors.violet,
                  title: 'Change PIN',
                  subtitle: 'Set a new 4-digit PIN',
                  onTap: () => context.push(AppRoutes.pinSetup),
                ),
            ],
          ),

          SettingsSection(
            title: 'Biometrics',
            children: [
              if (!settings.biometricAvailable)
                SettingsActionTile(
                  icon: Icons.fingerprint_rounded,
                  color: colorScheme.outline,
                  title: 'Biometric Unavailable',
                  subtitle:
                      'This device does not support biometric authentication.',
                  enabled: false,
                  onTap: null,
                )
              else
                SettingsSwitchTile(
                  icon: Icons.fingerprint_rounded,
                  color: colorScheme.secondary,
                  title: 'Fingerprint / Face ID',
                  subtitle: 'Unlock with biometrics instead of your PIN',
                  value: settings.biometricEnabled,
                  onChanged: settings.pinEnabled
                      ? (enabled) => ref
                            .read(securitySettingsProvider.notifier)
                            .setBiometric(enabled)
                      : null,
                ),
            ],
          ),

          SettingsSection(
            title: 'Auto-Lock',
            children: [
              if (!settings.pinEnabled)
                SettingsActionTile(
                  icon: Icons.timer_outlined,
                  color: colorScheme.outline,
                  title: 'Auto-Lock',
                  subtitle: 'Enable PIN lock first to configure auto-lock.',
                  enabled: false,
                  onTap: null,
                )
              else
                SettingsActionTile(
                  icon: Icons.timer_outlined,
                  color: AppColors.amber,
                  title: 'Lock After',
                  subtitle: _autoLockLabel(settings.autoLockMinutes),
                  onTap: () => _showAutoLockPicker(context, ref, settings),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAutoLockPicker(
    BuildContext context,
    WidgetRef ref,
    SecuritySettings settings,
  ) {
    const List<int> options = <int>[1, 2, 5, 10, 15, 30, 0];
    final ThemeData theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Text(
                'Lock after',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...options.map((minutes) {
              final bool selected = minutes == settings.autoLockMinutes;
              return ListTile(
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(_autoLockLabel(minutes)),
                onTap: () {
                  ref
                      .read(securitySettingsProvider.notifier)
                      .setAutoLock(minutes);
                  Navigator.of(ctx).pop();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  static String _autoLockLabel(int minutes) {
    if (minutes == 0) return 'Never';
    if (minutes == 1) return 'After 1 minute';
    return 'After $minutes minutes';
  }
}

// ── Status card ───────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.settings});

  final SecuritySettings settings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool enabled = settings.pinEnabled;
    final Color accent = enabled ? colorScheme.secondary : colorScheme.outline;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: enabled
              ? <Color>[
                  colorScheme.primaryContainer.withValues(alpha: 0.65),
                  colorScheme.secondaryContainer.withValues(alpha: 0.4),
                ]
              : <Color>[
                  colorScheme.surfaceContainerLow,
                  colorScheme.surfaceContainerHigh,
                ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              enabled ? Icons.shield_rounded : Icons.shield_outlined,
              color: accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'App lock is on' : 'App lock is off',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  enabled
                      ? 'TutorMate unlocks with your PIN'
                      : 'Your library is not protected yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
