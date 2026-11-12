import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_constants.dart';
import '../../../app/router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';

// ── Filter state ─────────────────────────────────────────────────────────────

class _NotesFilter {
  final String query;
  final int? grade;
  final int? subjectId;
  final int? bookId;

  const _NotesFilter({
    this.query = '',
    this.grade,
    this.subjectId,
    this.bookId,
  });

  bool get hasActive =>
      query.isNotEmpty ||
      grade != null ||
      subjectId != null ||
      bookId != null;

  _NotesFilter copyWith({
    String? query,
    int? grade,
    int? subjectId,
    int? bookId,
    bool clearGrade = false,
    bool clearSubject = false,
    bool clearBook = false,
  }) =>
      _NotesFilter(
        query: query ?? this.query,
        grade: clearGrade ? null : (grade ?? this.grade),
        subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
        bookId: clearBook ? null : (bookId ?? this.bookId),
      );
}

final _notesFilterProvider =
    StateProvider<_NotesFilter>((_) => const _NotesFilter());

/// My Notes screen: list of all notes with search, filter, and CRUD.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(allNotesProvider);
    final booksAsync = ref.watch(allBooksProvider);
    final subjectsAsync = ref.watch(allSubjectsProvider);
    final filter = ref.watch(_notesFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchBar(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter bar ───────────────────────────────────────────────────
          if (filter.hasActive) _buildActiveFiltersBar(filter, ref),

          // ── Filter chips row ─────────────────────────────────────────────
          _buildFilterRow(booksAsync, subjectsAsync, filter, ref),

          const Divider(height: 1),

          // ── Notes list ───────────────────────────────────────────────────
          Expanded(
            child: notesAsync.when(
              data: (notes) {
                final filtered = _applyFilter(notes, filter);
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.sticky_note_2_outlined,
                    title: filter.hasActive
                        ? 'No notes match your filters'
                        : 'No notes yet',
                    message: filter.hasActive
                        ? 'Try clearing some filters.'
                        : 'Create your first note by tapping +.',
                    actionLabel:
                        filter.hasActive ? null : 'Create Note',
                    onAction: filter.hasActive
                        ? null
                        : () => _openNoteEdit(context),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final note = filtered[index];
                    return _NoteCard(note: note);
                  },
                );
              },
              loading: () => const LoadingIndicator(),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNoteEdit(context),
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
    );
  }

  List<Note> _applyFilter(List<Note> notes, _NotesFilter filter) {
    return notes.where((n) {
      if (filter.query.isNotEmpty) {
        final q = filter.query.toLowerCase();
        if (!n.title.toLowerCase().contains(q) &&
            !(n.content.toLowerCase().contains(q))) {
          return false;
        }
      }
      if (filter.grade != null && n.grade != filter.grade) return false;
      if (filter.subjectId != null && n.subjectId != filter.subjectId) {
        return false;
      }
      if (filter.bookId != null && n.bookId != filter.bookId) return false;
      return true;
    }).toList();
  }

  void _openNoteEdit(BuildContext context) {
    context.push(AppRoutes.noteEdit);
  }

  void _showSearchBar(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search Notes'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Title or content…',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(_notesFilterProvider.notifier).state = ref
                  .read(_notesFilterProvider)
                  .copyWith(query: '');
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(_notesFilterProvider.notifier).state = ref
                  .read(_notesFilterProvider)
                  .copyWith(query: _searchController.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBar(_NotesFilter filter, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Filtered: ${filter.query.isNotEmpty ? '"${filter.query}" ' : ''}'
              '${filter.grade != null ? 'Grade ${filter.grade} ' : ''}'
              '${filter.bookId != null ? '1 book ' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(_notesFilterProvider.notifier).state =
                    const _NotesFilter(),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(
    AsyncValue<List<Book>> booksAsync,
    AsyncValue<List<Subject>> subjectsAsync,
    _NotesFilter filter,
    WidgetRef ref,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Grade filter
          _buildFilterChip(
            context: context,
            label: filter.grade != null ? 'Grade ${filter.grade}' : 'Grade',
            icon: Icons.grade_outlined,
            active: filter.grade != null,
            onTap: () => _showGradeFilter(ref, filter),
          ),
          // Subject filter
          subjectsAsync.when(
            data: (subjects) => _buildFilterChip(
              context: context,
              label: filter.subjectId != null
                  ? subjects
                      .firstWhere(
                        (s) => s.id == filter.subjectId,
                        orElse: () => Subject(
                            id: -1,
                            name: 'Unknown',
                            createdAt: DateTime.now()),
                      )
                      .name
                  : 'Subject',
              icon: Icons.subject_outlined,
              active: filter.subjectId != null,
              onTap: () => _showSubjectFilter(ref, filter, subjects),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          // Book filter
          booksAsync.when(
            data: (books) => _buildFilterChip(
              context: context,
              label: filter.bookId != null
                  ? books
                      .firstWhere(
                        (b) => b.id == filter.bookId,
                        orElse: () => books.first,
                      )
                      .title
                  : 'Book',
              icon: Icons.menu_book_outlined,
              active: filter.bookId != null,
              onTap: () => _showBookFilter(ref, filter, books),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
      selected: active,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _showGradeFilter(WidgetRef ref, _NotesFilter current) {
    showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('All Grades'),
            onTap: () {
              ref.read(_notesFilterProvider.notifier).state =
                  current.copyWith(clearGrade: true);
              Navigator.of(ctx).pop();
            },
          ),
          ...AppConstants.grades.map(
            (g) => ListTile(
              title: Text('Grade $g'),
              onTap: () {
                ref.read(_notesFilterProvider.notifier).state =
                    current.copyWith(grade: g);
                Navigator.of(ctx).pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSubjectFilter(
      WidgetRef ref, _NotesFilter current, List<Subject> subjects) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('All Subjects'),
            onTap: () {
              ref.read(_notesFilterProvider.notifier).state =
                  current.copyWith(clearSubject: true);
              Navigator.of(ctx).pop();
            },
          ),
          ...subjects.map(
            (s) => ListTile(
              title: Text(s.name),
              onTap: () {
                ref.read(_notesFilterProvider.notifier).state =
                    current.copyWith(subjectId: s.id);
                Navigator.of(ctx).pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBookFilter(
      WidgetRef ref, _NotesFilter current, List<Book> books) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('All Books'),
            onTap: () {
              ref.read(_notesFilterProvider.notifier).state =
                  current.copyWith(clearBook: true);
              Navigator.of(ctx).pop();
            },
          ),
          ...books.map(
            (b) => ListTile(
              leading: const Icon(Icons.menu_book),
              title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                ref.read(_notesFilterProvider.notifier).state =
                    current.copyWith(bookId: b.id);
                Navigator.of(ctx).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Note card ─────────────────────────────────────────────────────────────────

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Look up book title for page-linked notes.
    final booksAsync = ref.watch(allBooksProvider);
    String? bookTitle;
    if (note.bookId != null) {
      booksAsync.whenData((books) {
        try {
          bookTitle = books.firstWhere((b) => b.id == note.bookId).title;
        } catch (_) {}
      });
    }

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // If linked to a book and page, open reader at that page.
          if (note.bookId != null && note.pageNumber != null) {
            context.push(AppRoutes.readerFor(note.bookId!));
          } else {
            context.push(AppRoutes.noteEdit, extra: note);
          }
        },
        onLongPress: () => _showNoteMenu(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.bookId != null)
                    Icon(Icons.link, size: 16, color: colorScheme.primary),
                ],
              ),
              const SizedBox(height: 4),
              // Content preview
              Text(
                note.content,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Metadata chips
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  if (note.grade != null)
                    _chip(context, 'Grade ${note.grade}',
                        Icons.grade_outlined),
                  if (bookTitle != null && note.pageNumber != null)
                    _chip(context, 'p.${note.pageNumber}',
                        Icons.menu_book_outlined),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  void _showNoteMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(ctx).pop();
                context.push(AppRoutes.noteEdit, extra: note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Delete Note',
                  message: 'Delete "${note.title}"? This cannot be undone.',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (!confirmed) return;
                await ref.read(notesDaoProvider).deleteNote(note.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Note deleted')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
