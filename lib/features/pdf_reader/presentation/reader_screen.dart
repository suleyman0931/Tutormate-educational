import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import '../../../app/constants/app_constants.dart';
import '../../../app/router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/bookmarks_dao.dart';
import '../../../core/database/daos/progress_dao.dart';
import '../../../core/utils/document_converter.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../annotations/data/annotation_controller.dart';
import '../../annotations/presentation/annotation_overlay.dart';
import '../../annotations/presentation/annotation_toolbar.dart';
import '../../library/data/library_providers.dart';
import '../data/reader_providers.dart';

/// PDF reader powered by pdfrx (PDFium).
///
/// Handles document conversion, resume-at-last-page, reading modes, and
/// annotation overlays.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.bookId,
    this.pageNumber,
    this.showResumePrompt = true,
  });
  final int bookId;
  final int? pageNumber; // Page to open directly (from bookmark or continue)

  /// When false, the saved page is restored without asking "Continue Reading?".
  /// Reader tabs use this so background tabs open silently.
  final bool showResumePrompt;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
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
  bool _restoringPage = false;
  String? _errorMessage;

  // Periodic save timer
  Timer? _saveTimer;

  // Current book
  Book? _book;

  // Cached so progress can still be saved from dispose().
  late final ProgressDao _progressDao;

  // Annotation mode flag
  bool _isAnnotationMode = false;

  // Dark mode flag
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progressDao = ref.read(progressDaoProvider);
    _loadBook();
    _schedulePeriodicSave();
    _resetToolbarTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

    // Convert Word/text documents to PDF on demand (the result is cached).
    var pdfPath = book.filePath;
    if (DocumentConverter.needsConversion(book.filePath)) {
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
          setState(
            () => _errorMessage = 'Conversion failed: PDF file not created.',
          );
          return;
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop(); // Close converting dialog
        setState(() => _errorMessage = 'Could not convert document:\n$e');
        return;
      }
    }

    // Decide the initial page BEFORE building the viewer, so it opens
    // directly at the right page instead of flashing page 1.
    var initialPage = 1;

    if (widget.pageNumber != null && widget.pageNumber! > 0) {
      initialPage = widget.pageNumber!;
    } else {
      final progress = await _progressDao.getProgress(widget.bookId);
      if (progress != null && progress.currentPage > 1 && mounted) {
        if (!widget.showResumePrompt) {
          initialPage = progress.currentPage;
        } else {
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
            initialPage = progress.currentPage;
          }
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _currentPage = initialPage;
      _book = book.copyWith(filePath: pdfPath);
    });

    await ref.read(booksDaoProvider).updateLastOpened(widget.bookId);
  }

  void _schedulePeriodicSave() {
    _saveTimer = Timer.periodic(
      Duration(milliseconds: AppConstants.progressSaveIntervalMs),
      (_) => _saveProgress(),
    );
  }

  Future<void> _saveProgress() async {
    if (_book == null || !_ready || _totalPages == 0) return;
    final page = _currentPage;
    final total = _totalPages;
    await _progressDao.saveProgress(
      bookId: widget.bookId,
      currentPage: page,
      progressPercentage: total > 0 ? page / total : 0,
    );
  }

  void _onPdfrxPageChanged(int? page) {
    // Ignore callbacks fired while the viewer initializes or while we are
    // restoring the saved page; otherwise page 1 overwrites the resume point.
    if (!_ready || _restoringPage) return;
    if (page != null && page != _currentPage) {
      setState(() => _currentPage = page);
      _saveProgress();
    }
  }

  Future<void> _onPdfrxViewerReady(
    pdfrx.PdfDocument document,
    pdfrx.PdfViewerController controller,
  ) async {
    final pageCount = controller.pageCount;
    var page = _currentPage;
    if (page < 1) page = 1;
    if (pageCount > 0 && page > pageCount) page = pageCount;

    setState(() {
      _totalPages = pageCount;
      _currentPage = page;
      _ready = true;
    });

    _restoringPage = true;
    try {
      if (page > 1) {
        await controller.goToPage(
          pageNumber: page,
          duration: Duration.zero,
        );
      }
    } finally {
      _restoringPage = false;
    }

    if (pageCount > 0 && _book?.totalPages != pageCount) {
      unawaited(
        ref
            .read(booksDaoProvider)
            .updatePageCount(widget.bookId, pageCount),
      );
    }

    // Persist the resumed page right away so the dashboard and reader tabs
    // show the correct page even before the next periodic save.
    await _saveProgress();
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

    // The overlay builder changed; re-layout while keeping the current zoom.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pdfrxController.invalidate();
    });
  }

  void _setReadingMode(ReadingMode mode) {
    if (ref.read(readerSettingsProvider).mode == mode) return;
    final page = _currentPage;
    ref.read(readerSettingsProvider.notifier).setMode(mode);

    // pdfrx caches the page layout; invalidate so the new layout is applied.
    // Then re-center the current page using the existing zoom level so the
    // reading position and zoom are both preserved across the layout change.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _pdfrxController.invalidate();
      await _pdfrxController.goToPage(
        pageNumber: page,
        anchor: pdfrx.PdfPageAnchor.center,
        duration: Duration.zero,
      );
    });
  }

  Future<void> _zoomIn() async {
    if (!_ready) return;
    await _pdfrxController.zoomUp(
      duration: const Duration(milliseconds: 150),
    );
  }

  Future<void> _zoomOut() async {
    if (!_ready) return;
    await _pdfrxController.zoomDown(
      duration: const Duration(milliseconds: 150),
    );
  }

  /// Pans the zoomed page. A positive direction means "move the viewport
  /// toward that edge", so pressing right reveals content on the right.
  Future<void> _panBy(Offset direction) async {
    if (!_ready) return;

    // Move by roughly a quarter of the visible area on each press.
    final stepX =
        (_pdfrxController.viewSize.width * 0.28).clamp(48.0, 280.0);
    final stepY =
        (_pdfrxController.viewSize.height * 0.22).clamp(48.0, 280.0);
    final delta = Offset(direction.dx * stepX, direction.dy * stepY);

    final next = _pdfrxController.value.clone()
      ..translateByDouble(delta.dx, delta.dy, 0, 1);
    await _pdfrxController.goTo(
      next,
      duration: const Duration(milliseconds: 120),
    );
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
      await _pdfrxController.goToPage(
        pageNumber: result,
        duration: const Duration(milliseconds: 200),
      );
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
                // Always use pdfrx - it supports ALL fonts and languages
                // (uses PDFium engine like Chrome, supports Ethiopic, Arabic, etc.)
                : _buildPdfrxReader(),
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

  Future<void> _askGeminiAboutSelection(
    pdfrx.PdfViewerContextMenuBuilderParams params,
  ) async {
    final selected =
        (await params.textSelectionDelegate.getSelectedText()).trim();
    if (selected.isEmpty || !mounted) return;

    params.dismissContextMenu();
    await params.textSelectionDelegate.clearTextSelection();

    if (!mounted) return;
    await context.push(
      AppRoutes.aiFor(widget.bookId, page: _currentPage),
      extra: selected,
    );
  }

  /// Horizontal strip used by single-page mode: all pages are laid out
  /// side-by-side at their natural size. Horizontal paging then lets the
  /// viewer snap one page at a time while the transform (zoom) is preserved
  /// when switching modes.
  static pdfrx.PdfPageLayout _singlePageLayout(
    List<pdfrx.PdfPage> pages,
    pdfrx.PdfViewerParams params,
  ) {
    var maxHeight = 0.0;
    for (final page in pages) {
      if (page.height > maxHeight) maxHeight = page.height;
    }

    final layouts = <Rect>[];
    var x = params.margin;
    for (final page in pages) {
      layouts.add(
        Rect.fromLTWH(
          x,
          params.margin + (maxHeight - page.height) / 2,
          page.width,
          page.height,
        ),
      );
      x += page.width + params.margin;
    }

    return pdfrx.PdfPageLayout(
      pageLayouts: layouts,
      documentSize: Size(x, maxHeight + params.margin * 2),
    );
  }

  // pdfrx reader - supports ALL fonts, languages, scripts (Ethiopic, Arabic, etc.)
  Widget _buildPdfrxReader() {
    final settings = ref.watch(readerSettingsProvider);
    
    return Stack(
      children: [
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
          child: GestureDetector(
            onTap: _toggleToolbar,
            behavior: HitTestBehavior.translucent,
            child: pdfrx.PdfViewer.file(
              _book!.filePath,
              key: const ValueKey('pdfrx_reader'),
              controller: _pdfrxController,
              initialPageNumber: _currentPage,
              params: pdfrx.PdfViewerParams(
                backgroundColor: _isDarkMode
                    ? const Color(0xFF1A1A1A)
                    : Colors.white,
                onPageChanged: _onPdfrxPageChanged,
                onViewerReady: _onPdfrxViewerReady,
                scaleEnabled: true,
                panEnabled: true,
                customizeContextMenuItems: (params, items) {
                  if (params.isTextSelectionEnabled &&
                      params.textSelectionDelegate.hasSelectedText) {
                    items.add(
                      ContextMenuButtonItem(
                        label: 'Ask Gemini',
                        onPressed: () => _askGeminiAboutSelection(params),
                      ),
                    );
                  }
                },
                layoutPages: settings.mode == ReadingMode.singlePage
                    ? _singlePageLayout
                    : null,
                // Show annotation overlay only in annotation mode
                pageOverlaysBuilder: _isAnnotationMode
                    ? (context, pageRect, page) => [
                        AnnotationOverlay(
                          bookId: widget.bookId,
                          pageNumber: page.pageNumber,
                          pageRect: pageRect,
                        ),
                      ]
                    : null,
              ),
            ),
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

        // Annotation toolbar - only shown in annotation mode
        if (_isAnnotationMode)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: const AnnotationToolbar(),
          ),

        // Zoom buttons for annotation mode
        if (_isAnnotationMode && _ready) _buildZoomControls(),

        // Scroll handle for fast page navigation
        if (_ready) _buildScrollHandle(),
      ],
    );
  }

  Widget _buildZoomControls() {
    return Positioned(
      left: 12,
      bottom: MediaQuery.of(context).padding.bottom + 76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Material(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(22),
            elevation: 4,
            child: AnimatedBuilder(
              animation: _pdfrxController,
              builder: (context, _) {
                final zoom = (_pdfrxController.currentZoom * 100).round();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _zoomIn,
                      tooltip: 'Zoom in',
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 22,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    Text(
                      '$zoom%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: _zoomOut,
                      tooltip: 'Zoom out',
                      icon: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 22,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          _buildPanPad(),
        ],
      ),
    );
  }

  /// Four-direction pad used to reach the edges of a zoomed page.
  Widget _buildPanPad() {
    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      child: AnimatedBuilder(
        animation: _pdfrxController,
        builder: (context, _) {
          final zoomed = _pdfrxController.currentZoom > 1.01;
          return Opacity(
            opacity: zoomed ? 1 : 0.45,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PanButton(
                    icon: Icons.keyboard_arrow_up_rounded,
                    tooltip: 'Move up',
                    onPan: () => _panBy(const Offset(0, 1)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PanButton(
                        icon: Icons.keyboard_arrow_left_rounded,
                        tooltip: 'Move left',
                        onPan: () => _panBy(const Offset(1, 0)),
                      ),
                      const SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(
                          Icons.open_with_rounded,
                          color: Colors.white24,
                          size: 16,
                        ),
                      ),
                      _PanButton(
                        icon: Icons.keyboard_arrow_right_rounded,
                        tooltip: 'Move right',
                        onPan: () => _panBy(const Offset(-1, 0)),
                      ),
                    ],
                  ),
                  _PanButton(
                    icon: Icons.keyboard_arrow_down_rounded,
                    tooltip: 'Move down',
                    onPan: () => _panBy(const Offset(0, -1)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // A small draggable handle for fast page navigation.
  Widget _buildScrollHandle() {
    final screenHeight = MediaQuery.of(context).size.height;
    final topBarHeight = 100.0;   // approx top bar
    final bottomBarHeight = 80.0; // approx bottom bar + toolbar
    final handleHeight = 60.0;
    final minY = topBarHeight;
    final maxY = screenHeight - bottomBarHeight - handleHeight;

    // Initialize to middle on first build
    if (!_scrollHandleInitialized) {
      _scrollHandleY = (minY + maxY) / 2;
      _scrollHandleInitialized = true;
    }

    return Positioned(
      right: 8,
      top: _scrollHandleY,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            _scrollHandleY += details.delta.dy;
            _scrollHandleY = _scrollHandleY.clamp(minY, maxY);
          });

          // Calculate which page to go to based on handle position
          // Map handle Y position (minY..maxY) → page (1.._totalPages)
          if (_totalPages > 1) {
            final ratio = (_scrollHandleY - minY) / (maxY - minY);
            final targetPage = (ratio * (_totalPages - 1) + 1).round()
                .clamp(1, _totalPages);
            final currentPage = _pdfrxController.pageNumber ?? _currentPage;
            if (targetPage != currentPage) {
              _pdfrxController.goToPage(
                pageNumber: targetPage,
                duration: const Duration(milliseconds: 150),
              );
            }
          }
        },
        child: Container(
          width: 36,
          height: handleHeight,
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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
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
                  iconSize: isLandscape ? 20 : 24,
                  padding: isLandscape
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.all(8),
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
                    _setReadingMode(next);
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


/// Small directional button that keeps panning while held down.
class _PanButton extends StatefulWidget {
  const _PanButton({
    required this.icon,
    required this.tooltip,
    required this.onPan,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPan;

  @override
  State<_PanButton> createState() => _PanButtonState();
}

class _PanButtonState extends State<_PanButton> {
  Timer? _repeatTimer;

  void _startPanning() {
    widget.onPan();
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(
      const Duration(milliseconds: 140),
      (_) => widget.onPan(),
    );
  }

  void _stopPanning() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopPanning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      triggerMode: TooltipTriggerMode.manual,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _startPanning(),
        onTapUp: (_) => _stopPanning(),
        onTapCancel: _stopPanning,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(widget.icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
