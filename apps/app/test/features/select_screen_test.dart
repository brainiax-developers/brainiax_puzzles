import 'package:app/features/select/select_screen.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/navigation/app_routes.dart';
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
    core.EngineRegistry().register(TestSudokuEngine());
  });

  tearDown(() {
    core.EngineRegistry().clear();
  });

  Future<GoRouter> pumpSelectScreen(
    WidgetTester tester, {
    List<Object> overrides = const [],
  }) async {
    final GoRouter router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SelectScreen(),
        ),
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
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('shows the library filters without search or word filter', (
    WidgetTester tester,
  ) async {
    await pumpSelectScreen(tester);

    expect(find.text('Puzzle Library'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Numbers'), findsOneWidget);
    expect(find.text('Visual'), findsOneWidget);
    expect(find.text('Favourites'), findsOneWidget);
    expect(find.text('Word'), findsNothing);
    expect(find.byIcon(Icons.search), findsNothing);
  });

  testWidgets('cards show difficulty chips as labels only', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpSelectScreen(tester);

    expect(find.text('Classic Sudoku'), findsOneWidget);
    expect(find.text('Easy'), findsWidgets);
    expect(find.text('Medium'), findsWidgets);
    expect(find.text('Hard'), findsWidgets);
    expect(find.text('Expert'), findsWidgets);

    await tester.tap(find.text('Easy').first);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.text('Play Screen'), findsNothing);
  });

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

    expect(find.text('Choose mode'), findsOneWidget);
    expect(find.text('How to Play'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('starting random play navigates to the random play route', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpSelectScreen(
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

    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.play(PuzzleType.sudokuClassic.key, PuzzleMode.random.key),
    );
    expect(find.text('Play Screen'), findsOneWidget);
  });
}
