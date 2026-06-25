import 'package:app/app_router.dart';
import 'package:app/features/home/home_screen.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/navigation/app_routes.dart';
import 'package:app/shared/providers/puzzle_local_store_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_puzzle_data.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    core.EngineRegistry().clear();
    core.EngineRegistry().register(TestSudokuEngine());
  });

  tearDown(() {
    core.EngineRegistry().clear();
  });

  ActivePuzzleRun buildRun() {
    final puzzle = buildSudokuPuzzle();
    final now = DateTime.utc(2026, 6, 19, 12);
    return ActivePuzzleRun(
      puzzleType: PuzzleType.sudokuClassic,
      mode: PuzzleMode.random,
      difficulty: 'Medium',
      size: puzzle.meta.size.id,
      seed: puzzle.meta.seedStr,
      generatedPuzzleJson: puzzle.toJson(),
      createdAtUtc: now,
      updatedAtUtc: now,
      elapsedMs: const Duration(minutes: 3, seconds: 10).inMilliseconds,
      moveCount: 8,
      hintsUsed: 0,
      isSolved: false,
      dailyDateKeyUtc: null,
    );
  }

  List<Object> buildOverrides({
    ActivePuzzleRun? latestRun,
    PuzzleType? nextDailyType = PuzzleType.sudokuClassic,
    List<PuzzleType> favourites = const [],
  }) {
    final DateTime nowUtc = DateTime.utc(2026, 6, 23, 12);
    final String todayKey = DailyUtcDate.todayKey(now: nowUtc);

    return [
      dailyNowProvider.overrideWith((ref) => nowUtc),
      dailyStreakStatusProvider.overrideWith(
        (ref) async => const DailyStreakStatus(
          currentStreak: 14,
          bestStreak: 14,
          lastCompletedDateKeyUtc: '2026-06-23',
        ),
      ),
      homeStatsProvider.overrideWith(
        (ref) async => const HomeStatsSnapshot(
          totalSolved: 12,
          todayCompleted: 2,
          completedThisWeek: 5,
        ),
      ),
      latestActiveRunProvider.overrideWith((ref) async => latestRun),
      nextUncompletedDailyPuzzleTypeProvider(
        todayKey,
      ).overrideWith((ref) async => nextDailyType),
      favouritePuzzleTypesProvider.overrideWith((ref) async => favourites),
    ];
  }

  Widget buildSubject({
    ActivePuzzleRun? latestRun,
    PuzzleType? nextDailyType = PuzzleType.sudokuClassic,
    List<PuzzleType> favourites = const [],
  }) {
    return ProviderScope(
      overrides: buildOverrides(
        latestRun: latestRun,
        nextDailyType: nextDailyType,
        favourites: favourites,
      ).cast(),
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    );
  }

  Future<GoRouter> pumpHomeRouter(
    WidgetTester tester, {
    ActivePuzzleRun? latestRun,
    PuzzleType? nextDailyType = PuzzleType.sudokuClassic,
    List<PuzzleType> favourites = const [],
  }) async {
    final GoRouter router = createAppRouter(initialLocation: AppRoutes.home);
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(
          latestRun: latestRun,
          nextDailyType: nextDailyType,
          favourites: favourites,
        ).cast(),
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

  testWidgets('renders the branded home dashboard content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byIcon(Icons.extension_rounded), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.text('Today\'s Challenge'), findsOneWidget);
    expect(find.textContaining('Resets in '), findsOneWidget);
    expect(find.text('Quick Play'), findsOneWidget);
    expect(find.text('Random'), findsOneWidget);
    expect(find.text('Favourite Puzzle'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Your Stats'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Total Solved'), findsOneWidget);
    expect(find.text('Today Completed'), findsOneWidget);
    expect(find.text('Completed This Week'), findsOneWidget);
  });

  testWidgets('does not render deprecated home copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Offline ready'), findsNothing);
    expect(find.text('Sync pending'), findsNothing);
    expect(find.text('Browse All'), findsNothing);
    expect(find.text('Hints Used'), findsNothing);
  });

  testWidgets('hides continue card when there is no active run', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Continue'), findsNothing);
    expect(find.text('Resume'), findsNothing);
  });

  testWidgets('shows continue card when an active run exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject(latestRun: buildRun()));
    await tester.pump();

    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Random Play'), findsOneWidget);
  });

  testWidgets('favourite quick play guides empty state to puzzle library', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpHomeRouter(tester);
    await tester.ensureVisible(find.text('Favourite Puzzle'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Favourite Puzzle'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.puzzles);
    expect(
      find.text('Pick a favourite in Puzzle Library to launch it fast.'),
      findsOneWidget,
    );
  });

  testWidgets('completed daily CTA routes to daily hub instead of play', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpHomeRouter(tester, nextDailyType: null);

    await tester.tap(find.text('View Daily'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.daily);
    expect(find.text('Daily Challenges'), findsWidgets);
  });
}
