import 'dart:convert';
import 'dart:ui';

import '../../../core/database/enums.dart';

// ── Base ─────────────────────────────────────────────────────────────────────

/// In-memory representation of a single annotation.
/// Coordinates are always stored/transferred in **normalized** form (0.0–1.0).
abstract class AnnotationData {
  const AnnotationData({
    required this.type,
    required this.color,
  });

  final AnnotationType type;
  final Color color;

  /// Serialise to JSON for storage in the database.
  Map<String, dynamic> toJson();

  /// Round-trips to a JSON string.
  String toJsonString() => jsonEncode(toJson());

  /// Factory: deserialise from a stored JSON string.
  static AnnotationData fromJsonString(
      String jsonStr, AnnotationType type, Color color) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    switch (type) {
      case AnnotationType.highlight:
      case AnnotationType.underline:
      case AnnotationType.strikethrough:
        return RectAnnotationData.fromJson(map, type, color);
      case AnnotationType.text:
        return TextAnnotationData.fromJson(map, color);
      case AnnotationType.drawing:
        return DrawingAnnotationData.fromJson(map, color);
    }
  }
}

// ── Rect-based (highlight / underline / strikethrough) ───────────────────────

/// Annotation defined by a normalised rectangle over the page.
/// Used for highlight, underline, and strikethrough.
class RectAnnotationData extends AnnotationData {
  const RectAnnotationData({
    required super.type,
    required super.color,
    required this.rect,
    this.selectedText,
  });

  /// Normalised rectangle (all values 0.0–1.0).
  final Rect rect;

  /// The text covered by this annotation, if captured.
  final String? selectedText;

  factory RectAnnotationData.fromJson(
    Map<String, dynamic> map,
    AnnotationType type,
    Color color,
  ) {
    return RectAnnotationData(
      type: type,
      color: color,
      rect: Rect.fromLTRB(
        (map['l'] as num).toDouble(),
        (map['t'] as num).toDouble(),
        (map['r'] as num).toDouble(),
        (map['b'] as num).toDouble(),
      ),
      selectedText: map['text'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'l': rect.left,
        't': rect.top,
        'r': rect.right,
        'b': rect.bottom,
        if (selectedText != null) 'text': selectedText,
      };
}

// ── Text annotation ──────────────────────────────────────────────────────────

/// Annotation that places a text label at a normalised point on the page.
class TextAnnotationData extends AnnotationData {
  const TextAnnotationData({
    required super.color,
    required this.position,
    required this.text,
    this.fontSize = 14.0,
  }) : super(type: AnnotationType.text);

  /// Normalised position (top-left anchor) of the text box.
  final Offset position;
  final String text;
  final double fontSize;

  factory TextAnnotationData.fromJson(Map<String, dynamic> map, Color color) {
    return TextAnnotationData(
      color: color,
      position: Offset(
        (map['x'] as num).toDouble(),
        (map['y'] as num).toDouble(),
      ),
      text: map['text'] as String,
      fontSize: (map['fs'] as num?)?.toDouble() ?? 14.0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'x': position.dx,
        'y': position.dy,
        'text': text,
        'fs': fontSize,
      };
}

// ── Drawing / freehand ───────────────────────────────────────────────────────

/// A freehand stroke consisting of a list of normalised points.
class DrawingAnnotationData extends AnnotationData {
  const DrawingAnnotationData({
    required super.color,
    required this.points,
    this.strokeWidth = 3.0,
  }) : super(type: AnnotationType.drawing);

  /// Normalised points of the stroke.
  final List<Offset> points;
  final double strokeWidth;

  factory DrawingAnnotationData.fromJson(
      Map<String, dynamic> map, Color color) {
    final rawPoints = map['pts'] as List<dynamic>;
    final points = <Offset>[];
    for (int i = 0; i < rawPoints.length - 1; i += 2) {
      points.add(Offset(
        (rawPoints[i] as num).toDouble(),
        (rawPoints[i + 1] as num).toDouble(),
      ));
    }
    return DrawingAnnotationData(
      color: color,
      points: points,
      strokeWidth: (map['sw'] as num?)?.toDouble() ?? 3.0,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final flatPoints = <double>[];
    for (final p in points) {
      flatPoints.add(p.dx);
      flatPoints.add(p.dy);
    }
    return {
      'pts': flatPoints,
      'sw': strokeWidth,
    };
  }
}
