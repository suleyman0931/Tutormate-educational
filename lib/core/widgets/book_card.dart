import 'dart:io';

import 'package:flutter/material.dart';

import '../database/app_database.dart';

/// A polished card displaying a book cover, title, grade, subject, and
/// category badge.
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCover(colorScheme),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        book.category.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      _chip(
                        context,
                        'G${book.grade}',
                        background: colorScheme.primary.withValues(alpha: 0.10),
                        foreground: colorScheme.primary,
                      ),
                      if (subjectName != null && subjectName!.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: _chip(
                            context,
                            subjectName!,
                            background: colorScheme.surfaceContainerHighest,
                            foreground: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(ColorScheme colorScheme) {
    if (book.coverPath != null && book.coverPath!.isNotEmpty) {
      final File file = File(book.coverPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, child) =>
              _coverPlaceholder(colorScheme),
        );
      }
    }
    return _coverPlaceholder(colorScheme);
  }

  Widget _coverPlaceholder(ColorScheme colorScheme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.85),
            colorScheme.secondaryContainer.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 40,
          color: colorScheme.primary.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
