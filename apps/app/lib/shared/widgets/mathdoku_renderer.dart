import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/puzzle_core.dart';

import 'painter_utils.dart';
import 'puzzle_renderer.dart';
import 'performance_optimizations.dart';

class MathdokuRenderer extends PuzzleRenderer<MathdokuRendererWidget>
    with PerformanceOptimizedRendering {
  late MathdokuBoard _board;
  late GridMetrics _gridMetrics;

  late Paint _linePaint;
  late Paint _cellBgPaint;
  late Paint _selectionPaint;
  late Paint _errorPaint;

  @override
  void initState() {
    super.initState();
    _updateBoard();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupPaints();
  }

  void _setupPaints() {
    final cs = Theme.of(context).colorScheme;
    _linePaint = PerformanceOptimizations.getCachedPaint(
      key: 'md_line',
      color: cs.outline.withOpacity(0.3),
      strokeWidth: 1,
    );
    _cellBgPaint = PerformanceOptimizations.getCachedPaint(
      key: 'md_cell_bg',
      color: cs.surface,
      style: PaintingStyle.fill,
    );
    _selectionPaint = PerformanceOptimizations.getCachedPaint(
      key: 'md_sel',
      color: cs.primary,
      strokeWidth: 3,
    );
    _errorPaint = PerformanceOptimizations.getCachedPaint(
      key: 'md_err',
      color: cs.error,
      strokeWidth: 2,
    );
  }

  void _updateBoard() {
    if (widget.puzzle?.state is MathdokuBoard) {
      _board = widget.puzzle!.state as MathdokuBoard;
    } else {
      // Fallback empty board now defaults to 9x9 to match new target size.
      _board = MathdokuBoard.empty(size: 9, cages: const []);
    }
  }

  Offset? _hitTest(Offset position) =>
      PainterUtils.hitTestGrid(position: position, metrics: _gridMetrics);

  @override
  Widget buildPuzzleContent(BuildContext context, Size size) {
    _gridMetrics = PainterUtils.calculateGridMetrics(
      availableSize: size,
      rows: _board.size,
      columns: _board.size,
      padding: 16,
      cellSpacing: 1,
    );
    return CustomPaint(
      painter: _MathdokuContentPainter(
        board: _board,
        metrics: _gridMetrics,
        cellBgPaint: _cellBgPaint,
        theme: Theme.of(context),
      ),
      size: size,
    );
  }

  @override
  Widget buildGridBackground(BuildContext context, Size size) {
    // Initialize metrics before painting background
    _gridMetrics = PainterUtils.calculateGridMetrics(
      availableSize: size,
      rows: _board.size,
      columns: _board.size,
      padding: 16,
      cellSpacing: 1,
    );
    return CustomPaint(
      painter: PuzzleGridPainter(metrics: _gridMetrics, linePaint: _linePaint),
      size: size,
    );
  }

  @override
  Widget buildCellContent(BuildContext context, Offset position, Size cellSize) =>
      const SizedBox.shrink();

  @override
  Widget buildSelectionHighlight(BuildContext context, Offset position, Size cellSize) {
    final rect = PainterUtils.getCellRect(gridPosition: position, metrics: _gridMetrics);
    return AnimatedBuilder(
      animation: selectionAnimation,
      builder: (context, _) => CustomPaint(
        painter: _CellHighlightPainter(
          cellRect: rect,
          highlightPaint: _selectionPaint,
          animationValue: selectionAnimation.value,
          borderRadius: 3,
        ),
      ),
    );
  }

  @override
  Widget buildErrorHighlight(BuildContext context, Offset position, Size cellSize) {
    final rect = PainterUtils.getCellRect(gridPosition: position, metrics: _gridMetrics);
    return AnimatedBuilder(
      animation: errorAnimation,
      builder: (context, _) => CustomPaint(
        painter: _CellHighlightPainter(
          cellRect: rect,
          highlightPaint: _errorPaint,
          animationValue: errorAnimation.value,
          borderRadius: 3,
        ),
      ),
    );
  }

  @override
  void onTap(Offset position) {
    final gp = _hitTest(position);
    if (gp == null) return;
    setState(() {
      super.onTap(position);
    });
  }

  @override
  void onKeyEvent(KeyEvent event) {
    super.onKeyEvent(event);
    if (event is! KeyDownEvent || selectedPosition == null) return;
    final row = selectedPosition!.dy.toInt();
    final col = selectedPosition!.dx.toInt();

    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      widget.onMove?.call(MathdokuMove(row: row, col: col, value: 0));
      return;
    }
    final digit = int.tryParse(event.logicalKey.keyLabel);
    if (digit != null && digit >= 1 && digit <= _board.size) {
      widget.onMove?.call(MathdokuMove(row: row, col: col, value: digit));
    }
  }
}

class MathdokuRendererWidget extends PuzzleRendererWidget {
  const MathdokuRendererWidget({
    super.key,
    required super.puzzle,
    super.gameState,
    super.onCellSelected,
    super.onMove,
    super.onError,
    super.hintCells,
    super.hintAnimationValue,
  });

  @override
  State<MathdokuRendererWidget> createState() => MathdokuRenderer();
}

class _MathdokuContentPainter extends CustomPainter {
  const _MathdokuContentPainter({
    required this.board,
    required this.metrics,
    required this.cellBgPaint,
    required this.theme,
  });

  final MathdokuBoard board;
  final GridMetrics metrics;
  final Paint cellBgPaint;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final valueStyle = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final cageStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      fontSize: (board.size >= 9) ? 10 : null,
    );

    // Precompute cage mapping & top-left for label placement
    final Map<int, Offset> cageTopLeft = <int, Offset>{};
    for (final MathdokuCage cage in board.cages) {
      int topIndex = cage.cells.reduce((int a, int b) => a < b ? a : b);
      final int r = topIndex ~/ board.size;
      final int c = topIndex % board.size;
      cageTopLeft[cage.id] = Offset(c.toDouble(), r.toDouble());
    }

    // Generate stable pastel colors per cage using HSL seeded by cage id.
    Color cageColorFor(int cageId) {
      final double hue = (cageId * 37) % 360; // pseudo-random but deterministic
      final bool isDark = theme.brightness == Brightness.dark;
      final double lightness = isDark ? 0.25 : 0.88;
      final double saturation = 0.45;
      return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
    }

    final Paint borderPaint = Paint()
      ..color = theme.colorScheme.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    // Build quick lookup of cage id per cell for border decisions.
    final List<int> cageIdByCell = List<int>.filled(board.cellCount, -1);
    for (final MathdokuCage cage in board.cages) {
      for (final int idx in cage.cells) {
        cageIdByCell[idx] = cage.id;
      }
    }

    // First pass: paint tinted backgrounds & values & labels.
    for (int row = 0; row < board.size; row++) {
      for (int col = 0; col < board.size; col++) {
        final Rect rect = PainterUtils.getCellRect(
          gridPosition: Offset(col.toDouble(), row.toDouble()),
          metrics: metrics,
        );
        final MathdokuCage cage = board.cageAt(row, col);
        final Color bgColor = cageColorFor(cage.id);
        final Paint tinted = Paint()
          ..color = bgColor.withOpacity(0.92)
          ..style = PaintingStyle.fill;
        PainterUtils.paintCellBackground(
          canvas: canvas,
          cellRect: rect,
          backgroundPaint: tinted,
          borderRadius: 4,
        );

        final int v = board.cellAt(row, col);
        if (v != 0 && valueStyle != null) {
          PainterUtils.paintCellText(
            canvas: canvas,
            cellRect: rect,
            text: v.toString(),
            textStyle: valueStyle,
          );
        }

        // Cage label top-left
        final bool isTopLeft = cageTopLeft[cage.id] == Offset(col.toDouble(), row.toDouble());
        if (isTopLeft && cageStyle != null) {
          final String label = '${cage.target}${cage.operation.symbol}';
          final TextPainter tp = TextPainter(
            text: TextSpan(text: label, style: cageStyle),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
          )..layout(maxWidth: rect.width - 2);
          tp.paint(canvas, Offset(rect.left + 3, rect.top + 1));
        }
      }
    }

    // Second pass: draw cage borders where adjacent cells have different cage ids.
    for (int row = 0; row < board.size; row++) {
      for (int col = 0; col < board.size; col++) {
        final int index = row * board.size + col;
        final int cageId = cageIdByCell[index];
        final Rect rect = PainterUtils.getCellRect(
          gridPosition: Offset(col.toDouble(), row.toDouble()),
          metrics: metrics,
        );

        void drawEdge(Offset a, Offset b) {
          canvas.drawLine(a, b, borderPaint);
        }

        // Up
        if (row == 0 || cageIdByCell[index - board.size] != cageId) {
          drawEdge(rect.topLeft, rect.topRight);
        }
        // Left
        if (col == 0 || cageIdByCell[index - 1] != cageId) {
          drawEdge(rect.topLeft, rect.bottomLeft);
        }
        // Right
        if (col == board.size - 1 || cageIdByCell[index + 1] != cageId) {
          drawEdge(rect.topRight, rect.bottomRight);
        }
        // Down
        if (row == board.size - 1 || cageIdByCell[index + board.size] != cageId) {
          drawEdge(rect.bottomLeft, rect.bottomRight);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MathdokuContentPainter oldDelegate) {
    return oldDelegate.board != board || oldDelegate.metrics != metrics || oldDelegate.theme != theme;
  }
}

class _CellHighlightPainter extends CustomPainter {
  const _CellHighlightPainter({
    required this.cellRect,
    required this.highlightPaint,
    required this.animationValue,
    this.borderRadius = 3.0,
  });

  final Rect cellRect;
  final Paint highlightPaint;
  final double animationValue;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    PainterUtils.paintSelectionHighlight(
      canvas: canvas,
      cellRect: cellRect,
      highlightPaint: highlightPaint,
      animationValue: animationValue,
      borderRadius: borderRadius,
    );
  }

  @override
  bool shouldRepaint(covariant _CellHighlightPainter oldDelegate) {
    return oldDelegate.cellRect != cellRect ||
        oldDelegate.highlightPaint != highlightPaint ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.borderRadius != borderRadius;
  }
}
