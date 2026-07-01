import 'package:app/shared/widgets/sudoku_renderer.dart';
import 'package:app/shared/widgets/takuzu_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import '../helpers/test_puzzle_data.dart';

void main() {
  testWidgets(
    'sudoku renderer handles editable, fixed, hint, and error paths',
    (WidgetTester tester) async {
      final moves = <core.SudokuMove>[];

      await tester.pumpWidget(
        _rendererApp(
          SudokuRendererWidget(
            puzzle: buildSudokuPuzzle(),
            notes: const <int, Set<int>>{
              1: <int>{2, 4, 10},
            },
            hintCells: const <Offset>[Offset(1, 0)],
            hintAnimationValue: 1,
            hintFilledCells: const <int>{0},
            onMove: (move) => moves.add(move as core.SudokuMove),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final finder = find.byType(SudokuRendererWidget);
      final state = tester.state<SudokuRenderer>(finder);
      final context = tester.element(finder);

      await _tapGridCell(tester, finder, side: 300, grid: 9, col: 0, row: 0);
      state.onDigitInput(5);
      state.onClearCell();
      await tester.pump(const Duration(milliseconds: 200));
      expect(moves, <core.SudokuMove>[
        const core.SudokuMove(row: 0, col: 0, digit: 5),
        const core.SudokuMove(row: 0, col: 0, digit: 0),
      ]);

      await _tapGridCell(tester, finder, side: 300, grid: 9, col: 2, row: 0);
      state.onDigitInput(9);
      state.onClearCell();
      expect(moves, hasLength(2), reason: 'fixed cells ignore edits');

      state.setErrorPositions(<Offset>{const Offset(0, 0)});
      await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        state.buildCellContent(
          context,
          const Offset(0, 0),
          const Size.square(24),
        ),
        isA<AnimatedBuilder>(),
      );
      expect(
        state.buildSelectionHighlight(
          context,
          const Offset(0, 0),
          const Size.square(24),
        ),
        isA<AnimatedBuilder>(),
      );
      expect(
        state.buildErrorHighlight(
          context,
          const Offset(0, 0),
          const Size.square(24),
        ),
        isA<AnimatedBuilder>(),
      );
      expect(
        state.buildHintHighlight(
          context,
          const Offset(1, 0),
          const Size.square(24),
        ),
        isA<CustomPaint>(),
      );

      await tester.pumpWidget(
        _rendererApp(
          SudokuRendererWidget(
            puzzle: buildSudokuPuzzle().state.setCell(0, 0, 5).letPuzzle(),
            onMove: (move) => moves.add(move as core.SudokuMove),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'takuzu renderer cycles cells, handles keys, and shows violations',
    (WidgetTester tester) async {
      final moves = <core.TakuzuMove>[];
      final puzzle = _violatingTakuzuPuzzle();

      await tester.pumpWidget(
        _rendererApp(
          TakuzuRendererWidget(
            puzzle: puzzle,
            hintCells: const <Offset>[Offset(1, 1)],
            onMove: (move) => moves.add(move as core.TakuzuMove),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final finder = find.byType(TakuzuRendererWidget);
      final state = tester.state<TakuzuRenderer>(finder);
      final context = tester.element(finder);

      await _tapGridCell(tester, finder, side: 300, grid: 4, col: 1, row: 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(moves.last, const core.TakuzuMove(row: 1, col: 1, value: 0));

      state.onKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.digit1,
          logicalKey: LogicalKeyboardKey.digit1,
          character: '1',
          timeStamp: Duration.zero,
        ),
      );
      state.onKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.backspace,
          logicalKey: LogicalKeyboardKey.backspace,
          timeStamp: Duration.zero,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(moves, hasLength(1));

      await _tapGridCell(tester, finder, side: 300, grid: 4, col: 0, row: 0);
      expect(moves.where((move) => move.row == 0 && move.col == 0), isEmpty);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        state.buildCellContent(context, Offset.zero, const Size.square(24)),
        isA<SizedBox>(),
      );
      expect(
        state.buildSelectionHighlight(
          context,
          Offset.zero,
          const Size.square(24),
        ),
        isA<AnimatedBuilder>(),
      );
      expect(
        state.buildErrorHighlight(context, Offset.zero, const Size.square(24)),
        isA<AnimatedBuilder>(),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _rendererApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox.square(dimension: 300, child: child)),
    ),
  );
}

Future<void> _tapGridCell(
  WidgetTester tester,
  Finder finder, {
  required double side,
  required int grid,
  required int col,
  required int row,
}) async {
  final topLeft = tester.getTopLeft(finder);
  const padding = 16.0;
  const spacing = 1.0;
  final cellSize = (side - (padding * 2) - (spacing * (grid - 1))) / grid;
  final cellWithSpacing = cellSize + spacing;
  await tester.tapAt(
    topLeft +
        Offset(
          padding + col * cellWithSpacing + cellSize / 2,
          padding + row * cellWithSpacing + cellSize / 2,
        ),
  );
}

core.GeneratedPuzzle<core.TakuzuBoard> _violatingTakuzuPuzzle() {
  const cells = <int>[
    0,
    0,
    0,
    1,
    1,
    core.TakuzuBoard.emptyValue,
    1,
    0,
    0,
    0,
    1,
    1,
    1,
    1,
    0,
    0,
  ];
  const fixed = <bool>[
    true,
    true,
    true,
    true,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
  ];
  return core.GeneratedPuzzle<core.TakuzuBoard>(
    state: core.TakuzuBoard(size: 4, cells: cells, fixed: fixed),
    meta: buildTakuzuPuzzle().meta,
  );
}

extension on core.SudokuBoard {
  core.GeneratedPuzzle<core.SudokuBoard> letPuzzle() {
    return core.GeneratedPuzzle<core.SudokuBoard>(
      state: this,
      meta: buildSudokuPuzzle().meta,
    );
  }
}
