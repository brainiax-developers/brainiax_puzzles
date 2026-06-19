import 'package:app/shared/models/puzzle_input_moves.dart';
import 'package:app/shared/widgets/nonogram_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import '../helpers/test_puzzle_data.dart';

void main() {
  testWidgets('drag across empty cells emits one batch fill move', (
    tester,
  ) async {
    final moves = <dynamic>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 360,
            child: NonogramRendererWidget(
              puzzle: _emptyNonogramPuzzle(),
              onMove: moves.add,
            ),
          ),
        ),
      ),
    );

    final state = tester.state<NonogramRenderer>(
      find.byType(NonogramRendererWidget),
    );
    state.onPanStart(DragStartDetails(localPosition: const Offset(80, 80)));
    state.onPanUpdate(
      DragUpdateDetails(
        globalPosition: const Offset(140, 80),
        localPosition: const Offset(140, 80),
      ),
    );
    state.onPanUpdate(
      DragUpdateDetails(
        globalPosition: const Offset(80, 80),
        localPosition: const Offset(80, 80),
      ),
    );
    state.onPanUpdate(
      DragUpdateDetails(
        globalPosition: const Offset(200, 80),
        localPosition: const Offset(200, 80),
      ),
    );
    state.onPanEnd(DragEndDetails());
    await tester.pump();

    expect(moves, hasLength(1));
    final batch = moves.single as NonogramBatchMove;
    expect(batch.moves, hasLength(3));
    expect(
      batch.moves.map(
        (core.NonogramMove move) => (move.row, move.col, move.value),
      ),
      containsAll(<(int, int, int?)>{(0, 0, 1), (0, 1, 1), (0, 2, 1)}),
    );
  });

  testWidgets('cross-mode drag emits cross helper marks', (tester) async {
    final moves = <dynamic>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 360,
            child: NonogramRendererWidget(
              puzzle: _emptyNonogramPuzzle(),
              crossMode: true,
              onMove: moves.add,
            ),
          ),
        ),
      ),
    );

    final state = tester.state<NonogramRenderer>(
      find.byType(NonogramRendererWidget),
    );
    state.onPanStart(DragStartDetails(localPosition: const Offset(80, 80)));
    state.onPanUpdate(
      DragUpdateDetails(
        globalPosition: const Offset(140, 80),
        localPosition: const Offset(140, 80),
      ),
    );
    state.onPanEnd(DragEndDetails());
    await tester.pump();

    expect(moves, hasLength(1));
    final batch = moves.single as NonogramBatchMove;
    expect(
      batch.moves.map((core.NonogramMove move) => move.value),
      everyElement(0),
    );
  });
}

core.GeneratedPuzzle<core.NonogramBoard> _emptyNonogramPuzzle() {
  final base = buildNonogramPuzzle();
  final board = base.state.copyWith(
    cells: List<int?>.filled(base.state.cellCount, null),
  );
  return core.GeneratedPuzzle<core.NonogramBoard>(
    state: board,
    meta: base.meta,
  );
}
