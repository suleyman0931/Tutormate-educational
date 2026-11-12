import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_constants.dart';
import '../../../app/router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/enums.dart';
import '../../../core/widgets/book_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/library_filters.dart';
import '../data/library_providers.dart';

/// The main library screen with search, combined filters, sorting,
/// and a responsive book grid.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  bool _searchVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickAndImport() async {
    final repo = ref.read(bookRepositoryProvider);
    final files = await repo.pickPdfFiles(allowMultiple: true);
    if (files.isEmpty || !mounted) return;
    context.push(AppRoutes.import, extra: files);
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchController.clear();
        ref.read(libraryFiltersProvider.notifier).setSearchQuery('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(libraryFiltersProvider);
    final booksAsync = ref.watch(filteredBooksProvider);
    final subjectMapAsync = ref.watch(subjectMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: _searchVisible
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search books...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    ref.read(libraryFiltersProvider.notifier).setSearchQuery(value),
              )
            : const Text('Library'),
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          PopupMenuButton<SortBy>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (sortBy) =>
                ref.read(libraryFiltersProvider.notifier).setSortBy(sortBy),
            itemBuilder: (context) => SortBy.values.map((s) {
              return PopupMenuItem(
                value: s,
                child: Row(
                  children: [
                    if (filters.sortBy == s)
                      Icon(Icons.check, color: Theme.of(context).colorScheme.primary,
                          size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    Text(s.label),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter bar ────────────────────────────────────────────────────────
          _FilterBar(filters: filters),
          const Divider(height: 1),

          // ── Book grid ──────────────────────────────────────────────────────────
          Expanded(
            child: booksAsync.when(
              data: (books) {
                if (books.isEmpty) {
                  return EmptyState(
                    icon: filters.hasActiveFilters
                        ? Icons.filter_alt_off_outlined
                        : Icons.library_books_outlined,
                    title: filters.hasActiveFilters
                        ? 'No books match your filters'
                        : 'Your library is empty',
                    message: filters.hasActiveFilters
                        ? 'Try adjusting the filters or clearing them.'
                        : 'Import PDF or Text files to get started.',
                    actionLabel: filters.hasActiveFilters ? null : 'Import Documents',
                    onAction: filters.hasActiveFilters ? null : _pickAndImport,
                  );
                }
                return subjectMapAsync.when(
                  data: (subjectMap) => _buildBookGrid(books, subjectMap),
                  loading: () => const LoadingIndicator(),
                  error: (_, _) => _buildBookGrid(books, {}),
                );
              },
              loading: () => const LoadingIndicator(),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndImport,
        icon: const Icon(Icons.add),
        label: const Text('Import'),
        tooltip: 'Import documents',
      ),
    );
  }

  Widget _buildBookGrid(List<Book> books, Map<int, String> subjectMap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive column count: 2 on phones, 3+ on tablets.
        final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(2, 6);
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.55,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return BookCard(
              book: book,
              subjectName: subjectMap[book.subjectId],
              onTap: () => context.push(AppRoutes.bookDetailsFor(book.id)),
            );
          },
        );
      },
    );
  }
}

/// A horizontally scrollable filter bar with grade, category, and subject
/// dropdowns.
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filters});
  final LibraryFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(allSubjectsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // ── Grade filter ──────────────────────────────────────────────────
            _FilterDropdown<int?>(
              label: filters.selectedGrade != null
                  ? 'Grade ${filters.selectedGrade}'
                  : 'All Grades',
              icon: Icons.grade_outlined,
              selected: filters.selectedGrade,
              items: [
                const _DropdownItem(label: 'All Grades', value: null),
                ...AppConstants.grades.map(
                  (g) => _DropdownItem(label: 'Grade $g', value: g),
                ),
              ],
              onChanged: (v) =>
                  ref.read(libraryFiltersProvider.notifier).setGrade(v),
            ),

            // ── Category filter ────────────────────────────────────────────────
            _FilterDropdown<BookCategory?>(
              label: filters.selectedCategory?.shortLabel ?? 'All Categories',
              icon: Icons.category_outlined,
              selected: filters.selectedCategory,
              items: [
                const _DropdownItem(label: 'All Categories', value: null),
                ...BookCategory.values.map(
                  (c) => _DropdownItem(label: c.label, value: c),
                ),
              ],
              onChanged: (v) =>
                  ref.read(libraryFiltersProvider.notifier).setCategory(v),
            ),

            // ── Subject filter ────────────────────────────────────────────────
            subjectsAsync.when(
              data: (subjects) => _FilterDropdown<int?>(
                label: _subjectLabel(filters.selectedSubjectId, subjects),
                icon: Icons.subject_outlined,
                selected: filters.selectedSubjectId,
                items: [
                  const _DropdownItem(label: 'All Subjects', value: null),
                  ...subjects.map(
                    (s) => _DropdownItem(label: s.name, value: s.id),
                  ),
                ],
                onChanged: (v) =>
                    ref.read(libraryFiltersProvider.notifier).setSubject(v),
              ),
              loading: () => const SizedBox(
                width: 120,
                child: Center(child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),

            // ── Clear filters ──────────────────────────────────────────────────
            if (filters.hasActiveFilters)
              TextButton.icon(
                onPressed: () {
                  ref.read(libraryFiltersProvider.notifier).clearFilters();
                  _clearSearch(ref);
                },
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _clearSearch(WidgetRef ref) {
    ref.read(libraryFiltersProvider.notifier).setSearchQuery('');
  }

  String _subjectLabel(int? id, List<Subject> subjects) {
    if (id == null) return 'All Subjects';
    return subjects.firstWhere(
      (s) => s.id == id,
      orElse: () => Subject(id: -1, name: 'Unknown', createdAt: DateTime.now()),
    ).name;
  }
}

/// A compact dropdown button used in the filter bar.
class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.icon,
    required this.selected,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T selected;
  final List<_DropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = selected != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: hasSelection
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: selected,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item.value,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 6),
                  Text(item.label),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DropdownItem<T> {
  final String label;
  final T value;
  const _DropdownItem({required this.label, required this.value});
}
