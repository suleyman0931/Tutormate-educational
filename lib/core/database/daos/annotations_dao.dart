import 'package:drift/drift.dart';

import '../app_database.dart';

/// Data-access object for the [Annotations] table.
class AnnotationsDao {
  final AppDatabase _db;
  AnnotationsDao(this._db);

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Watches annotations for a specific book page.
  Stream<List<Annotation>> watchAnnotationsByPage(int bookId, int pageNumber) {
    return (_db.select(_db.annotations)
          ..where(
            (t) => t.bookId.equals(bookId) & t.pageNumber.equals(pageNumber),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Returns annotations for a specific book page.
  Future<List<Annotation>> getAnnotationsByPage(int bookId, int pageNumber) {
    return (_db.select(_db.annotations)
          ..where(
            (t) => t.bookId.equals(bookId) & t.pageNumber.equals(pageNumber),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Watches all annotations for a book (all pages).
  Stream<List<Annotation>> watchAnnotationsByBook(int bookId) {
    return (_db.select(_db.annotations)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.asc(t.pageNumber)]))
        .watch();
  }

  /// Returns all annotations for a book (all pages).
  Future<List<Annotation>> getAllAnnotationsByBook(int bookId) {
    return (_db.select(_db.annotations)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.asc(t.pageNumber)]))
        .get();
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Inserts an annotation and returns its id.
  Future<int> insertAnnotation(AnnotationsCompanion annotation) {
    return _db.into(_db.annotations).insert(annotation);
  }

  /// Updates an existing annotation.
  Future<bool> updateAnnotation(Annotation annotation) {
    return _db.update(_db.annotations).replace(annotation);
  }

  /// Deletes an annotation by id.
  Future<int> deleteAnnotation(int id) {
    return (_db.delete(_db.annotations)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes all annotations for a book (used during book deletion cascade).
  Future<int> deleteAnnotationsByBook(int bookId) {
    return (_db.delete(_db.annotations)
          ..where((t) => t.bookId.equals(bookId)))
        .go();
  }
}
