import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/database/app_database.dart';
import '../features/about/presentation/about_screen.dart';
import '../features/ai/presentation/ai_chat_screen.dart';
import '../features/bookmarks/presentation/bookmarks_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/security/presentation/pin_setup_screen.dart';
import '../features/security/presentation/security_settings_screen.dart';
import '../features/settings/presentation/backup_screen.dart';
import '../features/library/presentation/book_details_screen.dart';
import '../features/library/presentation/book_edit_screen.dart';
import '../features/library/presentation/import_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/notes/presentation/note_edit_screen.dart';
import '../features/notes/presentation/notes_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/subjects/presentation/subjects_screen.dart';
import '../features/pdf_reader/presentation/reader_screen.dart';

/// Application routes, used for navigation and deep linking.
class AppRoutes {
  AppRoutes._();

  static const home = '/';
  static const library = '/library';
  static const ai = '/ai';
  static const notes = '/notes';
  static const settings = '/settings';
  static const about = '/about';
  static const bookDetails = '/library/book';
  static const import = '/library/import';
  static const reader = '/reader';
  static const bookmarks = '/bookmarks';
  static const subjects = '/subjects';
  static const bookEdit = '/library/edit';
  static const noteEdit = '/notes/edit';
  static const backup = '/settings/backup';
  static const securitySettings = '/settings/security';
  static const pinSetup = '/settings/security/pin-setup';

  static String bookDetailsFor(int id) => '$bookDetails/$id';
  static String readerFor(int bookId) => '$reader/$bookId';
  static String bookEditFor(int id) => '$bookEdit/$id';

  static String aiFor(int bookId, {int? page}) {
    final query = page == null ? '' : '?page=$page';
    return '$ai/book/$bookId$query';
  }
}

/// Arguments for creating a note linked to a specific PDF page.
class NoteCreateArgs {
  final int bookId;
  final int pageNumber;
  final String? bookTitle;
  const NoteCreateArgs(
      {required this.bookId, required this.pageNumber, this.bookTitle});
}

/// The GoRouter configuration.
///
/// Uses a [StatefulShellRoute.indexedStack] for the bottom navigation so that
/// each tab preserves its own state and scroll position.
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    routes: [
      // ── Shell route with bottom navigation ─────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _MainShell(navigationShell: navigationShell);
        },
        branches: [
          // Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          // Library
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          // AI Tutor
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.ai,
                builder: (context, state) => const AiChatScreen(),
              ),
            ],
          ),
          // My Notes
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.notes,
                builder: (context, state) => const NotesScreen(),
              ),
            ],
          ),
          // Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Full-screen routes (outside the bottom-nav shell) ───────────────────
      GoRoute(
        path: '${AppRoutes.bookDetails}/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return BookDetailsScreen(bookId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.import,
        builder: (context, state) {
          final files = state.extra as List<PlatformFile>? ?? [];
          return ImportScreen(files: files);
        },
      ),
      GoRoute(
        path: '/library/edit/:id',
        builder: (context, state) {
          final book = state.extra as Book;
          return BookEditScreen(book: book);
        },
      ),
      GoRoute(
        path: AppRoutes.subjects,
        builder: (context, state) => const SubjectsScreen(),
      ),
      // AI Tutor focused on one book (full-screen, no bottom nav)
      GoRoute(
        path: '${AppRoutes.ai}/book/:bookId',
        builder: (context, state) {
          final bookId = int.tryParse(state.pathParameters['bookId'] ?? '');
          final page = int.tryParse(state.uri.queryParameters['page'] ?? '');
          return AiChatScreen(initialBookId: bookId, initialPage: page);
        },
      ),
      // About / developer information
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const AboutScreen(),
      ),
      // Reader route — full-screen, no bottom nav
      GoRoute(
        path: '${AppRoutes.reader}/:bookId',
        builder: (context, state) {
          final bookId = int.parse(state.pathParameters['bookId']!);
          return ReaderScreen(bookId: bookId);
        },
      ),
      // Note edit/create route
      GoRoute(
        path: AppRoutes.noteEdit,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Note) {
            return NoteEditScreen(existingNote: extra);
          }
          if (extra is NoteCreateArgs) {
            return NoteEditScreen(
              linkedBookId: extra.bookId,
              linkedPageNumber: extra.pageNumber,
              linkedBookTitle: extra.bookTitle,
            );
          }
          return const NoteEditScreen();
        },
      ),
      // Bookmarks screen — global view of all bookmarks
      GoRoute(
        path: AppRoutes.bookmarks,
        builder: (context, state) => const BookmarksScreen(),
      ),
      // Backup & Restore screen
      GoRoute(
        path: AppRoutes.backup,
        builder: (context, state) => const BackupScreen(),
      ),
      // Security settings
      GoRoute(
        path: AppRoutes.securitySettings,
        builder: (context, state) => const SecuritySettingsScreen(),
      ),
      // PIN setup
      GoRoute(
        path: AppRoutes.pinSetup,
        builder: (context, state) => const PinSetupScreen(),
      ),
    ],
  );
}

/// The main shell widget hosting the bottom navigation bar.
class _MainShell extends StatelessWidget {
  const _MainShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded),
            label: 'AI Tutor',
          ),
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined),
            selectedIcon: Icon(Icons.sticky_note_2_rounded),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
