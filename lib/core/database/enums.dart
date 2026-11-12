import 'package:drift/drift.dart';

/// Book categories used to organize the library.
enum BookCategory {
  studentBook,
  teacherGuide,
  shortNote,
  other;

  /// Human-readable label for display.
  String get label {
    switch (this) {
      case BookCategory.studentBook:
        return 'Student Books';
      case BookCategory.teacherGuide:
        return 'Teacher Guides';
      case BookCategory.shortNote:
        return 'Short Notes';
      case BookCategory.other:
        return 'Other Books';
    }
  }

  /// Short label for compact display.
  String get shortLabel {
    switch (this) {
      case BookCategory.studentBook:
        return 'Student';
      case BookCategory.teacherGuide:
        return 'Teacher';
      case BookCategory.shortNote:
        return 'Short Note';
      case BookCategory.other:
        return 'Other';
    }
  }

  /// Parses a [BookCategory] from its storage string name.
  static BookCategory fromName(String name) {
    return BookCategory.values.firstWhere(
      (e) => e.name == name,
      orElse: () => BookCategory.other,
    );
  }
}

/// Types of annotations a user can create on a PDF page.
enum AnnotationType {
  highlight,
  underline,
  strikethrough,
  text,
  drawing;

  /// Human-readable label.
  String get label {
    switch (this) {
      case AnnotationType.highlight:
        return 'Highlight';
      case AnnotationType.underline:
        return 'Underline';
      case AnnotationType.strikethrough:
        return 'Strikethrough';
      case AnnotationType.text:
        return 'Text';
      case AnnotationType.drawing:
        return 'Drawing';
    }
  }

  /// Parses an [AnnotationType] from its storage string name.
  static AnnotationType fromName(String name) {
    return AnnotationType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => AnnotationType.highlight,
    );
  }
}

/// Drift converter that maps [BookCategory] ↔ TEXT column.
class BookCategoryConverter extends TypeConverter<BookCategory, String> {
  const BookCategoryConverter();

  @override
  BookCategory fromSql(String fromDb) => BookCategory.fromName(fromDb);

  @override
  String toSql(BookCategory value) => value.name;
}

/// Drift converter that maps [AnnotationType] ↔ TEXT column.
class AnnotationTypeConverter extends TypeConverter<AnnotationType, String> {
  const AnnotationTypeConverter();

  @override
  AnnotationType fromSql(String fromDb) => AnnotationType.fromName(fromDb);

  @override
  String toSql(AnnotationType value) => value.name;
}
