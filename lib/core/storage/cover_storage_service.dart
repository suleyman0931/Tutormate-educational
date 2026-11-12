import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/constants/app_constants.dart';

/// Manages cover image storage inside the app documents directory.
///
/// Cover images are stored at `<docs>/covers/<book_id>.jpg`.
/// The actual rendering of the first PDF page to image bytes is performed
/// by the PDF viewer package (selected in Phase 3) and passed to [saveCover].
class CoverStorageService {
  CoverStorageService();

  /// Returns the directory where cover images are stored, creating it if needed.
  Future<Directory> _coversDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, AppConstants.coversDir));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Saves cover image bytes (JPEG/PNG) to app-managed storage.
  /// Returns the absolute path of the saved cover.
  Future<String> saveCover(Uint8List bytes, int bookId) async {
    final dir = await _coversDir();
    final destPath = p.join(dir.path, '$bookId.jpg');
    final destFile = File(destPath);
    await destFile.writeAsBytes(bytes);
    return destPath;
  }

  /// Returns the expected cover path for a book (does not check existence).
  Future<String> coverPathFor(int bookId) async {
    final dir = await _coversDir();
    return p.join(dir.path, '$bookId.jpg');
  }

  /// Checks whether a cover image exists at [coverPath].
  Future<bool> coverExists(String? coverPath) async {
    if (coverPath == null || coverPath.isEmpty) return false;
    return File(coverPath).exists();
  }

  /// Deletes a cover image from disk if it exists.
  Future<void> deleteCover(String? coverPath) async {
    if (coverPath == null || coverPath.isEmpty) return;
    final file = File(coverPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Riverpod provider for [CoverStorageService].
final coverStorageServiceProvider = Provider<CoverStorageService>((ref) {
  return CoverStorageService();
});
