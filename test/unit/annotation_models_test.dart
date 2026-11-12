import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutormate/core/database/enums.dart';
import 'package:tutormate/features/annotations/data/annotation_models.dart';

void main() {
  group('AnnotationData JSON round-trips', () {
    test('RectAnnotationData serialises and deserialises correctly', () {
      const original = RectAnnotationData(
        type: AnnotationType.highlight,
        color: Color(0xFFFFEB3B),
        rect: Rect.fromLTRB(0.1, 0.2, 0.8, 0.9),
        selectedText: 'hello world',
      );

      final json = original.toJsonString();
      final restored = AnnotationData.fromJsonString(
          json, AnnotationType.highlight, const Color(0xFFFFEB3B));

      expect(restored, isA<RectAnnotationData>());
      final r = restored as RectAnnotationData;
      expect(r.rect.left, closeTo(0.1, 1e-6));
      expect(r.rect.top, closeTo(0.2, 1e-6));
      expect(r.rect.right, closeTo(0.8, 1e-6));
      expect(r.rect.bottom, closeTo(0.9, 1e-6));
      expect(r.selectedText, 'hello world');
    });

    test('TextAnnotationData serialises and deserialises correctly', () {
      const original = TextAnnotationData(
        color: Color(0xFFE53935),
        position: Offset(0.3, 0.4),
        text: 'important note',
        fontSize: 16.0,
      );

      final json = original.toJsonString();
      final restored = AnnotationData.fromJsonString(
          json, AnnotationType.text, const Color(0xFFE53935));

      expect(restored, isA<TextAnnotationData>());
      final t = restored as TextAnnotationData;
      expect(t.position.dx, closeTo(0.3, 1e-6));
      expect(t.position.dy, closeTo(0.4, 1e-6));
      expect(t.text, 'important note');
      expect(t.fontSize, 16.0);
    });

    test('DrawingAnnotationData serialises and deserialises correctly', () {
      const original = DrawingAnnotationData(
        color: Color(0xFF1A237E),
        points: [Offset(0.1, 0.2), Offset(0.5, 0.6), Offset(0.9, 0.8)],
        strokeWidth: 4.0,
      );

      final json = original.toJsonString();
      final restored = AnnotationData.fromJsonString(
          json, AnnotationType.drawing, const Color(0xFF1A237E));

      expect(restored, isA<DrawingAnnotationData>());
      final d = restored as DrawingAnnotationData;
      expect(d.points.length, 3);
      expect(d.points[0].dx, closeTo(0.1, 1e-6));
      expect(d.points[2].dy, closeTo(0.8, 1e-6));
      expect(d.strokeWidth, 4.0);
    });

    test('RectAnnotationData works for underline type', () {
      const data = RectAnnotationData(
        type: AnnotationType.underline,
        color: Color(0xFF00897B),
        rect: Rect.fromLTRB(0.0, 0.5, 1.0, 0.6),
      );
      final json = data.toJsonString();
      final restored = AnnotationData.fromJsonString(
          json, AnnotationType.underline, const Color(0xFF00897B));
      expect(restored.type, AnnotationType.underline);
    });
  });

  group('BookCategory', () {
    test('all categories have non-empty labels', () {
      for (final cat in BookCategory.values) {
        expect(cat.label, isNotEmpty);
        expect(cat.shortLabel, isNotEmpty);
      }
    });

    test('fromName round-trips correctly', () {
      for (final cat in BookCategory.values) {
        expect(BookCategory.fromName(cat.name), cat);
      }
    });

    test('fromName unknown string returns other', () {
      expect(BookCategory.fromName('nonexistent'), BookCategory.other);
    });
  });

  group('AnnotationType', () {
    test('all types have non-empty labels', () {
      for (final t in AnnotationType.values) {
        expect(t.label, isNotEmpty);
      }
    });

    test('fromName round-trips correctly', () {
      for (final t in AnnotationType.values) {
        expect(AnnotationType.fromName(t.name), t);
      }
    });
  });
}
