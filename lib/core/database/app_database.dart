import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../app/constants/app_constants.dart';
import 'enums.dart';
import 'tables/annotations.dart';
import 'tables/bookmarks.dart';
import 'tables/books.dart';
import 'tables/notes.dart';
import 'tables/reading_progress.dart';
import 'tables/subjects.dart';

part 'app_database.g.dart';

/// TutorMate's Drift database.
///
/// All 6 tables with foreign-key constraints, indexes, and a migration
/// strategy that seeds default subjects on first creation.
@DriftDatabase(
  tables: [Books, Subjects, ReadingProgress, Bookmarks, Notes, Annotations],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _seedSubjects();
      },
      onUpgrade: (m, from, to) async {
        // Future migrations go here, incrementing schemaVersion.
      },
      beforeOpen: (details) async {
        // Enable foreign keys and use WAL for better concurrent read/write.
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode = WAL');
        // Idempotent index creation (runs on every open, safe with IF NOT EXISTS).
        await _createIndexes();
      },
    );
  }

  // ── Seed ─────────────────────────────────────────────────────────────────

  Future<void> _seedSubjects() async {
    final now = DateTime.now();
    for (final name in AppConstants.defaultSubjects) {
      await into(subjects).insertOnConflictUpdate(
        SubjectsCompanion.insert(name: name, createdAt: Value(now)),
      );
    }
  }

  // ── Custom indexes ────────────────────────────────────────────────────────
  // Idempotent index creation with IF NOT EXISTS so this is safe to run on
  // every open (covers both fresh installs and upgrades).

  Future<void> _createIndexes() async {
    final stmts = [
      'CREATE INDEX IF NOT EXISTS idx_books_subject_id ON books(subject_id)',
      'CREATE INDEX IF NOT EXISTS idx_books_grade ON books(grade)',
      'CREATE INDEX IF NOT EXISTS idx_books_category ON books(category)',
      'CREATE INDEX IF NOT EXISTS idx_books_created_at ON books(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_books_last_opened_at ON books(last_opened_at)',
      'CREATE INDEX IF NOT EXISTS idx_annotations_book_page ON annotations(book_id, page_number)',
      'CREATE INDEX IF NOT EXISTS idx_notes_book_id ON notes(book_id)',
      'CREATE INDEX IF NOT EXISTS idx_notes_subject_id ON notes(subject_id)',
      'CREATE INDEX IF NOT EXISTS idx_notes_grade ON notes(grade)',
      'CREATE INDEX IF NOT EXISTS idx_notes_created_at ON notes(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_book_id ON bookmarks(book_id)',
    ];
    for (final stmt in stmts) {
      await customStatement(stmt);
    }
  }

  static DatabaseConnection _openConnection() {
    return driftDatabase(name: AppConstants.databaseName);
  }
}
