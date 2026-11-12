import 'package:drift/drift.dart';

import '../app_database.dart';

/// Data-access object for the [Bookmarks] table.
class BookmarksDao {
  final AppDatabase _db;
  BookmarksDao(this._db);

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Watches all bookmarks ordered by creation date (newest first).
  Stream<List<Bookmark>> watchAllBookmarks() {
    return (_db.select(_db.bookmarks)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Watches bookmarks for a specific book.
  Stream<List<Bookmark>> watchBookmarksByBook(int bookId) {
    return (_db.select(_db.bookmarks)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.asc(t.pageNumber)]))
        .watch();
  }

  /// Returns bookmarks for a specific book.
  Future<List<Bookmark>> getBookmarksByBook(int bookId) {
    return (_db.select(_db.bookmarks)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.asc(t.pageNumber)]))
        .get();
  }

  /// Returns whether a bookmark exists for the given book and page.
  Future<Bookmark?> getBookmark(int bookId, int pageNumber) {
    return (_db.select(_db.bookmarks)
          ..where((t) => t.bookId.equals(bookId) & t.pageNumber.equals(pageNumber)))
        .getSingleOrNull();
  }

  /// Watches the total bookmark count (for dashboard stats).
  Stream<int> watchBookmarkCount() {
    final count = _db.bookmarks.id.count();
    final query = _db.selectOnly(_db.bookmarks)..addColumns([count]);
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Inserts a bookmark. Returns its id.
  /// Throws if a bookmark already exists for (bookId, pageNumber).
  Future<int> insertBookmark(BookmarksCompanion bookmark) {
    return _db.into(_db.bookmarks).insert(bookmark);
  }

  /// Updates an existing bookmark.
  Future<bool> updateBookmark(Bookmark bookmark) {
    return _db.update(_db.bookmarks).replace(bookmark);
  }

  /// Deletes a bookmark by id.
  Future<int> deleteBookmark(int id) {
    return (_db.delete(_db.bookmarks)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes bookmarks for a book (used during book deletion cascade).
  Future<int> deleteBookmarksByBook(int bookId) {
    return (_db.delete(_db.bookmarks)
          ..where((t) => t.bookId.equals(bookId)))
        .go();
  }
}
