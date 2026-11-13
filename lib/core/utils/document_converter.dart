import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Converts various document formats to PDF on-demand.
class DocumentConverter {
  DocumentConverter._();

  /// Checks if a file needs conversion to PDF.
  static bool needsConversion(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ext == '.txt' || ext == '.doc' || ext == '.docx';
  }

  /// Gets the file extension.
  static String getExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }

  /// Converts a document to PDF and returns the PDF file path.
  /// Creates a temporary PDF in the same directory as the source.
  static Future<String> convertToPdf(String filePath) async {
    final ext = getExtension(filePath);

    switch (ext) {
      case '.txt':
        return _convertTextToPdf(filePath);
      case '.doc':
      case '.docx':
        return _convertWordToPdf(filePath);
      default:
        return filePath; // Already PDF or unsupported
    }
  }

  /// Converts a text file to PDF.
  static Future<String> _convertTextToPdf(String textFilePath) async {
    final textFile = File(textFilePath);
    final textContent = await textFile.readAsString();

    final pdf = pw.Document();
    final lines = textContent.split('\n');
    const linesPerPage = 45;

    for (var i = 0; i < lines.length; i += linesPerPage) {
      final pageLines = lines.skip(i).take(linesPerPage).join('\n');
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  pageLines,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            );
          },
        ),
      );
    }

    // Save to temp directory with .converted.pdf suffix
    final dir = path.dirname(textFilePath);
    final basename = path.basenameWithoutExtension(textFilePath);
    final pdfPath = path.join(dir, '$basename.converted.pdf');
    
    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(await pdf.save());

    return pdfPath;
  }

  /// Converts a Word document to PDF.
  /// Extracts text content and creates a readable PDF.
  static Future<String> _convertWordToPdf(String wordFilePath) async {
    final pdf = pw.Document();
    String content = '';
    
    try {
      final file = File(wordFilePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        
        // Try to extract text from .docx (XML-based format)
        String extractedText = _extractTextFromDocx(bytes);
        if (extractedText.isEmpty) {
          // Fallback: extract any readable ASCII text
          extractedText = _extractReadableText(bytes);
        }
        
        if (extractedText.isNotEmpty) {
          content = extractedText;
        } else {
          content = 'Document: ${path.basename(wordFilePath)}\n'
              'Size: ${(bytes.length / 1024).toStringAsFixed(1)} KB\n\n'
              'Unable to extract text from this file. The file may be corrupted or in an unsupported format.';
        }
      }
    } catch (e) {
      content = 'Error reading Word document:\n$e\n\n'
          'File: ${path.basename(wordFilePath)}';
    }

    final lines = content.split('\n');
    const linesPerPage = 45;

    for (var i = 0; i < lines.length; i += linesPerPage) {
      final pageLines = lines.skip(i).take(linesPerPage).join('\n');
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  pageLines,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            );
          },
        ),
      );
    }

    final dir = path.dirname(wordFilePath);
    final basename = path.basenameWithoutExtension(wordFilePath);
    final pdfPath = path.join(dir, '$basename.converted.pdf');
    
    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(await pdf.save());

    return pdfPath;
  }

  /// Extracts text from a .docx file (which is a ZIP containing XML).
  /// Returns empty string if not a valid docx or extraction fails.
  static String _extractTextFromDocx(List<int> bytes) {
    try {
      // Look for common text patterns in XML
      final text = String.fromCharCodes(bytes);
      // .docx files contain text within <w:t> tags (simplified extraction)
      final buffer = StringBuffer();
      int index = 0;
      while ((index = text.indexOf('<w:t', index)) != -1) {
        final end = text.indexOf('</w:t>', index);
        if (end != -1) {
          final start = text.indexOf('>', index) + 1;
          if (start > index) {
            buffer.write(text.substring(start, end));
            buffer.write(' ');
          }
          index = end;
        } else {
          break;
        }
      }
      return buffer.toString().trim();
    } catch (_) {
      return '';
    }
  }

  /// Extracts readable ASCII text from binary data.
  static String _extractReadableText(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      // Include printable ASCII characters and common whitespace
      if ((byte >= 32 && byte <= 126) || byte == 9 || byte == 10 || byte == 13) {
        buffer.writeCharCode(byte);
      }
    }
    
    // Split into lines and filter meaningful ones
    final lines = buffer.toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.length > 2 && !line.startsWith('<?'))
        .take(500) // Limit to first 500 meaningful lines
        .toList();
    
    return lines.join('\n');
  }

  /// Cleans up temporary converted PDF files.
  static Future<void> cleanupConverted(String convertedPath) async {
    if (convertedPath.contains('.converted.pdf')) {
      try {
        await File(convertedPath).delete();
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }
}
