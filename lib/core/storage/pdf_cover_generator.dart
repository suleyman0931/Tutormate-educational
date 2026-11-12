import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

/// Generates a PNG cover image from the first page of a PDF file.
class PdfCoverGenerator {
  PdfCoverGenerator._();

  /// Renders page 1 of [pdfPath] at [width] pixels wide and returns PNG bytes.
  ///
  /// Returns null on any error.
  static Future<Uint8List?> generateCover(
    String pdfPath, {
    int width = 300,
  }) async {
    PdfDocument? document;
    PdfImage? pdfImage;
    try {
      document = await PdfDocument.openFile(pdfPath);
      if (document.pages.isEmpty) return null;

      final page = document.pages.first;
      final scale = width / page.width;
      final height = (page.height * scale).toInt();

      pdfImage = await page.render(
        fullWidth: width.toDouble(),
        fullHeight: height.toDouble(),
        backgroundColor: 0xFFFFFFFF,
      );
      if (pdfImage == null) return null;

      // pdfrx returns BGRA8888 — convert to RGBA
      final rgbaPixels = _bgraToRgba(pdfImage.pixels);

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        rgbaPixels,
        pdfImage.width,
        pdfImage.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final uiImage = await completer.future;

      final byteData =
          await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();

      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      pdfImage?.dispose();
      await document?.dispose();
    }
  }

  /// Converts BGRA8888 pixel data to RGBA8888.
  static Uint8List _bgraToRgba(Uint8List bgra) {
    final rgba = Uint8List(bgra.length);
    for (var i = 0; i < bgra.length; i += 4) {
      rgba[i] = bgra[i + 2];     // R ← B
      rgba[i + 1] = bgra[i + 1]; // G ← G
      rgba[i + 2] = bgra[i];     // B ← R
      rgba[i + 3] = bgra[i + 3]; // A ← A
    }
    return rgba;
  }
}
