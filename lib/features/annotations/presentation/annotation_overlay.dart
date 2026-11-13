import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/enums.dart';
import '../../../core/utils/coordinate_utils.dart';
import '../data/annotation_controller.dart';
import '../data/annotation_models.dart';

/// Transparent overlay drawn on top of a PDF page that:
/// - Renders existing annotations via [CustomPaint].
/// - Captures touch input to create new annotations.
///
/// [pageRect] is the page's bounding box in widget-local coordinates (from
/// pdfrx's pageOverlaysBuilder callback).
class AnnotationOverlay extends ConsumerStatefulWidget {
  const AnnotationOverlay({
    super.key,
    required this.bookId,
    required this.pageNumber,
    required this.pageRect,
  });

  final int bookId;
  final int pageNumber;
  final Rect pageRect;

  @override
  ConsumerState<AnnotationOverlay> createState() => _AnnotationOverlayState();
}

class _AnnotationOverlayState extends ConsumerState<AnnotationOverlay> {
  /// Points being drawn in the current freehand stroke (screen coords).
  final List<Offset> _currentStroke = [];

  /// Start point for rect-based tools (screen coords).
  Offset? _rectStart;
  Offset? _rectEnd;

  PageKey get _pk => PageKey(widget.bookId, widget.pageNumber);

  AnnotationTool get _tool => ref.read(annotationToolProvider);
  Color get _color => ref.read(annotationColorProvider);
  double get _strokeWidth => ref.read(annotationStrokeWidthProvider);

  // ── Gesture handling ───────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    final tool = _tool;
    
    if (tool == AnnotationTool.none || !tool.isActive) return;

    // d.localPosition is in the overlay's local coordinate system
    // which is the same as the page rect's coordinate system within the overlay
    final position = d.localPosition;

    if (tool.isRectBased) {
      setState(() {
        _rectStart = position;
        _rectEnd = position;
      });
    } else if (tool == AnnotationTool.drawing) {
      setState(() {
        _currentStroke
          ..clear()
          ..add(position);
      });
    } else if (tool == AnnotationTool.eraser) {
      _eraseAtPosition(position);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final tool = _tool;
    
    if (tool == AnnotationTool.none || !tool.isActive) return;

    final position = d.localPosition;

    if (tool.isRectBased) {
      setState(() => _rectEnd = position);
    } else if (tool == AnnotationTool.drawing) {
      setState(() => _currentStroke.add(position));
    } else if (tool == AnnotationTool.eraser) {
      _eraseAtPosition(position);
    }
  }

  void _onPanEnd(DragEndDetails _) async {
    final tool = _tool;
    
    if (tool == AnnotationTool.none || !tool.isActive) return;

    final controller =
        ref.read(annotationControllerProvider(_pk).notifier);

    if (tool.isRectBased && _rectStart != null && _rectEnd != null) {
      final screenRect = Rect.fromPoints(_rectStart!, _rectEnd!);
      if (screenRect.width < 4 || screenRect.height < 4) {
        // Too small — ignore.
        setState(() {
          _rectStart = null;
          _rectEnd = null;
        });
        return;
      }

      // screenRect is already in the overlay's local coordinate system,
      // which maps directly to normalized page coordinates
      final normRect = CoordinateUtils.rectToNormalized(
          screenRect, Rect.fromLTWH(0, 0, widget.pageRect.width, widget.pageRect.height));
      late AnnotationType type;
      switch (tool) {
        case AnnotationTool.highlight:
          type = AnnotationType.highlight;
        case AnnotationTool.underline:
          type = AnnotationType.underline;
        case AnnotationTool.strikethrough:
          type = AnnotationType.strikethrough;
        default:
          type = AnnotationType.highlight;
      }
      await controller.addAnnotation(
        RectAnnotationData(type: type, color: _color, rect: normRect),
      );
      setState(() {
        _rectStart = null;
        _rectEnd = null;
      });
    } else if (tool == AnnotationTool.drawing && _currentStroke.length > 1) {
      // _currentStroke points are in the overlay's local coordinate system
      final normPoints = CoordinateUtils.pointsToNormalized(
          _currentStroke, Rect.fromLTWH(0, 0, widget.pageRect.width, widget.pageRect.height));
      await controller.addAnnotation(
        DrawingAnnotationData(
          color: _color,
          points: normPoints,
          strokeWidth: _strokeWidth,
        ),
      );
      setState(() => _currentStroke.clear());
    }
  }

  Future<void> _onTapUp(TapUpDetails d) async {
    final tool = _tool;
    if (tool == AnnotationTool.none || !tool.isActive) return;

    final controller =
        ref.read(annotationControllerProvider(_pk).notifier);

    // Use localPosition directly - overlay is already positioned at the page
    final position = d.localPosition;

    if (tool == AnnotationTool.text) {
      await _showTextInputDialog(position, controller);
    } else if (tool == AnnotationTool.eraser) {
      _eraseAt(position, controller);
    }
  }

  Future<void> _showTextInputDialog(
      Offset tapPosition, AnnotationPageController controller) async {
    final textController = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Text Note'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter annotation text…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(textController.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    // Convert local position to normalized position
    final normPos =
        CoordinateUtils.toNormalized(tapPosition, Rect.fromLTWH(0, 0, widget.pageRect.width, widget.pageRect.height));
    await controller.addAnnotation(
      TextAnnotationData(
        color: _color,
        position: normPos,
        text: text,
      ),
    );
  }

  void _eraseAtPosition(Offset position) {
    final controller = ref.read(annotationControllerProvider(_pk).notifier);
    final annotations = ref.read(annotationControllerProvider(_pk));
    
    // position is in overlay's local coordinate system
    // Find annotation whose rendered area contains the position
    final pageSize = Rect.fromLTWH(0, 0, widget.pageRect.width, widget.pageRect.height);
    
    for (int i = annotations.length - 1; i >= 0; i--) {
      final item = annotations[i];
      final data = item.data;
      bool hit = false;

      if (data is RectAnnotationData) {
        // Convert normalized rect to local coordinates
        final localRect = CoordinateUtils.rectToScreen(data.rect, pageSize);
        hit = localRect.inflate(8).contains(position);
      } else if (data is TextAnnotationData) {
        // Convert normalized position to local coordinates
        final localPos = CoordinateUtils.toScreen(data.position, pageSize);
        hit = Rect.fromLTWH(localPos.dx, localPos.dy, 100, 30)
            .inflate(8)
            .contains(position);
      } else if (data is DrawingAnnotationData) {
        // Convert normalized points to local coordinates
        final localPoints = CoordinateUtils.pointsToScreen(data.points, pageSize);
        hit = localPoints.any((p) => (p - position).distance < 20);
      }

      if (hit) {
        controller.removeAnnotationAt(i);
        return;
      }
    }
  }

  void _eraseAt(
      Offset tapPosition, AnnotationPageController controller) {
    final annotations = ref.read(annotationControllerProvider(_pk));
    
    // tapPosition is in overlay's local coordinate system
    final pageSize = Rect.fromLTWH(0, 0, widget.pageRect.width, widget.pageRect.height);
    
    for (int i = annotations.length - 1; i >= 0; i--) {
      final item = annotations[i];
      final data = item.data;
      bool hit = false;

      if (data is RectAnnotationData) {
        // Convert normalized rect to local coordinates
        final localRect = CoordinateUtils.rectToScreen(data.rect, pageSize);
        hit = localRect.inflate(8).contains(tapPosition);
      } else if (data is TextAnnotationData) {
        // Convert normalized position to local coordinates
        final localPos = CoordinateUtils.toScreen(data.position, pageSize);
        hit = Rect.fromLTWH(localPos.dx, localPos.dy, 100, 30)
            .inflate(8)
            .contains(tapPosition);
      } else if (data is DrawingAnnotationData) {
        // Convert normalized points to local coordinates
        final localPoints = CoordinateUtils.pointsToScreen(data.points, pageSize);
        hit = localPoints.any((p) => (p - tapPosition).distance < 16);
      }

      if (hit) {
        controller.removeAnnotationAt(i);
        return;
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final annotations =
        ref.watch(annotationControllerProvider(_pk));
    final tool = ref.watch(annotationToolProvider);

    return GestureDetector(
      // Only absorb gestures when a tool is active - otherwise let pdfrx handle scrolling
      // When tool is active, use opaque so all gestures in this overlay are captured
      // When tool is inactive, use translucent to pass through to pdfrx
      behavior: tool.isActive ? HitTestBehavior.opaque : HitTestBehavior.translucent,
      onPanStart: tool.isActive ? _onPanStart : null,
      onPanUpdate: tool.isActive ? _onPanUpdate : null,
      onPanEnd: tool.isActive ? _onPanEnd : null,
      onTapUp: tool.isActive ? _onTapUp : null,
      child: CustomPaint(
        size: Size(widget.pageRect.width, widget.pageRect.height),
        painter: _AnnotationPainter(
          annotations: annotations,
          pageRect: widget.pageRect,
          currentStroke: _currentStroke,
          currentColor: _color,
          currentStrokeWidth: _strokeWidth,
          currentTool: tool,
          rectStart: _rectStart,
          rectEnd: _rectEnd,
        ),
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _AnnotationPainter extends CustomPainter {
  const _AnnotationPainter({
    required this.annotations,
    required this.pageRect,
    required this.currentStroke,
    required this.currentColor,
    required this.currentStrokeWidth,
    required this.currentTool,
    this.rectStart,
    this.rectEnd,
  });

  final List<AnnotationItem> annotations;
  final Rect pageRect;
  final List<Offset> currentStroke;
  final Color currentColor;
  final double currentStrokeWidth;
  final AnnotationTool currentTool;
  final Offset? rectStart;
  final Offset? rectEnd;

  @override
  void paint(Canvas canvas, Size size) {
    // Clip to the page rect to avoid painting outside.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Draw all saved annotations.
    for (final item in annotations) {
      _paintAnnotation(canvas, item.data);
    }

    // Draw in-progress stroke/rect - already in local coordinates
    if (currentTool == AnnotationTool.drawing && currentStroke.length > 1) {
      _paintStroke(canvas, currentStroke, currentColor, currentStrokeWidth);
    } else if (currentTool.isRectBased &&
        rectStart != null &&
        rectEnd != null) {
      final rect = Rect.fromPoints(rectStart!, rectEnd!);
      _paintRectAnnotation(canvas, rect, currentColor, currentTool);
    }

    canvas.restore();
  }

  void _paintAnnotation(Canvas canvas, AnnotationData data) {
    // pageRect is the overlay's size in its local coordinate system
    // which is (0, 0, width, height) so we pass a local rect
    final pageSize = Rect.fromLTWH(0, 0, pageRect.width, pageRect.height);
    
    if (data is RectAnnotationData) {
      final localRect = CoordinateUtils.rectToScreen(data.rect, pageSize);
      _paintRectAnnotation(canvas, localRect, data.color, _toolForType(data.type));
    } else if (data is TextAnnotationData) {
      final localPos = CoordinateUtils.toScreen(data.position, pageSize);
      _paintText(canvas, localPos, data.text, data.color, data.fontSize);
    } else if (data is DrawingAnnotationData) {
      final localPoints = CoordinateUtils.pointsToScreen(data.points, pageSize);
      _paintStroke(canvas, localPoints, data.color, data.strokeWidth);
    }
  }

  void _paintRectAnnotation(
      Canvas canvas, Rect rect, Color color, AnnotationTool tool) {
    switch (tool) {
      case AnnotationTool.highlight:
        final paint = Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill;
        canvas.drawRect(rect, paint);
      case AnnotationTool.underline:
        final paint = Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
            rect.bottomLeft, rect.bottomRight, paint);
      case AnnotationTool.strikethrough:
        final paint = Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        final mid = rect.top + rect.height / 2;
        canvas.drawLine(
            Offset(rect.left, mid), Offset(rect.right, mid), paint);
      default:
        break;
    }
  }

  void _paintText(Canvas canvas, Offset position, String text, Color color,
      double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          backgroundColor: Colors.white.withValues(alpha: 0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 160);
    // Draw background bubble.
    final bgRect = Rect.fromLTWH(
        position.dx - 2, position.dy - 2, tp.width + 4, tp.height + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    tp.paint(canvas, position);
  }

  void _paintStroke(
      Canvas canvas, List<Offset> points, Color color, double strokeWidth) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  AnnotationTool _toolForType(AnnotationType type) {
    switch (type) {
      case AnnotationType.highlight:
        return AnnotationTool.highlight;
      case AnnotationType.underline:
        return AnnotationTool.underline;
      case AnnotationType.strikethrough:
        return AnnotationTool.strikethrough;
      default:
        return AnnotationTool.none;
    }
  }

  @override
  bool shouldRepaint(_AnnotationPainter old) =>
      old.annotations != annotations ||
      old.currentStroke != currentStroke ||
      old.rectStart != rectStart ||
      old.rectEnd != rectEnd ||
      old.currentColor != currentColor ||
      old.currentTool != currentTool;
}
