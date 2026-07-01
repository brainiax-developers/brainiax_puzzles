import 'package:app/shared/models/models.dart';
import 'package:app/shared/widgets/active_run_card.dart';
import 'package:app/shared/widgets/category_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

void main() {
  testWidgets('active run card shows filled-cell progress and resume action', (
    WidgetTester tester,
  ) async {
    var resumed = false;
    await tester.pumpWidget(
      _app(
        ActiveRunCard(
          run: _run(
            puzzleType: PuzzleType.sudokuClassic,
            mode: PuzzleMode.daily,
            elapsedMs: 3723000,
            state: <String, dynamic>{
              'cells': <int>[1, 0, 2, 3],
              'fixed': <bool>[true, false, false, false],
            },
          ),
          title: 'Continue Sudoku',
          subtitle: 'Daily board',
          onResume: () => resumed = true,
        ),
      ),
    );

    expect(find.text('Continue Sudoku'), findsOneWidget);
    expect(find.text('Daily board'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.text('1h 2m'), findsOneWidget);
    expect(find.text('67% progress'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Resume'));
    expect(resumed, isTrue);
  });

  testWidgets('active run card computes puzzle-specific progress safely', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          child: Column(
            children: <Widget>[
              ActiveRunCard(
                run: _run(
                  puzzleType: PuzzleType.nonogramMono,
                  state: <String, dynamic>{
                    'cells': <int?>[1, null, 1, 0],
                    'rowClues': <List<int>>[
                      <int>[2],
                      <int>[1],
                    ],
                  },
                ),
                title: 'Nonogram',
                onResume: () {},
              ),
              ActiveRunCard(
                run: _run(
                  puzzleType: PuzzleType.slitherlinkLoop,
                  state: <String, dynamic>{
                    'edges': <int>[
                      core.SlitherlinkBoard.edgeOn,
                      core.SlitherlinkBoard.edgeOff,
                      core.SlitherlinkBoard.edgeUnknown,
                      core.SlitherlinkBoard.edgeOn,
                    ],
                  },
                ),
                title: 'Slitherlink',
                onResume: () {},
              ),
              ActiveRunCard(
                run: _run(
                  puzzleType: PuzzleType.takuzuBinary,
                  state: <String, dynamic>{
                    'cells': <int>[0, core.TakuzuBoard.emptyValue, 1, 0],
                    'fixed': <bool>[true, false, false, false],
                  },
                ),
                title: 'Takuzu',
                onResume: () {},
              ),
              ActiveRunCard(
                run: _run(
                  puzzleType: PuzzleType.kakuro,
                  state: <String, dynamic>{
                    'cells': <int>[0, 2, 0, 4],
                  },
                ),
                title: 'Kakuro',
                onResume: () {},
              ),
              ActiveRunCard(
                run: _run(
                  puzzleType: PuzzleType.mathdokuClassic,
                  state: <String, dynamic>{},
                ),
                title: 'Malformed',
                onResume: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('67% progress'), findsNWidgets(2));
    expect(find.text('50% progress'), findsWidgets);
    expect(find.text('Malformed'), findsOneWidget);
  });

  testWidgets('category header renders singular, plural, and no-count copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: <Widget>[
            CategoryHeader(category: PuzzleCategory.logic, puzzleCount: 1),
            CategoryHeader(category: PuzzleCategory.word, puzzleCount: 3),
            CategoryHeader(category: PuzzleCategory.logic),
          ],
        ),
      ),
    );

    expect(find.text('Logic'), findsNWidgets(2));
    expect(find.text('Word'), findsOneWidget);
    expect(find.text('1 puzzle'), findsOneWidget);
    expect(find.text('3 puzzles'), findsOneWidget);
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: Scaffold(body: child),
  );
}

ActivePuzzleRun _run({
  required PuzzleType puzzleType,
  PuzzleMode mode = PuzzleMode.random,
  int elapsedMs = 83000,
  required Map<String, dynamic> state,
}) {
  return ActivePuzzleRun(
    puzzleType: puzzleType,
    mode: mode,
    difficulty: 'easy',
    size: '4x4',
    seed: 'seed',
    generatedPuzzleJson: <String, dynamic>{'state': state},
    createdAtUtc: DateTime.utc(2026, 7, 1),
    updatedAtUtc: DateTime.utc(2026, 7, 1, 0, 1),
    elapsedMs: elapsedMs,
    moveCount: 2,
    hintsUsed: 0,
    isSolved: false,
    dailyDateKeyUtc: mode == PuzzleMode.daily ? '2026-07-01' : null,
  );
}
