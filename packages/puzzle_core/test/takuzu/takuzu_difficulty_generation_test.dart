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
  group('TakuzuGenerator difficulty profiles', () {
    const TakuzuGenerator generator = TakuzuGenerator();
    const TakuzuValidator validator = TakuzuValidator();
    const TakuzuSolver solver = TakuzuSolver();

    GeneratorContext ctx({
      required int seed,
      required String level,
      required int size,
    }) => GeneratorContext(
          rng: SeededRng(seed),
          seedStr: 'takuzu_${level}_$seed',
          seed64: seed,
          size: SizeOpt(id: '${size}x$size', description: '$size x $size', width: size, height: size),
          difficulty: DifficultyRequest(level: level),
        );

    Future<void> assertPuzzle({
      required String level,
      required int size,
      required double minRatio,
      required double maxRatio,
      required int minChain,
      required int maxChain,
    }) async {
      final GeneratorContext context = ctx(seed: 123456, level: level, size: size);
      final PuzzleGenerationResult<TakuzuBoard> result = generator.generate(context);

      final ValidationSummary summary = validator.validatePuzzle(result.board);
      expect(summary.isValid, isTrue, reason: summary.issues.join(','));

      final SolverResult<TakuzuBoard> solveResult = solver.solve(
        result.board,
        SolverContext(rng: SeededRng(987654321), maxSolutions: 2),
      );
      expect(solveResult.hasSolution, isTrue);
      expect(solveResult.isUnique, isTrue);

      final int givens = result.board.cells.where((int v) => v != TakuzuBoard.emptyValue).length;
      final double ratio = givens / result.board.cellCount;
      final double oneCell = 1.0 / result.board.cellCount;
      if (level != 'expert') {
        expect(ratio >= minRatio && ratio <= maxRatio + oneCell, isTrue,
            reason: 'ratio=$ratio not in [$minRatio, ${maxRatio + oneCell}] for $level');
      } else {
        expect(ratio <= maxRatio + oneCell, isTrue, reason: 'ratio=$ratio exceeds ${maxRatio + oneCell} for expert');
      }

      final int chain = (solveResult.telemetry['longestChain'] as int?) ??
          ((solveResult.telemetry['longestChain'] as num?)?.toInt() ?? 0);
      if (level == 'easy') {
        // No strict chain requirements for easy beyond density.
        expect(chain >= 0, isTrue);
      } else {
        expect(chain >= minChain, isTrue,
            reason: 'chain=$chain below min $minChain for $level');
      }
    }

    test('easy 6x6', () async {
      await assertPuzzle(level: 'easy', size: 6, minRatio: 0.50, maxRatio: 0.60, minChain: 0, maxChain: 1);
    });

    test('medium 8x8', () async {
      await assertPuzzle(level: 'medium', size: 8, minRatio: 0.40, maxRatio: 0.50, minChain: 1, maxChain: 2);
    });

    test('hard 10x10', () async {
      await assertPuzzle(level: 'hard', size: 10, minRatio: 0.30, maxRatio: 0.40, minChain: 3, maxChain: 5);
    });

    test('expert 12x12', () async {
      await assertPuzzle(level: 'expert', size: 12, minRatio: 0.20, maxRatio: 0.30, minChain: 6, maxChain: 9999);
    });
  });
}
