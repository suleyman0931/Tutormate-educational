import 'package:drift/drift.dart';
import 'books.dart';

/// Bookmarks for specific PDF pages.
///
/// Enforced unique on (bookId, pageNumber) to prevent accidental
/// duplicate bookmarks on the same page.
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageNumber => integer()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {bookId, pageNumber},
  ];
}
