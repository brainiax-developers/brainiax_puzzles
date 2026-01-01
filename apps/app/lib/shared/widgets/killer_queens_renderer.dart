import 'dart:math' show sin, pi;

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
  late Paint _fixedPaint;
  late Paint _selectionPaint;
  late Paint _hintPaint;

  Offset? _lastDragPosition;
  
  late AnimationController _vibrationController;

  @override
  void initState() {
    super.initState();
    _updateBoard();
    
    // Initialize vibration animation
    _vibrationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..addListener(() {
      setState(() {}); // Rebuild during animation
    });
  }
  
  @override
  void dispose() {
    _vibrationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant KillerQueensRendererWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.puzzle?.state != oldWidget.puzzle?.state) {
      _updateBoard();
    }
    
    // Start vibration animation when conflicts appear
    if (widget.isShowingConflicts && !oldWidget.isShowingConflicts) {
      _vibrationController.forward(from: 0.0);
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

    // Calculate vibration offset (oscillates horizontally)
    final vibrationOffset = _vibrationController.isAnimating 
      ? Tween<double>(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: Curves.easeInOut))
          .animate(_vibrationController)
          .value * 8.0 * // Max offset
          sin(_vibrationController.value * 8 * pi) // Oscillate
      : 0.0;

    return CustomPaint(
      painter: _KillerQueensContentPainter(
        board: _board,
        metrics: _metrics,
        cellPaint: _cellPaint,
        fixedPaint: _fixedPaint,
        hintPaint: _hintPaint,
        theme: Theme.of(context),
        hintCells: widget.hintCells,
        hintProgress: widget.hintAnimationValue,
        conflictingCells: widget.conflictingCells,
        isShowingConflicts: widget.isShowingConflicts,
        vibrationOffset: vibrationOffset,
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
          highlightPaint: _selectionPaint,
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
  Widget buildCellContent(BuildContext context, Offset position, Size cellSize) {
    return const SizedBox.shrink();
  }

  @override
  void onTap(Offset position) {
    final Offset? gridPos = _hitTest(position);
    if (gridPos == null) return;
    final int row = gridPos.dy.toInt();
    final int col = gridPos.dx.toInt();
    final int index = row * _board.size + col;
    if (_board.fixed[index]) {
      super.onTap(position);
      return;
    }
    final int currentValue = _board.cells[index];
    final int nextValue = currentValue == 0 ? 2 : currentValue == 2 ? 1 : 0;
    widget.onMove?.call(
      core.KillerQueensMove(row: row, col: col, value: nextValue),
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
    if (_board.fixed[index]) {
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      final int currentValue = _board.cells[index];
      final int nextValue = currentValue == 0 ? 2 : currentValue == 2 ? 1 : 0;
      widget.onMove?.call(
        core.KillerQueensMove(row: row, col: col, value: nextValue),
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

  @override
  void onPanStart(DragStartDetails details) {
    final Offset? gridPos = _hitTest(details.localPosition);
    if (gridPos == null) return;
    _lastDragPosition = gridPos;
    _placeCrossAt(gridPos);
    super.onPanStart(details);
  }

  @override
  void onPanUpdate(DragUpdateDetails details) {
    final Offset? gridPos = _hitTest(details.localPosition);
    if (gridPos == null || gridPos == _lastDragPosition) return;
    _lastDragPosition = gridPos;
    _placeCrossAt(gridPos);
    super.onPanUpdate(details);
  }

  @override
  void onPanEnd(DragEndDetails details) {
    _lastDragPosition = null;
    super.onPanEnd(details);
  }

  void _placeCrossAt(Offset gridPos) {
    final int row = gridPos.dy.toInt();
    final int col = gridPos.dx.toInt();
    final int index = row * _board.size + col;
    if (_board.fixed[index] || _board.cells[index] == 1) {
      return; // Skip fixed or queen cells
    }
    widget.onMove?.call(
      core.KillerQueensMove(row: row, col: col, value: 2),
    );
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
    this.conflictingCells,
    this.isShowingConflicts = false,
  });
  
  final Set<int>? conflictingCells;
  final bool isShowingConflicts;

  @override
  State<KillerQueensRendererWidget> createState() => KillerQueensRenderer();
}

class _KillerQueensContentPainter extends CustomPainter {
  _KillerQueensContentPainter({
    required this.board,
    required this.metrics,
    required this.cellPaint,
    required this.fixedPaint,
    required this.hintPaint,
    required this.theme,
    required this.hintCells,
    required this.hintProgress,
    this.conflictingCells,
    this.isShowingConflicts = false,
    this.vibrationOffset = 0.0,
  });

  final core.KillerQueensBoard board;
  final GridMetrics metrics;
  final Paint cellPaint;
  final Paint fixedPaint;
  final Paint hintPaint;
  final ThemeData theme;
  final List<Offset>? hintCells;
  final double hintProgress;
  final Set<int>? conflictingCells;
  final bool isShowingConflicts;
  final double vibrationOffset;

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
      ..color = theme.colorScheme.outline
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    // Generate stable pastel colors per cage using HSL seeded by cage id
    Color cageColorFor(int cageId) {
      final double hue = (cageId * 37) % 360; // pseudo-random but deterministic
      final bool isDark = theme.brightness == Brightness.dark;
      final double lightness = isDark ? 0.25 : 0.88;
      final double saturation = 0.45;
      return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
    }

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

    // First pass: paint cage backgrounds and cell content
    for (int row = 0; row < board.size; row++) {
      for (int col = 0; col < board.size; col++) {
        final Rect rect = PainterUtils.getCellRect(
          gridPosition: Offset(col.toDouble(), row.toDouble()),
          metrics: metrics,
        );
        
        final int index = row * board.size + col;
        final int cageId = board.cageByCell[index];
        final Color bgColor = cageColorFor(cageId);
        
        // Draw cage background
        final Paint cageBgPaint = Paint()
          ..color = bgColor.withOpacity(0.92)
          ..style = PaintingStyle.fill;
        PainterUtils.paintCellBackground(
          canvas: canvas,
          cellRect: rect,
          backgroundPaint: cageBgPaint,
          borderRadius: 4,
        );

        // Overlay fixed cell highlight
        if (board.fixed[index]) {
          canvas.drawRect(rect, fixedPaint);
        }

        // Overlay hint highlight
        if (hintIndices.contains(index) && hintProgress > 0) {
          canvas.drawRect(rect, hintPaint);
        }

        // Draw queen
        if (board.cells[index] == 1) {
          // Check if this queen is in conflict
          final bool isConflicting = isShowingConflicts && 
                                     conflictingCells != null && 
                                     conflictingCells!.contains(index);
          
          // Apply vibration offset if conflicting
          final double offsetX = isConflicting ? vibrationOffset : 0.0;
          
          // Use red color for conflicting queens
          final TextStyle queenStyle = isConflicting
              ? textStyle.copyWith(color: Colors.red)
              : textStyle;
          
          textPainter.text = TextSpan(text: 'Q', style: queenStyle);
          textPainter.layout(minWidth: 0, maxWidth: rect.width);
          final Offset textOffset = Offset(
            rect.left + (rect.width - textPainter.width) / 2 + offsetX,
            rect.top + (rect.height - textPainter.height) / 2,
          );
          textPainter.paint(canvas, textOffset);
        }

        // Draw cross
        if (board.cells[index] == 2) {
          final Paint crossPaint = Paint()
            ..color = theme.colorScheme.onSurface
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round;
          final double padding = rect.width * 0.2;
          canvas.drawLine(
            rect.topLeft + Offset(padding, padding),
            rect.bottomRight - Offset(padding, padding),
            crossPaint,
          );
          canvas.drawLine(
            rect.topRight + Offset(-padding, padding),
            rect.bottomLeft - Offset(-padding, padding),
            crossPaint,
          );
        }
      }
    }

    // Second pass: draw cage boundaries
    for (int row = 0; row < board.size; row++) {
      for (int col = 0; col < board.size; col++) {
        final int index = row * board.size + col;
        final int cage = board.cageByCell[index];
        final Rect rect = PainterUtils.getCellRect(
          gridPosition: Offset(col.toDouble(), row.toDouble()),
          metrics: metrics,
        );

        void drawEdge(Offset a, Offset b) {
          canvas.drawLine(a, b, cagePaint);
        }

        // Top boundary
        if (row == 0 || board.cageByCell[index - board.size] != cage) {
          drawEdge(rect.topLeft, rect.topRight);
        }

        // Left boundary
        if (col == 0 || board.cageByCell[index - 1] != cage) {
          drawEdge(rect.topLeft, rect.bottomLeft);
        }

        // Bottom boundary
        if (row == board.size - 1 || board.cageByCell[index + board.size] != cage) {
          drawEdge(rect.bottomLeft, rect.bottomRight);
        }

        // Right boundary
        if (col == board.size - 1 || board.cageByCell[index + 1] != cage) {
          drawEdge(rect.topRight, rect.bottomRight);
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
    required this.highlightPaint,
    required this.progress,
  });

  final Rect rect;
  final Paint highlightPaint;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final RRect rRect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rRect, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _CellHighlightPainter oldDelegate) {
    return oldDelegate.rect != rect ||
        oldDelegate.highlightPaint != highlightPaint ||
        oldDelegate.progress != progress;
  }
}
