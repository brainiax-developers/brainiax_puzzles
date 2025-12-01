import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

/// Kakuro on-demand generator bridging the new puzzle_core isolate API.
/// Retries indefinitely with fresh seeds and surfaces the first successful
/// puzzle back to the caller. No built-in fallback puzzles are used.
class KakuroOnDemandService {
  KakuroOnDemandService();

  final Random _random = Random();
  core.KakuroPuzzleGenerator? _generator;
  Future<core.DifficultyBucketConfig>? _configFuture;

  Future<core.GeneratedPuzzle<dynamic>> nextPuzzle({
    required String difficulty,
    Duration timeBudget = const Duration(milliseconds: 320),
    int width = 9,
    int height = 9,
  }) async {
    final String normalized = difficulty.toLowerCase();
    int attempt = 0;
    while (true) {
      attempt++;
      final int seed = _random.nextInt(0x7fffffff);
      final request = core.GenerateKakuroRequest(
        width: width,
        height: height,
        difficulty: normalized,
        seed: seed,
        timeBudget: timeBudget,
        strategy: core.KakuroGenerationStrategy.solutionFirst,
      );
      try {
        final core.KakuroPuzzleGenerator generator = await _ensureGenerator();
        final core.KakuroPuzzle puzzle = await _runGenerator(
          generator,
          request,
        );
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

  Future<core.KakuroPuzzleGenerator> _ensureGenerator() async {
    if (_generator != null) {
      return _generator!;
    }
    final core.DifficultyBucketConfig config = await (_configFuture ??=
        _loadDifficultyConfig());
    _generator = core.KakuroPuzzleGenerator(difficultyConfig: config);
    return _generator!;
  }

  Future<core.DifficultyBucketConfig> _loadDifficultyConfig() async {
    try {
      final String raw = await rootBundle.loadString(
        'packages/puzzle_core/assets/kakuro_difficulty_thresholds.json',
      );
      final Map<String, dynamic> jsonMap =
          jsonDecode(raw) as Map<String, dynamic>;
      return core.DifficultyBucketConfig.fromJson(jsonMap);
    } catch (_) {
      return const core.DifficultyBucketConfig(
        buckets: <core.DifficultyBucketThreshold>[
          core.DifficultyBucketThreshold(id: 'easy', maxInclusive: 0.35),
          core.DifficultyBucketThreshold(id: 'medium', maxInclusive: 0.65),
          core.DifficultyBucketThreshold(id: 'hard', maxInclusive: 0.95),
          core.DifficultyBucketThreshold(id: 'expert', maxInclusive: 1.20),
        ],
      );
    }
  }

  Future<core.KakuroPuzzle> _runGenerator(
    core.KakuroPuzzleGenerator generator,
    core.GenerateKakuroRequest request,
  ) async {
    return generator.generateSync(request);
  }
}

final kakuroOnDemandProvider = Provider<KakuroOnDemandService>((ref) {
  return KakuroOnDemandService();
});
