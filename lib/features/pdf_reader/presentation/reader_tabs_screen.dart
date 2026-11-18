import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/reader_tabs.dart';
import 'reader_screen.dart';

/// Hosts the reader with a tab strip so several books can stay open at once.
///
/// The book passed in by the route is registered as a tab. Other previously
/// opened books remain available in the strip, and new books can be added
/// without leaving the reader.
class ReaderTabsScreen extends ConsumerStatefulWidget {
  const ReaderTabsScreen({
    super.key,
    required this.bookId,
    this.pageNumber,
  });

  final int bookId;
  final int? pageNumber;

  @override
  ConsumerState<ReaderTabsScreen> createState() => _ReaderTabsScreenState();
}

class _ReaderTabsScreenState extends ConsumerState<ReaderTabsScreen> {
  /// Tabs whose PDF viewer has been created. Tabs are mounted lazily so that
  /// restoring seven open books does not load seven documents at once.
  final Set<int> _mountedBookIds = <int>{};

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Keep screen awake while reading
    _mountedBookIds.add(widget.bookId);
    ref
        .read(readerTabsProvider.notifier)
        .open(widget.bookId, initialPage: widget.pageNumber);
  }

  @override
  void dispose() {
    WakelockPlus.disable(); // Allow the screen to sleep again
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReaderTabsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId) {
      _mountedBookIds.add(widget.bookId);
      ref
          .read(readerTabsProvider.notifier)
          .open(widget.bookId, initialPage: widget.pageNumber);
    }
  }

  Future<void> _openBookPicker() async {
    final openIds =
        ref.read(readerTabsProvider).tabs.map((tab) => tab.bookId).toSet();
    final books = await ref.read(booksDaoProvider).getAllBooks();
    if (!mounted) return;

    final available =
        books.where((book) => !openIds.contains(book.id)).toList();

    final selectedId = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.65,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Open a book',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${openIds.length}/${ReaderTabsNotifier.maxTabs} open',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: available.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
                          child: Text(
                            'All books in your library are already open in tabs.',
                            style: TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: available.length,
                          itemBuilder: (context, index) {
                            final book = available[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.auto_stories_rounded,
                                color: Colors.white70,
                              ),
                              title: Text(
                                book.title,
                                style: const TextStyle(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'Grade ${book.grade}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(book.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedId == null || !mounted) return;

    ref.read(readerTabsProvider.notifier).open(selectedId);
    await ref.read(booksDaoProvider).updateLastOpened(selectedId);
  }

  void _closeTab(int index) {
    final tabs = ref.read(readerTabsProvider);
    final closing = tabs.tabs[index];
    final wasLast = tabs.tabs.length == 1;

    ref.read(readerTabsProvider.notifier).close(index);
    _mountedBookIds.remove(closing.bookId);

    if (wasLast && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tabsState = ref.watch(readerTabsProvider);
    final booksAsync = ref.watch(allBooksProvider);

    final activeTab = tabsState.activeTab;
    if (activeTab == null) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    _mountedBookIds.add(activeTab.bookId);

    final mountedTabs = tabsState.tabs
        .where((tab) => _mountedBookIds.contains(tab.bookId))
        .toList();
    var activeChildIndex =
        mountedTabs.indexWhere((tab) => tab.bookId == activeTab.bookId);
    if (activeChildIndex < 0) activeChildIndex = 0;

    final bookTitles = <int, String>{
      for (final book in booksAsync.valueOrNull ?? const <Book>[])
        book.id: book.title,
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _ReaderTabStrip(
            tabsState: tabsState,
            bookTitles: bookTitles,
            onSelect: (index) {
              ref.read(readerTabsProvider.notifier).select(index);
            },
            onClose: _closeTab,
            onAdd: _openBookPicker,
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: IndexedStack(
                index: activeChildIndex,
                children: [
                  for (final tab in mountedTabs)
                    ReaderScreen(
                      key: ValueKey('reader_tab_${tab.bookId}'),
                      bookId: tab.bookId,
                      pageNumber: tab.initialPage,
                      showResumePrompt: false,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The horizontal strip of open book tabs.
class _ReaderTabStrip extends ConsumerStatefulWidget {
  const _ReaderTabStrip({
    required this.tabsState,
    required this.bookTitles,
    required this.onSelect,
    required this.onClose,
    required this.onAdd,
  });

  final ReaderTabsState tabsState;
  final Map<int, String> bookTitles;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;
  final VoidCallback onAdd;

  @override
  ConsumerState<_ReaderTabStrip> createState() => _ReaderTabStripState();
}

class _ReaderTabStripState extends ConsumerState<_ReaderTabStrip> {
  final Map<int, GlobalKey> _tabKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _scheduleReveal();
  }

  @override
  void didUpdateWidget(covariant _ReaderTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabsState.activeIndex != widget.tabsState.activeIndex ||
        oldWidget.tabsState.tabs.length != widget.tabsState.tabs.length) {
      _scheduleReveal();
    }
  }

  void _scheduleReveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealActiveTab());
  }

  void _revealActiveTab() {
    if (!mounted) return;
    final tab = widget.tabsState.activeTab;
    if (tab == null) return;

    final tabContext = _tabKeys[tab.bookId]?.currentContext;
    if (tabContext == null) return;

    Scrollable.ensureVisible(
      tabContext,
      duration: const Duration(milliseconds: 200),
      alignment: 0.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabsState = widget.tabsState;
    final progressAsync = ref.watch(allReadingProgressProvider);
    final pages = <int, int>{
      for (final progress in progressAsync.valueOrNull ??
          const <ReadingProgressEntry>[])
        progress.bookId: progress.currentPage,
    };

    return Material(
      color: const Color(0xFF111111),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  itemCount: tabsState.tabs.length,
                  itemBuilder: (context, index) {
                    final tab = tabsState.tabs[index];
                    final active = index == tabsState.activeIndex;
                    final title = widget.bookTitles[tab.bookId] ?? 'Book';
                    final page = pages[tab.bookId] ?? tab.initialPage;

                    return Padding(
                      key: _tabKeys.putIfAbsent(
                        tab.bookId,
                        () => GlobalKey(),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 6,
                      ),
                      child: Material(
                        color: active
                            ? Colors.white.withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => widget.onSelect(index),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 190),
                            padding: const EdgeInsets.only(left: 10, right: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 14,
                                  color: active
                                      ? Colors.white
                                      : Colors.white54,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: active
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: active
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (page != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    'p.$page',
                                    style: TextStyle(
                                      color: active
                                          ? Colors.amber
                                          : Colors.white38,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => widget.onClose(index),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: active
                                          ? Colors.white70
                                          : Colors.white38,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Text(
                '${tabsState.tabs.length}/${ReaderTabsNotifier.maxTabs}',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: 'Open another book',
                onPressed: widget.onAdd,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
