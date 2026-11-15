import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

/// Converts Word (.docx/.doc) and text (.txt) documents to PDF on demand.
///
/// Uses bundled Noto Sans Ethiopic fonts, so Ethiopic (Amharic), Latin, and
/// other Unicode text render correctly instead of the built-in Helvetica.
class DocumentConverter {
  DocumentConverter._();

  static Future<pw.ThemeData>? _themeFuture;

  /// Checks if a file needs conversion to PDF.
  static bool needsConversion(String filePath) {
    final ext = getExtension(filePath);
    return ext == '.txt' || ext == '.doc' || ext == '.docx';
  }

  /// Gets the file extension.
  static String getExtension(String filePath) {
    return p.extension(filePath).toLowerCase();
  }

  /// Deterministic cached PDF path for [filePath].
  static String convertedPathFor(String filePath) => '$filePath.converted.pdf';

  /// Converts a document to PDF and returns the PDF file path.
  ///
  /// The result is cached next to the original as
  /// `<original>.converted.pdf` and reused on later calls.
  static Future<String> convertToPdf(String filePath) async {
    if (!needsConversion(filePath)) return filePath;

    final cachedPath = convertedPathFor(filePath);
    final cachedFile = File(cachedPath);
    if (await cachedFile.exists() && await cachedFile.length() > 0) {
      return cachedPath;
    }

    final extension = getExtension(filePath);
    final blocks = switch (extension) {
      '.txt' => await _readText(filePath),
      '.docx' => await _readDocx(filePath),
      '.doc' => await _readDoc(filePath),
      _ => throw FormatException('Unsupported document format: $extension'),
    };

    final bytes = await _renderDocument(blocks);
    await cachedFile.writeAsBytes(bytes, flush: true);
    return cachedPath;
  }

  /// Deletes a cached converted PDF.
  static Future<void> cleanupConverted(String convertedPath) async {
    if (!convertedPath.contains('.converted.pdf')) return;
    try {
      await File(convertedPath).delete();
    } catch (_) {
      // Ignore cleanup errors.
    }
  }

  /// Deletes the cached converted PDF belonging to [originalPath], if any.
  static Future<void> removeCached(String originalPath) =>
      cleanupConverted(convertedPathFor(originalPath));

  // ── Rendering ───────────────────────────────────────────────────────────────

  static Future<pw.ThemeData> _documentTheme() {
    return _themeFuture ??= () async {
      final latinRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
      );
      final latinBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
      );
      final ethiopicRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansEthiopic-Regular.ttf'),
      );
      final ethiopicBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansEthiopic-Bold.ttf'),
      );
      return pw.ThemeData.withFont(
        base: latinRegular,
        bold: latinBold,
        italic: latinRegular,
        boldItalic: latinBold,
        // Noto Sans Ethiopic contains Ethiopic glyphs only; Latin text is
        // handled by the base Noto Sans font above.
        fontFallback: [ethiopicRegular, ethiopicBold],
      );
    }();
  }

  static Future<Uint8List> _renderDocument(List<_DocBlock> blocks) async {
    final theme = await _documentTheme();
    final document = pw.Document(theme: theme);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 56),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromInt(0xFF757575),
            ),
          ),
        ),
        build: (context) => [
          for (final block in blocks) _buildBlock(_sanitizeBlock(block)),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _buildBlock(_DocBlock block) {
    final table = block.table;
    if (table != null) {
      if (table.isEmpty) return pw.SizedBox(height: 6);
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.TableHelper.fromTextArray(
          data: table,
          headerCount: 1,
          cellPadding: const pw.EdgeInsets.all(4),
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          border: pw.TableBorder.all(
            color: PdfColor.fromInt(0xFFBDBDBD),
            width: 0.5,
          ),
        ),
      );
    }

    if (block.runs.isEmpty) return pw.SizedBox(height: 8);

    final headingLevel = block.headingLevel;
    if (headingLevel != null) {
      final text = block.runs.map((run) => run.text).join();
      final size = switch (headingLevel) {
        0 => 20.0,
        1 => 17.0,
        2 => 15.0,
        _ => 13.0,
      };
      return pw.Padding(
        padding: pw.EdgeInsets.only(
          top: headingLevel == 0 ? 4 : 12,
          bottom: 6,
        ),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF1A237E),
          ),
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
          children: [
            for (final run in block.runs)
              pw.TextSpan(
                text: run.text,
                style: pw.TextStyle(
                  fontWeight: run.bold ? pw.FontWeight.bold : null,
                  fontStyle: run.italic ? pw.FontStyle.italic : null,
                  decoration:
                      run.underline ? pw.TextDecoration.underline : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static _DocBlock _sanitizeBlock(_DocBlock block) {
    return _DocBlock(
      runs: [
        for (final run in block.runs)
          _TextRun(
            _sanitize(run.text),
            bold: run.bold,
            italic: run.italic,
            underline: run.underline,
          ),
      ],
      headingLevel: block.headingLevel,
      table: block.table
          ?.map((row) => row.map(_sanitize).toList(growable: false))
          .toList(growable: false),
    );
  }

  /// Removes characters the bundled font cannot render (emoji, controls).
  static String _sanitize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune == 0x09 || rune == 0x0A) {
        buffer.writeCharCode(rune);
      } else if (rune == 0x0D || rune == 0x0B || rune == 0x0C) {
        buffer.write('\n');
      } else if (rune == 0xA0) {
        buffer.write(' ');
      } else if (rune < 0x20 || rune > 0xFFFF) {
        continue;
      } else if ((rune >= 0x200B && rune <= 0x200F) ||
          (rune >= 0x202A && rune <= 0x202E) ||
          rune == 0x2060 ||
          rune == 0xFEFF ||
          rune == 0xFFFD) {
        continue;
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  // ── TXT ─────────────────────────────────────────────────────────────────────

  static Future<List<_DocBlock>> _readText(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return _textToBlocks(_decodeTextFile(bytes));
  }

  static String _decodeTextFile(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16Le(bytes, start: 2);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final units = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) {
        units.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(units);
    }

    final decoded = utf8.decode(bytes, allowMalformed: true);
    if (!decoded.contains('\uFFFD')) return decoded;

    // UTF-16LE without a BOM is common for Amharic text files.
    final utf16 = _decodeUtf16Le(bytes);
    if (_meaningfulCount(utf16) > _meaningfulCount(decoded)) return utf16;

    return latin1.decode(bytes);
  }

  static String _decodeUtf16Le(Uint8List bytes, {int start = 0}) {
    final units = <int>[];
    for (var i = start; i + 1 < bytes.length; i += 2) {
      units.add(bytes[i] | (bytes[i + 1] << 8));
    }
    return String.fromCharCodes(units);
  }

  static List<_DocBlock> _textToBlocks(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = <_DocBlock>[];

    for (final rawLine in normalized.split('\n')) {
      final line = rawLine.replaceAll('\t', '    ').trimRight();
      if (line.trim().isEmpty) {
        if (blocks.isNotEmpty && blocks.last.runs.isNotEmpty) {
          blocks.add(const _DocBlock());
        }
        continue;
      }
      blocks.add(_DocBlock(runs: [_TextRun(line)]));
    }

    while (blocks.isNotEmpty && blocks.last.runs.isEmpty) {
      blocks.removeLast();
    }
    if (blocks.isEmpty) {
      blocks.add(const _DocBlock(runs: [_TextRun('(Empty document)')]));
    }
    return blocks;
  }

  // ── DOCX ────────────────────────────────────────────────────────────────────

  static Future<List<_DocBlock>> _readDocx(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw FormatException('Could not open .docx file: $e');
    }

    ArchiveFile? documentXml;
    for (final file in archive.files) {
      if (file.isFile && file.name == 'word/document.xml') {
        documentXml = file;
        break;
      }
    }
    if (documentXml == null) {
      throw const FormatException(
        'This file is not a valid Word .docx document.',
      );
    }

    final content = documentXml.content;
    final xmlBytes = content is Uint8List
        ? content
        : Uint8List.fromList(content as List<int>);
    final xml = XmlDocument.parse(utf8.decode(xmlBytes, allowMalformed: true));

    final body = _firstDescendant(xml, 'body');
    if (body == null) return _textToBlocks('(Empty document)');

    final blocks = <_DocBlock>[];
    _parseWordContainer(body, blocks);
    if (blocks.isEmpty) return _textToBlocks('(Empty document)');
    return blocks;
  }

  static void _parseWordContainer(
    XmlElement container,
    List<_DocBlock> blocks,
  ) {
    for (final element in container.childElements) {
      switch (element.name.local) {
        case 'p':
          blocks.add(_parseWordParagraph(element));
        case 'tbl':
          final table = _parseWordTable(element);
          if (table != null) blocks.add(table);
        case 'sdt':
          final content = _child(element, 'sdtContent');
          if (content != null) _parseWordContainer(content, blocks);
        case 'customXml':
        case 'ins':
          _parseWordContainer(element, blocks);
        case 'del':
          break; // Deleted revision text.
        default:
          break;
      }
    }
  }

  static _DocBlock _parseWordParagraph(XmlElement paragraph) {
    int? headingLevel;
    var listItem = false;

    final properties = _child(paragraph, 'pPr');
    if (properties != null) {
      final style = _child(properties, 'pStyle');
      if (style != null) {
        headingLevel = _headingLevel(_attr(style, 'val') ?? '');
      }
      if (_child(properties, 'numPr') != null) listItem = true;
    }

    final runs = <_TextRun>[];
    _collectWordRuns(paragraph, runs);
    if (runs.isEmpty) return const _DocBlock();
    if (listItem) runs.insert(0, const _TextRun('•  '));

    return _DocBlock(runs: _mergeRuns(runs), headingLevel: headingLevel);
  }

  static void _collectWordRuns(XmlNode node, List<_TextRun> runs) {
    for (final child in node.children) {
      if (child is! XmlElement) continue;
      switch (child.name.local) {
        case 'r':
          final run = _parseWordRun(child);
          if (run != null) runs.add(run);
        case 'hyperlink':
        case 'smartTag':
        case 'fldSimple':
        case 'ins':
        case 'sdt':
        case 'sdtContent':
          _collectWordRuns(child, runs);
        default:
          break;
      }
    }
  }

  static _TextRun? _parseWordRun(XmlElement run) {
    var bold = false;
    var italic = false;
    var underline = false;

    final properties = _child(run, 'rPr');
    if (properties != null) {
      bold = _isOn(_child(properties, 'b'));
      italic = _isOn(_child(properties, 'i'));
      underline = _isOn(_child(properties, 'u'));
    }

    final buffer = StringBuffer();
    for (final child in run.childElements) {
      switch (child.name.local) {
        case 't':
          buffer.write(child.innerText);
        case 'tab':
          buffer.write('\t');
        case 'br':
        case 'cr':
          buffer.write('\n');
        case 'noBreakHyphen':
          buffer.write('-');
        default:
          break;
      }
    }

    final text = buffer.toString();
    if (text.isEmpty) return null;
    return _TextRun(
      text,
      bold: bold,
      italic: italic,
      underline: underline,
    );
  }

  static List<_TextRun> _mergeRuns(List<_TextRun> runs) {
    final merged = <_TextRun>[];
    for (final run in runs) {
      if (merged.isEmpty) {
        merged.add(run);
        continue;
      }
      final previous = merged.last;
      if (previous.bold == run.bold &&
          previous.italic == run.italic &&
          previous.underline == run.underline) {
        merged[merged.length - 1] = _TextRun(
          previous.text + run.text,
          bold: previous.bold,
          italic: previous.italic,
          underline: previous.underline,
        );
      } else {
        merged.add(run);
      }
    }
    return merged;
  }

  static _DocBlock? _parseWordTable(XmlElement table) {
    final rows = <List<String>>[];

    for (final rowElement in table.findAllElements('tr', namespace: '*')) {
      final cells = <String>[];
      for (final cellElement in rowElement.findElements('tc', namespace: '*')) {
        final paragraphs = <String>[];
        for (final paragraph
            in cellElement.findAllElements('p', namespace: '*')) {
          final runs = <_TextRun>[];
          _collectWordRuns(paragraph, runs);
          final text = runs.map((run) => run.text).join().trim();
          if (text.isNotEmpty) paragraphs.add(text);
        }
        cells.add(paragraphs.join('\n'));
      }
      if (cells.isNotEmpty) rows.add(cells);
    }

    if (rows.isEmpty ||
        rows.every((row) => row.every((cell) => cell.trim().isEmpty))) {
      return null;
    }
    return _DocBlock(table: rows);
  }

  static int? _headingLevel(String styleName) {
    final normalized = styleName.toLowerCase().replaceAll(
          RegExp(r'[\s_-]+'),
          '',
        );
    if (normalized == 'title') return 0;
    final match = RegExp(r'heading(\d+)').firstMatch(normalized);
    final level = int.tryParse(match?.group(1) ?? '');
    if (level == null) return null;
    if (level < 1) return 1;
    if (level > 3) return 3;
    return level;
  }

  // ── DOC (OLE compound file + Word piece table) ─────────────────────────────

  static Future<List<_DocBlock>> _readDoc(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    String? extracted;

    final ole = _OleFile.tryParse(bytes);
    if (ole != null) {
      final word = ole.readStream('WordDocument');
      if (word != null && word.length > 0x200) {
        final usesOneTable = (_u16(word, 0x0A) & 0x0200) != 0;
        final table = ole.readStream(usesOneTable ? '1Table' : '0Table');
        extracted = _extractWordText(word, table);
      }
    }

    extracted ??= _heuristicTextExtraction(bytes);
    if (extracted.trim().isEmpty) {
      throw const FormatException(
        'Could not extract text from this .doc file. '
        'Try saving it as .docx or PDF.',
      );
    }
    return _textToBlocks(extracted);
  }

  static String? _extractWordText(Uint8List word, Uint8List? table) {
    final ccpText = _u32(word, 0x4C);
    final fcClx = _u32(word, 0x01A2);
    final lcbClx = _u32(word, 0x01A6);

    if (table != null &&
        fcClx > 0 &&
        lcbClx > 0 &&
        fcClx + lcbClx <= table.length) {
      final pieceText =
          _extractFromPieceTable(word, table, fcClx, lcbClx, ccpText);
      if (pieceText != null && pieceText.trim().isNotEmpty) {
        return _cleanWordText(pieceText);
      }
    }

    // Word 6/95 and some malformed documents store text contiguously.
    final fcMin = _u32(word, 0x18);
    final fcMac = _u32(word, 0x1C);
    if (fcMin > 0 && fcMac > fcMin && fcMac <= word.length) {
      final text = _decodeContiguousText(word.sublist(fcMin, fcMac));
      if (text.trim().isNotEmpty) return _cleanWordText(text);
    }

    return null;
  }

  static String? _extractFromPieceTable(
    Uint8List word,
    Uint8List table,
    int fcClx,
    int lcbClx,
    int ccpText,
  ) {
    try {
      var position = fcClx;
      final end = fcClx + lcbClx;

      while (position < end) {
        final clxType = table[position];
        position += 1;

        if (clxType == 0x01) {
          // Prc: a grpprl block that can precede the piece table.
          final size = _u16(table, position);
          position += 2 + size;
          continue;
        }
        if (clxType != 0x02) return null;

        final plcSize = _u32(table, position);
        position += 4;
        if (plcSize < 16 || position + plcSize > table.length) return null;

        final pieceCount = (plcSize - 4) ~/ 12;
        if (pieceCount <= 0) return null;

        final cpOffset = position;
        final pcdOffset = position + (pieceCount + 1) * 4;
        final buffer = StringBuffer();

        for (var i = 0; i < pieceCount; i++) {
          final cpStart = _u32(table, cpOffset + i * 4);
          final cpEnd = _u32(table, cpOffset + (i + 1) * 4);
          if (ccpText > 0 && cpStart >= ccpText) break;

          var charCount = cpEnd - cpStart;
          if (charCount <= 0) continue;
          if (ccpText > 0 && cpStart + charCount > ccpText) {
            charCount = ccpText - cpStart;
          }

          final pcd = pcdOffset + i * 8;
          if (pcd + 8 > table.length) break;

          final rawFc = _u32(table, pcd + 2);
          final compressed = (rawFc & 0x40000000) != 0;
          var fc = rawFc & 0x3FFFFFFF;

          if (compressed) {
            fc ~/= 2;
            if (fc + charCount > word.length) continue;
            for (var j = 0; j < charCount; j++) {
              buffer.writeCharCode(word[fc + j]);
            }
          } else {
            if (fc + charCount * 2 > word.length) continue;
            for (var j = 0; j < charCount; j++) {
              final code = word[fc + j * 2] | (word[fc + j * 2 + 1] << 8);
              buffer.writeCharCode(code);
            }
          }
        }

        return buffer.toString();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static String _cleanWordText(String raw) {
    final buffer = StringBuffer();
    for (final code in raw.runes) {
      switch (code) {
        case 0x0D:
        case 0x0B:
        case 0x0C:
        case 0x0E:
        case 0x07:
          buffer.write('\n');
        case 0x09:
          buffer.write('\t');
        case 0x1E:
          buffer.write('-');
        case 0x1F:
          break;
        case 0x13:
        case 0x14:
        case 0x15:
          break;
        default:
          if (code >= 0x20) buffer.writeCharCode(code);
      }
    }

    final lines = buffer
        .toString()
        .split('\n')
        .map((line) => line.replaceAll('\t', '    ').trimRight());

    final output = <String>[];
    var previousBlank = false;
    for (final line in lines) {
      if (line.trim().isEmpty) {
        if (!previousBlank) output.add('');
        previousBlank = true;
      } else {
        output.add(line);
        previousBlank = false;
      }
    }
    return output.join('\n').trim();
  }

  static String _decodeContiguousText(Uint8List bytes) {
    final utf16 = _decodeUtf16Le(bytes);
    final singleByte = String.fromCharCodes(bytes);
    return _meaningfulCount(utf16) >= _meaningfulCount(singleByte)
        ? utf16
        : singleByte;
  }

  static String _heuristicTextExtraction(Uint8List bytes) {
    final asciiRuns = _extractAsciiRuns(bytes);
    final utf16Runs = _extractUtf16Runs(bytes);
    return _meaningfulCount(utf16Runs) >= _meaningfulCount(asciiRuns)
        ? utf16Runs
        : asciiRuns;
  }

  static String _extractAsciiRuns(Uint8List bytes) {
    final buffer = StringBuffer();
    var run = <int>[];

    void flush() {
      if (run.length >= 4) {
        buffer.writeln(String.fromCharCodes(run));
      }
      run = <int>[];
    }

    for (final byte in bytes) {
      if (byte == 0x09 ||
          byte == 0x0A ||
          byte == 0x0D ||
          (byte >= 0x20 && byte <= 0x7E)) {
        run.add(byte);
      } else {
        flush();
      }
    }
    flush();
    return buffer.toString();
  }

  static String _extractUtf16Runs(Uint8List bytes) {
    final buffer = StringBuffer();
    final units = <int>[];

    void flush() {
      if (units.length >= 8) {
        buffer.writeln(String.fromCharCodes(units));
      }
      units.clear();
    }

    var index = 0;
    while (index + 1 < bytes.length) {
      final code = bytes[index] | (bytes[index + 1] << 8);
      if (_isReadableCodeUnit(code)) {
        units.add(code);
        index += 2;
        continue;
      }

      flush();
      // Re-align one byte later in case the run starts at an odd offset.
      if (index + 2 < bytes.length) {
        final shifted = bytes[index + 1] | (bytes[index + 2] << 8);
        if (_isReadableCodeUnit(shifted)) {
          units.add(shifted);
          index += 3;
          continue;
        }
      }
      index += 2;
    }
    flush();
    return buffer.toString();
  }

  static bool _isReadableCodeUnit(int code) {
    if (code == 0x09 || code == 0x0A || code == 0x0D) return true;
    if (code >= 0x20 && code <= 0x7E) return true;
    if (code >= 0xA0 && code <= 0x024F) return true;
    if (code >= 0x1200 && code <= 0x137F) return true;
    return false;
  }

  static final RegExp _meaningfulPattern =
      RegExp(r'[\t\n\r\u0020-\u007E\u00A0-\u024F\u1200-\u137F]');

  static int _meaningfulCount(String value) {
    var count = 0;
    final limit = value.length > 20000 ? 20000 : value.length;
    for (var i = 0; i < limit; i++) {
      if (_meaningfulPattern.hasMatch(value[i])) count++;
    }
    return count;
  }

  // ── XML helpers ─────────────────────────────────────────────────────────────

  static XmlElement? _firstDescendant(XmlNode root, String localName) {
    for (final element in root.descendants.whereType<XmlElement>()) {
      if (element.name.local == localName) return element;
    }
    return null;
  }

  static XmlElement? _child(XmlElement parent, String localName) {
    for (final child in parent.childElements) {
      if (child.name.local == localName) return child;
    }
    return null;
  }

  static String? _attr(XmlElement element, String localName) {
    for (final attribute in element.attributes) {
      if (attribute.name.local == localName) return attribute.value;
    }
    return null;
  }

  static bool _isOn(XmlElement? element) {
    if (element == null) return false;
    final value = _attr(element, 'val');
    if (value == null) return true;
    final normalized = value.toLowerCase();
    return normalized != '0' &&
        normalized != 'false' &&
        normalized != 'off' &&
        normalized != 'none';
  }

  // ── Byte helpers ────────────────────────────────────────────────────────────

  static int _u16(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 1 >= bytes.length) return 0;
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  static int _u32(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 3 >= bytes.length) return 0;
    return (bytes[offset] |
            (bytes[offset + 1] << 8) |
            (bytes[offset + 2] << 16) |
            (bytes[offset + 3] << 24)) &
        0xFFFFFFFF;
  }
}

// ── Document model ────────────────────────────────────────────────────────────

class _DocBlock {
  const _DocBlock({this.runs = const [], this.headingLevel, this.table});

  final List<_TextRun> runs;
  final int? headingLevel;
  final List<List<String>>? table;
}

class _TextRun {
  const _TextRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
}

// ── OLE compound file reader (legacy .doc) ────────────────────────────────────

class _OleEntry {
  const _OleEntry(this.name, this.type, this.startSector, this.size);

  final String name;
  final int type;
  final int startSector;
  final int size;
}

class _OleFile {
  _OleFile._(
    this._bytes,
    this._sectorSize,
    this._miniSectorSize,
    this._miniCutoff,
    this._fat,
    this._miniFat,
    this._miniStream,
    this._entries,
  );

  static const int _freeSector = 0xFFFFFFFF;
  static const int _endOfChain = 0xFFFFFFFE;

  static int _u16(Uint8List bytes, int offset) =>
      DocumentConverter._u16(bytes, offset);

  static int _u32(Uint8List bytes, int offset) =>
      DocumentConverter._u32(bytes, offset);

  final Uint8List _bytes;
  final int _sectorSize;
  final int _miniSectorSize;
  final int _miniCutoff;
  final List<int> _fat;
  final List<int> _miniFat;
  final Uint8List _miniStream;
  final List<_OleEntry> _entries;

  static _OleFile? tryParse(Uint8List bytes) {
    try {
      if (bytes.length < 512) return null;
      if (bytes[0] != 0xD0 ||
          bytes[1] != 0xCF ||
          bytes[2] != 0x11 ||
          bytes[3] != 0xE0 ||
          bytes[4] != 0xA1 ||
          bytes[5] != 0xB1 ||
          bytes[6] != 0x1A ||
          bytes[7] != 0xE1) {
        return null;
      }

      final sectorShift = _u16(bytes, 0x1E);
      final miniSectorShift = _u16(bytes, 0x20);
      if (sectorShift < 9 || sectorShift > 12) return null;
      if (miniSectorShift < 6 || miniSectorShift > 12) return null;

      final sectorSize = 1 << sectorShift;
      final miniSectorSize = 1 << miniSectorShift;
      final firstDirectorySector = _u32(bytes, 0x30);
      final miniCutoff = _u32(bytes, 0x38);
      final firstMiniFatSector = _u32(bytes, 0x3C);
      final miniFatSectorCount = _u32(bytes, 0x40);
      final firstDifatSector = _u32(bytes, 0x44);
      final difatSectorCount = _u32(bytes, 0x48);

      final fatSectorIds = <int>[];
      for (var i = 0; i < 109; i++) {
        final sector = _u32(bytes, 0x4C + i * 4);
        if (sector == _freeSector || sector == _endOfChain) continue;
        fatSectorIds.add(sector);
      }

      var difatSector = firstDifatSector;
      final visitedDifat = <int>{};
      for (var i = 0; i < difatSectorCount; i++) {
        if (difatSector == _endOfChain || difatSector == _freeSector) break;
        if (!visitedDifat.add(difatSector)) break;

        final offset = _sectorOffset(difatSector, sectorSize);
        if (offset < 0 || offset + sectorSize > bytes.length) break;

        final entriesPerSector = sectorSize ~/ 4;
        for (var j = 0; j < entriesPerSector - 1; j++) {
          final sector = _u32(bytes, offset + j * 4);
          if (sector == _freeSector || sector == _endOfChain) continue;
          fatSectorIds.add(sector);
        }
        difatSector = _u32(bytes, offset + (entriesPerSector - 1) * 4);
      }

      final fat = <int>[];
      for (final sectorId in fatSectorIds) {
        final offset = _sectorOffset(sectorId, sectorSize);
        if (offset < 0 || offset + sectorSize > bytes.length) continue;
        for (var i = 0; i < sectorSize ~/ 4; i++) {
          fat.add(_u32(bytes, offset + i * 4));
        }
      }
      if (fat.isEmpty) return null;

      final directoryBytes = _readChain(
        bytes,
        fat,
        firstDirectorySector,
        sectorSize,
        maxBytes: 1 << 20,
      );
      if (directoryBytes == null) return null;

      final entries = <_OleEntry>[];
      for (var offset = 0;
          offset + 128 <= directoryBytes.length;
          offset += 128) {
        final nameLength = _u16(directoryBytes, offset + 0x40);
        final type = directoryBytes[offset + 0x42];
        if (type == 0) continue;

        final startSector = _u32(directoryBytes, offset + 0x74);
        final size = _u32(directoryBytes, offset + 0x78);

        var name = '';
        if (nameLength >= 2 && nameLength <= 64) {
          final units = <int>[];
          for (var i = 0; i + 1 < nameLength - 2; i += 2) {
            final code = directoryBytes[offset + i] |
                (directoryBytes[offset + i + 1] << 8);
            if (code == 0) break;
            units.add(code);
          }
          name = String.fromCharCodes(units);
        }

        entries.add(_OleEntry(name, type, startSector, size));
      }

      Uint8List miniStream = Uint8List(0);
      for (final entry in entries) {
        if (entry.type == 5) {
          final rootBytes = _readChain(
            bytes,
            fat,
            entry.startSector,
            sectorSize,
            maxBytes: entry.size,
          );
          if (rootBytes != null) miniStream = rootBytes;
          break;
        }
      }

      final miniFat = <int>[];
      if (miniFatSectorCount > 0 && firstMiniFatSector != _endOfChain) {
        final miniFatBytes = _readChain(
          bytes,
          fat,
          firstMiniFatSector,
          sectorSize,
          maxBytes: miniFatSectorCount * sectorSize,
        );
        if (miniFatBytes != null) {
          for (var i = 0; i + 3 < miniFatBytes.length; i += 4) {
            miniFat.add(_u32(miniFatBytes, i));
          }
        }
      }

      return _OleFile._(
        bytes,
        sectorSize,
        miniSectorSize,
        miniCutoff,
        fat,
        miniFat,
        miniStream,
        entries,
      );
    } catch (_) {
      return null;
    }
  }

  Uint8List? readStream(String name) {
    final normalizedName = name.toLowerCase();
    _OleEntry? entry;
    for (final candidate in _entries) {
      if (candidate.type == 2 &&
          candidate.name.toLowerCase() == normalizedName) {
        entry = candidate;
        break;
      }
    }
    if (entry == null) return null;
    if (entry.size <= 0) return Uint8List(0);

    if (entry.size < _miniCutoff && _miniStream.isNotEmpty) {
      return _readMiniChain(entry.startSector, entry.size);
    }
    return _readChain(
      _bytes,
      _fat,
      entry.startSector,
      _sectorSize,
      maxBytes: entry.size,
    );
  }

  Uint8List? _readMiniChain(int startSector, int size) {
    final output = BytesBuilder(copy: false);
    var sector = startSector;
    var remaining = size;
    final visited = <int>{};

    while (sector != _endOfChain && remaining > 0) {
      if (sector == _freeSector || !visited.add(sector)) break;
      final offset = sector * _miniSectorSize;
      if (offset < 0 || offset >= _miniStream.length) break;

      final length = remaining < _miniSectorSize ? remaining : _miniSectorSize;
      final end =
          offset + length > _miniStream.length ? _miniStream.length : offset + length;
      output.add(_miniStream.sublist(offset, end));
      remaining -= end - offset;

      if (sector >= _miniFat.length) break;
      sector = _miniFat[sector];
    }

    final result = output.takeBytes();
    return result.isEmpty ? null : result;
  }

  static Uint8List? _readChain(
    Uint8List bytes,
    List<int> fat,
    int startSector,
    int sectorSize, {
    required int maxBytes,
  }) {
    final output = BytesBuilder(copy: false);
    var sector = startSector;
    var produced = 0;
    final visited = <int>{};

    while (sector != _endOfChain && produced < maxBytes) {
      if (sector == _freeSector || !visited.add(sector)) break;
      final offset = _sectorOffset(sector, sectorSize);
      if (offset < 0 || offset + sectorSize > bytes.length) break;

      final take =
          maxBytes - produced < sectorSize ? maxBytes - produced : sectorSize;
      output.add(bytes.sublist(offset, offset + take));
      produced += take;

      if (sector >= fat.length) break;
      sector = fat[sector];
    }

    final result = output.takeBytes();
    return result.isEmpty ? null : result;
  }

  static int _sectorOffset(int sector, int sectorSize) =>
      (sector + 1) * sectorSize;
}
