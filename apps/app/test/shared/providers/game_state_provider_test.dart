import 'package:app/shared/providers/game_state_provider.dart';
import 'package:app/shared/models/puzzle_input_moves.dart';
import 'package:app/shared/services/generation_isolate.dart';
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

  test(
    'startNewGame preserves measured difficulty when worker metadata differs',
    () async {
      final worker = _SinglePuzzleGenerationWorker(
        buildSudokuPuzzle(difficulty: 'hard'),
      );
      final container = ProviderContainer(
        overrides: [puzzleGenerationWorkerProvider.overrideWithValue(worker)],
      );
      addTearDown(container.dispose);

      await container
          .read(gameStateProvider.notifier)
          .startNewGame(
            engineId: 'sudoku_classic',
            seed: 'selected-easy',
            difficulty: 'easy',
            size: '9x9',
          );

      final state = container.read(gameStateProvider)!;
      expect(worker.request?.difficulty.level, equals('easy'));
      expect(state.difficulty, equals('hard'));
      expect(state.puzzle.meta.difficulty.level, equals('hard'));
      expect(
        state.puzzle.telemetry?.extras['requestedDifficulty'],
        equals('easy'),
      );
      expect(state.puzzle.telemetry?.extras['difficultyMismatch'], isTrue);
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

  test('restored notes and silent note clears do not add history', () async {
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
      notes: const <int, Set<int>>{
        0: <int>{1, 2},
      },
    );

    expect(
      container.read(gameStateProvider)!.notes[0],
      containsAll(<int>{1, 2}),
    );
    notifier.clearNotesForCell(0, recordHistory: false);

    expect(container.read(gameStateProvider)!.notes.containsKey(0), isFalse);
    expect(notifier.actionHistory, isEmpty);
  });

  test('restored notes remain the undo baseline after a new move', () async {
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
      notes: const <int, Set<int>>{
        40: <int>{5},
      },
    );

    await notifier.makeMove(const core.SudokuMove(row: 0, col: 0, digit: 5));
    notifier.undo();

    expect(container.read(gameStateProvider)!.notes[40], contains(5));
  });

  test(
    'Killer Queens queen placement auto-crosses as one history action',
    () async {
      core.EngineRegistry().register(const _TestKillerQueensEngine());
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final puzzle = _buildKillerQueensProviderPuzzle();
      final notifier = container.read(gameStateProvider.notifier);

      await notifier.startWithGeneratedPuzzle(
        engineId: 'killer_queens',
        seed: puzzle.meta.seedStr,
        difficulty: puzzle.meta.difficulty.level,
        size: puzzle.meta.size.id,
        puzzle: puzzle,
      );

      final changed = await notifier.makeMove(
        const core.KillerQueensMove(row: 2, col: 2, value: 1),
      );

      final board =
          container.read(gameStateProvider)!.puzzle.state
              as core.KillerQueensBoard;
      expect(changed, isTrue);
      expect(notifier.actionHistory, hasLength(1));
      expect(board.valueAt(2, 2), 1);
      expect(board.valueAt(2, 0), 1, reason: 'existing queens are preserved');
      expect(board.valueAt(0, 2), 1, reason: 'fixed queens are preserved');
      expect(board.valueAt(2, 1), 2);
      expect(board.valueAt(2, 3), 2);
      expect(board.valueAt(1, 2), 2);
      expect(board.valueAt(3, 2), 2);
      expect(board.valueAt(1, 1), 2);
      expect(board.valueAt(1, 3), 2);
      expect(board.valueAt(3, 1), 2);
      expect(board.valueAt(3, 3), 2);

      notifier.undo();
      expect(
        container.read(gameStateProvider)!.puzzle.state,
        puzzle.state,
        reason: 'auto-crossing replays as a single undoable action',
      );
    },
  );

  test('Killer Queens conflict indicators survive auto-crossing', () async {
    core.EngineRegistry().register(const _TestKillerQueensEngine());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final puzzle = _buildKillerQueensProviderPuzzle();
    final notifier = container.read(gameStateProvider.notifier);

    await notifier.startWithGeneratedPuzzle(
      engineId: 'killer_queens',
      seed: puzzle.meta.seedStr,
      difficulty: puzzle.meta.difficulty.level,
      size: puzzle.meta.size.id,
      puzzle: puzzle,
    );

    await notifier.makeMove(
      const core.KillerQueensMove(row: 2, col: 2, value: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2100));

    final state = container.read(gameStateProvider)!;
    expect(state.isShowingConflicts, isTrue);
    expect(state.conflictingCells, containsAll(<int>{2, 8, 10}));
  });

  test('Nonogram batch move applies once and skips no-op batches', () async {
    core.EngineRegistry().register(const _TestNonogramEngine());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final puzzle = _buildNonogramProviderPuzzle();
    final notifier = container.read(gameStateProvider.notifier);

    await notifier.startWithGeneratedPuzzle(
      engineId: 'nonogram_mono',
      seed: puzzle.meta.seedStr,
      difficulty: puzzle.meta.difficulty.level,
      size: puzzle.meta.size.id,
      puzzle: puzzle,
    );

    final changed = await notifier.makeMove(
      const NonogramBatchMove(<core.NonogramMove>[
        core.NonogramMove(row: 0, col: 0, value: 1),
        core.NonogramMove(row: 0, col: 1, value: 1),
      ]),
    );

    var board =
        container.read(gameStateProvider)!.puzzle.state as core.NonogramBoard;
    expect(changed, isTrue);
    expect(notifier.actionHistory, hasLength(1));
    expect(board.cellAt(0, 0), 1);
    expect(board.cellAt(0, 1), 1);

    final noOp = await notifier.makeMove(
      const NonogramBatchMove(<core.NonogramMove>[
        core.NonogramMove(row: 0, col: 0, value: 1),
      ]),
    );

    board =
        container.read(gameStateProvider)!.puzzle.state as core.NonogramBoard;
    expect(noOp, isFalse);
    expect(notifier.actionHistory, hasLength(1));
    expect(board.cellAt(0, 0), 1);
  });

  test('Kakuro move history supports notes, undo, redo, and reset', () async {
    core.EngineRegistry().register(const _TestKakuroEngine());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final puzzle = buildKakuroPuzzle();
    final notifier = container.read(gameStateProvider.notifier);

    await notifier.startWithGeneratedPuzzle(
      engineId: 'kakuro',
      seed: puzzle.meta.seedStr,
      difficulty: puzzle.meta.difficulty.level,
      size: puzzle.meta.size.id,
      puzzle: puzzle,
    );

    notifier.recordNoteAction(5, 1, true);
    expect(container.read(gameStateProvider)!.notes[5], contains(1));
    expect(notifier.canUndo, isTrue);

    final changed = await notifier.makeMove(
      const core.KakuroMove(index: 5, value: 1),
    );
    expect(changed, isTrue);
    var board =
        container.read(gameStateProvider)!.puzzle.state as core.KakuroBoard;
    expect(board.cellValues[5], 1);

    notifier.undo();
    board = container.read(gameStateProvider)!.puzzle.state as core.KakuroBoard;
    expect(board.cellValues[5], 0);
    expect(container.read(gameStateProvider)!.notes[5], contains(1));

    notifier.undo();
    expect(container.read(gameStateProvider)!.notes.containsKey(5), isFalse);

    notifier.redo();
    notifier.redo();
    board = container.read(gameStateProvider)!.puzzle.state as core.KakuroBoard;
    expect(board.cellValues[5], 1);
    expect(container.read(gameStateProvider)!.notes[5], contains(1));

    notifier.resetToInitial();
    board = container.read(gameStateProvider)!.puzzle.state as core.KakuroBoard;
    expect(board.cellValues[5], 0);
    expect(container.read(gameStateProvider)!.notes, isEmpty);
  });

  test('Kakuro rejects invalid moves without adding history', () async {
    core.EngineRegistry().register(const _TestKakuroEngine());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final puzzle = buildKakuroPuzzle();
    final notifier = container.read(gameStateProvider.notifier);

    await notifier.startWithGeneratedPuzzle(
      engineId: 'kakuro',
      seed: puzzle.meta.seedStr,
      difficulty: puzzle.meta.difficulty.level,
      size: puzzle.meta.size.id,
      puzzle: puzzle,
    );

    expect(
      () => notifier.makeMove(const core.KakuroMove(index: 0, value: 1)),
      throwsException,
    );
    expect(notifier.actionHistory, isEmpty);
    expect(notifier.canUndo, isFalse);
  });

  test('game actions serialize note and move records', () {
    final timestamp = DateTime.utc(2026, 7, 1, 12);
    final move = GameMoveAction(
      timestamp: timestamp,
      actionIndex: 1,
      move: const core.KakuroMove(index: 5, value: 1),
    );
    final note = NoteAction(
      timestamp: timestamp,
      actionIndex: 2,
      cellIndex: 5,
      digit: 3,
      isAdding: true,
    );

    expect(move.toJson()['move'], <String, dynamic>{'index': 5, 'value': 1});
    expect(note.toJson()['cellIndex'], 5);
    expect(GameAction.fromJson(note.toJson()), isA<NoteAction>());
    expect(GameAction.fromJson(move.toJson()), isA<GameMoveAction>());
    expect(
      () => GameAction.fromJson(<String, dynamic>{'type': 'unknown'}),
      throwsUnsupportedError,
    );
  });
}

core.GeneratedPuzzle<core.KillerQueensBoard>
_buildKillerQueensProviderPuzzle() {
  const int size = 4;
  final cells = List<int>.filled(size * size, 0);
  final fixed = List<bool>.filled(size * size, false);
  cells[2] = 1;
  fixed[2] = true;
  cells[8] = 1;
  final cages = <core.KillerQueensCage>[
    for (int index = 0; index < size * size; index++)
      core.KillerQueensCage(cells: <int>[index]),
  ];
  return core.GeneratedPuzzle<core.KillerQueensBoard>(
    state: core.KillerQueensBoard(
      size: size,
      cells: cells,
      fixed: fixed,
      cages: cages,
    ),
    meta: buildKillerQueensPuzzle().meta,
  );
}

class _SinglePuzzleGenerationWorker implements PuzzleGenerationWorker {
  _SinglePuzzleGenerationWorker(this.puzzle);

  final core.GeneratedPuzzle<dynamic> puzzle;
  PuzzleGenerationRequest? request;

  @override
  Future<core.GeneratedPuzzle<dynamic>> generate(
    PuzzleGenerationRequest request, {
    Duration? timeout,
  }) async {
    this.request = request;
    return puzzle;
  }
}

core.GeneratedPuzzle<core.NonogramBoard> _buildNonogramProviderPuzzle() {
  return core.GeneratedPuzzle<core.NonogramBoard>(
    state: core.NonogramBoard.empty(
      width: 3,
      height: 3,
      rowClues: const <List<int>>[
        <int>[2],
        <int>[],
        <int>[],
      ],
      columnClues: const <List<int>>[
        <int>[1],
        <int>[1],
        <int>[],
      ],
    ),
    meta: buildNonogramPuzzle().meta,
  );
}

class _TestKillerQueensEngine
    implements
        core.PuzzleEngine<core.KillerQueensBoard, core.KillerQueensMove> {
  const _TestKillerQueensEngine();

  @override
  String get id => 'killer_queens';

  @override
  String get name => 'Test Killer Queens';

  @override
  String get version => '1.0.0';

  @override
  core.PuzzleCapabilities get capabilities => const core.PuzzleCapabilities();

  @override
  core.GeneratedPuzzle<core.KillerQueensBoard> generate({
    required String seedStr,
    required int seed64,
    required core.SizeOpt size,
    required core.DifficultyScore difficulty,
  }) {
    return _buildKillerQueensProviderPuzzle();
  }

  @override
  bool isSolved(core.KillerQueensBoard state) => false;

  @override
  core.PuzzleHint? requestHint({
    required core.KillerQueensBoard currentState,
    core.PuzzleHintRequest? request,
  }) {
    return null;
  }

  @override
  core.MoveResult<core.KillerQueensBoard> validateMove({
    required core.KillerQueensBoard currentState,
    required core.KillerQueensMove move,
  }) {
    return core.MoveResult.success(
      currentState.setCell(move.row, move.col, move.value),
    );
  }
}

class _TestNonogramEngine
    implements core.PuzzleEngine<core.NonogramBoard, core.NonogramMove> {
  const _TestNonogramEngine();

  @override
  String get id => 'nonogram_mono';

  @override
  String get name => 'Test Nonogram';

  @override
  String get version => '1.0.0';

  @override
  core.PuzzleCapabilities get capabilities => const core.PuzzleCapabilities();

  @override
  core.GeneratedPuzzle<core.NonogramBoard> generate({
    required String seedStr,
    required int seed64,
    required core.SizeOpt size,
    required core.DifficultyScore difficulty,
  }) {
    return _buildNonogramProviderPuzzle();
  }

  @override
  bool isSolved(core.NonogramBoard state) =>
      state.cellAt(0, 0) == 1 && state.cellAt(0, 1) == 1;

  @override
  core.PuzzleHint? requestHint({
    required core.NonogramBoard currentState,
    core.PuzzleHintRequest? request,
  }) {
    return null;
  }

  @override
  core.MoveResult<core.NonogramBoard> validateMove({
    required core.NonogramBoard currentState,
    required core.NonogramMove move,
  }) {
    if (move.row < 0 || move.row >= currentState.height) {
      return core.MoveResult.failure('row_out_of_range');
    }
    if (move.col < 0 || move.col >= currentState.width) {
      return core.MoveResult.failure('col_out_of_range');
    }
    final cells = List<int?>.from(currentState.cells);
    cells[currentState.indexOf(move.row, move.col)] = move.value;
    return core.MoveResult.success(currentState.copyWith(cells: cells));
  }
}

class _TestKakuroEngine
    implements core.PuzzleEngine<core.KakuroBoard, core.KakuroMove> {
  const _TestKakuroEngine();

  @override
  String get id => 'kakuro';

  @override
  String get name => 'Test Kakuro';

  @override
  String get version => '1.0.0';

  @override
  core.PuzzleCapabilities get capabilities => const core.PuzzleCapabilities();

  @override
  core.GeneratedPuzzle<core.KakuroBoard> generate({
    required String seedStr,
    required int seed64,
    required core.SizeOpt size,
    required core.DifficultyScore difficulty,
  }) {
    return buildKakuroPuzzle();
  }

  @override
  bool isSolved(core.KakuroBoard state) {
    final solved = buildKakuroPuzzle(solved: true).state;
    for (int i = 0; i < state.cellCount; i++) {
      if (state.cellValues[i] != solved.cellValues[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  core.PuzzleHint? requestHint({
    required core.KakuroBoard currentState,
    core.PuzzleHintRequest? request,
  }) {
    return null;
  }

  @override
  core.MoveResult<core.KakuroBoard> validateMove({
    required core.KakuroBoard currentState,
    required core.KakuroMove move,
  }) {
    if (move.index < 0 || move.index >= currentState.cellCount) {
      return core.MoveResult.failure('index_out_of_range');
    }
    if (!currentState.isWhite(move.index)) {
      return core.MoveResult.failure('cell_is_not_white');
    }
    if (move.value < 0 || move.value > 9) {
      return core.MoveResult.failure('digit_out_of_range');
    }
    return core.MoveResult.success(
      currentState.setCellValue(move.index, move.value),
    );
  }
}
