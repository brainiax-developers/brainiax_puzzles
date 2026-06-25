import 'dart:async';
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

  // Error tracking for delayed visual feedback
  final Set<Offset> _violatingCells = {};
  Timer? _errorDisplayTimer;
  bool _showErrors = false;
  static const Duration _errorDisplayDelay = Duration(seconds: 3);

  @override
  void dispose() {
    _errorDisplayTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _updateBoard();
  }

  @override
  void didUpdateWidget(covariant TakuzuRendererWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // GeneratedPuzzle equality ignores the state field; compare state explicitly
    // so the renderer refreshes when moves update the board.
    final Object? newState = widget.puzzle?.state;
    final Object? oldState = oldWidget.puzzle?.state;
    if (widget.puzzle != oldWidget.puzzle || newState != oldState) {
      _updateBoard();
    }
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
      _scheduleValidation();
    } else {
      _board = TakuzuBoard.empty(6);
    }
  }

  /// Schedule delayed validation to detect rule violations
  void _scheduleValidation() {
    // Cancel any pending timer
    _errorDisplayTimer?.cancel();

    // Immediately check if board is now valid
    final violations = _detectViolations();
    if (violations.isEmpty && _showErrors) {
      // Board is valid now, clear errors immediately
      setState(() {
        _showErrors = false;
        _violatingCells.clear();
      });
      return;
    }

    // If there are violations, schedule delayed display
    if (violations.isNotEmpty) {
      _errorDisplayTimer = Timer(_errorDisplayDelay, () {
        if (mounted) {
          setState(() {
            _violatingCells.clear();
            _violatingCells.addAll(violations);
            _showErrors = true;
          });
        }
      });
    }
  }

  /// Detect all cells that violate Takuzu rules
  Set<Offset> _detectViolations() {
    final violations = <Offset>{};
    final size = _board.size;
    final limit = size ~/ 2;

    // Check rows for violations
    for (int row = 0; row < size; row++) {
      // Count 0s and 1s
      int zeros = 0, ones = 0;
      for (int col = 0; col < size; col++) {
        final value = _board.cellAt(row, col);
        if (value == 0) zeros++;
        if (value == 1) ones++;
      }

      // Mark cells if count violations
      if (zeros > limit) {
        for (int col = 0; col < size; col++) {
          if (_board.cellAt(row, col) == 0) {
            violations.add(Offset(col.toDouble(), row.toDouble()));
          }
        }
      }
      if (ones > limit) {
        for (int col = 0; col < size; col++) {
          if (_board.cellAt(row, col) == 1) {
            violations.add(Offset(col.toDouble(), row.toDouble()));
          }
        }
      }

      // Check for three consecutive identical values
      for (int col = 0; col <= size - 3; col++) {
        final a = _board.cellAt(row, col);
        final b = _board.cellAt(row, col + 1);
        final c = _board.cellAt(row, col + 2);
        if (a != TakuzuBoard.emptyValue && a == b && b == c) {
          violations.add(Offset(col.toDouble(), row.toDouble()));
          violations.add(Offset((col + 1).toDouble(), row.toDouble()));
          violations.add(Offset((col + 2).toDouble(), row.toDouble()));
        }
      }
    }

    // Check columns for violations
    for (int col = 0; col < size; col++) {
      // Count 0s and 1s
      int zeros = 0, ones = 0;
      for (int row = 0; row < size; row++) {
        final value = _board.cellAt(row, col);
        if (value == 0) zeros++;
        if (value == 1) ones++;
      }

      // Mark cells if count violations
      if (zeros > limit) {
        for (int row = 0; row < size; row++) {
          if (_board.cellAt(row, col) == 0) {
            violations.add(Offset(col.toDouble(), row.toDouble()));
          }
        }
      }
      if (ones > limit) {
        for (int row = 0; row < size; row++) {
          if (_board.cellAt(row, col) == 1) {
            violations.add(Offset(col.toDouble(), row.toDouble()));
          }
        }
      }

      // Check for three consecutive identical values
      for (int row = 0; row <= size - 3; row++) {
        final a = _board.cellAt(row, col);
        final b = _board.cellAt(row + 1, col);
        final c = _board.cellAt(row + 2, col);
        if (a != TakuzuBoard.emptyValue && a == b && b == c) {
          violations.add(Offset(col.toDouble(), row.toDouble()));
          violations.add(Offset(col.toDouble(), (row + 1).toDouble()));
          violations.add(Offset(col.toDouble(), (row + 2).toDouble()));
        }
      }
    }

    // Check for duplicate rows (when fully filled)
    final Map<String, List<int>> rowSignatures = {};
    for (int row = 0; row < size; row++) {
      bool isComplete = true;
      final StringBuffer buffer = StringBuffer();
      for (int col = 0; col < size; col++) {
        final value = _board.cellAt(row, col);
        if (value == TakuzuBoard.emptyValue) {
          isComplete = false;
          break;
        }
        buffer.write(value);
      }
      if (isComplete) {
        final signature = buffer.toString();
        rowSignatures.putIfAbsent(signature, () => []).add(row);
      }
    }
    for (final rows in rowSignatures.values) {
      if (rows.length > 1) {
        for (final row in rows) {
          for (int col = 0; col < size; col++) {
            violations.add(Offset(col.toDouble(), row.toDouble()));
          }
        }
      }
    }

    // Check for duplicate columns (when fully filled)
    final Map<String, List<int>> colSignatures = {};
    for (int col = 0; col < size; col++) {
      bool isComplete = true;
      final StringBuffer buffer = StringBuffer();
      for (int row = 0; row < size; row++) {
        final value = _board.cellAt(row, col);
        if (value == TakuzuBoard.emptyValue) {
          isComplete = false;
          break;
        }
        buffer.write(value);
      }
      if (isComplete) {
        final signature = buffer.toString();
        colSignatures.putIfAbsent(signature, () => []).add(col);
      }
    }
    for (final cols in colSignatures.values) {
      if (cols.length > 1) {
        for (final col in cols) {
          for (int row = 0; row < size; row++) {
            violations.add(Offset(col.toDouble(), row.toDouble()));
          }
        }
      }
    }

    return violations;
  }

  Offset? _hitTest(Offset position) =>
      PainterUtils.hitTestGrid(position: position, metrics: _gridMetrics);

  GridMetrics _calculateGridMetrics(Size size) {
    final TakuzuCounterLayout layout = TakuzuCounterLayout.forSize(size);
    final GridMetrics base = PainterUtils.calculateGridMetrics(
      availableSize: Size(
        size.width - layout.rowCounterWidth,
        size.height - layout.columnCounterHeight,
      ),
      rows: _board.size,
      columns: _board.size,
      padding: 16,
      cellSpacing: 1,
    );
    return GridMetrics(
      cellSize: base.cellSize,
      gridSize: base.gridSize,
      gridOffset: base.gridOffset + Offset(0, layout.columnCounterHeight),
      padding: base.padding,
      cellSpacing: base.cellSpacing,
      rows: base.rows,
      columns: base.columns,
    );
  }

  @override
  Widget buildPuzzleContent(BuildContext context, Size size) {
    _gridMetrics = _calculateGridMetrics(size);
    return CustomPaint(
      painter: _TakuzuContentPainter(
        board: _board,
        metrics: _gridMetrics,
        cellBgPaint: _cellBgPaint,
        theme: Theme.of(context),
        violatingCells: _showErrors ? _violatingCells : {},
      ),
      size: size,
    );
  }

  @override
  Widget buildGridBackground(BuildContext context, Size size) {
    // Initialize metrics before painting background
    _gridMetrics = _calculateGridMetrics(size);
    return CustomPaint(
      painter: PuzzleGridPainter(metrics: _gridMetrics, linePaint: _linePaint),
      size: size,
    );
  }

  @override
  Widget buildCellContent(
    BuildContext context,
    Offset position,
    Size cellSize,
  ) => const SizedBox.shrink();

  @override
  Widget buildSelectionHighlight(
    BuildContext context,
    Offset position,
    Size cellSize,
  ) {
    final rect = PainterUtils.getCellRect(
      gridPosition: position,
      metrics: _gridMetrics,
    );
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
  Widget buildErrorHighlight(
    BuildContext context,
    Offset position,
    Size cellSize,
  ) {
    final rect = PainterUtils.getCellRect(
      gridPosition: position,
      metrics: _gridMetrics,
    );
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

    // Call parent to handle selection state
    super.onTap(position);

    final row = gp.dy.toInt();
    final col = gp.dx.toInt();

    // Check if cell is fixed (a given clue)
    if (_board.isFixed(row, col)) {
      return;
    }

    final current = _board.cellAt(row, col);
    int next;
    // Cycle: empty → 0 → 1 → empty
    if (current == TakuzuBoard.emptyValue) {
      next = 0;
    } else if (current == 0) {
      next = 1;
    } else {
      next = TakuzuBoard.emptyValue;
    }

    widget.onMove?.call(TakuzuMove(row: row, col: col, value: next));
  }

  @override
  void onKeyEvent(KeyEvent event) {
    super.onKeyEvent(event);
    if (event is! KeyDownEvent || selectedPosition == null) return;
    final row = selectedPosition!.dy.toInt();
    final col = selectedPosition!.dx.toInt();

    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      widget.onMove?.call(
        TakuzuMove(row: row, col: col, value: TakuzuBoard.emptyValue),
      );
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
    this.violatingCells = const {},
  });

  final TakuzuBoard board;
  final GridMetrics metrics;
  final Paint cellBgPaint;
  final ThemeData theme;
  final Set<Offset> violatingCells;

  @override
  void paint(Canvas canvas, Size size) {
    final baseStyle = theme.textTheme.titleSmall;
    final ColorScheme colorScheme = theme.colorScheme;
    final TextStyle counterStyle =
        (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
          color: colorScheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        );
    final TextStyle warningCounterStyle = counterStyle.copyWith(
      color: colorScheme.error,
      fontWeight: FontWeight.w800,
    );

    final errorPaint = Paint()
      ..color = theme.colorScheme.error
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

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
        if (v != TakuzuBoard.emptyValue && baseStyle != null) {
          final bool isFixed = board.isFixed(row, col);
          final TextStyle textStyle = baseStyle.copyWith(
            color: isFixed ? colorScheme.onSurface : colorScheme.primary,
            fontWeight: isFixed ? FontWeight.w800 : FontWeight.w600,
          );
          PainterUtils.paintCellText(
            canvas: canvas,
            cellRect: rect,
            text: v.toString(),
            textStyle: textStyle,
          );
        }

        // Draw red X on violating cells
        final cellPos = Offset(col.toDouble(), row.toDouble());
        if (violatingCells.contains(cellPos)) {
          final padding = rect.width * 0.2;
          final x1 = rect.left + padding;
          final y1 = rect.top + padding;
          final x2 = rect.right - padding;
          final y2 = rect.bottom - padding;

          // Draw X
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), errorPaint);
          canvas.drawLine(Offset(x2, y1), Offset(x1, y2), errorPaint);
        }
      }
    }

    _paintCounters(
      canvas: canvas,
      normalStyle: counterStyle,
      warningStyle: warningCounterStyle,
    );
  }

  void _paintCounters({
    required Canvas canvas,
    required TextStyle normalStyle,
    required TextStyle warningStyle,
  }) {
    final TakuzuCounts counts = TakuzuCounts.fromBoard(board);
    final int allowed = board.size ~/ 2;

    for (int row = 0; row < board.size; row++) {
      final TakuzuLineCount count = counts.rows[row];
      final Rect rowRect = Rect.fromLTWH(
        metrics.gridRect.right + 6,
        metrics.gridOffset.dy +
            row * (metrics.cellSize.height + metrics.cellSpacing),
        58,
        metrics.cellSize.height,
      );
      _paintCounterText(
        canvas: canvas,
        rect: rowRect,
        text: count.compactLabel,
        style: count.exceeds(allowed) ? warningStyle : normalStyle,
        align: TextAlign.left,
      );
    }

    for (int col = 0; col < board.size; col++) {
      final TakuzuLineCount count = counts.columns[col];
      final Rect colRect = Rect.fromLTWH(
        metrics.gridOffset.dx +
            col * (metrics.cellSize.width + metrics.cellSpacing),
        metrics.gridRect.top - 28,
        metrics.cellSize.width,
        24,
      );
      _paintCounterText(
        canvas: canvas,
        rect: colRect,
        text: count.stackedLabel,
        style: count.exceeds(allowed) ? warningStyle : normalStyle,
        align: TextAlign.center,
      );
    }
  }

  void _paintCounterText({
    required Canvas canvas,
    required Rect rect,
    required String text,
    required TextStyle style,
    required TextAlign align,
  }) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: rect.width);

    final double dx = align == TextAlign.center
        ? rect.left + (rect.width - textPainter.width) / 2
        : rect.left;
    final Offset offset = Offset(
      dx,
      rect.top + (rect.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TakuzuContentPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.metrics != metrics ||
        oldDelegate.theme != theme ||
        oldDelegate.violatingCells != violatingCells;
  }
}

@visibleForTesting
class TakuzuCounterLayout {
  const TakuzuCounterLayout({
    required this.rowCounterWidth,
    required this.columnCounterHeight,
  });

  final double rowCounterWidth;
  final double columnCounterHeight;

  static TakuzuCounterLayout forSize(Size size) {
    if (size.width < 280 || size.height < 280) {
      return const TakuzuCounterLayout(
        rowCounterWidth: 46,
        columnCounterHeight: 24,
      );
    }
    return const TakuzuCounterLayout(
      rowCounterWidth: 64,
      columnCounterHeight: 30,
    );
  }
}

@visibleForTesting
class TakuzuLineCount {
  const TakuzuLineCount({required this.zeros, required this.ones});

  final int zeros;
  final int ones;

  String get compactLabel => '0:$zeros 1:$ones';
  String get stackedLabel => '0:$zeros\n1:$ones';

  bool exceeds(int allowed) => zeros > allowed || ones > allowed;
}

@visibleForTesting
class TakuzuCounts {
  const TakuzuCounts({required this.rows, required this.columns});

  final List<TakuzuLineCount> rows;
  final List<TakuzuLineCount> columns;

  static TakuzuCounts fromBoard(TakuzuBoard board) {
    final List<TakuzuLineCount> rows = <TakuzuLineCount>[];
    final List<TakuzuLineCount> columns = <TakuzuLineCount>[];

    for (int row = 0; row < board.size; row++) {
      int zeros = 0;
      int ones = 0;
      for (int col = 0; col < board.size; col++) {
        final int value = board.cellAt(row, col);
        if (value == 0) zeros++;
        if (value == 1) ones++;
      }
      rows.add(TakuzuLineCount(zeros: zeros, ones: ones));
    }

    for (int col = 0; col < board.size; col++) {
      int zeros = 0;
      int ones = 0;
      for (int row = 0; row < board.size; row++) {
        final int value = board.cellAt(row, col);
        if (value == 0) zeros++;
        if (value == 1) ones++;
      }
      columns.add(TakuzuLineCount(zeros: zeros, ones: ones));
    }

    return TakuzuCounts(rows: rows, columns: columns);
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
