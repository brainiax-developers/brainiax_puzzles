import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/puzzle_core.dart';
import 'painter_utils.dart';
import 'puzzle_renderer.dart';
import 'performance_optimizations.dart';

/// Kakuro puzzle renderer with full interaction support.
class KakuroRenderer extends PuzzleRenderer<KakuroRendererWidget>
    with PerformanceOptimizedRendering {
  late GridMetrics _gridMetrics;
  late KakuroBoard _board;

  // Animation controllers for smooth interactions
  late AnimationController _cellAnimationController;
  late Animation<double> _cellAnimation;

  // Performance optimization - cache paint objects
  late Paint _linePaint;
  late Paint _majorLinePaint;
  late Paint _selectionPaint;
  late Paint _runHighlightPaint;
  late Paint _errorPaint;
  late Paint _whiteCellBackgroundPaint;
  late Paint _blackCellBackgroundPaint;
  late Paint _hintPaint;

  void initState() {
    super.initState();
    _setupAnimations();
    _updateBoard();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupPaints();
  }

  void _setupAnimations() {
    _cellAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _cellAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cellAnimationController,
      curve: Curves.easeOut,
    ));
  }

  void _setupPaints() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    _linePaint = PerformanceOptimizations.getCachedPaint(
      key: 'kakuro_line',
      color: colorScheme.outline.withOpacity(0.3),
      strokeWidth: 1.0,
    );

    _majorLinePaint = PerformanceOptimizations.getCachedPaint(
      key: 'kakuro_major_line',
      color: colorScheme.onSurface.withOpacity(0.8),
      strokeWidth: 3.0,
    );

    _selectionPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kakuro_selection',
      color: colorScheme.primary,
      strokeWidth: 3.0,
    );

    _runHighlightPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kakuro_run_highlight',
      color: colorScheme.primary.withOpacity(0.15),
      style: PaintingStyle.fill,
    );

    _errorPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kakuro_error',
      color: colorScheme.error,
      strokeWidth: 2.0,
    );

    _whiteCellBackgroundPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kakuro_white_cell_bg',
      color: colorScheme.surface,
      style: PaintingStyle.fill,
    );

    _blackCellBackgroundPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kakuro_black_cell_bg',
      color: colorScheme.onSurface,
      style: PaintingStyle.fill,
    );

    _hintPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kakuro_hint',
      color: colorScheme.secondary.withOpacity(0.6),
      style: PaintingStyle.fill,
    );
  }

  void _updateBoard() {
    if (widget.puzzle?.state is KakuroBoard) {
      _board = widget.puzzle!.state as KakuroBoard;
    }
  }

  void _computeMetrics(Size size) {
    _gridMetrics = PainterUtils.calculateGridMetrics(
      availableSize: size,
      rows: _board.height,
      columns: _board.width,
      padding: 8.0,
      cellSpacing: 1.0,
    );
  }

  @override
  void didUpdateWidget(KakuroRendererWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Object? newState = widget.puzzle?.state;
    final Object? oldState = oldWidget.puzzle?.state;
    if (widget.puzzle != oldWidget.puzzle || newState != oldState) {
      _updateBoard();
    }
  }

  @override
  Offset? hitTest(Offset position) {
    return PainterUtils.hitTestGrid(
      position: position,
      metrics: _gridMetrics,
    );
  }

  @override
  Offset? moveFocus(Offset current, Offset direction) {
    final newCol = (current.dx + direction.dx).clamp(0.0, (_board.width - 1).toDouble());
    final newRow = (current.dy + direction.dy).clamp(0.0, (_board.height - 1).toDouble());
    return Offset(newCol, newRow);
  }

  @override
  Size getCellSize(Size totalSize) {
    _computeMetrics(totalSize);
    return _gridMetrics.cellSize;
  }

  @override
  Widget buildPuzzleContent(BuildContext context, Size size) {
    _computeMetrics(size);
    return CustomPaint(
      painter: KakuroContentPainter(
        board: _board,
        metrics: _gridMetrics,
        linePaint: _linePaint,
        whiteCellBackgroundPaint: _whiteCellBackgroundPaint,
        blackCellBackgroundPaint: _blackCellBackgroundPaint,
        notes: widget.notes,
        theme: Theme.of(context),
      ),
      size: size,
    );
  }

  @override
  Widget buildGridBackground(BuildContext context, Size size) {
    _computeMetrics(size);
    return CustomPaint(
      painter: PuzzleGridPainter(
        metrics: _gridMetrics,
        linePaint: _linePaint,
        majorLinePaint: _majorLinePaint,
        majorLineInterval: _board.width, // Draw boundary around the whole grid
      ),
      size: size,
    );
  }

  @override
  Widget buildCellContent(BuildContext context, Offset position, Size cellSize) {
    final row = position.dy.toInt();
    final col = position.dx.toInt();
    final cellIndex = row * _board.width + col;
    final isWhite = _board.cellTypes[cellIndex] == KakuroBoard.cellWhite;
    
    if (!isWhite) {
      return const SizedBox.shrink(); // Black cells draw their own content in KakuroContentPainter
    }

    final value = _board.cellValues[cellIndex];
    if (value == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _cellAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * _cellAnimation.value),
          child: Text(
            value.toString(),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  @override
  Widget buildSelectionHighlight(BuildContext context, Offset position, Size cellSize) {
    final cellRect = PainterUtils.getCellRect(
      gridPosition: position,
      metrics: _gridMetrics,
    );

    final row = position.dy.toInt();
    final col = position.dx.toInt();
    final cellIndex = row * _board.width + col;
    final isWhite = _board.cellTypes[cellIndex] == KakuroBoard.cellWhite;

    List<Rect> runRects = [];
    if (isWhite) {
      // Find horizontal run
      int startCol = col;
      while (startCol > 0 && _board.cellTypes[row * _board.width + (startCol - 1)] == KakuroBoard.cellWhite) {
        startCol--;
      }
      int endCol = col;
      while (endCol < _board.width - 1 && _board.cellTypes[row * _board.width + (endCol + 1)] == KakuroBoard.cellWhite) {
        endCol++;
      }
      
      for (int c = startCol; c <= endCol; c++) {
        if (c != col) { // don't double highlight the selected cell with run highlight
          runRects.add(PainterUtils.getCellRect(
            gridPosition: Offset(c.toDouble(), row.toDouble()),
            metrics: _gridMetrics,
          ));
        }
      }

      // Find vertical run
      int startRow = row;
      while (startRow > 0 && _board.cellTypes[(startRow - 1) * _board.width + col] == KakuroBoard.cellWhite) {
        startRow--;
      }
      int endRow = row;
      while (endRow < _board.height - 1 && _board.cellTypes[(endRow + 1) * _board.width + col] == KakuroBoard.cellWhite) {
        endRow++;
      }

      for (int r = startRow; r <= endRow; r++) {
        if (r != row) {
          runRects.add(PainterUtils.getCellRect(
            gridPosition: Offset(col.toDouble(), r.toDouble()),
            metrics: _gridMetrics,
          ));
        }
      }
    }

    return AnimatedBuilder(
      animation: selectionAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: KakuroHighlightPainter(
            cellRect: cellRect,
            highlightPaint: _selectionPaint,
            runRects: runRects,
            runPaint: _runHighlightPaint,
            animationValue: selectionAnimation.value,
            borderRadius: 0.0,
          ),
          size: cellSize, // This size is ignored because we draw relative to grid metrics
        );
      },
    );
  }

  @override
  Widget buildErrorHighlight(BuildContext context, Offset position, Size cellSize) {
    final cellRect = PainterUtils.getCellRect(
      gridPosition: position,
      metrics: _gridMetrics,
    );

    return AnimatedBuilder(
      animation: errorAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: KakuroCellHighlightPainter(
            cellRect: cellRect,
            highlightPaint: _errorPaint,
            animationValue: errorAnimation.value,
            borderRadius: 0.0,
          ),
          size: cellSize,
        );
      },
    );
  }

  @override
  Widget buildHintHighlight(BuildContext context, Offset position, Size cellSize) {
    final cellRect = PainterUtils.getCellRect(
      gridPosition: position,
      metrics: _gridMetrics,
    );

    final animVal = (widget.hintAnimationValue).clamp(0.0, 1.0);

    return CustomPaint(
      painter: _HintCellPainter(
        cellRect: cellRect,
        basePaint: _hintPaint,
        animationValue: animVal,
        borderRadius: 0.0,
      ),
      size: cellSize,
    );
  }

  void onDigitInput(int digit) {
    if (selectedPosition == null) return;

    final row = selectedPosition!.dy.toInt();
    final col = selectedPosition!.dx.toInt();
    final cellIndex = row * _board.width + col;

    if (_board.cellTypes[cellIndex] != KakuroBoard.cellWhite) return;

    final move = KakuroMove(index: row * _board.width + col, value: digit);
    widget.onMove?.call(move);

    _cellAnimationController.forward().then((_) {
      _cellAnimationController.reverse();
    });
  }

  void onClearCell() {
    if (selectedPosition == null) return;

    final row = selectedPosition!.dy.toInt();
    final col = selectedPosition!.dx.toInt();
    final cellIndex = row * _board.width + col;

    if (_board.cellTypes[cellIndex] != KakuroBoard.cellWhite) return;

    final move = KakuroMove(index: row * _board.width + col, value: 0);
    widget.onMove?.call(move);
  }

  @override
  void onKeyEvent(KeyEvent event) {
    super.onKeyEvent(event);

    if (event is KeyDownEvent) {
      if (event.logicalKey.keyLabel.length == 1) {
        final digit = int.tryParse(event.logicalKey.keyLabel);
        if (digit != null && digit >= 1 && digit <= 9) {
          onDigitInput(digit);
          return;
        }
      }

      switch (event.logicalKey) {
        case LogicalKeyboardKey.backspace:
        case LogicalKeyboardKey.delete:
          onClearCell();
          break;
        case LogicalKeyboardKey.escape:
          clearSelection();
          break;
      }
    }
  }

  @override
  void dispose() {
    _cellAnimationController.dispose();
    disposePerformanceMonitoring();
    super.dispose();
  }
}

class KakuroRendererWidget extends PuzzleRendererWidget {
  const KakuroRendererWidget({
    super.key,
    required super.puzzle,
    super.gameState,
    super.onCellSelected,
    super.onMove,
    super.onError,
    super.hintCells,
    super.hintAnimationValue,
    this.notes = const <int, Set<int>>{},
  });

  final Map<int, Set<int>> notes;

  @override
  State<KakuroRendererWidget> createState() => KakuroRenderer();
}

class KakuroContentPainter extends CustomPainter {
  const KakuroContentPainter({
    required this.board,
    required this.metrics,
    required this.linePaint,
    required this.whiteCellBackgroundPaint,
    required this.blackCellBackgroundPaint,
    required this.notes,
    required this.theme,
  });

  final KakuroBoard board;
  final GridMetrics metrics;
  final Paint linePaint;
  final Paint whiteCellBackgroundPaint;
  final Paint blackCellBackgroundPaint;
  final Map<int, Set<int>> notes;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final colorScheme = theme.colorScheme;
    final outlinePaint = Paint()
      ..color = colorScheme.outline.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (int row = 0; row < board.height; row++) {
      for (int col = 0; col < board.width; col++) {
        final int cellIndex = row * board.width + col;
        final cellRect = PainterUtils.getCellRect(
          gridPosition: Offset(col.toDouble(), row.toDouble()),
          metrics: metrics,
        );
        
        final isWhite = board.cellTypes[cellIndex] == KakuroBoard.cellWhite;

        if (isWhite) {
          PainterUtils.paintCellBackground(
            canvas: canvas,
            cellRect: cellRect,
            backgroundPaint: whiteCellBackgroundPaint,
          );
          
          final value = board.cellValues[cellIndex];
          if (value != 0) {
            final textStyle = theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.primary,
            );
            PainterUtils.paintCellText(
              canvas: canvas,
              cellRect: cellRect,
              text: value.toString(),
              textStyle: textStyle ?? const TextStyle(),
            );
          } else {
            final Set<int> cellNotes = notes[cellIndex] ?? const <int>{};
            if (cellNotes.isNotEmpty) {
              const int noteGridSize = 3;
              final List<int> sortedNotes = cellNotes.toList()..sort();
              final double noteWidth = cellRect.width / noteGridSize;
              final double noteHeight = cellRect.height / noteGridSize;
              final TextStyle noteStyle = theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ) ??
                  TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: cellRect.height / 5.5,
                  );

              for (final int note in sortedNotes) {
                if (note < 1 || note > 9) continue;
                final int noteRow = (note - 1) ~/ noteGridSize;
                final int noteCol = (note - 1) % noteGridSize;
                final Rect noteRect = Rect.fromLTWH(
                  cellRect.left + (noteCol * noteWidth),
                  cellRect.top + (noteRow * noteHeight),
                  noteWidth,
                  noteHeight,
                );
                PainterUtils.paintCellText(
                  canvas: canvas,
                  cellRect: noteRect,
                  text: note.toString(),
                  textStyle: noteStyle,
                );
              }
            }
          }
        } else {
          // Paint Black Cell
          PainterUtils.paintCellBackground(
            canvas: canvas,
            cellRect: cellRect,
            backgroundPaint: blackCellBackgroundPaint,
          );
          
          final acrossClue = board.acrossClues[cellIndex];
          final downClue = board.downClues[cellIndex];
          
          if (acrossClue != 0 || downClue != 0) {
            final clueLinePaint = Paint()
              ..color = colorScheme.surface.withOpacity(0.5)
              ..strokeWidth = 1.0
              ..style = PaintingStyle.stroke;

            // Draw diagonal line
            canvas.drawLine(cellRect.topLeft, cellRect.bottomRight, clueLinePaint);
            
            final TextStyle clueStyle = theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.surface,
              fontWeight: FontWeight.bold,
              fontSize: cellRect.height / 3.5,
            ) ?? const TextStyle();

            if (acrossClue != 0) {
              // Draw in top-right triangle
              final acrossRect = Rect.fromLTRB(
                cellRect.left + cellRect.width / 2,
                cellRect.top,
                cellRect.right,
                cellRect.top + cellRect.height / 2,
              );
              PainterUtils.paintCellText(
                canvas: canvas,
                cellRect: acrossRect,
                text: acrossClue.toString(),
                textStyle: clueStyle,
              );
            }
            
            if (downClue != 0) {
              // Draw in bottom-left triangle
              final downRect = Rect.fromLTRB(
                cellRect.left,
                cellRect.top + cellRect.height / 2,
                cellRect.left + cellRect.width / 2,
                cellRect.bottom,
              );
              PainterUtils.paintCellText(
                canvas: canvas,
                cellRect: downRect,
                text: downClue.toString(),
                textStyle: clueStyle,
              );
            }
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(KakuroContentPainter oldDelegate) {
    return board != oldDelegate.board ||
        metrics != oldDelegate.metrics ||
        theme != oldDelegate.theme ||
        !_notesEqual(notes, oldDelegate.notes);
  }

  bool _notesEqual(Map<int, Set<int>> a, Map<int, Set<int>> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final MapEntry<int, Set<int>> entry in a.entries) {
      final Set<int>? other = b[entry.key];
      if (other == null || entry.value.length != other.length) {
        return false;
      }
      if (!setEquals(entry.value, other)) {
        return false;
      }
    }
    return true;
  }
}

class KakuroHighlightPainter extends CustomPainter {
  const KakuroHighlightPainter({
    required this.cellRect,
    required this.highlightPaint,
    required this.runRects,
    required this.runPaint,
    required this.animationValue,
    this.borderRadius = 0.0,
  });

  final Rect cellRect;
  final Paint highlightPaint;
  final List<Rect> runRects;
  final Paint runPaint;
  final double animationValue;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw run highlights
    final runOpacity = (runPaint.color.opacity * animationValue).clamp(0.0, 1.0);
    final currentRunPaint = Paint()
      ..color = runPaint.color.withOpacity(runOpacity)
      ..style = runPaint.style;

    for (final runRect in runRects) {
      if (borderRadius > 0) {
        final rrect = RRect.fromRectAndRadius(
          runRect,
          Radius.circular(borderRadius),
        );
        canvas.drawRRect(rrect, currentRunPaint);
      } else {
        canvas.drawRect(runRect, currentRunPaint);
      }
    }

    // Draw main cell highlight
    PainterUtils.paintSelectionHighlight(
      canvas: canvas,
      cellRect: cellRect,
      highlightPaint: highlightPaint,
      animationValue: animationValue,
      borderRadius: borderRadius,
    );
  }

  @override
  bool shouldRepaint(KakuroHighlightPainter oldDelegate) {
    return cellRect != oldDelegate.cellRect ||
           highlightPaint != oldDelegate.highlightPaint ||
           runRects != oldDelegate.runRects ||
           runPaint != oldDelegate.runPaint ||
           animationValue != oldDelegate.animationValue ||
           borderRadius != oldDelegate.borderRadius;
  }
}

class KakuroCellHighlightPainter extends CustomPainter {
  const KakuroCellHighlightPainter({
    required this.cellRect,
    required this.highlightPaint,
    required this.animationValue,
    this.borderRadius = 0.0,
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
  bool shouldRepaint(KakuroCellHighlightPainter oldDelegate) {
    return cellRect != oldDelegate.cellRect ||
           highlightPaint != oldDelegate.highlightPaint ||
           animationValue != oldDelegate.animationValue ||
           borderRadius != oldDelegate.borderRadius;
  }
}

class _HintCellPainter extends CustomPainter {
  _HintCellPainter({
    required this.cellRect,
    required this.basePaint,
    required this.animationValue,
    this.borderRadius = 0.0,
  });

  final Rect cellRect;
  final Paint basePaint;
  final double animationValue;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = basePaint.color.withOpacity((basePaint.color.opacity) * (0.4 + 0.6 * animationValue))
      ..style = PaintingStyle.fill;

    PainterUtils.paintCellBackground(
      canvas: canvas,
      cellRect: cellRect,
      backgroundPaint: paint,
    );
  }

  @override
  bool shouldRepaint(covariant _HintCellPainter oldDelegate) {
    return oldDelegate.cellRect != cellRect ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.basePaint.color != basePaint.color;
  }
}
