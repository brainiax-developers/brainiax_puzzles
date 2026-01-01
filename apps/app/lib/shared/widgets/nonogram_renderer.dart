import 'dart:math' as math;

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
    final NonogramBoard? boardState =
        widget.puzzle?.state is NonogramBoard ? widget.puzzle!.state as NonogramBoard : null;
    _board = boardState ?? _emptyBoard();
  }

  NonogramBoard _emptyBoard() {
    return NonogramBoard.empty(
      width: 5,
      height: 5,
      rowClues: List.generate(5, (_) => <int>[]),
      columnClues: List.generate(5, (_) => <int>[]),
    );
  }

  @override
  void didUpdateWidget(covariant NonogramRendererWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final NonogramBoard? nextBoard =
        widget.puzzle?.state is NonogramBoard ? widget.puzzle!.state as NonogramBoard : null;
    final NonogramBoard? previousBoard =
        oldWidget.puzzle?.state is NonogramBoard ? oldWidget.puzzle!.state as NonogramBoard : null;
    if (nextBoard != null) {
      if (_board != nextBoard) {
        _board = nextBoard;
      }
    } else if (previousBoard != null) {
      _board = _emptyBoard();
    }
  }

  Offset? _hitTest(Offset position) {
    return PainterUtils.hitTestGrid(position: position, metrics: _gridMetrics);
  }

  _NonogramLayout _calculateLayout(Size size) {
    const double basePadding = 16.0;
    const double clueSpacing = 8.0;
    const double cellSpacing = 1.0;

    final ThemeData theme = Theme.of(context);
    final TextStyle baseStyle = theme.textTheme.bodySmall ??
        theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: 12);
    final TextStyle clueStyle = baseStyle.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.8),
    );

    double rowClueWidth = 0;
    final TextPainter rowPainter = TextPainter(
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    );
    for (int row = 0; row < _board.height; row++) {
      final List<int> clue =
          row < _board.rowClues.length ? _board.rowClues[row] : const <int>[];
      final String text = clue.isEmpty ? '0' : clue.join(' ');
      rowPainter.text = TextSpan(text: text, style: clueStyle);
      rowPainter.layout();
      rowClueWidth = math.max(rowClueWidth, rowPainter.width);
    }
    if (rowClueWidth == 0) {
      rowClueWidth = (clueStyle.fontSize ?? 12) * 1.2;
    }

    int maxColumnLines = 0;
    for (int col = 0; col < _board.width; col++) {
      final List<int> clue =
          col < _board.columnClues.length ? _board.columnClues[col] : const <int>[];
      final int lines = clue.isEmpty ? 1 : clue.length;
      if (lines > maxColumnLines) {
        maxColumnLines = lines;
      }
    }
    if (maxColumnLines == 0) {
      maxColumnLines = 1;
    }

    final TextPainter columnPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      text: TextSpan(text: '88', style: clueStyle),
    )..layout();
    final double lineHeight = columnPainter.height;
    final double columnClueHeight =
        (lineHeight * maxColumnLines) + clueSpacing * (maxColumnLines - 1);

    final double leftMargin = basePadding + rowClueWidth + clueSpacing;
    final double topMargin = basePadding + columnClueHeight + clueSpacing;
    final double rightMargin = basePadding;
    final double bottomMargin = basePadding;

    final double usableWidth = math.max(0, size.width - leftMargin - rightMargin);
    final double usableHeight = math.max(0, size.height - topMargin - bottomMargin);

    final double cellWidth = _board.width > 0
        ? (usableWidth - cellSpacing * (_board.width - 1)) / _board.width
        : 0;
    final double cellHeight = _board.height > 0
        ? (usableHeight - cellSpacing * (_board.height - 1)) / _board.height
        : 0;
    final double cellSize = math.max(0, math.min(cellWidth, cellHeight));

    final double gridWidth = cellSize * _board.width +
        cellSpacing * (_board.width > 0 ? _board.width - 1 : 0);
    final double gridHeight = cellSize * _board.height +
        cellSpacing * (_board.height > 0 ? _board.height - 1 : 0);

    final double offsetX = leftMargin + math.max(0, (usableWidth - gridWidth) / 2);
    final double offsetY = topMargin + math.max(0, (usableHeight - gridHeight) / 2);

    final GridMetrics metrics = GridMetrics(
      cellSize: Size(cellSize, cellSize),
      gridSize: Size(gridWidth, gridHeight),
      gridOffset: Offset(offsetX, offsetY),
      padding: basePadding,
      cellSpacing: cellSpacing,
      rows: _board.height,
      columns: _board.width,
    );

    return _NonogramLayout(
      metrics: metrics,
      rowClueWidth: rowClueWidth,
      clueSpacing: clueSpacing,
      clueTextStyle: clueStyle,
    );
  }

  // Note: keyboard arrow navigation is handled by the base class; for now we
  // rely on tap interaction for selection in Nonogram.

  @override
  Widget buildPuzzleContent(BuildContext context, Size size) {
    final _NonogramLayout layout = _calculateLayout(size);
    _gridMetrics = layout.metrics;

    return CustomPaint(
      painter: _NonogramContentPainter(
        board: _board,
        metrics: _gridMetrics,
        filledPaint: _filledPaint,
        emptyPaint: _emptyPaint,
        clueTextStyle: layout.clueTextStyle,
        rowClueWidth: layout.rowClueWidth,
        clueSpacing: layout.clueSpacing,
      ),
      size: size,
    );
  }

  @override
  Widget buildGridBackground(BuildContext context, Size size) {
    final _NonogramLayout layout = _calculateLayout(size);
    _gridMetrics = layout.metrics;
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
    // If crossMode is enabled, toggle cross (0) <-> empty (null). Otherwise
    // keep the previous cycle behavior: null -> filled (1) -> cross (0) -> null.
    if (widget.crossMode) {
      final current = _board.cellAt(row, col);
      final int? next = (current == 0) ? null : 0;
      widget.onMove?.call(NonogramMove(row: row, col: col, value: next));
    } else {
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
    }
    super.onTap(position);
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
    this.crossMode = false,
  });

  final bool crossMode;

  @override
  State<NonogramRendererWidget> createState() => NonogramRenderer();
}

class _NonogramContentPainter extends CustomPainter {
  const _NonogramContentPainter({
    required this.board,
    required this.metrics,
    required this.filledPaint,
    required this.emptyPaint,
    required this.clueTextStyle,
    required this.rowClueWidth,
    required this.clueSpacing,
  });

  final NonogramBoard board;
  final GridMetrics metrics;
  final Paint filledPaint;
  final Paint emptyPaint;
  final TextStyle clueTextStyle;
  final double rowClueWidth;
  final double clueSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final TextPainter rowPainter = TextPainter(
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    );
    final TextPainter columnPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (int row = 0; row < board.height; row++) {
      final List<int> rowClue = row < board.rowClues.length ? board.rowClues[row] : const <int>[];
      final String clueText = rowClue.isEmpty ? '0' : rowClue.join(' ');
      rowPainter.text = TextSpan(text: clueText, style: clueTextStyle);
      rowPainter.layout();
      final Rect cellRect = PainterUtils.getCellRect(
        gridPosition: Offset(0, row.toDouble()),
        metrics: metrics,
      );
      final double clueRight = metrics.gridOffset.dx - clueSpacing;
      final double clueLeft = clueRight - rowClueWidth;
      final double dx = clueLeft + (rowClueWidth - rowPainter.width);
      final double dy = cellRect.center.dy - rowPainter.height / 2;
      rowPainter.paint(canvas, Offset(dx, dy));
    }

    final double columnBaseline = metrics.gridOffset.dy - clueSpacing;
    for (int col = 0; col < board.width; col++) {
      final List<int> columnClue =
          col < board.columnClues.length ? board.columnClues[col] : const <int>[];
      final List<int> clues = columnClue.isEmpty ? const <int>[0] : columnClue;
      double y = columnBaseline;
      for (int i = clues.length - 1; i >= 0; i--) {
        final String clueText = clues[i].toString();
        columnPainter.text = TextSpan(text: clueText, style: clueTextStyle);
        columnPainter.layout();
        y -= columnPainter.height;
        final Rect cellRect = PainterUtils.getCellRect(
          gridPosition: Offset(col.toDouble(), 0),
          metrics: metrics,
        );
        final double dx = cellRect.center.dx - columnPainter.width / 2;
        columnPainter.paint(canvas, Offset(dx, y));
        y -= clueSpacing;
      }
    }

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
  }

  @override
  bool shouldRepaint(covariant _NonogramContentPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.metrics != metrics ||
        oldDelegate.filledPaint != filledPaint ||
        oldDelegate.emptyPaint != emptyPaint ||
        oldDelegate.clueTextStyle != clueTextStyle ||
        oldDelegate.rowClueWidth != rowClueWidth ||
        oldDelegate.clueSpacing != clueSpacing;
  }
}

extension on NonogramMove {
  NonogramMove copyWith({int? row, int? col, int? value}) => NonogramMove(
        row: row ?? this.row,
        col: col ?? this.col,
        value: value ?? this.value,
      );
}

class _NonogramLayout {
  const _NonogramLayout({
    required this.metrics,
    required this.rowClueWidth,
    required this.clueSpacing,
    required this.clueTextStyle,
  });

  final GridMetrics metrics;
  final double rowClueWidth;
  final double clueSpacing;
  final TextStyle clueTextStyle;
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
