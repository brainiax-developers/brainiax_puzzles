import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../engine/slitherlink/line_builder.dart';
import '../../engine/slitherlink/solver.dart';
import '../../engine/slitherlink/solver_adapter.dart';
import '../../models/slitherlink_models.dart';
import '../../slitherlink/slitherlink_board.dart';
import '../../slitherlink/slitherlink_topology.dart';
import '../../solver/solver.dart';
import '../../util/seeded_rng.dart';
import 'clues.dart';
import 'difficulty.dart';
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
    final Duration effectiveBudget = deterministicMode
        ? const Duration(days: 1)
        : timeBudget.inMicroseconds > 0
        ? Duration(
            microseconds: math.min(
              timeBudget.inMicroseconds,
              tuning.generationTimeBudget.inMicroseconds,
            ),
          )
        : tuning.generationTimeBudget;
    final int restartBudget = math.min(maxRestarts, tuning.maxRestarts);
    final Stopwatch stopwatch = Stopwatch()..start();

    StateError? lastError;
    for (int attempt = 0; attempt < restartBudget; attempt++) {
      if (stopwatch.elapsed > effectiveBudget) {
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
          deterministicMode: deterministicMode,
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
    required bool deterministicMode,
  }) {
    final LoopSynthesisResult loop = synthesizeLoop(
      width: width,
      height: height,
      rng: SeededRng(seed ^ 0x9e3779b97f4a7c15),
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
    final ClueRemovalConfig config = ClueRemovalConfig(
      width: width,
      height: height,
      timeBudget: deterministicMode
          ? const Duration(days: 1)
          : tuning.removalTimeBudget,
      maxBacktrackDepth: tuning.solverMaxDepth,
      binarySearchFraction: tuning.binarySearchFraction,
      targetClueFraction: tuning.targetClueFraction,
      maxFailedRemovals: tuning.maxFailedRemovals,
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
    final SolverResult<SlitherlinkBoard> solverResult = _solver.solve(
      board,
      SolverContext(
        rng: SeededRng(seed ^ 0x41c64e6d),
        maxSolutions: 2,
        speculativeStepBudget: tuning.solverMaxDepth,
      ),
    );
    if (!solverResult.isUnique || solverResult.solutions.isEmpty) {
      throw StateError('Slitherlink uniqueness failed');
    }
    final SlitherlinkBoard solution = solverResult.solutions.first;
    if (!_edgesMatch(solution.edges, targetEdges)) {
      throw StateError('Generated clues drifted from target loop');
    }
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
