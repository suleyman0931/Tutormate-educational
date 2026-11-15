import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/constants/app_constants.dart';

/// Manages document file storage inside the app documents directory.
///
/// Imported files are copied from file-picker cache paths into
/// `<docs>/pdfs/<book_id><original_extension>` so they persist independently
/// of the picker and keep their real format (PDF, DOCX, DOC, TXT).
class PdfStorageService {
  PdfStorageService();

  /// Returns the directory where documents are stored, creating it if needed.
  Future<Directory> _pdfsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, AppConstants.pdfsDir));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies a source document into app-managed storage, preserving its
  /// original extension (`.pdf`, `.docx`, `.doc`, `.txt`).
  Future<String> importDocument(String sourcePath, int bookId) async {
    final extension = p.extension(sourcePath).toLowerCase();
    final destPath = await _destinationPath(bookId, extension);
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Writes document bytes into app-managed storage, preserving the original
  /// extension taken from [fileName] or [extension].
  Future<String> importDocumentBytes(
    List<int> bytes,
    int bookId, {
    String? fileName,
    String? extension,
  }) async {
    var ext = extension ?? (fileName != null ? p.extension(fileName) : '');
    if (ext.isNotEmpty && !ext.startsWith('.')) ext = '.$ext';
    final destPath = await _destinationPath(bookId, ext.toLowerCase());
    await File(destPath).writeAsBytes(bytes, flush: true);
    return destPath;
  }

  Future<String> _destinationPath(int bookId, String extension) async {
    final dir = await _pdfsDir();
    await _deleteStaleFilesFor(bookId, keepExtension: extension);
    return p.join(dir.path, '$bookId$extension');
  }

  /// Removes any previously stored file for [bookId] that has a different
  /// extension, preventing leftovers when a book is replaced.
  Future<void> _deleteStaleFilesFor(
    int bookId, {
    required String keepExtension,
  }) async {
    final dir = await _pdfsDir();
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (p.basenameWithoutExtension(name) != '$bookId') continue;
      if (p.extension(name).toLowerCase() == keepExtension.toLowerCase()) {
        continue;
      }
      try {
        await entity.delete();
      } catch (_) {
        // Ignore stale-file cleanup errors.
      }
    }
  }

  /// Copies a source PDF file into app-managed storage.
  Future<String> importPdf(String sourcePath, int bookId) =>
      importDocument(sourcePath, bookId);

  /// Copies PDF bytes into app-managed storage.
  Future<String> importPdfBytes(List<int> bytes, int bookId) =>
      importDocumentBytes(bytes, bookId, extension: '.pdf');

  /// Returns the expected storage path for a book's PDF (does not check existence).
  Future<String> pdfPathFor(int bookId) async {
    final dir = await _pdfsDir();
    return p.join(dir.path, '$bookId.pdf');
  }

  /// Checks whether the file at [filePath] still exists on disk.
  Future<bool> fileExists(String filePath) async {
    return File(filePath).exists();
  }

  /// Deletes a document file from disk if it exists.
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
