import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

import 'package:puzzle_core/src/util/seeded_rng.dart';

void main() {
  group('SlitherlinkSolver', () {
    test('solves generated puzzles and respects uniqueness', () {
      final SlitherlinkPipelineGenerator generator = const SlitherlinkPipelineGenerator();
      final GeneratorContext context = GeneratorContext(
        rng: SeededRng(Seed.fromString('slitherlink_solver_test')),
        seedStr: 'slitherlink_solver_test',
        seed64: Seed.fromString('slitherlink_solver_test'),
        size: const SizeOpt(id: '6x6', description: '6x6', width: 6, height: 6),
        difficulty: const DifficultyRequest(level: 'hard'),
      );

      final SlitherlinkBoard puzzle = generator.generate(context).board;
      final SlitherlinkSolver solver = const SlitherlinkSolver();
      final SlitherlinkValidator validator = const SlitherlinkValidator();

      final SolverResult<SlitherlinkBoard> result = solver.solve(
        puzzle,
        SolverContext(
          rng: SeededRng(Seed.fromString('slitherlink_solver_test_solver')),
          maxSolutions: 2,
        ),
      );

      expect(result.hasSolution, isTrue);
      expect(result.isUnique, isTrue);
      final SlitherlinkBoard solution = result.solutions.single;
      expect(validator.validateSolution(puzzle, solution).isValid, isTrue);
      expect(validator.isSolved(solution), isTrue);
    });

    test('rejects configurations with disjoint loops', () {
      final SlitherlinkTopology topology = SlitherlinkTopology.forSize(2, 2);
      final List<int?> clues = List<int?>.filled(4, null);
      final List<int> edges =
          List<int>.filled(topology.edgeCount, SlitherlinkBoard.edgeOff);

      // Build two independent 1x1 loops in opposite corners.
      const List<int> loopCells = <int>[0, 3];
      for (final int cell in loopCells) {
        for (final int edge in topology.cellEdges[cell]) {
          edges[edge] = SlitherlinkBoard.edgeOn;
        }
      }

      final SlitherlinkBoard invalid = SlitherlinkBoard(
        width: 2,
        height: 2,
        clues: clues,
        edges: edges,
      );

      final SlitherlinkSolver solver = const SlitherlinkSolver();
      final SolverResult<SlitherlinkBoard> result = solver.solve(
        invalid,
        SolverContext(
          rng: SeededRng(Seed.fromString('slitherlink_solver_invalid')),
          maxSolutions: 2,
        ),
      );

      expect(result.hasSolution, isFalse);
    });
  });
}
