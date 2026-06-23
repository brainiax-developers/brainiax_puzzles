import 'package:app/app_router.dart';
import 'package:app/features/daily/daily_hub_provider.dart';
import 'package:app/features/daily/daily_providers.dart';
import 'package:app/features/daily/daily_screen.dart';
import 'package:app/features/play/play_screen.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/navigation/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_puzzle_data.dart';

void main() {
  const String fireEmoji = '\u{1F525}';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<GoRouter> pumpDailyRouter(
    WidgetTester tester, {
    required DailyHubViewData view,
  }) async {
    final GoRouter router = createAppRouter(initialLocation: AppRoutes.daily);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyHubProvider.overrideWith((ref) async => view),
          dailyPuzzleProvider.overrideWith((ref, puzzleTypeKey) async {
            return switch (puzzleTypeKey) {
              'kakuro_classic' => buildKakuroPuzzle(),
              'slitherlink_loop' => buildSlitherlinkPuzzle(),
              'mathdoku_classic' => buildMathdokuPuzzle(),
              'nonogram_mono' => buildNonogramPuzzle(),
              _ => buildSudokuPuzzle(),
            };
          }),
        ],
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

  testWidgets('loads the Daily Challenges hub and does not auto-navigate', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpDailyRouter(
      tester,
      view: _buildView(
        streakCount: 13,
        statusCard: const DailyHubStatusCard(
          title: 'Keep your streak alive!',
          body: 'Complete any daily puzzle before reset.',
          ctaLabel: 'Keep streak going',
          isActionEnabled: true,
        ),
      ),
    );

    expect(find.byType(DailyScreen), findsOneWidget);
    expect(find.text('Daily Challenges'), findsWidgets);
    expect(find.textContaining('Resets in 8h 42m'), findsWidgets);
    expect(find.text('$fireEmoji 13 day streak'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-weekly-calendar')), findsOneWidget);
    await _scrollTo(tester, find.text('Today\'s Puzzles'));
    expect(find.text('Today\'s Puzzles'), findsOneWidget);
    expect(find.byType(PlayScreen), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.daily);
  });

  testWidgets('renders weekly states and dynamic card copy', (
    WidgetTester tester,
  ) async {
    await pumpDailyRouter(
      tester,
      view: _buildView(
        statusCard: const DailyHubStatusCard(
          title: 'Streak secured for today \u{1F525}',
          body: '2 puzzles left if you want more. Next set in 8h 42m.',
          ctaLabel: 'Play another',
          isActionEnabled: true,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('daily-weekday-2026-06-16-completed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('daily-weekday-2026-06-17-missed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('daily-weekday-2026-06-21-future')),
      findsOneWidget,
    );
    expect(find.text('Streak secured for today $fireEmoji'), findsOneWidget);
    expect(find.text('Resets in 8h 42m'), findsWidgets);
  });

  testWidgets('shows play, resume, completed, and solved time states', (
    WidgetTester tester,
  ) async {
    await pumpDailyRouter(tester, view: _buildView());

    await _scrollTo(tester, find.text('Today\'s Puzzles'));
    expect(find.text('3/5 done'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Play'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Resume'), findsOneWidget);
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('daily-puzzle-kakuro_classic')),
    );
    expect(find.widgetWithText(ElevatedButton, 'View'), findsWidgets);
    expect(find.text('Solved in 4m 5s'), findsOneWidget);
  });

  testWidgets('renders filters and hides old tab or fake social UI', (
    WidgetTester tester,
  ) async {
    await pumpDailyRouter(tester, view: _buildView());

    await _scrollTo(tester, find.text('Today\'s Puzzles'));
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Unplayed'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Completed'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Classic Sudoku'), findsNothing);
    expect(
      find.widgetWithText(ChoiceChip, 'Monochrome Nonogram'),
      findsNothing,
    );
    expect(find.textContaining('Locked streak'), findsNothing);
    expect(find.textContaining('Leaderboard'), findsNothing);
    expect(find.textContaining('playing'), findsNothing);
    expect(find.textContaining('rank'), findsNothing);
    await _scrollTo(
      tester,
      find.text('Today\'s set stays playable offline once opened.'),
    );
    expect(
      find.text('Today\'s set stays playable offline once opened.'),
      findsOneWidget,
    );
  });

  testWidgets('filters the Today\'s Puzzles list', (WidgetTester tester) async {
    await pumpDailyRouter(tester, view: _buildView());

    await _scrollTo(tester, find.text('Today\'s Puzzles'));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Unplayed'));
    await tester.pumpAndSettle();

    expect(find.text('Classic Sudoku'), findsOneWidget);
    expect(find.text('Monochrome Nonogram'), findsOneWidget);
    expect(find.text('Classic Kakuro'), findsNothing);
    expect(find.text('Slitherlink Loop'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pumpAndSettle();

    expect(find.text('Classic Sudoku'), findsNothing);
    expect(find.text('Monochrome Nonogram'), findsNothing);
    expect(find.text('Classic Kakuro'), findsOneWidget);
    expect(find.text('Slitherlink Loop'), findsOneWidget);
  });

  testWidgets('empty filter state renders safely', (WidgetTester tester) async {
    await pumpDailyRouter(
      tester,
      view: _buildView(
        completedCount: 0,
        totalCount: 2,
        entries: const <DailyHubPuzzleEntry>[
          DailyHubPuzzleEntry(
            puzzleType: PuzzleType.sudokuClassic,
            cardState: DailyHubCardState.play,
            solvedDuration: null,
            difficultyLabel: 'Daily',
          ),
          DailyHubPuzzleEntry(
            puzzleType: PuzzleType.nonogramMono,
            cardState: DailyHubCardState.resume,
            solvedDuration: null,
            difficultyLabel: 'Daily',
          ),
        ],
        uncompletedPuzzleTypes: const <PuzzleType>[
          PuzzleType.sudokuClassic,
          PuzzleType.nonogramMono,
        ],
      ),
    );

    await _scrollTo(tester, find.text('Today\'s Puzzles'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pumpAndSettle();

    expect(find.text('No puzzles match this filter'), findsOneWidget);
    expect(
      find.text(
        'Try a different filter to see the rest of today\'s daily set.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('completed daily puzzle cards route through the daily gate', (
    WidgetTester tester,
  ) async {
    await pumpDailyRouter(tester, view: _buildView());

    await _scrollTo(
      tester,
      find.byKey(const ValueKey('daily-puzzle-kakuro_classic')),
    );
    final Finder kakuroCard = find.byKey(
      const ValueKey('daily-puzzle-kakuro_classic'),
    );
    await tester.tap(
      find.descendant(
        of: kakuroCard,
        matching: find.widgetWithText(ElevatedButton, 'View'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PlayScreen), findsOneWidget);
    final PlayScreen playScreen = tester.widget(find.byType(PlayScreen));
    expect(playScreen.puzzleType, PuzzleType.kakuroClassic);
    expect(playScreen.mode, PuzzleMode.daily);
  });

  testWidgets('all-complete state does not show an enabled start action', (
    WidgetTester tester,
  ) async {
    await pumpDailyRouter(
      tester,
      view: _buildView(
        completedCount: 5,
        totalCount: 5,
        entries: const <DailyHubPuzzleEntry>[
          DailyHubPuzzleEntry(
            puzzleType: PuzzleType.sudokuClassic,
            cardState: DailyHubCardState.completed,
            solvedDuration: Duration(minutes: 4),
            difficultyLabel: 'Daily',
          ),
        ],
        uncompletedPuzzleTypes: const <PuzzleType>[],
        statusCard: const DailyHubStatusCard(
          title: 'Daily set complete!',
          body: 'Next set unlocks in 8h 42m.',
          ctaLabel: 'All done today',
          isActionEnabled: false,
        ),
      ),
    );

    final ElevatedButton button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'All done today'),
    );

    expect(find.text('Daily set complete!'), findsOneWidget);
    expect(button.onPressed, isNull);
  });
}

DailyHubViewData _buildView({
  int streakCount = 7,
  int completedCount = 3,
  int totalCount = 5,
  List<DailyHubPuzzleEntry>? entries,
  List<PuzzleType>? uncompletedPuzzleTypes,
  DailyHubStatusCard? statusCard,
}) {
  final List<DailyHubPuzzleEntry> resolvedEntries =
      entries ??
      const <DailyHubPuzzleEntry>[
        DailyHubPuzzleEntry(
          puzzleType: PuzzleType.sudokuClassic,
          cardState: DailyHubCardState.play,
          solvedDuration: null,
          difficultyLabel: 'Daily',
        ),
        DailyHubPuzzleEntry(
          puzzleType: PuzzleType.nonogramMono,
          cardState: DailyHubCardState.resume,
          solvedDuration: null,
          difficultyLabel: 'Daily',
        ),
        DailyHubPuzzleEntry(
          puzzleType: PuzzleType.kakuroClassic,
          cardState: DailyHubCardState.completed,
          solvedDuration: Duration(minutes: 4, seconds: 5),
          difficultyLabel: 'easy',
        ),
        DailyHubPuzzleEntry(
          puzzleType: PuzzleType.slitherlinkLoop,
          cardState: DailyHubCardState.completed,
          solvedDuration: Duration(minutes: 7, seconds: 12),
          difficultyLabel: 'Daily',
        ),
        DailyHubPuzzleEntry(
          puzzleType: PuzzleType.mathdokuClassic,
          cardState: DailyHubCardState.completed,
          solvedDuration: Duration(minutes: 9),
          difficultyLabel: 'Daily',
        ),
      ];

  return DailyHubViewData(
    streakCount: streakCount,
    timeUntilReset: const Duration(hours: 8, minutes: 42),
    completedCount: completedCount,
    totalCount: totalCount,
    week: <DailyHubWeekday>[
      DailyHubWeekday(
        dateUtc: DateTime.utc(2026, 6, 15),
        dateKeyUtc: '2026-06-15',
        label: 'Mon',
        state: DailyHubWeekdayState.unknown,
      ),
      DailyHubWeekday(
        dateUtc: DateTime.utc(2026, 6, 16),
        dateKeyUtc: '2026-06-16',
        label: 'Tue',
        state: DailyHubWeekdayState.completed,
      ),
      DailyHubWeekday(
        dateUtc: DateTime.utc(2026, 6, 17),
        dateKeyUtc: '2026-06-17',
        label: 'Wed',
        state: DailyHubWeekdayState.missed,
      ),
      DailyHubWeekday(
        dateUtc: DateTime.utc(2026, 6, 18),
        dateKeyUtc: '2026-06-18',
        label: 'Thu',
        state: DailyHubWeekdayState.missed,
      ),
      DailyHubWeekday(
        dateUtc: DateTime.utc(2026, 6, 19),
        dateKeyUtc: '2026-06-19',
        label: 'Fri',
        state: DailyHubWeekdayState.todayCompleted,
      ),
      DailyHubWeekday(
        dateUtc: DateTime.utc(2026, 6, 20),
        dateKeyUtc: '2026-06-20',
        label: 'Sat',
        state: DailyHubWeekdayState.future,
      ),
      DailyHubWeekday(
        dateUtc: DateTime.utc(2026, 6, 21),
        dateKeyUtc: '2026-06-21',
        label: 'Sun',
        state: DailyHubWeekdayState.future,
      ),
    ],
    entries: resolvedEntries,
    statusCard:
        statusCard ??
        const DailyHubStatusCard(
          title: 'Streak secured for today \u{1F525}',
          body: '2 puzzles left if you want more. Next set in 8h 42m.',
          ctaLabel: 'Play another',
          isActionEnabled: true,
        ),
    uncompletedPuzzleTypes:
        uncompletedPuzzleTypes ??
        const <PuzzleType>[PuzzleType.sudokuClassic, PuzzleType.nonogramMono],
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}
