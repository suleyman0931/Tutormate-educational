import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/theme_provider.dart';
import '../../../core/widgets/settings_section.dart';
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _AppIdentityCard(),

          SettingsSection(
            title: 'Appearance',
            children: [_ThemeTile(current: themeMode)],
          ),

          SettingsSection(
            title: 'Reading Preferences',
            children: [
              _ReadingModeTile(settings: readerSettings),
              SettingsSwitchTile(
                icon: Icons.format_list_numbered_rounded,
                title: 'Show Page Numbers',
                subtitle: 'Display current page and total in reader',
                value: readerSettings.showPageNumbers,
                onChanged: (v) => ref
                    .read(readerSettingsProvider.notifier)
                    .setShowPageNumbers(v),
              ),
              SettingsSwitchTile(
                icon: Icons.fullscreen_rounded,
                title: 'Distraction-Free Mode',
                subtitle: 'Auto-hide toolbar after 3 seconds',
                value: readerSettings.distractionFree,
                onChanged: (v) => ref
                    .read(readerSettingsProvider.notifier)
                    .setDistractionFree(v),
              ),
            ],
          ),

          SettingsSection(
            title: 'Library',
            children: [
              ListTile(
                leading: const SettingsTileIcon(Icons.label_outlined),
                title: const Text('Manage Subjects'),
                subtitle: const Text('Add, rename, or delete subjects'),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => context.push(AppRoutes.subjects),
              ),
            ],
          ),

          SettingsSection(
            title: 'AI Assistant',
            children: [
              ListTile(
                leading: const SettingsTileIcon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.violet,
                ),
                title: const Text('Gemini API Key'),
                subtitle: Text(
                  aiSettings.isConfigured
                      ? 'Connected · ${aiSettings.model}'
                      : 'Not configured · tap to add your key',
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => showAiSettingsDialog(context, ref),
              ),
            ],
          ),

          SettingsSection(
            title: 'Backup & Restore',
            children: [
              ListTile(
                leading: const SettingsTileIcon(
                  Icons.backup_outlined,
                  color: AppColors.amber,
                ),
                title: const Text('Backup & Restore'),
                subtitle: const Text('Export or import all your data'),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => context.push(AppRoutes.backup),
              ),
            ],
          ),

          SettingsSection(
            title: 'Security',
            children: [
              ListTile(
                leading: const SettingsTileIcon(Icons.lock_outline_rounded),
                title: const Text('App Lock'),
                subtitle: const Text('PIN and biometric protection'),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => context.push(AppRoutes.securitySettings),
              ),
            ],
          ),

          SettingsSection(
            title: 'About',
            children: [
              ListTile(
                leading: const SettingsTileIcon(
                  Icons.info_outline_rounded,
                  color: AppColors.slate,
                ),
                title: const Text('About TutorMate'),
                subtitle: const Text(
                  'Version 1.0.0 · Developer: Suleyman Abdu',
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => context.push(AppRoutes.about),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared tile widgets ───────────────────────────────────────────────────────

class _AppIdentityCard extends StatelessWidget {
  const _AppIdentityCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.65),
            colorScheme.secondaryContainer.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TutorMate',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your offline reading companion',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Version 1.0.0',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
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

// ── Theme tile ───────────────────────────────────────────────────────────────

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile({required this.current});
  final ThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: SettingsTileIcon(_iconFor(current), color: AppColors.violet),
      title: const Text('Theme'),
      subtitle: Text(_labelFor(current)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
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
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            _ThemeOption(
              icon: Icons.light_mode_outlined,
              label: 'Light',
              selected: current == ThemeMode.light,
              onTap: () {
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light);
                Navigator.of(ctx).pop();
              },
            ),
            _ThemeOption(
              icon: Icons.dark_mode_outlined,
              label: 'Dark',
              selected: current == ThemeMode.dark,
              onTap: () {
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark);
                Navigator.of(ctx).pop();
              },
            ),
            _ThemeOption(
              icon: Icons.brightness_auto_outlined,
              label: 'System Default',
              selected: current == ThemeMode.system,
              onTap: () {
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.system);
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
      leading: Icon(
        icon,
        color: selected ? colorScheme.primary : colorScheme.onSurface,
      ),
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
      leading: SettingsTileIcon(
        settings.mode == ReadingMode.continuous
            ? Icons.view_day_outlined
            : Icons.auto_stories_outlined,
        color: Theme.of(context).colorScheme.secondary,
      ),
      title: const Text('Reading Mode'),
      subtitle: Text(settings.mode.label),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
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
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.view_day_outlined),
              title: const Text('Continuous Scroll'),
              subtitle: const Text('Pages flow continuously'),
              trailing: settings.mode == ReadingMode.continuous
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(ctx).colorScheme.primary,
                    )
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
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(ctx).colorScheme.primary,
                    )
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
