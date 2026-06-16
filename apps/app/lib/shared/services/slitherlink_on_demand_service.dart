import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

class SlitherlinkOnDemandService {
  SlitherlinkOnDemandService();

  Future<core.GeneratedPuzzle<core.SlitherlinkBoard>> nextPuzzle({
    required String difficulty,
    required int width,
    required int height,
    required String seed,
    Duration timeBudget = const Duration(milliseconds: 350),
  }) async {
    final core.SlitherlinkDifficulty resolved = _parseDifficulty(difficulty);
    final int seed64 = core.Seed.fromString(seed);
    final core.GenerateSlitherlinkRequest request =
        core.GenerateSlitherlinkRequest(
          width: width,
          height: height,
          difficulty: resolved,
          seed64: seed64,
          timeBudget: timeBudget,
        );
    final core.SlitherlinkPuzzle puzzle = await core
        .generateSlitherlinkInIsolate(request);
    return _wrapPuzzle(puzzle, seed: seed, seed64: seed64);
  }

  core.GeneratedPuzzle<core.SlitherlinkBoard> _wrapPuzzle(
    core.SlitherlinkPuzzle puzzle, {
    required String seed,
    required int seed64,
  }) {
    final core.SizeOpt size = core.SizeOpt(
      id: '${puzzle.width}x${puzzle.height}',
      description: '${puzzle.width}x${puzzle.height}',
      width: puzzle.width,
      height: puzzle.height,
    );
    final core.DifficultyScore score = _scoreFromDifficulty(puzzle.difficulty);
    final Map<String, Object?> generatorTelemetry = Map<String, Object?>.from(
      puzzle.telemetry,
    );
    final Map<String, num> metrics = _difficultyMetrics(generatorTelemetry);
    final double rawScore =
        (generatorTelemetry['difficultyRawScore'] as num?)?.toDouble() ??
        score.value;
    final core.PuzzleMetadata meta = core.PuzzleMetadata(
      engineVersion: 'slitherlink_on_demand_1',
      rngId: core.SeededRng.rngId,
      size: size,
      difficulty: score,
      seedStr: seed,
      seed64: seed64,
    );
    final core.GenerationTelemetry telemetry = core.GenerationTelemetry(
      difficulty: core.DifficultyTelemetry(
        rawScore: rawScore,
        bucket: score.level,
        metrics: metrics,
      ),
      extras: <String, Object?>{
        'generator': generatorTelemetry,
        'variant': puzzle.variant.name,
        'entrances': puzzle.entrances
            .map((core.EdgeHint e) => e.toJson())
            .toList(),
      },
    );
    return core.GeneratedPuzzle<core.SlitherlinkBoard>(
      state: puzzle.toBoard(),
      meta: meta,
      telemetry: telemetry,
    );
  }

  core.SlitherlinkDifficulty _parseDifficulty(String value) {
    switch (value.toLowerCase()) {
      case 'easy':
        return core.SlitherlinkDifficulty.easy;
      case 'medium':
        return core.SlitherlinkDifficulty.medium;
      case 'hard':
        return core.SlitherlinkDifficulty.hard;
      case 'expert':
        return core.SlitherlinkDifficulty.expert;
      default:
        return core.SlitherlinkDifficulty.medium;
    }
  }

  core.DifficultyScore _scoreFromDifficulty(core.SlitherlinkDifficulty value) {
    switch (value) {
      case core.SlitherlinkDifficulty.easy:
        return const core.DifficultyScore(value: 0.35, level: 'easy');
      case core.SlitherlinkDifficulty.medium:
        return const core.DifficultyScore(value: 0.6, level: 'medium');
      case core.SlitherlinkDifficulty.hard:
        return const core.DifficultyScore(value: 0.9, level: 'hard');
      case core.SlitherlinkDifficulty.expert:
        return const core.DifficultyScore(value: 1.2, level: 'expert');
    }
  }

  Map<String, num> _difficultyMetrics(Map<String, Object?> telemetry) {
    final Object? rawMetrics = telemetry['difficultyMetrics'];
    if (rawMetrics is Map) {
      return rawMetrics.map(
        (key, value) => MapEntry(key.toString(), value as num),
      );
    }
    final Map<String, num> metrics = <String, num>{};
    for (final String key in <String>[
      'clueDensity',
      'revealedZeroRatio',
      'nonZeroRevealedClues',
      'loopEdgeCount',
      'loopCoverageRatio',
      'loopTouchedRows',
      'loopTouchedCols',
      'loopBoundingBoxWidth',
      'loopBoundingBoxHeight',
      'speculativeSteps',
      'maxDepth',
      'localAssignments',
      'globalAssignments',
      'totalAssignments',
    ]) {
      final Object? value = telemetry[key];
      if (value is num) {
        metrics[key] = value;
      }
    }
    return metrics;
  }
}

final slitherlinkOnDemandProvider = Provider<SlitherlinkOnDemandService>((ref) {
  return SlitherlinkOnDemandService();
});
