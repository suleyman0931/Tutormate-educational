import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';

/// Displays all bookmarks across every book with tap-to-open and delete.
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(allBookmarksProvider);
    final booksAsync = ref.watch(allBooksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: bookmarksAsync.when(
        data: (bookmarks) {
          if (bookmarks.isEmpty) {
            return const EmptyState(
              icon: Icons.bookmark_border,
              title: 'No Bookmarks Yet',
              message:
                  'Tap the bookmark icon in the reader toolbar to save a page.',
            );
          }

          final booksMap = <int, Book>{};
          booksAsync.whenData((books) {
            for (final b in books) {
              booksMap[b.id] = b;
            }
          });

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: bookmarks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final bm = bookmarks[index];
              final book = booksMap[bm.bookId];
              return _BookmarkTile(bookmark: bm, book: book);
            },
          );
        },
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _BookmarkTile extends ConsumerWidget {
  const _BookmarkTile({required this.bookmark, this.book});
  final Bookmark bookmark;
  final Book? book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '${bookmark.pageNumber}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
        title: Text(
          bookmark.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book != null)
              Text(
                book!.title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (bookmark.description != null &&
                bookmark.description!.isNotEmpty)
              Text(
                bookmark.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'p.${bookmark.pageNumber}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Delete Bookmark',
              onPressed: () => _deleteBookmark(context, ref),
            ),
          ],
        ),
        onTap: () {
          // Open reader at the bookmarked page.
          context.push(AppRoutes.readerFor(bookmark.bookId));
        },
        isThreeLine:
            bookmark.description != null && bookmark.description!.isNotEmpty,
      ),
    );
  }

  Future<void> _deleteBookmark(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Bookmark',
      message: 'Remove bookmark "${bookmark.title}"?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(bookmarksDaoProvider).deleteBookmark(bookmark.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bookmark deleted')),
      );
    }
  }
}
