import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/settings_section.dart';

/// Backup and Restore screen accessible from Settings.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isWorking = false;
  String _statusMessage = '';
  double _progress = 0.0;
  String? _lastBackupPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _BackupHeroCard(),

          if (_isWorking) ...[
            const SizedBox(height: 20),
            _ProgressCard(message: _statusMessage, progress: _progress),
          ],

          if (_lastBackupPath != null && !_isWorking) ...[
            const SizedBox(height: 16),
            _LastBackupCard(filePath: _lastBackupPath!),
          ],

          SettingsSection(
            title: 'Backup',
            children: [
              SettingsActionTile(
                icon: Icons.cloud_upload_outlined,
                color: AppColors.amber,
                title: 'Create Backup',
                subtitle: 'Save all books, notes, and settings to one file',
                enabled: !_isWorking,
                trailing: const Icon(Icons.download_rounded, size: 20),
                onTap: _createBackup,
              ),
            ],
          ),

          SettingsSection(
            title: 'Restore',
            children: [
              SettingsActionTile(
                icon: Icons.restore_rounded,
                color: AppColors.violet,
                title: 'Restore from Backup',
                subtitle: 'Choose a .tutormate archive from your device',
                enabled: !_isWorking,
                trailing: const Icon(Icons.upload_rounded, size: 20),
                onTap: _pickAndRestore,
              ),
            ],
          ),

          const SizedBox(height: 20),
          const _RestoreWarning(),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    setState(() {
      _isWorking = true;
      _statusMessage = 'Starting backup…';
      _progress = 0.0;
      _lastBackupPath = null;
    });

    try {
      final svc = ref.read(backupServiceProvider);
      final path = await svc.createBackup(
        onProgress: (msg, pct) {
          if (mounted) {
            setState(() {
              _statusMessage = msg;
              _progress = pct;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isWorking = false;
          _lastBackupPath = path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved: ${path.split('/').last}'),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _statusMessage = '';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    }
  }

  Future<void> _pickAndRestore() async {
    // Pick a .tutormate file
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result.isEmpty) return;
    final filePath = result.first.path;
    if (filePath == null) return;

    if (!mounted) return;

    // Validate first
    setState(() {
      _isWorking = true;
      _statusMessage = 'Validating backup…';
      _progress = 0.1;
    });

    final restoreSvc = ref.read(restoreServiceProvider);
    final validation = await restoreSvc.validate(filePath);

    if (!validation.isValid) {
      if (mounted) {
        setState(() => _isWorking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid backup: ${validation.error}')),
        );
      }
      return;
    }

    if (!mounted) return;

    final manifest = validation.manifest!;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Restore Backup?',
      message:
          'Backup created: ${manifest.createdAt.toLocal().toString().split('.').first}\n\n'
          'This will REPLACE all current books, notes, annotations, and settings. '
          'The app needs to restart after restoring. Continue?',
      confirmLabel: 'Restore',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      setState(() => _isWorking = false);
      return;
    }

    try {
      await restoreSvc.restore(
        filePath,
        merge: false,
        onProgress: (msg, pct) {
          if (mounted) {
            setState(() {
              _statusMessage = msg;
              _progress = pct;
            });
          }
        },
      );
      if (mounted) {
        setState(() => _isWorking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore complete! Please restart TutorMate.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isWorking = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _BackupHeroCard extends StatelessWidget {
  const _BackupHeroCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
              Icons.cloud_sync_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep your library safe',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A .tutormate archive contains all your books, notes, '
                  'annotations, bookmarks, reading progress, and settings. '
                  'Store it on external storage or move it to another device.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
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

// ── Progress card ─────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.message, required this.progress});

  final String message;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message.isEmpty ? 'Working…' : message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Last backup card ──────────────────────────────────────────────────────────

class _LastBackupCard extends StatelessWidget {
  const _LastBackupCard({required this.filePath});

  final String filePath;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backup created',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  filePath.split('/').last,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Restore warning ───────────────────────────────────────────────────────────

class _RestoreWarning extends StatelessWidget {
  const _RestoreWarning();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Restoring replaces all current data with the contents of the '
              'backup file. TutorMate must be restarted afterwards.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
