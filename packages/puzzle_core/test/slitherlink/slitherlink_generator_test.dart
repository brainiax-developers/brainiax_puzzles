import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

import 'package:puzzle_core/src/util/seeded_rng.dart';

void main() {
  group('SlitherlinkGenerator', () {
    test('produces solvable and unique puzzles', () {
      final SlitherlinkGenerator generator = const SlitherlinkGenerator();
      final GeneratorContext context = GeneratorContext(
        rng: SeededRng(Seed.fromString('slitherlink_generator_test')),
        seedStr: 'slitherlink_generator_test',
        seed64: Seed.fromString('slitherlink_generator_test'),
        size: const SizeOpt(id: '5x5', description: '5x5', width: 5, height: 5),
        difficulty: const DifficultyRequest(level: 'medium'),
      );

      final PuzzleGenerationResult<SlitherlinkBoard> result =
          generator.generate(context);
      final SlitherlinkBoard puzzle = result.board;

      expect(puzzle.width, 5);
      expect(puzzle.height, 5);
      expect(puzzle.clues.length, 25);
      expect(puzzle.clues.where((int? c) => c != null).length, greaterThan(0));

      final SlitherlinkValidator validator = const SlitherlinkValidator();
      expect(validator.validatePuzzle(puzzle).isValid, isTrue);

      final SlitherlinkSolver solver = const SlitherlinkSolver();
      final SolverResult<SlitherlinkBoard> solved = solver.solve(
        puzzle,
        SolverContext(
          rng: SeededRng(Seed.fromString('slitherlink_generator_test_solver')),
          maxSolutions: 2,
        ),
      );

      expect(solved.hasSolution, isTrue);
      expect(solved.isUnique, isTrue);
      final SlitherlinkBoard solution = solved.solutions.first;
      expect(validator.validateSolution(puzzle, solution).isValid, isTrue);
    });
  });
}
