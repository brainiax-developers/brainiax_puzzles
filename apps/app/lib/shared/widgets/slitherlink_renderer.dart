import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/puzzle_core.dart';

import 'painter_utils.dart';
import 'puzzle_renderer.dart';
import 'performance_optimizations.dart';

class SlitherlinkRenderer extends PuzzleRenderer<SlitherlinkRendererWidget>
    with PerformanceOptimizedRendering {
  late SlitherlinkBoard _board;
  late GridMetrics _gridMetrics;
  // No direct dependency on internal topology; use simple index math.

  late Paint _linePaint;
  late Paint _edgeOnPaint;
  late Paint _edgeOffPaint;
  // Selection/error paints not used for edge highlighting in this minimal renderer.

  static const double _edgeThickness = 3.0;
  static const double _hitTolerance = 10.0; // px tolerance to select an edge

  @override
  void initState() {
    super.initState();
    _updateBoard();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Theme.of(context) and other inherited lookups must occur here or in build
    _setupPaints();
  }

  void _setupPaints() {
    final cs = Theme.of(context).colorScheme;
    _linePaint = PerformanceOptimizations.getCachedPaint(
      key: 'sl_line',
      color: cs.outline.withOpacity(0.3),
      strokeWidth: 1,
    );
    _edgeOnPaint = PerformanceOptimizations.getCachedPaint(
      key: 'sl_edge_on',
      color: cs.primary,
      strokeWidth: _edgeThickness,
    );
    _edgeOffPaint = PerformanceOptimizations.getCachedPaint(
      key: 'sl_edge_off',
      color: cs.outline.withOpacity(0.2),
      strokeWidth: 1.5,
    );
  }

  void _updateBoard() {
    if (widget.puzzle?.state is SlitherlinkBoard) {
      _board = widget.puzzle!.state as SlitherlinkBoard;
    } else {
      _board = SlitherlinkBoard.empty(width: 5, height: 5, clues: List<int?>.filled(25, null));
    }
  }

  @override
  void didUpdateWidget(covariant SlitherlinkRendererWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.puzzle != oldWidget.puzzle) {
      _updateBoard();
    }
  }

  Offset? _hitTest(Offset position) {
    // First check if inside grid rect; if near a grid line, return closest edge as a special encoded Offset
    if (!_gridMetrics.gridRect.inflate(_hitTolerance).contains(position)) return null;

    final cellSize = _gridMetrics.cellSize.width + _gridMetrics.cellSpacing;
    final rel = position - _gridMetrics.gridOffset;
    // Compute nearest grid lines
    final colF = rel.dx / cellSize;
    final rowF = rel.dy / cellSize;
    final col = colF.floor();
    final row = rowF.floor();

    // Distances to nearest vertical and horizontal lines
    final distToV = (colF - col).abs() * cellSize;
    final distToH = (rowF - row).abs() * cellSize;

    if (distToH < distToV && distToH <= _hitTolerance) {
      // horizontal edge at row line between (row, col) .. (row, col+1)
      final edgeRow = row.clamp(0, _board.height);
      final edgeCol = col.clamp(0, _board.width - 1);
      final index = _horizontalEdgeIndex(edgeRow, edgeCol);
      return Offset(index.toDouble(), -1); // encode horizontal by dy = -1
    } else if (distToV <= _hitTolerance) {
      // vertical edge at col line between (row, col)
      final edgeRow = row.clamp(0, _board.height - 1);
      final edgeCol = col.clamp(0, _board.width);
      final index = _verticalEdgeIndex(edgeRow, edgeCol);
      return Offset(index.toDouble(), -2); // encode vertical by dy = -2
    }
    return null;
  }

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
      painter: _SlitherlinkContentPainter(
        board: _board,
        metrics: _gridMetrics,
        linePaint: _linePaint,
        edgeOnPaint: _edgeOnPaint,
        edgeOffPaint: _edgeOffPaint,
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
  Widget buildCellContent(BuildContext context, Offset position, Size cellSize) {
    return const SizedBox.shrink();
  }

  @override
  Widget buildSelectionHighlight(BuildContext context, Offset position, Size cellSize) {
    // Selection for edges: we don't use the cell highlight here.
    return const SizedBox.shrink();
  }

  @override
  Widget buildErrorHighlight(BuildContext context, Offset position, Size cellSize) {
    return const SizedBox.shrink();
  }

  @override
  void onTap(Offset position) {
    final hit = _hitTest(position);
    if (hit == null) return;
    final edgeIndex = hit.dx.toInt();
    final isHorizontal = hit.dy == -1;

    // Cycle Unknown -> On -> Off -> Unknown
    final current = _board.edges[edgeIndex];
    int next;
    if (current == SlitherlinkBoard.edgeUnknown) {
      next = SlitherlinkBoard.edgeOn;
    } else if (current == SlitherlinkBoard.edgeOn) {
      next = SlitherlinkBoard.edgeOff;
    } else {
      next = SlitherlinkBoard.edgeUnknown;
    }

    // Map edge index back to row/col for move API
    if (isHorizontal) {
      // derive row/col by scanning; more efficient mapping could be added if needed
      // horizontal index formula: row * width + col
      final row = (edgeIndex ~/ _board.width);
      final col = edgeIndex % _board.width;
      widget.onMove?.call(SlitherlinkMove(horizontal: true, row: row, col: col, value: next));
    } else {
      final base = _horizontalEdgeCount;
      final idx = edgeIndex - base;
      final row = idx ~/ (_board.width + 1);
      final col = idx % (_board.width + 1);
      widget.onMove?.call(SlitherlinkMove(horizontal: false, row: row, col: col, value: next));
    }
  }

  int get _horizontalEdgeCount => (_board.height + 1) * _board.width;
  int _horizontalEdgeIndex(int row, int col) => row * _board.width + col;
  int _verticalEdgeIndex(int row, int col) => _horizontalEdgeCount + row * (_board.width + 1) + col;
}

class SlitherlinkRendererWidget extends PuzzleRendererWidget {
  const SlitherlinkRendererWidget({
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
  State<SlitherlinkRendererWidget> createState() => SlitherlinkRenderer();
}

class _SlitherlinkContentPainter extends CustomPainter {
  const _SlitherlinkContentPainter({
    required this.board,
    required this.metrics,
    required this.linePaint,
    required this.edgeOnPaint,
    required this.edgeOffPaint,
    required this.theme,
  });

  final SlitherlinkBoard board;
  final GridMetrics metrics;
  final Paint linePaint;
  final Paint edgeOnPaint;
  final Paint edgeOffPaint;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw clues inside cells
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.8),
      fontWeight: FontWeight.w600,
    );
    for (int row = 0; row < board.height; row++) {
      for (int col = 0; col < board.width; col++) {
        final rect = PainterUtils.getCellRect(
          gridPosition: Offset(col.toDouble(), row.toDouble()),
          metrics: metrics,
        );
        final clue = board.clues[board.cellIndex(row, col)];
        if (clue != null && textStyle != null) {
          PainterUtils.paintCellText(
            canvas: canvas,
            cellRect: rect,
            text: clue.toString(),
            textStyle: textStyle,
          );
        }
      }
    }

    // Draw edges
    final cell = metrics.cellSize.width + metrics.cellSpacing;
    final ox = metrics.gridOffset.dx;
    final oy = metrics.gridOffset.dy;

    // horizontal edges
    for (int r = 0; r <= board.height; r++) {
      for (int c = 0; c < board.width; c++) {
        final idx = r * board.width + c;
        final v = board.edges[idx];
        if (v == SlitherlinkBoard.edgeOn) {
          final y = oy + r * cell;
          final x1 = ox + c * cell;
          final x2 = x1 + metrics.cellSize.width;
          canvas.drawLine(Offset(x1, y), Offset(x2, y), edgeOnPaint);
        } else if (v == SlitherlinkBoard.edgeOff) {
          final y = oy + r * cell;
          final x = ox + c * cell + metrics.cellSize.width / 2;
          // small dot to indicate off (optional aesthetic)
          canvas.drawCircle(Offset(x, y), 1.5, edgeOffPaint);
        }
      }
    }

    // vertical edges
    for (int r = 0; r < board.height; r++) {
      for (int c = 0; c <= board.width; c++) {
        final idx = (_horizontalEdgeCount(board.height, board.width)) + r * (board.width + 1) + c;
        final v = board.edges[idx];
        if (v == SlitherlinkBoard.edgeOn) {
          final x = ox + c * cell;
          final y1 = oy + r * cell;
          final y2 = y1 + metrics.cellSize.height;
          canvas.drawLine(Offset(x, y1), Offset(x, y2), edgeOnPaint);
        } else if (v == SlitherlinkBoard.edgeOff) {
          final x = ox + c * cell;
          final y = oy + r * cell + metrics.cellSize.height / 2;
          canvas.drawCircle(Offset(x, y), 1.5, edgeOffPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SlitherlinkContentPainter oldDelegate) {
    return oldDelegate.board != board || oldDelegate.metrics != metrics || oldDelegate.theme != theme;
  }
  int _horizontalEdgeCount(int h, int w) => (h + 1) * w;
}
