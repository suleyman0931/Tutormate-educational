import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/backup_service.dart';
import '../../../core/widgets/confirm_dialog.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Info card ────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('About Backup',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A backup archive (.tutormate file) includes all your books, '
                    'notes, annotations, bookmarks, reading progress, and app settings. '
                    'Store it on external storage or share it to restore on another device.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Progress ─────────────────────────────────────────────────────
          if (_isWorking) ...[
            Text(_statusMessage,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _progress,
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
            const SizedBox(height: 20),
          ],

          // ── Last backup path ─────────────────────────────────────────────
          if (_lastBackupPath != null && !_isWorking) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saved: ${_lastBackupPath!.split('/').last}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Backup button ────────────────────────────────────────────────
          FilledButton.icon(
            onPressed: _isWorking ? null : _createBackup,
            icon: const Icon(Icons.backup_outlined),
            label: const Text('Create Backup'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 12),

          // ── Restore button ───────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: _isWorking ? null : _pickAndRestore,
            icon: const Icon(Icons.restore_outlined),
            label: const Text('Restore from Backup'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 24),

          // ── Warning ───────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: colorScheme.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Restoring will replace all current data with the contents '
                  'of the backup file. The app will need to restart.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  Future<void> _pickAndRestore() async {
    // Pick a .tutormate file
    final result = await FilePicker.pickFiles(
      type: FileType.any,
    );
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
          SnackBar(
              content:
                  Text('Invalid backup: ${validation.error}')),
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
            content: Text(
                'Restore complete! Please restart TutorMate.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isWorking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }
}
