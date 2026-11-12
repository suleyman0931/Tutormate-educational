# TutorMate – Implementation Tasks

Tasks are grouped into the 7 development phases from the spec. Each phase ends with `flutter analyze`, fixing errors, and updating this file's status.

Status legend: `[ ]` not started · `[~]` in progress · `[x]` completed

---

## Phase 1 – Foundation

- [x] 1.1 Initialize Flutter Android-only project (`flutter create --platforms=android tutormate`) and verify Android-only config (no iOS folders/config).
- [x] 1.2 Configure `pubspec.yaml` dependencies: flutter_riverpod, go_router, drift, drift_flutter, sqlite3_flutter_libs, path_provider, file_picker, shared_preferences, local_auth, archive, and a PDF viewer package (chosen/verified in Phase 3). Pin exact versions after verifying compatibility.
- [x] 1.3 Set up `app/theme/` with Material 3 light/dark themes from Deep Navy Blue seed, Teal secondary, Soft Orange accent. Create `app_colors.dart` and `app_theme.dart`.
- [x] 1.4 Set up Riverpod (`ProviderScope` in `main.dart` / `app.dart`).
- [x] 1.5 Set up GoRouter in `app/router.dart` with shell route + bottom navigation (Home, Library, My Notes, Settings) and nested/full-screen routes per design §5.1.
- [x] 1.6 Set up Drift database in `core/database/` with all 6 tables (`books`, `subjects`, `reading_progress`, `bookmarks`, `notes`, `annotations`), enums, foreign keys, indexes, unique constraints, `PRAGMA foreign_keys = ON`, migration strategy with subject seeding on create.
- [x] 1.7 Create DAOs for each table in `core/database/daos/` with CRUD + query methods; expose as Riverpod providers.
- [x] 1.8 Implement `core/storage/pdf_storage_service.dart` (copy imported PDF to app docs dir keyed by book id) and `core/storage/cover_storage_service.dart` (render first page → save cover image).
- [x] 1.9 Create shared `core/widgets/`: book_card, empty_state, loading_indicator, error_widget, stat_card, confirm_dialog, section_header.
- [x] 1.10 Create placeholder screen widgets for Home, Library, My Notes, Settings wired into the router shell so navigation works end-to-end.
- [x] 1.11 Run `flutter analyze`; fix all errors. Confirm app builds and bottom navigation works on an Android emulator/device.

## Phase 2 – PDF Library

- [x] 2.1 Implement PDF import flow: file_picker (single + multiple selection) → copy file to app storage via `PdfStorageService` → compute file hash → generate cover from first page via `CoverStorageService`.
- [x] 2.2 Implement import metadata form (required: title, category, grade, subject; optional: description, author, publisher, academic year) with auto-detected filename suggestion and cover preview.
- [x] 2.3 Implement duplicate import detection (compare hash against stored `books.file_hash`) with a user warning/confirmation.
- [x] 2.4 Implement book repository + providers (watch all books, book by id, create/update/delete).
- [x] 2.5 Implement subject management (seed common subjects; add/edit/delete custom subjects) in `features/subjects`.
- [x] 2.6 Implement Library screen: book grid/list with cards (cover, title, grade, subject, category badge) and book details screen.
- [x] 2.7 Implement combined filters: grade, category, subject dropdowns + search field (title/subject/category/author/description) + sort (Recently Added, Recently Opened, A–Z, Z–A, Most Read). Allow simultaneous filters.
- [x] 2.8 Implement book edit, replace PDF, and delete (with confirmation dialog explaining cascading deletion of notes/bookmarks/annotations/progress).
- [x] 2.9 Implement empty state when no books match filters.
- [x] 2.10 Run `flutter analyze`; fix errors. Test import (single + multiple), metadata, duplicate detection, edit, replace, delete, and filtering/sorting.

## Phase 3 – PDF Reader

- [x] 3.1 Select and integrate the compatible PDF viewer package (verify it exposes page size + zoom/scroll transforms needed for annotation overlay).
- [x] 3.2 Implement reader screen rendering PDF smoothly with continuous-scroll and single-page modes (toggle from reading settings).
- [x] 3.3 Implement zoom (pinch), page navigation (swipe/buttons), jump-to-page dialog, and page-number display.
- [x] 3.4 Implement page thumbnails strip (toggle) for quick navigation.
- [x] 3.5 Implement in-PDF text search overlay with match navigation and text selection where supported.
- [x] 3.6 Implement portrait/landscape support via `OrientationBuilder`.
- [x] 3.7 Implement automatic reading progress: save `current_page`, `progress_percentage`, `last_read_at` on page change + periodic timer + lifecycle observer (background/close); restore position on open.
- [x] 3.8 Implement reader toolbar (back, book info, bookmark toggle, search, notes, annotation tools entry, reading settings) with auto-hide.
- [x] 3.9 Implement missing-file detection and corrupted/encrypted PDF handling with clear messages.
- [x] 3.10 Run `flutter analyze`; fix errors. Test reading, navigation, zoom, thumbnails, search, and progress persistence across restarts.

## Phase 4 – Notes and Annotations

- [ ] 4.1 Implement annotation overlay layer above PDF pages with normalized coordinate transforms (`core/utils/coordinate_utils.dart`).
- [ ] 4.2 Implement highlight, underline, strikethrough tools (text-selection-based; store normalized rect + text + color).
- [ ] 4.3 Implement text annotation tool (tap location → input bubble; store normalized point + text + color).
- [ ] 4.4 Implement freehand drawing/handwriting (finger/stylus) tool (normalized points list + stroke width + color).
- [ ] 4.5 Implement eraser (hit-test delete) and annotation color picker.
- [ ] 4.6 Implement undo/redo with an in-session action stack.
- [ ] 4.7 Implement annotation persistence: load by `(book_id, page)` and render; save on add/edit/delete with `created_at`/`updated_at`. Verify correct positioning across zoom/scroll/orientation/reopen.
- [ ] 4.8 Implement page-linked notes (create from reader at current page with book/page/subject/grade) and independent notes (from My Notes).
- [ ] 4.9 Implement My Notes screen: list (title, content preview, book, page, grade, subject, created date), create/edit/delete, search, filter (grade/subject/book/date), and tap page-linked note → open reader at page.
- [ ] 4.10 Implement export of annotated PDF copy (render annotations into a new PDF; original unchanged) via `core/services/pdf_export_service.dart`.
- [ ] 4.11 Run `flutter analyze`; fix errors. Test annotations persist and stay positioned across zoom/scroll/orientation/reopen; test notes CRUD/filter and annotated export.

## Phase 5 – Dashboard and Settings

- [x] 5.1 Implement Home dashboard statistics (total books, student books, teacher guides, short notes, other books, total bookmarks).
- [x] 5.2 Implement Continue Reading card (last opened book: cover, title, grade, subject, current/total page, progress %) with tap-to-resume at saved position.
- [x] 5.3 Implement Recently Opened horizontal cards.
- [x] 5.4 Implement Quick Actions (Import PDF, Browse Library, My Notes, Bookmarks).
- [x] 5.5 Implement reading customization settings: theme (light/dark/system), default zoom, single/continuous mode, show page numbers, distraction-free mode, configurable toolbar (persist via SharedPreferences).
- [x] 5.6 Wire theme and reading settings to the reader and app.
- [x] 5.7 Run `flutter analyze`; fix errors. Test dashboard stats, continue-reading resume, recently opened, and reading customization persistence.

## Phase 6 – Backup and Security

- [ ] 6.1 Implement backup service: export DB (books/progress/bookmarks/notes/annotations/subjects), PDF files, covers, preferences into a `.tutormate` zip archive with `manifest.json` (schema version, app version, per-file checksums).
- [ ] 6.2 Implement restore service: pick archive, validate integrity (checksums + schema version), confirm replace vs merge, restore files + DB.
- [ ] 6.3 Implement backup/restore UI in Settings with progress indicators.
- [ ] 6.4 Implement security: PIN lock setup/change (hashed with salt, stored securely), biometric auth via `local_auth`, auto-lock after configurable period.
- [ ] 6.5 Implement lock screen shown on launch (when enabled) and on auto-lock timeout; biometric fallback to PIN.
- [ ] 6.6 Run `flutter analyze`; fix errors. Test backup → restore on a fresh install, integrity validation, PIN/biometric lock, and auto-lock.

## Phase 7 – Testing and Release

- [ ] 7.1 Unit tests: Drift DAOs (in-memory DB), coordinate transforms, backup manifest validation, duplicate-detection hashing, validators, PIN hashing.
- [ ] 7.2 Widget tests: dashboard, library filters/sort, import form, reader toolbar, annotation overlay, notes list, bookmarks, settings.
- [ ] 7.3 Integration tests: import → read → annotate → persist across restart → export; backup → restore on fresh DB.
- [ ] 7.4 Offline test: disable network and run full flows.
- [ ] 7.5 Android device test (low-end if available): large PDF rendering, memory, restart-after-reboot.
- [ ] 7.6 Write README with setup, build, and run instructions.
- [ ] 7.7 Build release APK (`flutter build apk --release`). Optionally build AAB (`flutter build appbundle --release`).
- [ ] 7.8 Final verification against all 15 acceptance criteria from requirements.md §7.

---

## Definition of Done (per phase)

- All phase tasks completed and checked off above.
- `flutter analyze` passes with no errors.
- Phase behavior tested on an Android emulator/device.
- This file updated with status; a short summary of what was implemented and tested is reported to the user.

## Notes

- Do not implement anything outside the defined scope (see requirements.md §3 Out of Scope) without proposing it first and getting approval.
- Prioritize, in order: PDF reading, automatic reading progress, annotations, bookmarks, page-linked notes.
- Real functional features only — no fake buttons or TODO placeholders for important features.
