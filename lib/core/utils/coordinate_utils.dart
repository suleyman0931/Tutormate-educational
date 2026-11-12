import 'package:flutter/material.dart';

/// Utility methods for converting between screen (widget) coordinates and
/// normalized PDF page coordinates (0.0–1.0 of the page's native size).
///
/// Normalized coordinates are stored in the database so that annotations
/// remain correct across different zoom levels, screen sizes, and orientations.
class CoordinateUtils {
  CoordinateUtils._();

  /// Converts a screen-space [point] to normalized page coordinates.
  ///
  /// [pageRect] is the page's bounding rect in screen-space (widget coords).
  static Offset toNormalized(Offset point, Rect pageRect) {
    if (pageRect.isEmpty) return Offset.zero;
    return Offset(
      (point.dx - pageRect.left) / pageRect.width,
      (point.dy - pageRect.top) / pageRect.height,
    );
  }

  /// Converts a normalized [point] back to screen-space coordinates.
  ///
  /// [pageRect] is the page's bounding rect in screen-space (widget coords).
  static Offset toScreen(Offset normalizedPoint, Rect pageRect) {
    return Offset(
      pageRect.left + normalizedPoint.dx * pageRect.width,
      pageRect.top + normalizedPoint.dy * pageRect.height,
    );
  }

  /// Converts a screen-space [rect] to normalized page coordinates.
  static Rect rectToNormalized(Rect rect, Rect pageRect) {
    if (pageRect.isEmpty) return Rect.zero;
    return Rect.fromLTRB(
      (rect.left - pageRect.left) / pageRect.width,
      (rect.top - pageRect.top) / pageRect.height,
      (rect.right - pageRect.left) / pageRect.width,
      (rect.bottom - pageRect.top) / pageRect.height,
    );
  }

  /// Converts a normalized [rect] back to screen-space coordinates.
  static Rect rectToScreen(Rect normalizedRect, Rect pageRect) {
    return Rect.fromLTRB(
      pageRect.left + normalizedRect.left * pageRect.width,
      pageRect.top + normalizedRect.top * pageRect.height,
      pageRect.left + normalizedRect.right * pageRect.width,
      pageRect.top + normalizedRect.bottom * pageRect.height,
    );
  }

  /// Converts a list of screen-space points to normalized coordinates.
  static List<Offset> pointsToNormalized(List<Offset> points, Rect pageRect) {
    return points.map((p) => toNormalized(p, pageRect)).toList();
  }

  /// Converts a list of normalized points back to screen-space coordinates.
  static List<Offset> pointsToScreen(
      List<Offset> normalizedPoints, Rect pageRect) {
    return normalizedPoints.map((p) => toScreen(p, pageRect)).toList();
  }

  /// Clamps a normalized value to [0.0, 1.0].
  static double clampNorm(double v) => v.clamp(0.0, 1.0);

  /// Clamps a normalized point to the [0.0, 1.0] × [0.0, 1.0] unit square.
  static Offset clampNormPoint(Offset p) =>
      Offset(clampNorm(p.dx), clampNorm(p.dy));
}
