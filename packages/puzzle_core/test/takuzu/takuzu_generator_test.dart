import 'package:test/test.dart';

import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/generators/generator.dart';
import 'package:puzzle_core/src/takuzu/takuzu_board.dart';
import 'package:puzzle_core/src/takuzu/takuzu_generator.dart';
import 'package:puzzle_core/src/takuzu/takuzu_solver.dart';
import 'package:puzzle_core/src/takuzu/takuzu_validator.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:puzzle_core/src/validation/validator.dart';
import 'package:puzzle_core/src/solver/solver.dart';

void main() {
  group('TakuzuGenerator', () {
    const TakuzuGenerator generator = TakuzuGenerator();
    const TakuzuValidator validator = TakuzuValidator();
    const TakuzuSolver solver = TakuzuSolver();

    GeneratorContext context0(int seed) {
      return GeneratorContext(
        rng: SeededRng(seed),
        seedStr: 'takuzu_$seed',
        seed64: seed,
        size: const SizeOpt(id: '4x4', description: '4x4 Takuzu', width: 4, height: 4),
        difficulty: const DifficultyRequest(level: 'easy'),
      );
    }

    test('produces valid, uniquely solvable puzzles', () {
      final GeneratorContext context = context0(12345);
      final PuzzleGenerationResult<TakuzuBoard> result = generator.generate(context);

      final ValidationSummary summary = validator.validatePuzzle(result.board);
      expect(summary.isValid, isTrue, reason: summary.issues.join(','));

      final SolverResult<TakuzuBoard> solveResult = solver.solve(
        result.board,
        SolverContext(rng: SeededRng(987654321), maxSolutions: 2),
      );

      expect(solveResult.hasSolution, isTrue);
      expect(solveResult.isUnique, isTrue);
    });

    test('is deterministic for identical seeds', () {
      final PuzzleGenerationResult<TakuzuBoard> first = generator.generate(context0(42));
      final PuzzleGenerationResult<TakuzuBoard> second = generator.generate(context0(42));

      expect(first.board.cells, equals(second.board.cells));
      expect(first.board.fixed, equals(second.board.fixed));
    });
  });
}
