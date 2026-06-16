import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

void main() {
  group('SlitherlinkGenerator (on-demand)', () {
    final SlitherlinkGenerator generator = SlitherlinkGenerator();
    final SlitherlinkSolver solver = const SlitherlinkSolver();

    for (final SlitherlinkDifficulty difficulty
        in SlitherlinkDifficulty.values) {
      test('generates $difficulty puzzles', () async {
        final SlitherlinkPuzzle puzzle = await generator.generate(
          width: 6,
          height: 6,
          difficulty: difficulty,
          seed: Seed.fromString('slitherlink_async_${difficulty.name}'),
          timeBudget: const Duration(milliseconds: 400),
        );
        final SlitherlinkBoard board = puzzle.toBoard();
        final SolverResult<SlitherlinkBoard> solved = solver.solve(
          board,
          SolverContext(rng: SeededRng(0x12345678), maxSolutions: 2),
        );
        expect(
          solved.isUnique,
          isTrue,
          reason: 'Puzzle should have a single solution',
        );
        expect(
          board.clues.where((int? c) => c != null).length,
          greaterThan(0),
          reason: 'Clue set should not be empty',
        );
        final Map<int, int> histogram = <int, int>{};
        for (final int? clue in puzzle.clues) {
          if (clue != null) {
            histogram[clue] = (histogram[clue] ?? 0) + 1;
          }
        }
        final int informative =
            (histogram[1] ?? 0) +
            (histogram[2] ?? 0) +
            (histogram[3] ?? 0) +
            (histogram[4] ?? 0);
        expect(
          informative,
          greaterThan(0),
          reason: 'Should include non-zero clues',
        );
      });
    }

    test('rejects capped solver results from a tiny profile', () async {
      final SlitherlinkGenerator tinyGenerator = SlitherlinkGenerator(
        profile: _tinyProfile(),
      );

      await expectLater(
        tinyGenerator.generate(
          width: 6,
          height: 6,
          difficulty: SlitherlinkDifficulty.easy,
          seed: Seed.fromString('tiny_slitherlink_0'),
          timeBudget: const Duration(seconds: 1),
          maxRestarts: 1,
        ),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.toString(),
            'message',
            contains('Slitherlink solver could not prove uniqueness'),
          ),
        ),
      );
    });
  });
}

SlitherlinkDifficultyProfile _tinyProfile() {
  const SlitherlinkDifficultyTuning tinyTuning = SlitherlinkDifficultyTuning(
    generationTimeBudget: Duration(seconds: 1),
    removalTimeBudget: Duration(seconds: 1),
    solverMaxDepth: 0,
    targetClueFraction: 0.35,
    binarySearchFraction: 0.5,
    maxFailedRemovals: 2,
    maxRestarts: 1,
  );

  return SlitherlinkDifficultyProfile(
    <SlitherlinkDifficulty, SlitherlinkDifficultyTuning>{
      SlitherlinkDifficulty.easy: tinyTuning,
      SlitherlinkDifficulty.medium: tinyTuning,
      SlitherlinkDifficulty.hard: tinyTuning,
      SlitherlinkDifficulty.expert: tinyTuning,
    },
  );
}
