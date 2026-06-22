import 'dart:async';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

/// Kakuro on-demand generator bridging the new puzzle_core isolate API.
/// Uses bounded retries with deterministic sub-seeds derived from a base seed.
/// No built-in fallback puzzles are used.
class KakuroOnDemandService {
  KakuroOnDemandService({
    Future<core.KakuroPuzzle> Function(core.GenerateKakuroRequest request)?
    runGenerator,
  }) : _runGeneratorOverride = runGenerator;

  final Random _random = Random();
  final Future<core.KakuroPuzzle> Function(core.GenerateKakuroRequest request)?
  _runGeneratorOverride;

  Future<core.GeneratedPuzzle<dynamic>> nextPuzzle({
    required String difficulty,
    Duration timeBudget = const Duration(seconds: 8),
    int maxAttempts = 4,
    int? seed,
    int width = 9,
    int height = 9,
  }) async {
    final String normalized = difficulty.toLowerCase();
    final DateTime startedAt = DateTime.now();
    final Stopwatch wall = Stopwatch()..start();
    if (maxAttempts <= 0) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be > 0');
    }
    if (timeBudget <= Duration.zero) {
      throw ArgumentError.value(timeBudget, 'timeBudget', 'must be > 0');
    }

    final int baseSeed = seed ?? _random.nextInt(0x7fffffff);
    Object? lastError;
    StackTrace? lastStackTrace;
    int attemptsStarted = 0;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final Duration remaining = timeBudget - wall.elapsed;
      if (remaining <= Duration.zero) {
        break;
      }
      attemptsStarted = attempt;
      final int attemptSeed = _deriveAttemptSeed(baseSeed, attempt);
      final int attemptsRemaining = maxAttempts - attempt + 1;
      final Duration attemptBudget = Duration(
        milliseconds: (remaining.inMilliseconds / attemptsRemaining).ceil(),
      );

      if (kDebugMode) {
        debugPrint(
          '[KakuroOnDemand] start attempt=$attempt '
              'difficulty=$normalized seed=$attemptSeed '
              'baseSeed=$baseSeed '
              'attemptBudgetMs=${attemptBudget.inMilliseconds} '
              'remainingBudgetMs=${remaining.inMilliseconds}',
        );
      }

      final request = core.GenerateKakuroRequest(
        width: width,
        height: height,
        difficulty: normalized,
        seed: attemptSeed,
        timeBudget: attemptBudget,
        maxRestarts: 1,
        strategy: core.KakuroGenerationStrategy.solutionFirst,
      );
      try {
        final core.KakuroPuzzle puzzle = await _runGenerator(request);
        wall.stop();
        if (kDebugMode) {
          debugPrint(
            '[KakuroOnDemand] success difficulty=$normalized '
            'seed=${puzzle.seed} attempts=$attempt '
            'elapsedMs=${wall.elapsedMilliseconds} '
            'startedAt=${startedAt.toIso8601String()} '
            'size=${puzzle.width}x${puzzle.height} '
            'bucket=${puzzle.difficultyBucket}',
          );
        }
        return core.kakuroPuzzleAsGeneratedPuzzle(puzzle);
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (kDebugMode) {
          // ignore: avoid_print
          print(
            'Kakuro generation failed for $difficulty (attempt $attempt): $error',
          );
          // ignore: avoid_print
          print(stackTrace);
        }
      }
    }

    wall.stop();
    throw core.GenerationFailure(
      message:
          'Kakuro generation exhausted attempts=$maxAttempts within '
          'budgetMs=${timeBudget.inMilliseconds}',
      attempts: attemptsStarted,
      elapsed: wall.elapsed,
      baseSeed: baseSeed,
      lastError: lastError,
      lastStackTrace: lastStackTrace,
      context: <String, Object?>{
        'difficulty': normalized,
        'width': width,
        'height': height,
        'startedAt': startedAt.toIso8601String(),
      },
    );
  }

  Future<core.KakuroPuzzle> _runGenerator(
    core.GenerateKakuroRequest request,
  ) async {
    final override = _runGeneratorOverride;
    if (override != null) {
      return override(request);
    }
    return core.generateKakuroInIsolate(request);
  }

  int _deriveAttemptSeed(int baseSeed, int attempt) {
    const int step = 0x9e3779b9;
    return (baseSeed + (attempt - 1) * step) & 0x7fffffff;
  }
}

final kakuroOnDemandProvider = Provider<KakuroOnDemandService>((ref) {
  return KakuroOnDemandService();
});
