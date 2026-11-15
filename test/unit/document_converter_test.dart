import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tutormate/core/utils/document_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('document_converter_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('needsConversion identifies Word and text documents', () {
    expect(DocumentConverter.needsConversion('a.pdf'), isFalse);
    expect(DocumentConverter.needsConversion('a.PDF'), isFalse);
    expect(DocumentConverter.needsConversion('a.docx'), isTrue);
    expect(DocumentConverter.needsConversion('a.doc'), isTrue);
    expect(DocumentConverter.needsConversion('a.txt'), isTrue);
  });

  test('converts a text file to a cached PDF', () async {
    final file = File(p.join(tempDir.path, 'notes.txt'));
    await file.writeAsString('Hello world\n\nEthiopic: ሰላም ዓለም\n');

    final pdfPath = await DocumentConverter.convertToPdf(file.path);

    expect(pdfPath, DocumentConverter.convertedPathFor(file.path));
    final pdfFile = File(pdfPath);
    expect(await pdfFile.exists(), isTrue);
    final bytes = await pdfFile.readAsBytes();
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');

    // Second call reuses the cache rather than regenerating.
    final again = await DocumentConverter.convertToPdf(file.path);
    expect(again, pdfPath);
  });

  test('converts a docx file with a paragraph and a table', () async {
    const documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
      <w:r><w:t>Unit One</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:rPr><w:b/></w:rPr><w:t>Bold</w:t></w:r>
      <w:r><w:t xml:space="preserve"> and plain text</w:t></w:r>
    </w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Name</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Value</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Alpha</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>1</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
    <w:sectPr/>
  </w:body>
</w:document>''';

    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'word/document.xml',
          utf8.encode(documentXml).length,
          utf8.encode(documentXml),
        ),
      );
    final docxBytes = ZipEncoder().encode(archive)!;
    final file = File(p.join(tempDir.path, 'lesson.docx'));
    await file.writeAsBytes(docxBytes);

    final pdfPath = await DocumentConverter.convertToPdf(file.path);

    expect(pdfPath, DocumentConverter.convertedPathFor(file.path));
    final pdfBytes = await File(pdfPath).readAsBytes();
    expect(pdfBytes.length, greaterThan(1000));
    expect(ascii.decode(pdfBytes.sublist(0, 4)), '%PDF');
  });
}
