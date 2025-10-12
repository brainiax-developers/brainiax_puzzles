import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/mathdoku/mathdoku_solver.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:puzzle_core/src/validation/validator.dart';
import 'package:test/test.dart';

void main() {
  group('Mathdoku engine pipeline', () {
    final MathdokuEngine engine = MathdokuEngine();
    final SizeOpt size4 = SizeOpt(
      id: 'latin4x4',
      description: 'Mathdoku 4x4',
      width: 4,
      height: 4,
    );
    final SizeOpt size6 = SizeOpt(
      id: 'latin6x6',
      description: 'Mathdoku 6x6',
      width: 6,
      height: 6,
    );
    const DifficultyScore difficulty = DifficultyScore(value: 0.0, level: 'auto');

    test('deterministic generation and unique solutions for 4x4 seeds', () {
      final List<String> seeds = <String>[
        'mathdoku_seed_0',
        'mathdoku_seed_1',
        'mathdoku_seed_2',
        'mathdoku_seed_3',
        'mathdoku_seed_4',
      ];

      for (final String seedStr in seeds) {
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<MathdokuBoard> first = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size4,
          difficulty: difficulty,
        );
        final GeneratedPuzzle<MathdokuBoard> second = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size4,
          difficulty: difficulty,
        );

        expect(first.state, equals(second.state));

        final MathdokuSolver solver = const MathdokuSolver();
        final SolverResult<MathdokuBoard> result = solver.solve(
          first.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );

        expect(result.hasSolution, isTrue, reason: 'Puzzle should be solvable');
        expect(result.isUnique, isTrue, reason: 'Puzzle must be unique');

        final MathdokuBoard solution = result.solutions.first;
        final ValidationSummary validation =
            engine.validator.validateSolution(first.state, solution);
        expect(validation.isValid, isTrue, reason: validation.issues.join(','));
        expect(engine.isSolved(solution), isTrue);
      }
    });

    test('deterministic generation for 6x6 seeds', () {
      for (int i = 0; i < 10; i++) {
        final String seedStr = 'mathdoku_property_$i';
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<MathdokuBoard> generated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size6,
          difficulty: difficulty,
        );

        final MathdokuSolver solver = const MathdokuSolver();
        final SolverResult<MathdokuBoard> result = solver.solve(
          generated.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );

        expect(result.solutions.length, equals(1));

        final GeneratedPuzzle<MathdokuBoard> regenerated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size6,
          difficulty: difficulty,
        );
        expect(regenerated.state, equals(generated.state));
      }
    });
  });
}
