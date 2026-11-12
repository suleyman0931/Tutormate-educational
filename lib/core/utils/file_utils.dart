import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// File-related utilities: hashing, size checks, safe naming.
class FileUtils {
  FileUtils._();

  /// Computes a SHA-256 hash of the file.
  ///
  /// For files smaller than [maxFullHashSize] bytes, the entire content is
  /// hashed. For larger files, the first and last 2 MB chunks are hashed
  /// together with the file size to produce a fast fingerprint. This avoids
  /// loading huge PDFs entirely into memory.
  static Future<String> computeFileHash(
    String filePath, {
    int maxFullHashSize = 50 * 1024 * 1024, // 50 MB
  }) async {
    final file = File(filePath);
    final size = await file.length();

    if (size <= maxFullHashSize) {
      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    }

    // Large file: hash head + tail + size for a fast fingerprint.
    final raf = await file.open();
    try {
      final chunkSize = 2 * 1024 * 1024; // 2 MB
      final head = await raf.read(chunkSize);
      await raf.setPosition(size - chunkSize);
      final tail = await raf.read(chunkSize);

      final digest = sha256.convert([
        ...head,
        ...tail,
        ..._intToBytes(size),
      ]);
      return digest.toString();
    } finally {
      await raf.close();
    }
  }

  /// Computes a SHA-256 hash of raw bytes.
  static String computeFileHashFromBytes(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Returns the file size in bytes, or 0 if the file doesn't exist.
  static Future<int> fileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return file.length();
    }
    return 0;
  }

  /// Checks whether a file exists at [filePath].
  static Future<bool> exists(String filePath) async {
    return File(filePath).exists();
  }

  /// Extracts the filename without extension from a full path.
  static String fileNameWithoutExtension(String filePath) {
    return p.basenameWithoutExtension(filePath);
  }

  /// Converts an integer to a list of 8 bytes (big-endian).
  static List<int> _intToBytes(int value) {
    return [
      (value >> 56) & 0xFF,
      (value >> 48) & 0xFF,
      (value >> 40) & 0xFF,
      (value >> 32) & 0xFF,
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }
}
