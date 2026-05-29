import 'dart:async';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

/// Kakuro on-demand generator bridging the new puzzle_core isolate API.
/// Uses bounded retries with deterministic sub-seeds derived from a base seed.
/// No built-in fallback puzzles are used.
class KakuroOnDemandService {
  KakuroOnDemandService();

  final Random _random = Random();

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

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final Duration remaining = timeBudget - wall.elapsed;
      if (remaining <= Duration.zero) {
        break;
      }
      final int attemptSeed = _deriveAttemptSeed(baseSeed, attempt);
      if (kDebugMode) {
        debugPrint(
          '[KakuroOnDemand] start attempt=$attempt '
          'difficulty=$normalized seed=$attemptSeed '
          'baseSeed=$baseSeed '
          'budgetMs=${timeBudget.inMilliseconds}',
        );
      }
      final request = core.GenerateKakuroRequest(
        width: width,
        height: height,
        difficulty: normalized,
        seed: attemptSeed,
        timeBudget: remaining,
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
      attempts: maxAttempts,
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
