import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import 'package:app/features/select/select_screen.dart';
import 'package:app/features/play/play_screen.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/providers/puzzle_generation_controller.dart';
import 'package:app/shared/services/puzzle_preload_service.dart';
import 'package:app/shared/widgets/sudoku_renderer.dart';

import '../helpers/test_puzzle_data.dart';

class _FakePuzzleGenerationController extends PuzzleGenerationController {
  _FakePuzzleGenerationController(this._puzzle);

  final core.GeneratedPuzzle<dynamic> _puzzle;

  @override
  Future<core.GeneratedPuzzle<dynamic>?> build() async => null;

  @override
  Future<core.GeneratedPuzzle<dynamic>> generate({
    required PuzzleType puzzleType,
    required String difficulty,
    String? seed,
    String? size,
  }) async {
    state = AsyncValue.data(_puzzle);
    return _puzzle;
  }
}

class _EmptyPreloadService extends PuzzlePreloadService {
  @override
  Future<void> preloadAll({Duration interItemYield = const Duration(milliseconds: 50)}) async {}

  @override
  core.GeneratedPuzzle<dynamic>? getCached(PuzzleType puzzleType, String difficulty) => null;

  @override
  bool get hasPreloaded => false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    core.EngineRegistry().clear();
  });

  tearDown(() {
    core.EngineRegistry().clear();
  });

  testWidgets('full flow generates, solves, and records stats', (tester) async {
    final engine = TestSudokuEngine();
    core.EngineRegistry().register(engine);

    final solved = buildSudokuPuzzle(solved: true);
    final puzzleBoard = solved.state.setCell(0, 0, 0);
    final generatedPuzzle = core.GeneratedPuzzle<core.SudokuBoard>(
      state: puzzleBoard,
      meta: solved.meta,
    );

    dynamic receivedExtra;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SelectScreen()),
        GoRoute(
          path: '/play/:puzzleType/:mode',
          builder: (context, state) {
            receivedExtra = state.extra;
            return PlayScreen(
              puzzleType: PuzzleType.sudokuClassic,
              mode: PuzzleMode.random,
              puzzleInstance: state.extra,
              difficulty: 'easy',
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          puzzleGenerationControllerProvider.overrideWith(
            () => _FakePuzzleGenerationController(generatedPuzzle),
          ),
          puzzlePreloadProvider.overrideWithValue(_EmptyPreloadService()),
        ],
        child: MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    expect(find.text('Random Play'), findsWidgets);

    await tester.tap(find.text('Random Play').first);
    await tester.pump();

    expect(find.textContaining('Generating'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(receivedExtra, equals(generatedPuzzle));
    expect(find.byType(PlayScreen), findsOneWidget);

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
    expect(find.textContaining('Streak'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final key = 'puzzle_local_store.v1.best_time.${PuzzleType.sudokuClassic.key}.easy';
    expect(prefs.containsKey(key), isTrue);
  });
}
