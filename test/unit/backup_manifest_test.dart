import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tutormate/core/services/backup_service.dart';

void main() {
  group('BackupManifest', () {
    test('serialises to JSON and deserialises back correctly', () {
      final original = BackupManifest(
        schemaVersion: 1,
        appVersion: '1.0.0',
        createdAt: DateTime(2026, 6, 15, 10, 30),
        fileHashes: {
          'database.sqlite': 'abc123',
          'pdfs/1.pdf': 'def456',
          'covers/1.jpg': 'ghi789',
          'preferences.json': 'jkl012',
        },
      );

      final json = jsonEncode(original.toJson());
      final restored = BackupManifest.fromJson(
          jsonDecode(json) as Map<String, dynamic>);

      expect(restored.schemaVersion, 1);
      expect(restored.appVersion, '1.0.0');
      expect(restored.createdAt, DateTime(2026, 6, 15, 10, 30));
      expect(restored.fileHashes['database.sqlite'], 'abc123');
      expect(restored.fileHashes['pdfs/1.pdf'], 'def456');
      expect(restored.fileHashes.length, 4);
    });

    test('fromJson handles empty fileHashes', () {
      final manifest = BackupManifest(
        schemaVersion: 1,
        appVersion: '1.0.0',
        createdAt: DateTime.now(),
        fileHashes: {},
      );
      final json = jsonEncode(manifest.toJson());
      final restored = BackupManifest.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
      expect(restored.fileHashes, isEmpty);
    });

    test('toJson includes all required fields', () {
      final manifest = BackupManifest(
        schemaVersion: 2,
        appVersion: '1.5.0',
        createdAt: DateTime(2026, 1, 1),
        fileHashes: {'a': 'b'},
      );
      final json = manifest.toJson();
      expect(json.containsKey('schemaVersion'), isTrue);
      expect(json.containsKey('appVersion'), isTrue);
      expect(json.containsKey('createdAt'), isTrue);
      expect(json.containsKey('fileHashes'), isTrue);
    });
  });

  group('LibraryFilters', () {
    test('ValidationResult.ok sets isValid true', () {
      final manifest = BackupManifest(
        schemaVersion: 1,
        appVersion: '1.0.0',
        createdAt: DateTime.now(),
        fileHashes: {},
      );
      final result = ValidationResult.ok(manifest);
      expect(result.isValid, isTrue);
      expect(result.error, isNull);
      expect(result.manifest, isNotNull);
    });

    test('ValidationResult.fail sets isValid false', () {
      const result = ValidationResult.fail('Corrupted file');
      expect(result.isValid, isFalse);
      expect(result.error, 'Corrupted file');
      expect(result.manifest, isNull);
    });
  });
}
