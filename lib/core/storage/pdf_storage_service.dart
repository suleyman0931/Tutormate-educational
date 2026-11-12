import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/constants/app_constants.dart';

/// Manages PDF file storage inside the app documents directory.
///
/// Imported PDFs are copied from file-picker cache paths into
/// `<docs>/pdfs/<book_id>.pdf` so they persist independently of the picker.
class PdfStorageService {
  PdfStorageService();

  /// Returns the directory where PDF files are stored, creating it if needed.
  Future<Directory> _pdfsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, AppConstants.pdfsDir));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies a source PDF file into app-managed storage.
  ///
  /// [sourcePath] is the temporary file-picker path. [bookId] is used to
  /// name the destination file. Returns the absolute path of the stored copy.
  Future<String> importPdf(String sourcePath, int bookId) async {
    final dir = await _pdfsDir();
    final destPath = p.join(dir.path, '$bookId.pdf');
    final sourceFile = File(sourcePath);
    await sourceFile.copy(destPath);
    return destPath;
  }

  /// Copies PDF bytes (when only bytes are available, e.g. from picker) into
  /// app-managed storage. Returns the absolute path.
  Future<String> importPdfBytes(List<int> bytes, int bookId) async {
    final dir = await _pdfsDir();
    final destPath = p.join(dir.path, '$bookId.pdf');
    final destFile = File(destPath);
    await destFile.writeAsBytes(bytes);
    return destPath;
  }

  /// Returns the expected storage path for a book's PDF (does not check existence).
  Future<String> pdfPathFor(int bookId) async {
    final dir = await _pdfsDir();
    return p.join(dir.path, '$bookId.pdf');
  }

  /// Checks whether the PDF file at [filePath] still exists on disk.
  Future<bool> fileExists(String filePath) async {
    return File(filePath).exists();
  }

  /// Deletes a PDF file from disk if it exists.
  Future<void> deletePdf(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Riverpod provider for [PdfStorageService].
final pdfStorageServiceProvider = Provider<PdfStorageService>((ref) {
  return PdfStorageService();
});
