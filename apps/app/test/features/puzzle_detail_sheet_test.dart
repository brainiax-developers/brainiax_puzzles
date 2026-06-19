import 'package:app/features/select/puzzle_detail_sheet.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/providers/puzzle_local_store_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_puzzle_data.dart';

void main() {
  const PuzzleMetadata metadata = PuzzleMetadata(
    type: PuzzleType.sudokuClassic,
    displayName: 'Classic Sudoku',
    description:
        'Fill the grid so every row, column, and box contains each number once.',
    icon: Icons.grid_on,
    accentColors: [Color(0xFF2196F3), Color(0xFF1976D2)],
    supportedSizes: ['9x9'],
    supportedDifficulties: ['Easy', 'Medium', 'Hard', 'Expert'],
    supportsHints: true,
    category: PuzzleCategory.logic,
  );

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
      elapsedMs: const Duration(minutes: 4).inMilliseconds,
      moveCount: 6,
      hintsUsed: 0,
      isSolved: false,
      dailyDateKeyUtc: null,
    );
  }

  Widget buildSubject({
    bool isFavourite = false,
    bool dailyCompleted = false,
    ActivePuzzleRun? activeRun,
  }) {
    return ProviderScope(
      overrides: [
        isFavouritePuzzleTypeProvider(
          metadata.type,
        ).overrideWith((ref) async => isFavourite),
        activeRunForPuzzleTypeProvider(
          metadata.type,
        ).overrideWith((ref) async => activeRun),
        puzzleTodayCompletionProvider(
          metadata.type,
        ).overrideWith((ref) async => dailyCompleted),
        preferredDifficultyProvider(
          metadata.type,
        ).overrideWith((ref) async => 'Medium'),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: PuzzleDetailSheet(hostContext: context, metadata: metadata),
            );
          },
        ),
      ),
    );
  }

  testWidgets('shows the picker content for a daily-eligible puzzle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject(isFavourite: true));
    await tester.pump();

    expect(find.text('Classic Sudoku'), findsOneWidget);
    expect(find.byIcon(Icons.grid_on), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.text('Objective'), findsOneWidget);
    expect(find.text('How to Play'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.text('Random Play'), findsOneWidget);
    expect(find.text('Same puzzle for everyone'), findsOneWidget);
    expect(find.text('Unique to you'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('Expert'), findsOneWidget);
    expect(find.text('Offline'), findsNothing);
    expect(find.text('Daily Seed'), findsNothing);
    expect(find.text('Best Time'), findsNothing);
    expect(find.text('Grid Size'), findsNothing);
  });

  testWidgets('shows saved game card when an active run exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject(activeRun: buildRun()));
    await tester.pump();

    expect(find.text('Saved Game'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Random Play'), findsOneWidget);
  });

  testWidgets('changes the daily CTA when the puzzle is completed today', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject(dailyCompleted: true));
    await tester.pump();

    expect(find.text('Completed Today'), findsOneWidget);
    expect(find.text('View Daily'), findsOneWidget);
  });
}
