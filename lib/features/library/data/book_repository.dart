import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/books_dao.dart';
import '../../../core/database/daos/subjects_dao.dart';
import '../../../core/database/enums.dart';
import '../../../core/storage/cover_storage_service.dart';
import '../../../core/storage/pdf_cover_generator.dart';
import '../../../core/storage/pdf_storage_service.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/text_to_pdf_converter.dart';

/// Thrown when a PDF with the same content hash already exists in the library.
class DuplicateBookException implements Exception {
  final String existingTitle;
  DuplicateBookException(this.existingTitle);

  @override
  String toString() =>
      'A book with the same content already exists: "$existingTitle"';
}

/// Orchestrates PDF import, book CRUD, and file management.
class BookRepository {
  BookRepository(
    this._booksDao,
    this._subjectsDao,
    this._pdfStorage,
    this._coverStorage,
  );

  final BooksDao _booksDao;
  final SubjectsDao _subjectsDao;
  final PdfStorageService _pdfStorage;
  final CoverStorageService _coverStorage;

  // ── Import ──────────────────────────────────────────────────────────────────

  /// Picks one or more document files from the device.
  /// Supports PDF, Word (.docx, .doc), and Text (.txt).
  /// In file_picker 13.x, multiple selection is always enabled.
  Future<List<PlatformFile>> pickPdfFiles({bool allowMultiple = true}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'txt'],
    );
    
    // If only single file requested, return just first file
    if (!allowMultiple && result.isNotEmpty) {
      return [result.first];
    }
    
    return result;
  }

  /// Computes the SHA-256 hash of a picked file for duplicate detection.
  /// Uses [path] when available (Android), falls back to reading bytes.
  Future<String> _computeHash(PlatformFile file) async {
    if (file.path != null) {
      return FileUtils.computeFileHash(file.path!);
    }
    // Fallback: read bytes via the XFile stream.
    final bytes = await file.readAsBytes();
    return FileUtils.computeFileHashFromBytes(bytes);
  }

  /// Imports a single document into the library.
  /// Stores the original file (PDF, Word, or Text).
  /// Conversion happens on-demand when opening.
  ///
  /// Returns the new book ID. Throws [DuplicateBookException] if a book with
  /// the same content hash already exists (when [checkDuplicate] is true).
  Future<int> importBook({
    required PlatformFile file,
    required String title,
    required BookCategory category,
    required int grade,
    required int subjectId,
    String? description,
    String? author,
    String? publisher,
    String? academicYear,
    bool checkDuplicate = true,
  }) async {
    // 1. Compute hash for duplicate detection.
    final hash = await _computeHash(file);

    // 2. Check for duplicates.
    if (checkDuplicate) {
      final existing = await _booksDao.findByHash(hash);
      if (existing != null) {
        throw DuplicateBookException(existing.title);
      }
    }

    // 3. Insert book record with a placeholder path (will be updated after copy).
    final bookId = await _booksDao.insertBook(
      BooksCompanion.insert(
        title: title,
        category: category,
        grade: grade,
        subjectId: subjectId,
        filePath: '', // placeholder — updated after file copy
        description: Value(description),
        author: Value(author),
        publisher: Value(publisher),
        academicYear: Value(academicYear),
        fileHash: Value(hash),
      ),
    );

    // 4. Copy the PDF into app-managed storage.
    String finalPath;
    try {
      if (file.path != null) {
        finalPath = await _pdfStorage.importPdf(file.path!, bookId);
      } else {
        final bytes = await file.readAsBytes();
        finalPath = await _pdfStorage.importPdfBytes(bytes, bookId);
      }
    } catch (e) {
      // Roll back: delete the book record if file copy fails.
      await _booksDao.deleteBook(bookId);
      rethrow;
    }

    // 5. Generate cover from first page (best-effort, never fails import).
    String? coverPath;
    try {
      final coverBytes =
          await PdfCoverGenerator.generateCover(finalPath);
      if (coverBytes != null) {
        coverPath = await _coverStorage.saveCover(coverBytes, bookId);
      }
    } catch (_) {
      // Cover generation is optional; ignore errors.
    }

    // 6. Update the book record with final file path, cover, and total pages.
    final book = await _booksDao.getBook(bookId);
    if (book != null) {
      await _booksDao.updateBook(
        book.copyWith(
          filePath: finalPath,
          coverPath: Value(coverPath),
        ),
      );
    }

    return bookId;
  }

  /// Imports multiple PDFs in a batch with the same category, grade, subject.
  /// Each file's filename is used as its title.
  Future<List<({String filename, dynamic result, bool success})>>
      importMultipleBooks({
    required List<PlatformFile> files,
    required BookCategory category,
    required int grade,
    required int subjectId,
  }) async {
    final results = <({String filename, dynamic result, bool success})>[];

    for (final file in files) {
      try {
        final title = FileUtils.fileNameWithoutExtension(file.name);
        final id = await importBook(
          file: file,
          title: title,
          category: category,
          grade: grade,
          subjectId: subjectId,
          checkDuplicate: true,
        );
        results.add((filename: file.name, result: id, success: true));
      } on DuplicateBookException catch (e) {
        results.add((filename: file.name, result: e.toString(), success: false));
      } catch (e) {
        results.add((filename: file.name, result: e.toString(), success: false));
      }
    }

    return results;
  }

  // ── Update ──────────────────────────────────────────────────────────────────

  /// Updates a book's metadata fields.
  Future<void> updateBookMetadata({
    required int bookId,
    String? title,
    BookCategory? category,
    int? grade,
    int? subjectId,
    String? description,
    String? author,
    String? publisher,
    String? academicYear,
  }) async {
    final book = await _booksDao.getBook(bookId);
    if (book == null) return;

    await _booksDao.updateBook(
      book.copyWith(
        title: title ?? book.title,
        category: category ?? book.category,
        grade: grade ?? book.grade,
        subjectId: subjectId ?? book.subjectId,
        description: Value(description ?? book.description),
        author: Value(author ?? book.author),
        publisher: Value(publisher ?? book.publisher),
        academicYear: Value(academicYear ?? book.academicYear),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Replaces a book's PDF file with a new one, updating the file hash.
  Future<void> replacePdf({
    required int bookId,
    required PlatformFile newFile,
  }) async {
    final book = await _booksDao.getBook(bookId);
    if (book == null) return;

    // Delete old PDF from disk.
    await _pdfStorage.deletePdf(book.filePath);

    // Copy new PDF.
    String newPath;
    if (newFile.path != null) {
      newPath = await _pdfStorage.importPdf(newFile.path!, bookId);
    } else {
      final bytes = await newFile.readAsBytes();
      newPath = await _pdfStorage.importPdfBytes(bytes, bookId);
    }

    // Compute new hash.
    final hash = await _computeHash(newFile);

    // Update book record.
    await _booksDao.updateBook(
      book.copyWith(
        filePath: newPath,
        fileHash: Value(hash),
        updatedAt: DateTime.now(),
      ),
    );
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  /// Deletes a book and all its associated files from disk.
  /// FK cascades remove reading progress, bookmarks, and annotations.
  /// Notes linked to this book have their bookId set to NULL (preserved).
  Future<void> deleteBook(int bookId) async {
    final book = await _booksDao.getBook(bookId);
    if (book == null) return;

    await _pdfStorage.deletePdf(book.filePath);
    await _coverStorage.deleteCover(book.coverPath);
    await _booksDao.deleteBook(bookId);
  }

  // ── Misc ────────────────────────────────────────────────────────────────────

  /// Returns the subject name for a given subject ID.
  Future<String?> getSubjectName(int subjectId) async {
    final subject = await _subjectsDao.getSubject(subjectId);
    return subject?.name;
  }

  /// Updates the last opened timestamp for a book.
  Future<void> markAsOpened(int bookId) async {
    await _booksDao.updateLastOpened(bookId);
  }
}
