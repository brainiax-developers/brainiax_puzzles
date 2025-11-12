import 'dart:typed_data';

import '../generators/generator.dart';
import '../util/determinism.dart';
import '../util/seeded_rng.dart';
import 'clues.dart';
import 'loop_synthesis.dart';
import 'removal.dart';
import 'slitherlink_board.dart';
import 'slitherlink_solver.dart';
import 'solver_adapter.dart';

class SlitherlinkGenerator extends PuzzleGenerator<SlitherlinkBoard> {
  const SlitherlinkGenerator();

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
      colors: loop.colors,
      width: width,
      height: height,
      stride: loop.stride,
    );

    final SlitherlinkUniqueness uniqueness =
        SlitherlinkUniqueness(const SlitherlinkSolver());
    final Uint8List solutionEdges = Uint8List.fromList(loop.solutionEdges);
    final ClueRemovalResult removal = removeClues(
      fullClues: fullClues,
      rng: rng,
      config: ClueRemovalConfig(
        width: width,
        height: height,
        timeBudget: tuning.timeBudget,
        maxBacktrackDepth: tuning.maxBacktrackDepth,
      ),
      uniqueness: uniqueness,
      outSolutionEdges: solutionEdges,
    );

    final SlitherlinkBoard puzzle = SlitherlinkBoard.empty(
      width: width,
      height: height,
      clues: removal.clues,
    );

    stopwatch.stop();

    final Map<String, Object?> telemetry = <String, Object?>{
      'width': width,
      'height': height,
      'difficulty': context.difficulty.level.toLowerCase(),
      'generator': 'region_color',
      'revealedClues': removal.clues.where((int? c) => c != null).length,
      'loopFlipCount': loop.flipCount,
      'solverCalls': removal.stats.solverCalls,
      'removalMaxDepth': removal.stats.maxDepthHit,
      'removalElapsedUs': removal.stats.elapsed.inMicroseconds,
      'removedClues': removal.stats.removedClueCount,
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
  timeBudget: Duration(seconds: 30),
  maxBacktrackDepth: 2500,
);

final Map<String, _DifficultyTuning> _difficultyTunings = <String, _DifficultyTuning>{
  'easy': const _DifficultyTuning(
    timeBudget: Duration(seconds: 15),
    maxBacktrackDepth: 1500,
  ),
  'medium': const _DifficultyTuning(
    timeBudget: Duration(seconds: 20),
    maxBacktrackDepth: 2500,
  ),
  'hard': const _DifficultyTuning(
    timeBudget: Duration(seconds: 25),
    maxBacktrackDepth: 3500,
  ),
  'expert': const _DifficultyTuning(
    timeBudget: Duration(seconds: 30),
    maxBacktrackDepth: 4500,
  ),
};
