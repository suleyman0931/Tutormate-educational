import 'package:drift/drift.dart';

import '../app_database.dart';

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
    return _db.into(_db.readingProgress).insertOnConflictUpdate(companion);
  }

  /// Deletes reading progress for a book (used when a book is deleted).
  Future<int> deleteProgress(int bookId) {
    return (_db.delete(_db.readingProgress)
          ..where((t) => t.bookId.equals(bookId)))
        .go();
  }
}
