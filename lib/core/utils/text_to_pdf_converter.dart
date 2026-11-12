import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Converts text files to PDF format.
class TextToPdfConverter {
  TextToPdfConverter._();

  /// Converts a text file to PDF and saves it.
  /// Returns the path to the generated PDF file.
  static Future<String> convertTextToPdf(String textFilePath) async {
    // Read the text file
    final textFile = File(textFilePath);
    final textContent = await textFile.readAsString();

    // Create a PDF document
    final pdf = pw.Document();

    // Split text into lines
    final lines = textContent.split('\n');
    const linesPerPage = 45; // Approximately 45 lines per page

    // Add pages
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

    // Save PDF to a temporary file
    final pdfPath = textFilePath.replaceAll('.txt', '.pdf');
    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(await pdf.save());

    return pdfPath;
  }
}
