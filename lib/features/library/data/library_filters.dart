import '../../../core/database/app_database.dart';
import '../../../core/database/enums.dart';

/// Sort options for the library.
enum SortBy {
  recentlyAdded,
  recentlyOpened,
  alphabeticalAZ,
  alphabeticalZA,
  mostRead;

  String get label {
    switch (this) {
      case SortBy.recentlyAdded:
        return 'Recently Added';
      case SortBy.recentlyOpened:
        return 'Recently Opened';
      case SortBy.alphabeticalAZ:
        return 'Title A–Z';
      case SortBy.alphabeticalZA:
        return 'Title Z–A';
      case SortBy.mostRead:
        return 'Most Read';
    }
  }
}

/// Immutable filter state for the library screen.
class LibraryFilters {
  final String searchQuery;
  final int? selectedGrade; // null = all grades
  final BookCategory? selectedCategory; // null = all categories
  final int? selectedSubjectId; // null = all subjects
  final SortBy sortBy;

  const LibraryFilters({
    this.searchQuery = '',
    this.selectedGrade,
    this.selectedCategory,
    this.selectedSubjectId,
    this.sortBy = SortBy.recentlyAdded,
  });

  LibraryFilters copyWith({
    String? searchQuery,
    int? selectedGrade,
    BookCategory? selectedCategory,
    int? selectedSubjectId,
    SortBy? sortBy,
    bool clearGrade = false,
    bool clearCategory = false,
    bool clearSubject = false,
  }) {
    return LibraryFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedGrade: clearGrade ? null : (selectedGrade ?? this.selectedGrade),
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedSubjectId:
          clearSubject ? null : (selectedSubjectId ?? this.selectedSubjectId),
      sortBy: sortBy ?? this.sortBy,
    );
  }

  /// Whether any non-default filter is active.
  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      selectedGrade != null ||
      selectedCategory != null ||
      selectedSubjectId != null;
}

/// Pure filtering and sorting logic — kept separate from providers so it
/// can be unit-tested in Phase 7.
class LibraryFilterEngine {
  LibraryFilterEngine._();

  /// Applies [filters] to a list of [books], using [subjectMap] for
  /// subject-name-based search.
  static List<Book> apply(
    List<Book> books,
    LibraryFilters filters,
    Map<int, String> subjectMap,
  ) {
    var result = books.toList();

    // ── Search ─────────────────────────────────────────────────────────
    if (filters.searchQuery.isNotEmpty) {
      final query = filters.searchQuery.toLowerCase();
      result = result.where((book) {
        final subjectName = subjectMap[book.subjectId]?.toLowerCase() ?? '';
        return book.title.toLowerCase().contains(query) ||
            subjectName.contains(query) ||
            book.category.label.toLowerCase().contains(query) ||
            (book.author?.toLowerCase().contains(query) ?? false) ||
            (book.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // ── Grade filter ─────────────────────────────────────────────────────
    if (filters.selectedGrade != null) {
      result = result.where((b) => b.grade == filters.selectedGrade).toList();
    }

    // ── Category filter ──────────────────────────────────────────────────
    if (filters.selectedCategory != null) {
      result =
          result.where((b) => b.category == filters.selectedCategory).toList();
    }

    // ── Subject filter ────────────────────────────────────────────────────
    if (filters.selectedSubjectId != null) {
      result = result
          .where((b) => b.subjectId == filters.selectedSubjectId)
          .toList();
    }

    // ── Sort ─────────────────────────────────────────────────────────────
    result = _sort(result, filters.sortBy);

    return result;
  }

  static List<Book> _sort(List<Book> books, SortBy sortBy) {
    final sorted = books.toList();
    switch (sortBy) {
      case SortBy.recentlyAdded:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SortBy.recentlyOpened:
        sorted.sort((a, b) {
          final aTime = a.lastOpenedAt;
          final bTime = b.lastOpenedAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1; // nulls last
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
      case SortBy.alphabeticalAZ:
        sorted.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case SortBy.alphabeticalZA:
        sorted.sort((a, b) =>
            b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      case SortBy.mostRead:
        // Sort by whether the book has been opened (has lastOpenedAt),
        // then by most recent.
        sorted.sort((a, b) {
          final aOpened = a.lastOpenedAt != null ? 1 : 0;
          final bOpened = b.lastOpenedAt != null ? 1 : 0;
          if (aOpened != bOpened) return bOpened.compareTo(aOpened);
          final aTime = a.lastOpenedAt;
          final bTime = b.lastOpenedAt;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });
    }
    return sorted;
  }
}
