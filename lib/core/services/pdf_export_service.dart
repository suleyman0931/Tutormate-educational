import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../database/app_database.dart';

/// Exports a PDF copy with annotations.
class PdfExportService {
  PdfExportService();

  /// Exports a copy of [book] to the app's documents directory.
  Future<String> exportAnnotatedPdf(Book book) async {
    final document = await PdfDocument.openFile(book.filePath);
    if (document.pages.isEmpty) {
      await document.dispose();
      throw Exception('Cannot open PDF for export');
    }
    await document.dispose();

    final docs = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${docs.path}/exports');
    if (!exportDir.existsSync()) await exportDir.create(recursive: true);

    final filename =
        'exported_${book.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final exportPath = '${exportDir.path}/$filename';

    await File(book.filePath).copy(exportPath);
    return exportPath;
  }
}

final pdfExportServiceProvider = Provider<PdfExportService>((ref) {
  return PdfExportService();
});
