import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/database/app_database.dart';
import 'gemini_service.dart';

/// Text extracted from a single PDF page.
class BookPageText {
  final int pageNumber;
  final String text;

  const BookPageText({required this.pageNumber, required this.text});
}

/// Extracted text for one book.
class BookText {
  final int bookId;
  final String title;
  final List<BookPageText> pages;
  final bool isComplete;

  const BookText({
    required this.bookId,
    required this.title,
    required this.pages,
    required this.isComplete,
  });

  int get pageCount => pages.length;

  String get combinedText =>
      pages.map((page) => page.text).where((text) => text.isNotEmpty).join('\n');
}

/// A page that informed an AI answer.
class AiContextSource {
  final String bookTitle;
  final int pageNumber;

  const AiContextSource({required this.bookTitle, required this.pageNumber});
}

/// The relevant PDF excerpts sent to Gemini, plus their sources.
class AiContext {
  final String text;
  final List<AiContextSource> sources;
  final int booksSearched;
  final int pagesSearched;

  const AiContext({
    required this.text,
    required this.sources,
    required this.booksSearched,
    required this.pagesSearched,
  });

  const AiContext.empty()
      : text = '',
        sources = const [],
        booksSearched = 0,
        pagesSearched = 0;

  bool get isEmpty => text.trim().isEmpty;
}

class _CachedBookText {
  final BookText text;
  final DateTime fileModified;

  const _CachedBookText(this.text, this.fileModified);
}

class _Chunk {
  final String bookTitle;
  final int bookIndex;
  final int pageNumber;
  final int order;
  final String text;
  int score = 0;

  _Chunk({
    required this.bookTitle,
    required this.bookIndex,
    required this.pageNumber,
    required this.order,
    required this.text,
  });
}

/// Simplified PDF AI Context Service
/// Note: PDF text extraction disabled - AI will work without PDF context
class PdfAiContextService {
  static const String _cacheFolder = 'ai_text_cache';
  static const int _cacheVersion = 1;
  static const int _libraryPageBudget = 320;
  static const int _libraryPerBookPageBudget = 60;

  final Map<int, _CachedBookText> _memoryCache = {};
  final Map<int, Future<BookText>> _inFlight = {};
  Directory? _cacheDir;

  // ── Extraction ─────────────────────────────────────────────────────────────

  /// Extracts the text of [book], returning cached text when available.
  Future<BookText> extractBook(
    Book book, {
    int? maxPages,
    void Function(int extracted, int total)? onProgress,
  }) async {
    final file = File(book.filePath);
    if (!await file.exists()) {
      throw const AiException(
        'The PDF file is missing from the device. Re-import it and try again.',
      );
    }

    final modified = await file.lastModified();
    final cached = _memoryCache[book.id];
    if (cached != null &&
        cached.fileModified == modified &&
        cached.text.pages.isNotEmpty &&
        (maxPages == null ||
            cached.text.isComplete ||
            cached.text.pageCount <= maxPages)) {
      return cached.text;
    }

    final inFlight = _inFlight[book.id];
    if (inFlight != null) return inFlight;

    final future = _extractBookInternal(
      book,
      modified: modified,
      maxPages: maxPages,
      onProgress: onProgress,
    );
    _inFlight[book.id] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(book.id);
    }
  }

  Future<BookText> _extractBookInternal(
    Book book, {
    required DateTime modified,
    int? maxPages,
    void Function(int extracted, int total)? onProgress,
  }) async {
    // Try the persistent cache first.
    if (maxPages == null) {
      final diskCached = await _readDiskCache(book.id, modified);
      if (diskCached != null) {
        _memoryCache[book.id] = _CachedBookText(diskCached, modified);
        onProgress?.call(diskCached.pageCount, diskCached.pageCount);
        return diskCached;
      }
    }

    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(book.filePath);
      final total = document.pages.length;
      final limit = maxPages == null ? total : min(maxPages, total);
      final pages = <BookPageText>[];

      for (var i = 0; i < limit; i++) {
        final page = document.pages[i];
        String text = '';
        try {
          final raw = await page.loadText();
          text = raw?.fullText ?? '';
        } catch (_) {
          // A page that cannot be parsed is skipped rather than failing
          // the whole book.
        }
        pages.add(
          BookPageText(
            pageNumber: page.pageNumber,
            text: text.replaceAll('\u0000', ' ').trim(),
          ),
        );
        onProgress?.call(i + 1, limit);
      }

      final result = BookText(
        bookId: book.id,
        title: book.title,
        pages: pages,
        isComplete: limit == total,
      );

      if (result.isComplete) {
        _memoryCache[book.id] = _CachedBookText(result, modified);
        await _writeDiskCache(result, book.filePath, modified);
      }

      return result;
    } on AiException {
      rethrow;
    } catch (_) {
      throw AiException(
        'Could not read the text in "${book.title}". '
        'The file may be corrupted or password-protected.',
      );
    } finally {
      await document?.dispose();
    }
  }

  // ── Disk cache ─────────────────────────────────────────────────────────────

  Future<Directory> _getCacheDir() async {
    final existing = _cacheDir;
    if (existing != null) return existing;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _cacheFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  Future<BookText?> _readDiskCache(int bookId, DateTime fileModified) async {
    try {
      final dir = await _getCacheDir();
      final file = File(p.join(dir.path, '$bookId.json'));
      if (!await file.exists()) return null;

      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (json['version'] != _cacheVersion) return null;

      final cached = DateTime.fromMillisecondsSinceEpoch(json['modified'] as int);
      if (cached != fileModified) return null;

      final pagesList = (json['pages'] as List<dynamic>)
          .map((p) => BookPageText(
                pageNumber: p['page'] as int,
                text: p['text'] as String,
              ))
          .toList();

      return BookText(
        bookId: json['bookId'] as int,
        title: json['title'] as String,
        pages: pagesList,
        isComplete: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDiskCache(
    BookText text,
    String filePath,
    DateTime modified,
  ) async {
    try {
      final dir = await _getCacheDir();
      final file = File(p.join(dir.path, '${text.bookId}.json'));

      final json = {
        'version': _cacheVersion,
        'bookId': text.bookId,
        'title': text.title,
        'modified': modified.millisecondsSinceEpoch,
        'pages': text.pages
            .map((p) => {'page': p.pageNumber, 'text': p.text})
            .toList(),
      };

      await file.writeAsString(jsonEncode(json));
    } catch (_) {
      // Non-fatal cache write error
    }
  }

  // ── Library context ────────────────────────────────────────────────────────

  /// Builds context from books for a given question.
  Future<AiContext> buildContext({
    required List<Book> books,
    required String question,
    bool searchEntireLibrary = false,
    int? focusPage,
    void Function(String)? onStatus,
  }) async {
    if (books.isEmpty) return const AiContext.empty();

    if (searchEntireLibrary) {
      return buildLibraryContext(question, books);
    } else {
      // Single book mode
      return buildBookContext(question, books.first, currentPage: focusPage);
    }
  }

  /// Builds context from the user's full library for a given question.
  Future<AiContext> buildLibraryContext(
    String question,
    List<Book> library,
  ) async {
    if (library.isEmpty) return const AiContext.empty();

    final chunks = <_Chunk>[];
    int booksSearched = 0;

    for (int bookIdx = 0; bookIdx < library.length; bookIdx++) {
      final book = library[bookIdx];
      try {
        final text = await extractBook(
          book,
          maxPages: _libraryPerBookPageBudget,
        );

        if (text.pages.isEmpty) continue;
        booksSearched++;

        for (final page in text.pages) {
          if (page.text.isEmpty) continue;
          final sentences = _splitIntoSentences(page.text);
          for (int i = 0; i < sentences.length; i++) {
            chunks.add(_Chunk(
              bookTitle: book.title,
              bookIndex: bookIdx,
              pageNumber: page.pageNumber,
              order: i,
              text: sentences[i],
            ));
          }
        }
      } catch (_) {
        // Skip books that fail to extract
        continue;
      }
    }

    return _selectAndBuildContext(chunks, question, booksSearched);
  }

  /// Builds context from a single book for a given question.
  Future<AiContext> buildBookContext(
    String question,
    Book book, {
    int? currentPage,
  }) async {
    final text = await extractBook(book);
    if (text.pages.isEmpty) return const AiContext.empty();

    final chunks = <_Chunk>[];
    for (final page in text.pages) {
      if (page.text.isEmpty) continue;
      final sentences = _splitIntoSentences(page.text);
      for (int i = 0; i < sentences.length; i++) {
        chunks.add(_Chunk(
          bookTitle: book.title,
          bookIndex: 0,
          pageNumber: page.pageNumber,
          order: i,
          text: sentences[i],
        ));
      }
    }

    return _selectAndBuildContext(chunks, question, 1);
  }

  AiContext _selectAndBuildContext(
    List<_Chunk> chunks,
    String question,
    int booksSearched,
  ) {
    if (chunks.isEmpty) return const AiContext.empty();

    // Score chunks by keyword overlap
    final qWords = _extractKeywords(question.toLowerCase());
    for (final chunk in chunks) {
      final cWords = _extractKeywords(chunk.text.toLowerCase());
      chunk.score = qWords.where((w) => cWords.contains(w)).length;
    }

    // Sort by score descending
    chunks.sort((a, b) {
      final scoreComp = b.score.compareTo(a.score);
      if (scoreComp != 0) return scoreComp;
      // Tie-break: same book, same page, earlier sentence
      final bookComp = a.bookIndex.compareTo(b.bookIndex);
      if (bookComp != 0) return bookComp;
      final pageComp = a.pageNumber.compareTo(b.pageNumber);
      if (pageComp != 0) return pageComp;
      return a.order.compareTo(b.order);
    });

    // Take top chunks
    final selected = chunks.take(50).toList();
    final sources = <AiContextSource>[];
    final buffer = StringBuffer();

    for (final chunk in selected) {
      if (!sources.any((s) =>
          s.bookTitle == chunk.bookTitle &&
          s.pageNumber == chunk.pageNumber)) {
        sources.add(AiContextSource(
          bookTitle: chunk.bookTitle,
          pageNumber: chunk.pageNumber,
        ));
      }
      buffer.writeln(chunk.text);
    }

    return AiContext(
      text: buffer.toString(),
      sources: sources,
      booksSearched: booksSearched,
      pagesSearched: chunks.map((c) => c.pageNumber).toSet().length,
    );
  }

  List<String> _splitIntoSentences(String text) {
    return text
        .split(RegExp(r'[.!?]+'))
        .map((s) => s.trim())
        .where((s) => s.length > 20)
        .toList();
  }

  Set<String> _extractKeywords(String text) {
    return text
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 3)
        .toSet();
  }

  /// Extracts all pages from [book] and yields progress.
  Stream<(int, int)> extractBookWithProgress(Book book) async* {
    try {
      final document = await PdfDocument.openFile(book.filePath);
      final total = document.pages.length;

      for (var i = 0; i < total; i++) {
        yield (i + 1, total);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await document.dispose();
    } catch (_) {
      yield (0, 0);
    }
  }

  void clearMemoryCache() {
    _memoryCache.clear();
  }

  Future<void> deleteDiskCache(int bookId) async {
    try {
      final dir = await _getCacheDir();
      final file = File(p.join(dir.path, '$bookId.json'));
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

final pdfAiContextServiceProvider = Provider<PdfAiContextService>((ref) {
  return PdfAiContextService();
});
