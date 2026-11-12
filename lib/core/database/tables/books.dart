import 'package:drift/drift.dart';
import '../enums.dart';
import 'subjects.dart';

/// Books table – core entity for the PDF library.
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 300)();
  TextColumn get category =>
      text().map(const BookCategoryConverter())();
  IntColumn get grade => integer()(); // 1–5
  IntColumn get subjectId =>
      integer().references(Subjects, #id)();
  TextColumn get description => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get publisher => text().nullable()();
  TextColumn get academicYear => text().nullable()();
  TextColumn get filePath => text()();
  TextColumn get coverPath => text().nullable()();
  IntColumn get totalPages => integer().withDefault(const Constant(0))();
  TextColumn get fileHash => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
}
