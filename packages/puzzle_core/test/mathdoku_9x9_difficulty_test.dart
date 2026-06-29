import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/mathdoku/mathdoku_solver.dart';

void main() {
  group('Mathdoku 9x9 difficulty generation', () {
    final MathdokuEngine engine = MathdokuEngine();
    const SizeOpt size9 = SizeOpt(
      id: 'latin9x9',
      description: 'Mathdoku 9x9',
      width: 9,
      height: 9,
    );

    const List<String> difficulties = <String>[
      'easy',
      'medium',
      'hard',
      'expert',
    ];

    DifficultyScore difficultyScoreFor(String level) {
      switch (level) {
        case 'easy':
          return const DifficultyScore(value: 0.3, level: 'easy');
        case 'medium':
          return const DifficultyScore(value: 0.6, level: 'medium');
        case 'hard':
          return const DifficultyScore(value: 0.9, level: 'hard');
        case 'expert':
          return const DifficultyScore(value: 1.0, level: 'expert');
        default:
          return const DifficultyScore(value: 0.6, level: 'medium');
      }
    }

    String benchmarkSeed(String level, int index) =>
        'bench:mathdoku_classic:$level:9x9:$index';

    double median(List<double> values) {
      expect(values, isNotEmpty);
      final List<double> sorted = List<double>.from(values)..sort();
      final int mid = sorted.length ~/ 2;
      if (sorted.length.isOdd) {
        return sorted[mid];
      }
      return (sorted[mid - 1] + sorted[mid]) / 2.0;
    }

    test('operations, coverage, and uniqueness hold across sample seeds', () {
      const int samplesPerDifficulty = 8;

      for (final String level in difficulties) {
        final DifficultyScore diffScore = difficultyScoreFor(level);
        for (int i = 0; i < samplesPerDifficulty; i++) {
          final String seedStr = benchmarkSeed(level, i);
          final int seed64 = Seed.fromString(seedStr);
          final GeneratedPuzzle<MathdokuBoard> generated = engine.generate(
            seedStr: seedStr,
            seed64: seed64,
            size: size9,
            difficulty: diffScore,
          );

          expect(generated.state.size, equals(9));

          final int expectedCells = 9 * 9;
          final Set<int> covered = <int>{};
          for (final MathdokuCage cage in generated.state.cages) {
            covered.addAll(cage.cells);
          }
          expect(covered.length, equals(expectedCells));

          for (final MathdokuCage cage in generated.state.cages) {
            if (cage.cells.length == 1) {
              expect(cage.operation, equals(MathdokuOperation.equality));
              continue;
            }
            expect(cage.operation == MathdokuOperation.equality, isFalse);
            if (cage.cells.length > 2) {
              expect(
                cage.operation == MathdokuOperation.subtraction ||
                    cage.operation == MathdokuOperation.division,
                isFalse,
                reason:
                    'Cage size ${cage.cells.length} must not use subtraction/division: ${cage.operation}',
              );
            }
          }

          final MathdokuSolver solver = const MathdokuSolver();
          final SolverResult<MathdokuBoard> result = solver.solve(
            generated.state,
            SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
          );
          expect(result.hasSolution, isTrue);
          expect(
            result.isUnique,
            isTrue,
            reason: 'Generated 9x9 $level puzzle should be uniquely solvable',
          );

          final Object? warning = generated.telemetry?.extras['warning'];
          if (warning != null) {
            expect(
              warning,
              contains('difficulty_mismatch'),
              reason:
                  'Fallback warning should be visible in telemetry when mismatch happens',
            );
          }
        }
      }
    });

    test('raw score medians increase by requested difficulty', () {
      const int samplesPerDifficulty = 12;
      final Map<String, double> medians = <String, double>{};

      for (final String level in difficulties) {
        final DifficultyScore diffScore = difficultyScoreFor(level);
        final List<double> rawScores = <double>[];

        for (int i = 0; i < samplesPerDifficulty; i++) {
          final String seedStr = benchmarkSeed(level, i);
          final int seed64 = Seed.fromString(seedStr);
          final GeneratedPuzzle<MathdokuBoard> generated = engine.generate(
            seedStr: seedStr,
            seed64: seed64,
            size: size9,
            difficulty: diffScore,
          );
          rawScores.add(
            generated.telemetry?.difficulty.rawScore ??
                generated.meta.difficulty.value,
          );
        }

        medians[level] = median(rawScores);
      }

      expect(
        medians['easy']!,
        lessThan(medians['medium']!),
        reason:
            'Expected easy median < medium median, got ${medians['easy']} and ${medians['medium']}',
      );
      expect(
        medians['medium']!,
        lessThan(medians['hard']!),
        reason:
            'Expected medium median < hard median, got ${medians['medium']} and ${medians['hard']}',
      );
      expect(
        medians['hard']!,
        lessThan(medians['expert']!),
        reason:
            'Expected hard median < expert median, got ${medians['hard']} and ${medians['expert']}',
      );
    });

    test('difficulty mismatch fallback emits warning telemetry', () {
      final MathdokuEngine strictEngine = MathdokuEngine(
        config: const DifficultyBucketConfig(
          buckets: <DifficultyBucketThreshold>[
            DifficultyBucketThreshold(id: 'easy', maxInclusive: 100.0),
            DifficultyBucketThreshold(id: 'medium', maxInclusive: 200.0),
            DifficultyBucketThreshold(id: 'hard', maxInclusive: 300.0),
            DifficultyBucketThreshold(id: 'expert', maxInclusive: 350.0),
          ],
        ),
      );

      const DifficultyScore requested = DifficultyScore(
        value: 0.3,
        level: 'easy',
      );
      final String seedStr = benchmarkSeed('easy', 0);
      final int seed64 = Seed.fromString(seedStr);

      final GeneratedPuzzle<MathdokuBoard> generated = strictEngine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: size9,
        difficulty: requested,
      );

      expect(generated.meta.difficulty.level, equals('expert'));
      expect(generated.telemetry, isNotNull);
      expect(
        generated.telemetry!.extras['warning'],
        equals('difficulty_mismatch_after_retries_returning_best_effort'),
      );
      expect(
        (generated.telemetry!.extras['attempt'] as num?)?.toInt(),
        equals(6),
      );

      final MathdokuSolver solver = const MathdokuSolver();
      final SolverResult<MathdokuBoard> result = solver.solve(
        generated.state,
        SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
      );
      expect(result.hasSolution, isTrue);
      expect(result.isUnique, isTrue);
    });
  });
}
