import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/puzzle_core.dart';
import 'painter_utils.dart';
import 'puzzle_renderer.dart';
import 'performance_optimizations.dart';

/// Sudoku puzzle renderer with full interaction support.
class SudokuRenderer extends PuzzleRenderer<SudokuRendererWidget>
    with PerformanceOptimizedRendering {
  static const int _gridSize = 9;
  static const int _boxSize = 3;

  late GridMetrics _gridMetrics;
  late SudokuBoard _board;
  Set<Offset> _conflictPositions = {};

  // Animation controllers for smooth interactions
  late AnimationController _cellAnimationController;
  late Animation<double> _cellAnimation;

  // Note: selection and error animations are provided by the base class
  // (PuzzleRenderer) as `_selectionAnimation` and `_errorAnimation`.
  // Do not redeclare them here to avoid shadowing and attempts to access
  // the base class's private `_animationController`.

  // Performance optimization - cache paint objects
  late Paint _linePaint;
  late Paint _majorLinePaint;
  late Paint _selectionPaint;
  late Paint _errorPaint;
  late Paint _conflictPaint;
  late Paint _cellBackgroundPaint;
  late Paint _fixedCellBackgroundPaint;
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

    // The base class `PuzzleRenderer` already initializes `_animationController`,
    // `_selectionAnimation` and `_errorAnimation` in its `initState`.
    // We rely on those base animations and only set up the local cell
    // animation controller here.
  }

  void _setupPaints() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    _linePaint = PerformanceOptimizations.getCachedPaint(
      key: 'sudoku_line',
      color: colorScheme.outline.withOpacity(0.3),
      strokeWidth: 1.0,
    );

    _majorLinePaint = PerformanceOptimizations.getCachedPaint(
      key: 'sudoku_major_line',
      color: colorScheme.onSurface.withOpacity(0.8),
      strokeWidth: 3.0,
    );

    _selectionPaint = PerformanceOptimizations.getCachedPaint(
      key: 'sudoku_selection',
      color: colorScheme.primary,
      strokeWidth: 3.0,
    );

    _errorPaint = PerformanceOptimizations.getCachedPaint(
      key: 'sudoku_error',
      color: colorScheme.error,
      strokeWidth: 2.0,
    );


    _conflictPaint = PerformanceOptimizations.getCachedPaint(
      key: 'sudoku_conflict',
      color: colorScheme.error.withOpacity(0.3),
      strokeWidth: 1.0,
    );

    _cellBackgroundPaint = PerformanceOptimizations.getCachedPaint(
      key: 'sudoku_cell_bg',
      color: colorScheme.surface,
      style: PaintingStyle.fill,
    );

    _fixedCellBackgroundPaint = PerformanceOptimizations.getCachedPaint(
      key: 'sudoku_fixed_cell_bg',
      color: colorScheme.surfaceContainerHighest,
      style: PaintingStyle.fill,
    );

    _hintPaint = PerformanceOptimizations.getCachedPaint(
      key: 'sudoku_hint',
      color: colorScheme.secondary.withOpacity(0.6),
      style: PaintingStyle.fill,
    );
  }

  void _updateBoard() {
    if (widget.puzzle?.state is SudokuBoard) {
      _board = widget.puzzle!.state as SudokuBoard;
      _updateConflicts();
    }
  }

  void _computeMetrics(Size size) {
    _gridMetrics = PainterUtils.calculateGridMetrics(
      availableSize: size,
      rows: _gridSize,
      columns: _gridSize,
      padding: 16.0,
      cellSpacing: 1.0,
    );
  }

  void _updateConflicts() {
    _conflictPositions.clear();

    // Check for conflicts in rows, columns, and boxes
    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        final value = _board.cellAt(row, col);
        if (value != 0 && _hasConflict(row, col, value)) {
          _conflictPositions.add(Offset(col.toDouble(), row.toDouble()));
        }
      }
    }
  }

  bool _hasConflict(int row, int col, int value) {
    // Check row
    for (int c = 0; c < _gridSize; c++) {
      if (c != col && _board.cellAt(row, c) == value) {
        return true;
      }
    }

    // Check column
    for (int r = 0; r < _gridSize; r++) {
      if (r != row && _board.cellAt(r, col) == value) {
        return true;
      }
    }

    // Check box
    final boxRow = (row ~/ _boxSize) * _boxSize;
    final boxCol = (col ~/ _boxSize) * _boxSize;
    for (int r = boxRow; r < boxRow + _boxSize; r++) {
      for (int c = boxCol; c < boxCol + _boxSize; c++) {
        if ((r != row || c != col) && _board.cellAt(r, c) == value) {
          return true;
        }
      }
    }

    return false;
  }

  @override
  void didUpdateWidget(SudokuRendererWidget oldWidget) {
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
  Offset? hitTest(Offset position) {
    return PainterUtils.hitTestGrid(
      position: position,
      metrics: _gridMetrics,
    );
  }

  @override
  Offset? moveFocus(Offset current, Offset direction) {
    final newCol = (current.dx + direction.dx).clamp(0.0, (_gridSize - 1).toDouble());
    final newRow = (current.dy + direction.dy).clamp(0.0, (_gridSize - 1).toDouble());
    return Offset(newCol, newRow);
  }

  @override
  Size getCellSize(Size totalSize) {
    _computeMetrics(totalSize);
    return _gridMetrics.cellSize;
  }

  // Note: Do not override build(); base class handles layout. Compute metrics
  // using the exact size provided to the content/background builders.

  @override
  Widget buildPuzzleContent(BuildContext context, Size size) {
    // Calculate grid metrics based on the actual allocated size, not the full screen.
    _computeMetrics(size);
    return CustomPaint(
      painter: SudokuContentPainter(
        board: _board,
        metrics: _gridMetrics,
        linePaint: _linePaint,
        majorLinePaint: _majorLinePaint,
        cellBackgroundPaint: _cellBackgroundPaint,
        fixedCellBackgroundPaint: _fixedCellBackgroundPaint,
        conflictPaint: _conflictPaint,
        conflictPositions: _conflictPositions,
        notes: widget.notes,
        theme: Theme.of(context),
      ),
      size: size,
    );
  }

  @override
  Widget buildGridBackground(BuildContext context, Size size) {
    // Ensure grid metrics are initialized before painting background
    _computeMetrics(size);
    return CustomPaint(
      painter: PuzzleGridPainter(
        metrics: _gridMetrics,
        linePaint: _linePaint,
        majorLinePaint: _majorLinePaint,
        majorLineInterval: _boxSize,
      ),
      size: size,
    );
  }

  @override
  Widget buildCellContent(BuildContext context, Offset position, Size cellSize) {
    final row = position.dy.toInt();
    final col = position.dx.toInt();
    final value = _board.cellAt(row, col);
    final isFixed = _board.isFixed(row, col);
    final hasConflict = _conflictPositions.contains(position);
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
              color: hasConflict
                ? colorScheme.error
                : isFixed
                  ? colorScheme.onSurface
                  : colorScheme.primary,
              fontWeight: isFixed ? FontWeight.bold : FontWeight.normal,
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

    return AnimatedBuilder(
      animation: selectionAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: CellHighlightPainter(
            cellRect: cellRect,
            highlightPaint: _selectionPaint,
            animationValue: selectionAnimation.value,
            borderRadius: 4.0,
          ),
          size: cellSize,
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
          painter: CellHighlightPainter(
            cellRect: cellRect,
            highlightPaint: _errorPaint,
            animationValue: errorAnimation.value,
            borderRadius: 4.0,
          ),
          size: cellSize,
        );
      },
    );
  }

  @override
  Widget buildHintHighlight(BuildContext context, Offset position, Size cellSize) {
    // Calculate the cell rect using existing utilities
    final cellRect = PainterUtils.getCellRect(
      gridPosition: position,
      metrics: _gridMetrics,
    );

    // Use the widget's hintAnimationValue to modulate opacity
    final animVal = (widget.hintAnimationValue).clamp(0.0, 1.0);

    return CustomPaint(
      painter: _HintCellPainter(
        cellRect: cellRect,
        basePaint: _hintPaint,
        animationValue: animVal,
        borderRadius: 4.0,
      ),
      size: cellSize,
    );
  }

  /// Handle digit input from keyboard or number pad.
  void onDigitInput(int digit) {
    if (selectedPosition == null) return;

    final row = selectedPosition!.dy.toInt();
    final col = selectedPosition!.dx.toInt();

    if (_board.isFixed(row, col)) return;

    // Create and validate move
    final move = SudokuMove(row: row, col: col, digit: digit);
    widget.onMove?.call(move);

    // Animate cell update
    _cellAnimationController.forward().then((_) {
      _cellAnimationController.reverse();
    });
  }

  /// Handle backspace/delete to clear cell.
  void onClearCell() {
    if (selectedPosition == null) return;

    final row = selectedPosition!.dy.toInt();
    final col = selectedPosition!.dx.toInt();

    if (_board.isFixed(row, col)) return;

    final move = SudokuMove(row: row, col: col, digit: 0);
    widget.onMove?.call(move);
  }

  @override
  void onKeyEvent(KeyEvent event) {
    super.onKeyEvent(event);

    if (event is KeyDownEvent) {
      // Handle digit input
      if (event.logicalKey.keyLabel.length == 1) {
        final digit = int.tryParse(event.logicalKey.keyLabel);
        if (digit != null && digit >= 1 && digit <= 9) {
          onDigitInput(digit);
          return;
        }
      }

      // Handle special keys
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

/// Widget for Sudoku puzzle rendering.
class SudokuRendererWidget extends PuzzleRendererWidget {
  const SudokuRendererWidget({
    super.key,
    required super.puzzle,
    super.gameState,
    super.onCellSelected,
    super.onMove,
    super.onError,
    super.hintCells,
    super.hintAnimationValue,
    this.notes = const <int, Set<int>>{},
    this.hintFilledCells = const <int>{},
  });

  final Map<int, Set<int>> notes;
  final Set<int> hintFilledCells;

  @override
  State<SudokuRendererWidget> createState() => SudokuRenderer();
}

/// Custom painter for Sudoku content.
class SudokuContentPainter extends CustomPainter {
  const SudokuContentPainter({
    required this.board,
    required this.metrics,
    required this.linePaint,
    required this.majorLinePaint,
    required this.cellBackgroundPaint,
    required this.fixedCellBackgroundPaint,
    required this.conflictPaint,
    required this.conflictPositions,
    required this.notes,
    required this.theme,
    this.hintFilledCells = const <int>{},
  });

  final SudokuBoard board;
  final GridMetrics metrics;
  final Paint linePaint;
  final Paint majorLinePaint;
  final Paint cellBackgroundPaint;
  final Paint fixedCellBackgroundPaint;
  final Paint conflictPaint;
  final Set<Offset> conflictPositions;
  final Map<int, Set<int>> notes;
  final ThemeData theme;
  final Set<int> hintFilledCells;

  @override
  void paint(Canvas canvas, Size size) {
    final colorScheme = theme.colorScheme;

    // Paint cell backgrounds
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final cellRect = PainterUtils.getCellRect(
          gridPosition: Offset(col.toDouble(), row.toDouble()),
          metrics: metrics,
        );

        final isFixed = board.isFixed(row, col);
        final hasConflict = conflictPositions.contains(Offset(col.toDouble(), row.toDouble()));

        // Paint background
        final backgroundPaint = isFixed ? fixedCellBackgroundPaint : cellBackgroundPaint;
        PainterUtils.paintCellBackground(
          canvas: canvas,
          cellRect: cellRect,
          backgroundPaint: backgroundPaint,
        );

        // Paint conflict highlight
        if (hasConflict) {
          PainterUtils.paintCellBackground(
            canvas: canvas,
            cellRect: cellRect,
            backgroundPaint: conflictPaint,
          );
        }

        // Paint cell value or notes
        final value = board.cellAt(row, col);
        if (value != 0) {
          final textStyle = theme.textTheme.headlineSmall?.copyWith(
            color: hasConflict
                ? colorScheme.error
                : isFixed
                    ? colorScheme.onSurface
                    : (hintFilledCells.contains(row * SudokuBoard.side + col)
                        ? colorScheme.tertiary
                        : colorScheme.primary),
            fontWeight: isFixed ? FontWeight.bold : FontWeight.normal,
          );

          PainterUtils.paintCellText(
            canvas: canvas,
            cellRect: cellRect,
            text: value.toString(),
            textStyle: textStyle ?? const TextStyle(),
          );
        } else {
          final Set<int> cellNotes = notes[row * SudokuBoard.side + col] ?? const <int>{};
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
              if (note < 1 || note > SudokuBoard.side) {
                continue;
              }
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
      }
    }
  }

  @override
  bool shouldRepaint(SudokuContentPainter oldDelegate) {
    return board != oldDelegate.board ||
        metrics != oldDelegate.metrics ||
        conflictPositions != oldDelegate.conflictPositions ||
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

/// Custom painter for cell highlights.
class CellHighlightPainter extends CustomPainter {
  const CellHighlightPainter({
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
  bool shouldRepaint(CellHighlightPainter oldDelegate) {
    return cellRect != oldDelegate.cellRect ||
           highlightPaint != oldDelegate.highlightPaint ||
           animationValue != oldDelegate.animationValue ||
           borderRadius != oldDelegate.borderRadius;
  }
}

/// Painter for hint-filled cells. This paints a rounded rect background
/// with opacity modulated by `animationValue`.
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
