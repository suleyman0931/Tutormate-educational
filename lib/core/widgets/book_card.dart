import 'dart:io';

import 'package:flutter/material.dart';

import '../database/app_database.dart';

/// A card displaying a book's cover, title, grade, subject, and category badge.
class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    this.subjectName,
    this.onTap,
    this.onLongPress,
  });

  final Book book;
  final String? subjectName;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: _buildCover(colorScheme),
                ),
              ),
              // Info
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        _chip(context, 'G${book.grade}'),
                        if (subjectName != null)
                          _chip(context, subjectName!, maxLength: 12),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.category.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(ColorScheme colorScheme) {
    if (book.coverPath != null && book.coverPath!.isNotEmpty) {
      final file = File(book.coverPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, child) => _coverPlaceholder(colorScheme),
        );
      }
    }
    return _coverPlaceholder(colorScheme);
  }

  Widget _coverPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 40,
          color: colorScheme.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, {int maxLength = 6}) {
    final display = label.length > maxLength
        ? '${label.substring(0, maxLength)}…'
        : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        display,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
