import 'package:app/shared/providers/game_state_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import '../../helpers/test_puzzle_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    core.EngineRegistry().clear();
    core.EngineRegistry().register(TestSudokuEngine());
  });

  tearDown(() {
    core.EngineRegistry().clear();
  });

  test(
    'makeMove returns false and records no history for no-op clear',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final puzzle = buildSudokuPuzzle();

      await container
          .read(gameStateProvider.notifier)
          .startWithGeneratedPuzzle(
            engineId: 'sudoku_classic',
            seed: puzzle.meta.seedStr,
            difficulty: puzzle.meta.difficulty.level,
            size: puzzle.meta.size.id,
            puzzle: puzzle,
          );

      final changed = await container
          .read(gameStateProvider.notifier)
          .makeMove(const core.SudokuMove(row: 0, col: 0, digit: 0));

      expect(changed, isFalse);
      expect(container.read(gameStateProvider.notifier).canUndo, isFalse);
    },
  );

  test('invalid rejected move does not record history', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final puzzle = buildSudokuPuzzle();

    await container
        .read(gameStateProvider.notifier)
        .startWithGeneratedPuzzle(
          engineId: 'sudoku_classic',
          seed: puzzle.meta.seedStr,
          difficulty: puzzle.meta.difficulty.level,
          size: puzzle.meta.size.id,
          puzzle: puzzle,
        );

    expect(
      () => container
          .read(gameStateProvider.notifier)
          .makeMove(const core.SudokuMove(row: 0, col: 0, digit: 9)),
      throwsException,
    );
    expect(container.read(gameStateProvider.notifier).canUndo, isFalse);
  });

  test('Sudoku placement cleanup clears same-cell and peer notes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final puzzle = buildSudokuPuzzle();
    final notifier = container.read(gameStateProvider.notifier);

    await notifier.startWithGeneratedPuzzle(
      engineId: 'sudoku_classic',
      seed: puzzle.meta.seedStr,
      difficulty: puzzle.meta.difficulty.level,
      size: puzzle.meta.size.id,
      puzzle: puzzle,
    );

    notifier.recordNoteAction(0, 5, true);
    notifier.recordNoteAction(1, 5, true);
    notifier.recordNoteAction(40, 5, true);

    final changed = await notifier.makeMove(
      const core.SudokuMove(row: 0, col: 0, digit: 5),
    );
    notifier.cleanupSudokuNotesForPlacement(row: 0, col: 0, digit: 5);

    expect(changed, isTrue);
    expect(container.read(gameStateProvider)!.notes.containsKey(0), isFalse);
    expect(container.read(gameStateProvider)!.notes.containsKey(1), isFalse);
    expect(container.read(gameStateProvider)!.notes[40], contains(5));
  });
}
