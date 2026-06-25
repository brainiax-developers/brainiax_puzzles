import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../engine/slitherlink/line_builder.dart';
import '../../engine/slitherlink/solver.dart';
import '../../engine/slitherlink/solver_adapter.dart';
import '../../difficulty/telemetry.dart';
import '../../models/slitherlink_models.dart';
import '../../slitherlink/slitherlink_board.dart';
import '../../slitherlink/slitherlink_difficulty.dart';
import '../../slitherlink/slitherlink_topology.dart';
import '../../solver/solver.dart';
import '../../util/seeded_rng.dart';
import 'clues.dart';
import 'difficulty.dart';
import 'quality.dart';
import 'removal.dart';

class SlitherlinkGenerator {
  SlitherlinkGenerator({SlitherlinkDifficultyProfile? profile})
    : _profile = profile ?? defaultSlitherlinkDifficultyProfile(),
      _solver = const SlitherlinkSolver(),
      _uniqueness = SlitherlinkUniqueness(const SlitherlinkSolver());

  final SlitherlinkDifficultyProfile _profile;
  final SlitherlinkSolver _solver;
  final SlitherlinkUniqueness _uniqueness;
  final math.Random _random = math.Random();
  static final Map<_FallbackKey, SlitherlinkPuzzle> _fallbackCache =
      <_FallbackKey, SlitherlinkPuzzle>{};

  Future<SlitherlinkPuzzle> generate({
    required int width,
    required int height,
    required SlitherlinkDifficulty difficulty,
    SlitherlinkVariant variant = SlitherlinkVariant.classicLoop,
    int? seed,
    Duration timeBudget = const Duration(milliseconds: 350),
    int maxRestarts = 40,
  }) async {
    final bool deterministicMode = seed != null;
    final SlitherlinkDifficultyTuning tuning = _profile.resolve(difficulty);
    final int restartBudget = math.min(maxRestarts, tuning.maxRestarts);
    final Duration effectiveBudget = _deterministicBudget(
      timeBudget,
      tuning,
      restartBudget,
    );
    final Stopwatch stopwatch = Stopwatch()..start();

    StateError? lastError;
    for (int attempt = 0; attempt < restartBudget; attempt++) {
      if (!deterministicMode && stopwatch.elapsed > effectiveBudget) {
        break;
      }
      final int attemptSeed = _resolveSeed(seed, attempt);
      try {
        final SlitherlinkPuzzle puzzle = _generateOnce(
          width: width,
          height: height,
          difficulty: difficulty,
          variant: variant,
          tuning: tuning,
          seed: attemptSeed,
          useTimeBudget: !deterministicMode,
        );
        _fallbackCache[_FallbackKey(width, height, difficulty, variant, seed)] =
            puzzle;
        return puzzle;
      } catch (err) {
        lastError = StateError(err.toString());
        continue;
      }
    }

    final SlitherlinkPuzzle? fallback =
        _fallbackCache[_FallbackKey(width, height, difficulty, variant, seed)];
    if (fallback != null) {
      return fallback;
    }
    if (lastError != null) {
      throw lastError;
    }
    throw StateError('Slitherlink generation exhausted restarts');
  }

  SlitherlinkPuzzle _generateOnce({
    required int width,
    required int height,
    required SlitherlinkDifficulty difficulty,
    required SlitherlinkVariant variant,
    required SlitherlinkDifficultyTuning tuning,
    required int seed,
    required bool useTimeBudget,
  }) {
    final SlitherlinkQualityProfile qualityProfile =
        slitherlinkQualityProfileFor(
          width: width,
          height: height,
          difficulty: difficulty.name,
        );
    final LoopSynthesisResult loop = synthesizeLoop(
      width: width,
      height: height,
      rng: SeededRng(seed ^ 0x9e3779b97f4a7c15),
      constraints: LoopSynthesisConstraints(
        minLoopEdgeCount: qualityProfile.minLoopEdgeCount,
        minTouchedRows: qualityProfile.minTouchedRows,
        minTouchedCols: qualityProfile.minTouchedCols,
        minBoundingBoxWidth: qualityProfile.minBoundingBoxWidth,
        minBoundingBoxHeight: qualityProfile.minBoundingBoxHeight,
        maxFullZeroRatio: qualityProfile.maxFullZeroRatio,
      ),
    );
    final List<int> fullClues = deriveClues(
      solutionEdges: loop.solutionEdges,
      width: width,
      height: height,
    );
    final Uint8List targetEdges = Uint8List.fromList(loop.solutionEdges);
    final Uint8List solverSolutionBuffer = Uint8List.fromList(
      loop.solutionEdges,
    );
    if (tuning.solverMaxDepth <= 0) {
      throw StateError('Slitherlink solver could not prove uniqueness');
    }
    final SlitherlinkQualityMetrics loopMetrics =
        SlitherlinkQualityMetrics.analyze(
          width: width,
          height: height,
          solutionEdges: loop.solutionEdges,
          fullClues: fullClues,
          revealedClues: List<int?>.from(fullClues),
        );
    final String? loopRejectReason = qualityProfile.loopRejectReason(
      loopMetrics,
    );
    if (loopRejectReason != null) {
      throw StateError(loopRejectReason);
    }
    final ClueRemovalConfig config = ClueRemovalConfig(
      width: width,
      height: height,
      timeBudget: tuning.removalTimeBudget,
      maxBacktrackDepth: tuning.solverMaxDepth,
      binarySearchFraction: tuning.binarySearchFraction,
      targetClueFraction: qualityProfile.targetClueDensity,
      maxFailedRemovals: math.max(tuning.maxFailedRemovals, width * height),
      qualityProfile: qualityProfile,
      requireQualityGate: true,
      useTimeBudget: useTimeBudget,
    );
    final ClueRemovalResult removal = removeClues(
      fullClues: fullClues,
      rng: SeededRng(seed ^ 0x5bf03635d8e1a1ad),
      config: config,
      uniqueness: _uniqueness,
      outSolutionEdges: solverSolutionBuffer,
    );
    final SlitherlinkBoard board = SlitherlinkBoard.empty(
      width: width,
      height: height,
      clues: removal.clues,
    );
    final SlitherlinkQualityMetrics finalMetrics =
        SlitherlinkQualityMetrics.analyze(
          width: width,
          height: height,
          solutionEdges: targetEdges,
          fullClues: fullClues,
          revealedClues: removal.clues,
        );
    final String? finalRejectReason = qualityProfile.finalRejectReason(
      finalMetrics,
    );
    if (finalRejectReason != null) {
      throw StateError(finalRejectReason);
    }
    final SolverResult<SlitherlinkBoard> solverResult = _solver.solve(
      board,
      SolverContext(
        rng: SeededRng(seed ^ 0x41c64e6d),
        maxSolutions: 2,
        speculativeStepBudget: tuning.solverMaxDepth,
      ),
    );
    if (solverResult.solutionStatus == SolverStatus.unknown) {
      throw StateError('Slitherlink solver could not prove uniqueness');
    }
    if (!solverResult.isUnique || solverResult.solutions.length != 1) {
      throw StateError('Slitherlink uniqueness failed');
    }
    final SlitherlinkBoard solution = solverResult.solutions.first;
    if (!_edgesMatch(solution.edges, targetEdges)) {
      throw StateError('Generated clues drifted from target loop');
    }
    final Map<String, Object?> generatorTelemetry = _buildGeneratorTelemetry(
      width: width,
      height: height,
      difficulty: difficulty,
      qualityProfile: qualityProfile,
      qualityMetrics: finalMetrics,
      removal: removal,
      solverResult: solverResult,
    );
    final DifficultyTelemetry difficultyTelemetry =
        const SlitherlinkDifficultyScorer().score(
          puzzle: board,
          solution: solution,
          context: DifficultyContext(
            generatorTelemetry: generatorTelemetry,
            solverTelemetry: solverResult.telemetry,
          ),
        );
    final List<EdgeHint> entrances = _computeEntrances(
      variant: variant,
      solution: solution,
      seed: seed,
    );
    final SlitherlinkPuzzle puzzle = SlitherlinkPuzzle(
      width: width,
      height: height,
      clues: removal.clues,
      variant: variant,
      entrances: entrances,
      seed: seed,
      difficulty: difficulty,
      telemetry: <String, Object?>{
        ...generatorTelemetry,
        'difficultyRawScore': difficultyTelemetry.rawScore,
        'difficultyMetrics': difficultyTelemetry.metrics,
      },
    );
    return puzzle;
  }

  List<EdgeHint> _computeEntrances({
    required SlitherlinkVariant variant,
    required SlitherlinkBoard solution,
    required int seed,
  }) {
    if (variant == SlitherlinkVariant.classicLoop) {
      return const <EdgeHint>[];
    }
    final SlitherlinkTopology topology = solution.topology;
    final Map<Direction, List<EdgeHint>> buckets = <Direction, List<EdgeHint>>{
      Direction.north: <EdgeHint>[],
      Direction.south: <EdgeHint>[],
      Direction.east: <EdgeHint>[],
      Direction.west: <EdgeHint>[],
    };
    for (int edge = 0; edge < solution.edges.length; edge++) {
      if (solution.edges[edge] != SlitherlinkBoard.edgeOn) {
        continue;
      }
      final EdgeHint? hint = _edgeHintForBoundaryEdge(edge, topology);
      if (hint != null) {
        buckets[hint.dir]!.add(hint);
      }
    }
    final List<List<Direction>> pairs = <List<Direction>>[
      <Direction>[Direction.north, Direction.south],
      <Direction>[Direction.west, Direction.east],
    ];
    final SeededRng pickRng = SeededRng(seed ^ 0x1234abcd);
    for (final List<Direction> pair in pairs) {
      final List<EdgeHint> a = buckets[pair[0]]!;
      final List<EdgeHint> b = buckets[pair[1]]!;
      if (a.isEmpty || b.isEmpty) {
        continue;
      }
      final EdgeHint first = a[pickRng.nextIntInRange(a.length)];
      final EdgeHint second = b[pickRng.nextIntInRange(b.length)];
      return <EdgeHint>[first, second];
    }
    return const <EdgeHint>[];
  }

  EdgeHint? _edgeHintForBoundaryEdge(int edge, SlitherlinkTopology topology) {
    if (edge < topology.horizontalEdgeCount) {
      final int row = edge ~/ topology.width;
      final int col = edge % topology.width;
      if (row == 0) {
        return EdgeHint(x: col, y: row, dir: Direction.north);
      }
      if (row == topology.height) {
        return EdgeHint(x: col, y: row, dir: Direction.south);
      }
    } else {
      final int idx = edge - topology.horizontalEdgeCount;
      final int stride = topology.width + 1;
      final int row = idx ~/ stride;
      final int col = idx % stride;
      if (col == 0) {
        return EdgeHint(x: col, y: row, dir: Direction.west);
      }
      if (col == topology.width) {
        return EdgeHint(x: col, y: row, dir: Direction.east);
      }
    }
    return null;
  }

  int _resolveSeed(int? explicitSeed, int attempt) {
    final int salt = 0x9e3779b97f4a7c15 * (attempt + 1);
    if (explicitSeed != null) {
      return (explicitSeed ^ salt) & 0xffffffffffffffff;
    }
    final int rnd =
        (_random.nextInt(0x7fffffff) << 17) ^ _random.nextInt(0x7fffffff);
    final String signature = 'slitherlink:$rnd:$salt';
    return Seed.fromString(signature);
  }
}

Duration _deterministicBudget(
  Duration requested,
  SlitherlinkDifficultyTuning tuning,
  int restartBudget,
) {
  final int perAttemptUs = math.max(
    requested.inMicroseconds,
    tuning.generationTimeBudget.inMicroseconds +
        tuning.removalTimeBudget.inMicroseconds,
  );
  return Duration(microseconds: perAttemptUs * math.max(1, restartBudget));
}

Map<String, Object?> _buildGeneratorTelemetry({
  required int width,
  required int height,
  required SlitherlinkDifficulty difficulty,
  required SlitherlinkQualityProfile qualityProfile,
  required SlitherlinkQualityMetrics qualityMetrics,
  required ClueRemovalResult removal,
  required SolverResult<SlitherlinkBoard> solverResult,
}) {
  final int revealedClues = qualityMetrics.revealedClues
      .where((int? clue) => clue != null)
      .length;
  final int totalCells = width * height;
  return <String, Object?>{
    'width': width,
    'height': height,
    'difficulty': difficulty.name,
    'generator': 'spanning_tree_cycle_scored_v2',
    'revealedClues': revealedClues,
    'hiddenClues': totalCells - revealedClues,
    'clueHistogram': qualityMetrics.revealedClueHistogram,
    ...qualityMetrics.toTelemetry(),
    'solverStatus': solverResult.solutionStatus.name,
    'solutionCount': solverResult.solutions.length,
    'speculativeSteps': solverResult.telemetry['speculativeSteps'] ?? 0,
    'maxDepth': solverResult.telemetry['maxDepth'] ?? 0,
    'localAssignments': solverResult.telemetry['localAssignments'] ?? 0,
    'globalAssignments': solverResult.telemetry['globalAssignments'] ?? 0,
    'totalAssignments': solverResult.telemetry['totalAssignments'] ?? 0,
    'solverTelemetry': solverResult.telemetry,
    'solverCalls': removal.stats.solverCalls,
    'removalMaxDepth': removal.stats.maxDepthHit,
    'removedClues': removal.stats.removedClueCount,
    'removalHitTimeBudget': removal.stats.hitTimeBudget,
    'removalQualityGatePassed': removal.stats.qualityGatePassed,
    if (removal.stats.qualityRejectReason != null)
      'removalQualityRejectReason': removal.stats.qualityRejectReason,
    'qualityProfile': qualityProfile.toTelemetry(),
    'qualityGatePassed': true,
    'qualityRejectReason': null,
  };
}

class GenerateSlitherlinkRequest {
  final int width;
  final int height;
  final SlitherlinkDifficulty difficulty;
  final SlitherlinkVariant variant;
  final int? seed64;
  final Duration timeBudget;
  final int maxRestarts;

  const GenerateSlitherlinkRequest({
    required this.width,
    required this.height,
    required this.difficulty,
    this.variant = SlitherlinkVariant.classicLoop,
    this.seed64,
    this.timeBudget = const Duration(milliseconds: 350),
    this.maxRestarts = 40,
  });
}

Future<SlitherlinkPuzzle> generateSlitherlinkInIsolate(
  GenerateSlitherlinkRequest request,
) {
  return Isolate.run(() {
    final SlitherlinkGenerator generator = SlitherlinkGenerator();
    return generator.generate(
      width: request.width,
      height: request.height,
      difficulty: request.difficulty,
      variant: request.variant,
      seed: request.seed64,
      timeBudget: request.timeBudget,
      maxRestarts: request.maxRestarts,
    );
  });
}

class _FallbackKey {
  final int width;
  final int height;
  final SlitherlinkDifficulty difficulty;
  final SlitherlinkVariant variant;
  final int? seed64;

  const _FallbackKey(
    this.width,
    this.height,
    this.difficulty,
    this.variant,
    this.seed64,
  );

  @override
  bool operator ==(Object other) {
    return other is _FallbackKey &&
        other.width == width &&
        other.height == height &&
        other.difficulty == difficulty &&
        other.variant == variant &&
        other.seed64 == seed64;
  }

  @override
  int get hashCode => Object.hash(width, height, difficulty, variant, seed64);
}

bool _edgesMatch(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
