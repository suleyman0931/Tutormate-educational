import 'package:drift/drift.dart';
import '../enums.dart';
import 'books.dart';

/// PDF annotations – highlight, underline, strikethrough, text, drawing.
///
/// Positions are stored in normalized coordinates (0.0–1.0 of the PDF
/// page's native size) inside [annotationData] as JSON. This guarantees
/// correct placement across zoom, scroll, orientation, and reopen.
class Annotations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageNumber => integer()();
  TextColumn get annotationType =>
      text().map(const AnnotationTypeConverter())();
  TextColumn get annotationData => text()(); // JSON payload
  IntColumn get color => integer().withDefault(const Constant(0xFFFFEB3B))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
