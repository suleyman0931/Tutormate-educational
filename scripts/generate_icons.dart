/// Run with: dart run scripts/generate_icons.dart
///
/// Generates TutorMate launcher icons for all Android mipmap densities
/// by rendering the icon programmatically and saving as PNG.
///
/// Requires the `image` package (already in pubspec.yaml via pdfrx → image).

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() async {
  // Android mipmap densities: folder → pixel size
  const densities = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  const baseDir = 'android/app/src/main/res';

  for (final entry in densities.entries) {
    final size = entry.value;
    final icon = _generateIcon(size);
    final outPath = '$baseDir/${entry.key}/ic_launcher.png';
    final file = File(outPath);
    await file.writeAsBytes(img.encodePng(icon));
    print('✓ Generated $outPath ($size×$size)');
  }

  // Also generate a 1024×1024 version for Play Store
  final large = _generateIcon(1024);
  final largeFile = File('scripts/ic_launcher_1024.png');
  await largeFile.writeAsBytes(img.encodePng(large));
  print('✓ Generated scripts/ic_launcher_1024.png (1024×1024)');

  print('\nAll icons generated successfully!');
}

img.Image _generateIcon(int size) {
  final image = img.Image(width: size, height: size);

  final double s = size.toDouble();
  final double radius = s * 0.215; // rounded corner radius

  // ── Background gradient (Deep Navy → slightly lighter navy) ──────────────
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      // Rounded rect mask
      if (!_inRoundedRect(x, y, size, radius)) continue;

      // Linear gradient top-left → bottom-right
      final t = (x + y) / (s * 2);
      final r = _lerp(0x1A, 0x28, t).round();
      final g = _lerp(0x23, 0x35, t).round();
      final b = _lerp(0x7E, 0x93, t).round();
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  // ── Open book ──────────────────────────────────────────────────────────────
  final cx = s / 2;
  final cy = s * 0.47;
  final bookW = s * 0.68; // total book width
  final bookH = s * 0.42; // book height
  final top = cy - bookH / 2;
  final bot = cy + bookH / 2;
  final left = cx - bookW / 2;
  final right = cx + bookW / 2;
  final spine = cx;

  // Left page (white, slightly tilted trapezoid)
  _fillPoly(image, [
    _P(spine, top - s * 0.015),
    _P(left + s * 0.02, top + s * 0.03),
    _P(left, bot - s * 0.03),
    _P(spine, bot + s * 0.015),
  ], 0xFF, 0xFF, 0xFF, 248);

  // Right page (slightly off-white)
  _fillPoly(image, [
    _P(spine, top - s * 0.015),
    _P(right - s * 0.02, top + s * 0.03),
    _P(right, bot - s * 0.03),
    _P(spine, bot + s * 0.015),
  ], 0xF0, 0xF2, 0xFF, 240);

  // Spine shadow line
  _drawLine(image, spine.round(), (top - s * 0.02).round(),
      spine.round(), (bot + s * 0.02).round(), 0xC5, 0xCA, 0xE9, 160, 2);

  // ── Text lines on left page ────────────────────────────────────────────────
  final lineColor = img.ColorRgba8(0x9F, 0xA8, 0xDA, 140);
  final lineSpacing = bookH / 7;
  for (int i = 1; i <= 5; i++) {
    final ly = top + s * 0.06 + lineSpacing * i;
    final lx1 = left + s * 0.045 + (i * s * 0.005);
    final lx2 = spine - s * 0.03;
    final thickness = i == 1 ? 3 : 2;
    for (int t = 0; t < thickness; t++) {
      img.drawLine(image,
          x1: lx1.round(), y1: (ly + t).round(),
          x2: lx2.round(), y2: (ly + t).round(),
          color: lineColor);
    }
  }

  // ── Text lines on right page ───────────────────────────────────────────────
  for (int i = 1; i <= 5; i++) {
    final ly = top + s * 0.06 + lineSpacing * i;
    final lx1 = spine + s * 0.03;
    final lx2 = right - s * 0.045 - (i * s * 0.004);
    final thickness = i == 1 ? 3 : 2;
    for (int t = 0; t < thickness; t++) {
      img.drawLine(image,
          x1: lx1.round(), y1: (ly + t).round(),
          x2: lx2.round(), y2: (ly + t).round(),
          color: lineColor);
    }
  }

  // ── Orange accent circle (checkmark) ──────────────────────────────────────
  final acX = (cx + bookW * 0.26).round();
  final acY = (cy + bookH * 0.30).round();
  final acR = (s * 0.085).round();
  img.fillCircle(image, x: acX, y: acY, radius: acR,
      color: img.ColorRgba8(0xFF, 0x8A, 0x65, 242));

  // Checkmark inside circle
  final ck = s * 0.04;
  _drawLine(image,
      (acX - ck * 0.5).round(), acY.round(),
      (acX - ck * 0.1).round(), (acY + ck * 0.6).round(),
      0xFF, 0xFF, 0xFF, 255, (s * 0.025).round());
  _drawLine(image,
      (acX - ck * 0.1).round(), (acY + ck * 0.6).round(),
      (acX + ck * 0.7).round(), (acY - ck * 0.5).round(),
      0xFF, 0xFF, 0xFF, 255, (s * 0.025).round());

  // ── Teal bookmark ribbon top-right ────────────────────────────────────────
  final bmX = right - s * 0.05;
  final bmW = s * 0.075;
  final bmTop = top - s * 0.08;
  final bmH = s * 0.14;
  _fillPoly(image, [
    _P(bmX - bmW, bmTop),
    _P(bmX, bmTop),
    _P(bmX, bmTop + bmH),
    _P(bmX - bmW / 2, bmTop + bmH * 0.78),
    _P(bmX - bmW, bmTop + bmH),
  ], 0x00, 0x89, 0x7B, 220);

  return image;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _P {
  final double x, y;
  const _P(this.x, this.y);
}

bool _inRoundedRect(int px, int py, int size, double r) {
  final x = px.toDouble();
  final y = py.toDouble();
  final s = size.toDouble();
  // Check if point is inside the rounded rectangle
  final cx = x < r ? r : (x > s - r ? s - r : x);
  final cy = y < r ? r : (y > s - r ? s - r : y);
  final dx = x - cx;
  final dy = y - cy;
  return dx * dx + dy * dy <= r * r;
}

double _lerp(num a, num b, double t) => a + (b - a) * t;

void _fillPoly(img.Image image, List<_P> poly,
    int r, int g, int b, int a) {
  final minY = poly.map((p) => p.y).reduce(math.min).floor();
  final maxY = poly.map((p) => p.y).reduce(math.max).ceil();

  for (int y = minY; y <= maxY; y++) {
    final intersections = <double>[];
    for (int i = 0; i < poly.length; i++) {
      final p1 = poly[i];
      final p2 = poly[(i + 1) % poly.length];
      if ((p1.y <= y && p2.y > y) || (p2.y <= y && p1.y > y)) {
        final t = (y - p1.y) / (p2.y - p1.y);
        intersections.add(p1.x + t * (p2.x - p1.x));
      }
    }
    intersections.sort();
    for (int i = 0; i + 1 < intersections.length; i += 2) {
      final x1 = intersections[i].round();
      final x2 = intersections[i + 1].round();
      for (int x = x1; x <= x2; x++) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          image.setPixelRgba(x, y, r, g, b, a);
        }
      }
    }
  }
}

void _drawLine(img.Image image, int x1, int y1, int x2, int y2,
    int r, int g, int b, int a, [int thickness = 1]) {
  final color = img.ColorRgba8(r, g, b, a);
  for (int t = 0; t < thickness; t++) {
    img.drawLine(image,
        x1: x1, y1: y1 + t, x2: x2, y2: y2 + t, color: color);
    img.drawLine(image,
        x1: x1 + t, y1: y1, x2: x2 + t, y2: y2, color: color);
  }
}
