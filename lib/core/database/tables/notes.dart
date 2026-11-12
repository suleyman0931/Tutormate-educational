import 'package:drift/drift.dart';
import 'books.dart';
import 'subjects.dart';

/// Personal notes – optionally linked to a book and page.
///
/// When a referenced book is deleted, [bookId] is set to NULL so the
/// note content is preserved as an independent note.
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId =>
      integer().nullable().references(Books, #id, onDelete: KeyAction.setNull)();
  IntColumn get pageNumber => integer().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get content => text()();
  IntColumn get subjectId =>
      integer().nullable().references(Subjects, #id, onDelete: KeyAction.setNull)();
  IntColumn get grade => integer().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
