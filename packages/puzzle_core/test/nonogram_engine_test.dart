import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/nonogram/nonogram_solver.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:puzzle_core/src/validation/validator.dart';
import 'package:test/test.dart';

void main() {
  group('Nonogram engine pipeline', () {
    final NonogramEngine engine = NonogramEngine();
    final SizeOpt size10 = SizeOpt(
      id: 'mono10x10',
      description: 'Monochrome 10x10',
      width: 10,
      height: 10,
    );
    final SizeOpt size15 = SizeOpt(
      id: 'mono15x15',
      description: 'Monochrome 15x15',
      width: 15,
      height: 15,
    );
    const DifficultyScore difficulty = DifficultyScore(value: 0.0, level: 'auto');

    test('deterministic generation and uniqueness for sample 10x10 seeds', () {
      const List<String> seeds = <String>[
        'nonogram_seed_0',
        'nonogram_seed_1',
        'nonogram_seed_2',
        'nonogram_seed_3',
        'nonogram_seed_4',
      ];

      for (final String seedStr in seeds) {
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<NonogramBoard> first = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size10,
          difficulty: difficulty,
        );
        final GeneratedPuzzle<NonogramBoard> second = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size10,
          difficulty: difficulty,
        );

        expect(first.state.rowClues, equals(second.state.rowClues));
        expect(first.state.columnClues, equals(second.state.columnClues));

        final NonogramSolver solver = const NonogramSolver();
        final SolverResult<NonogramBoard> solveResult = solver.solve(
          first.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );

        expect(solveResult.hasSolution, isTrue, reason: 'Puzzle should be solvable');
        expect(solveResult.isUnique, isTrue, reason: 'Puzzle must be unique');

        final NonogramBoard solution = solveResult.solutions.first;
        final ValidationSummary validation =
            engine.validator.validateSolution(first.state, solution);
        expect(validation.isValid, isTrue, reason: validation.issues.join(','));
        expect(engine.isSolved(solution), isTrue);
      }
    });

    test('property sample of seeds remain deterministic for 15x15 puzzles', () {
      for (int i = 0; i < 12; i++) {
        final String seedStr = 'nonogram_property_$i';
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<NonogramBoard> generated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size15,
          difficulty: difficulty,
        );

        final NonogramSolver solver = const NonogramSolver();
        final SolverResult<NonogramBoard> solveResult = solver.solve(
          generated.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );

        expect(solveResult.solutions.length, equals(1));

        final GeneratedPuzzle<NonogramBoard> regenerated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size15,
          difficulty: difficulty,
        );
        expect(regenerated.state.rowClues, equals(generated.state.rowClues));
        expect(regenerated.state.columnClues, equals(generated.state.columnClues));
      }
    });
  });
}
