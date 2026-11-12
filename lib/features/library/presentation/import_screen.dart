import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_constants.dart';
import '../../../core/database/enums.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/book_repository.dart';
import '../data/library_providers.dart';

/// Screen for importing documents with metadata.
///
/// Supports: PDF and Text (.txt)
/// Text files are automatically converted to PDF.
///
/// When a single file is selected, the user fills in all fields.
/// When multiple files are selected, common metadata is set.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, required this.files});

  /// The documents picked by the user.
  final List<PlatformFile> files;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _authorController = TextEditingController();
  final _publisherController = TextEditingController();
  final _academicYearController = TextEditingController();

  BookCategory? _category;
  int? _grade;
  int? _subjectId;
  bool _importing = false;
  String? _error;

  bool get _isSingle => widget.files.length == 1;

  @override
  void initState() {
    super.initState();
    if (_isSingle) {
      _titleController.text =
          FileUtils.fileNameWithoutExtension(widget.files.first.name);
    }
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

  Future<void> _handleImport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null || _grade == null || _subjectId == null) {
      setState(() => _error = 'Please select category, grade, and subject.');
      return;
    }

    setState(() {
      _importing = true;
      _error = null;
    });

    final repo = ref.read(bookRepositoryProvider);

    try {
      if (_isSingle) {
        await repo.importBook(
          file: widget.files.first,
          title: _titleController.text.trim(),
          category: _category!,
          grade: _grade!,
          subjectId: _subjectId!,
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
      } else {
        await repo.importMultipleBooks(
          files: widget.files,
          category: _category!,
          grade: _grade!,
          subjectId: _subjectId!,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSingle
                ? '"${_titleController.text}" imported successfully'
                : '${widget.files.length} books imported successfully'),
          ),
        );
        context.pop();
      }
    } on DuplicateBookException catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
          _error = e.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
          _error = 'Import failed: $e';
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
        title: Text(_isSingle ? 'Import Document' : 'Import ${widget.files.length} Documents'),
      ),
      body: _importing
          ? LoadingIndicator(message: _isSingle
              ? 'Importing "${_titleController.text}"...'
              : 'Importing ${widget.files.length} books...')
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Cover preview placeholder ──────────────────────────────
                  _buildCoverPreview(theme),
                  const SizedBox(height: 24),

                  // ── File list (multiple import) ────────────────────────────
                  if (!_isSingle) ...[
                    _buildFileList(theme),
                    const SizedBox(height: 16),
                  ],

                  // ── Title (single import only) ───────────────────────────────
                  if (_isSingle) ...[
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Book Title *',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Please enter a title'
                              : null,
                    ),
                    const SizedBox(height: 16),
                  ],

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
                    onChanged: (v) => setState(() => _category = v),
                    validator: (v) => v == null ? 'Please select a category' : null,
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
                    onChanged: (v) => setState(() => _grade = v),
                    validator: (v) => v == null ? 'Please select a grade' : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Subject ──────────────────────────────────────────────────
                  subjectsAsync.when(
                    data: (subjects) {
                      // Ensure selected subject still exists.
                      if (_subjectId != null &&
                          !subjects.any((s) => s.id == _subjectId)) {
                        _subjectId = null;
                      }
                      return DropdownButtonFormField<int>(
                        initialValue: _subjectId,
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
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('Error loading subjects: $e'),
                  ),
                  const SizedBox(height: 16),

                  // ── Optional fields (single import only) ─────────────────────
                  if (_isSingle) ...[
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _authorController,
                      decoration: const InputDecoration(
                        labelText: 'Author (optional)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _publisherController,
                      decoration: const InputDecoration(
                        labelText: 'Publisher (optional)',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _academicYearController,
                      decoration: const InputDecoration(
                        labelText: 'Academic Year (optional)',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else
                    const SizedBox(height: 24),

                  // ── Error message ────────────────────────────────────────────
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Actions ────────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _handleImport,
                          icon: const Icon(Icons.download),
                          label: Text(_isSingle ? 'Import' : 'Import All'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCoverPreview(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Center(
      child: Column(
        children: [
          Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              Icons.picture_as_pdf_outlined,
              size: 48,
              color: colorScheme.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cover preview will be generated\nfrom the first page',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.files.length} PDFs to import',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...widget.files.map((file) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.description,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.name,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
