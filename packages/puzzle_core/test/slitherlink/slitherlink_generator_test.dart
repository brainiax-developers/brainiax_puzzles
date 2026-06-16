import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

void main() {
  group('SlitherlinkPipelineGenerator', () {
    const SlitherlinkPipelineGenerator generator =
        SlitherlinkPipelineGenerator();
    const SlitherlinkValidator validator = SlitherlinkValidator();
    const SlitherlinkSolver solver = SlitherlinkSolver();

    GeneratorContext contextFor(
      String seed,
      int size, {
      String difficulty = 'medium',
    }) => GeneratorContext(
      rng: SeededRng(Seed.fromString(seed)),
      seedStr: seed,
      seed64: Seed.fromString(seed),
      size: SizeOpt(
        id: '${size}x$size',
        description: '${size}x$size',
        width: size,
        height: size,
      ),
      difficulty: DifficultyRequest(level: difficulty),
    );

    test('is deterministic for identical seeds', () {
      final PuzzleGenerationResult<SlitherlinkBoard> first = generator.generate(
        contextFor('slitherlink_deterministic', 5),
      );
      final PuzzleGenerationResult<SlitherlinkBoard> second = generator
          .generate(contextFor('slitherlink_deterministic', 5));

      expect(first.board.clues, equals(second.board.clues));
      expect(
        first.snapshot.telemetry['solutionEdges'],
        equals(second.snapshot.telemetry['solutionEdges']),
      );
    });

    test('produces a unique, single-loop puzzle', () {
      final PuzzleGenerationResult<SlitherlinkBoard> result = generator
          .generate(contextFor('slitherlink_unique', 6));
      final SlitherlinkBoard puzzle = result.board;

      expect(puzzle.clues.where((int? c) => c != null).length, greaterThan(0));
      expect(validator.validatePuzzle(puzzle).isValid, isTrue);

      final SolverResult<SlitherlinkBoard> solved = solver.solve(
        puzzle,
        SolverContext(
          rng: SeededRng(Seed.fromString('slitherlink_unique_solver')),
          maxSolutions: 2,
        ),
      );

      expect(solved.hasSolution, isTrue);
      expect(solved.isUnique, isTrue);
      final SlitherlinkBoard solution = solved.solutions.first;
      expect(validator.validateSolution(puzzle, solution).isValid, isTrue);
      _expectSingleLoop(solution);
    });

    test('generates 10x10 puzzles within performance budget', () {
      final Stopwatch sw = Stopwatch()..start();
      final PuzzleGenerationResult<SlitherlinkBoard> result = generator
          .generate(contextFor('slitherlink_perf', 10));
      sw.stop();

      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));

      final SolverResult<SlitherlinkBoard> solved = solver.solve(
        result.board,
        SolverContext(
          rng: SeededRng(Seed.fromString('slitherlink_perf_solver')),
          maxSolutions: 2,
        ),
      );
      expect(solved.isUnique, isTrue);
    });

    test('serializes and deserializes consistently', () {
      final PuzzleGenerationResult<SlitherlinkBoard> result = generator
          .generate(contextFor('slitherlink_serialize', 7));
      final SlitherlinkBoard roundTrip = SlitherlinkBoard.fromJson(
        result.board.toJson(),
      );
      expect(roundTrip, equals(result.board));
    });

    test('emits rich difficulty telemetry in generator snapshot', () {
      final PuzzleGenerationResult<SlitherlinkBoard> result = generator
          .generate(contextFor('slitherlink_telemetry', 5));
      final Map<String, Object?> telemetry = result.snapshot.telemetry;

      _expectSlitherlinkTelemetryKeys(telemetry);
      expect(
        telemetry['revealedClues'],
        equals(result.board.clues.where((int? clue) => clue != null).length),
      );
      expect(
        telemetry['hiddenClues'],
        equals(result.board.clues.where((int? clue) => clue == null).length),
      );
      final Map<String, Object?> histogram = (telemetry['clueHistogram'] as Map)
          .cast<String, Object?>();
      expect(histogram.keys, containsAll(<String>['0', '1', '2', '3']));
    });

    test('exposes rich difficulty telemetry on generated puzzles', () {
      final SlitherlinkEngine engine = SlitherlinkEngine(
        config: const DifficultyBucketConfig(
          buckets: <DifficultyBucketThreshold>[
            DifficultyBucketThreshold(id: 'medium', maxInclusive: 9999.0),
          ],
        ),
      );
      final GeneratedPuzzle<SlitherlinkBoard> generated = engine.generate(
        seedStr: 'slitherlink_generated_telemetry',
        seed64: Seed.fromString('slitherlink_generated_telemetry'),
        size: const SizeOpt(id: '5x5', description: '5x5', width: 5, height: 5),
        difficulty: const DifficultyScore(value: 0.5, level: 'medium'),
      );

      final GenerationTelemetry telemetry = generated.telemetry!;
      final Map<String, Object?> generatorTelemetry =
          (telemetry.extras['generator'] as Map).cast<String, Object?>();
      final Map<String, num> metrics = telemetry.difficulty.metrics;

      _expectSlitherlinkTelemetryKeys(generatorTelemetry);
      expect(
        telemetry.difficulty.bucket,
        equals(generated.meta.difficulty.level),
      );
      expect(metrics.keys, containsAll(_slitherlinkDifficultyMetricKeys));
      expect(
        engine.difficultyConfig.bucketFor(telemetry.difficulty.rawScore),
        equals(generated.meta.difficulty.level),
      );
    });

    test('rejects non-unique full-clue fallback solves', () {
      final SlitherlinkBoard first = _solvedBoard(
        width: 1,
        height: 1,
        edges: <int>[
          SlitherlinkBoard.edgeOn,
          SlitherlinkBoard.edgeOn,
          SlitherlinkBoard.edgeOn,
          SlitherlinkBoard.edgeOn,
        ],
      );
      final SlitherlinkBoard second = _solvedBoard(
        width: 1,
        height: 1,
        edges: <int>[
          SlitherlinkBoard.edgeOff,
          SlitherlinkBoard.edgeOff,
          SlitherlinkBoard.edgeOff,
          SlitherlinkBoard.edgeOff,
        ],
      );

      final SolverResult<SlitherlinkBoard> fallbackSolve =
          SolverResult<SlitherlinkBoard>(
            solutions: <SlitherlinkBoard>[first, second],
            elapsed: Duration.zero,
          );

      expect(slitherlinkFallbackSolveAccepted(fallbackSolve), isFalse);
    });
  });
}

const List<String> _slitherlinkTelemetryKeys = <String>[
  'clueDensity',
  'revealedClues',
  'hiddenClues',
  'clueHistogram',
  'loopEdgeCount',
  'speculativeSteps',
  'maxDepth',
  'localAssignments',
  'globalAssignments',
  'totalAssignments',
];

const List<String> _slitherlinkDifficultyMetricKeys = <String>[
  'clueDensity',
  'revealedClues',
  'hiddenClues',
  'clue0',
  'clue1',
  'clue2',
  'clue3',
  'loopEdgeCount',
  'speculativeSteps',
  'maxDepth',
  'localAssignments',
  'globalAssignments',
  'totalAssignments',
];

void _expectSlitherlinkTelemetryKeys(Map<String, Object?> telemetry) {
  expect(telemetry.keys, containsAll(_slitherlinkTelemetryKeys));
}

SlitherlinkBoard _solvedBoard({
  required int width,
  required int height,
  required List<int> edges,
}) {
  return SlitherlinkBoard(
    width: width,
    height: height,
    clues: List<int?>.filled(width * height, null),
    edges: edges,
  );
}

void _expectSingleLoop(SlitherlinkBoard solution) {
  final SlitherlinkTopology topology = solution.topology;
  final List<int> degree = List<int>.filled(topology.vertexCount, 0);
  final List<int> parent = List<int>.generate(
    topology.vertexCount,
    (int i) => i,
  );
  int find(int x) {
    if (parent[x] != x) {
      parent[x] = find(parent[x]);
    }
    return parent[x];
  }

  void union(int a, int b) {
    final int ra = find(a);
    final int rb = find(b);
    if (ra != rb) {
      parent[rb] = ra;
    }
  }

  int onEdges = 0;
  for (int edge = 0; edge < solution.edges.length; edge++) {
    if (solution.edges[edge] != SlitherlinkBoard.edgeOn) {
      continue;
    }
    onEdges++;
    final int a = topology.edgeVertexA[edge];
    final int b = topology.edgeVertexB[edge];
    degree[a]++;
    degree[b]++;
    union(a, b);
  }

  expect(onEdges, greaterThan(0));
  final List<int> activeVertices = <int>[];
  for (int v = 0; v < degree.length; v++) {
    final int deg = degree[v];
    expect(
      deg == 0 || deg == 2,
      isTrue,
      reason: 'Every vertex must have degree 0 or 2 in a single loop.',
    );
    if (deg > 0) {
      activeVertices.add(v);
    }
  }

  expect(activeVertices, isNotEmpty);
  final int root = find(activeVertices.first);
  for (final int v in activeVertices) {
    expect(
      find(v),
      root,
      reason: 'All active vertices should belong to the same component.',
    );
  }

  expect(
    onEdges,
    equals(activeVertices.length),
    reason: 'A single cycle has matching edge and vertex counts.',
  );
}
