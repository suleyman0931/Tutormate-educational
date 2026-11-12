import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/library_providers.dart';

/// Displays full details for a single book with actions:
/// read, edit, replace PDF, and delete (with confirmation).
class BookDetailsScreen extends ConsumerWidget {
  const BookDetailsScreen({super.key, required this.bookId});
  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookByIdProvider(bookId));
    final subjectMapAsync = ref.watch(subjectMapProvider);

    return bookAsync.when(
      data: (book) {
        if (book == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Book not found')),
          );
        }
        return subjectMapAsync.when(
          data: (subjectMap) =>
              _BookDetailsContent(book: book, subjectName: subjectMap[book.subjectId]),
          loading: () =>
              _BookDetailsContent(book: book, subjectName: null),
          error: (_, _) =>
              _BookDetailsContent(book: book, subjectName: null),
        );
      },
      loading: () => const Scaffold(
        body: LoadingIndicator(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorWidget(message: e.toString()),
      ),
    );
  }
}

class _BookDetailsContent extends ConsumerWidget {
  const _BookDetailsContent({required this.book, this.subjectName});
  final Book book;
  final String? subjectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => context.push(
              '/library/edit/${book.id}',
              extra: book,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value, context, ref),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'read',
                child: ListTile(
                  leading: Icon(Icons.menu_book_outlined),
                  title: Text('Read'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'replace',
                child: ListTile(
                  leading: Icon(Icons.swap_horiz),
                  title: Text('Replace PDF'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          // ── Cover + title ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 140,
                  height: 190,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildCover(colorScheme),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  book.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // ── Chips ────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                _infoChip(context, Icons.category_outlined, book.category.label),
                _infoChip(context, Icons.grade_outlined, 'Grade ${book.grade}'),
                if (subjectName != null)
                  _infoChip(context, Icons.subject_outlined, subjectName!),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Metadata list ────────────────────────────────────────────────────
          _metadataSection(context, theme),

          const SizedBox(height: 16),

          // ── Read button ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () {
                ref.read(bookRepositoryProvider).markAsOpened(book.id);
                context.push('/reader/${book.id}');
              },
              icon: const Icon(Icons.menu_book),
              label: const Text('Read Book'),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.aiFor(book.id)),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Ask AI about this book'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCover(ColorScheme colorScheme) {
    if (book.coverPath != null && book.coverPath!.isNotEmpty) {
      final file = File(book.coverPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return Container(
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Icon(
        Icons.menu_book_rounded,
        size: 56,
        color: colorScheme.primary.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _metadataSection(BuildContext context, ThemeData theme) {
    final entries = <_MetadataEntry>[
      if (book.author != null && book.author!.isNotEmpty)
        _MetadataEntry(Icons.person_outline, 'Author', book.author!),
      if (book.publisher != null && book.publisher!.isNotEmpty)
        _MetadataEntry(Icons.business_outlined, 'Publisher', book.publisher!),
      if (book.academicYear != null && book.academicYear!.isNotEmpty)
        _MetadataEntry(Icons.calendar_today_outlined, 'Academic Year', book.academicYear!),
      _MetadataEntry(Icons.insert_drive_file_outlined, 'File', book.filePath.split('/').last),
      if (book.description != null && book.description!.isNotEmpty)
        _MetadataEntry(Icons.description_outlined, 'Description', book.description!),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.map((e) => _metadataRow(context, theme, e)).toList(),
        ),
      ),
    );
  }

  Widget _metadataRow(BuildContext context, ThemeData theme, _MetadataEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(entry.icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(entry.value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, BuildContext context, WidgetRef ref) {
    switch (action) {
      case 'read':
        ref.read(bookRepositoryProvider).markAsOpened(book.id);
        context.push('/reader/${book.id}');
      case 'replace':
        _replacePdf(context, ref);
      case 'delete':
        _deleteBook(context, ref);
    }
  }

  Future<void> _replacePdf(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(bookRepositoryProvider);
    final files = await repo.pickPdfFiles(allowMultiple: false);
    if (files.isEmpty || !context.mounted) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Replace PDF',
      message: 'Replace the PDF for "${book.title}"? The current file will be deleted. '
          'Book metadata and annotations will be preserved.',
      confirmLabel: 'Replace',
    );
    if (!confirmed || !context.mounted) return;

    try {
      await repo.replacePdf(bookId: book.id, newFile: files.first);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF replaced successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to replace PDF: $e')),
        );
      }
    }
  }

  Future<void> _deleteBook(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Book',
      message: 'Delete "${book.title}"?\n\n'
          'This will permanently remove:\n'
          '• The PDF file\n'
          '• Reading progress\n'
          '• Bookmarks\n'
          '• Annotations\n\n'
          'Notes linked to this book will be preserved but unlinked.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(bookRepositoryProvider).deleteBook(book.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${book.title}" deleted')),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }
}

class _MetadataEntry {
  final IconData icon;
  final String label;
  final String value;
  const _MetadataEntry(this.icon, this.label, this.value);
}
