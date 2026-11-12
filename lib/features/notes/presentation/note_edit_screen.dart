import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

/// Screen for creating or editing a personal note.
///
/// When [linkedBookId] and [linkedPageNumber] are provided, the note will be
/// linked to a specific PDF page.
class NoteEditScreen extends ConsumerStatefulWidget {
  const NoteEditScreen({
    super.key,
    this.existingNote,
    this.linkedBookId,
    this.linkedPageNumber,
    this.linkedBookTitle,
  });

  final Note? existingNote;
  final int? linkedBookId;
  final int? linkedPageNumber;
  final String? linkedBookTitle;

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;

  int? _subjectId;
  int? _grade;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existingNote != null;

  @override
  void initState() {
    super.initState();
    final n = widget.existingNote;
    _titleCtrl = TextEditingController(text: n?.title ?? '');
    _contentCtrl = TextEditingController(text: n?.content ?? '');
    _subjectId = n?.subjectId;
    _grade = n?.grade;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notesDao = ref.read(notesDaoProvider);
      if (_isEditing) {
        await notesDao.updateNote(
          widget.existingNote!.copyWith(
            title: _titleCtrl.text.trim(),
            content: _contentCtrl.text.trim(),
            subjectId: Value(_subjectId),
            grade: Value(_grade),
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        await notesDao.insertNote(
          NotesCompanion.insert(
            title: _titleCtrl.text.trim(),
            content: _contentCtrl.text.trim(),
            bookId: Value(widget.linkedBookId),
            pageNumber: Value(widget.linkedPageNumber),
            subjectId: Value(_subjectId),
            grade: Value(_grade),
          ),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Note updated' : 'Note saved',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Failed to save: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(allSubjectsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Note' : 'New Note'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Link info ───────────────────────────────────────────────────
            if (widget.linkedBookId != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.linkedBookTitle != null
                            ? '${widget.linkedBookTitle} — Page ${widget.linkedPageNumber}'
                            : 'Linked to page ${widget.linkedPageNumber}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Title ────────────────────────────────────────────────────────
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title *',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),

            // ── Content ──────────────────────────────────────────────────────
            TextFormField(
              controller: _contentCtrl,
              decoration: const InputDecoration(
                labelText: 'Content *',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
              maxLines: 10,
              minLines: 5,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Content is required'
                  : null,
            ),
            const SizedBox(height: 16),

            // ── Grade (optional) ─────────────────────────────────────────────
            DropdownButtonFormField<int?>(
              initialValue: _grade,
              decoration: const InputDecoration(
                labelText: 'Grade (optional)',
                prefixIcon: Icon(Icons.grade_outlined),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('No Grade')),
                ...AppConstants.grades.map(
                  (g) =>
                      DropdownMenuItem(value: g, child: Text('Grade $g')),
                ),
              ],
              onChanged: (v) => setState(() => _grade = v),
            ),
            const SizedBox(height: 16),

            // ── Subject (optional) ───────────────────────────────────────────
            subjectsAsync.when(
              data: (subjects) => DropdownButtonFormField<int?>(
                initialValue:
                    subjects.any((s) => s.id == _subjectId) ? _subjectId : null,
                decoration: const InputDecoration(
                  labelText: 'Subject (optional)',
                  prefixIcon: Icon(Icons.subject_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('No Subject')),
                  ...subjects.map(
                    (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _subjectId = v),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading subjects: $e'),
            ),
            const SizedBox(height: 24),

            // ── Error ────────────────────────────────────────────────────────
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),

            // ── Save button ──────────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'Update Note' : 'Save Note'),
            ),
          ],
        ),
      ),
    );
  }
}
