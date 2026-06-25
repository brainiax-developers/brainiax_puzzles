import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

void main() {
  group('SlitherlinkValidator', () {
    const SlitherlinkValidator validator = SlitherlinkValidator();

    test('recognizes solved boards', () {
      final SlitherlinkPipelineGenerator generator =
          const SlitherlinkPipelineGenerator();
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
      expect(validator.validateSolution(puzzle, solution).isValid, isTrue);
      expect(validator.isSolved(solution), isTrue);
    });

    test('accepts a completed single-loop fixture', () {
      final SlitherlinkBoard puzzle = _unknownBoard(
        width: 2,
        height: 2,
        clues: <int?>[2, 2, 2, 2],
      );
      final SlitherlinkBoard solution = _completedBoard(
        width: 2,
        height: 2,
        clues: puzzle.clues,
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

      expect(validator.validateSolution(puzzle, solution).isValid, isTrue);
      expect(validator.isSolved(solution), isTrue);
    });

    test(
      'isSolved accepts required loop edges with non-loop edges unmarked',
      () {
        final SlitherlinkBoard board = _outerLoopFixture(
          nonLoopValue: SlitherlinkBoard.edgeUnknown,
        );

        expect(validator.isSolved(board), isTrue);
      },
    );

    test(
      'isSolved accepts required loop edges with non-loop edges crossed',
      () {
        final SlitherlinkBoard board = _outerLoopFixture(
          nonLoopValue: SlitherlinkBoard.edgeOff,
        );

        expect(validator.isSolved(board), isTrue);
      },
    );

    test('isSolved rejects a missing required loop edge', () {
      final SlitherlinkBoard board = _outerLoopFixture(
        nonLoopValue: SlitherlinkBoard.edgeUnknown,
        removeEdge: (SlitherlinkTopology topology) =>
            topology.horizontalEdgeIndex(0, 0),
      );

      expect(validator.isSolved(board), isFalse);
    });

    test('isSolved rejects an incorrectly drawn non-loop edge', () {
      final SlitherlinkBoard board = _outerLoopFixture(
        nonLoopValue: SlitherlinkBoard.edgeUnknown,
        addEdge: (SlitherlinkTopology topology) =>
            topology.horizontalEdgeIndex(1, 0),
      );

      expect(validator.isSolved(board), isFalse);
    });

    test('isSolved does not require crosses on non-loop edges', () {
      final SlitherlinkBoard board = _outerLoopFixture(
        nonLoopValue: SlitherlinkBoard.edgeUnknown,
      );

      expect(board.isComplete, isFalse);
      expect(validator.isSolved(board), isTrue);
    });

    test('flags multi-cycle solutions', () {
      final SlitherlinkBoard puzzle = _unknownBoard(
        width: 3,
        height: 1,
        clues: List<int?>.filled(3, null),
      );
      final SlitherlinkBoard invalidSolution = _completedBoard(
        width: 3,
        height: 1,
        clues: puzzle.clues,
        onEdges: (SlitherlinkTopology topology) => <int>[
          ...topology.cellEdges[0],
          ...topology.cellEdges[2],
        ],
      );

      final ValidationSummary summary = validator.validateSolution(
        puzzle,
        invalidSolution,
      );
      expect(summary.isValid, isFalse);
      expect(summary.issues.join(','), contains('not_single_loop'));
    });

    test('flags completed boards with a degree-3 branch', () {
      final SlitherlinkBoard puzzle = _unknownBoard(
        width: 2,
        height: 2,
        clues: List<int?>.filled(4, null),
      );
      final SlitherlinkBoard invalidSolution = _completedBoard(
        width: 2,
        height: 2,
        clues: puzzle.clues,
        onEdges: (SlitherlinkTopology topology) => <int>[
          topology.horizontalEdgeIndex(0, 0),
          topology.horizontalEdgeIndex(0, 1),
          topology.verticalEdgeIndex(0, 1),
        ],
      );

      final SlitherlinkTopology topology = invalidSolution.topology;
      expect(
        _onDegreeAt(invalidSolution, topology.vertexIndex(0, 1)),
        equals(3),
      );

      final ValidationSummary summary = validator.validateSolution(
        puzzle,
        invalidSolution,
      );
      expect(summary.isValid, isFalse);
      expect(summary.issues, contains(startsWith('vertex_degree_violation:')));
    });

    test('flags completed boards with a dangling endpoint', () {
      final SlitherlinkBoard puzzle = _unknownBoard(
        width: 2,
        height: 2,
        clues: List<int?>.filled(4, null),
      );
      final SlitherlinkBoard invalidSolution = _completedBoard(
        width: 2,
        height: 2,
        clues: puzzle.clues,
        onEdges: (SlitherlinkTopology topology) => <int>[
          topology.horizontalEdgeIndex(0, 0),
        ],
      );

      final ValidationSummary summary = validator.validateSolution(
        puzzle,
        invalidSolution,
      );
      expect(summary.isValid, isFalse);
      expect(summary.issues, contains(startsWith('vertex_degree_violation:')));
    });

    test('rejects clue values above the Slitherlink range', () {
      final SlitherlinkBoard puzzle = _unknownBoard(
        width: 2,
        height: 2,
        clues: <int?>[4, null, null, null],
      );

      final ValidationSummary summary = validator.validatePuzzle(puzzle);

      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('invalid_clue:0'));
    });
  });
}

SlitherlinkBoard _outerLoopFixture({
  required int nonLoopValue,
  int Function(SlitherlinkTopology topology)? removeEdge,
  int Function(SlitherlinkTopology topology)? addEdge,
}) {
  final SlitherlinkTopology topology = SlitherlinkTopology.forSize(2, 2);
  final Set<int> loopEdges = <int>{
    topology.horizontalEdgeIndex(0, 0),
    topology.horizontalEdgeIndex(0, 1),
    topology.horizontalEdgeIndex(2, 0),
    topology.horizontalEdgeIndex(2, 1),
    topology.verticalEdgeIndex(0, 0),
    topology.verticalEdgeIndex(1, 0),
    topology.verticalEdgeIndex(0, 2),
    topology.verticalEdgeIndex(1, 2),
  };

  final int? edgeToRemove = removeEdge?.call(topology);
  if (edgeToRemove != null) {
    loopEdges.remove(edgeToRemove);
  }
  final int? edgeToAdd = addEdge?.call(topology);
  if (edgeToAdd != null) {
    loopEdges.add(edgeToAdd);
  }

  return SlitherlinkBoard(
    width: 2,
    height: 2,
    clues: const <int?>[2, 2, 2, 2],
    edges: List<int>.generate(
      topology.edgeCount,
      (int edge) =>
          loopEdges.contains(edge) ? SlitherlinkBoard.edgeOn : nonLoopValue,
    ),
  );
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

int _onDegreeAt(SlitherlinkBoard board, int vertex) {
  int degree = 0;
  for (final int edge in board.topology.vertexEdges[vertex]) {
    if (board.edges[edge] == SlitherlinkBoard.edgeOn) {
      degree++;
    }
  }
  return degree;
}
