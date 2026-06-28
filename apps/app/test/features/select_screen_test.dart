import 'package:app/features/select/select_screen.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/providers/puzzle_local_store_providers.dart';
import 'package:app/shared/services/generation_isolate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_puzzle_data.dart';

class _ImmediatePuzzleGenerationWorker implements PuzzleGenerationWorker {
  _ImmediatePuzzleGenerationWorker(this._puzzle);

  final core.GeneratedPuzzle<dynamic> _puzzle;

  @override
  Future<core.GeneratedPuzzle<dynamic>> generate(
    PuzzleGenerationRequest request, {
    Duration? timeout,
  }) async {
    return _puzzle;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    core.EngineRegistry().clear();
    for (final puzzleType in PuzzleType.values) {
      core.EngineRegistry().register(
        core.StubPuzzleEngine(
          engineId: puzzleType.key,
          engineName: puzzleType.displayName,
        ),
      );
    }
  });

  tearDown(() {
    core.EngineRegistry().clear();
  });

  ActivePuzzleRun buildRun({PuzzleType puzzleType = PuzzleType.sudokuClassic}) {
    final puzzle = buildSudokuPuzzle();
    final now = DateTime.utc(2026, 6, 23, 12);
    return ActivePuzzleRun(
      puzzleType: puzzleType,
      mode: PuzzleMode.random,
      difficulty: 'Medium',
      size: puzzle.meta.size.id,
      seed: puzzle.meta.seedStr,
      generatedPuzzleJson: puzzle.toJson(),
      createdAtUtc: now,
      updatedAtUtc: now,
      elapsedMs: const Duration(minutes: 4).inMilliseconds,
      moveCount: 6,
      hintsUsed: 0,
      isSolved: false,
      dailyDateKeyUtc: null,
    );
  }

  Future<GoRouter> pumpSelectScreen(
    WidgetTester tester, {
    List<Object> overrides = const [],
  }) async {
    final GoRouter router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SelectScreen()),
        GoRoute(
          path: '/play/:puzzleType/:mode',
          builder: (context, state) =>
              const Scaffold(body: Text('Play Screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp.router(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('shows the library title and filters without search or word', (
    WidgetTester tester,
  ) async {
    await pumpSelectScreen(tester);

    expect(find.text('Puzzle Library'), findsOneWidget);
    expect(
      find.text(
        'Choose a puzzle type, then pick Daily Challenge or Random Play.',
      ),
      findsOneWidget,
    );
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Numbers'), findsWidgets);
    expect(find.text('Visual'), findsWidgets);
    expect(find.text('Favourites'), findsOneWidget);
    expect(find.text('Word'), findsNothing);
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets(
    'cards show puzzle copy, icon, read-only difficulty chips, and no stats',
    (WidgetTester tester) async {
      final GoRouter router = await pumpSelectScreen(tester);

      expect(find.text('Classic Sudoku'), findsOneWidget);
      expect(
        find.text(
          'Fill the grid so every row, column, and box contains each number once.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.grid_on), findsOneWidget);
      expect(find.text('Numbers'), findsWidgets);
      expect(find.text('Easy'), findsWidgets);
      expect(find.text('Medium'), findsWidgets);
      expect(find.text('Hard'), findsWidgets);
      expect(find.text('Expert'), findsWidgets);
      expect(find.text('Best Time'), findsNothing);
      expect(find.text('Solved Count'), findsNothing);
      expect(find.text('Rank'), findsNothing);
      expect(find.text('Playing Now'), findsNothing);

      await tester.tap(find.text('Easy').first);
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.text('Play Screen'), findsNothing);
    },
  );

  testWidgets('favourite star toggles without opening the picker', (
    WidgetTester tester,
  ) async {
    await pumpSelectScreen(tester);

    await tester.tap(find.byTooltip('Add favourite').first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.text('Choose mode'), findsNothing);
  });

  testWidgets('tapping a card opens the picker sheet without replacing route', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpSelectScreen(tester);

    await tester.tap(find.text('Classic Sudoku'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Mode'), findsOneWidget);
    expect(find.text('How to Play'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets(
    'shows in-progress badge and continue action only when an active run exists',
    (WidgetTester tester) async {
      await pumpSelectScreen(
        tester,
        overrides: [
          activeRunForPuzzleTypeProvider(
            PuzzleType.sudokuClassic,
          ).overrideWith((ref) async => buildRun()),
        ],
      );

      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    },
  );

  testWidgets('shows an empty favourites state when no favourites exist', (
    WidgetTester tester,
  ) async {
    await pumpSelectScreen(tester);

    await tester.tap(find.text('Favourites'));
    await tester.pumpAndSettle();

    expect(find.text('No favourite puzzles yet'), findsOneWidget);
    expect(
      find.text('Star a puzzle card to save that puzzle type here.'),
      findsOneWidget,
    );
  });

  testWidgets('numbers filter includes Sudoku and Mathdoku', (
    WidgetTester tester,
  ) async {
    await pumpSelectScreen(tester);

    await tester.tap(find.text('Numbers').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Classic Mathdoku'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Classic Sudoku', skipOffstage: false), findsOneWidget);
    expect(find.text('Classic Mathdoku', skipOffstage: false), findsOneWidget);
    expect(find.text('Monochrome Nonogram'), findsNothing);
    expect(find.text('Slitherlink Loop'), findsNothing);
    expect(find.text('Killer Queens'), findsNothing);
  });



  testWidgets('visual filter includes Nonogram Slitherlink and Killer Queens', (
    WidgetTester tester,
  ) async {
    await pumpSelectScreen(tester);

    await tester.tap(find.text('Visual').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Killer Queens'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Monochrome Nonogram'), findsOneWidget);
    expect(find.text('Slitherlink Loop'), findsOneWidget);
    expect(find.text('Killer Queens'), findsOneWidget);
    expect(find.text('Classic Sudoku'), findsNothing);
    expect(find.text('Classic Mathdoku'), findsNothing);
  });

  testWidgets('starting random play navigates to the random play route', (
    WidgetTester tester,
  ) async {
    await pumpSelectScreen(
      tester,
      overrides: [
        puzzleGenerationWorkerProvider.overrideWithValue(
          _ImmediatePuzzleGenerationWorker(buildSudokuPuzzle()),
        ),
      ],
    );

    await tester.tap(find.text('Classic Sudoku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Random Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Random Puzzle'));
    await tester.pumpAndSettle();

    expect(find.text('Play Screen'), findsOneWidget);
  });
}
