import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

/// Kakuro on-demand generator bridging the new puzzle_core isolate API.
/// Retries indefinitely with fresh seeds and surfaces the first successful
/// puzzle back to the caller. No built-in fallback puzzles are used.
class KakuroOnDemandService {
  KakuroOnDemandService();

  final Random _random = Random();

  Future<core.GeneratedPuzzle<dynamic>> nextPuzzle({
    required String difficulty,
    Duration timeBudget = const Duration(milliseconds: 2200),
    int width = 9,
    int height = 9,
  }) async {
    final String normalized = difficulty.toLowerCase();
    final DateTime startedAt = DateTime.now();
    final Stopwatch wall = Stopwatch()..start();
    int attempt = 0;
    while (true) {
      attempt++;
      final int seed = _random.nextInt(0x7fffffff);
      if (kDebugMode) {
        debugPrint(
          '[KakuroOnDemand] start attempt=$attempt '
          'difficulty=$normalized seed=$seed '
          'budgetMs=${timeBudget.inMilliseconds}',
        );
      }
      final request = core.GenerateKakuroRequest(
        width: width,
        height: height,
        difficulty: normalized,
        seed: seed,
        timeBudget: timeBudget,
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
        if (kDebugMode) {
          // ignore: avoid_print
          print(
            'Kakuro generation failed for $difficulty (attempt $attempt): $error',
          );
          // ignore: avoid_print
          print(stackTrace);
        }
        // Small backoff to avoid a tight failure loop.
        await Future.delayed(Duration(milliseconds: min(80 * attempt, 600)));
      }
    }
  }

  Future<core.KakuroPuzzle> _runGenerator(
    core.GenerateKakuroRequest request,
  ) async {
    return core.generateKakuroInIsolate(request);
  }
}

final kakuroOnDemandProvider = Provider<KakuroOnDemandService>((ref) {
  return KakuroOnDemandService();
});
