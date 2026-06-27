import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/play/play_screen.dart';
import 'package:app/shared/providers/puzzle_generation_controller.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/theme/app_theme.dart';
import 'package:app/shared/widgets/sudoku_renderer.dart';
import 'package:app/shared/services/puzzle_registry.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

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

  testWidgets('play screen interaction frames stay under 16ms', (tester) async {
    final engine = TestSudokuEngine();
    core.EngineRegistry().register(engine);

    final solved = buildSudokuPuzzle(solved: true);
    final puzzleBoard = solved.state.setCell(0, 0, 0);
    final puzzle = core.GeneratedPuzzle<core.SudokuBoard>(
      state: puzzleBoard,
      meta: solved.meta,
    );

    final frameTimings = <FrameTiming>[];
    void timingsCallback(List<FrameTiming> timings) =>
        frameTimings.addAll(timings);
    tester.binding.addTimingsCallback(timingsCallback);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: PlayScreen(
            puzzleType: PuzzleType.sudokuClassic,
            mode: PuzzleMode.random,
            puzzleInstance: puzzle,
            difficulty: 'easy',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final sudokuFinder = find.byType(SudokuRendererWidget);
    final renderBox = tester.renderObject<RenderBox>(sudokuFinder);
    final topLeft = renderBox.localToGlobal(Offset.zero);
    final cellSize = renderBox.size.width / core.SudokuBoard.side;
    final cellCenter = topLeft + Offset(cellSize / 2, cellSize / 2);

    await tester.tapAt(cellCenter);
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    tester.binding.removeTimingsCallback(timingsCallback);

    expect(frameTimings, isNotEmpty);
    for (final timing in frameTimings) {
      expect(
        timing.totalSpan,
        lessThanOrEqualTo(const Duration(milliseconds: 16)),
      );
    }
  });

  test('puzzle generation completes under 100ms SLA', () async {
    final engine = TestSudokuEngine();
    core.EngineRegistry().register(engine);
    final registry = PuzzleRegistry();
    registry.initialize();

    final container = ProviderContainer();
    final controller = container.read(
      puzzleGenerationControllerProvider.notifier,
    );
    final stopwatch = Stopwatch()..start();
    final puzzle = await controller.generate(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'easy',
    );
    stopwatch.stop();

    expect(puzzle, isNotNull);
    expect(stopwatch.elapsed, lessThanOrEqualTo(puzzleGenerationPhase2Sla));
    container.dispose();
  });
}
