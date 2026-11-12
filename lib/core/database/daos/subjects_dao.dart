import 'package:drift/drift.dart';

import '../app_database.dart';

/// Data-access object for the [Subjects] table.
class SubjectsDao {
  final AppDatabase _db;
  SubjectsDao(this._db);

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Watches all subjects ordered alphabetically.
  Stream<List<Subject>> watchAllSubjects() {
    return (_db.select(_db.subjects)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Returns all subjects ordered alphabetically.
  Future<List<Subject>> getAllSubjects() {
    return (_db.select(_db.subjects)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Returns a subject by id, or null.
  Future<Subject?> getSubject(int id) {
    return (_db.select(_db.subjects)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Finds a subject by exact name (case-insensitive match handled at app level).
  Future<Subject?> findByName(String name) {
    return (_db.select(_db.subjects)..where((t) => t.name.equals(name)))
        .getSingleOrNull();
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Inserts a subject and returns its id.
  Future<int> insertSubject(SubjectsCompanion subject) {
    return _db.into(_db.subjects).insert(subject);
  }

  /// Updates a subject's name.
  Future<bool> updateSubject(Subject subject) {
    return _db.update(_db.subjects).replace(subject);
  }

  /// Deletes a subject by id.
  /// Books referencing this subject will retain the [subjectId] value
  /// (no cascade); handle reassignment at the domain layer if needed.
  Future<int> deleteSubject(int id) {
    return (_db.delete(_db.subjects)..where((t) => t.id.equals(id))).go();
  }
}
