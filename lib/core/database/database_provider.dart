import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'daos/annotations_dao.dart';
import 'daos/bookmarks_dao.dart';
import 'daos/books_dao.dart';
import 'daos/notes_dao.dart';
import 'daos/progress_dao.dart';
import 'daos/subjects_dao.dart';

/// Provides the singleton [AppDatabase] instance.
///
/// The database is closed automatically when the provider is disposed.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Provides the [BooksDao].
final booksDaoProvider = Provider<BooksDao>((ref) {
  return BooksDao(ref.watch(databaseProvider));
});

/// Provides the [SubjectsDao].
final subjectsDaoProvider = Provider<SubjectsDao>((ref) {
  return SubjectsDao(ref.watch(databaseProvider));
});

/// Provides the [ProgressDao].
final progressDaoProvider = Provider<ProgressDao>((ref) {
  return ProgressDao(ref.watch(databaseProvider));
});

/// Provides the [BookmarksDao].
final bookmarksDaoProvider = Provider<BookmarksDao>((ref) {
  return BookmarksDao(ref.watch(databaseProvider));
});

/// Provides the [NotesDao].
final notesDaoProvider = Provider<NotesDao>((ref) {
  return NotesDao(ref.watch(databaseProvider));
});

/// Provides the [AnnotationsDao].
final annotationsDaoProvider = Provider<AnnotationsDao>((ref) {
  return AnnotationsDao(ref.watch(databaseProvider));
});

// ── Convenience stream providers ─────────────────────────────────────────

/// Watches all books in the library.
final allBooksProvider = StreamProvider<List<Book>>((ref) {
  return ref.watch(booksDaoProvider).watchAllBooks();
});

/// Watches all subjects.
final allSubjectsProvider = StreamProvider<List<Subject>>((ref) {
  return ref.watch(subjectsDaoProvider).watchAllSubjects();
});

/// Watches library statistics for the dashboard.
final libraryStatsProvider = StreamProvider<LibraryStats>((ref) {
  return ref.watch(booksDaoProvider).watchLibraryStats();
});

/// Watches the total bookmark count.
final bookmarkCountProvider = StreamProvider<int>((ref) {
  return ref.watch(bookmarksDaoProvider).watchBookmarkCount();
});

/// Watches recently opened books.
final recentlyOpenedBooksProvider = StreamProvider<List<Book>>((ref) {
  return ref.watch(booksDaoProvider).watchRecentlyOpened();
});

/// Watches the last opened book.
final lastOpenedBookProvider = StreamProvider<Book?>((ref) {
  return ref.watch(booksDaoProvider).watchLastOpenedBook();
});

/// Watches all bookmarks.
final allBookmarksProvider = StreamProvider<List<Bookmark>>((ref) {
  return ref.watch(bookmarksDaoProvider).watchAllBookmarks();
});

/// Watches all notes.
final allNotesProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(notesDaoProvider).watchAllNotes();
});
