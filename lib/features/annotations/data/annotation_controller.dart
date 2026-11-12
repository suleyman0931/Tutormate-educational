import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/annotations_dao.dart';
import '../../../core/database/database_provider.dart';
import 'annotation_models.dart';

// ── Tool enum ─────────────────────────────────────────────────────────────────

/// Which annotation tool is currently active in the reader.
enum AnnotationTool {
  none,
  highlight,
  underline,
  strikethrough,
  text,
  drawing,
  eraser;

  bool get isRectBased =>
      this == highlight || this == underline || this == strikethrough;
  bool get isActive => this != none;
}

// ── Annotation item (in-memory) ───────────────────────────────────────────────

/// In-memory annotation item — a decoded DB row + its parsed data model.
class AnnotationItem {
  final int? dbId; // null before first persist
  final int bookId;
  final int pageNumber;
  final AnnotationData data;

  const AnnotationItem({
    this.dbId,
    required this.bookId,
    required this.pageNumber,
    required this.data,
  });

  AnnotationItem withId(int id) => AnnotationItem(
        dbId: id,
        bookId: bookId,
        pageNumber: pageNumber,
        data: data,
      );
}

// ── Page annotation args ──────────────────────────────────────────────────────

/// Family argument: identifies a unique (bookId, pageNumber) pair.
class PageKey {
  final int bookId;
  final int pageNumber;

  const PageKey(this.bookId, this.pageNumber);

  @override
  bool operator ==(Object other) =>
      other is PageKey &&
      other.bookId == bookId &&
      other.pageNumber == pageNumber;

  @override
  int get hashCode => Object.hash(bookId, pageNumber);
}

// ── Annotation page controller ────────────────────────────────────────────────

/// Manages annotations for one (bookId, pageNumber) pair.
///
/// Uses [FamilyNotifier] so Riverpod can keep one instance per unique [PageKey].
class AnnotationPageController
    extends FamilyNotifier<List<AnnotationItem>, PageKey> {
  final List<List<AnnotationItem>> _undoStack = [];
  final List<List<AnnotationItem>> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  AnnotationsDao get _dao => ref.read(annotationsDaoProvider);

  @override
  List<AnnotationItem> build(PageKey arg) {
    // Load from DB asynchronously; start with empty list.
    Future.microtask(() => _loadAnnotations(arg));
    return [];
  }

  Future<void> _loadAnnotations(PageKey key) async {
    final rows =
        await _dao.getAnnotationsByPage(key.bookId, key.pageNumber);
    final items = rows.map((row) {
      final color = Color(row.color);
      final data = AnnotationData.fromJsonString(
          row.annotationData, row.annotationType, color);
      return AnnotationItem(
          dbId: row.id,
          bookId: key.bookId,
          pageNumber: key.pageNumber,
          data: data);
    }).toList();
    state = items;
  }

  void _pushUndo() {
    _undoStack.add(List<AnnotationItem>.from(state));
    _redoStack.clear();
  }

  /// Adds a new annotation and persists it immediately.
  Future<void> addAnnotation(AnnotationData data) async {
    _pushUndo();
    final item = AnnotationItem(
        bookId: arg.bookId, pageNumber: arg.pageNumber, data: data);
    final id = await _dao.insertAnnotation(
      AnnotationsCompanion.insert(
        bookId: arg.bookId,
        pageNumber: arg.pageNumber,
        annotationType: data.type,
        annotationData: data.toJsonString(),
        color: Value(data.color.toARGB32()),
      ),
    );
    state = [...state, item.withId(id)];
  }

  /// Removes an annotation at [index] and deletes from DB.
  Future<void> removeAnnotationAt(int index) async {
    if (index < 0 || index >= state.length) return;
    _pushUndo();
    final item = state[index];
    if (item.dbId != null) await _dao.deleteAnnotation(item.dbId!);
    final updated = List<AnnotationItem>.from(state)..removeAt(index);
    state = updated;
  }

  /// Undo the last annotation change.
  Future<void> undo() async {
    if (!canUndo) return;
    _redoStack.add(List<AnnotationItem>.from(state));
    final previous = _undoStack.removeLast();
    state = previous;
    await _syncToDb(previous);
  }

  /// Redo the last undone change.
  Future<void> redo() async {
    if (!canRedo) return;
    _undoStack.add(List<AnnotationItem>.from(state));
    final next = _redoStack.removeLast();
    state = next;
    await _syncToDb(next);
  }

  /// Clears all annotations for this page.
  Future<void> clearAll() async {
    _pushUndo();
    await _dao.deleteAnnotationsByBook(arg.bookId);
    state = [];
  }

  /// Full re-sync: delete all and re-insert from [items].
  /// Only called by undo/redo to bring the DB back in line.
  Future<void> _syncToDb(List<AnnotationItem> items) async {
    // Delete only page-specific annotations, then re-insert.
    final allForBook = await _dao.getAllAnnotationsByBook(arg.bookId);
    for (final row in allForBook) {
      if (row.pageNumber == arg.pageNumber) {
        await _dao.deleteAnnotation(row.id);
      }
    }
    final updated = <AnnotationItem>[];
    for (final item in items) {
      final id = await _dao.insertAnnotation(
        AnnotationsCompanion.insert(
          bookId: arg.bookId,
          pageNumber: arg.pageNumber,
          annotationType: item.data.type,
          annotationData: item.data.toJsonString(),
          color: Value(item.data.color.toARGB32()),
        ),
      );
      updated.add(item.withId(id));
    }
    state = updated;
  }
}

/// Provider family — one controller per unique [PageKey].
final annotationControllerProvider = NotifierProviderFamily<
    AnnotationPageController, List<AnnotationItem>, PageKey>(
  AnnotationPageController.new,
);

// ── Global tool/color/stroke providers ───────────────────────────────────────

/// Currently selected annotation tool.
final annotationToolProvider =
    StateProvider<AnnotationTool>((_) => AnnotationTool.none);

/// Currently selected annotation color.
final annotationColorProvider =
    StateProvider<Color>((_) => const Color(0xFFFFEB3B));

/// Currently selected stroke width (for drawing tool).
final annotationStrokeWidthProvider = StateProvider<double>((_) => 3.0);
