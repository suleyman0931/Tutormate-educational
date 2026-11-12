# TutorMate – Requirements Specification

## 1. Overview

TutorMate is a personal, offline-first educational digital library and advanced PDF reading application for Android, built with Flutter and Dart. It targets educational books for Grades 1–5 and provides a complete offline reading and study environment including organization, reading, annotation, bookmarking, notes, and backup/restore.

TutorMate is **not** a school management tool. It contains no student management, teacher management, lesson scheduling, alarms, reminders, online accounts, or cloud services.

## 2. Goals

- Provide a complete offline educational PDF library and reading assistant.
- Allow users to upload, organize, read, and annotate educational PDF books.
- Support grade (1–5), category, and subject classification.
- Automatically remember and restore the last reading position.
- Enable bookmarks, highlights, underlines, strikethrough, text annotations, and freehand drawing over PDF pages.
- Allow personal notes linked to specific PDF pages or created independently.
- Provide local backup and restore of all application data.
- Remain lightweight and performant on low-end Android devices.

## 3. Scope

### In Scope

- PDF import (single and multiple), storage, and management.
- Book organization by four categories, five grades, and subjects.
- Library search, combined filtering, and sorting.
- Advanced PDF reader with continuous and single-page modes, zoom, navigation, thumbnails, and in-PDF text search.
- Automatic reading progress save and restore.
- Bookmark system (add, edit, delete, jump to page, dedicated bookmarks screen).
- PDF annotation system (highlight, underline, strikethrough, text annotations, freehand drawing, eraser, color, undo/redo) with persistence.
- Export of an annotated PDF copy (original unchanged).
- Personal notes system (page-linked and independent) with search and filtering.
- Reading customization (themes, zoom, modes, page numbers, distraction-free mode).
- Backup and restore (metadata, PDFs, progress, bookmarks, notes, annotations, subjects, preferences).
- Optional security (PIN lock, biometric authentication, auto-lock).
- Light/Dark/System themes with Material Design 3.
- Android-only build target.

### Out of Scope

- Student management.
- Teacher or tutor management.
- Teaching plans.
- Lesson scheduling.
- Alarms.
- Reminders.
- Online accounts or registration.
- Cloud sync or cloud services.
- iOS support or iOS-specific configuration.

## 4. User Stories

### Library Management

- As a user, I can import one or more educational PDFs from Android storage so that I can build my library.
- As a user, I can fill in book metadata (title, category, grade, subject) when importing a PDF.
- As a user, I can optionally add description, author, publisher, and academic year.
- As a user, I can see the PDF filename auto-detected as a suggested title.
- As a user, I can see a cover preview generated from the first page of the PDF.
- As a user, I can edit book information after import.
- As a user, I can replace the PDF file of an existing book.
- As a user, I can delete a book, with a confirmation that explains what happens to its notes, bookmarks, and annotations.
- As a user, I can view full book details.
- As a user, I am warned when importing a duplicate PDF where practical.

### Organization

- As a user, I can classify books into Student Books, Teacher Guides, Short Notes, or Other Books.
- As a user, I can classify books by Grade 1–5.
- As a user, I can assign common subjects (Mathematics, English, Amharic, Afaan Oromo, Science, Social Studies, Civics, Other).
- As a user, I can add, edit, and delete custom subjects.

### Search, Filter, Sort

- As a user, I can search books by title, subject, category, author, or description.
- As a user, I can filter by grade, category, and subject simultaneously.
- As a user, I can sort by Recently Added, Recently Opened, Alphabetical A–Z, Alphabetical Z–A, or Most Read.
- As a user, I see a clear empty state when no books match my filters.

### PDF Reading

- As a user, I can read PDFs with smooth continuous scrolling or single-page mode.
- As a user, I can zoom in and out, navigate pages, and jump to a specific page.
- As a user, I can view page thumbnails for quick navigation.
- As a user, I can search text within a PDF.
- As a user, I can select PDF text where supported.
- As a user, the app supports both portrait and landscape orientation.
- As a user, I can see the current page and total pages.
- As a user, the app automatically saves and restores my reading position, even after an unexpected shutdown.

### Bookmarks

- As a user, I can add, remove, and edit bookmarks with titles and descriptions.
- As a user, I can view all bookmarks and jump directly to a bookmarked page.
- As a user, I can create multiple bookmarks per book.

### Annotations

- As a user, I can highlight, underline, and strikethrough PDF text.
- As a user, I can add text annotations and freehand drawings over pages.
- As a user, I can write with finger or stylus.
- As a user, I can erase annotations and change annotation color.
- As a user, I can undo and redo annotation actions.
- As a user, my annotations persist and stay in the correct position when zooming, scrolling, changing orientation, or reopening the PDF.
- As a user, I can export a separate annotated PDF copy while keeping the original unchanged.

### Notes

- As a user, I can create notes linked to a book and specific page, or independent notes.
- As a user, I can create, view, edit, delete, and search notes.
- As a user, I can filter notes by grade, subject, book, or date.
- As a user, tapping a page-linked note opens the corresponding PDF at that page.

### Dashboard

- As a user, I can see statistics (total books, per-category counts, total bookmarks).
- As a user, I can continue reading my last opened book from the exact previous position.
- As a user, I can see recently opened books.
- As a user, I can use quick actions (Import PDF, Browse Library, My Notes, Bookmarks).

### Reading Customization

- As a user, I can choose Light, Dark, or System theme.
- As a user, I can set default zoom, single-page or continuous mode, and toggle page numbers.
- As a user, I can use a distraction-free reading mode.
- As a user, the app remembers my last reading position.

### Backup & Restore

- As a user, I can back up metadata, PDFs, progress, bookmarks, notes, annotations, subjects, and preferences.
- As a user, I can restore a backup on another Android device.
- As a user, the app validates backup integrity before restoring.
- As a user, I confirm before replacing or merging existing data during restore.

### Security

- As a user, I can optionally enable a PIN lock and/or biometric authentication.
- As a user, I can configure an automatic lock after a period of inactivity.
- As a user, the app requires no online account.

## 5. Functional Requirements

### FR-1: Application Navigation

- FR-1.1: A bottom navigation bar with four sections: Home, Library, My Notes, Settings.
- FR-1.2: Dashboard provides quick access to bookmarks and recently opened books.

### FR-2: Home Dashboard

- FR-2.1: Display statistics: total books, student books, teacher guides, short notes, other books, total bookmarks.
- FR-2.2: Display the last opened book with cover, title, grade, subject, current page, total pages, and progress percentage.
- FR-2.3: Tapping the Continue Reading card reopens the book at the previous reading position.
- FR-2.4: Display recently opened books as horizontal cards.
- FR-2.5: Provide quick actions: Import PDF, Browse Library, My Notes, Bookmarks.

### FR-3: Library

- FR-3.1: Support four categories: Student Books, Teacher Guides, Short Notes, Other Books.
- FR-3.2: Support grades 1–5.
- FR-3.3: Support common subjects and custom subjects (add, edit, delete).
- FR-3.4: Show an information form on PDF import with required fields (title, category, grade, subject) and optional fields (description, author, publisher, academic year).
- FR-3.5: Auto-detect the PDF filename and suggest it as the title.
- FR-3.6: Generate a cover preview from the first PDF page when possible.
- FR-3.7: Support single and multiple PDF imports.
- FR-3.8: Support editing book information, replacing PDF files, deleting books (with confirmation), and viewing book details.
- FR-3.9: Detect duplicate imports where practical.
- FR-3.10: Copy imported PDFs into application-managed storage; do not rely on temporary file-picker paths.
- FR-3.11: Before deleting a book, confirm and explain the effect on its notes, bookmarks, and annotations.

### FR-4: Library Search, Filter, Sort

- FR-4.1: Grade filter: All Grades, Grade 1–5.
- FR-4.2: Category filter: All Categories and the four categories.
- FR-4.3: Subject filter: any available subject.
- FR-4.4: Search by title, subject, category, author, description.
- FR-4.5: Sort by Recently Added, Recently Opened, Alphabetical A–Z, Alphabetical Z–A, Most Read.
- FR-4.6: Allow multiple filters simultaneously.
- FR-4.7: Show a clear empty state when no books match.

### FR-5: PDF Reader

- FR-5.1: Render PDFs smoothly with continuous scrolling and single-page modes.
- FR-5.2: Support zoom in/out, page navigation, jump to page, and page thumbnails.
- FR-5.3: Support in-PDF text search.
- FR-5.4: Support PDF text selection where supported.
- FR-5.5: Support portrait and landscape orientation.
- FR-5.6: Display current page and total pages.
- FR-5.7: Automatically save book id, current page, reading position, progress percentage, and last reading date.
- FR-5.8: Restore the previous position when reopening a book.
- FR-5.9: Save progress periodically and on close/background; prevent loss after unexpected shutdown.
- FR-5.10: Provide a reader toolbar: back, book info, bookmark, search, notes, annotation tools, reading settings.

### FR-6: Bookmarks

- FR-6.1: Add, remove, and edit bookmarks (title and description).
- FR-6.2: View all bookmarks and jump to bookmarked pages.
- FR-6.3: Support multiple bookmarks per book.
- FR-6.4: Provide a dedicated Bookmarks screen showing bookmarks from all books.

### FR-7: Annotations

- FR-7.1: Implement highlight, underline, strikethrough, text annotations, freehand drawing, finger/stylus handwriting, eraser, color change, undo, redo.
- FR-7.2: Persist annotations with book id, page number, type, content, position, dimensions, color, created_at, updated_at.
- FR-7.3: Keep annotations in correct positions across zoom, scroll, orientation change, and reopen using normalized coordinates.
- FR-7.4: Do not permanently modify the original PDF.
- FR-7.5: Provide export of a separate annotated PDF copy.
- FR-7.6: Implement actual functional annotations, not decorative toolbar buttons.

### FR-8: Notes

- FR-8.1: Support page-linked notes (book, page, subject, grade) and independent notes.
- FR-8.2: Support create, view, edit, delete, search, filter, and automatic saving.
- FR-8.3: Notes dashboard shows title, content preview, book title, page number, grade, subject, creation date.
- FR-8.4: Filter notes by grade, subject, book, date.
- FR-8.5: Tapping a page-linked note opens the corresponding PDF at that page.

### FR-9: Reading Customization

- FR-9.1: Light, Dark, System themes.
- FR-9.2: Adjustable default zoom.
- FR-9.3: Single-page and continuous reading modes.
- FR-9.4: Remember last reading position.
- FR-9.5: Toggle page numbers visibility.
- FR-9.6: Distraction-free reading mode.
- FR-9.7: Configurable reader toolbar.

### FR-10: Backup & Restore

- FR-10.1: Export book metadata, PDF files, reading progress, bookmarks, notes, annotations, subjects, preferences.
- FR-10.2: Create a portable backup archive restorable on another Android device.
- FR-10.3: Validate backup integrity before restoration.
- FR-10.4: Confirm before replacing or merging existing data.

### FR-11: Security

- FR-11.1: Optional PIN lock.
- FR-11.2: Optional biometric authentication.
- FR-11.3: Automatic locking after a configurable period.
- FR-11.4: Store security preferences appropriately; no online account required.

### FR-12: Subjects

- FR-12.1: Provide common subjects: Mathematics, English, Amharic, Afaan Oromo, Science, Social Studies, Civics, Other.
- FR-12.2: Allow adding, editing, and deleting custom subjects.

## 6. Non-Functional Requirements

### NFR-1: Platform

- Android ONLY. No iOS support or iOS-specific configuration.
- Optimize for Android smartphones and tablets.

### NFR-2: Performance & Reliability

- Work efficiently on low-end Android devices.
- Lazy loading, efficient PDF rendering, page caching where appropriate.
- Efficient database queries; do not block the UI during expensive operations.
- Do not load entire large PDFs into memory unnecessarily.
- Background saving of progress and annotations.
- Safe file operations.

### NFR-3: Offline

- All important features must work without an internet connection.

### NFR-4: Robustness

- Duplicate import prevention where practical.
- Corrupted PDF detection.
- Password-protected PDF handling.
- Missing-file detection.
- Memory-efficient PDF handling.
- Graceful error handling with clear error messages.

### NFR-5: UI/UX

- Material Design 3.
- Color palette: Primary Deep Navy Blue, Secondary Teal, Accent Soft Orange; light background white/very light gray; dark background deep charcoal.
- Modern, professional, attractive book cards, clean typography, consistent spacing, rounded corners, beautiful empty states, subtle animations, responsive layouts, accessible touch targets, professional loading indicators, clear error messages.
- Avoid overcrowded screens; optimize for small Android screens.

### NFR-6: Maintainability

- Feature-based Clean Architecture; keep features independent and reusable.
- Clean, maintainable Dart code; reusable widgets; Flutter best practices.
- Lightweight dependencies.

## 7. Acceptance Criteria

The application is complete when:

1. Educational PDFs can be imported from Android storage.
2. Books can be organized into four categories.
3. Books can be classified by Grade 1–5.
4. Subjects can be assigned to books.
5. Books can be searched, filtered, and sorted.
6. PDFs can be read inside the application.
7. Reading automatically resumes from the last page.
8. Multiple pages can be bookmarked.
9. PDF pages can be highlighted, underlined, drawn on, and annotated.
10. Personal notes can be written and associated with individual PDF pages.
11. All personal notes can be searched and managed.
12. Annotated PDF copies can be exported.
13. All important data can be backed up and restored.
14. The application can be used completely offline.
15. The application can be installed and run on Android devices.

## 8. Technical Constraints

- Framework: Flutter; Language: Dart.
- State Management: Riverpod.
- Local Database: SQLite + Drift.
- Navigation: GoRouter.
- PDF Rendering: a compatible Flutter PDF viewer (verify compatibility before installation).
- File Import: File Picker; use Android Storage Access Framework where necessary.
- Local Storage: application documents directory.
- Preferences: SharedPreferences.
- UI: Material Design 3.
- Security: Local Authentication.
- Store PDF files in the device file system, not as large SQLite binary records.
- Verify package compatibility before installation; avoid unnecessary dependencies.
