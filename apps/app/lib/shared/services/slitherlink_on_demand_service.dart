import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

class SlitherlinkOnDemandService {
  SlitherlinkOnDemandService();

  Future<core.GeneratedPuzzle<core.SlitherlinkBoard>> nextPuzzle({
    required String difficulty,
    required int width,
    required int height,
    Duration timeBudget = const Duration(milliseconds: 350),
  }) async {
    final core.SlitherlinkDifficulty resolved = _parseDifficulty(difficulty);
    final core.GenerateSlitherlinkRequest request =
        core.GenerateSlitherlinkRequest(
      width: width,
      height: height,
      difficulty: resolved,
      timeBudget: timeBudget,
    );
    final core.SlitherlinkPuzzle puzzle =
        await core.generateSlitherlinkInIsolate(
      request,
    );
    return _wrapPuzzle(puzzle);
  }

  core.GeneratedPuzzle<core.SlitherlinkBoard> _wrapPuzzle(
    core.SlitherlinkPuzzle puzzle,
  ) {
    final core.SizeOpt size = core.SizeOpt(
      id: '${puzzle.width}x${puzzle.height}',
      description: '${puzzle.width}x${puzzle.height}',
      width: puzzle.width,
      height: puzzle.height,
    );
    final core.DifficultyScore score = _scoreFromDifficulty(puzzle.difficulty);
    final int seed64 = puzzle.seed ?? core.Seed.fromString('${puzzle.width}x${puzzle.height}:${score.level}');
    final core.PuzzleMetadata meta = core.PuzzleMetadata(
      engineVersion: 'slitherlink_on_demand_1',
      rngId: core.SeededRng.rngId,
      size: size,
      difficulty: score,
      seedStr: 'slitherlink:$seed64',
      seed64: seed64,
    );
    final core.GenerationTelemetry telemetry = core.GenerationTelemetry(
      difficulty: core.DifficultyTelemetry(
        rawScore: score.value,
        bucket: score.level,
        metrics: const <String, num>{},
      ),
      extras: <String, Object?>{
        'variant': puzzle.variant.name,
        'entrances':
            puzzle.entrances.map((core.EdgeHint e) => e.toJson()).toList(),
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
}

final slitherlinkOnDemandProvider =
    Provider<SlitherlinkOnDemandService>((ref) {
  return SlitherlinkOnDemandService();
});
