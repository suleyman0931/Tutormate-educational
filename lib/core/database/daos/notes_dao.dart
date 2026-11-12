import 'package:drift/drift.dart';

import '../app_database.dart';

/// Data-access object for the [Notes] table.
class NotesDao {
  final AppDatabase _db;
  NotesDao(this._db);

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Watches all notes ordered by creation date (newest first).
  Stream<List<Note>> watchAllNotes() {
    return (_db.select(_db.notes)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Returns all notes ordered by creation date.
  Future<List<Note>> getAllNotes() {
    return (_db.select(_db.notes)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Watches notes for a specific book.
  Stream<List<Note>> watchNotesByBook(int bookId) {
    return (_db.select(_db.notes)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Watches notes for a specific book and page.
  Stream<List<Note>> watchNotesByPage(int bookId, int pageNumber) {
    return (_db.select(_db.notes)
          ..where(
            (t) => t.bookId.equals(bookId) & t.pageNumber.equals(pageNumber),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Returns a note by id.
  Future<Note?> getNote(int id) {
    return (_db.select(_db.notes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Inserts a note and returns its id.
  Future<int> insertNote(NotesCompanion note) {
    return _db.into(_db.notes).insert(note);
  }

  /// Updates an existing note.
  Future<bool> updateNote(Note note) {
    return _db.update(_db.notes).replace(note);
  }

  /// Deletes a note by id.
  Future<int> deleteNote(int id) {
    return (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();
  }
}
