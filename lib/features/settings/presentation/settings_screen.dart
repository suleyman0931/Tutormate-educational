import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/theme_provider.dart';
import '../../ai/data/ai_settings.dart';
import '../../ai/presentation/ai_settings_dialog.dart';
import '../../pdf_reader/data/reader_providers.dart';

/// Full settings screen organised into sections:
/// - Appearance (theme)
/// - Reading Preferences
/// - Library (subjects management)
/// - AI Assistant (Gemini API key and model)
/// - Backup & Restore
/// - Security
/// - About
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final readerSettings = ref.watch(readerSettingsProvider);
    final aiSettings = ref.watch(aiSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Appearance ────────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          _ThemeTile(current: themeMode),

          const Divider(height: 1),

          // ── Reading Preferences ───────────────────────────────────────────
          _SectionHeader('Reading Preferences'),
          _ReadingModeTile(settings: readerSettings),
          _SwitchTile(
            icon: Icons.format_list_numbered,
            title: 'Show Page Numbers',
            subtitle: 'Display current page and total in reader',
            value: readerSettings.showPageNumbers,
            onChanged: (v) =>
                ref.read(readerSettingsProvider.notifier).setShowPageNumbers(v),
          ),
          _SwitchTile(
            icon: Icons.crop_free_outlined,
            title: 'Distraction-Free Mode',
            subtitle: 'Auto-hide toolbar after 3 seconds',
            value: readerSettings.distractionFree,
            onChanged: (v) =>
                ref.read(readerSettingsProvider.notifier).setDistractionFree(v),
          ),

          const Divider(height: 1),

          // ── Library ────────────────────────────────────────────────────────
          _SectionHeader('Library'),
          ListTile(
            leading: const Icon(Icons.label_outlined),
            title: const Text('Manage Subjects'),
            subtitle: const Text('Add, rename, or delete subjects'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.subjects),
          ),

          const Divider(height: 1),

          // ── AI Assistant ──────────────────────────────────────────────────
          _SectionHeader('AI Assistant'),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Gemini API Key'),
            subtitle: Text(
              aiSettings.isConfigured
                  ? 'Connected · ${aiSettings.model}'
                  : 'Not configured · tap to add your key',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showAiSettingsDialog(context, ref),
          ),

          const Divider(height: 1),

          // ── Backup & Restore ─────────────────────────────────────────────
          _SectionHeader('Backup & Restore'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup & Restore'),
            subtitle: const Text('Export or import all your data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.backup),
          ),

          const Divider(height: 1),

          // ── Security ────────────────────────────────────────────────────
          _SectionHeader('Security'),
          ListTile(
            leading: const Icon(Icons.lock_outlined),
            title: const Text('App Lock'),
            subtitle: const Text('PIN and biometric protection'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.securitySettings),
          ),

          const Divider(height: 1),

          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About TutorMate'),
            subtitle: const Text('Version 1.0.0 · Developer: Suleyman Abdu'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.about),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Shared tile widgets ───────────────────────────────────────────────────────

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

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

// ── Theme tile ────────────────────────────────────────────────────────────────

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile({required this.current});
  final ThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(_iconFor(current)),
      title: const Text('Theme'),
      subtitle: Text(_labelFor(current)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemePicker(context, ref),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Choose Theme',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Divider(height: 1),
            _ThemeOption(
              icon: Icons.light_mode_outlined,
              label: 'Light',
              selected: current == ThemeMode.light,
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setTheme(ThemeMode.light);
                Navigator.of(ctx).pop();
              },
            ),
            _ThemeOption(
              icon: Icons.dark_mode_outlined,
              label: 'Dark',
              selected: current == ThemeMode.dark,
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setTheme(ThemeMode.dark);
                Navigator.of(ctx).pop();
              },
            ),
            _ThemeOption(
              icon: Icons.brightness_auto_outlined,
              label: 'System Default',
              selected: current == ThemeMode.system,
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setTheme(ThemeMode.system);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _labelFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'Follow system';
    }
  }

  static IconData _iconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon,
          color: selected ? colorScheme.primary : colorScheme.onSurface),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? colorScheme.primary : null,
          fontWeight: selected ? FontWeight.w600 : null,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle, color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

// ── Reading mode tile ─────────────────────────────────────────────────────────

class _ReadingModeTile extends ConsumerWidget {
  const _ReadingModeTile({required this.settings});
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(
        settings.mode == ReadingMode.continuous
            ? Icons.view_day_outlined
            : Icons.auto_stories_outlined,
      ),
      title: const Text('Reading Mode'),
      subtitle: Text(settings.mode.label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showModePicker(context, ref),
    );
  }

  void _showModePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Reading Mode',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.view_day_outlined),
              title: const Text('Continuous Scroll'),
              subtitle: const Text('Pages flow continuously'),
              trailing: settings.mode == ReadingMode.continuous
                  ? Icon(Icons.check_circle,
                      color: Theme.of(ctx).colorScheme.primary)
                  : null,
              onTap: () {
                ref
                    .read(readerSettingsProvider.notifier)
                    .setMode(ReadingMode.continuous);
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_stories_outlined),
              title: const Text('Single Page'),
              subtitle: const Text('One page at a time'),
              trailing: settings.mode == ReadingMode.singlePage
                  ? Icon(Icons.check_circle,
                      color: Theme.of(ctx).colorScheme.primary)
                  : null,
              onTap: () {
                ref
                    .read(readerSettingsProvider.notifier)
                    .setMode(ReadingMode.singlePage);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
