import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../app/constants/app_constants.dart';
import '../../../app/router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/bookmarks_dao.dart';
import '../../../core/utils/document_converter.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../annotations/data/annotation_controller.dart';
import '../../annotations/presentation/annotation_overlay.dart';
import '../../annotations/presentation/annotation_toolbar.dart';
import '../../library/data/library_providers.dart';
import '../data/reader_providers.dart';

/// Hybrid PDF Reader:
/// - Uses flutter_pdfview for reading (excellent gestures on Samsung A10s)
/// - Switches to pdfrx when annotation mode is activated
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId, this.pageNumber});
  final int bookId;
  final int? pageNumber; // Page to open directly (from bookmark or continue)

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  // Controllers for both viewers
  PDFViewController? _pdfViewController;
  final pdfrx.PdfViewerController _pdfrxController = pdfrx.PdfViewerController();

  // Toolbar visibility
  bool _toolbarVisible = true;
  Timer? _toolbarHideTimer;

  // Scroll handle Y position (draggable)
  double _scrollHandleY = 0;
  bool _scrollHandleInitialized = false;

  // Current state
  int _currentPage = 1;
  int _totalPages = 0;
  bool _ready = false;
  String? _errorMessage;

  // Periodic save timer
  Timer? _saveTimer;

  // Current book
  Book? _book;

  // Annotation mode flag
  bool _isAnnotationMode = false;

  // Dark mode flag
  bool _isDarkMode = false;

  // Scroll lock flag for annotation mode
  bool _scrollLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable(); // Keep screen awake while reading
    _loadBook();
    _schedulePeriodicSave();
    _resetToolbarTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable(); // Allow screen to sleep
    _toolbarHideTimer?.cancel();
    _saveTimer?.cancel();
    _saveProgress();
    // PdfViewerController from pdfrx doesn't need manual disposal
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveProgress();
    }
  }

  Future<void> _loadBook() async {
    final book = await ref.read(booksDaoProvider).getBook(widget.bookId);
    if (!mounted) return;

    if (book == null) {
      setState(() => _errorMessage = 'Book not found in library.');
      return;
    }

    if (!File(book.filePath).existsSync()) {
      setState(
        () => _errorMessage =
            'File not found. The file may have been moved or deleted.\n\nPath: ${book.filePath}',
      );
      return;
    }

    // Check if document needs conversion to PDF
    final extension = book.filePath.split('.').last.toLowerCase();
    String pdfPath = book.filePath;

    if (extension != 'pdf') {
      // Show converting dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Converting document to PDF...'),
              ],
            ),
          ),
        );
      }

      try {
        pdfPath = await DocumentConverter.convertToPdf(book.filePath);
        if (mounted) Navigator.of(context).pop(); // Close converting dialog
        
        if (!File(pdfPath).existsSync()) {
          setState(() => _errorMessage = 'Conversion failed: PDF file not created.');
          return;
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop(); // Close converting dialog
        setState(() => _errorMessage = 'Could not convert document:\n$e');
        return;
      }
    }

    // Create a modified book object with PDF path
    setState(() => _book = book.copyWith(filePath: pdfPath));

    // If pageNumber was passed (from bookmark or AI), use it directly
    if (widget.pageNumber != null && widget.pageNumber! > 0) {
      setState(() => _currentPage = widget.pageNumber!);
      await ref.read(booksDaoProvider).updateLastOpened(widget.bookId);
      return;
    }

    final progress =
        await ref.read(progressDaoProvider).getProgress(widget.bookId);
    if (progress != null && progress.currentPage > 1) {
      // Show "Continue reading?" dialog
      if (mounted) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Continue Reading?'),
            content: Text(
              'You were on page ${progress.currentPage}. Do you want to continue from where you left off?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Start from Beginning'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );

        if (shouldContinue == true) {
          setState(() => _currentPage = progress.currentPage);
        } else {
          setState(() => _currentPage = 1);
        }
      }
    }

    await ref.read(booksDaoProvider).updateLastOpened(widget.bookId);
  }

  void _schedulePeriodicSave() {
    _saveTimer = Timer.periodic(
      Duration(milliseconds: AppConstants.progressSaveIntervalMs),
      (_) => _saveProgress(),
    );
  }

  Future<void> _saveProgress() async {
    if (_book == null || _totalPages == 0) return;
    final page = _currentPage;
    final total = _totalPages;
    await ref.read(progressDaoProvider).saveProgress(
          bookId: widget.bookId,
          currentPage: page,
          progressPercentage: total > 0 ? page / total : 0,
        );
  }

  void _onPageChanged(int? page, int? total) {
    if (page != null && page != _currentPage) {
      setState(() => _currentPage = page);
      _saveProgress();
    }
    if (total != null && total != _totalPages) {
      setState(() => _totalPages = total);
    }
  }

  void _onPdfrxPageChanged(int? page) {
    if (page != null && page != _currentPage) {
      setState(() => _currentPage = page);
      _saveProgress();
    }
  }

  void _onPdfViewCreated(PDFViewController controller) {
    _pdfViewController = controller;
    controller.getPageCount().then((count) {
      if (mounted) {
        setState(() {
          _totalPages = count ?? 0;
          _ready = true;
        });
      }
    });

    if (_currentPage > 1) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _pdfViewController?.setPage(_currentPage);
      });
    }
  }

  void _onPdfrxViewerReady(pdfrx.PdfDocument document, pdfrx.PdfViewerController c) {
    setState(() {
      _totalPages = c.pageCount;
      _ready = true;
    });

    if (_currentPage > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          c.goToPage(pageNumber: _currentPage, duration: Duration.zero);
        }
      });
    }
  }

  void _toggleToolbar() {
    setState(() => _toolbarVisible = !_toolbarVisible);
    if (_toolbarVisible) _resetToolbarTimer();
  }

  void _resetToolbarTimer() {
    _toolbarHideTimer?.cancel();
    final settings = ref.read(readerSettingsProvider);
    if (!settings.distractionFree) return;
    _toolbarHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toolbarVisible = false);
    });
  }

  void _toggleAnnotationMode() {
    setState(() {
      _isAnnotationMode = !_isAnnotationMode;
      if (_isAnnotationMode) {
        // Entering annotation mode - activate drawing tool
        ref.read(annotationToolProvider.notifier).state =
            AnnotationTool.drawing;
      } else {
        // Exiting annotation mode - deactivate tool
        ref.read(annotationToolProvider.notifier).state = AnnotationTool.none;
      }
    });

    // Sync page number when switching modes
    if (_isAnnotationMode && _pdfViewController != null) {
      _pdfViewController!.getCurrentPage().then((page) {
        if (page != null && mounted) {
          _pdfrxController.goToPage(pageNumber: page, duration: Duration.zero);
        }
      });
    }
  }

  Future<void> _showJumpToPageDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to Page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter page number (1–$_totalPages)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Page number',
                hintText: 'e.g., $_currentPage',
                prefixIcon: const Icon(Icons.tag_outlined),
              ),
              onSubmitted: (v) {
                final n = int.tryParse(v);
                if (n != null && n >= 1 && n <= _totalPages) {
                  Navigator.of(context).pop(n);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n != null && n >= 1 && n <= _totalPages) {
                Navigator.of(context).pop(n);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Please enter a number between 1 and $_totalPages'),
                  ),
                );
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (result != null && result >= 1 && result <= _totalPages) {
      if (_isAnnotationMode) {
        _pdfrxController.goToPage(pageNumber: result);
      } else {
        _pdfViewController?.setPage(result);
      }
    }
  }

  Future<void> _toggleBookmark() async {
    final bookmarksDao = ref.read(bookmarksDaoProvider);
    final existing =
        await bookmarksDao.getBookmark(widget.bookId, _currentPage);
    if (existing != null) {
      await bookmarksDao.deleteBookmark(existing.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bookmark removed from page $_currentPage')),
        );
      }
    } else {
      await _showAddBookmarkDialog(bookmarksDao);
    }
  }

  Future<void> _showAddBookmarkDialog(BookmarksDao bookmarksDao) async {
    final titleController = TextEditingController(
      text: 'Page $_currentPage',
    );
    final descController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bookmark'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              decoration:
                  const InputDecoration(labelText: 'Description (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await bookmarksDao.insertBookmark(
          BookmarksCompanion.insert(
            bookId: widget.bookId,
            pageNumber: _currentPage,
            title: titleController.text.trim().isEmpty
                ? 'Page $_currentPage'
                : titleController.text.trim(),
            description: descController.text.trim().isEmpty
                ? Value.absent()
                : Value(descController.text.trim()),
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bookmark added to page $_currentPage')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not add bookmark: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          _saveProgress();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _errorMessage != null
            ? _buildErrorState()
            : _book == null
                ? const LoadingIndicator(message: 'Opening book...')
                : _isAnnotationMode
                    ? _buildPdfrxReader()
                    : _buildFlutterPdfViewReader(),
      ),
    );
  }

  Widget _buildErrorState() {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  // Reading mode with flutter_pdfview (best gestures)
  Widget _buildFlutterPdfViewReader() {
    final settings = ref.watch(readerSettingsProvider);

    return GestureDetector(
      onTap: _toggleToolbar,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // Same ColorFiltered approach as annotation mode - inverts ALL content
          ColorFiltered(
            colorFilter: _isDarkMode
                ? const ColorFilter.matrix([
                    -1, 0, 0, 0, 255,
                    0, -1, 0, 0, 255,
                    0, 0, -1, 0, 255,
                    0, 0, 0, 1, 0,
                  ])
                : const ColorFilter.matrix([
                    1, 0, 0, 0, 0,
                    0, 1, 0, 0, 0,
                    0, 0, 1, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
            child: PDFView(
              key: ValueKey('pdf_${settings.mode.name}_$_isDarkMode'),
              filePath: _book!.filePath,
              enableSwipe: true,
              swipeHorizontal: settings.mode == ReadingMode.singlePage,
              autoSpacing: true,
              pageFling: settings.mode == ReadingMode.singlePage,
              pageSnap: settings.mode == ReadingMode.singlePage,
              defaultPage: _currentPage - 1,
              fitPolicy: FitPolicy.WIDTH,
              preventLinkNavigation: false,
              backgroundColor: const Color(0xFFFFFFFF),
              onRender: (pages) {
                if (mounted) {
                  setState(() {
                    _totalPages = pages ?? 0;
                    _ready = true;
                  });
                }
              },
              onError: (error) {
                if (mounted) {
                  setState(() => _errorMessage = 'Error loading PDF: $error');
                }
              },
              onPageError: (page, error) {
                debugPrint('Error on page $page: $error');
              },
              onViewCreated: _onPdfViewCreated,
              onPageChanged: _onPageChanged,
            ),
          ),

          if (_toolbarVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(settings),
            ),

          if (_toolbarVisible && settings.showPageNumbers && _ready)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(),
            ),
        ],
      ),
    );
  }

  // Annotation mode with pdfrx (annotations work properly)
  Widget _buildPdfrxReader() {
    final settings = ref.watch(readerSettingsProvider);
    
    return Stack(
      children: [
        // Wrap in ColorFiltered for dark mode - inverts ALL content including text
        ColorFiltered(
          colorFilter: _isDarkMode
              ? const ColorFilter.matrix([
                  -1, 0, 0, 0, 255,
                  0, -1, 0, 0, 255,
                  0, 0, -1, 0, 255,
                  0, 0, 0, 1, 0,
                ])
              : const ColorFilter.matrix([
                  1, 0, 0, 0, 0,
                  0, 1, 0, 0, 0,
                  0, 0, 1, 0, 0,
                  0, 0, 0, 1, 0,
                ]), // identity - no change in light mode
          child: pdfrx.PdfViewer.file(
            _book!.filePath,
            key: ValueKey('pdfrx_${settings.mode.name}_$_isDarkMode'),
            controller: _pdfrxController,
            params: pdfrx.PdfViewerParams(
              backgroundColor: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
              onPageChanged: _onPdfrxPageChanged,
              onViewerReady: _onPdfrxViewerReady,
              scaleEnabled: true,
              panEnabled: true,
              pageOverlaysBuilder: (context, pageRect, page) => [
                AnnotationOverlay(
                  bookId: widget.bookId,
                  pageNumber: page.pageNumber,
                  pageRect: pageRect,
                ),
              ],
            ),
          ),
        ),

        if (_toolbarVisible)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(ref.read(readerSettingsProvider)),
          ),

        if (_toolbarVisible && ref.read(readerSettingsProvider).showPageNumbers && _ready)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(),
          ),

        Consumer(
          builder: (ctx, ref, _) {
            final tool = ref.watch(annotationToolProvider);
            if (!tool.isActive) return const SizedBox.shrink();
            return Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: const AnnotationToolbar(),
            );
          },
        ),

        // Small scroll handle on the right - drag up/down to scroll the page
        _buildScrollHandle(),
      ],
    );
  }

  // A small draggable handle that scrolls the PDF viewer
  Widget _buildScrollHandle() {
    final screenHeight = MediaQuery.of(context).size.height;
    // Initialize position to middle of screen on first build
    if (!_scrollHandleInitialized) {
      _scrollHandleY = screenHeight / 2 - 30;
      _scrollHandleInitialized = true;
    }

    return Positioned(
      right: 8,
      top: _scrollHandleY,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            // Move the handle with finger
            _scrollHandleY += details.delta.dy;
            // Clamp to screen bounds
            _scrollHandleY = _scrollHandleY.clamp(80.0, screenHeight - 160.0);
          });
          // Also scroll the PDF based on drag
          final dy = details.delta.dy;
          if (dy.abs() > 1) {
            final currentPage = _pdfrxController.pageNumber ?? _currentPage;
            if (dy > 8 && currentPage < _totalPages) {
              _pdfrxController.goToPage(pageNumber: currentPage + 1);
            } else if (dy < -8 && currentPage > 1) {
              _pdfrxController.goToPage(pageNumber: currentPage - 1);
            }
          }
        },
        child: Container(
          width: 36,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 18),
              Icon(Icons.drag_handle, color: Colors.white, size: 16),
              Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ReaderSettings settings) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.87),
            Colors.black.withValues(alpha: 0.5),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                  tooltip: 'Go back',
                ),
                Expanded(
                  child: Text(
                    _book?.title ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Annotation tools - always visible
                if (_isAnnotationMode)
                  Consumer(
                    builder: (ctx, ref, _) {
                      final tool = ref.watch(annotationToolProvider);
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Tooltip(
                          message: tool == AnnotationTool.drawing ? 'Drawing active' : tool == AnnotationTool.eraser ? 'Eraser active' : '',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: tool != AnnotationTool.none ? Colors.amber.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: tool != AnnotationTool.none ? Border.all(color: Colors.amber, width: 1) : null,
                            ),
                            child: Text(
                              tool == AnnotationTool.drawing ? '✏️ Drawing' : tool == AnnotationTool.eraser ? '🗑️ Eraser' : '',
                              style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: Colors.white),
                  tooltip: 'Ask AI',
                  onPressed: () => context.push(
                    AppRoutes.aiFor(widget.bookId, page: _currentPage),
                  ),
                ),
                StreamBuilder<List<Bookmark>>(
                  stream: ref
                      .read(bookmarksDaoProvider)
                      .watchBookmarksByBook(widget.bookId),
                  builder: (context, snap) {
                    final bookmarked =
                        snap.data?.any((b) => b.pageNumber == _currentPage) ??
                            false;
                    return IconButton(
                      icon: Icon(
                        bookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: bookmarked ? Colors.amber : Colors.white,
                      ),
                      tooltip: bookmarked ? 'Remove Bookmark' : 'Add Bookmark',
                      onPressed: _toggleBookmark,
                    );
                  },
                ),
                if (!_isAnnotationMode)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    tooltip: 'Annotation Mode',
                    onPressed: () {
                      ref.read(annotationToolProvider.notifier).state = AnnotationTool.drawing;
                      _toggleAnnotationMode();
                    },
                  ),
                if (_isAnnotationMode)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Exit Annotation Mode',
                    onPressed: () {
                      ref.read(annotationToolProvider.notifier).state = AnnotationTool.none;
                      _toggleAnnotationMode();
                    },
                  ),
                IconButton(
                  icon: Icon(
                    settings.mode == ReadingMode.continuous
                        ? Icons.view_day_outlined
                        : Icons.swipe_outlined,
                    color: Colors.white,
                  ),
                  tooltip: 'Reading mode',
                  onPressed: () {
                    final next = settings.mode == ReadingMode.continuous
                        ? ReadingMode.singlePage
                        : ReadingMode.continuous;
                    ref.read(readerSettingsProvider.notifier).setMode(next);
                  },
                ),
                IconButton(
                  icon: Icon(
                    _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: _isDarkMode ? Colors.amber : Colors.white,
                  ),
                  tooltip: _isDarkMode ? 'Light mode' : 'Dark mode',
                  onPressed: () {
                    setState(() {
                      _isDarkMode = !_isDarkMode;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.tag_outlined, color: Colors.white),
                  tooltip: 'Go to page',
                  onPressed: _showJumpToPageDialog,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final progress = _totalPages > 0 ? _currentPage / _totalPages : 0.0;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.80),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _showJumpToPageDialog,
                child: Text(
                  '$_currentPage / $_totalPages${_isAnnotationMode ? ' (Annotation Mode)' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
