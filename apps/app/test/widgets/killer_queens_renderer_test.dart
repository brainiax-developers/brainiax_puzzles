import 'package:app/shared/widgets/killer_queens_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import '../helpers/test_puzzle_data.dart';

void main() {
  testWidgets('Queen mode emits a queen placement move', (tester) async {
    final moves = <core.KillerQueensMove>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 360,
            child: KillerQueensRendererWidget(
              puzzle: buildKillerQueensPuzzle(),
              inputMode: KillerQueensInputMode.queen,
              onMove: (move) => moves.add(move as core.KillerQueensMove),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(
      tester.getTopLeft(find.byType(KillerQueensRendererWidget)) +
          const Offset(40, 40),
    );
    await tester.pump();

    expect(moves, hasLength(1));
    expect(moves.single, const core.KillerQueensMove(row: 0, col: 0, value: 1));
  });

  testWidgets('Cross mode emits a cross move, not a queen move', (
    tester,
  ) async {
    final moves = <core.KillerQueensMove>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 360,
            child: KillerQueensRendererWidget(
              puzzle: buildKillerQueensPuzzle(),
              inputMode: KillerQueensInputMode.cross,
              onMove: (move) => moves.add(move as core.KillerQueensMove),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(
      tester.getTopLeft(find.byType(KillerQueensRendererWidget)) +
          const Offset(40, 40),
    );
    await tester.pump();

    expect(moves, hasLength(1));
    expect(moves.single, const core.KillerQueensMove(row: 0, col: 0, value: 2));
  });
}
