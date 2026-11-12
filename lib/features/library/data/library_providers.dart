import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/enums.dart';
import '../../../core/storage/cover_storage_service.dart';
import '../../../core/storage/pdf_storage_service.dart';
import 'book_repository.dart';
import 'library_filters.dart';

// Re-export database providers so screens that import this file also get
// allSubjectsProvider, allBooksProvider, libraryStatsProvider, etc.
export '../../../core/database/database_provider.dart';

/// Provides the [BookRepository] singleton.
final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(
    ref.watch(booksDaoProvider),
    ref.watch(subjectsDaoProvider),
    ref.watch(pdfStorageServiceProvider),
    ref.watch(coverStorageServiceProvider),
  );
});

// ── Filter state ─────────────────────────────────────────────────────────────

/// Manages the library filter/sort state.
class LibraryFiltersNotifier extends Notifier<LibraryFilters> {
  @override
  LibraryFilters build() => const LibraryFilters();

  void setSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);

  void setGrade(int? grade) {
    state = grade == null
        ? state.copyWith(clearGrade: true)
        : state.copyWith(selectedGrade: grade);
  }

  void setCategory(BookCategory? category) {
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(selectedCategory: category);
  }

  void setSubject(int? subjectId) {
    state = subjectId == null
        ? state.copyWith(clearSubject: true)
        : state.copyWith(selectedSubjectId: subjectId);
  }

  void setSortBy(SortBy sortBy) => state = state.copyWith(sortBy: sortBy);

  void clearFilters() => state = const LibraryFilters();
}

final libraryFiltersProvider =
    NotifierProvider<LibraryFiltersNotifier, LibraryFilters>(
  LibraryFiltersNotifier.new,
);

// ── Subject map ──────────────────────────────────────────────────────────────

/// Maps subject IDs to names, reacting to subject changes.
final subjectMapProvider = StreamProvider<Map<int, String>>((ref) {
  return ref.watch(subjectsDaoProvider).watchAllSubjects().map((subjects) {
    return {for (final s in subjects) s.id: s.name};
  });
});

// ── Filtered books ───────────────────────────────────────────────────────────

/// Watches books filtered and sorted according to the current filter state.
final filteredBooksProvider = StreamProvider<List<Book>>((ref) async* {
  final filters = ref.watch(libraryFiltersProvider);
  final booksDao = ref.watch(booksDaoProvider);
  final subjectsDao = ref.watch(subjectsDaoProvider);

  // Load subjects once for name-based search.
  final subjects = await subjectsDao.getAllSubjects();
  final subjectMap = {for (final s in subjects) s.id: s.name};

  await for (final books in booksDao.watchAllBooks()) {
    yield LibraryFilterEngine.apply(books, filters, subjectMap);
  }
});

/// Watches a single book by id.
final bookByIdProvider = StreamProvider.family<Book?, int>((ref, id) {
  return ref.watch(booksDaoProvider).watchBook(id);
});

/// Watches reading progress for a book (used in book details).
final progressByBookProvider =
    StreamProvider.family<ReadingProgressEntry?, int>((ref, bookId) {
  return ref.watch(progressDaoProvider).watchProgress(bookId);
});

/// Watches bookmarks for a book (used in book details).
final bookmarksByBookProvider =
    StreamProvider.family<List<Bookmark>, int>((ref, bookId) {
  return ref.watch(bookmarksDaoProvider).watchBookmarksByBook(bookId);
});

/// Watches notes for a book (used in book details).
final notesByBookProvider = StreamProvider.family<List<Note>, int>((ref, bookId) {
  return ref.watch(notesDaoProvider).watchNotesByBook(bookId);
});
