import 'package:drift/drift.dart';
import 'books.dart';

/// Tracks the user's reading progress per book (one row per book).
@DataClassName('ReadingProgressEntry')
class ReadingProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId =>
      integer().unique().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get currentPage => integer().withDefault(const Constant(1))();
  RealColumn get progressPercentage =>
      real().withDefault(const Constant(0.0))();
  DateTimeColumn get lastReadAt =>
      dateTime().withDefault(currentDateAndTime)();
}
