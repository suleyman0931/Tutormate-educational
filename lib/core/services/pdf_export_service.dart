import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../database/app_database.dart';
import '../utils/document_converter.dart';

/// Exports a PDF copy with annotations.
class PdfExportService {
  PdfExportService();

  /// Exports a copy of [book] to the app's documents directory.
  Future<String> exportAnnotatedPdf(Book book) async {
    // Word/text documents are exported as their converted PDF version.
    final pdfPath = DocumentConverter.needsConversion(book.filePath)
        ? await DocumentConverter.convertToPdf(book.filePath)
        : book.filePath;

    final document = await PdfDocument.openFile(pdfPath);
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

    await File(pdfPath).copy(exportPath);
    return exportPath;
  }
}

final pdfExportServiceProvider = Provider<PdfExportService>((ref) {
  return PdfExportService();
});
