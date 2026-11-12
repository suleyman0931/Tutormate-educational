import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/annotation_controller.dart';

/// Simplified annotation toolbar with only handwriting and eraser.
class AnnotationToolbar extends ConsumerWidget {
  const AnnotationToolbar({super.key});

  static const _colors = [
    Color(0xFF000000), // black
    Color(0xFFE53935), // red
    Color(0xFF1565C0), // blue
    Color(0xFF4CAF50), // green
    Color(0xFFFF6F00), // orange
    Color(0xFFAD1457), // pink
  ];

  static const _strokeWidths = [2.0, 4.0, 6.0, 8.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(annotationToolProvider);
    final color = ref.watch(annotationColorProvider);
    final strokeWidth = ref.watch(annotationStrokeWidthProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.97),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // ── Tool buttons ───────────────────────────────────────────────
              _ToolBtn(
                icon: Icons.draw_outlined,
                label: 'Handwriting',
                active: tool == AnnotationTool.drawing,
                onTap: () => ref.read(annotationToolProvider.notifier).state =
                    tool == AnnotationTool.drawing
                        ? AnnotationTool.none
                        : AnnotationTool.drawing,
              ),
              const SizedBox(width: 4),
              _ToolBtn(
                icon: Icons.auto_fix_high,
                label: 'Eraser',
                active: tool == AnnotationTool.eraser,
                onTap: () => ref.read(annotationToolProvider.notifier).state =
                    tool == AnnotationTool.eraser
                        ? AnnotationTool.none
                        : AnnotationTool.eraser,
              ),

              const SizedBox(width: 8),
              const VerticalDivider(width: 16),
              const SizedBox(width: 8),

              // ── Color picker ───────────────────────────────────────────────
              const Text(
                'Color: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4),
              ..._colors.map(
                (c) => GestureDetector(
                  onTap: () =>
                      ref.read(annotationColorProvider.notifier).state = c,
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == color
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: c == color ? 3 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),
              const VerticalDivider(width: 16),
              const SizedBox(width: 8),

              // ── Stroke width ───────────────────────────────────────────────
              const Text(
                'Size: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4),
              ..._strokeWidths.map(
                (w) => GestureDetector(
                  onTap: () =>
                      ref.read(annotationStrokeWidthProvider.notifier).state =
                          w,
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: w == strokeWidth
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.transparent,
                      border: Border.all(
                        color: w == strokeWidth
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: w == strokeWidth ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 24,
                        height: w,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(w / 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),
              const VerticalDivider(width: 16),
              const SizedBox(width: 4),

              // ── Close ───────────────────────────────────────────────────────
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close annotation tools',
                onPressed: () =>
                    ref.read(annotationToolProvider.notifier).state =
                        AnnotationTool.none,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active
                ? colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? colorScheme.primary
                  : Colors.grey.shade300,
              width: active ? 2 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: 24,
            color: active
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
