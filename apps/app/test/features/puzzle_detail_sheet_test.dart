import 'package:app/features/select/puzzle_detail_sheet.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/providers/puzzle_local_store_providers.dart';
import 'package:app/shared/services/puzzle_progress_service.dart';
import 'package:app/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  const PuzzleMetadata comingSoonMetadata = PuzzleMetadata(
    type: PuzzleType.kakuroClassic,
    displayName: 'Classic Kakuro',
    description:
        'Place digits so each clue group adds correctly without repeats.',
    icon: Icons.add_box,
    accentColors: [Color(0xFFFF9800), Color(0xFFF57C00)],
    supportedSizes: ['7x9'],
    supportedDifficulties: ['Easy'],
    supportsHints: true,
    category: PuzzleCategory.logic,
    isAvailable: false,
    availabilityBadgeLabel: 'Coming Soon',
    unavailableMessage: 'Kakuro is coming soon.',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ActivePuzzleRun buildRun({PuzzleMode mode = PuzzleMode.random}) {
    final puzzle = buildSudokuPuzzle();
    final now = DateTime.utc(2026, 6, 19, 12);
    return ActivePuzzleRun(
      puzzleType: PuzzleType.sudokuClassic,
      mode: mode,
      difficulty: 'Hard',
      size: puzzle.meta.size.id,
      seed: puzzle.meta.seedStr,
      generatedPuzzleJson: puzzle.toJson(),
      createdAtUtc: now,
      updatedAtUtc: now,
      elapsedMs: const Duration(minutes: 8, seconds: 12).inMilliseconds,
      moveCount: 6,
      hintsUsed: 0,
      isSolved: false,
      dailyDateKeyUtc: mode == PuzzleMode.daily
          ? DailyUtcDate.todayKey()
          : null,
    );
  }

  Widget buildSubject({
    PuzzleMetadata sheetMetadata = metadata,
    bool? isFavourite,
    bool dailyCompleted = false,
    ActivePuzzleRun? activeRun,
    String preferredDifficulty = 'Medium',
  }) {
    final overrides = [
      if (isFavourite != null)
        isFavouritePuzzleTypeProvider(
          sheetMetadata.type,
        ).overrideWith((ref) async => isFavourite),
      activeRunForPuzzleTypeProvider(
        sheetMetadata.type,
      ).overrideWith((ref) async => activeRun),
      puzzleTodayCompletionProvider(
        sheetMetadata.type,
      ).overrideWith((ref) async => dailyCompleted),
      preferredDifficultyProvider(
        sheetMetadata.type,
      ).overrideWith((ref) async => preferredDifficulty),
    ];

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light().copyWith(splashFactory: NoSplash.splashFactory),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: PuzzleDetailSheet(
                hostContext: context,
                metadata: sheetMetadata,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildRouterSubject({
    bool dailyCompleted = false,
    ActivePuzzleRun? activeRun,
    String preferredDifficulty = 'Medium',
  }) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: PuzzleDetailSheet(hostContext: context, metadata: metadata),
          ),
        ),
        GoRoute(
          path: '/daily',
          builder: (context, state) =>
              const Scaffold(body: Text('daily route')),
        ),
        GoRoute(
          path: '/play/:type/:mode',
          builder: (context, state) => Scaffold(
            body: Text(
              'play ${state.pathParameters['type']} ${state.pathParameters['mode']}',
            ),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        activeRunForPuzzleTypeProvider(
          metadata.type,
        ).overrideWith((ref) async => activeRun),
        puzzleTodayCompletionProvider(
          metadata.type,
        ).overrideWith((ref) async => dailyCompleted),
        preferredDifficultyProvider(
          metadata.type,
        ).overrideWith((ref) async => preferredDifficulty),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light().copyWith(splashFactory: NoSplash.splashFactory),
        routerConfig: router,
      ),
    );
  }

  Future<void> seedSavedRun(ActivePuzzleRun run) async {
    final prefs = await SharedPreferences.getInstance();
    await PuzzleProgressService(prefs).saveActiveRun(run);
  }

  testWidgets('renders puzzle name, icon, objective, and mode cards', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject(isFavourite: false));
    await tester.pump();

    expect(find.text('Classic Sudoku'), findsOneWidget);
    expect(find.byIcon(Icons.grid_on), findsOneWidget);
    expect(find.byIcon(Icons.star_outline), findsOneWidget);
    expect(find.text('Objective'), findsOneWidget);
    expect(find.text('How to Play'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.text('Random Play'), findsOneWidget);
    expect(find.text('Same puzzle for everyone'), findsOneWidget);
    expect(find.text('Unique to you'), findsOneWidget);
    expect(find.textContaining('Resets in '), findsOneWidget);
    expect(find.text('Offline'), findsNothing);
    expect(find.text('Daily Seed'), findsNothing);
    expect(find.text('Best Time'), findsNothing);
    expect(find.text('Grid Size'), findsNothing);
  });

  testWidgets('favourite star toggles without starting a puzzle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject(activeRun: null));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_outline));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('favourites.v1.puzzle_types'),
      contains(PuzzleType.sudokuClassic.key),
    );
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.text('Start Daily Challenge'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('How to Play stays safe when tutorial is a placeholder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('How to Play'));
    await tester.pump();

    expect(find.text('Tutorial coming soon.'), findsOneWidget);
  });

  testWidgets('random difficulty chips render and persist user selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject(preferredDifficulty: 'Medium'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Random Play'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hard'));
    await tester.tap(find.text('Hard'));
    await tester.pump();
    await tester.pump();

    final ChoiceChip hardChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Hard'),
    );
    final prefs = await SharedPreferences.getInstance();

    expect(hardChip.selected, isTrue);
    expect(
      prefs.getString('difficulty_pref_${PuzzleType.sudokuClassic.key}'),
      'Hard',
    );
  });

  testWidgets('daily mode keeps difficulty read only', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Daily Difficulty'), findsOneWidget);
    expect(find.text('Daily Set'), findsOneWidget);
    expect(find.text('Easy'), findsNothing);
    expect(find.text('Medium'), findsNothing);
    expect(find.text('Hard'), findsNothing);
    expect(find.text('Expert'), findsNothing);
  });

  testWidgets('shows saved game card only when an active run exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject(activeRun: buildRun()));
    await tester.pumpAndSettle();

    expect(find.text('Saved Game'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
  });

  testWidgets('hides saved game card when no active run exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject(activeRun: null));
    await tester.pumpAndSettle();

    expect(find.text('Saved Game'), findsNothing);
  });

  testWidgets(
    'completed daily routes to Daily instead of starting a new play run',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildRouterSubject(dailyCompleted: true));
      await tester.pumpAndSettle();

      expect(find.text('Completed Today'), findsWidgets);
      expect(find.text('View Daily'), findsOneWidget);

      await tester.tap(find.text('View Daily'));
      await tester.pumpAndSettle();

      expect(find.text('daily route'), findsOneWidget);
      expect(find.textContaining('play '), findsNothing);
    },
  );

  testWidgets('resume CTA uses the existing resume flow', (
    WidgetTester tester,
  ) async {
    final run = buildRun();
    await seedSavedRun(run);

    await tester.pumpWidget(buildRouterSubject(activeRun: run));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Resume'));
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'play ${PuzzleType.sudokuClassic.key} ${PuzzleMode.random.key}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('main CTA starts random flow with the selected difficulty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject(preferredDifficulty: 'Medium'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Random Play'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hard'));
    await tester.tap(find.text('Hard'));
    await tester.pump();
    await tester.ensureVisible(find.text('Start Random Puzzle'));
    await tester.tap(find.text('Start Random Puzzle'));
    await tester.pump();

    expect(find.text('Generating Classic Sudoku'), findsOneWidget);
    expect(find.text('Difficulty: Hard'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('coming soon sheet disables launch actions safely', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject(sheetMetadata: comingSoonMetadata));
    await tester.pumpAndSettle();

    expect(find.text('Coming Soon'), findsWidgets);
    expect(find.text('Kakuro is coming soon.'), findsOneWidget);
    expect(find.text('Choose Mode'), findsNothing);

    final ElevatedButton button = tester.widget(
      find.widgetWithText(ElevatedButton, 'Coming Soon'),
    );
    expect(button.onPressed, isNull);
  });
}
