import 'package:drift/drift.dart';

import '../app_database.dart';

/// A book paired with its saved reading progress, used by the dashboard's
/// "Continue Reading" list.
class ContinueReadingItem {
  final Book book;
  final ReadingProgressEntry progress;

  const ContinueReadingItem({required this.book, required this.progress});
}

/// Data-access object for the [ReadingProgress] table.
class ProgressDao {
  final AppDatabase _db;
  ProgressDao(this._db);

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Watches reading progress for a book, or null if no progress yet.
  Stream<ReadingProgressEntry?> watchProgress(int bookId) {
    return (_db.select(_db.readingProgress)
          ..where((t) => t.bookId.equals(bookId)))
        .watchSingleOrNull();
  }

  /// Watches every book that has saved progress, most recently read first.
  Stream<List<ContinueReadingItem>> watchContinueReading({int limit = 7}) {
    final query = _db.select(_db.readingProgress).join([
      innerJoin(_db.books, _db.books.id.equalsExp(_db.readingProgress.bookId)),
    ])
      ..orderBy([OrderingTerm.desc(_db.readingProgress.lastReadAt)])
      ..limit(limit);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => ContinueReadingItem(
                  book: row.readTable(_db.books),
                  progress: row.readTable(_db.readingProgress),
                ),
              )
              .toList(),
        );
  }

  /// Watches progress rows for all books (used to show pages in reader tabs).
  Stream<List<ReadingProgressEntry>> watchAllProgress() {
    return _db.select(_db.readingProgress).watch();
  }

  /// Returns reading progress for a book, or null.
  Future<ReadingProgressEntry?> getProgress(int bookId) {
    return (_db.select(_db.readingProgress)
          ..where((t) => t.bookId.equals(bookId)))
        .getSingleOrNull();
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Inserts or updates reading progress for a book (upsert).
  Future<void> saveProgress({
    required int bookId,
    required int currentPage,
    required double progressPercentage,
  }) {
    final companion = ReadingProgressCompanion.insert(
      bookId: bookId,
      currentPage: Value(currentPage),
      progressPercentage: Value(progressPercentage),
      lastReadAt: Value(DateTime.now()),
    );
    return _db.into(_db.readingProgress).insert(
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [_db.readingProgress.bookId],
          ),
        );
  }

  /// Deletes reading progress for a book (used when a book is deleted).
  Future<int> deleteProgress(int bookId) {
    return (_db.delete(_db.readingProgress)
          ..where((t) => t.bookId.equals(bookId)))
        .go();
  }
}
