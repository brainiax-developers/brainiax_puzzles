import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

void main() {
  group('SlitherlinkSolver', () {
    const SlitherlinkSolver solver = SlitherlinkSolver();
    const SlitherlinkValidator validator = SlitherlinkValidator();

    test('solves generated puzzles and respects uniqueness', () {
      final SlitherlinkPipelineGenerator generator =
          const SlitherlinkPipelineGenerator();
      final GeneratorContext context = GeneratorContext(
        rng: SeededRng(Seed.fromString('slitherlink_solver_test')),
        seedStr: 'slitherlink_solver_test',
        seed64: Seed.fromString('slitherlink_solver_test'),
        size: const SizeOpt(id: '6x6', description: '6x6', width: 6, height: 6),
        difficulty: const DifficultyRequest(level: 'hard'),
      );

      final SlitherlinkBoard puzzle = generator.generate(context).board;

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

    test('accepts a fixed completed single-loop solution', () {
      final SlitherlinkBoard completed = _completedBoard(
        width: 2,
        height: 2,
        clues: <int?>[2, 2, 2, 2],
        onEdges: (SlitherlinkTopology topology) => <int>[
          topology.horizontalEdgeIndex(0, 0),
          topology.horizontalEdgeIndex(0, 1),
          topology.horizontalEdgeIndex(2, 0),
          topology.horizontalEdgeIndex(2, 1),
          topology.verticalEdgeIndex(0, 0),
          topology.verticalEdgeIndex(1, 0),
          topology.verticalEdgeIndex(0, 2),
          topology.verticalEdgeIndex(1, 2),
        ],
      );

      final SolverResult<SlitherlinkBoard> result = solver.solve(
        completed,
        SolverContext(
          rng: SeededRng(Seed.fromString('slitherlink_fixed_single_loop')),
          maxSolutions: 2,
        ),
      );

      expect(result.solutionStatus, equals(SolverStatus.unique));
      expect(result.solutions, hasLength(1));
      expect(
        validator.validateSolution(completed, result.solutions.single).isValid,
        isTrue,
      );
    });

    test('rejects configurations with disjoint loops', () {
      final SlitherlinkBoard invalid = _completedBoard(
        width: 3,
        height: 1,
        clues: List<int?>.filled(3, null),
        onEdges: (SlitherlinkTopology topology) => <int>[
          ...topology.cellEdges[0],
          ...topology.cellEdges[2],
        ],
      );

      final SolverResult<SlitherlinkBoard> result = solver.solve(
        invalid,
        SolverContext(
          rng: SeededRng(Seed.fromString('slitherlink_solver_invalid')),
          maxSolutions: 2,
        ),
      );

      expect(result.hasSolution, isFalse);
    });

    test('reports noSolution for a known unsatisfiable clue', () {
      final SlitherlinkBoard puzzle = _unknownBoard(
        width: 1,
        height: 1,
        clues: <int?>[1],
      );

      final SolverResult<SlitherlinkBoard> result = solver.solve(
        puzzle,
        SolverContext(
          rng: SeededRng(Seed.fromString('slitherlink_no_solution')),
          maxSolutions: 2,
        ),
      );

      expect(result.solutionStatus, equals(SolverStatus.noSolution));
      expect(result.hasSolution, isFalse);
    });

    test('reports multiple for a known two-solution puzzle', () {
      final SlitherlinkBoard puzzle = _unknownBoard(
        width: 2,
        height: 2,
        clues: <int?>[2, 3, 3, 2],
      );

      final SolverResult<SlitherlinkBoard> result = solver.solve(
        puzzle,
        SolverContext(
          rng: SeededRng(Seed.fromString('slitherlink_multiple')),
          maxSolutions: 2,
        ),
      );

      expect(result.solutionStatus, equals(SolverStatus.multiple));
      expect(result.solutions, hasLength(2));
      for (final SlitherlinkBoard solution in result.solutions) {
        expect(validator.validateSolution(puzzle, solution).isValid, isTrue);
      }
    });

    test('reports unknown when a unique puzzle exhausts the search cap', () {
      final SlitherlinkBoard puzzle = _unknownBoard(
        width: 2,
        height: 2,
        clues: <int?>[2, 2, 2, 2],
      );

      final SolverResult<SlitherlinkBoard> uncapped = solver.solve(
        puzzle,
        SolverContext(
          rng: SeededRng(Seed.fromString('slitherlink_budget_uncapped')),
          maxSolutions: 2,
        ),
      );
      expect(uncapped.solutionStatus, equals(SolverStatus.unique));

      final SolverResult<SlitherlinkBoard> result = solver.solve(
        puzzle,
        SolverContext(
          rng: SeededRng(Seed.fromString('slitherlink_budget_unknown')),
          maxSolutions: 2,
          speculativeStepBudget: 0,
        ),
      );

      expect(result.solutionStatus, equals(SolverStatus.unknown));
      expect(result.isUnique, isFalse);
      expect(result.telemetry['speculativeStepBudgetHit'], isTrue);
    });
  });
}

SlitherlinkBoard _unknownBoard({
  required int width,
  required int height,
  required List<int?> clues,
}) {
  final SlitherlinkTopology topology = SlitherlinkTopology.forSize(
    width,
    height,
  );
  return SlitherlinkBoard(
    width: width,
    height: height,
    clues: clues,
    edges: List<int>.filled(topology.edgeCount, SlitherlinkBoard.edgeUnknown),
  );
}

SlitherlinkBoard _completedBoard({
  required int width,
  required int height,
  required List<int?> clues,
  required List<int> Function(SlitherlinkTopology topology) onEdges,
}) {
  final SlitherlinkTopology topology = SlitherlinkTopology.forSize(
    width,
    height,
  );
  final List<int> edges = List<int>.filled(
    topology.edgeCount,
    SlitherlinkBoard.edgeOff,
  );
  for (final int edge in onEdges(topology)) {
    edges[edge] = SlitherlinkBoard.edgeOn;
  }
  return SlitherlinkBoard(
    width: width,
    height: height,
    clues: clues,
    edges: edges,
  );
}
