import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

void main() {
  final SudokuDifficultyScorer scorer = const SudokuDifficultyScorer();
  final DifficultyBucketConfig config =
      const DifficultyConfigLoader().loadSync('assets/difficulty_thresholds.json');

  final SudokuBoard solution = boardFromMatrix(const <List<int>>[
    <int>[5, 3, 4, 6, 7, 8, 9, 1, 2],
    <int>[6, 7, 2, 1, 9, 5, 3, 4, 8],
    <int>[1, 9, 8, 3, 4, 2, 5, 6, 7],
    <int>[8, 5, 9, 7, 6, 1, 4, 2, 3],
    <int>[4, 2, 6, 8, 5, 3, 7, 9, 1],
    <int>[7, 1, 3, 9, 2, 4, 8, 5, 6],
    <int>[9, 6, 1, 5, 3, 7, 2, 8, 4],
    <int>[2, 8, 7, 4, 1, 9, 6, 3, 5],
    <int>[3, 4, 5, 2, 8, 6, 1, 7, 9],
  ]);

  test('difficulty buckets stay stable for fixture telemetry', () {
    final List<_Fixture> fixtures = <_Fixture>[
      _Fixture(
        name: 'easy',
        puzzle: boardFromMatrix(const <List<int>>[
          <int>[5, 3, 0, 6, 0, 8, 9, 1, 2],
          <int>[6, 0, 2, 1, 9, 5, 0, 4, 8],
          <int>[1, 9, 0, 3, 4, 2, 5, 6, 7],
          <int>[8, 5, 9, 7, 0, 1, 4, 2, 3],
          <int>[4, 2, 6, 8, 5, 3, 7, 0, 1],
          <int>[7, 1, 0, 9, 2, 4, 8, 5, 6],
          <int>[9, 6, 1, 5, 3, 7, 2, 8, 0],
          <int>[2, 8, 7, 4, 1, 9, 0, 3, 5],
          <int>[3, 4, 5, 2, 8, 6, 1, 7, 9],
        ]),
        solverTelemetry: const <String, Object?>{
          'humanAssignments': 10,
          'techniqueCounts': <String, int>{'nakedSingle': 10},
          'searchDepth': 0,
          'searchNodes': 0,
        },
        expectedBucket: 'easy',
      ),
      _Fixture(
        name: 'medium',
        puzzle: boardFromMatrix(const <List<int>>[
          <int>[5, 0, 4, 6, 7, 8, 9, 1, 2],
          <int>[6, 7, 0, 1, 9, 5, 3, 4, 8],
          <int>[1, 9, 8, 3, 0, 2, 5, 6, 7],
          <int>[8, 5, 9, 7, 6, 1, 4, 2, 3],
          <int>[4, 2, 6, 8, 5, 3, 7, 9, 1],
          <int>[7, 1, 3, 9, 2, 4, 8, 5, 6],
          <int>[9, 6, 1, 5, 3, 7, 2, 8, 4],
          <int>[2, 8, 7, 4, 1, 9, 6, 3, 5],
          <int>[3, 4, 5, 2, 8, 6, 1, 7, 9],
        ]),
        solverTelemetry: const <String, Object?>{
          'humanAssignments': 35,
          'techniqueCounts': <String, int>{
            'nakedSingle': 20,
            'hiddenSingle': 10,
            'nakedSubset': 5,
          },
          'searchDepth': 0,
          'searchNodes': 0,
        },
        expectedBucket: 'medium',
      ),
      _Fixture(
        name: 'hard',
        puzzle: boardFromMatrix(const <List<int>>[
          <int>[5, 0, 4, 0, 7, 8, 9, 1, 2],
          <int>[6, 7, 0, 1, 9, 5, 3, 4, 0],
          <int>[1, 9, 8, 3, 0, 2, 5, 6, 7],
          <int>[8, 5, 9, 7, 6, 1, 4, 0, 3],
          <int>[4, 2, 6, 8, 5, 3, 7, 9, 1],
          <int>[7, 1, 3, 9, 2, 4, 0, 5, 6],
          <int>[9, 6, 1, 5, 3, 7, 2, 8, 4],
          <int>[2, 8, 7, 4, 1, 9, 6, 3, 5],
          <int>[3, 4, 5, 2, 8, 6, 1, 7, 9],
        ]),
        solverTelemetry: const <String, Object?>{
          'humanAssignments': 45,
          'techniqueCounts': <String, int>{
            'nakedSingle': 15,
            'hiddenSingle': 12,
            'nakedSubset': 8,
            'pointing': 5,
            'claiming': 5,
          },
          'searchDepth': 2,
          'searchNodes': 180,
        },
        expectedBucket: 'hard',
      ),
      _Fixture(
        name: 'expert',
        puzzle: boardFromMatrix(const <List<int>>[
          <int>[5, 0, 4, 0, 7, 0, 9, 1, 0],
          <int>[6, 0, 0, 1, 9, 5, 3, 4, 0],
          <int>[1, 9, 8, 0, 0, 2, 5, 6, 0],
          <int>[8, 5, 9, 7, 0, 1, 4, 0, 3],
          <int>[4, 2, 6, 8, 5, 3, 7, 9, 1],
          <int>[7, 1, 3, 9, 2, 4, 0, 5, 6],
          <int>[9, 6, 1, 5, 3, 7, 2, 8, 4],
          <int>[2, 8, 7, 4, 1, 9, 6, 3, 5],
          <int>[3, 4, 5, 2, 8, 6, 1, 7, 9],
        ]),
        solverTelemetry: const <String, Object?>{
          'humanAssignments': 55,
          'techniqueCounts': <String, int>{
            'nakedSingle': 12,
            'hiddenSingle': 10,
            'nakedSubset': 8,
            'pointing': 6,
            'claiming': 6,
            'xWing': 3,
            'swordfish': 2,
          },
          'searchDepth': 4,
          'searchNodes': 560,
        },
        expectedBucket: 'expert',
      ),
    ];

    for (final _Fixture fixture in fixtures) {
      final DifficultyTelemetry telemetry = scorer.score(
        puzzle: fixture.puzzle,
        solution: solution,
        context: DifficultyContext(
          generatorTelemetry: fixture.generatorTelemetry,
          solverTelemetry: fixture.solverTelemetry,
        ),
      );
      final String bucket = config.bucketFor(telemetry.rawScore);
      expect(bucket, fixture.expectedBucket, reason: fixture.name);
    }
  });
}

class _Fixture {
  final String name;
  final SudokuBoard puzzle;
  final Map<String, Object?> generatorTelemetry;
  final Map<String, Object?> solverTelemetry;
  final String expectedBucket;

  _Fixture({
    required this.name,
    required this.puzzle,
    Map<String, Object?>? generatorTelemetry,
    required this.solverTelemetry,
    required this.expectedBucket,
  }) : generatorTelemetry = generatorTelemetry ?? <String, Object?>{
          'clues': puzzle.clueCount,
          'removals': SudokuBoard.cellCount - puzzle.clueCount,
        };
}
