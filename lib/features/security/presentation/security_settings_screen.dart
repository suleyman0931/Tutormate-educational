import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/services/security_service.dart';

/// Security settings: PIN toggle, biometric toggle, and auto-lock timer.
class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(securitySettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('App Lock')),
      body: ListView(
        children: [
          // ── PIN lock ────────────────────────────────────────────────────
          _SectionHeader('PIN Lock'),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outlined),
            title: const Text('Enable PIN Lock'),
            subtitle: Text(
              settings.pinEnabled
                  ? 'App is protected with a PIN'
                  : 'Secure the app with a 4-digit PIN',
            ),
            value: settings.pinEnabled,
            onChanged: (enabled) async {
              if (enabled) {
                // Navigate to PIN setup
                context.push(AppRoutes.pinSetup);
              } else {
                // Confirm and disable
                final confirmed = await _confirmDisable(context);
                if (confirmed) {
                  await ref
                      .read(securitySettingsProvider.notifier)
                      .removePin();
                }
              }
            },
          ),
          if (settings.pinEnabled) ...[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Change PIN'),
              onTap: () => context.push(AppRoutes.pinSetup),
              trailing: const Icon(Icons.chevron_right),
            ),
          ],

          const Divider(height: 1),

          // ── Biometric ───────────────────────────────────────────────────
          _SectionHeader('Biometric'),
          if (!settings.biometricAvailable)
            const ListTile(
              leading: Icon(Icons.fingerprint, color: Colors.grey),
              title: Text('Biometric Unavailable',
                  style: TextStyle(color: Colors.grey)),
              subtitle: Text(
                  'This device does not support biometric authentication.'),
            )
          else
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Use Fingerprint / Face ID'),
              subtitle: const Text(
                  'Unlock with biometrics instead of PIN'),
              value: settings.biometricEnabled,
              onChanged: settings.pinEnabled
                  ? (enabled) async {
                      await ref
                          .read(securitySettingsProvider.notifier)
                          .setBiometric(enabled);
                    }
                  : null, // disabled unless PIN is set
            ),

          const Divider(height: 1),

          // ── Auto-lock ───────────────────────────────────────────────────
          _SectionHeader('Auto-Lock'),
          if (!settings.pinEnabled)
            const ListTile(
              leading: Icon(Icons.timer_outlined, color: Colors.grey),
              title: Text('Auto-Lock', style: TextStyle(color: Colors.grey)),
              subtitle: Text('Enable PIN lock first to configure auto-lock.'),
            )
          else
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Lock After'),
              subtitle: Text(_autoLockLabel(settings.autoLockMinutes)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAutoLockPicker(context, ref, settings),
            ),
        ],
      ),
    );
  }

  Future<bool> _confirmDisable(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disable PIN Lock?'),
        content: const Text(
            'This will remove your PIN and disable app protection.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showAutoLockPicker(
      BuildContext context, WidgetRef ref, SecuritySettings settings) {
    const options = [1, 2, 5, 10, 15, 30, 0];
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: options.map((m) {
            final label = _autoLockLabel(m);
            return ListTile(
              title: Text(label),
              trailing: m == settings.autoLockMinutes
                  ? Icon(Icons.check,
                      color: Theme.of(ctx).colorScheme.primary)
                  : null,
              onTap: () {
                ref
                    .read(securitySettingsProvider.notifier)
                    .setAutoLock(m);
                Navigator.of(ctx).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  static String _autoLockLabel(int minutes) {
    if (minutes == 0) return 'Never';
    if (minutes == 1) return '1 minute';
    return '$minutes minutes';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
