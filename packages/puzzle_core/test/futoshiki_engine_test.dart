import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/futoshiki/futoshiki_solver.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:puzzle_core/src/validation/validator.dart';
import 'package:test/test.dart';

void main() {
  group('Futoshiki engine pipeline', () {
    final FutoshikiEngine engine = FutoshikiEngine();
    final SizeOpt size4 = SizeOpt(
      id: 'latin4x4',
      description: 'Futoshiki 4x4',
      width: 4,
      height: 4,
    );
    final SizeOpt size5 = SizeOpt(
      id: 'latin5x5',
      description: 'Futoshiki 5x5',
      width: 5,
      height: 5,
    );
    const DifficultyScore difficulty = DifficultyScore(value: 0.0, level: 'auto');

    test('deterministic generation and unique solutions for 4x4 seeds', () {
      final List<String> seeds = <String>[
        'futoshiki_seed_0',
        'futoshiki_seed_1',
        'futoshiki_seed_2',
        'futoshiki_seed_3',
        'futoshiki_seed_4',
      ];

      for (final String seedStr in seeds) {
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<FutoshikiBoard> first = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size4,
          difficulty: difficulty,
        );
        final GeneratedPuzzle<FutoshikiBoard> second = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size4,
          difficulty: difficulty,
        );

        expect(first.state, equals(second.state));

        final FutoshikiSolver solver = const FutoshikiSolver();
        final SolverResult<FutoshikiBoard> result = solver.solve(
          first.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );

        expect(result.hasSolution, isTrue, reason: 'Puzzle should be solvable');
        expect(result.isUnique, isTrue, reason: 'Puzzle must be unique');

        final FutoshikiBoard solution = result.solutions.first;
        final ValidationSummary validation =
            engine.validator.validateSolution(first.state, solution);
        expect(validation.isValid, isTrue, reason: validation.issues.join(','));
        expect(engine.isSolved(solution), isTrue);
      }
    });

    test('deterministic generation for 5x5 seeds', () {
      for (int i = 0; i < 10; i++) {
        final String seedStr = 'futoshiki_property_$i';
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<FutoshikiBoard> generated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size5,
          difficulty: difficulty,
        );

        final FutoshikiSolver solver = const FutoshikiSolver();
        final SolverResult<FutoshikiBoard> result = solver.solve(
          generated.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );

        expect(result.solutions.length, equals(1));

        final GeneratedPuzzle<FutoshikiBoard> regenerated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size5,
          difficulty: difficulty,
        );
        expect(regenerated.state, equals(generated.state));
      }
    });
  });
}
