import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutormate/core/utils/coordinate_utils.dart';

void main() {
  const pageRect = Rect.fromLTWH(0, 0, 400, 600);

  group('CoordinateUtils', () {
    test('toNormalized converts screen point to 0–1 range', () {
      const point = Offset(200, 300);
      final norm = CoordinateUtils.toNormalized(point, pageRect);
      expect(norm.dx, closeTo(0.5, 1e-9));
      expect(norm.dy, closeTo(0.5, 1e-9));
    });

    test('toScreen converts normalized point back to screen coords', () {
      const norm = Offset(0.5, 0.5);
      final screen = CoordinateUtils.toScreen(norm, pageRect);
      expect(screen.dx, closeTo(200.0, 1e-9));
      expect(screen.dy, closeTo(300.0, 1e-9));
    });

    test('round-trip: toNormalized → toScreen returns original point', () {
      const original = Offset(123, 456);
      final norm = CoordinateUtils.toNormalized(original, pageRect);
      final back = CoordinateUtils.toScreen(norm, pageRect);
      expect(back.dx, closeTo(original.dx, 1e-6));
      expect(back.dy, closeTo(original.dy, 1e-6));
    });

    test('rectToNormalized converts screen rect to 0–1 range', () {
      final rect = Rect.fromLTWH(100, 150, 200, 300);
      final norm = CoordinateUtils.rectToNormalized(rect, pageRect);
      expect(norm.left, closeTo(0.25, 1e-9));
      expect(norm.top, closeTo(0.25, 1e-9));
      expect(norm.right, closeTo(0.75, 1e-9));
      expect(norm.bottom, closeTo(0.75, 1e-9));
    });

    test('rectToScreen converts normalized rect back to screen coords', () {
      const norm = Rect.fromLTRB(0.0, 0.0, 1.0, 1.0);
      final screen = CoordinateUtils.rectToScreen(norm, pageRect);
      expect(screen.left, closeTo(0, 1e-9));
      expect(screen.top, closeTo(0, 1e-9));
      expect(screen.right, closeTo(400, 1e-9));
      expect(screen.bottom, closeTo(600, 1e-9));
    });

    test('rect round-trip returns original rect', () {
      final original = Rect.fromLTWH(50, 75, 100, 150);
      final norm = CoordinateUtils.rectToNormalized(original, pageRect);
      final back = CoordinateUtils.rectToScreen(norm, pageRect);
      expect(back.left, closeTo(original.left, 1e-6));
      expect(back.top, closeTo(original.top, 1e-6));
      expect(back.right, closeTo(original.right, 1e-6));
      expect(back.bottom, closeTo(original.bottom, 1e-6));
    });

    test('clampNorm clamps to 0–1', () {
      expect(CoordinateUtils.clampNorm(-0.5), 0.0);
      expect(CoordinateUtils.clampNorm(1.5), 1.0);
      expect(CoordinateUtils.clampNorm(0.5), 0.5);
    });

    test('toNormalized handles empty pageRect gracefully', () {
      final norm = CoordinateUtils.toNormalized(
          const Offset(10, 20), Rect.zero);
      expect(norm, Offset.zero);
    });

    test('pointsToNormalized converts list of screen points', () {
      final points = [const Offset(0, 0), const Offset(400, 600)];
      final norms = CoordinateUtils.pointsToNormalized(points, pageRect);
      expect(norms[0], const Offset(0.0, 0.0));
      expect(norms[1], const Offset(1.0, 1.0));
    });
  });
}
