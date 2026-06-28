import 'dart:io';

import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/engine/slitherlink/solver_adapter.dart';
import 'package:puzzle_core/src/generators/slitherlink/removal.dart';
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

    test('different seeds normally produce different clue layouts', () {
      final PuzzleGenerationResult<SlitherlinkBoard> first = generator.generate(
        contextFor('slitherlink_different_seed_a', 5, difficulty: 'easy'),
      );
      final PuzzleGenerationResult<SlitherlinkBoard> second = generator
          .generate(
            contextFor('slitherlink_different_seed_b', 5, difficulty: 'easy'),
          );

      expect(first.board.clues, isNot(equals(second.board.clues)));
    });

    test('5x5 easy generation passes loop and clue quality gates', () {
      final PuzzleGenerationResult<SlitherlinkBoard> result = generator
          .generate(
            contextFor('slitherlink_easy_quality', 5, difficulty: 'easy'),
          );
      final Map<String, Object?> telemetry = result.snapshot.telemetry;

      expect(telemetry['loopEdgeCount'], greaterThanOrEqualTo(16));
      expect(telemetry['loopTouchedRows'], greaterThanOrEqualTo(4));
      expect(telemetry['loopTouchedCols'], greaterThanOrEqualTo(4));
      expect(telemetry['loopBoundingBoxWidth'], greaterThanOrEqualTo(4));
      expect(telemetry['loopBoundingBoxHeight'], greaterThanOrEqualTo(4));
      expect((telemetry['revealedZeroRatio'] as num), lessThanOrEqualTo(0.50));
      expect(telemetry['nonZeroRevealedClues'], greaterThanOrEqualTo(6));
      expect(telemetry['qualityGatePassed'], isTrue);
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

    test('5x5 easy regression seeds avoid tiny and zero-heavy puzzles', () {
      final SlitherlinkQualityProfile profile = slitherlinkQualityProfileFor(
        width: 5,
        height: 5,
        difficulty: 'easy',
      );
      for (int i = 0; i < 20; i++) {
        final String seed = 'slitherlink_easy_regression_$i';
        final PuzzleGenerationResult<SlitherlinkBoard> result = generator
            .generate(contextFor(seed, 5, difficulty: 'easy'));
        final Map<String, Object?> telemetry = result.snapshot.telemetry;

        expect(
          telemetry['loopEdgeCount'],
          greaterThanOrEqualTo(profile.minLoopEdgeCount),
          reason: seed,
        );
        expect(
          telemetry['loopTouchedRows'],
          greaterThanOrEqualTo(profile.minTouchedRows),
          reason: seed,
        );
        expect(
          telemetry['loopTouchedCols'],
          greaterThanOrEqualTo(profile.minTouchedCols),
          reason: seed,
        );
        expect(
          telemetry['loopBoundingBoxWidth'],
          greaterThanOrEqualTo(profile.minBoundingBoxWidth),
          reason: seed,
        );
        expect(
          telemetry['loopBoundingBoxHeight'],
          greaterThanOrEqualTo(profile.minBoundingBoxHeight),
          reason: seed,
        );
        expect(
          telemetry['revealedZeroRatio'] as num,
          lessThanOrEqualTo(profile.maxRevealedZeroRatio),
          reason: seed,
        );
        expect(
          telemetry['nonZeroRevealedClues'],
          greaterThanOrEqualTo(profile.minNonZeroRevealedClues),
          reason: seed,
        );

        final SolverResult<SlitherlinkBoard> solved = solver.solve(
          result.board,
          SolverContext(
            rng: SeededRng(Seed.fromString('$seed:solver')),
            maxSolutions: 2,
          ),
        );
        expect(
          solved.solutionStatus,
          isNot(SolverStatus.unknown),
          reason: seed,
        );
        expect(solved.isUnique, isTrue, reason: seed);
      }
    });

    test('clue removal rejects final clue sets that fail quality gates', () {
      final SlitherlinkQualityProfile profile = slitherlinkQualityProfileFor(
        width: 5,
        height: 5,
        difficulty: 'easy',
      );

      expect(
        () => removeClues(
          fullClues: List<int>.filled(25, 0),
          rng: SeededRng(Seed.fromString('slitherlink_bad_removal')),
          config: ClueRemovalConfig(
            width: 5,
            height: 5,
            timeBudget: Duration.zero,
            maxBacktrackDepth: 1,
            binarySearchFraction: 0.4,
            targetClueFraction: profile.targetClueDensity,
            maxFailedRemovals: 1,
            qualityProfile: profile,
            requireQualityGate: true,
          ),
          uniqueness: const SlitherlinkUniqueness(SlitherlinkSolver()),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Slitherlink deterministic generation has no day-long budget', () {
      final String apiSource = File('lib/src/generators/slitherlink/api.dart')
          .readAsStringSync();
      final String generatorSource = File(
        'lib/src/generators/slitherlink/generator.dart',
      ).readAsStringSync();

      expect(apiSource, isNot(contains('Duration(days: 1)')));
      expect(generatorSource, isNot(contains('Duration(days: 1)')));
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
  'fullClueHistogram',
  'revealedClueHistogram',
  'loopEdgeCount',
  'loopCoverageRatio',
  'loopTouchedRows',
  'loopTouchedCols',
  'loopBoundingBoxWidth',
  'loopBoundingBoxHeight',
  'revealedZeroRatio',
  'nonZeroRevealedClues',
  'qualityGatePassed',
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
