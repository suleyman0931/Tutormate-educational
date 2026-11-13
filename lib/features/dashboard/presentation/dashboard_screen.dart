import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_card.dart';
import '../../library/data/library_providers.dart';

/// The Home dashboard screen.
///
/// Shows:
/// - Library statistics (stat cards)
/// - Continue Reading card for the last opened book
/// - Recently Opened horizontal scroll
/// - Quick Actions grid
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TutorMate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            tooltip: 'Bookmarks',
            onPressed: () => context.push(AppRoutes.bookmarks),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _StatsSection(),
            _ContinueReadingSection(),
            _RecentlyOpenedSection(),
            _QuickActionsSection(),
          ],
        ),
      ),
    );
  }
}

// ── Statistics ────────────────────────────────────────────────────────────────

class _StatsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(libraryStatsProvider);
    final bookmarkCountAsync = ref.watch(bookmarkCountProvider);

    return statsAsync.when(
      data: (stats) {
        final bookmarkCount =
            bookmarkCountAsync.valueOrNull ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Library Overview'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StatCard(
                    icon: Icons.library_books_rounded,
                    value: stats.totalBooks,
                    label: 'Total Books',
                    color: const Color(0xFF1A237E),
                  ),
                  StatCard(
                    icon: Icons.menu_book_rounded,
                    value: stats.studentBooks,
                    label: 'Student Books',
                    color: const Color(0xFF00897B),
                  ),
                  StatCard(
                    icon: Icons.person_outline,
                    value: stats.teacherGuides,
                    label: 'Teacher Guides',
                    color: const Color(0xFF6A1B9A),
                  ),
                  StatCard(
                    icon: Icons.note_outlined,
                    value: stats.shortNotes,
                    label: 'Short Notes',
                    color: const Color(0xFFFF6F00),
                  ),
                  StatCard(
                    icon: Icons.folder_outlined,
                    value: stats.otherBooks,
                    label: 'Other Books',
                    color: const Color(0xFF37474F),
                  ),
                  StatCard(
                    icon: Icons.bookmark_rounded,
                    value: bookmarkCount,
                    label: 'Bookmarks',
                    color: const Color(0xFFE53935),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

// ── Continue Reading ──────────────────────────────────────────────────────────

class _ContinueReadingSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastBookAsync = ref.watch(lastOpenedBookProvider);

    return lastBookAsync.when(
      data: (book) {
        if (book == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const SectionHeader(title: 'Continue Reading'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _ContinueReadingCard(book: book),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ContinueReadingCard extends ConsumerWidget {
  const _ContinueReadingCard({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(progressByBookProvider(book.id));
    final subjectMapAsync = ref.watch(subjectMapProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final subjectName = subjectMapAsync.valueOrNull?[book.subjectId] ?? '';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.3),
            colorScheme.primaryContainer.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(booksDaoProvider).updateLastOpened(book.id);
            context.push(AppRoutes.readerFor(book.id));
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Cover
                Container(
                  width: 70,
                  height: 95,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildCover(book, colorScheme),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _chip(context, 'Grade ${book.grade}'),
                          const SizedBox(width: 6),
                          if (subjectName.isNotEmpty)
                            _chip(context, subjectName),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Progress
                      progressAsync.when(
                        data: (progress) {
                          final page = progress?.currentPage ?? 1;
                          final total = book.totalPages;
                          final pct = total > 0
                              ? ((page / total) * 100).toInt()
                              : 0;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: total > 0 ? page / total : 0,
                                  backgroundColor: colorScheme.surfaceContainerHighest,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.primary,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                total > 0
                                    ? 'Page $page of $total  ($pct%)'
                                    : 'Page $page',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.play_circle_fill_rounded,
                    size: 40, color: colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(Book book, ColorScheme colorScheme) {
    if (book.coverPath != null && book.coverPath!.isNotEmpty) {
      final f = File(book.coverPath!);
      if (f.existsSync()) {
        return Image.file(f, fit: BoxFit.cover);
      }
    }
    return Center(
      child: Icon(Icons.menu_book_rounded,
          size: 32, color: colorScheme.primary.withValues(alpha: 0.6)),
    );
  }

  Widget _chip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              )),
    );
  }
}

// ── Recently Opened ───────────────────────────────────────────────────────────

class _RecentlyOpenedSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentlyOpenedBooksProvider);
    final subjectMapAsync = ref.watch(subjectMapProvider);

    return recentAsync.when(
      data: (books) {
        if (books.isEmpty) return const SizedBox.shrink();
        final subjectMap = subjectMapAsync.valueOrNull ?? {};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            SectionHeader(
              title: 'Recently Opened',
              actionLabel: 'See All',
              onAction: () => context.go(AppRoutes.library),
            ),
            SizedBox(
              height: 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  return _RecentBookCard(
                    book: book,
                    subjectName: subjectMap[book.subjectId],
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _RecentBookCard extends ConsumerWidget {
  const _RecentBookCard({required this.book, this.subjectName});
  final Book book;
  final String? subjectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        ref.read(booksDaoProvider).updateLastOpened(book.id);
        context.push(AppRoutes.readerFor(book.id));
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer.withValues(alpha: 0.4),
                      colorScheme.primaryContainer.withValues(alpha: 0.2),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildCover(colorScheme),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subjectName != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subjectName!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(ColorScheme colorScheme) {
    if (book.coverPath != null && book.coverPath!.isNotEmpty) {
      final f = File(book.coverPath!);
      if (f.existsSync()) {
        return Image.file(f, fit: BoxFit.cover, width: double.infinity);
      }
    }
    return Center(
      child: Icon(Icons.menu_book_rounded,
          size: 36, color: colorScheme.primary.withValues(alpha: 0.6)),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────

class _QuickActionsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const SectionHeader(title: 'Quick Actions'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _QuickActionTile(
                icon: Icons.upload_file_outlined,
                label: 'Import PDF',
                color: const Color(0xFF1A237E),
                onTap: () => context.push(AppRoutes.library),
              ),
              _QuickActionTile(
                icon: Icons.auto_awesome_outlined,
                label: 'AI Tutor',
                color: const Color(0xFF6A1B9A),
                onTap: () => context.go(AppRoutes.ai),
              ),
              _QuickActionTile(
                icon: Icons.library_books_outlined,
                label: 'Browse Library',
                color: const Color(0xFF00897B),
                onTap: () => context.go(AppRoutes.library),
              ),
              _QuickActionTile(
                icon: Icons.sticky_note_2_outlined,
                label: 'My Notes',
                color: const Color(0xFF00897B),
                onTap: () => context.go(AppRoutes.notes),
              ),
              _QuickActionTile(
                icon: Icons.note_add_outlined,
                label: 'New Note',
                color: const Color(0xFFFF6F00),
                onTap: () => context.push(AppRoutes.noteEdit),
              ),
              _QuickActionTile(
                icon: Icons.bookmark_border,
                label: 'Bookmarks',
                color: const Color(0xFFE53935),
                onTap: () => context.push(AppRoutes.bookmarks),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.08),
                color.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
