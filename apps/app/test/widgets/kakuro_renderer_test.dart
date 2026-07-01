import 'package:app/shared/widgets/kakuro_renderer.dart';
import 'package:app/shared/widgets/painter_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders clues, values, notes, selection, and hint highlights', (
    WidgetTester tester,
  ) async {
    final moves = <core.KakuroMove>[];

    await tester.pumpWidget(
      _KakuroHarness(
        puzzle: _buildKakuroPuzzle(),
        notes: const <int, Set<int>>{
          9: <int>{2, 8, 10},
        },
        hintCells: const <Offset>[Offset(2, 1)],
        hintAnimationValue: 0.75,
        onMove: moves.add,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final rendererFinder = find.byType(KakuroRendererWidget);
    expect(rendererFinder, findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tapCell(tester, col: 1, row: 1);
    await tester.pump(const Duration(milliseconds: 250));

    final state = tester.state<KakuroRenderer>(rendererFinder);
    state.setErrorPositions(<Offset>{const Offset(2, 2)});
    await tester.pump(const Duration(milliseconds: 250));

    state.onDigitInput(5);
    await tester.pump(const Duration(milliseconds: 200));
    state.onClearCell();
    await tester.pump(const Duration(milliseconds: 200));

    expect(moves, <core.KakuroMove>[
      const core.KakuroMove(index: 5, value: 5),
      const core.KakuroMove(index: 5, value: 0),
    ]);

    expect(
      state.buildCellContent(
        tester.element(rendererFinder),
        const Offset(1, 1),
        const Size.square(40),
      ),
      isA<AnimatedBuilder>(),
    );
    expect(
      state.buildCellContent(
        tester.element(rendererFinder),
        const Offset(2, 1),
        const Size.square(40),
      ),
      isA<SizedBox>(),
    );
    expect(
      state.buildCellContent(
        tester.element(rendererFinder),
        Offset.zero,
        const Size.square(40),
      ),
      isA<SizedBox>(),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores input for black cells and empty selection', (
    WidgetTester tester,
  ) async {
    final moves = <core.KakuroMove>[];

    await tester.pumpWidget(
      _KakuroHarness(puzzle: _buildKakuroPuzzle(), onMove: moves.add),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final state = tester.state<KakuroRenderer>(
      find.byType(KakuroRendererWidget),
    );
    state.onDigitInput(3);
    state.onClearCell();
    expect(moves, isEmpty);

    await _tapCell(tester, col: 0, row: 0);
    await tester.pump(const Duration(milliseconds: 100));

    state.onDigitInput(3);
    state.onClearCell();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 100));

    expect(moves, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'updates when board changes and remains bounded on small boards',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _KakuroHarness(puzzle: _buildKakuroPuzzle(), side: 96),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(
        _KakuroHarness(puzzle: _buildKakuroPuzzle(valueAtCenter: 8), side: 96),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final state = tester.state<KakuroRenderer>(
        find.byType(KakuroRendererWidget),
      );
      state.onTap(const Offset(-20, -20));
      state.onPanStart(DragStartDetails(localPosition: const Offset(30, 30)));
      state.onPanUpdate(
        DragUpdateDetails(
          globalPosition: const Offset(50, 50),
          localPosition: const Offset(50, 50),
        ),
      );
      state.onPanEnd(DragEndDetails());
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
    },
  );

  test('painters repaint only when relevant inputs change', () {
    final board = _kakuroBoard();
    final metrics = _metrics();
    final linePaint = Paint()..color = Colors.black;
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final blackPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    final theme = ThemeData();

    final content = KakuroContentPainter(
      board: board,
      metrics: metrics,
      linePaint: linePaint,
      whiteCellBackgroundPaint: whitePaint,
      blackCellBackgroundPaint: blackPaint,
      notes: const <int, Set<int>>{
        9: <int>{2, 8},
      },
      theme: theme,
    );

    expect(
      content.shouldRepaint(
        KakuroContentPainter(
          board: board,
          metrics: metrics,
          linePaint: linePaint,
          whiteCellBackgroundPaint: whitePaint,
          blackCellBackgroundPaint: blackPaint,
          notes: const <int, Set<int>>{
            9: <int>{2, 8},
          },
          theme: theme,
        ),
      ),
      isFalse,
    );
    expect(
      content.shouldRepaint(
        KakuroContentPainter(
          board: board,
          metrics: metrics,
          linePaint: linePaint,
          whiteCellBackgroundPaint: whitePaint,
          blackCellBackgroundPaint: blackPaint,
          notes: const <int, Set<int>>{
            9: <int>{2, 7},
          },
          theme: theme,
        ),
      ),
      isTrue,
    );

    final highlight = KakuroHighlightPainter(
      cellRect: const Rect.fromLTWH(0, 0, 20, 20),
      highlightPaint: linePaint,
      runRects: const <Rect>[Rect.fromLTWH(20, 0, 20, 20)],
      runPaint: whitePaint,
      animationValue: 1,
      borderRadius: 2,
    );
    expect(highlight.shouldRepaint(highlight), isFalse);
    expect(
      highlight.shouldRepaint(
        KakuroHighlightPainter(
          cellRect: const Rect.fromLTWH(1, 0, 20, 20),
          highlightPaint: linePaint,
          runRects: const <Rect>[Rect.fromLTWH(20, 0, 20, 20)],
          runPaint: whitePaint,
          animationValue: 1,
          borderRadius: 2,
        ),
      ),
      isTrue,
    );

    final cellHighlight = KakuroCellHighlightPainter(
      cellRect: const Rect.fromLTWH(0, 0, 20, 20),
      highlightPaint: linePaint,
      animationValue: 1,
      borderRadius: 2,
    );
    expect(cellHighlight.shouldRepaint(cellHighlight), isFalse);
    expect(
      cellHighlight.shouldRepaint(
        KakuroCellHighlightPainter(
          cellRect: const Rect.fromLTWH(0, 0, 20, 20),
          highlightPaint: linePaint,
          animationValue: 0.5,
          borderRadius: 2,
        ),
      ),
      isTrue,
    );
  });
}

class _KakuroHarness extends StatelessWidget {
  const _KakuroHarness({
    required this.puzzle,
    this.onMove,
    this.notes = const <int, Set<int>>{},
    this.hintCells,
    this.hintAnimationValue = 0,
    this.side = 300,
  });

  final core.GeneratedPuzzle<core.KakuroBoard> puzzle;
  final ValueChanged<core.KakuroMove>? onMove;
  final Map<int, Set<int>> notes;
  final List<Offset>? hintCells;
  final double hintAnimationValue;
  final double side;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(
        body: Center(
          child: SizedBox.square(
            dimension: side,
            child: KakuroRendererWidget(
              puzzle: puzzle,
              notes: notes,
              hintCells: hintCells,
              hintAnimationValue: hintAnimationValue,
              onMove: (move) => onMove?.call(move as core.KakuroMove),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _tapCell(
  WidgetTester tester, {
  required int col,
  required int row,
}) async {
  final topLeft = tester.getTopLeft(find.byType(KakuroRendererWidget));
  const padding = 8.0;
  const spacing = 1.0;
  const side = 300.0;
  const cellSize = (side - (padding * 2) - (spacing * 3)) / 4;
  final cellWithSpacing = cellSize + spacing;
  await tester.tapAt(
    topLeft +
        Offset(
          padding + (col * cellWithSpacing) + (cellSize / 2),
          padding + (row * cellWithSpacing) + (cellSize / 2),
        ),
  );
}

core.GeneratedPuzzle<core.KakuroBoard> _buildKakuroPuzzle({
  int valueAtCenter = 1,
}) {
  return core.GeneratedPuzzle<core.KakuroBoard>(
    state: _kakuroBoard(valueAtCenter: valueAtCenter),
    meta: const core.PuzzleMetadata(
      engineVersion: 'test',
      rngId: 'test',
      size: core.SizeOpt(id: '4x4', description: '4x4', width: 4, height: 4),
      difficulty: core.DifficultyScore(value: 0.3, level: 'easy'),
      seedStr: 'test:kakuro',
      seed64: 42,
    ),
  );
}

core.KakuroBoard _kakuroBoard({int valueAtCenter = 1}) {
  return core.KakuroBoard(
    width: 4,
    height: 4,
    cellTypes: const <int>[
      core.KakuroBoard.cellBlack,
      core.KakuroBoard.cellClue,
      core.KakuroBoard.cellClue,
      core.KakuroBoard.cellBlack,
      core.KakuroBoard.cellClue,
      core.KakuroBoard.cellWhite,
      core.KakuroBoard.cellWhite,
      core.KakuroBoard.cellBlack,
      core.KakuroBoard.cellClue,
      core.KakuroBoard.cellWhite,
      core.KakuroBoard.cellWhite,
      core.KakuroBoard.cellBlack,
      core.KakuroBoard.cellBlack,
      core.KakuroBoard.cellBlack,
      core.KakuroBoard.cellBlack,
      core.KakuroBoard.cellBlack,
    ],
    cellValues: <int>[
      0,
      0,
      0,
      0,
      0,
      valueAtCenter,
      0,
      0,
      0,
      0,
      4,
      0,
      0,
      0,
      0,
      0,
    ],
    acrossClues: const <int>[0, 0, 0, 0, 3, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0],
    downClues: const <int>[0, 4, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  );
}

GridMetrics _metrics() {
  return const GridMetrics(
    cellSize: Size.square(40),
    gridSize: Size.square(163),
    gridOffset: Offset(8, 8),
    padding: 8,
    cellSpacing: 1,
    rows: 4,
    columns: 4,
  );
}
