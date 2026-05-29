import 'dart:isolate';
import 'dart:developer' as developer;
import 'dart:math' as math;

import '../../api_types.dart';
import '../../difficulty/difficulty_config.dart';
import '../../difficulty/telemetry.dart';
import '../../generators/generator.dart';
import '../../util/seeded_rng.dart';
import '../../kakuro/kakuro_board.dart';
import '../../kakuro/kakuro_difficulty.dart';
import '../../kakuro/kakuro_generator.dart';
import 'models.dart';

class KakuroPuzzleGenerator {
  KakuroPuzzleGenerator({
    KakuroGenerator? generator,
    KakuroDifficultyScorer? scorer,
    DifficultyBucketConfig? difficultyConfig,
  }) : _generator = generator ?? const KakuroGenerator(),
       _difficultyScorer = scorer ?? const KakuroDifficultyScorer(),
       _difficultyConfig =
           difficultyConfig ??
           const DifficultyConfigLoader().loadSync(
             'assets/kakuro_difficulty_thresholds.json',
           );

  final KakuroGenerator _generator;
  final KakuroDifficultyScorer _difficultyScorer;
  final DifficultyBucketConfig _difficultyConfig;

  KakuroPuzzle generateSync(GenerateKakuroRequest request) {
    final DateTime startedAt = DateTime.now();
    final Stopwatch wall = Stopwatch()..start();
    final int baseSeed = request.seed ?? DateTime.now().microsecondsSinceEpoch;
    Object? lastError;
    final List<Map<String, Object?>> attemptLog = <Map<String, Object?>>[];

    for (int restart = 0; restart < request.maxRestarts; restart++) {
      final Duration elapsed = wall.elapsed;
      final Duration remaining = request.timeBudget - elapsed;
      if (remaining.isNegative || remaining.inMilliseconds <= 0) {
        break;
      }

      final int attemptSeed =
          (baseSeed + restart * 0x9e3779b97f4a7c15) & 0xffffffffffffffff;
      final Stopwatch attemptWatch = Stopwatch()..start();
      try {
        final KakuroPuzzle puzzle = _attempt(
          request: request,
          attemptSeed: attemptSeed,
          restartIndex: restart,
          elapsedBeforeAttempt: wall.elapsed,
          timeLimitOverride: remaining,
        );
        attemptWatch.stop();
        attemptLog.add(<String, Object?>{
          'seed': attemptSeed,
          'durationMs': attemptWatch.elapsedMilliseconds,
          'restart': restart,
          'status': 'success',
        });
        wall.stop();
        _logGenerationSummary(
          request: request,
          startedAt: startedAt,
          totalElapsed: wall.elapsed,
          baseSeed: baseSeed,
          attempts: attemptLog,
          result: puzzle,
        );
        return puzzle;
      } catch (err) {
        attemptWatch.stop();
        lastError = err;
        attemptLog.add(<String, Object?>{
          'seed': attemptSeed,
          'durationMs': attemptWatch.elapsedMilliseconds,
          'restart': restart,
          'status': 'error',
          'error': err.toString(),
        });
      }
    }

    wall.stop();
    _logGenerationSummary(
      request: request,
      startedAt: startedAt,
      totalElapsed: wall.elapsed,
      baseSeed: baseSeed,
      attempts: attemptLog,
      result: null,
    );

    throw GenerationFailure(
      message:
          'Unable to generate Kakuro puzzle within bounded attempts/budget',
      attempts: attemptLog.length,
      elapsed: wall.elapsed,
      baseSeed: baseSeed,
      lastError: lastError,
      context: <String, Object?>{
        'difficulty': request.difficulty,
        'width': request.width,
        'height': request.height,
        'maxRestarts': request.maxRestarts,
        'timeBudgetMs': request.timeBudget.inMilliseconds,
      },
    );
  }

  KakuroPuzzle _attempt({
    required GenerateKakuroRequest request,
    required int attemptSeed,
    required int restartIndex,
    required Duration elapsedBeforeAttempt,
    required Duration timeLimitOverride,
  }) {
    final SeededRng rng = SeededRng(attemptSeed);
    final context = GeneratorContext(
      rng: rng,
      seedStr: attemptSeed.toRadixString(16),
      seed64: attemptSeed,
      size: SizeOpt(
        id: '${request.width}x${request.height}',
        description: '${request.width}x${request.height}',
        width: request.width,
        height: request.height,
      ),
      difficulty: DifficultyRequest(level: request.difficulty),
    );

    // Respect the request's remaining time budget by applying a stricter cap.
    final Duration hardCap = timeLimitOverride <= Duration.zero
        ? const Duration(milliseconds: 250)
        : timeLimitOverride;
    final KakuroGenerator tunedGenerator = _generator.copyWith(
      hardTimeLimit: hardCap,
    );

    final Stopwatch attemptWatch = Stopwatch()..start();
    final generation = tunedGenerator.generate(context);
    attemptWatch.stop();

    final KakuroBoard board = generation.board;
    final DifficultyTelemetry difficultyTelemetry = _difficultyScorer.score(
      puzzle: board,
      solution: board,
      context: DifficultyContext(
        generatorTelemetry: generation.snapshot.telemetry,
        solverTelemetry: Map<String, Object?>.from(
          generation.snapshot.telemetry['solverTelemetry'] as Map? ?? const {},
        ),
      ),
    );
    final String bucket = _difficultyConfig.bucketFor(
      difficultyTelemetry.rawScore,
    );
    final Map<String, Object?> combinedTelemetry = Map<String, Object?>.from(
      generation.snapshot.telemetry,
    );
    combinedTelemetry['restartIndex'] = restartIndex;
    combinedTelemetry['elapsedBeforeAttemptMs'] =
        elapsedBeforeAttempt.inMilliseconds;
    combinedTelemetry['attemptDurationMs'] = attemptWatch.elapsedMilliseconds;
    combinedTelemetry['seed'] = attemptSeed.toString();
    combinedTelemetry['wallTimeBudgetMs'] = math.min(
      hardCap.inMilliseconds,
      request.timeBudget.inMilliseconds,
    );
    combinedTelemetry['strategy'] = request.strategy.name;

    return KakuroPuzzle(
      board: board,
      difficultyBucket: bucket,
      telemetry: combinedTelemetry,
      difficultyTelemetry: difficultyTelemetry,
      seed: attemptSeed,
      strategy: request.strategy,
      timeToGenerate: elapsedBeforeAttempt + attemptWatch.elapsed,
      restartCount: restartIndex,
    );
  }

  void _logGenerationSummary({
    required GenerateKakuroRequest request,
    required DateTime startedAt,
    required Duration totalElapsed,
    required int baseSeed,
    required List<Map<String, Object?>> attempts,
    required KakuroPuzzle? result,
  }) {
    final String status = result != null ? 'success' : 'failure';
    final String puzzleId = result != null
        ? '${result.seed}:${result.difficultyBucket}'
        : 'none';
    final String attemptSummary = attempts
        .map((Map<String, Object?> attempt) {
          final Object? restart = attempt['restart'];
          final Object? duration = attempt['durationMs'];
          final Object? attemptStatus = attempt['status'];
          return 'r$restart:${attemptStatus ?? 'n/a'}:${duration ?? '-'}ms';
        })
        .join(' ');

    developer.log(
      '[KakuroGen] $status '
      'difficulty=${request.difficulty} '
      'size=${request.width}x${request.height} '
      'seed=$baseSeed '
      'puzzleId=$puzzleId '
      'attempts=${attempts.length} '
      'elapsedMs=${totalElapsed.inMilliseconds} '
      'start=${startedAt.toIso8601String()} '
      'attempts=[$attemptSummary]',
      name: 'kakuro.generation',
    );
  }
}

Future<KakuroPuzzle> generateKakuroInIsolate(GenerateKakuroRequest request) {
  return Isolate.run(() => KakuroPuzzleGenerator().generateSync(request));
}

const String _kakuroOnDemandVersion = 'kakuro_on_demand_1';

GeneratedPuzzle<KakuroBoard> kakuroPuzzleAsGeneratedPuzzle(
  KakuroPuzzle puzzle,
) {
  final SizeOpt size = SizeOpt(
    id: '${puzzle.width}x${puzzle.height}',
    description: '${puzzle.width}x${puzzle.height}',
    width: puzzle.width,
    height: puzzle.height,
  );
  final DifficultyScore difficultyScore = DifficultyScore(
    value: puzzle.difficultyTelemetry.rawScore,
    level: puzzle.difficultyBucket,
  );
  final PuzzleMetadata meta = PuzzleMetadata(
    engineVersion: _kakuroOnDemandVersion,
    rngId: SeededRng.rngId,
    size: size,
    difficulty: difficultyScore,
    seedStr: (puzzle.seed ?? 0).toString(),
    seed64: puzzle.seed ?? 0,
  );
  final GenerationTelemetry telemetry = GenerationTelemetry(
    difficulty: puzzle.difficultyTelemetry,
    extras: puzzle.telemetry,
  );
  return GeneratedPuzzle<KakuroBoard>(
    state: puzzle.board,
    meta: meta,
    telemetry: telemetry,
  );
}
