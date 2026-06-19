import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/select/select_screen.dart';
import 'package:app/shared/services/puzzle_preload_service.dart';
import 'package:app/shared/models/models.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import '../helpers/test_puzzle_data.dart';

class _FakePuzzlePreloadService extends PuzzlePreloadService {
  _FakePuzzlePreloadService(this._cache);

  final Map<String, core.GeneratedPuzzle<dynamic>> _cache;

  String _cacheKey(PuzzleType type, String difficulty) =>
      '${type.key.toLowerCase()}::${difficulty.toLowerCase()}';

  @override
  Future<void> preloadAll({
    Duration interItemYield = const Duration(milliseconds: 50),
  }) async {}

  @override
  core.GeneratedPuzzle<dynamic>? getCached(
    PuzzleType puzzleType,
    String difficulty,
  ) {
    return _cache[_cacheKey(puzzleType, difficulty)];
  }

  @override
  bool get hasPreloaded => _cache.isNotEmpty;
}

void main() {
  Widget wrapWithProviders(Widget child) {
    return ProviderScope(child: child);
  }

  MaterialApp routerApp(GoRouter router) {
    return MaterialApp.router(
      routeInformationProvider: router.routeInformationProvider,
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
    );
  }

  group('SelectScreen', () {
    setUp(() {
      core.EngineRegistry().clear();
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      core.EngineRegistry().clear();
    });

    testWidgets('should show loading state initially', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWithProviders(
          routerApp(
            GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const SelectScreen(),
                ),
              ],
            ),
          ),
        ),
      );

      // Should show loading shimmer
      expect(find.byType(SelectScreen), findsOneWidget);

      // Wait for loading to complete
      await tester.pumpAndSettle();
    });

    testWidgets('should render registry-backed puzzle list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWithProviders(
          routerApp(
            GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const SelectScreen(),
                ),
              ],
            ),
          ),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      expect(find.byType(SelectScreen), findsOneWidget);
      expect(find.text('Classic Sudoku'), findsOneWidget);
    });

    testWidgets('should show puzzles when available', (
      WidgetTester tester,
    ) async {
      // Register some engines
      core.EngineRegistry().register(
        core.StubPuzzleEngine(engineId: 'sudoku_classic'),
      );
      core.EngineRegistry().register(
        core.StubPuzzleEngine(engineId: 'nonogram_mono'),
      );

      await tester.pumpWidget(
        wrapWithProviders(
          routerApp(
            GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const SelectScreen(),
                ),
              ],
            ),
          ),
        ),
      );

      // Wait for loading to complete
      await tester.pumpAndSettle();

      expect(find.text('Logic'), findsWidgets);
      expect(find.text('Classic Sudoku'), findsOneWidget);
      expect(find.text('Monochrome Nonogram'), findsOneWidget);
    });

    testWidgets('should navigate to play screen when puzzle is selected', (
      WidgetTester tester,
    ) async {
      // Register an engine
      core.EngineRegistry().register(
        core.StubPuzzleEngine(engineId: 'sudoku_classic'),
      );

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const SelectScreen()),
          GoRoute(
            path: '/play/:puzzleType/:mode',
            builder: (context, state) =>
                const Scaffold(body: Text('Play Screen')),
          ),
        ],
      );

      await tester.pumpWidget(wrapWithProviders(routerApp(router)));

      // Wait for loading to complete
      await tester.pumpAndSettle();

      final startDailyButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Start Daily').first,
      );
      startDailyButton.onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('Play Screen'), findsOneWidget);
    });

    testWidgets('shows new game action', (WidgetTester tester) async {
      final engine = TestSudokuEngine();
      core.EngineRegistry().register(engine);
      final cached = buildSudokuPuzzle();
      final preloadService = _FakePuzzlePreloadService({
        '${PuzzleType.sudokuClassic.key}::easy': cached,
      });

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const SelectScreen()),
          GoRoute(
            path: '/play/:puzzleType/:mode',
            builder: (context, state) {
              return const Scaffold(body: Text('Play Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [puzzlePreloadProvider.overrideWithValue(preloadService)],
          child: MaterialApp.router(
            routeInformationProvider: router.routeInformationProvider,
            routeInformationParser: router.routeInformationParser,
            routerDelegate: router.routerDelegate,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();

      expect(find.text('New Game'), findsWidgets);
    });
  });
}
