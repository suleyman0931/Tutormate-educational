import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutormate/app/theme/app_theme.dart';
import 'package:tutormate/core/database/app_database.dart';
import 'package:tutormate/core/database/database_provider.dart';
import 'package:tutormate/core/database/enums.dart';
import 'package:tutormate/features/about/presentation/about_screen.dart';
import 'package:tutormate/features/library/presentation/book_edit_screen.dart';
import 'package:tutormate/features/library/presentation/import_screen.dart';
import 'package:tutormate/features/notes/presentation/note_edit_screen.dart';
import 'package:tutormate/features/security/presentation/lock_screen.dart';
import 'package:tutormate/features/security/presentation/pin_setup_screen.dart';
import 'package:tutormate/features/security/presentation/security_settings_screen.dart';
import 'package:tutormate/features/settings/presentation/backup_screen.dart';
import 'package:tutormate/features/settings/presentation/settings_screen.dart';

base class TestPlatformFile extends PlatformFile {
  TestPlatformFile({required this.name, required String path})
    : uri = Uri.file(path);

  @override
  final String name;

  @override
  final Uri uri;

  @override
  XFile get xFile => XFile(uri.toFilePath());

  @override
  int? lengthSync() => 1024;

  @override
  Future<int?> length() async => 1024;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => const Stream<Uint8List>.empty();
}

void main() {
  final DateTime now = DateTime(2026, 1, 1);

  final List<Subject> subjects = <Subject>[
    Subject(id: 1, name: 'Mathematics', createdAt: now),
    Subject(id: 2, name: 'Physics', createdAt: now),
  ];

  final Book sampleBook = Book(
    id: 1,
    title: 'Mathematics Grade 10 Student Textbook',
    category: BookCategory.studentBook,
    grade: 5,
    subjectId: 1,
    filePath: '/tmp/math.pdf',
    totalPages: 120,
    createdAt: now,
    updatedAt: now,
    lastOpenedAt: now,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(320, 640),
    List<Override> overrides = const <Override>[],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          allSubjectsProvider.overrideWith(
            (ref) => Stream<List<Subject>>.value(subjects),
          ),
          ...overrides,
        ],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  final Map<String, Widget> screens = <String, Widget>{
    'settings': const SettingsScreen(),
    'backup': const BackupScreen(),
    'security settings': const SecuritySettingsScreen(),
    'pin setup': const PinSetupScreen(),
    'lock screen': const LockScreen(),
    'about': const AboutScreen(),
    'new note': const NoteEditScreen(),
    'edit book': BookEditScreen(book: sampleBook),
    'import': ImportScreen(
      files: <PlatformFile>[
        TestPlatformFile(name: 'sample.pdf', path: '/tmp/sample.pdf'),
      ],
    ),
  };

  for (final MapEntry<String, Widget> entry in screens.entries) {
    testWidgets('${entry.key} lays out at 320x640', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, entry.value);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('settings lays out at 360x800', (WidgetTester tester) async {
    await pumpScreen(
      tester,
      const SettingsScreen(),
      size: const Size(360, 800),
    );
    expect(tester.takeException(), isNull);
  });
}
