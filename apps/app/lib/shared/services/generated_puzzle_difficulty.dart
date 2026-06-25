import 'package:puzzle_core/puzzle_core.dart' as core;

class GeneratedPuzzleDifficultySnapshot {
  const GeneratedPuzzleDifficultySnapshot({
    required this.measuredDifficulty,
    required this.displayedDifficulty,
    required this.requestedDifficulty,
    required this.difficultyMismatch,
    required this.displayedDifficultyOverridden,
  });

  final core.DifficultyScore measuredDifficulty;
  final core.DifficultyScore displayedDifficulty;
  final core.DifficultyScore? requestedDifficulty;
  final bool difficultyMismatch;
  final bool displayedDifficultyOverridden;
}

bool generatedPuzzleMatchesDifficulty<T>(
  core.GeneratedPuzzle<T> puzzle,
  core.DifficultyScore requestedDifficulty,
) {
  return !generatedPuzzleDifficultySnapshot(
    puzzle: puzzle,
    requestedDifficulty: requestedDifficulty,
  ).difficultyMismatch;
}

GeneratedPuzzleDifficultySnapshot generatedPuzzleDifficultySnapshot<T>({
  required core.GeneratedPuzzle<T> puzzle,
  core.DifficultyScore? requestedDifficulty,
  bool overrideDisplayedDifficulty = false,
  core.DifficultyScore? displayedDifficultyOverride,
}) {
  final core.DifficultyScore measuredDifficulty =
      _measuredGeneratedPuzzleDifficulty(puzzle);
  final core.DifficultyScore? effectiveRequestedDifficulty =
      requestedDifficulty ?? _requestedDifficultyFromTelemetry(puzzle);
  final bool difficultyMismatch =
      effectiveRequestedDifficulty != null &&
      !_difficultyLevelsMatch(
        measuredDifficulty.level,
        effectiveRequestedDifficulty.level,
      );
  final bool displayedDifficultyOverridden =
      overrideDisplayedDifficulty && effectiveRequestedDifficulty != null;
  final core.DifficultyScore requestedDisplayDifficulty =
      effectiveRequestedDifficulty ?? measuredDifficulty;
  final core.DifficultyScore displayedDifficulty = displayedDifficultyOverridden
      ? displayedDifficultyOverride ?? requestedDisplayDifficulty
      : measuredDifficulty;

  return GeneratedPuzzleDifficultySnapshot(
    measuredDifficulty: measuredDifficulty,
    displayedDifficulty: displayedDifficulty,
    requestedDifficulty: effectiveRequestedDifficulty,
    difficultyMismatch: difficultyMismatch,
    displayedDifficultyOverridden: displayedDifficultyOverridden,
  );
}

String generatedPuzzleDifficultyDebugFields<T>({
  required core.GeneratedPuzzle<T> puzzle,
  core.DifficultyScore? requestedDifficulty,
}) {
  final GeneratedPuzzleDifficultySnapshot snapshot =
      generatedPuzzleDifficultySnapshot(
        puzzle: puzzle,
        requestedDifficulty: requestedDifficulty,
      );
  return 'requestedDifficulty='
      '${snapshot.requestedDifficulty?.level ?? 'unknown'} '
      'measuredDifficulty=${snapshot.measuredDifficulty.level} '
      'displayedDifficulty=${snapshot.displayedDifficulty.level} '
      'difficultyMismatch=${snapshot.difficultyMismatch}';
}

core.GeneratedPuzzle<T> normalizeGeneratedPuzzleDifficulty<T>({
  required core.GeneratedPuzzle<T> puzzle,
  required core.DifficultyScore requestedDifficulty,
  bool overrideDisplayedDifficulty = false,
  Map<String, Object?> telemetryExtras = const <String, Object?>{},
}) {
  final GeneratedPuzzleDifficultySnapshot snapshot =
      generatedPuzzleDifficultySnapshot(
        puzzle: puzzle,
        requestedDifficulty: requestedDifficulty,
        overrideDisplayedDifficulty: overrideDisplayedDifficulty,
      );
  final core.PuzzleMetadata meta = core.PuzzleMetadata(
    engineVersion: puzzle.meta.engineVersion,
    rngId: puzzle.meta.rngId,
    size: puzzle.meta.size,
    difficulty: snapshot.displayedDifficulty,
    seedStr: puzzle.meta.seedStr,
    seed64: puzzle.meta.seed64,
  );
  final core.GenerationTelemetry telemetry = core.GenerationTelemetry(
    difficulty:
        puzzle.telemetry?.difficulty ??
        core.DifficultyTelemetry(
          rawScore: snapshot.measuredDifficulty.value,
          bucket: snapshot.measuredDifficulty.level,
          metrics: const <String, num>{},
        ),
    extras: <String, Object?>{
      ...?puzzle.telemetry?.extras,
      'requestedDifficulty': requestedDifficulty.level,
      'requestedDifficultyValue': requestedDifficulty.value,
      'measuredDifficulty': snapshot.measuredDifficulty.level,
      'measuredDifficultyLevel': snapshot.measuredDifficulty.level,
      'measuredDifficultyValue': snapshot.measuredDifficulty.value,
      'displayedDifficulty': snapshot.displayedDifficulty.level,
      'displayedDifficultyValue': snapshot.displayedDifficulty.value,
      'difficultyMismatch': snapshot.difficultyMismatch,
      'difficultyDisplayedFromRequested':
          snapshot.displayedDifficultyOverridden,
      'difficultyMetadataNormalized': true,
      ...telemetryExtras,
    },
  );

  return core.GeneratedPuzzle<T>(
    state: puzzle.state,
    meta: meta,
    telemetry: telemetry,
  );
}

core.DifficultyScore _measuredGeneratedPuzzleDifficulty<T>(
  core.GeneratedPuzzle<T> puzzle,
) {
  final core.GenerationTelemetry? telemetry = puzzle.telemetry;
  final String telemetryBucket = telemetry?.difficulty.bucket.trim() ?? '';
  if (telemetryBucket.isNotEmpty &&
      telemetryBucket.toLowerCase() != 'pending') {
    return core.DifficultyScore(
      value: telemetry!.difficulty.rawScore,
      level: telemetryBucket,
    );
  }
  return puzzle.meta.difficulty;
}

core.DifficultyScore? _requestedDifficultyFromTelemetry<T>(
  core.GeneratedPuzzle<T> puzzle,
) {
  final Object? rawLevel = puzzle.telemetry?.extras['requestedDifficulty'];
  if (rawLevel is! String || rawLevel.trim().isEmpty) {
    return null;
  }
  final Object? rawValue = puzzle.telemetry?.extras['requestedDifficultyValue'];
  return core.DifficultyScore(
    value: rawValue is num ? rawValue.toDouble() : puzzle.meta.difficulty.value,
    level: rawLevel,
  );
}

bool _difficultyLevelsMatch(String left, String right) {
  return left.trim().toLowerCase() == right.trim().toLowerCase();
}
