import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutormate/app/theme/app_theme.dart';
import 'package:tutormate/core/database/app_database.dart';
import 'package:tutormate/core/database/daos/books_dao.dart';
import 'package:tutormate/core/database/enums.dart';
import 'package:tutormate/features/dashboard/presentation/dashboard_screen.dart';
import 'package:tutormate/features/bookmarks/presentation/bookmarks_screen.dart';
import 'package:tutormate/features/library/data/library_providers.dart';
import 'package:tutormate/features/library/presentation/library_screen.dart';
import 'package:tutormate/features/notes/presentation/notes_screen.dart';
import 'package:tutormate/features/subjects/presentation/subjects_screen.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final now = DateTime(2026, 1, 1);

  Book book(int id, String title, BookCategory category, int subjectId) {
    return Book(
      id: id,
      title: title,
      category: category,
      grade: (id % 5) + 1,
      subjectId: subjectId,
      filePath: '/tmp/$title.pdf',
      totalPages: 120,
      createdAt: now,
      updatedAt: now,
      lastOpenedAt: now,
    );
  }

  final books = [
    book(1, 'Mathematics Grade 10 Student Textbook', BookCategory.studentBook, 1),
    book(2, 'Physics Teacher Guide Grade 11', BookCategory.teacherGuide, 2),
    book(3, 'Biology Short Notes', BookCategory.shortNote, 3),
  ];

  final subjects = [
    Subject(id: 1, name: 'Mathematics', createdAt: now),
    Subject(id: 2, name: 'Physics', createdAt: now),
    Subject(id: 3, name: 'Biology', createdAt: now),
  ];

  List<Override> baseOverrides() => [
        allBooksProvider.overrideWith((ref) => Stream.value(books)),
        filteredBooksProvider.overrideWith((ref) => Stream.value(books)),
        subjectMapProvider.overrideWith(
          (ref) => Stream.value({for (final s in subjects) s.id: s.name}),
        ),
        allSubjectsProvider.overrideWith((ref) => Stream.value(subjects)),
        allBookmarksProvider.overrideWith(
          (ref) => Stream.value(const <Bookmark>[]),
        ),
        allNotesProvider.overrideWith((ref) => Stream.value(const <Note>[])),
      ];

  Future<void> pumpScreen(
    WidgetTester tester,
    Size size,
    Widget screen, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [...baseOverrides(), ...overrides],
        child: MaterialApp(
          theme: AppTheme.light,
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpDashboard(WidgetTester tester, Size size) {
    return pumpScreen(
      tester,
      size,
      const DashboardScreen(),
      overrides: [
        libraryStatsProvider.overrideWith(
          (ref) => Stream.value(
            const LibraryStats(
              totalBooks: 24,
              studentBooks: 12,
              teacherGuides: 5,
              shortNotes: 4,
              otherBooks: 3,
            ),
          ),
        ),
        bookmarkCountProvider.overrideWith((ref) => Stream.value(18)),
        recentlyOpenedBooksProvider.overrideWith(
          (ref) => Stream.value(books),
        ),
        lastOpenedBookProvider.overrideWith(
          (ref) => Stream.value(books.first),
        ),
        progressByBookProvider.overrideWith(
          (ref, id) => Stream.value(
            ReadingProgressEntry(
              id: 1,
              bookId: id,
              currentPage: 42,
              progressPercentage: 0.35,
              lastReadAt: now,
            ),
          ),
        ),
      ],
    );
  }

  for (final size in const [Size(320, 640), Size(360, 800), Size(412, 915)]) {
    testWidgets('dashboard lays out at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      await pumpDashboard(tester, size);
      expect(tester.takeException(), isNull);
    });

    testWidgets('library lays out at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      await pumpScreen(tester, size, const LibraryScreen());
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in <String, Widget>{
    'bookmarks': const BookmarksScreen(),
    'subjects': const SubjectsScreen(),
    'notes': const NotesScreen(),
  }.entries) {
    testWidgets('${entry.key} lays out at 320x640', (tester) async {
      await pumpScreen(tester, const Size(320, 640), entry.value);
      expect(tester.takeException(), isNull);
    });
  }
}
