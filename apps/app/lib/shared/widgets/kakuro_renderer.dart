import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/puzzle_core.dart';

import 'painter_utils.dart';
import 'puzzle_renderer.dart';
import 'performance_optimizations.dart';

class KakuroRenderer extends PuzzleRenderer<KakuroRendererWidget>
    with PerformanceOptimizedRendering {
  late KakuroBoard _board;
  late GridMetrics _gridMetrics;

  late Paint _linePaint;
  late Paint _blockPaint;
  late Paint _cellBgPaint;
  late Paint _selectionPaint;
  late Paint _errorPaint;
  late Paint _hintPaint;

  @override
  void initState() {
    super.initState();
    _updateBoard();
  }

  @override
  void didUpdateWidget(covariant KakuroRendererWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      key: 'kakuro_line',
      color: cs.outline.withOpacity(0.3),
      strokeWidth: 1,
    );
    _blockPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kakuro_block',
      color: cs.surfaceVariant,
      style: PaintingStyle.fill,
    );
    _cellBgPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kakuro_cell_bg',
      color: cs.surface,
      style: PaintingStyle.fill,
    );
    _selectionPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kakuro_selection',
      color: cs.primary,
      style: PaintingStyle.stroke,
      strokeWidth: 3,
    );
    _errorPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kakuro_error',
      color: cs.error,
      style: PaintingStyle.stroke,
      strokeWidth: 2,
    );
    _hintPaint = PerformanceOptimizations.getCachedPaint(
      key: 'kakuro_hint',
      color: cs.secondary.withOpacity(0.6),
      style: PaintingStyle.fill,
    );
  }

  void _updateBoard() {
    if (widget.puzzle?.state is KakuroBoard) {
      _board = widget.puzzle!.state as KakuroBoard;
    } else {
      // fallback tiny board
      _board = KakuroBoard(
        width: 6,
        height: 6,
        kinds: List<KakuroCellKind>.filled(36, KakuroCellKind.value),
        values: List<int>.filled(36, 0),
        acrossClues: List<int?>.filled(36, null),
        downClues: List<int?>.filled(36, null),
        entries: const [],
        acrossEntryForCell: List<int>.filled(36, -1),
        downEntryForCell: List<int>.filled(36, -1),
      );
    }
  }

  Offset? _hitTest(Offset position) {
    return PainterUtils.hitTestGrid(position: position, metrics: _gridMetrics);
  }

  @override
  Offset? hitTest(Offset position) => _hitTest(position);

  @override
  Widget buildPuzzleContent(BuildContext context, Size size) {
    // Metrics are initialized in buildGridBackground; compute here too to stay in sync if needed
    _gridMetrics = PainterUtils.calculateGridMetrics(
      availableSize: size,
      rows: _board.height,
      columns: _board.width,
      padding: 16,
      cellSpacing: 1,
    );

    return CustomPaint(
      painter: _KakuroContentPainter(
        board: _board,
        metrics: _gridMetrics,
        blockPaint: _blockPaint,
        cellBgPaint: _cellBgPaint,
        theme: Theme.of(context),
        notes: widget.notes,
      ),
      size: size,
    );
  }

  @override
  Widget buildGridBackground(BuildContext context, Size size) {
    // Initialize metrics first so background paints with correct layout
    _gridMetrics = PainterUtils.calculateGridMetrics(
      availableSize: size,
      rows: _board.height,
      columns: _board.width,
      padding: 16,
      cellSpacing: 1,
    );
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
  ) {
    // Values are painted by content painter
    return const SizedBox.shrink();
  }

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
  Widget buildHintHighlight(
    BuildContext context,
    Offset position,
    Size cellSize,
  ) {
    final rect = PainterUtils.getCellRect(
      gridPosition: position,
      metrics: _gridMetrics,
    );
    final animVal = (widget.hintAnimationValue).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = _hintPaint.color.withOpacity(
        _hintPaint.color.opacity * (0.4 + 0.6 * animVal),
      )
      ..style = PaintingStyle.fill;
    return CustomPaint(
      painter: CellBackgroundPainter(
        cellRect: rect,
        backgroundPaint: paint,
        borderRadius: 3,
      ),
    );
  }

  // Input: select a playable cell and enter digits (1..9), backspace to clear
  @override
  void onTap(Offset position) {
    final gp = _hitTest(position);
    if (gp == null) return;
    final row = gp.dy.toInt();
    final col = gp.dx.toInt();
    if (!_board.isPlayable(row, col)) return;
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
    if (!_board.isPlayable(row, col)) return;

    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      widget.onMove?.call(KakuroMove(row: row, col: col, digit: 0));
      return;
    }
    final digit = int.tryParse(event.logicalKey.keyLabel);
    if (digit != null && digit >= 1 && digit <= 9) {
      widget.onMove?.call(KakuroMove(row: row, col: col, digit: digit));
    }
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

class _KakuroContentPainter extends CustomPainter {
  const _KakuroContentPainter({
    required this.board,
    required this.metrics,
    required this.blockPaint,
    required this.cellBgPaint,
    required this.theme,
    this.notes = const <int, Set<int>>{},
  });

  final KakuroBoard board;
  final GridMetrics metrics;
  final Paint blockPaint;
  final Paint cellBgPaint;
  final ThemeData theme;
  final Map<int, Set<int>> notes;

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface,
      fontSize: 12,
    );
    final clueStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.7),
      fontSize: 10,
    );
    final completedClueStyle = clueStyle?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.35),
      fontWeight: FontWeight.w700,
    );
    final incorrectClueStyle = clueStyle?.copyWith(
      color: theme.colorScheme.error,
      fontWeight: FontWeight.w700,
    );
    for (int row = 0; row < board.height; row++) {
      for (int col = 0; col < board.width; col++) {
        final rect = PainterUtils.getCellRect(
          gridPosition: Offset(col.toDouble(), row.toDouble()),
          metrics: metrics,
        );
        final idx = board.indexOf(row, col);
        if (board.kinds[idx] == KakuroCellKind.block) {
          PainterUtils.paintCellBackground(
            canvas: canvas,
            cellRect: rect,
            backgroundPaint: blockPaint,
            borderRadius: 2,
          );
          // draw diagonal split and clues if present
          final across = board.acrossClues[idx];
          final down = board.downClues[idx];
          final diagPaint = Paint()
            ..color = theme.colorScheme.outline.withOpacity(0.4)
            ..strokeWidth = 1;
          canvas.drawLine(rect.topLeft, rect.bottomRight, diagPaint);
          if (across != null && clueStyle != null) {
            final KakuroRunState acrossState = KakuroRunInspector.forClue(
              board: board,
              row: row,
              col: col,
              direction: KakuroDirection.across,
            );
            final TextStyle resolvedStyle =
                acrossState == KakuroRunState.completeCorrect
                ? completedClueStyle!
                : acrossState == KakuroRunState.completeIncorrect
                ? incorrectClueStyle!
                : clueStyle;
            final tp = TextPainter(
              text: TextSpan(text: across.toString(), style: resolvedStyle),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: rect.width / 2 - 2);
            tp.paint(canvas, Offset(rect.center.dx + 2, rect.top + 2));
          }
          if (down != null && clueStyle != null) {
            final KakuroRunState downState = KakuroRunInspector.forClue(
              board: board,
              row: row,
              col: col,
              direction: KakuroDirection.down,
            );
            final TextStyle resolvedStyle =
                downState == KakuroRunState.completeCorrect
                ? completedClueStyle!
                : downState == KakuroRunState.completeIncorrect
                ? incorrectClueStyle!
                : clueStyle;
            final tp = TextPainter(
              text: TextSpan(text: down.toString(), style: resolvedStyle),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: rect.width / 2 - 2);
            tp.paint(canvas, Offset(rect.left + 2, rect.center.dy));
          }
        } else {
          // playable cell
          PainterUtils.paintCellBackground(
            canvas: canvas,
            cellRect: rect,
            backgroundPaint: cellBgPaint,
            borderRadius: 2,
          );
          final v = board.valueAt(row, col);
          if (v != 0 && textStyle != null) {
            PainterUtils.paintCellText(
              canvas: canvas,
              cellRect: rect,
              text: v.toString(),
              textStyle: textStyle.copyWith(fontWeight: FontWeight.w600),
            );
          } else {
            // Render notes if present
            final cellNotes = notes[board.indexOf(row, col)] ?? const <int>{};
            if (cellNotes.isNotEmpty) {
              final List<int> sortedNotes = cellNotes.toList()..sort();
              final noteStyle = theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: (rect.shortestSide * 0.18).clamp(7.0, 10.0),
                fontWeight: FontWeight.w500,
              );
              if (noteStyle != null) {
                const int noteGridSize = 3;
                final Rect noteGridRect = rect.deflate(
                  (rect.shortestSide * 0.08).clamp(2.0, 4.0),
                );
                final double noteWidth = noteGridRect.width / noteGridSize;
                final double noteHeight = noteGridRect.height / noteGridSize;
                for (final int note in sortedNotes) {
                  if (note < 1 || note > 9) {
                    continue;
                  }
                  final int noteRow = (note - 1) ~/ noteGridSize;
                  final int noteCol = (note - 1) % noteGridSize;
                  final Rect noteRect = Rect.fromLTWH(
                    noteGridRect.left + noteCol * noteWidth,
                    noteGridRect.top + noteRow * noteHeight,
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
    }
  }

  @override
  bool shouldRepaint(covariant _KakuroContentPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.metrics != metrics ||
        oldDelegate.theme != theme ||
        !_notesEqual(notes, oldDelegate.notes);
  }

  bool _notesEqual(Map<int, Set<int>> a, Map<int, Set<int>> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final MapEntry<int, Set<int>> entry in a.entries) {
      final Set<int>? otherSet = b[entry.key];
      if (otherSet == null || !_setEquals(entry.value, otherSet)) return false;
    }
    return true;
  }

  bool _setEquals(Set<int> a, Set<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final int value in a) {
      if (!b.contains(value)) return false;
    }
    return true;
  }
}

@visibleForTesting
enum KakuroRunState { incomplete, completeCorrect, completeIncorrect }

@visibleForTesting
class KakuroRunInspector {
  const KakuroRunInspector._();

  static KakuroRunState forClue({
    required KakuroBoard board,
    required int row,
    required int col,
    required KakuroDirection direction,
  }) {
    final int entryId = _entryIdAfterClue(
      board: board,
      row: row,
      col: col,
      direction: direction,
    );
    if (entryId < 0 || entryId >= board.entries.length) {
      return KakuroRunState.incomplete;
    }
    return forEntry(board, board.entries[entryId]);
  }

  static KakuroRunState forEntry(KakuroBoard board, KakuroEntry entry) {
    int sum = 0;
    final Set<int> seen = <int>{};
    for (final int index in entry.cells) {
      if (index < 0 ||
          index >= board.cellCount ||
          !board.isPlayableIndex(index)) {
        return KakuroRunState.incomplete;
      }
      final int value = board.values[index];
      if (value == 0) {
        return KakuroRunState.incomplete;
      }
      if (value < 1 || value > 9 || !seen.add(value)) {
        return KakuroRunState.completeIncorrect;
      }
      sum += value;
    }
    return sum == entry.sum
        ? KakuroRunState.completeCorrect
        : KakuroRunState.completeIncorrect;
  }

  static int _entryIdAfterClue({
    required KakuroBoard board,
    required int row,
    required int col,
    required KakuroDirection direction,
  }) {
    final int runRow = direction == KakuroDirection.across ? row : row + 1;
    final int runCol = direction == KakuroDirection.across ? col + 1 : col;
    if (runRow < 0 ||
        runRow >= board.height ||
        runCol < 0 ||
        runCol >= board.width) {
      return -1;
    }
    final int runIndex = board.indexOf(runRow, runCol);
    if (!board.isPlayableIndex(runIndex)) {
      return -1;
    }
    return direction == KakuroDirection.across
        ? board.acrossEntryForCell[runIndex]
        : board.downEntryForCell[runIndex];
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
