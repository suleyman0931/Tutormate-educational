# TutorMate – Design Specification

## 1. Overview

TutorMate is an Android-only, offline-first educational PDF library and advanced reading assistant built with Flutter. This document covers architecture, technology choices, database design, feature designs, UI/UX, and key technical decisions. It fulfills the requirements in `requirements.md`.

## 2. Technology Stack

| Component | Technology | Notes |
|---|---|---|
| Framework | Flutter | Android-only target |
| Language | Dart | |
| State Management | Riverpod (`flutter_riverpod` / `riverpod_annotation`) | |
| Local Database | Drift + SQLite (`drift`, `drift_flutter`, `sqlite3_flutter_libs`) | |
| Navigation | GoRouter (`go_router`) | |
| PDF Rendering | `paxon`/`pdfx` or `syncfusion_flutter_pdfviewer` (TBD during Phase 3) | Must support rendering, text search, text selection, and overlay. See §3 PDF rendering decision. |
| File Import | `file_picker` | Android Storage Access Framework compatible |
| Local Storage | `path_provider` (application documents directory) | |
| Preferences | `shared_preferences` | |
| UI | Material Design 3 (`flutter` Material 3) | |
| Security | `local_auth` | PIN lock and biometric |
| Archive (Backup) | `archive` | Portable backup archive creation/extraction |
| Image picker/cover | PDF render to image | Generate cover from first page |

### Package compatibility note

Before installing the PDF viewer, verify the latest compatible version against the chosen Flutter/Dart SDK and Android minSdk. The annotation overlay strategy (§3) depends on the viewer's ability to expose page size and scroll/zoom transforms. If a viewer lacks the needed hooks, fall back to a viewer that does, or wrap the viewer with a custom overlay controller.

## 3. Key Technical Decisions

### 3.1 Architecture: Feature-based Clean Architecture

```
lib/
  main.dart
  app/
    app.dart              # MaterialApp.router + ProviderScope
    router.dart           # GoRouter config (shell route w/ bottom nav)
    theme/
      app_theme.dart      # Material 3 light/dark themes + color scheme
      app_colors.dart
    constants/
      app_constants.dart
  core/
    database/
      database.dart        # Drift database definition
      tables/
        books.dart
        subjects.dart
        reading_progress.dart
        bookmarks.dart
        notes.dart
        annotations.dart
      daos/
        books_dao.dart
        subjects_dao.dart
        progress_dao.dart
        bookmarks_dao.dart
        notes_dao.dart
        annotations_dao.dart
      database_provider.dart
    storage/
      pdf_storage_service.dart   # copy/import/manage PDF files on disk
      cover_storage_service.dart # generate & store cover images
    services/
      backup_service.dart
      restore_service.dart
      security_service.dart
      pdf_export_service.dart
    utils/
      coordinate_utils.dart  # normalized coordinate transforms
      file_utils.dart
      validators.dart
      date_utils.dart
    widgets/                # shared reusable widgets
      book_card.dart
      empty_state.dart
      loading_indicator.dart
      error_widget.dart
      stat_card.dart
      confirm_dialog.dart
      section_header.dart
  features/
    dashboard/
      data/
      domain/
      presentation/
    library/
      data/
      domain/
      presentation/
    pdf_reader/
      data/
      domain/
      presentation/
    annotations/
      data/
      domain/
      presentation/
    notes/
      data/
      domain/
      presentation/
    bookmarks/
      data/
      domain/
      presentation/
    subjects/
      data/
      domain/
      presentation/
    settings/
      data/
      domain/
      presentation/
    security/
      presentation/
```

Each feature is organized into `data` (repositories, data sources, models/DTOs), `domain` (entities, repository interfaces, use cases), and `presentation` (screens, widgets, controllers/providers). Features remain independent and reusable.

### 3.2 PDF rendering and annotation overlay strategy

The annotation system is the highest-risk feature. The strategy:

1. Render PDF pages in a viewer that exposes the current page's rendered size and the active zoom/scale and scroll offset (transform).
2. Overlay a transparent `CustomPaint` / `GestureDetector` layer above each page that draws annotations and captures freehand input.
3. **Persist annotations in normalized coordinates** — coordinates stored as fractions of the PDF page's native size (0.0–1.0), independent of display scale or orientation. On render, multiply normalized coordinates by the current rendered page size to position overlays. This guarantees correct placement across zoom, scroll, orientation change, and reopen.
4. Text-based annotations (highlight/underline/strikethrough) store the target text range and normalized rect; drawing annotations store a list of normalized points + stroke width.
5. The original PDF file is never modified. Annotated export renders a new PDF with annotations baked in via a PDF writer library.

Because annotation correctness is critical, coordinate transforms are unit-tested independently (see tasks.md Phase 7).

### 3.3 Reading progress persistence

- Save periodically (every N pages or time interval), on page change, on reader close, and on app background (via lifecycle observer / WidgetsBindingObserver).
- Store `current_page`, `progress_percentage = current_page / total_pages`, `last_read_at`.
- On open, read progress and jump to `current_page`. This survives unexpected shutdown because progress is written on each page change, not only on graceful close.

### 3.4 File storage strategy

- Imported PDFs are copied from the picked URI into the app documents directory (`<docs>/pdfs/<book_id>.pdf`).
- Cover images are rendered from the first page and stored as `JPEG/PNG` at `<docs>/covers/<book_id>.jpg`.
- Backups include the PDF files from disk plus database exports.
- Never store large PDF binaries in SQLite; store file paths only.

### 3.5 Backup archive format

- A single `.zip` (or `.tutormate`) archive containing:
  - `tutormate.db` (exported SQLite database, or a JSON dump of all tables).
  - `pdfs/` directory with all PDF files keyed by book id.
  - `covers/` directory with cover images.
  - `manifest.json` with schema version, app version, timestamps, and integrity checksums (per-file hash).
- On restore: validate manifest checksums, check schema version compatibility, then either replace or merge data (user-confirmed).

### 3.6 Duplicate import detection

- Compute a hash (e.g., SHA-256) of the imported file's content (or size + first/last chunks for large files) and compare against stored hashes of existing books. Warn the user if a match is found. Store file hash on the `books` table (added column) for this purpose.

## 4. Database Design (Drift/SQLite)

### 4.1 Tables

#### books
| Column | Type | Constraints |
|---|---|---|
| id | INTEGER | PK, autoincrement |
| title | TEXT | NOT NULL |
| category | TEXT | NOT NULL (enum: student_book, teacher_guide, short_note, other) |
| grade | INTEGER | NOT NULL (1–5) |
| subject_id | INTEGER | FK → subjects.id, NOT NULL |
| description | TEXT | nullable |
| author | TEXT | nullable |
| publisher | TEXT | nullable |
| academic_year | TEXT | nullable |
| file_path | TEXT | NOT NULL |
| cover_path | TEXT | nullable |
| total_pages | INTEGER | NOT NULL |
| file_hash | TEXT | nullable (for duplicate detection) |
| created_at | INTEGER | NOT NULL (Unix ms) |
| updated_at | INTEGER | NOT NULL |
| last_opened_at | INTEGER | nullable |

Indexes: `idx_books_subject_id` on `subject_id`; `idx_books_grade` on `grade`; `idx_books_category` on `category`; `idx_books_created_at` on `created_at`; `idx_books_last_opened_at` on `last_opened_at`.

#### subjects
| Column | Type | Constraints |
|---|---|---|
| id | INTEGER | PK, autoincrement |
| name | TEXT | NOT NULL, UNIQUE |
| created_at | INTEGER | NOT NULL |

Seed with: Mathematics, English, Amharic, Afaan Oromo, Science, Social Studies, Civics, Other.

#### reading_progress
| Column | Type | Constraints |
|---|---|---|
| id | INTEGER | PK, autoincrement |
| book_id | INTEGER | FK → books.id, UNIQUE (one progress row per book) |
| current_page | INTEGER | NOT NULL |
| progress_percentage | REAL | NOT NULL |
| last_read_at | INTEGER | NOT NULL |

Index: `idx_progress_book_id` on `book_id`.

#### bookmarks
| Column | Type | Constraints |
|---|---|---|
| id | INTEGER | PK, autoincrement |
| book_id | INTEGER | FK → books.id |
| page_number | INTEGER | NOT NULL |
| title | TEXT | NOT NULL |
| description | TEXT | nullable |
| created_at | INTEGER | NOT NULL |

Index: `idx_bookmarks_book_id` on `book_id`. Unique constraint on `(book_id, page_number)` is **not** enforced (multiple bookmarks per page allowed? Spec says multiple bookmarks per book; allow multiple per page but could enforce unique per page — design choice: allow duplicates is unnecessary; enforce unique `(book_id, page_number)` to avoid accidental duplicates, but allow editing title/description). Decision: unique on `(book_id, page_number)`.

#### notes
| Column | Type | Constraints |
|---|---|---|
| id | INTEGER | PK, autoincrement |
| book_id | INTEGER | FK → books.id, nullable, ON DELETE SET NULL |
| page_number | INTEGER | nullable |
| title | TEXT | NOT NULL |
| content | TEXT | NOT NULL |
| subject_id | INTEGER | FK → subjects.id, nullable |
| grade | INTEGER | nullable |
| created_at | INTEGER | NOT NULL |
| updated_at | INTEGER | NOT NULL |

Index: `idx_notes_book_id`, `idx_notes_subject_id`, `idx_notes_grade`, `idx_notes_created_at`.

#### annotations
| Column | Type | Constraints |
|---|---|---|
| id | INTEGER | PK, autoincrement |
| book_id | INTEGER | FK → books.id, ON DELETE CASCADE |
| page_number | INTEGER | NOT NULL |
| annotation_type | TEXT | NOT NULL (highlight, underline, strikethrough, text, drawing) |
| annotation_data | TEXT | NOT NULL (JSON: normalized rect or points) |
| color | INTEGER | NOT NULL (ARGB int) |
| created_at | INTEGER | NOT NULL |
| updated_at | INTEGER | NOT NULL |

Index: `idx_annotations_book_page` on `(book_id, page_number)`.

### 4.2 Referential integrity & migrations

- Enable foreign keys (`PRAGMA foreign_keys = ON`) at database open.
- `notes.book_id` ON DELETE SET NULL (keep independent notes if book deleted).
- `annotations.book_id`, `bookmarks.book_id`, `reading_progress.book_id` ON DELETE CASCADE (remove with book).
- Use Drift migrations (`MigrationStrategy` with `onCreate` seeding subjects and `onUpgrade` steps). Schema versioning supports reliable future migrations.
- Use transactions for multi-record operations (e.g., deleting a book and cascading its data; backup/restore).

### 4.3 Enums

- `BookCategory`: `studentBook`, `teacherGuide`, `shortNote`, `other` (stored as TEXT).
- `AnnotationType`: `highlight`, `underline`, `strikethrough`, `text`, `drawing` (stored as TEXT).

## 5. Feature Designs

### 5.1 Navigation (GoRouter)

- Shell route with a `Scaffold` containing an `IndexedStack` + `NavigationBar` (bottom nav) with 4 destinations: Home, Library, My Notes, Settings.
- Nested routes:
  - `/` (home dashboard)
  - `/library` (library grid/list with filters)
  - `/notes` (my notes)
  - `/settings` (settings)
  - `/library/book/:id` (book details)
  - `/library/import` (import form)
  - `/reader/:bookId` (PDF reader)
  - `/bookmarks` (dedicated bookmarks screen)
  - `/subjects` (subject management)
- Reader route is a full-screen route outside the shell (no bottom nav).

### 5.2 Home Dashboard

- Statistics row: 6 stat cards (total books, per-category counts, total bookmarks).
- Continue Reading card: cover image, title, grade chip, subject chip, "page X / Y", progress bar, percentage. Tap → reader at saved page.
- Recently Opened: horizontal scroll of book cards sorted by `last_opened_at`.
- Quick Actions grid: Import PDF, Browse Library, My Notes, Bookmarks.

### 5.3 Library

- Filter bar: grade dropdown, category dropdown, subject dropdown, search field, sort dropdown.
- Book grid/list of cards (cover, title, grade, subject, category badge).
- Long-press or overflow menu: edit, replace PDF, delete (with confirm dialog explaining cascading deletion), view details.
- Import flow: file picker (single/multiple) → for each PDF, render first page as cover, prefill title from filename, show metadata form (required: title, category, grade, subject; optional: description, author, publisher, academic year) → copy file to app storage, compute hash, check duplicates → insert book row.
- Empty state illustration when no books match filters.

### 5.4 PDF Reader

- Full-screen reader with auto-hiding toolbar.
- Toolbar: back, book info, bookmark toggle, search, notes, annotation tools, reading settings.
- Modes: continuous scroll and single page (toggle in settings).
- Zoom (pinch), page nav (swipe / buttons), jump-to-page dialog, thumbnails strip (toggle).
- In-PDF search: search bar overlay highlighting matches; tap match to jump.
- Progress auto-save on page change, periodic timer, and lifecycle observer (background/close).
- Orientation support via `OrientationBuilder`.
- Annotation overlay (§3.2) toggled by annotation tools button.

### 5.5 Annotations

- Annotation tools palette: highlight, underline, strikethrough, text, draw, eraser, color picker, undo, redo.
- Highlight/underline/strikethrough: text selection-based; user selects text, picks tool → stores normalized rect + text range + color.
- Text annotation: tap location → text input bubble stored at normalized point.
- Drawing/freehand: pointer events captured as normalized points list + stroke width + color.
- Eraser: hit-test annotations by point; delete tapped annotation.
- Undo/redo: maintain an in-session action stack; persist to DB on change.
- Persistence: load annotations for `(book_id, page)` and render overlay; save on annotation add/edit/delete.
- Export annotated PDF: render pages and draw annotations at normalized → pixel mapping into a new PDF via a PDF writer; save to app storage and offer share/save.

### 5.6 Bookmarks

- Add bookmark from reader toolbar (captures current page) → edit title/description.
- Bookmarks list per book and a global Bookmarks screen (all books) with book title + page chips; tap to open reader at that page.
- Edit/delete bookmarks.

### 5.7 Notes

- Notes list (dashboard) with title, content preview, book title, page, grade, subject, created date.
- Create note: optional link to book/page (launched from reader for page-linked notes), subject, grade.
- Independent notes created from My Notes quick action.
- Search and filter (grade, subject, book, date).
- Tap page-linked note → reader at that page.

### 5.8 Reading Customization

- Settings: theme (light/dark/system), default zoom, reading mode (single/continuous), show page numbers toggle, distraction-free mode toggle, configurable toolbar.
- Persist in SharedPreferences.

### 5.9 Settings

- Theme, reading customization, backup, restore, security (PIN/biometric/auto-lock), about.
- Backup: choose destination, generate archive, show progress.
- Restore: pick archive, validate integrity, confirm replace/merge, restore.

### 5.10 Security

- On launch (if enabled): show lock screen with PIN keypad and/or biometric prompt via `local_auth`.
- Auto-lock: timer reset on activity; lock when exceeded (configurable period).
- PIN stored hashed (not plaintext) in SharedPreferences or a secure store.

## 6. State Management (Riverpod)

- Providers per feature:
  - `booksProvider` (stream/watch books), `bookProvider(id)`, `filteredBooksProvider(filters)`, `libraryStatsProvider`.
  - `subjectsProvider`, `notesProvider`, `filteredNotesProvider`, `bookmarksProvider`, `bookBookmarksProvider(id)`.
  - `progressProvider(bookId)`, `annotationsProvider(bookId, page)`, `readerControllerProvider`.
  - `themeProvider`, `readingSettingsProvider`, `securitySettingsProvider`, `backupStateProvider`.
- DAOs injected as Riverpod providers wrapping Drift.
- Async providers return `AsyncValue` for loading/error handling.

## 7. UI/UX Design

### 7.1 Color palette (Material 3 ColorScheme)

- Primary: Deep Navy Blue (`#1A237E` / seed).
- Secondary: Teal (`#00897B`).
- Accent/Tertiary: Soft Orange (`#FF8A65`).
- Light background: white / very light gray (`#F5F5F5`).
- Dark background: deep charcoal (`#121212` / `#1E1E1E`).
- Surface, onSurface, etc. derived by Material 3 from seed.

### 7.2 Design language

- Rounded corners (12–16dp), consistent spacing scale (4/8/12/16/24).
- Attractive book cards with cover image and category badge.
- Clean typography (Material 3 type scale).
- Beautiful empty states with illustration + message + CTA.
- Subtle animations (page transitions, hero animations for book covers).
- Professional loading indicators (circular/spinners), skeleton loaders for grids.
- Clear, friendly error messages with retry.
- Accessible touch targets ≥ 48dp.
- Responsive: grid columns adapt to width (phone vs tablet).

### 7.3 Themes

- `lightTheme` and `darkTheme` from the navy seed via `ColorScheme.fromSeed`.
- System theme follows platform setting.

## 8. Performance & Reliability Measures

- Lazy/incremental PDF page rendering; avoid loading entire PDF into memory.
- Page thumbnail caching (LRU) and cover caching.
- Database indexes on filter/sort columns.
- Background isolate for heavy work (hashing, archive) where feasible (using `compute` or Drift isolate).
- Pagination/limit on large queries.
- Debounced search input.
- Image caching for covers.
- Corrupted/encrypted PDF detection with clear messaging.
- Missing-file detection (check `file_path` exists before opening reader).

## 9. Error Handling

- Centralized error display via `AsyncValue` patterns and a reusable error widget.
- File operations wrapped in try/catch with user-friendly messages.
- Database errors surface as snackbar/dialog with retry where applicable.

## 10. Security Considerations

- PIN hashed (e.g., SHA-256 with salt) — never stored plaintext.
- Biometric via `local_auth`; biometric unlock does not replace PIN as fallback.
- Backup archive may contain sensitive notes; documented as user's responsibility (local file).
- No network/telemetry; fully offline.

## 11. Testing Strategy

- Unit tests: DAOs (Drift in-memory), coordinate transforms, backup manifest validation, duplicate detection hashing, validators.
- Widget tests: dashboard, library filters, import form, reader toolbar, annotation overlay, notes list, bookmarks, settings.
- Integration tests: import → read → annotate → persist across restart → export; backup → restore on fresh DB.
- See tasks.md Phase 7.

## 12. Open Questions / TBD

1. Final PDF viewer package selection — to be confirmed in Phase 3 based on whether the chosen package exposes page size/zoom transforms needed for the annotation overlay. Preferred candidates will be evaluated for compatibility first.
2. Backup archive extension (`.tutormate` vs `.zip`) — minor; will use `.tutormate` zip for branding.
3. Whether to enforce unique `(book_id, page_number)` for bookmarks — decided: enforce unique to prevent accidental duplicate bookmarks; user can edit existing bookmark on a page.
