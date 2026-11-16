import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutormate/core/database/app_database.dart';
import 'package:tutormate/core/database/daos/progress_dao.dart';
import 'package:tutormate/core/database/enums.dart';

void main() {
  late AppDatabase db;
  late ProgressDao dao;
  late int bookId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ProgressDao(db);
    final subjectId = await db
        .into(db.subjects)
        .insert(SubjectsCompanion.insert(name: 'Test Subject'));
    bookId = await db.into(db.books).insert(
          BooksCompanion.insert(
            title: 'Test Book',
            category: BookCategory.studentBook,
            grade: 5,
            subjectId: subjectId,
            filePath: '/tmp/test.pdf',
          ),
        );
  });

  tearDown(() => db.close());

  test('saveProgress inserts then updates the same row', () async {
    await dao.saveProgress(
      bookId: bookId,
      currentPage: 5,
      progressPercentage: 5 / 201,
    );
    await dao.saveProgress(
      bookId: bookId,
      currentPage: 42,
      progressPercentage: 42 / 201,
    );

    final progress = await dao.getProgress(bookId);

    expect(progress, isNotNull);
    expect(progress!.currentPage, 42);
    expect(progress.progressPercentage, closeTo(42 / 201, 0.0001));
    expect(await db.select(db.readingProgress).get(), hasLength(1));
  });
}
