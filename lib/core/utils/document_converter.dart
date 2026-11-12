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
  /// Note: This is a placeholder - full Word conversion requires external services.
  /// For now, we create a PDF showing the Word file info.
  static Future<String> _convertWordToPdf(String wordFilePath) async {
    final pdf = pw.Document();
    final filename = path.basename(wordFilePath);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Icon(
                  const pw.IconData(0xe873), // document icon
                  size: 80,
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Word Document',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  filename,
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'Note: Full Word document rendering is not yet supported.',
                  style: const pw.TextStyle(fontSize: 12),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Convert your Word file to PDF using Google Docs or Microsoft Word,',
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  'then import the PDF for full features.',
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );

    final dir = path.dirname(wordFilePath);
    final basename = path.basenameWithoutExtension(wordFilePath);
    final pdfPath = path.join(dir, '$basename.converted.pdf');
    
    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(await pdf.save());

    return pdfPath;
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
