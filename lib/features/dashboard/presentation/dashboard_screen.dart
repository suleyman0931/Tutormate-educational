import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/progress_dao.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_card.dart';
import '../../library/data/library_providers.dart';

/// The Home dashboard: greeting header, search, library overview,
/// continue reading, recently opened books, and quick actions.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
    FocusScope.of(context).unfocus();
  }

  String get _greeting {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final bool searching = _query.trim().isNotEmpty;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {},
        edgeOffset: 120,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeader(context),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(child: _buildSearchField(context)),
            ),
            if (searching)
              SliverToBoxAdapter(child: _SearchResultsSection(query: _query.trim()))
            else ...[
              const SliverToBoxAdapter(child: _StatsSection()),
              const SliverToBoxAdapter(child: _ContinueReadingSection()),
              const SliverToBoxAdapter(child: _RecentlyOpenedSection()),
              const SliverToBoxAdapter(child: _QuickActionsSection()),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final double topInset = MediaQuery.paddingOf(context).top;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 208,
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: const Text(
        'TutorMate',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.bookmark_border_rounded, color: Colors.white),
          tooltip: 'Bookmarks',
          onPressed: () => context.push(AppRoutes.bookmarks),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: Stack(
            children: [
              Positioned(
                right: -48,
                top: -56,
                child: _glow(180, Colors.white.withValues(alpha: 0.06)),
              ),
              Positioned(
                right: 36,
                bottom: -40,
                child: _glow(120, AppColors.secondary.withValues(alpha: 0.22)),
              ),
              Positioned(
                left: -36,
                bottom: 28,
                child: _glow(96, Colors.white.withValues(alpha: 0.04)),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  topInset + kToolbarHeight + 4,
                  20,
                  20,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ready for your next chapter?',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 13.5,
                      ),
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

  Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() => _query = value),
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search books, subjects, or grades',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 21,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 19),
                  tooltip: 'Clear search',
                  onPressed: _clearSearch,
                ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

// ── Search results ────────────────────────────────────────────────────────────

class _SearchResultsSection extends ConsumerWidget {
  const _SearchResultsSection({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(allBooksProvider);
    final subjectMap = ref.watch(subjectMapProvider).valueOrNull ?? {};

    return booksAsync.when(
      data: (books) {
        final String q = query.toLowerCase();
        final results = books.where((book) {
          final String subject = subjectMap[book.subjectId] ?? '';
          return book.title.toLowerCase().contains(q) ||
              subject.toLowerCase().contains(q) ||
              'grade ${book.grade}'.contains(q);
        }).toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );

        if (results.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 52,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.45),
                ),
                const SizedBox(height: 14),
                Text(
                  'No books match "$query"',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Try a different title, subject, or grade.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: 'Search Results (${results.length})'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final book in results)
                    _SearchResultTile(
                      book: book,
                      subjectName: subjectMap[book.subjectId],
                    ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Could not load books.')),
      ),
    );
  }
}

class _SearchResultTile extends ConsumerWidget {
  const _SearchResultTile({required this.book, this.subjectName});

  final Book book;
  final String? subjectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final subtitleParts = [
      'Grade ${book.grade}',
      if (subjectName != null && subjectName!.isNotEmpty) subjectName!,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.cardTheme.color ?? colorScheme.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: () {
            ref.read(booksDaoProvider).updateLastOpened(book.id);
            context.push(AppRoutes.readerFor(book.id));
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: SizedBox(
                    width: 42,
                    height: 56,
                    child: _buildCover(colorScheme),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
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
                      const SizedBox(height: 3),
                      Text(
                        subtitleParts.join(' · '),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(ColorScheme colorScheme) {
    if (book.coverPath != null && book.coverPath!.isNotEmpty) {
      final File file = File(book.coverPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return ColoredBox(
      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
      child: Icon(
        Icons.auto_stories_rounded,
        size: 20,
        color: colorScheme.primary.withValues(alpha: 0.6),
      ),
    );
  }
}

// ── Statistics ────────────────────────────────────────────────────────────────

class _StatsSection extends ConsumerWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(libraryStatsProvider);
    final bookmarkCountAsync = ref.watch(bookmarkCountProvider);

    return statsAsync.when(
      data: (stats) {
        final int bookmarkCount = bookmarkCountAsync.valueOrNull ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Library Overview'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 108,
                ),
                children: [
                  StatCard(
                    icon: Icons.library_books_rounded,
                    value: stats.totalBooks,
                    label: 'Total Books',
                    color: AppColors.primary,
                  ),
                  StatCard(
                    icon: Icons.menu_book_rounded,
                    value: stats.studentBooks,
                    label: 'Student Books',
                    color: AppColors.secondary,
                  ),
                  StatCard(
                    icon: Icons.person_outline_rounded,
                    value: stats.teacherGuides,
                    label: 'Teacher Guides',
                    color: AppColors.violet,
                  ),
                  StatCard(
                    icon: Icons.notes_rounded,
                    value: stats.shortNotes,
                    label: 'Short Notes',
                    color: AppColors.amber,
                  ),
                  StatCard(
                    icon: Icons.folder_outlined,
                    value: stats.otherBooks,
                    label: 'Other Books',
                    color: AppColors.slate,
                  ),
                  StatCard(
                    icon: Icons.bookmark_rounded,
                    value: bookmarkCount,
                    label: 'Bookmarks',
                    color: AppColors.rose,
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
  const _ContinueReadingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueAsync = ref.watch(continueReadingProvider);

    return continueAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Continue Reading'),
            SizedBox(
              height: 158,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _ContinueReadingCard(item: items[index]),
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

class _ContinueReadingCard extends ConsumerWidget {
  const _ContinueReadingCard({required this.item});

  final ContinueReadingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Book book = item.book;
    final int page = item.progress.currentPage;
    final int total = book.totalPages;
    final String subjectName =
        ref.watch(subjectMapProvider).valueOrNull?[book.subjectId] ?? '';
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    double value = item.progress.progressPercentage;
    if (total > 0) value = page / total;
    value = value.clamp(0.0, 1.0);
    final int pct = (value * 100).round();

    return SizedBox(
      width: 288,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.22),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: InkWell(
                onTap: () {
                  ref.read(booksDaoProvider).updateLastOpened(book.id);
                  context.push(
                    AppRoutes.readerFor(book.id),
                    extra: page > 1 ? page : null,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 92,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: _buildCover(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'PICK UP WHERE YOU LEFT OFF',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              book.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _chip('Grade ${book.grade}'),
                                if (subjectName.isNotEmpty) ...[
                                  const SizedBox(width: 5),
                                  Flexible(child: _chip(subjectName)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: value,
                                minHeight: 5,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.18),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.accentLight,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              total > 0
                                  ? 'Page $page of $total · $pct%'
                                  : 'Page $page',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    if (item.book.coverPath != null && item.book.coverPath!.isNotEmpty) {
      final File file = File(item.book.coverPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return ColoredBox(
      color: AppColors.secondary.withValues(alpha: 0.35),
      child: const Center(
        child: Icon(Icons.auto_stories_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Recently Opened ───────────────────────────────────────────────────────────

class _RecentlyOpenedSection extends ConsumerWidget {
  const _RecentlyOpenedSection();

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
            SectionHeader(
              title: 'Recently Opened',
              actionLabel: 'See All',
              onAction: () => context.go(AppRoutes.library),
            ),
            SizedBox(
              height: 204,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return SizedBox(
      width: 118,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              ref.read(booksDaoProvider).updateLastOpened(book.id);
              context.push(AppRoutes.readerFor(book.id));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 146,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: theme.brightness == Brightness.dark ? 0.3 : 0.08,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildCover(colorScheme),
                        Positioned(
                          left: 7,
                          bottom: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'G${book.grade}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  book.title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subjectName != null && subjectName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subjectName!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
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

  Widget _buildCover(ColorScheme colorScheme) {
    if (book.coverPath != null && book.coverPath!.isNotEmpty) {
      final File file = File(book.coverPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.9),
            colorScheme.secondaryContainer.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 34,
          color: colorScheme.primary.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Quick Actions'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 70,
            ),
            children: [
              _QuickActionTile(
                icon: Icons.upload_file_rounded,
                label: 'Import',
                color: AppColors.primary,
                onTap: () => context.push(AppRoutes.library),
              ),
              _QuickActionTile(
                icon: Icons.auto_awesome_rounded,
                label: 'AI Tutor',
                color: AppColors.violet,
                onTap: () => context.go(AppRoutes.ai),
              ),
              _QuickActionTile(
                icon: Icons.note_add_rounded,
                label: 'New Note',
                color: AppColors.amber,
                onTap: () => context.push(AppRoutes.noteEdit),
              ),
              _QuickActionTile(
                icon: Icons.bookmark_rounded,
                label: 'Bookmarks',
                color: AppColors.rose,
                onTap: () => context.push(AppRoutes.bookmarks),
              ),
            ],
          ),
        ),
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Material(
      color: theme.cardTheme.color ?? colorScheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
