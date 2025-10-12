import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:test/test.dart';

void main() {
  group('Sudoku pipeline properties', () {
    final SudokuEngine engine = SudokuEngine();
    final SizeOpt size = SizeOpt(
      id: 'classic9x9',
      description: 'Classic 9x9',
      width: 9,
      height: 9,
    );
    const DifficultyScore difficulty = DifficultyScore(value: 0.0, level: 'auto');

    test('deterministic generation, solvable, and unique for sample seeds', () {
      final List<String> seeds = <String>[
        'sudoku_seed_0',
        'sudoku_seed_1',
        'sudoku_seed_2',
        'sudoku_seed_3',
        'sudoku_seed_4',
      ];

      for (final String seedStr in seeds) {
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<SudokuBoard> first = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size,
          difficulty: difficulty,
        );
        final GeneratedPuzzle<SudokuBoard> second = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size,
          difficulty: difficulty,
        );

        expect(first.state.cells, equals(second.state.cells));
        expect(first.meta.seed64, equals(seed64));

        final SudokuSolver solver = const SudokuSolver();
        final SolverResult<SudokuBoard> solveResult = solver.solve(
          first.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );

        expect(solveResult.hasSolution, isTrue, reason: 'Puzzle should be solvable');
        expect(solveResult.isUnique, isTrue, reason: 'Puzzle must be unique');

        final SudokuBoard solution = solveResult.solutions.first;
        final ValidationSummary validation =
            engine.validator.validateSolution(first.state, solution);
        expect(validation.isValid, isTrue, reason: validation.issues.join(','));
        expect(engine.isSolved(solution), isTrue);
      }
    });

    test('property sample of seeds remain deterministic and unique', () {
      for (int i = 0; i < 20; i++) {
        final String seedStr = 'property_seed_$i';
        final int seed64 = Seed.fromString(seedStr);
        final GeneratedPuzzle<SudokuBoard> generated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size,
          difficulty: difficulty,
        );

        final SudokuSolver solver = const SudokuSolver();
        final SolverResult<SudokuBoard> solveResult = solver.solve(
          generated.state,
          SolverContext(rng: SeededRng(seed64), maxSolutions: 2),
        );

        expect(solveResult.solutions.length, equals(1));
        final GeneratedPuzzle<SudokuBoard> regenerated = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: size,
          difficulty: difficulty,
        );
        expect(regenerated.state.cells, equals(generated.state.cells));
      }
    });
  });
}
