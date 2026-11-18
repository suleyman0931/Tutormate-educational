import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single book open inside the reader.
class ReaderTab {
  final int bookId;

  /// Page to open when the tab is first displayed. When null, the saved
  /// reading progress is used instead.
  final int? initialPage;

  const ReaderTab({required this.bookId, this.initialPage});
}

/// State for all open reader tabs.
class ReaderTabsState {
  final List<ReaderTab> tabs;
  final int activeIndex;

  const ReaderTabsState({this.tabs = const [], this.activeIndex = 0});

  ReaderTab? get activeTab {
    if (tabs.isEmpty) return null;
    return tabs[activeIndex.clamp(0, tabs.length - 1)];
  }

  bool contains(int bookId) => tabs.any((tab) => tab.bookId == bookId);
}

/// Keeps track of the books currently open in reader tabs.
///
/// Up to [ReaderTabsNotifier.maxTabs] books can stay open at once so the user
/// can switch between them without closing the previous book.
class ReaderTabsNotifier extends Notifier<ReaderTabsState> {
  static const int maxTabs = 7;

  @override
  ReaderTabsState build() => const ReaderTabsState();

  /// Opens [bookId], selecting the tab if it is already open. When the limit
  /// is reached the least recently opened tab is replaced.
  void open(int bookId, {int? initialPage}) {
    final existingIndex =
        state.tabs.indexWhere((tab) => tab.bookId == bookId);
    if (existingIndex >= 0) {
      final tabs = [...state.tabs];
      // Replace the entry so a stale explicit page is cleared and the tab
      // resumes from the saved progress instead.
      tabs[existingIndex] =
          ReaderTab(bookId: bookId, initialPage: initialPage);
      state = ReaderTabsState(tabs: tabs, activeIndex: existingIndex);
      return;
    }

    var tabs = [
      ...state.tabs,
      ReaderTab(bookId: bookId, initialPage: initialPage),
    ];
    if (tabs.length > maxTabs) {
      tabs = tabs.sublist(tabs.length - maxTabs);
    }
    state = ReaderTabsState(tabs: tabs, activeIndex: tabs.length - 1);
  }

  void select(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    if (index == state.activeIndex) return;
    state = ReaderTabsState(tabs: state.tabs, activeIndex: index);
  }

  void close(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    final tabs = [...state.tabs]..removeAt(index);
    if (tabs.isEmpty) {
      state = const ReaderTabsState();
      return;
    }

    var active = state.activeIndex;
    if (index < active) active--;
    if (active >= tabs.length) active = tabs.length - 1;
    if (active < 0) active = 0;
    state = ReaderTabsState(tabs: tabs, activeIndex: active);
  }

  void closeBook(int bookId) {
    final index = state.tabs.indexWhere((tab) => tab.bookId == bookId);
    if (index >= 0) close(index);
  }
}

final readerTabsProvider =
    NotifierProvider<ReaderTabsNotifier, ReaderTabsState>(
  ReaderTabsNotifier.new,
);
