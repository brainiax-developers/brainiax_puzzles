import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/play/play_screen.dart';
import 'package:app/shared/providers/game_state_provider.dart';
import 'package:app/shared/widgets/sudoku_renderer.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import 'package:app/shared/models/models.dart';

import '../helpers/test_puzzle_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    core.EngineRegistry().clear();
  });

  tearDown(() {
    core.EngineRegistry().clear();
  });

  testWidgets('solving updates status and records completion stats', (tester) async {
    final engine = TestSudokuEngine();
    core.EngineRegistry().register(engine);

    final solved = buildSudokuPuzzle(solved: true);
    final puzzleBoard = solved.state.setCell(0, 0, 0);
    final puzzle = core.GeneratedPuzzle<core.SudokuBoard>(
      state: puzzleBoard,
      meta: solved.meta,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PlayScreen(
            puzzleType: PuzzleType.sudokuClassic,
            mode: PuzzleMode.random,
            puzzleInstance: puzzle,
            difficulty: 'Easy',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final sudokuFinder = find.byType(SudokuRendererWidget);
    expect(sudokuFinder, findsOneWidget);

    final renderBox = tester.renderObject<RenderBox>(sudokuFinder);
    final topLeft = renderBox.localToGlobal(Offset.zero);
    final cellSize = renderBox.size.width / core.SudokuBoard.side;
    final cellCenter = topLeft + Offset(cellSize / 2, cellSize / 2);

    await tester.tapAt(cellCenter);
    await tester.pump();

    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    expect(find.text('Solved'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final key = 'puzzle_local_store.v1.best_time.${PuzzleType.sudokuClassic.key}.easy';
    expect(prefs.containsKey(key), isTrue);
    expect(find.textContaining('Streak'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayScreen)),
    );
    expect(container.read(gameStateProvider)?.isSolved, isTrue);
  });
}
