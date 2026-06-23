import 'package:app/shared/services/generated_puzzle_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

void main() {
  test('preserves measured difficulty and records mismatch telemetry', () {
    final core.GeneratedPuzzle<core.StubPuzzleState> puzzle = _stubPuzzle(
      metaDifficulty: 'easy',
      telemetryDifficulty: 'hard',
      telemetryRawScore: 0.9,
    );

    final normalized = normalizeGeneratedPuzzleDifficulty(
      puzzle: puzzle,
      requestedDifficulty: const core.DifficultyScore(
        value: 0.3,
        level: 'easy',
      ),
    );

    expect(normalized.meta.difficulty.level, equals('hard'));
    expect(normalized.telemetry?.extras['requestedDifficulty'], equals('easy'));
    expect(normalized.telemetry?.extras['measuredDifficulty'], equals('hard'));
    expect(normalized.telemetry?.extras['displayedDifficulty'], equals('hard'));
    expect(normalized.telemetry?.extras['difficultyMismatch'], isTrue);
  });

  test('can explicitly override displayed difficulty when requested', () {
    final core.GeneratedPuzzle<core.StubPuzzleState> puzzle = _stubPuzzle(
      metaDifficulty: 'hard',
      telemetryDifficulty: 'hard',
      telemetryRawScore: 0.9,
    );

    final normalized = normalizeGeneratedPuzzleDifficulty(
      puzzle: puzzle,
      requestedDifficulty: const core.DifficultyScore(
        value: 0.3,
        level: 'easy',
      ),
      overrideDisplayedDifficulty: true,
    );

    expect(normalized.meta.difficulty.level, equals('easy'));
    expect(normalized.telemetry?.extras['measuredDifficulty'], equals('hard'));
    expect(normalized.telemetry?.extras['displayedDifficulty'], equals('easy'));
    expect(
      normalized.telemetry?.extras['difficultyDisplayedFromRequested'],
      isTrue,
    );
  });
}

core.GeneratedPuzzle<core.StubPuzzleState> _stubPuzzle({
  required String metaDifficulty,
  required String telemetryDifficulty,
  required double telemetryRawScore,
}) {
  return core.GeneratedPuzzle<core.StubPuzzleState>(
    state: const core.StubPuzzleState(
      id: 'difficulty-test',
      data: <String, dynamic>{},
    ),
    meta: core.PuzzleMetadata(
      engineVersion: 'test',
      rngId: core.SeededRng.rngId,
      size: const core.SizeOpt(
        id: '9x9',
        description: '9x9',
        width: 9,
        height: 9,
      ),
      difficulty: core.DifficultyScore(
        value: metaDifficulty == 'hard' ? 0.9 : 0.3,
        level: metaDifficulty,
      ),
      seedStr: 'difficulty-test',
      seed64: core.Seed.fromString('difficulty-test'),
    ),
    telemetry: core.GenerationTelemetry(
      difficulty: core.DifficultyTelemetry(
        rawScore: telemetryRawScore,
        bucket: telemetryDifficulty,
        metrics: const <String, num>{},
      ),
      extras: const <String, Object?>{},
    ),
  );
}
