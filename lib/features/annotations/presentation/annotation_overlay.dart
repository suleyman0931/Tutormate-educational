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
    final scrollLocked = ref.read(scrollLockProvider);
    
    if (tool == AnnotationTool.none) return;
    
    // If scroll is not locked, don't start annotation - allow scrolling
    if (!scrollLocked) return;

    // Convert local position to screen coordinates
    final screenPos = Offset(
      d.localPosition.dx + widget.pageRect.left,
      d.localPosition.dy + widget.pageRect.top,
    );

    if (tool.isRectBased) {
      setState(() {
        _rectStart = screenPos;
        _rectEnd = screenPos;
      });
    } else if (tool == AnnotationTool.drawing) {
      setState(() {
        _currentStroke
          ..clear()
          ..add(screenPos);
      });
    } else if (tool == AnnotationTool.eraser) {
      _eraseAtPosition(screenPos);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final tool = _tool;
    final scrollLocked = ref.read(scrollLockProvider);
    
    if (tool == AnnotationTool.none) return;
    
    // If scroll is not locked, don't update annotation - allow scrolling
    if (!scrollLocked) return;

    // Convert local position to screen coordinates
    final screenPos = Offset(
      d.localPosition.dx + widget.pageRect.left,
      d.localPosition.dy + widget.pageRect.top,
    );

    if (tool.isRectBased) {
      setState(() => _rectEnd = screenPos);
    } else if (tool == AnnotationTool.drawing) {
      setState(() => _currentStroke.add(screenPos));
    } else if (tool == AnnotationTool.eraser) {
      _eraseAtPosition(screenPos);
    }
  }

  Future<void> _onPanEnd(DragEndDetails _) async {
    final tool = _tool;
    final scrollLocked = ref.read(scrollLockProvider);
    
    if (tool == AnnotationTool.none) return;
    
    // If scroll was not locked, we didn't draw anything
    if (!scrollLocked) return;

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

      final normRect = CoordinateUtils.rectToNormalized(
          screenRect, widget.pageRect);
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
      final normPoints = CoordinateUtils.pointsToNormalized(
          _currentStroke, widget.pageRect);
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
    if (tool == AnnotationTool.none) return;

    final controller =
        ref.read(annotationControllerProvider(_pk).notifier);

    // Convert local position to screen coordinates
    final screenPos = Offset(
      d.localPosition.dx + widget.pageRect.left,
      d.localPosition.dy + widget.pageRect.top,
    );

    if (tool == AnnotationTool.text) {
      await _showTextInputDialog(screenPos, controller);
    } else if (tool == AnnotationTool.eraser) {
      _eraseAt(screenPos, controller);
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
    final normPos =
        CoordinateUtils.toNormalized(tapPosition, widget.pageRect);
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
    
    // Find annotation whose rendered area contains the position.
    for (int i = annotations.length - 1; i >= 0; i--) {
      final item = annotations[i];
      final data = item.data;
      bool hit = false;

      if (data is RectAnnotationData) {
        final screenRect =
            CoordinateUtils.rectToScreen(data.rect, widget.pageRect);
        hit = screenRect.inflate(8).contains(position);
      } else if (data is TextAnnotationData) {
        final screenPos =
            CoordinateUtils.toScreen(data.position, widget.pageRect);
        hit = Rect.fromLTWH(screenPos.dx, screenPos.dy, 100, 30)
            .inflate(8)
            .contains(position);
      } else if (data is DrawingAnnotationData) {
        // Check if position is near any point of the stroke.
        final screenPoints = CoordinateUtils.pointsToScreen(
            data.points, widget.pageRect);
        hit = screenPoints.any(
            (p) => (p - position).distance < 20); // Increased radius for easier erasing
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
    // Find annotation whose rendered area contains the tap.
    for (int i = annotations.length - 1; i >= 0; i--) {
      final item = annotations[i];
      final data = item.data;
      bool hit = false;

      if (data is RectAnnotationData) {
        final screenRect =
            CoordinateUtils.rectToScreen(data.rect, widget.pageRect);
        hit = screenRect.inflate(8).contains(tapPosition);
      } else if (data is TextAnnotationData) {
        final screenPos =
            CoordinateUtils.toScreen(data.position, widget.pageRect);
        hit = Rect.fromLTWH(screenPos.dx, screenPos.dy, 100, 30)
            .inflate(8)
            .contains(tapPosition);
      } else if (data is DrawingAnnotationData) {
        // Check if tap is near any point of the stroke.
        final screenPoints = CoordinateUtils.pointsToScreen(
            data.points, widget.pageRect);
        hit = screenPoints.any(
            (p) => (p - tapPosition).distance < 16);
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
      behavior: HitTestBehavior.translucent,
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

    // Draw in-progress stroke/rect.
    // Convert from screen coords to local canvas coords
    if (currentTool == AnnotationTool.drawing && currentStroke.length > 1) {
      final localStroke = currentStroke
          .map((p) => p.translate(-pageRect.left, -pageRect.top))
          .toList();
      _paintStroke(canvas, localStroke, currentColor, currentStrokeWidth);
    } else if (currentTool.isRectBased &&
        rectStart != null &&
        rectEnd != null) {
      final localRect = Rect.fromPoints(
        rectStart!.translate(-pageRect.left, -pageRect.top),
        rectEnd!.translate(-pageRect.left, -pageRect.top),
      );
      _paintRectAnnotation(canvas, localRect, currentColor, currentTool);
    }

    canvas.restore();
  }

  void _paintAnnotation(Canvas canvas, AnnotationData data) {
    if (data is RectAnnotationData) {
      final screenRect =
          CoordinateUtils.rectToScreen(data.rect, pageRect);
      _paintRectAnnotation(
          canvas, screenRect, data.color, _toolForType(data.type));
    } else if (data is TextAnnotationData) {
      final screenPos =
          CoordinateUtils.toScreen(data.position, pageRect);
      _paintText(canvas, screenPos, data.text, data.color, data.fontSize);
    } else if (data is DrawingAnnotationData) {
      final screenPoints = CoordinateUtils.pointsToScreen(
              data.points, pageRect);
      _paintStroke(
          canvas, screenPoints, data.color, data.strokeWidth);
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
