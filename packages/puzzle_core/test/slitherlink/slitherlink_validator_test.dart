import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

import 'package:puzzle_core/src/util/seeded_rng.dart';

void main() {
  group('SlitherlinkValidator', () {
    test('recognizes solved boards', () {
      final SlitherlinkGenerator generator = const SlitherlinkGenerator();
      final GeneratorContext context = GeneratorContext(
        rng: SeededRng(Seed.fromString('slitherlink_validator_test')),
        seedStr: 'slitherlink_validator_test',
        seed64: Seed.fromString('slitherlink_validator_test'),
        size: const SizeOpt(id: '5x5', description: '5x5', width: 5, height: 5),
        difficulty: const DifficultyRequest(level: 'easy'),
      );
      final SlitherlinkBoard puzzle = generator.generate(context).board;
      final SlitherlinkSolver solver = const SlitherlinkSolver();
      final SolverResult<SlitherlinkBoard> result = solver.solve(
        puzzle,
        SolverContext(
          rng: SeededRng(Seed.fromString('slitherlink_validator_solver')),
          maxSolutions: 1,
        ),
      );

      expect(result.hasSolution, isTrue);
      final SlitherlinkBoard solution = result.solutions.first;
      final SlitherlinkValidator validator = const SlitherlinkValidator();
      expect(validator.validateSolution(puzzle, solution).isValid, isTrue);
      expect(validator.isSolved(solution), isTrue);
    });

    test('flags multi-cycle solutions', () {
      final SlitherlinkTopology topology = SlitherlinkTopology.forSize(2, 2);
      final List<int?> clues = List<int?>.filled(4, null);
      final List<int> edges =
          List<int>.filled(topology.edgeCount, SlitherlinkBoard.edgeOff);

      const List<int> loopCells = <int>[0, 3];
      for (final int cell in loopCells) {
        for (final int edge in topology.cellEdges[cell]) {
          edges[edge] = SlitherlinkBoard.edgeOn;
        }
      }

      final SlitherlinkBoard puzzle = SlitherlinkBoard(
        width: 2,
        height: 2,
        clues: clues,
        edges: List<int>.filled(topology.edgeCount, SlitherlinkBoard.edgeUnknown),
      );
      final SlitherlinkBoard invalidSolution = SlitherlinkBoard(
        width: 2,
        height: 2,
        clues: clues,
        edges: edges,
      );

      final SlitherlinkValidator validator = const SlitherlinkValidator();
      final ValidationSummary summary =
          validator.validateSolution(puzzle, invalidSolution);
      expect(summary.isValid, isFalse);
      expect(summary.issues.join(','), contains('not_single_loop'));
    });
  });
}
