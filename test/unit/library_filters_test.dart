import 'package:flutter_test/flutter_test.dart';
import 'package:tutormate/core/database/enums.dart';
import 'package:tutormate/features/library/data/library_filters.dart';

// Minimal Book-like stub for testing the filter engine
// We use the real LibraryFilterEngine which expects Book objects from Drift.
// Since we can't instantiate Book directly in tests without a DB, we test
// LibraryFilters (the state class) independently.

void main() {
  group('LibraryFilters', () {
    test('defaults have no active filters', () {
      const filters = LibraryFilters();
      expect(filters.hasActiveFilters, isFalse);
      expect(filters.searchQuery, isEmpty);
      expect(filters.selectedGrade, isNull);
      expect(filters.selectedCategory, isNull);
      expect(filters.selectedSubjectId, isNull);
      expect(filters.sortBy, SortBy.recentlyAdded);
    });

    test('copyWith sets searchQuery', () {
      const filters = LibraryFilters();
      final updated = filters.copyWith(searchQuery: 'math');
      expect(updated.searchQuery, 'math');
      expect(updated.hasActiveFilters, isTrue);
    });

    test('copyWith sets grade', () {
      const filters = LibraryFilters();
      final updated = filters.copyWith(selectedGrade: 3);
      expect(updated.selectedGrade, 3);
      expect(updated.hasActiveFilters, isTrue);
    });

    test('copyWith clearGrade removes grade', () {
      const filters = LibraryFilters(selectedGrade: 2);
      final cleared = filters.copyWith(clearGrade: true);
      expect(cleared.selectedGrade, isNull);
    });

    test('copyWith sets category', () {
      const filters = LibraryFilters();
      final updated =
          filters.copyWith(selectedCategory: BookCategory.studentBook);
      expect(updated.selectedCategory, BookCategory.studentBook);
      expect(updated.hasActiveFilters, isTrue);
    });

    test('copyWith clearCategory removes category', () {
      const filters =
          LibraryFilters(selectedCategory: BookCategory.teacherGuide);
      final cleared = filters.copyWith(clearCategory: true);
      expect(cleared.selectedCategory, isNull);
    });

    test('copyWith sets subjectId', () {
      const filters = LibraryFilters();
      final updated = filters.copyWith(selectedSubjectId: 5);
      expect(updated.selectedSubjectId, 5);
      expect(updated.hasActiveFilters, isTrue);
    });

    test('copyWith clearSubject removes subjectId', () {
      const filters = LibraryFilters(selectedSubjectId: 3);
      final cleared = filters.copyWith(clearSubject: true);
      expect(cleared.selectedSubjectId, isNull);
    });

    test('copyWith sets sortBy', () {
      const filters = LibraryFilters();
      final updated = filters.copyWith(sortBy: SortBy.alphabeticalAZ);
      expect(updated.sortBy, SortBy.alphabeticalAZ);
      // sortBy alone does not activate hasActiveFilters
      expect(updated.hasActiveFilters, isFalse);
    });

    test('all SortBy values have non-empty labels', () {
      for (final s in SortBy.values) {
        expect(s.label, isNotEmpty);
      }
    });
  });
}
