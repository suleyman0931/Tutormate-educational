import 'package:drift/drift.dart';

import '../app_database.dart';
import '../enums.dart';

/// Library statistics for the dashboard.
class LibraryStats {
  final int totalBooks;
  final int studentBooks;
  final int teacherGuides;
  final int shortNotes;
  final int otherBooks;

  const LibraryStats({
    required this.totalBooks,
    required this.studentBooks,
    required this.teacherGuides,
    required this.shortNotes,
    required this.otherBooks,
  });

  static const empty = LibraryStats(
    totalBooks: 0,
    studentBooks: 0,
    teacherGuides: 0,
    shortNotes: 0,
    otherBooks: 0,
  );
}

/// Data-access object for the [Books] table.
class BooksDao {
  final AppDatabase _db;
  BooksDao(this._db);

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Watches all books ordered by creation date (newest first).
  Stream<List<Book>> watchAllBooks() {
    return (_db.select(_db.books)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Returns all books ordered by creation date (newest first).
  Future<List<Book>> getAllBooks() {
    return (_db.select(_db.books)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Watches a single book by id.
  Stream<Book?> watchBook(int id) {
    return (_db.select(_db.books)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Returns a single book by id, or null.
  Future<Book?> getBook(int id) {
    return (_db.select(_db.books)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Watches recently opened books (those with a non-null [lastOpenedAt]).
  Stream<List<Book>> watchRecentlyOpened({int limit = 10}) {
    return (_db.select(_db.books)
          ..where((t) => t.lastOpenedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.lastOpenedAt)])
          ..limit(limit))
        .watch();
  }

  /// Watches the last opened book (most recent [lastOpenedAt]).
  Stream<Book?> watchLastOpenedBook() {
    return (_db.select(_db.books)
          ..where((t) => t.lastOpenedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.lastOpenedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Finds a book by its file hash (for duplicate detection).
  Future<Book?> findByHash(String hash) {
    return (_db.select(_db.books)..where((t) => t.fileHash.equals(hash)))
        .getSingleOrNull();
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Inserts a new book and returns its id.
  Future<int> insertBook(BooksCompanion book) {
    return _db.into(_db.books).insert(book);
  }

  /// Updates an existing book. Returns true on success.
  Future<bool> updateBook(Book book) {
    return _db.update(_db.books).replace(book);
  }

  /// Deletes a book by id. Cascading FK rules remove related progress,
  /// bookmarks, and annotations; notes have [bookId] set to NULL.
  Future<int> deleteBook(int id) {
    return (_db.delete(_db.books)..where((t) => t.id.equals(id))).go();
  }

  /// Updates the [lastOpenedAt] timestamp for a book.
  Future<void> updateLastOpened(int id) {
    return (_db.update(_db.books)..where((t) => t.id.equals(id)))
        .write(BooksCompanion(lastOpenedAt: Value(DateTime.now())));
  }

  // ── Statistics ────────────────────────────────────────────────────────────

  /// Watches aggregated library statistics in a single query.
  Stream<LibraryStats> watchLibraryStats() {
    final total = _db.books.id.count();
    final studentCount = _db.books.category.count(
      filter: _db.books.category.equals(BookCategory.studentBook.name),
    );
    final teacherCount = _db.books.category.count(
      filter: _db.books.category.equals(BookCategory.teacherGuide.name),
    );
    final shortNoteCount = _db.books.category.count(
      filter: _db.books.category.equals(BookCategory.shortNote.name),
    );
    final otherCount = _db.books.category.count(
      filter: _db.books.category.equals(BookCategory.other.name),
    );

    final query = _db.selectOnly(_db.books)
      ..addColumns([
        total,
        studentCount,
        teacherCount,
        shortNoteCount,
        otherCount,
      ]);

    return query.map((row) {
      return LibraryStats(
        totalBooks: row.read(total) ?? 0,
        studentBooks: row.read(studentCount) ?? 0,
        teacherGuides: row.read(teacherCount) ?? 0,
        shortNotes: row.read(shortNoteCount) ?? 0,
        otherBooks: row.read(otherCount) ?? 0,
      );
    }).watchSingle();
  }
}
