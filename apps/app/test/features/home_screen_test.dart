import 'package:app/features/home/home_screen.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/providers/puzzle_local_store_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_puzzle_data.dart';

void main() {
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

  Widget buildSubject({ActivePuzzleRun? latestRun}) {
    final String todayKey = DailyUtcDate.todayKey();
    return ProviderScope(
      overrides: [
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
        ).overrideWith((ref) async => PuzzleType.sudokuClassic),
        favouritePuzzleTypesProvider.overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    );
  }

  testWidgets('shows the home dashboard content', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Today\'s Challenge'), findsOneWidget);
    expect(find.text('Quick Play'), findsOneWidget);
    expect(find.text('Random'), findsOneWidget);
    expect(find.text('Favourite Puzzle'), findsOneWidget);
    expect(find.text('Total Solved'), findsOneWidget);
    expect(find.text('Today Completed'), findsOneWidget);
    expect(find.text('Completed This Week'), findsOneWidget);
    expect(find.text('Offline ready'), findsNothing);
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
}
