import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/puzzle_core.dart';

import 'painter_utils.dart';
import 'puzzle_renderer.dart';
import 'performance_optimizations.dart';

/// Nonogram puzzle renderer using the common PuzzleRenderer pattern.
class NonogramRenderer extends PuzzleRenderer<NonogramRendererWidget>
    with PerformanceOptimizedRendering {
  late NonogramBoard _board;
  late GridMetrics _gridMetrics;

  // Paint cache
  late Paint _linePaint;
  late Paint _filledPaint;
  late Paint _emptyPaint;
  late Paint _selectionPaint;
  late Paint _errorPaint;
  late Paint _hintPaint;

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    _linePaint = PerformanceOptimizations.getCachedPaint(
      key: 'nonogram_line',
      color: colorScheme.outline.withOpacity(0.3),
      strokeWidth: 1,
    );
    _filledPaint = PerformanceOptimizations.getCachedPaint(
      key: 'nonogram_filled',
      color: colorScheme.primary.withOpacity(0.9),
      style: PaintingStyle.fill,
    );
    _emptyPaint = PerformanceOptimizations.getCachedPaint(
      key: 'nonogram_empty',
      color: colorScheme.outline.withOpacity(0.2),
      style: PaintingStyle.stroke,
      strokeWidth: 1.5,
    );
    _selectionPaint = PerformanceOptimizations.getCachedPaint(
      key: 'nonogram_selection',
      color: colorScheme.secondary,
      style: PaintingStyle.stroke,
      strokeWidth: 3,
    );
    _errorPaint = PerformanceOptimizations.getCachedPaint(
      key: 'nonogram_error',
      color: colorScheme.error,
      style: PaintingStyle.stroke,
      strokeWidth: 2,
    );
    _hintPaint = PerformanceOptimizations.getCachedPaint(
      key: 'nonogram_hint',
      color: colorScheme.secondary.withOpacity(0.6),
      style: PaintingStyle.fill,
    );
  }

  void _updateBoard() {
    if (widget.puzzle?.state is NonogramBoard) {
      _board = widget.puzzle!.state as NonogramBoard;
    } else {
      // Fallback empty board if state is not available yet
      _board = NonogramBoard.empty(
        width: 5,
        height: 5,
        rowClues: List.generate(5, (_) => <int>[]),
        columnClues: List.generate(5, (_) => <int>[]),
      );
    }
  }

  @override
  void didUpdateWidget(covariant NonogramRendererWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.puzzle != oldWidget.puzzle) {
      _updateBoard();
    }
  }

  Offset? _hitTest(Offset position) {
    return PainterUtils.hitTestGrid(position: position, metrics: _gridMetrics);
  }

  // Note: keyboard arrow navigation is handled by the base class; for now we
  // rely on tap interaction for selection in Nonogram.

  @override
  Widget buildPuzzleContent(BuildContext context, Size size) {
    _gridMetrics = PainterUtils.calculateGridMetrics(
      availableSize: size,
      rows: _board.height,
      columns: _board.width,
      padding: 16,
      cellSpacing: 1,
    );

    return CustomPaint(
      painter: _NonogramContentPainter(
        board: _board,
        metrics: _gridMetrics,
        filledPaint: _filledPaint,
        emptyPaint: _emptyPaint,
        theme: Theme.of(context),
      ),
      size: size,
    );
  }

  @override
  Widget buildGridBackground(BuildContext context, Size size) {
    return CustomPaint(
      painter: PuzzleGridPainter(
        metrics: _gridMetrics,
        linePaint: _linePaint,
      ),
      size: size,
    );
  }

  @override
  Widget buildCellContent(BuildContext context, Offset position, Size cellSize) {
    // We paint entire board in buildPuzzleContent; per-cell overlay not needed.
    return const SizedBox.shrink();
  }

  @override
  Widget buildSelectionHighlight(BuildContext context, Offset position, Size cellSize) {
    final cellRect = PainterUtils.getCellRect(gridPosition: position, metrics: _gridMetrics);
    return AnimatedBuilder(
      animation: selectionAnimation,
      builder: (context, _) => CustomPaint(
        painter: _CellHighlightPainter(
          cellRect: cellRect,
          highlightPaint: _selectionPaint,
          animationValue: selectionAnimation.value,
          borderRadius: 2,
        ),
      ),
    );
  }

  @override
  Widget buildErrorHighlight(BuildContext context, Offset position, Size cellSize) {
    final cellRect = PainterUtils.getCellRect(gridPosition: position, metrics: _gridMetrics);
    return AnimatedBuilder(
      animation: errorAnimation,
      builder: (context, _) => CustomPaint(
        painter: _CellHighlightPainter(
          cellRect: cellRect,
          highlightPaint: _errorPaint,
          animationValue: errorAnimation.value,
          borderRadius: 2,
        ),
      ),
    );
  }

  @override
  Widget buildHintHighlight(BuildContext context, Offset position, Size cellSize) {
    final cellRect = PainterUtils.getCellRect(gridPosition: position, metrics: _gridMetrics);
    final animVal = (widget.hintAnimationValue).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = _hintPaint.color.withOpacity(_hintPaint.color.opacity * (0.4 + 0.6 * animVal))
      ..style = PaintingStyle.fill;
    return CustomPaint(
      painter: CellBackgroundPainter(
        cellRect: cellRect,
        backgroundPaint: paint,
        borderRadius: 2,
      ),
    );
  }

  // Input handling: clicking toggles cell state: null -> 1 (filled) -> 0 (empty/cross) -> null
  @override
  void onTap(Offset position) {
    final gp = _hitTest(position);
    if (gp == null) return;
    final row = gp.dy.toInt();
    final col = gp.dx.toInt();
    final current = _board.cellAt(row, col);
    int? next;
    if (current == null) {
      next = 1; // filled
    } else if (current == 1) {
      next = 0; // marked empty
    } else {
      next = null;
    }
    widget.onMove?.call(NonogramMove(row: row, col: col, value: next));
    setState(() {
      // local selection feedback
      super.onTap(position);
    });
  }

  @override
  void onKeyEvent(KeyEvent event) {
    super.onKeyEvent(event);
    if (event is! KeyDownEvent || selectedPosition == null) return;
    final row = selectedPosition!.dy.toInt();
    final col = selectedPosition!.dx.toInt();

    if (event.logicalKey == LogicalKeyboardKey.space) {
      // toggle null/filled
      final current = _board.cellAt(row, col);
      final next = (current == 1) ? null : 1;
      widget.onMove?.call(NonogramMove(row: row, col: col, value: next));
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      widget.onMove?.call(const NonogramMove(row: 0, col: 0, value: null).copyWith(row: row, col: col));
      return;
    }
    // 0/1 direct entry
    final digit = int.tryParse(event.logicalKey.keyLabel);
    if (digit != null && (digit == 0 || digit == 1)) {
      widget.onMove?.call(NonogramMove(row: row, col: col, value: digit));
    }
  }
}

class NonogramRendererWidget extends PuzzleRendererWidget {
  const NonogramRendererWidget({
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
  State<NonogramRendererWidget> createState() => NonogramRenderer();
}

class _NonogramContentPainter extends CustomPainter {
  const _NonogramContentPainter({
    required this.board,
    required this.metrics,
    required this.filledPaint,
    required this.emptyPaint,
    required this.theme,
  });

  final NonogramBoard board;
  final GridMetrics metrics;
  final Paint filledPaint;
  final Paint emptyPaint;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    for (int row = 0; row < board.height; row++) {
      for (int col = 0; col < board.width; col++) {
        final rect = PainterUtils.getCellRect(
          gridPosition: Offset(col.toDouble(), row.toDouble()),
          metrics: metrics,
        );
        final value = board.cellAt(row, col);
        if (value == 1) {
          PainterUtils.paintCellBackground(
            canvas: canvas,
            cellRect: rect,
            backgroundPaint: filledPaint,
            borderRadius: 2,
          );
        } else if (value == 0) {
          // draw a small cross to indicate empty
          final p1 = Offset(rect.left + 4, rect.top + 4);
          final p2 = Offset(rect.right - 4, rect.bottom - 4);
          final p3 = Offset(rect.right - 4, rect.top + 4);
          final p4 = Offset(rect.left + 4, rect.bottom - 4);
          canvas.drawLine(p1, p2, emptyPaint);
          canvas.drawLine(p3, p4, emptyPaint);
        }
      }
    }
    // Optional TODO: render clues around grid margins (future enhancement)
  }

  @override
  bool shouldRepaint(covariant _NonogramContentPainter oldDelegate) {
    return oldDelegate.board != board || oldDelegate.metrics != metrics || oldDelegate.theme != theme;
  }
}

extension on NonogramMove {
  NonogramMove copyWith({int? row, int? col, int? value}) => NonogramMove(
        row: row ?? this.row,
        col: col ?? this.col,
        value: value ?? this.value,
      );
}

class _CellHighlightPainter extends CustomPainter {
  const _CellHighlightPainter({
    required this.cellRect,
    required this.highlightPaint,
    required this.animationValue,
    this.borderRadius = 2.0,
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
