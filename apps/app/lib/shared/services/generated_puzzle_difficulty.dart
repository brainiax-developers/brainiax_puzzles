import 'package:puzzle_core/puzzle_core.dart' as core;

bool generatedPuzzleMatchesDifficulty(
  core.GeneratedPuzzle<dynamic> puzzle,
  core.DifficultyScore requestedDifficulty,
) {
  return puzzle.meta.difficulty.level.toLowerCase() ==
      requestedDifficulty.level.toLowerCase();
}

core.GeneratedPuzzle<dynamic> normalizeGeneratedPuzzleDifficulty({
  required core.GeneratedPuzzle<dynamic> puzzle,
  required core.DifficultyScore requestedDifficulty,
}) {
  if (generatedPuzzleMatchesDifficulty(puzzle, requestedDifficulty)) {
    return puzzle;
  }

  final core.PuzzleMetadata meta = core.PuzzleMetadata(
    engineVersion: puzzle.meta.engineVersion,
    rngId: puzzle.meta.rngId,
    size: puzzle.meta.size,
    difficulty: requestedDifficulty,
    seedStr: puzzle.meta.seedStr,
    seed64: puzzle.meta.seed64,
  );

  final core.GenerationTelemetry? telemetry = puzzle.telemetry == null
      ? null
      : core.GenerationTelemetry(
          difficulty: puzzle.telemetry!.difficulty,
          extras: <String, Object?>{
            ...puzzle.telemetry!.extras,
            'requestedDifficulty': requestedDifficulty.level,
            'measuredDifficultyLevel': puzzle.meta.difficulty.level,
            'difficultyMetadataNormalized': true,
          },
        );

  return core.GeneratedPuzzle<dynamic>(
    state: puzzle.state,
    meta: meta,
    telemetry: telemetry,
  );
}
