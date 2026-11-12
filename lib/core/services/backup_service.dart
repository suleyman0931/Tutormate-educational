import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/constants/app_constants.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';

/// Current backup schema version. Increment when the archive format changes.
const int _kBackupSchemaVersion = 1;

/// Backup progress callback.
typedef BackupProgressCallback = void Function(String message, double progress);

/// Encapsulates everything needed to describe a backup archive.
class BackupManifest {
  final int schemaVersion;
  final String appVersion;
  final DateTime createdAt;
  final Map<String, String> fileHashes; // relative path → sha256

  const BackupManifest({
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.fileHashes,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
        'createdAt': createdAt.toIso8601String(),
        'fileHashes': fileHashes,
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      schemaVersion: json['schemaVersion'] as int,
      appVersion: json['appVersion'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      fileHashes: Map<String, String>.from(json['fileHashes'] as Map),
    );
  }
}

/// Creates a `.tutormate` backup archive containing:
/// - `manifest.json`
/// - `database.sqlite`
/// - `pdfs/<id>.pdf`
/// - `covers/<id>.jpg`
/// - `preferences.json`
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  Future<String> createBackup({
    BackupProgressCallback? onProgress,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(p.join(docs.path, AppConstants.backupsDir));
    if (!backupsDir.existsSync()) await backupsDir.create(recursive: true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final archivePath = p.join(
        backupsDir.path, 'tutormate_$timestamp${AppConstants.backupExtension}');

    onProgress?.call('Preparing backup…', 0.05);

    final archive = Archive();
    final fileHashes = <String, String>{};

    // 1. Database file
    onProgress?.call('Exporting database…', 0.1);
    final dbFile =
        File(p.join(docs.path, '${AppConstants.databaseName}.sqlite'));
    if (dbFile.existsSync()) {
      final dbBytes = await dbFile.readAsBytes();
      fileHashes['database.sqlite'] = sha256.convert(dbBytes).toString();
      archive.addFile(
          ArchiveFile('database.sqlite', dbBytes.length, dbBytes));
    }

    // 2. PDF files
    onProgress?.call('Backing up PDFs…', 0.25);
    final books = await _db.select(_db.books).get();
    for (final book in books) {
      final f = File(book.filePath);
      if (!f.existsSync()) continue;
      final bytes = await f.readAsBytes();
      final relativePath = 'pdfs/${p.basename(book.filePath)}';
      fileHashes[relativePath] = sha256.convert(bytes).toString();
      archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
    }

    // 3. Cover images
    onProgress?.call('Backing up covers…', 0.55);
    for (final book in books) {
      final coverPath = book.coverPath;
      if (coverPath == null) continue;
      final f = File(coverPath);
      if (!f.existsSync()) continue;
      final bytes = await f.readAsBytes();
      final relativePath = 'covers/${p.basename(coverPath)}';
      fileHashes[relativePath] = sha256.convert(bytes).toString();
      archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
    }

    // 4. SharedPreferences export
    onProgress?.call('Exporting preferences…', 0.75);
    final prefs = await SharedPreferences.getInstance();
    final prefsMap = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      prefsMap[key] = prefs.get(key);
    }
    final prefsBytes = utf8.encode(jsonEncode(prefsMap));
    fileHashes['preferences.json'] = sha256.convert(prefsBytes).toString();
    archive
        .addFile(ArchiveFile('preferences.json', prefsBytes.length, prefsBytes));

    // 5. Manifest
    onProgress?.call('Writing manifest…', 0.88);
    final manifest = BackupManifest(
      schemaVersion: _kBackupSchemaVersion,
      appVersion: '1.0.0',
      createdAt: DateTime.now(),
      fileHashes: fileHashes,
    );
    final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));
    archive.addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    // 6. Write zip using archive 4.x API
    onProgress?.call('Compressing archive…', 0.92);
    final outputStream = OutputFileStream(archivePath);
    ZipEncoder().encode(archive, output: outputStream);
    await outputStream.close();

    onProgress?.call('Backup complete!', 1.0);
    return archivePath;
  }
}

/// Result of a backup integrity validation.
class ValidationResult {
  final bool isValid;
  final String? error;
  final BackupManifest? manifest;

  const ValidationResult.ok(this.manifest)
      : isValid = true,
        error = null;
  const ValidationResult.fail(this.error)
      : isValid = false,
        manifest = null;
}

/// Validates and restores a `.tutormate` backup archive.
class RestoreService {
  RestoreService();

  /// Validates the archive at [archivePath] using archive 3.x `decodeBytes`.
  Future<ValidationResult> validate(String archivePath) async {
    try {
      final bytes = await File(archivePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) {
        return const ValidationResult.fail(
            'No manifest.json — this may not be a TutorMate backup.');
      }

      final manifestJson =
          jsonDecode(utf8.decode(manifestFile.content as List<int>))
              as Map<String, dynamic>;
      final manifest = BackupManifest.fromJson(manifestJson);

      if (manifest.schemaVersion > _kBackupSchemaVersion) {
        return ValidationResult.fail(
            'This backup needs a newer version of TutorMate '
            '(schema v${manifest.schemaVersion}).');
      }

      for (final entry in manifest.fileHashes.entries) {
        final archiveFile = archive.findFile(entry.key);
        if (archiveFile == null) {
          return ValidationResult.fail(
              'Incomplete archive: missing "${entry.key}".');
        }
        final actualHash =
            sha256.convert(archiveFile.content as List<int>).toString();
        if (actualHash != entry.value) {
          return ValidationResult.fail(
              'Checksum mismatch for "${entry.key}". Backup may be corrupted.');
        }
      }

      return ValidationResult.ok(manifest);
    } catch (e) {
      return ValidationResult.fail('Failed to read archive: $e');
    }
  }

  /// Restores the archive at [archivePath].
  Future<void> restore(
    String archivePath, {
    bool merge = false,
    BackupProgressCallback? onProgress,
  }) async {
    final docs = await getApplicationDocumentsDirectory();

    onProgress?.call('Opening archive…', 0.05);
    final bytes = await File(archivePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Restore database
    onProgress?.call('Restoring database…', 0.15);
    final dbFile = archive.findFile('database.sqlite');
    if (dbFile != null) {
      final dest =
          File(p.join(docs.path, '${AppConstants.databaseName}.sqlite'));
      await dest.writeAsBytes(dbFile.content as List<int>);
    }

    // 2. Restore PDFs
    onProgress?.call('Restoring PDFs…', 0.35);
    final pdfsDir = Directory(p.join(docs.path, AppConstants.pdfsDir));
    if (!pdfsDir.existsSync()) await pdfsDir.create(recursive: true);
    for (final file in archive.files) {
      if (file.isFile && file.name.startsWith('pdfs/')) {
        final dest =
            File(p.join(pdfsDir.path, p.basename(file.name)));
        await dest.writeAsBytes(file.content as List<int>);
      }
    }

    // 3. Restore covers
    onProgress?.call('Restoring covers…', 0.6);
    final coversDir = Directory(p.join(docs.path, AppConstants.coversDir));
    if (!coversDir.existsSync()) await coversDir.create(recursive: true);
    for (final file in archive.files) {
      if (file.isFile && file.name.startsWith('covers/')) {
        final dest =
            File(p.join(coversDir.path, p.basename(file.name)));
        await dest.writeAsBytes(file.content as List<int>);
      }
    }

    // 4. Restore preferences
    onProgress?.call('Restoring preferences…', 0.8);
    final prefsFile = archive.findFile('preferences.json');
    if (prefsFile != null) {
      final prefsMap =
          jsonDecode(utf8.decode(prefsFile.content as List<int>))
              as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      for (final entry in prefsMap.entries) {
        final v = entry.value;
        if (v is bool) await prefs.setBool(entry.key, v);
        if (v is int) await prefs.setInt(entry.key, v);
        if (v is double) await prefs.setDouble(entry.key, v);
        if (v is String) await prefs.setString(entry.key, v);
        if (v is List) {
          await prefs.setStringList(
              entry.key, v.map((e) => e.toString()).toList());
        }
      }
    }

    onProgress?.call('Restore complete! Please restart the app.', 1.0);
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});

final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService();
});
