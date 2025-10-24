import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/puzzle_core.dart';

import 'painter_utils.dart';
import 'puzzle_renderer.dart';
import 'performance_optimizations.dart';

class TakuzuRenderer extends PuzzleRenderer<TakuzuRendererWidget>
    with PerformanceOptimizedRendering {
  late TakuzuBoard _board;
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
      key: 'tz_line',
      color: cs.outline.withOpacity(0.3),
      strokeWidth: 1,
    );
    _cellBgPaint = PerformanceOptimizations.getCachedPaint(
      key: 'tz_cell_bg',
      color: cs.surface,
      style: PaintingStyle.fill,
    );
    _selectionPaint = PerformanceOptimizations.getCachedPaint(
      key: 'tz_sel',
      color: cs.primary,
      strokeWidth: 3,
    );
    _errorPaint = PerformanceOptimizations.getCachedPaint(
      key: 'tz_err',
      color: cs.error,
      strokeWidth: 2,
    );
  }

  void _updateBoard() {
    if (widget.puzzle?.state is TakuzuBoard) {
      _board = widget.puzzle!.state as TakuzuBoard;
    } else {
      _board = TakuzuBoard.empty(6);
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
      painter: _TakuzuContentPainter(
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
    final row = gp.dy.toInt();
    final col = gp.dx.toInt();
    final current = _board.cellAt(row, col);
    int next;
    if (current == TakuzuBoard.emptyValue) {
      next = 1;
    } else if (current == 1) {
      next = 0;
    } else {
      next = TakuzuBoard.emptyValue;
    }
    widget.onMove?.call(TakuzuMove(row: row, col: col, value: next));
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
      widget.onMove?.call(TakuzuMove(row: row, col: col, value: TakuzuBoard.emptyValue));
      return;
    }
    final digit = int.tryParse(event.logicalKey.keyLabel);
    if (digit != null && (digit == 0 || digit == 1)) {
      widget.onMove?.call(TakuzuMove(row: row, col: col, value: digit));
    }
  }
}

class TakuzuRendererWidget extends PuzzleRendererWidget {
  const TakuzuRendererWidget({
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
  State<TakuzuRendererWidget> createState() => TakuzuRenderer();
}

class _TakuzuContentPainter extends CustomPainter {
  const _TakuzuContentPainter({
    required this.board,
    required this.metrics,
    required this.cellBgPaint,
    required this.theme,
  });

  final TakuzuBoard board;
  final GridMetrics metrics;
  final Paint cellBgPaint;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final valueStyle = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );
    for (int row = 0; row < board.size; row++) {
      for (int col = 0; col < board.size; col++) {
        final rect = PainterUtils.getCellRect(
          gridPosition: Offset(col.toDouble(), row.toDouble()),
          metrics: metrics,
        );
        PainterUtils.paintCellBackground(
          canvas: canvas,
          cellRect: rect,
          backgroundPaint: cellBgPaint,
          borderRadius: 3,
        );
        final v = board.cellAt(row, col);
        if (v != TakuzuBoard.emptyValue && valueStyle != null) {
          PainterUtils.paintCellText(
            canvas: canvas,
            cellRect: rect,
            text: v.toString(),
            textStyle: valueStyle,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TakuzuContentPainter oldDelegate) {
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
