import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/daily/daily_seed_generator.dart';
import 'package:app/features/play/play_screen.dart';
import 'package:app/features/daily/daily_providers.dart';
import 'package:app/shared/analytics/analytics_events.dart';
import 'package:app/shared/analytics/analytics_providers.dart';
import 'package:app/shared/providers/game_state_provider.dart';
import 'package:app/shared/services/puzzle_local_store.dart';
import 'package:app/shared/services/puzzle_progress_service.dart';
import 'package:app/shared/widgets/nonogram_renderer.dart';
import 'package:app/shared/widgets/killer_queens_renderer.dart';
import 'package:app/shared/widgets/mathdoku_renderer.dart';
import 'package:app/shared/widgets/slitherlink_renderer.dart';
import 'package:app/shared/widgets/sudoku_renderer.dart';
import 'package:app/shared/widgets/takuzu_renderer.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import 'package:app/shared/models/models.dart';

import '../helpers/test_puzzle_data.dart';
import '../shared/analytics/fake_analytics_service.dart';

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
    final analytics = FakeAnalyticsService();
    core.EngineRegistry().register(engine);

    final solved = buildSudokuPuzzle(solved: true);
    final puzzleBoard = solved.state.setCell(0, 0, 0);
    final puzzle = core.GeneratedPuzzle<core.SudokuBoard>(
      state: puzzleBoard,
      meta: solved.meta,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [analyticsServiceProvider.overrideWithValue(analytics)],
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
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
    expect(
      analytics.events.map((event) => event.name),
      containsAll(<String>[
        AnalyticsEvents.puzzleStarted,
        AnalyticsEvents.puzzleCompleted,
      ]),
    );
    expect(
      analytics
          .lastEventNamed(AnalyticsEvents.puzzleCompleted)
          ?.parameters
          .keys,
      isNot(
        contains(
          anyOf('board', 'solution', 'puzzle_json', 'player_state', 'notes'),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayScreen)),
    );
    expect(container.read(gameStateProvider)?.isSolved, isTrue);
  });

  for (final difficulty in <String>['medium', 'hard']) {
    testWidgets('random $difficulty puzzle keeps generated difficulty', (
      tester,
    ) async {
      final engine = TestSudokuEngine();
      core.EngineRegistry().register(engine);

      final solved = buildSudokuPuzzle(solved: true, difficulty: difficulty);
      final puzzle = core.GeneratedPuzzle<core.SudokuBoard>(
        state: solved.state.setCell(0, 0, 0),
        meta: solved.meta,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayScreen(
              puzzleType: PuzzleType.sudokuClassic,
              mode: PuzzleMode.random,
              puzzleInstance: puzzle,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text(_titleCase(difficulty)), findsOneWidget);

      tester
          .widget<SudokuRendererWidget>(find.byType(SudokuRendererWidget))
          .onMove!(const core.SudokuMove(row: 0, col: 0, digit: 5));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesPuzzleLocalStore(prefs);
      final records = await store.completionRecords();
      expect(records.single.difficulty, difficulty);
      expect(
        await store.bestTime(PuzzleType.sudokuClassic, difficulty),
        isNotNull,
      );
      expect(find.textContaining(_titleCase(difficulty)), findsWidgets);
    });
  }

  testWidgets(
    'route difficulty label does not override generated puzzle difficulty',
    (tester) async {
      final engine = TestSudokuEngine();
      core.EngineRegistry().register(engine);

      final solved = buildSudokuPuzzle(solved: true, difficulty: 'hard');
      final puzzle = core.GeneratedPuzzle<core.SudokuBoard>(
        state: solved.state.setCell(0, 0, 0),
        meta: solved.meta,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
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

      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Easy'), findsNothing);
    },
  );

  testWidgets(
    'completed daily opens read-only solved view without regenerating',
    (tester) async {
      core.EngineRegistry().register(TestSudokuEngine());
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesPuzzleLocalStore(prefs);
      final progress = PuzzleProgressService(prefs);
      final String todayKey = DailyUtcDate.todayKey();
      final solvedPuzzle = buildSudokuPuzzle(solved: true);

      await store.recordCompletion(
        puzzleType: PuzzleType.sudokuClassic,
        difficulty: solvedPuzzle.meta.difficulty.level,
        completionTime: const Duration(minutes: 1, seconds: 17),
        mode: PuzzleMode.daily,
        size: solvedPuzzle.meta.size.id,
        seed: solvedPuzzle.meta.seedStr,
        moveCount: 9,
        hintsUsed: 1,
        dailyDateKeyUtc: todayKey,
      );
      await progress.saveRunForPuzzle(
        puzzleType: PuzzleType.sudokuClassic,
        mode: PuzzleMode.daily,
        puzzle: solvedPuzzle,
        elapsed: const Duration(minutes: 1, seconds: 17),
        moveCount: 9,
        hintsUsed: 1,
        isSolved: true,
        dailyDateKeyUtc: todayKey,
      );

      var generatedDaily = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyPuzzleProvider.overrideWith((ref, puzzleTypeKey) async {
              generatedDaily = true;
              return buildSudokuPuzzle();
            }),
          ],
          child: const MaterialApp(
            home: PlayScreen(
              puzzleType: PuzzleType.sudokuClassic,
              mode: PuzzleMode.daily,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(generatedDaily, isFalse);
      expect(find.byType(SudokuRendererWidget), findsOneWidget);
      expect(find.text('Solved'), findsOneWidget);
      expect(find.text('01:17'), findsOneWidget);

      final restartButton = tester.widget<InkWell>(
        find
            .ancestor(of: find.text('Restart'), matching: find.byType(InkWell))
            .first,
      );
      expect(restartButton.onTap, isNull);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('01:17'), findsOneWidget);
      expect((await store.completionRecords()), hasLength(1));
    },
  );

  testWidgets(
    'daily solved in the same screen disables restart and keeps solved run',
    (tester) async {
      core.EngineRegistry().register(TestSudokuEngine());

      final solved = buildSudokuPuzzle(solved: true);
      final puzzle = core.GeneratedPuzzle<core.SudokuBoard>(
        state: solved.state.setCell(0, 0, 0),
        meta: solved.meta,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: PlayScreen(
              puzzleType: PuzzleType.sudokuClassic,
              mode: PuzzleMode.daily,
              puzzleInstance: puzzle,
              difficulty: 'Easy',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .widget<SudokuRendererWidget>(find.byType(SudokuRendererWidget))
          .onMove!(const core.SudokuMove(row: 0, col: 0, digit: 5));
      await tester.pumpAndSettle();

      expect(find.text('Solved'), findsOneWidget);
      expect(find.text('Restart puzzle?'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      final restartButton = tester.widget<InkWell>(
        find
            .ancestor(of: find.text('Restart'), matching: find.byType(InkWell))
            .first,
      );
      expect(restartButton.onTap, isNull);

      await tester.tap(find.text('Restart'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Restart puzzle?'), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesPuzzleLocalStore(prefs);
      final records = await store.completionRecords();
      expect(records, hasLength(1));

      final run = await PuzzleProgressService(prefs).loadActiveRunFor(
        type: PuzzleType.sudokuClassic,
        mode: PuzzleMode.daily,
        dailyDateKeyUtc: DailyUtcDate.todayKey(),
      );
      expect(run?.isSolved, isTrue);
      expect(
        run == null ? null : PuzzleProgressService(prefs).loadPuzzleForRun(run),
        isNotNull,
      );
    },
  );

  testWidgets('completed Nonogram daily reopens solved board view', (
    tester,
  ) async {
    final solvedPuzzle = buildNonogramPuzzle();
    core.EngineRegistry().register(_TestNonogramEngine(solvedPuzzle));
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesPuzzleLocalStore(prefs);
    final progress = PuzzleProgressService(prefs);
    final String todayKey = DailyUtcDate.todayKey();

    await store.recordCompletion(
      puzzleType: PuzzleType.nonogramMono,
      difficulty: solvedPuzzle.meta.difficulty.level,
      completionTime: const Duration(seconds: 42),
      mode: PuzzleMode.daily,
      size: solvedPuzzle.meta.size.id,
      seed: solvedPuzzle.meta.seedStr,
      moveCount: 3,
      hintsUsed: 0,
      dailyDateKeyUtc: todayKey,
    );
    await progress.saveRunForPuzzle(
      puzzleType: PuzzleType.nonogramMono,
      mode: PuzzleMode.daily,
      puzzle: solvedPuzzle,
      elapsed: const Duration(seconds: 42),
      moveCount: 3,
      hintsUsed: 0,
      dailyDateKeyUtc: todayKey,
    );

    var generatedDaily = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyPuzzleProvider.overrideWith((ref, puzzleTypeKey) async {
            generatedDaily = true;
            return buildNonogramPuzzle();
          }),
        ],
        child: const MaterialApp(
          home: PlayScreen(
            puzzleType: PuzzleType.nonogramMono,
            mode: PuzzleMode.daily,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(generatedDaily, isFalse);
    expect(find.byType(NonogramRendererWidget), findsOneWidget);
    expect(find.textContaining('complete for today'), findsNothing);
    expect(find.text('Solved'), findsOneWidget);
  });

  testWidgets(
    'unfinished daily resumes persisted elapsed time before generating',
    (tester) async {
      core.EngineRegistry().register(TestSudokuEngine());
      final prefs = await SharedPreferences.getInstance();
      final progress = PuzzleProgressService(prefs);
      final String todayKey = DailyUtcDate.todayKey();
      final puzzle = buildSudokuPuzzle();

      await progress.saveRunForPuzzle(
        puzzleType: PuzzleType.sudokuClassic,
        mode: PuzzleMode.daily,
        puzzle: puzzle,
        elapsed: const Duration(minutes: 3, seconds: 12),
        moveCount: 4,
        hintsUsed: 0,
        dailyDateKeyUtc: todayKey,
        notes: const <int, Set<int>>{
          0: <int>{2, 3},
        },
      );

      var generatedDaily = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyPuzzleProvider.overrideWith((ref, puzzleTypeKey) async {
              generatedDaily = true;
              return buildSudokuPuzzle();
            }),
          ],
          child: const MaterialApp(
            home: PlayScreen(
              puzzleType: PuzzleType.sudokuClassic,
              mode: PuzzleMode.daily,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(generatedDaily, isFalse);
      expect(find.text('03:12'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlayScreen)),
      );
      expect(
        container.read(gameStateProvider)?.notes[0],
        containsAll(<int>{2, 3}),
      );
    },
  );

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
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
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
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
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

    expect(find.byTooltip('How to Play'), findsOneWidget);
  });

  testWidgets('Clear removes Sudoku notes-only and value-plus-notes cells', (
    tester,
  ) async {
    core.EngineRegistry().register(TestSudokuEngine());
    final puzzle = buildSudokuPuzzle();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PlayScreen(
            puzzleType: PuzzleType.sudokuClassic,
            mode: PuzzleMode.random,
            puzzleInstance: puzzle,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayScreen)),
    );
    final notifier = container.read(gameStateProvider.notifier);
    notifier.recordNoteAction(0, 5, true);
    tester
        .widget<SudokuRendererWidget>(find.byType(SudokuRendererWidget))
        .onCellSelected!(Offset.zero);
    await tester.ensureVisible(find.text('Clear'));
    tester
        .widget<InkWell>(
          find
              .ancestor(of: find.text('Clear'), matching: find.byType(InkWell))
              .first,
        )
        .onTap!();
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(gameStateProvider)!.notes.containsKey(0), isFalse);

    await notifier.makeMove(const core.SudokuMove(row: 0, col: 0, digit: 5));
    notifier.recordNoteAction(0, 6, true);
    await tester.pump();
    tester
        .widget<InkWell>(
          find
              .ancestor(of: find.text('Clear'), matching: find.byType(InkWell))
              .first,
        )
        .onTap!();
    await tester.pump(const Duration(milliseconds: 100));

    final state = container.read(gameStateProvider)!;
    final board = state.puzzle.state as core.SudokuBoard;
    expect(board.cellAt(0, 0), 0);
    expect(state.notes.containsKey(0), isFalse);

    final prefs = await SharedPreferences.getInstance();
    final run = await PuzzleProgressService(
      prefs,
    ).loadActiveRunFor(type: PuzzleType.sudokuClassic, mode: PuzzleMode.random);
    expect(run?.notes.containsKey(0), isFalse);
  });

  testWidgets('Clear removes MathDoku notes-only and value-plus-notes cells', (
    tester,
  ) async {
    core.EngineRegistry().register(const _TestMathdokuEngine());
    final puzzle = buildMathdokuPuzzle();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PlayScreen(
            puzzleType: PuzzleType.mathdokuClassic,
            mode: PuzzleMode.random,
            puzzleInstance: puzzle,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayScreen)),
    );
    final notifier = container.read(gameStateProvider.notifier);

    await notifier.makeMove(const core.MathdokuMove(row: 0, col: 0, value: 0));
    notifier.recordNoteAction(0, 3, true);
    tester
        .widget<MathdokuRendererWidget>(find.byType(MathdokuRendererWidget))
        .onCellSelected!(Offset.zero);
    await tester.ensureVisible(find.text('Clear'));
    tester
        .widget<InkWell>(
          find
              .ancestor(of: find.text('Clear'), matching: find.byType(InkWell))
              .first,
        )
        .onTap!();
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(gameStateProvider)!.notes.containsKey(0), isFalse);

    await notifier.makeMove(const core.MathdokuMove(row: 0, col: 0, value: 1));
    notifier.recordNoteAction(0, 2, true);
    await tester.pump();
    tester
        .widget<InkWell>(
          find
              .ancestor(of: find.text('Clear'), matching: find.byType(InkWell))
              .first,
        )
        .onTap!();
    await tester.pump(const Duration(milliseconds: 100));

    final state = container.read(gameStateProvider)!;
    final board = state.puzzle.state as core.MathdokuBoard;
    expect(board.cellAt(0, 0), 0);
    expect(state.notes.containsKey(0), isFalse);
  });

  for (final entry
      in <
        (
          PuzzleType,
          core.PuzzleEngine<dynamic, dynamic>,
          core.GeneratedPuzzle<dynamic>,
          Type,
        )
      >[
        (
          PuzzleType.takuzuBinary,
          core.TakuzuEngine(),
          _buildTakuzuHintPuzzle(),
          TakuzuRendererWidget,
        ),
        (
          PuzzleType.slitherlinkLoop,
          core.SlitherlinkEngine(),
          _buildAlmostSolvedSlitherlinkPuzzle(),
          SlitherlinkRendererWidget,
        ),
        (
          PuzzleType.killerQueens,
          core.KillerQueensEngine(),
          _buildKillerQueensHintPuzzle(),
          KillerQueensRendererWidget,
        ),
      ]) {
    testWidgets('${entry.$1.displayName} hint applies and increments count', (
      tester,
    ) async {
      core.EngineRegistry().register(entry.$2);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayScreen(
              puzzleType: entry.$1,
              mode: PuzzleMode.random,
              puzzleInstance: entry.$3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(entry.$4), findsOneWidget);
      final InkWell hintButton = tester.widget<InkWell>(
        find
            .ancestor(of: find.text('Hint'), matching: find.byType(InkWell))
            .first,
      );
      expect(hintButton.onTap, isNotNull);

      await tester.tap(find.text('Hint'));
      await tester.pump(const Duration(milliseconds: 2300));

      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesPuzzleLocalStore(prefs);
      final records = await store.completionRecords();
      if (records.isNotEmpty) {
        expect(records.last.hintsUsed, 1);
      } else {
        final run = await PuzzleProgressService(
          prefs,
        ).loadActiveRunFor(type: entry.$1, mode: PuzzleMode.random);
        expect(run?.hintsUsed, 1);
      }
    });
  }

  testWidgets('supported Sudoku hint applies and increments hints used', (
    tester,
  ) async {
    final analytics = FakeAnalyticsService();
    core.EngineRegistry().register(HintingSudokuEngine());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [analyticsServiceProvider.overrideWithValue(analytics)],
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

    await tester.tap(find.text('Hint'));
    await tester.pump(const Duration(milliseconds: 200));

    final prefs = await SharedPreferences.getInstance();
    final run = await PuzzleProgressService(
      prefs,
    ).loadActiveRunFor(type: PuzzleType.sudokuClassic, mode: PuzzleMode.random);
    expect(run?.hintsUsed, 1);
    expect(
      analytics.lastEventNamed(AnalyticsEvents.hintUsed)?.parameters,
      <String, Object?>{
        'puzzle_type': PuzzleType.sudokuClassic.key,
        'mode': PuzzleMode.random.key,
        'difficulty': 'easy',
        'size': '9x9',
        'hints_used': 1,
      },
    );
  });


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

core.GeneratedPuzzle<core.TakuzuBoard> _buildTakuzuHintPuzzle() {
  final puzzle = buildTakuzuPuzzle();
  final board = puzzle.state.setCell(1, 1, core.TakuzuBoard.emptyValue);
  return core.GeneratedPuzzle<core.TakuzuBoard>(
    state: board,
    meta: puzzle.meta,
  );
}

core.GeneratedPuzzle<core.KillerQueensBoard> _buildKillerQueensHintPuzzle() {
  final puzzle = buildKillerQueensPuzzle();
  final cells = List<int>.from(puzzle.state.cells);
  cells[9] = 0;
  return core.GeneratedPuzzle<core.KillerQueensBoard>(
    state: puzzle.state.copyWith(cells: cells),
    meta: puzzle.meta,
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

String _titleCase(String value) {
  return value[0].toUpperCase() + value.substring(1);
}

class HintingSudokuEngine extends TestSudokuEngine {
  @override
  core.PuzzleCapabilities get capabilities =>
      const core.PuzzleCapabilities(supportsHints: true);

  @override
  core.PuzzleHint? requestHint({
    required core.SudokuBoard currentState,
    core.PuzzleHintRequest? request,
  }) {
    return core.PuzzleHint(
      cells: <core.PuzzleHintCell>[
        core.PuzzleHintCell(
          row: 0,
          column: 0,
          metadata: <String, Object?>{'digit': 5},
        ),
      ],
      metadata: const <String, Object?>{'kind': 'fill_single_cell'},
    );
  }
}

class _TestMathdokuEngine
    implements core.PuzzleEngine<core.MathdokuBoard, core.MathdokuMove> {
  const _TestMathdokuEngine();

  @override
  String get id => PuzzleType.mathdokuClassic.key;

  @override
  String get name => 'Test MathDoku';

  @override
  String get version => '1.0.0';

  @override
  core.PuzzleCapabilities get capabilities =>
      const core.PuzzleCapabilities(supportsHints: true);

  @override
  core.GeneratedPuzzle<core.MathdokuBoard> generate({
    required String seedStr,
    required int seed64,
    required core.SizeOpt size,
    required core.DifficultyScore difficulty,
  }) {
    return buildMathdokuPuzzle();
  }

  @override
  bool isSolved(core.MathdokuBoard state) => false;

  @override
  core.PuzzleHint? requestHint({
    required core.MathdokuBoard currentState,
    core.PuzzleHintRequest? request,
  }) {
    return null;
  }

  @override
  core.MoveResult<core.MathdokuBoard> validateMove({
    required core.MathdokuBoard currentState,
    required core.MathdokuMove move,
  }) {
    return core.MoveResult.success(
      currentState.setCell(move.row, move.col, move.value),
    );
  }
}
