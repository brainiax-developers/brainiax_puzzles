import 'package:app/shared/widgets/kakuro_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

void main() {
  test('run state is incomplete until every run cell is filled', () {
    final board = _clueBoard(values: const <int>[0, 0]);

    expect(
      KakuroRunInspector.forEntry(board, board.entries[0]),
      KakuroRunState.incomplete,
    );
    expect(
      KakuroRunInspector.forClue(
        board: board,
        row: 0,
        col: 0,
        direction: core.KakuroDirection.across,
      ),
      KakuroRunState.incomplete,
    );
  });

  test('run state detects completed correct and incorrect sums', () {
    final correct = _clueBoard(values: const <int>[4, 6]);
    final wrong = _clueBoard(values: const <int>[3, 6]);

    expect(
      KakuroRunInspector.forEntry(correct, correct.entries[0]),
      KakuroRunState.completeCorrect,
    );
    expect(
      KakuroRunInspector.forEntry(wrong, wrong.entries[0]),
      KakuroRunState.completeIncorrect,
    );
  });

  testWidgets('renders notes for playable cells', (WidgetTester tester) async {
    final board = _clueBoard(values: const <int>[0, 0]);
    final notes = <int, Set<int>>{
      1: {2, 3, 4},
    };
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KakuroRendererWidget(
            puzzle: core.GeneratedPuzzle<core.KakuroBoard>(
              state: board,
              meta: const core.PuzzleMetadata(
                engineVersion: '1.0',
                rngId: 'test',
                seed64: 0,
                seedStr: 'test',
                difficulty: core.DifficultyScore(value: 0, level: 'easy'),
                size: core.SizeOpt(id: '3x1', description: '3x1', width: 3, height: 1),
              ),
            ),
            notes: notes,
          ),
        ),
      ),
    );
    
    expect(find.byType(KakuroRendererWidget), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}

core.KakuroBoard _clueBoard({required List<int> values}) {
  return core.KakuroBoard(
    width: 3,
    height: 1,
    kinds: const <core.KakuroCellKind>[
      core.KakuroCellKind.block,
      core.KakuroCellKind.value,
      core.KakuroCellKind.value,
    ],
    values: <int>[0, ...values],
    acrossClues: const <int?>[10, null, null],
    downClues: const <int?>[null, null, null],
    entries: const <core.KakuroEntry>[
      core.KakuroEntry(
        id: 0,
        direction: core.KakuroDirection.across,
        cells: <int>[1, 2],
        sum: 10,
      ),
    ],
    acrossEntryForCell: const <int>[-1, 0, 0],
    downEntryForCell: const <int>[-1, -1, -1],
  );
}
