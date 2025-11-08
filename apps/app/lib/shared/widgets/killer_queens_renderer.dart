import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import 'painter_utils.dart';
import 'performance_optimizations.dart';
import 'puzzle_renderer.dart';

class KillerQueensRenderer extends PuzzleRenderer<KillerQueensRendererWidget>
    with PerformanceOptimizedRendering {
  late core.KillerQueensBoard _board;
  late GridMetrics _metrics;

  late Paint _gridPaint;
  late Paint _cellPaint;
  late Paint _blockedPaint;
  late Paint _fixedPaint;
  late Paint _selectionPaint;
  late Paint _hintPaint;

  @override
  void initState() {
    super.initState();
    _updateBoard();
  }

  @override
  void didUpdateWidget(covariant KillerQueensRendererWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.puzzle?.state != oldWidget.puzzle?.state) {
      _updateBoard();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupPaints();
  }

  void _setupPaints() {
    final ColorScheme colors = Theme.of(context).colorScheme;
    _gridPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kq_grid',
      color: colors.outline.withOpacity(0.35),
      strokeWidth: 1.0,
    );
    _cellPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kq_cell',
      color: colors.surface,
      style: PaintingStyle.fill,
    );
    _blockedPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kq_blocked',
      color: colors.surfaceVariant.withOpacity(0.8),
      style: PaintingStyle.fill,
    );
    _fixedPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kq_fixed',
      color: colors.primary.withOpacity(0.12),
      style: PaintingStyle.fill,
    );
    _selectionPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kq_sel',
      color: colors.primary,
      strokeWidth: 3.0,
    );
    _hintPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kq_hint',
      color: colors.secondary.withOpacity(0.18),
      style: PaintingStyle.fill,
    );
  }

  void _updateBoard() {
    if (widget.puzzle?.state is core.KillerQueensBoard) {
      _board = widget.puzzle!.state as core.KillerQueensBoard;
    } else {
      _board = core.KillerQueensBoard.empty(size: 6);
    }
  }

  Offset? _hitTest(Offset position) {
    return PainterUtils.hitTestGrid(position: position, metrics: _metrics);
  }

  @override
  Widget buildPuzzleContent(BuildContext context, Size size) {
    _metrics = PainterUtils.calculateGridMetrics(
      availableSize: size,
      rows: _board.size,
      columns: _board.size,
      padding: 16,
      cellSpacing: 1,
    );

    return CustomPaint(
      painter: _KillerQueensContentPainter(
        board: _board,
        metrics: _metrics,
        cellPaint: _cellPaint,
        blockedPaint: _blockedPaint,
        fixedPaint: _fixedPaint,
        hintPaint: _hintPaint,
        theme: Theme.of(context),
        hintCells: widget.hintCells,
        hintProgress: widget.hintAnimationValue,
      ),
      size: size,
    );
  }

  @override
  Widget buildGridBackground(BuildContext context, Size size) {
    _metrics = PainterUtils.calculateGridMetrics(
      availableSize: size,
      rows: _board.size,
      columns: _board.size,
      padding: 16,
      cellSpacing: 1,
    );
    return CustomPaint(
      painter: PuzzleGridPainter(metrics: _metrics, linePaint: _gridPaint),
      size: size,
    );
  }

  @override
  Widget buildSelectionHighlight(
    BuildContext context,
    Offset position,
    Size cellSize,
  ) {
    final Rect rect = PainterUtils.getCellRect(gridPosition: position, metrics: _metrics);
    return AnimatedBuilder(
      animation: selectionAnimation,
      builder: (BuildContext context, _) => CustomPaint(
        painter: _CellHighlightPainter(
          rect: rect,
          paint: _selectionPaint,
          progress: selectionAnimation.value,
        ),
      ),
    );
  }

  @override
  Widget buildErrorHighlight(
    BuildContext context,
    Offset position,
    Size cellSize,
  ) => const SizedBox.shrink();

  @override
  void onTap(Offset position) {
    final Offset? gridPos = _hitTest(position);
    if (gridPos == null) return;
    final int row = gridPos.dy.toInt();
    final int col = gridPos.dx.toInt();
    final int index = row * _board.size + col;
    if (_board.blocked[index] || _board.fixed[index]) {
      super.onTap(position);
      return;
    }
    final int currentValue = _board.cells[index];
    widget.onMove?.call(
      core.KillerQueensMove(row: row, col: col, value: currentValue == 1 ? 0 : 1),
    );
    super.onTap(position);
  }

  @override
  void onKeyEvent(KeyEvent event) {
    super.onKeyEvent(event);
    if (event is! KeyDownEvent || selectedPosition == null) return;
    final int row = selectedPosition!.dy.toInt();
    final int col = selectedPosition!.dx.toInt();
    final int index = row * _board.size + col;
    if (_board.blocked[index] || _board.fixed[index]) {
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      final int currentValue = _board.cells[index];
      widget.onMove?.call(
        core.KillerQueensMove(row: row, col: col, value: currentValue == 1 ? 0 : 1),
      );
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_board.cells[index] != 0) {
        widget.onMove?.call(core.KillerQueensMove(row: row, col: col, value: 0));
      }
    }
  }
}

class KillerQueensRendererWidget extends PuzzleRendererWidget {
  const KillerQueensRendererWidget({
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
  State<KillerQueensRendererWidget> createState() => KillerQueensRenderer();
}

class _KillerQueensContentPainter extends CustomPainter {
  _KillerQueensContentPainter({
    required this.board,
    required this.metrics,
    required this.cellPaint,
    required this.blockedPaint,
    required this.fixedPaint,
    required this.hintPaint,
    required this.theme,
    required this.hintCells,
    required this.hintProgress,
  });

  final core.KillerQueensBoard board;
  final GridMetrics metrics;
  final Paint cellPaint;
  final Paint blockedPaint;
  final Paint fixedPaint;
  final Paint hintPaint;
  final ThemeData theme;
  final List<Offset>? hintCells;
  final double hintProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final TextStyle textStyle = theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ) ??
        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    final Paint cagePaint = Paint()
      ..color = theme.colorScheme.outline.withOpacity(0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final Set<int> hintIndices = <int>{};
    if (hintCells != null) {
      for (final Offset offset in hintCells!) {
        final int row = offset.dy.toInt();
        final int col = offset.dx.toInt();
        if (row >= 0 && row < board.size && col >= 0 && col < board.size) {
          hintIndices.add(row * board.size + col);
        }
      }
    }

    for (int row = 0; row < board.size; row++) {
      for (int col = 0; col < board.size; col++) {
        final Rect rect = PainterUtils.getCellRect(
          gridPosition: Offset(col.toDouble(), row.toDouble()),
          metrics: metrics,
        );
        canvas.drawRect(rect, cellPaint);

        final int index = row * board.size + col;
        if (board.blocked[index]) {
          canvas.drawRect(rect, blockedPaint);
        } else if (board.fixed[index]) {
          canvas.drawRect(rect, fixedPaint);
        }

        if (hintIndices.contains(index) && hintProgress > 0) {
          canvas.drawRect(rect, hintPaint);
        }

        if (board.cells[index] == 1) {
          textPainter.text = TextSpan(text: 'Q', style: textStyle);
          textPainter.layout(minWidth: 0, maxWidth: rect.width);
          final Offset textOffset = Offset(
            rect.left + (rect.width - textPainter.width) / 2,
            rect.top + (rect.height - textPainter.height) / 2,
          );
          textPainter.paint(canvas, textOffset);
        }
      }
    }

    // Draw cage boundaries
    for (int row = 0; row < board.size; row++) {
      for (int col = 0; col < board.size; col++) {
        final int index = row * board.size + col;
        if (board.blocked[index]) continue;
        final int cage = board.cageByCell[index];
        final Rect rect = PainterUtils.getCellRect(
          gridPosition: Offset(col.toDouble(), row.toDouble()),
          metrics: metrics,
        );

        // Top boundary
        final bool drawTop = row == 0 ||
            board.blocked[index - board.size] ||
            board.cageByCell[index - board.size] != cage;
        if (drawTop) {
          canvas.drawLine(rect.topLeft, rect.topRight, cagePaint);
        }

        // Left boundary
        final bool drawLeft = col == 0 ||
            board.blocked[index - 1] ||
            board.cageByCell[index - 1] != cage;
        if (drawLeft) {
          canvas.drawLine(rect.topLeft, rect.bottomLeft, cagePaint);
        }

        // Bottom boundary
        final bool drawBottom = row == board.size - 1 ||
            board.blocked[index + board.size] ||
            board.cageByCell[index + board.size] != cage;
        if (drawBottom) {
          canvas.drawLine(rect.bottomLeft, rect.bottomRight, cagePaint);
        }

        // Right boundary
        final bool drawRight = col == board.size - 1 ||
            board.blocked[index + 1] ||
            board.cageByCell[index + 1] != cage;
        if (drawRight) {
          canvas.drawLine(rect.topRight, rect.bottomRight, cagePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KillerQueensContentPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.hintCells != hintCells ||
        oldDelegate.hintProgress != hintProgress;
  }
}

class _CellHighlightPainter extends CustomPainter {
  _CellHighlightPainter({
    required this.rect,
    required this.paint,
    required this.progress,
  });

  final Rect rect;
  final Paint paint;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final RRect rRect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(covariant _CellHighlightPainter oldDelegate) {
    return oldDelegate.rect != rect ||
        oldDelegate.paint != paint ||
        oldDelegate.progress != progress;
  }
}
