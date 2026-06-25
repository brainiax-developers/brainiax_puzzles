import 'dart:math' as math;
import 'dart:typed_data';

import '../generator.dart';
import '../../engine/slitherlink/line_builder.dart';
import '../../engine/slitherlink/solver.dart';
import '../../engine/slitherlink/solver_adapter.dart';
import '../../solver/solver.dart';
import '../../util/determinism.dart';
import '../../util/seeded_rng.dart';
import '../../slitherlink/slitherlink_board.dart';
import 'clues.dart';
import 'quality.dart';
import 'removal.dart';

class SlitherlinkPipelineGenerator extends PuzzleGenerator<SlitherlinkBoard> {
  const SlitherlinkPipelineGenerator();

  static const List<int> _supportedWidths = <int>[5, 6, 7, 8, 9, 10];
  static const List<int> _supportedHeights = <int>[5, 6, 7, 8, 9, 10];

  @override
  PuzzleGenerationResult<SlitherlinkBoard> generate(GeneratorContext context) {
    final int width = context.size.width;
    final int height = context.size.height;
    if (!_supportedWidths.contains(width) ||
        !_supportedHeights.contains(height)) {
      throw ArgumentError('Unsupported Slitherlink size: ${width}x$height');
    }
    if (width != height) {
      throw ArgumentError('Non-square Slitherlink sizes are not supported');
    }

    final Stopwatch stopwatch = Stopwatch()..start();
    final _DifficultyTuning tuning =
        _difficultyTunings[context.difficulty.level.toLowerCase()] ??
        _defaultTuning;
    final SlitherlinkQualityProfile qualityProfile =
        slitherlinkQualityProfileFor(
          width: width,
          height: height,
          difficulty: context.difficulty.level,
        );
    final SlitherlinkSolver solver = const SlitherlinkSolver();
    final SlitherlinkUniqueness uniqueness = SlitherlinkUniqueness(solver);
    final List<String> rejectReasons = <String>[];
    _AcceptedSlitherlinkCandidate? accepted;
    for (int attempt = 0; attempt < tuning.maxConstructionAttempts; attempt++) {
      try {
        accepted = _generateCandidate(
          width: width,
          height: height,
          difficulty: context.difficulty.level,
          seed: context.seed64 ^ (0x9e3779b97f4a7c15 * (attempt + 1)),
          verifySeed: Seed.fromString('${context.seedStr}:verify:$attempt'),
          tuning: tuning,
          qualityProfile: qualityProfile,
          solver: solver,
          uniqueness: uniqueness,
        );
        break;
      } catch (err) {
        rejectReasons.add(err.toString());
      }
    }
    if (accepted == null) {
      throw StateError(
        'Slitherlink generation exhausted quality attempts: '
        '${rejectReasons.isEmpty ? 'no candidates' : rejectReasons.last}',
      );
    }
    stopwatch.stop();

    final SlitherlinkBoard puzzle = accepted.puzzle;
    final int revealedClues = puzzle.clues.where((int? c) => c != null).length;
    final int totalCells = width * height;
    final int hiddenClues = totalCells - revealedClues;
    final Map<String, int> revealedHistogram = clueHistogram(puzzle.clues);
    final Map<String, Object?> telemetry = <String, Object?>{
      'width': width,
      'height': height,
      'difficulty': context.difficulty.level.toLowerCase(),
      'generator': 'spanning_tree_cycle_scored_v2',
      'clueDensity': totalCells == 0 ? 0.0 : revealedClues / totalCells,
      'revealedClues': revealedClues,
      'hiddenClues': hiddenClues,
      'clueHistogram': revealedHistogram,
      ...accepted.qualityMetrics.toTelemetry(),
      'speculativeSteps': accepted.solverTelemetry['speculativeSteps'] ?? 0,
      'maxDepth': accepted.solverTelemetry['maxDepth'] ?? 0,
      'localAssignments': accepted.solverTelemetry['localAssignments'] ?? 0,
      'globalAssignments': accepted.solverTelemetry['globalAssignments'] ?? 0,
      'totalAssignments': accepted.solverTelemetry['totalAssignments'] ?? 0,
      'solverStatus': accepted.solverStatus,
      'solverCalls': accepted.removal.stats.solverCalls,
      'removalMaxDepth': accepted.removal.stats.maxDepthHit,
      'removalElapsedUs': accepted.removal.stats.elapsed.inMicroseconds,
      'removedClues': accepted.removal.stats.removedClueCount,
      'removalHitTimeBudget': accepted.removal.stats.hitTimeBudget,
      'removalQualityGatePassed': accepted.removal.stats.qualityGatePassed,
      if (accepted.removal.stats.qualityRejectReason != null)
        'removalQualityRejectReason':
            accepted.removal.stats.qualityRejectReason,
      'fallbackFullClues': false,
      'timeBudgetMs': tuning.timeBudget.inMilliseconds,
      'maxBacktrackDepth': tuning.maxBacktrackDepth,
      'qualityProfile': qualityProfile.toTelemetry(),
      'qualityGatePassed': true,
      'qualityRejectReason': null,
      'qualityRejectedAttempts': rejectReasons.length,
      if (rejectReasons.isNotEmpty)
        'qualityRejectReasons': rejectReasons.take(12).toList(),
      'attempts': rejectReasons.length + 1,
      'retries': rejectReasons.length,
      'generationUs': stopwatch.elapsedMicroseconds,
      'solutionEdges': accepted.solutionEdges.toList(),
    };

    DeterminismGuard.assertNoFloatsOrDateTimes(puzzle.toJson());
    return PuzzleGenerationResult<SlitherlinkBoard>(
      board: puzzle,
      snapshot: GenerationSnapshot(telemetry: telemetry),
    );
  }
}

class _DifficultyTuning {
  const _DifficultyTuning({
    required this.timeBudget,
    required this.maxBacktrackDepth,
    required this.maxConstructionAttempts,
  });

  final Duration timeBudget;
  final int maxBacktrackDepth;
  final int maxConstructionAttempts;
}

const _DifficultyTuning _defaultTuning = _DifficultyTuning(
  timeBudget: Duration(milliseconds: 1200),
  maxBacktrackDepth: 2200,
  maxConstructionAttempts: 12,
);

final Map<String, _DifficultyTuning> _difficultyTunings =
    <String, _DifficultyTuning>{
      'easy': const _DifficultyTuning(
        timeBudget: Duration(milliseconds: 900),
        maxBacktrackDepth: 1200,
        maxConstructionAttempts: 12,
      ),
      'medium': const _DifficultyTuning(
        timeBudget: Duration(milliseconds: 1200),
        maxBacktrackDepth: 2000,
        maxConstructionAttempts: 12,
      ),
      'hard': const _DifficultyTuning(
        timeBudget: Duration(milliseconds: 1600),
        maxBacktrackDepth: 3200,
        maxConstructionAttempts: 14,
      ),
      'expert': const _DifficultyTuning(
        timeBudget: Duration(milliseconds: 2200),
        maxBacktrackDepth: 4500,
        maxConstructionAttempts: 16,
      ),
    };

_AcceptedSlitherlinkCandidate _generateCandidate({
  required int width,
  required int height,
  required String difficulty,
  required int seed,
  required int verifySeed,
  required _DifficultyTuning tuning,
  required SlitherlinkQualityProfile qualityProfile,
  required SlitherlinkSolver solver,
  required SlitherlinkUniqueness uniqueness,
}) {
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
  final SlitherlinkQualityMetrics loopMetrics =
      SlitherlinkQualityMetrics.analyze(
        width: width,
        height: height,
        solutionEdges: loop.solutionEdges,
        fullClues: fullClues,
        revealedClues: List<int?>.from(fullClues),
      );
  final String? loopRejectReason = qualityProfile.loopRejectReason(loopMetrics);
  if (loopRejectReason != null) {
    throw StateError(loopRejectReason);
  }

  final Uint8List targetEdges = Uint8List.fromList(loop.solutionEdges);
  final Uint8List solutionEdges = Uint8List.fromList(loop.solutionEdges);
  final ClueRemovalResult removal = removeClues(
    fullClues: fullClues,
    rng: SeededRng(seed ^ 0x5bf03635d8e1a1ad),
    config: ClueRemovalConfig(
      width: width,
      height: height,
      timeBudget: tuning.timeBudget,
      maxBacktrackDepth: tuning.maxBacktrackDepth,
      binarySearchFraction: 0.4,
      targetClueFraction: qualityProfile.targetClueDensity,
      maxFailedRemovals: math.max(48, width * height),
      qualityProfile: qualityProfile,
      requireQualityGate: true,
    ),
    uniqueness: uniqueness,
    outSolutionEdges: solutionEdges,
  );

  final SlitherlinkBoard puzzle = SlitherlinkBoard.empty(
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

  final SolverResult<SlitherlinkBoard> verificationResult = solver.solve(
    puzzle,
    SolverContext(
      rng: SeededRng(verifySeed),
      maxSolutions: 2,
      speculativeStepBudget: tuning.maxBacktrackDepth,
    ),
  );
  if (verificationResult.solutionStatus == SolverStatus.unknown) {
    throw StateError('solver_status_unknown');
  }
  if (!verificationResult.isUnique ||
      verificationResult.solutions.length != 1) {
    throw StateError('uniqueness_failed');
  }
  final Uint8List verifiedEdges = Uint8List.fromList(
    verificationResult.solutions.first.edges,
  );
  if (!_edgesMatch(verifiedEdges, targetEdges)) {
    throw StateError('target_loop_drift');
  }

  return _AcceptedSlitherlinkCandidate(
    puzzle: puzzle,
    solutionEdges: verifiedEdges,
    removal: removal,
    qualityMetrics: finalMetrics,
    solverTelemetry: verificationResult.telemetry,
    solverStatus: verificationResult.solutionStatus.name,
  );
}

class _AcceptedSlitherlinkCandidate {
  const _AcceptedSlitherlinkCandidate({
    required this.puzzle,
    required this.solutionEdges,
    required this.removal,
    required this.qualityMetrics,
    required this.solverTelemetry,
    required this.solverStatus,
  });

  final SlitherlinkBoard puzzle;
  final Uint8List solutionEdges;
  final ClueRemovalResult removal;
  final SlitherlinkQualityMetrics qualityMetrics;
  final Map<String, Object?> solverTelemetry;
  final String solverStatus;
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

bool slitherlinkFallbackSolveAccepted(
  SolverResult<SlitherlinkBoard> fallbackSolve,
) {
  return fallbackSolve.isUnique && fallbackSolve.solutions.isNotEmpty;
}

bool slitherlinkRetrySolveAccepted(
  SolverResult<SlitherlinkBoard> retrySolve,
  List<int> targetEdges,
) {
  return retrySolve.isUnique &&
      retrySolve.solutions.isNotEmpty &&
      _edgesMatch(retrySolve.solutions.first.edges, targetEdges);
}
