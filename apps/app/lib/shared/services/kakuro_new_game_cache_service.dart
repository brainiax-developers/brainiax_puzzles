import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;


/// Kakuro on-demand generator bridging the new puzzle_core isolate API
/// with the app. Keeps a tiny fallback cache (one entry per difficulty)
/// so we always have something to show if generation exceeds the time budget.
class KakuroOnDemandService {
  KakuroOnDemandService();

  final Map<String, core.GeneratedPuzzle<dynamic>> _fallbackCache =
      <String, core.GeneratedPuzzle<dynamic>>{};
  final Random _random = Random();

  Future<core.GeneratedPuzzle<dynamic>> nextPuzzle({
    required String difficulty,
    Duration timeBudget = const Duration(milliseconds: 320),
    int width = 9,
    int height = 9,
  }) async {
    final String normalized = difficulty.toLowerCase();
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
      final core.KakuroPuzzle puzzle =
          await core.generateKakuroInIsolate(request);
      final core.GeneratedPuzzle<dynamic> generated =
          core.kakuroPuzzleAsGeneratedPuzzle(puzzle);
      _fallbackCache[normalized] = generated;
      return generated;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Kakuro generation failed for $difficulty: $error');
        // ignore: avoid_print
        print(stackTrace);
      }
      final fallback = _fallbackCache[normalized];
      if (fallback != null) {
        return fallback;
      }
      rethrow;
    }
  }
}

final kakuroOnDemandProvider = Provider<KakuroOnDemandService>((ref) {
  return KakuroOnDemandService();
});
