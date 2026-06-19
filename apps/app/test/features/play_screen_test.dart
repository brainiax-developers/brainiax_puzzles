import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/daily/daily_seed_generator.dart';
import 'package:app/features/play/play_screen.dart';
import 'package:app/features/daily/daily_providers.dart';
import 'package:app/shared/providers/game_state_provider.dart';
import 'package:app/shared/services/puzzle_local_store.dart';
import 'package:app/shared/widgets/nonogram_renderer.dart';
import 'package:app/shared/widgets/killer_queens_renderer.dart';
import 'package:app/shared/widgets/slitherlink_renderer.dart';
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

  testWidgets('solving updates status and records completion stats', (
    tester,
  ) async {
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

    tester.widget<SudokuRendererWidget>(sudokuFinder).onMove!(
      const core.SudokuMove(row: 0, col: 0, digit: 5),
    );
    await tester.pumpAndSettle();

    expect(find.text('Solved'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesPuzzleLocalStore(prefs);
    final records = await store.completionRecords();
    expect(records, hasLength(1));
    expect(records.single.puzzleType, PuzzleType.sudokuClassic);
    expect(records.single.mode, PuzzleMode.random);
    expect(records.single.difficulty, 'easy');
    expect(records.single.moveCount, 1);
    expect(await store.bestTime(PuzzleType.sudokuClassic, 'easy'), isNotNull);
    expect(find.textContaining('Random Play'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayScreen)),
    );
    expect(container.read(gameStateProvider)?.isSolved, isTrue);
  });

  testWidgets('Nonogram completes after final fill without requiring crosses', (
    tester,
  ) async {
    final puzzle = _buildAlmostSolvedNonogramPuzzle();
    core.EngineRegistry().register(_TestNonogramEngine(puzzle));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyPuzzleProvider.overrideWith(
            (ref, puzzleTypeKey) async => puzzle,
          ),
        ],
        child: MaterialApp(
          home: PlayScreen(
            puzzleType: PuzzleType.nonogramMono,
            mode: PuzzleMode.daily,
            puzzleInstance: puzzle,
            difficulty: 'Easy',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final nonogramFinder = find.byType(NonogramRendererWidget);
    expect(nonogramFinder, findsOneWidget);

    tester.widget<NonogramRendererWidget>(nonogramFinder).onMove!(
      const core.NonogramMove(row: 1, col: 1, value: 0),
    );
    await tester.pumpAndSettle();

    tester.widget<NonogramRendererWidget>(nonogramFinder).onMove!(
      const core.NonogramMove(row: 0, col: 0, value: 1),
    );
    await tester.pumpAndSettle();

    expect(find.text('Solved'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesPuzzleLocalStore(prefs);
    final records = await store.completionRecords();
    expect(records, hasLength(1));
    expect(records.single.puzzleType, PuzzleType.nonogramMono);
    expect(records.single.mode, PuzzleMode.daily);
    expect(records.single.moveCount, 1);
    expect(
      await store.isDailyCompleted(
        PuzzleType.nonogramMono,
        DailyUtcDate.todayKey(),
      ),
      isTrue,
    );
  });

  testWidgets(
    'Slitherlink completes after final loop edge without requiring crosses',
    (tester) async {
      final puzzle = _buildAlmostSolvedSlitherlinkPuzzle();
      core.EngineRegistry().register(_TestSlitherlinkEngine(puzzle));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyPuzzleProvider.overrideWith(
              (ref, puzzleTypeKey) async => puzzle,
            ),
          ],
          child: MaterialApp(
            home: PlayScreen(
              puzzleType: PuzzleType.slitherlinkLoop,
              mode: PuzzleMode.daily,
              puzzleInstance: puzzle,
              difficulty: 'Easy',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final slitherlinkFinder = find.byType(SlitherlinkRendererWidget);
      expect(slitherlinkFinder, findsOneWidget);

      tester.widget<SlitherlinkRendererWidget>(slitherlinkFinder).onMove!(
        const core.SlitherlinkMove(
          horizontal: true,
          row: 1,
          col: 0,
          value: core.SlitherlinkBoard.edgeOff,
        ),
      );
      await tester.pumpAndSettle();

      tester.widget<SlitherlinkRendererWidget>(slitherlinkFinder).onMove!(
        const core.SlitherlinkMove(
          horizontal: true,
          row: 0,
          col: 0,
          value: core.SlitherlinkBoard.edgeOn,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Solved'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesPuzzleLocalStore(prefs);
      final records = await store.completionRecords();
      expect(records, hasLength(1));
      expect(records.single.puzzleType, PuzzleType.slitherlinkLoop);
      expect(records.single.mode, PuzzleMode.daily);
      expect(records.single.moveCount, 1);
      expect(
        await store.isDailyCompleted(
          PuzzleType.slitherlinkLoop,
          DailyUtcDate.todayKey(),
        ),
        isTrue,
      );
    },
  );

  testWidgets('Killer Queens mode controls show and update selected mode', (
    tester,
  ) async {
    final puzzle = buildKillerQueensPuzzle();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PlayScreen(
            puzzleType: PuzzleType.killerQueens,
            mode: PuzzleMode.random,
            puzzleInstance: puzzle,
            difficulty: 'Easy',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final controls = tester.widget<SegmentedButton<KillerQueensInputMode>>(
      find.byType(SegmentedButton<KillerQueensInputMode>),
    );
    expect(controls.selected, <KillerQueensInputMode>{
      KillerQueensInputMode.queen,
    });
    expect(find.text('Queen'), findsOneWidget);
    expect(find.text('Cross'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);

    await tester.tap(find.text('Cross'));
    await tester.pumpAndSettle();

    final updatedControls = tester
        .widget<SegmentedButton<KillerQueensInputMode>>(
          find.byType(SegmentedButton<KillerQueensInputMode>),
        );
    expect(updatedControls.selected, <KillerQueensInputMode>{
      KillerQueensInputMode.cross,
    });
  });

  testWidgets('shows tutorial entry and disabled unsupported hints', (
    tester,
  ) async {
    final engine = TestSudokuEngine();
    core.EngineRegistry().register(engine);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PlayScreen(
            puzzleType: PuzzleType.sudokuClassic,
            mode: PuzzleMode.random,
            puzzleInstance: buildSudokuPuzzle(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Hint'), findsOneWidget);
    final InkWell hintButton = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('Hint'), matching: find.byType(InkWell))
          .first,
    );
    expect(hintButton.onTap, isNull);

    await tester.tap(find.byTooltip('How to Play'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Classic Sudoku'), findsWidgets);
    expect(find.text('Full tutorial coming soon.'), findsOneWidget);
  });

  testWidgets(
    'daily Kakuro shows loading immediately and does not render stale puzzle',
    (tester) async {
      core.EngineRegistry().register(
        core.StubPuzzleEngine(engineId: PuzzleType.sudokuClassic.key),
      );
      core.EngineRegistry().register(
        core.StubPuzzleEngine(engineId: PuzzleType.kakuroClassic.key),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          dailyPuzzleProvider.overrideWith((ref, puzzleTypeKey) async {
            if (puzzleTypeKey == PuzzleType.kakuroClassic.key) {
              await Future<void>.delayed(const Duration(milliseconds: 800));
              return buildKakuroPuzzle();
            }
            return buildSudokuPuzzle();
          }),
        ],
      );
      addTearDown(container.dispose);

      final core.GeneratedPuzzle<core.SudokuBoard> staleSudoku =
          buildSudokuPuzzle();
      await container
          .read(gameStateProvider.notifier)
          .startWithGeneratedPuzzle(
            engineId: PuzzleType.sudokuClassic.key,
            seed: staleSudoku.meta.seedStr,
            difficulty: staleSudoku.meta.difficulty.level,
            size: staleSudoku.meta.size.id,
            puzzle: staleSudoku,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: PlayScreen(
              puzzleType: PuzzleType.kakuroClassic,
              mode: PuzzleMode.daily,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SudokuRendererWidget), findsNothing);
      expect(find.text('Generating puzzle...'), findsOneWidget);

      // Drain the delayed stub future to avoid pending timer assertions.
      await tester.pump(const Duration(milliseconds: 900));
    },
  );
}

core.GeneratedPuzzle<core.NonogramBoard> _buildAlmostSolvedNonogramPuzzle() {
  final board = core.NonogramBoard(
    width: 2,
    height: 2,
    rowClues: const <List<int>>[
      <int>[1],
      <int>[],
    ],
    columnClues: const <List<int>>[
      <int>[1],
      <int>[],
    ],
    cells: const <int?>[null, null, null, null],
  );
  return core.GeneratedPuzzle<core.NonogramBoard>(
    state: board,
    meta: _metadataFor(
      size: '2x2',
      difficulty: 'easy',
      dailyPuzzleType: PuzzleType.nonogramMono,
    ),
  );
}

core.GeneratedPuzzle<core.SlitherlinkBoard>
_buildAlmostSolvedSlitherlinkPuzzle() {
  final topology = core.SlitherlinkTopology.forSize(2, 2);
  final loopEdges = <int>{
    topology.horizontalEdgeIndex(0, 1),
    topology.horizontalEdgeIndex(2, 0),
    topology.horizontalEdgeIndex(2, 1),
    topology.verticalEdgeIndex(0, 0),
    topology.verticalEdgeIndex(1, 0),
    topology.verticalEdgeIndex(0, 2),
    topology.verticalEdgeIndex(1, 2),
  };
  final board = core.SlitherlinkBoard(
    width: 2,
    height: 2,
    clues: const <int?>[2, 2, 2, 2],
    edges: List<int>.generate(
      topology.edgeCount,
      (int edge) => loopEdges.contains(edge)
          ? core.SlitherlinkBoard.edgeOn
          : core.SlitherlinkBoard.edgeUnknown,
    ),
  );
  return core.GeneratedPuzzle<core.SlitherlinkBoard>(
    state: board,
    meta: _metadataFor(
      size: '2x2',
      difficulty: 'easy',
      dailyPuzzleType: PuzzleType.slitherlinkLoop,
    ),
  );
}

core.PuzzleMetadata _metadataFor({
  required String size,
  required String difficulty,
  PuzzleType? dailyPuzzleType,
}) {
  final parts = size.split('x');
  final width = int.parse(parts.first);
  final height = parts.length > 1 ? int.parse(parts[1]) : width;
  final dailySeed = dailyPuzzleType == null
      ? null
      : DailySeedGenerator().generate(dailyPuzzleType.key);
  return core.PuzzleMetadata(
    engineVersion: 'test',
    rngId: 'test',
    size: core.SizeOpt(
      id: size,
      description: size,
      width: width,
      height: height,
    ),
    difficulty: core.DifficultyScore(value: 0.3, level: difficulty),
    seedStr: dailySeed?.seedStr ?? 'test:$size:$difficulty',
    seed64: dailySeed?.seed64 ?? (size.hashCode ^ difficulty.hashCode),
  );
}

class _TestNonogramEngine
    implements core.PuzzleEngine<core.NonogramBoard, core.NonogramMove> {
  const _TestNonogramEngine(this.puzzle);

  final core.GeneratedPuzzle<core.NonogramBoard> puzzle;

  @override
  String get id => PuzzleType.nonogramMono.key;

  @override
  String get name => 'Test Nonogram Engine';

  @override
  String get version => '1.0.0';

  @override
  core.PuzzleCapabilities get capabilities =>
      const core.PuzzleCapabilities(supportsHints: false);

  @override
  core.GeneratedPuzzle<core.NonogramBoard> generate({
    required String seedStr,
    required int seed64,
    required core.SizeOpt size,
    required core.DifficultyScore difficulty,
  }) {
    return puzzle;
  }

  @override
  bool isSolved(core.NonogramBoard state) {
    for (int row = 0; row < state.height; row++) {
      if (!_cluesEqual(
        _deriveNonogramClues(state.rowValues(row)),
        state.rowClues[row],
      )) {
        return false;
      }
    }
    for (int col = 0; col < state.width; col++) {
      if (!_cluesEqual(
        _deriveNonogramClues(state.columnValues(col)),
        state.columnClues[col],
      )) {
        return false;
      }
    }
    return true;
  }

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
    if (move.value != null && move.value != 0 && move.value != 1) {
      return core.MoveResult.failure('value_out_of_range');
    }

    final cells = List<int?>.from(currentState.cells);
    cells[currentState.indexOf(move.row, move.col)] = move.value;
    return core.MoveResult.success(currentState.copyWith(cells: cells));
  }
}

class _TestSlitherlinkEngine
    implements core.PuzzleEngine<core.SlitherlinkBoard, core.SlitherlinkMove> {
  const _TestSlitherlinkEngine(this.puzzle);

  final core.GeneratedPuzzle<core.SlitherlinkBoard> puzzle;
  static const core.SlitherlinkValidator _validator =
      core.SlitherlinkValidator();

  @override
  String get id => PuzzleType.slitherlinkLoop.key;

  @override
  String get name => 'Test Slitherlink Engine';

  @override
  String get version => '1.0.0';

  @override
  core.PuzzleCapabilities get capabilities =>
      const core.PuzzleCapabilities(supportsHints: false);

  @override
  core.GeneratedPuzzle<core.SlitherlinkBoard> generate({
    required String seedStr,
    required int seed64,
    required core.SizeOpt size,
    required core.DifficultyScore difficulty,
  }) {
    return puzzle;
  }

  @override
  bool isSolved(core.SlitherlinkBoard state) => _validator.isSolved(state);

  @override
  core.PuzzleHint? requestHint({
    required core.SlitherlinkBoard currentState,
    core.PuzzleHintRequest? request,
  }) {
    return null;
  }

  @override
  core.MoveResult<core.SlitherlinkBoard> validateMove({
    required core.SlitherlinkBoard currentState,
    required core.SlitherlinkMove move,
  }) {
    final topology = currentState.topology;
    final int index;
    if (move.horizontal) {
      if (move.row < 0 || move.row > currentState.height) {
        return core.MoveResult.failure('row_out_of_range');
      }
      if (move.col < 0 || move.col >= currentState.width) {
        return core.MoveResult.failure('col_out_of_range');
      }
      index = topology.horizontalEdgeIndex(move.row, move.col);
    } else {
      if (move.row < 0 || move.row >= currentState.height) {
        return core.MoveResult.failure('row_out_of_range');
      }
      if (move.col < 0 || move.col > currentState.width) {
        return core.MoveResult.failure('col_out_of_range');
      }
      index = topology.verticalEdgeIndex(move.row, move.col);
    }
    if (move.value != core.SlitherlinkBoard.edgeUnknown &&
        move.value != core.SlitherlinkBoard.edgeOff &&
        move.value != core.SlitherlinkBoard.edgeOn) {
      return core.MoveResult.failure('value_out_of_range');
    }

    final edges = List<int>.from(currentState.edges);
    edges[index] = move.value;
    return core.MoveResult.success(currentState.copyWith(edges: edges));
  }
}

List<int> _deriveNonogramClues(List<int?> values) {
  final clues = <int>[];
  int runLength = 0;
  for (final value in values) {
    if (value == 1) {
      runLength++;
    } else if (runLength > 0) {
      clues.add(runLength);
      runLength = 0;
    }
  }
  if (runLength > 0) {
    clues.add(runLength);
  }
  return clues;
}

bool _cluesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
