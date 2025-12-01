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
import 'removal.dart';

class SlitherlinkPipelineGenerator extends PuzzleGenerator<SlitherlinkBoard> {
  const SlitherlinkPipelineGenerator();

  static const List<int> _supportedWidths = <int>[5, 6, 7, 8, 9, 10];
  static const List<int> _supportedHeights = <int>[5, 6, 7, 8, 9, 10];

  @override
  PuzzleGenerationResult<SlitherlinkBoard> generate(GeneratorContext context) {
    final int width = context.size.width;
    final int height = context.size.height;
    if (!_supportedWidths.contains(width) || !_supportedHeights.contains(height)) {
      throw ArgumentError('Unsupported Slitherlink size: ${width}x$height');
    }
    if (width != height) {
      throw ArgumentError('Non-square Slitherlink sizes are not supported');
    }

    final Stopwatch stopwatch = Stopwatch()..start();
    final SeededRng rng = context.rng;
    final _DifficultyTuning tuning =
        _difficultyTunings[context.difficulty.level.toLowerCase()] ?? _defaultTuning;

    final LoopSynthesisResult loop = synthesizeLoop(
      width: width,
      height: height,
      rng: rng,
    );

    final List<int> fullClues = deriveClues(
      solutionEdges: loop.solutionEdges,
      width: width,
      height: height,
    );

    final SlitherlinkSolver solver = const SlitherlinkSolver();
    final SlitherlinkUniqueness uniqueness = SlitherlinkUniqueness(solver);
    final Uint8List targetEdges = Uint8List.fromList(loop.solutionEdges);
    Uint8List solutionEdges = Uint8List.fromList(loop.solutionEdges);
    final ClueRemovalResult removal = removeClues(
      fullClues: fullClues,
      rng: rng,
      config: ClueRemovalConfig(
        width: width,
        height: height,
        timeBudget: tuning.timeBudget,
        maxBacktrackDepth: tuning.maxBacktrackDepth,
        binarySearchFraction: 0.4,
        targetClueFraction: 0.55,
        maxFailedRemovals: math.max(16, width * height ~/ 2),
      ),
      uniqueness: uniqueness,
      outSolutionEdges: solutionEdges,
    );

    SlitherlinkBoard puzzle = SlitherlinkBoard.empty(
      width: width,
      height: height,
      clues: removal.clues,
    );

    final SolverResult<SlitherlinkBoard> verificationResult = solver.solve(
      puzzle,
      SolverContext(
        rng: SeededRng(Seed.fromString('${context.seedStr}:verify')),
        maxSolutions: 2,
      ),
    );

    bool fallbackFullClues = false;
    if (!verificationResult.isUnique) {
      fallbackFullClues = true;
      puzzle = SlitherlinkBoard.empty(
        width: width,
        height: height,
        clues: List<int?>.from(fullClues),
      );
      final SolverResult<SlitherlinkBoard> fallbackSolve = solver.solve(
        puzzle,
        SolverContext(
          rng: SeededRng(Seed.fromString('${context.seedStr}:fallback')),
          maxSolutions: 2,
        ),
      );
      if (fallbackSolve.solutions.isNotEmpty) {
        solutionEdges = Uint8List.fromList(fallbackSolve.solutions.first.edges);
      } else {
        solutionEdges = Uint8List.fromList(loop.solutionEdges);
      }
    } else if (verificationResult.solutions.isNotEmpty) {
      solutionEdges = Uint8List.fromList(verificationResult.solutions.first.edges);
      if (!_edgesMatch(solutionEdges, targetEdges)) {
        fallbackFullClues = true;
        puzzle = SlitherlinkBoard.empty(
          width: width,
          height: height,
          clues: List<int?>.from(fullClues),
        );
        final SolverResult<SlitherlinkBoard> retrySolve = solver.solve(
          puzzle,
          SolverContext(
            rng: SeededRng(Seed.fromString('${context.seedStr}:retry')),
            maxSolutions: 2,
          ),
        );
        if (retrySolve.solutions.isEmpty ||
            !_edgesMatch(retrySolve.solutions.first.edges, targetEdges)) {
          throw StateError('Slitherlink generator drifted from target loop');
        }
        solutionEdges =
            Uint8List.fromList(retrySolve.solutions.first.edges);
      }
    }

    stopwatch.stop();

    final int revealedClues =
        puzzle.clues.where((int? c) => c != null).length;
    final int removedClues = fallbackFullClues ? 0 : removal.stats.removedClueCount;
    final Map<String, Object?> telemetry = <String, Object?>{
      'width': width,
      'height': height,
      'difficulty': context.difficulty.level.toLowerCase(),
      'generator': 'region_color',
      'revealedClues': revealedClues,
      'loopEdgeCount': loop.loopLength,
      'solverCalls': removal.stats.solverCalls,
      'removalMaxDepth': removal.stats.maxDepthHit,
      'removalElapsedUs': removal.stats.elapsed.inMicroseconds,
      'removedClues': removedClues,
      'removalHitTimeBudget': removal.stats.hitTimeBudget,
      'fallbackFullClues': fallbackFullClues,
      'timeBudgetMs': tuning.timeBudget.inMilliseconds,
      'maxBacktrackDepth': tuning.maxBacktrackDepth,
      'generationUs': stopwatch.elapsedMicroseconds,
      'solutionEdges': solutionEdges.toList(),
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
  });

  final Duration timeBudget;
  final int maxBacktrackDepth;
}

const _DifficultyTuning _defaultTuning = _DifficultyTuning(
  timeBudget: Duration(seconds: 12),
  maxBacktrackDepth: 2200,
);

final Map<String, _DifficultyTuning> _difficultyTunings = <String, _DifficultyTuning>{
  'easy': const _DifficultyTuning(
    timeBudget: Duration(seconds: 5),
    maxBacktrackDepth: 1200,
  ),
  'medium': const _DifficultyTuning(
    timeBudget: Duration(seconds: 8),
    maxBacktrackDepth: 2000,
  ),
  'hard': const _DifficultyTuning(
    timeBudget: Duration(seconds: 12),
    maxBacktrackDepth: 3200,
  ),
  'expert': const _DifficultyTuning(
    timeBudget: Duration(seconds: 16),
    maxBacktrackDepth: 4500,
  ),
};

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
