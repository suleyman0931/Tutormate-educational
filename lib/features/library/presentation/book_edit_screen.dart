import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/enums.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/library_providers.dart';

/// Screen for editing an existing book's metadata.
class BookEditScreen extends ConsumerStatefulWidget {
  const BookEditScreen({super.key, required this.book});
  final Book book;

  @override
  ConsumerState<BookEditScreen> createState() => _BookEditScreenState();
}

class _BookEditScreenState extends ConsumerState<BookEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _authorController;
  late final TextEditingController _publisherController;
  late final TextEditingController _academicYearController;

  late BookCategory _category;
  late int _grade;
  int? _subjectId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    _titleController = TextEditingController(text: b.title);
    _descriptionController = TextEditingController(text: b.description ?? '');
    _authorController = TextEditingController(text: b.author ?? '');
    _publisherController = TextEditingController(text: b.publisher ?? '');
    _academicYearController = TextEditingController(text: b.academicYear ?? '');
    _category = b.category;
    _grade = b.grade;
    _subjectId = b.subjectId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    _academicYearController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_subjectId == null) {
      setState(() => _error = 'Please select a subject.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(bookRepositoryProvider).updateBookMetadata(
            bookId: widget.book.id,
            title: _titleController.text.trim(),
            category: _category,
            grade: _grade,
            subjectId: _subjectId,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            author: _authorController.text.trim().isEmpty
                ? null
                : _authorController.text.trim(),
            publisher: _publisherController.text.trim().isEmpty
                ? null
                : _publisherController.text.trim(),
            academicYear: _academicYearController.text.trim().isEmpty
                ? null
                : _academicYearController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book updated successfully')),
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
        title: const Text('Edit Book'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _saving
          ? const LoadingIndicator(message: 'Saving changes...')
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Title ───────────────────────────────────────────────────
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Book Title *',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Category ────────────────────────────────────────────────
                  DropdownButtonFormField<BookCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: BookCategory.values.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat.label),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Grade ────────────────────────────────────────────────────
                  DropdownButtonFormField<int>(
                    initialValue: _grade,
                    decoration: const InputDecoration(
                      labelText: 'Grade *',
                      prefixIcon: Icon(Icons.grade_outlined),
                    ),
                    items: AppConstants.grades.map((g) {
                      return DropdownMenuItem(
                        value: g,
                        child: Text('Grade $g'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _grade = v);
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Subject ──────────────────────────────────────────────────
                  subjectsAsync.when(
                    data: (subjects) => DropdownButtonFormField<int>(
                      initialValue: subjects.any((s) => s.id == _subjectId)
                          ? _subjectId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Subject *',
                        prefixIcon: Icon(Icons.subject_outlined),
                      ),
                      items: subjects.map((s) {
                        return DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _subjectId = v),
                      validator: (v) =>
                          v == null ? 'Please select a subject' : null,
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error loading subjects: $e'),
                  ),
                  const SizedBox(height: 16),

                  // ── Optional fields ──────────────────────────────────────────
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _authorController,
                    decoration: const InputDecoration(
                      labelText: 'Author',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _publisherController,
                    decoration: const InputDecoration(
                      labelText: 'Publisher',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _academicYearController,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Error ────────────────────────────────────────────────────
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),

                  // ── Save button ─────────────────────────────────────────────
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
    );
  }
}
