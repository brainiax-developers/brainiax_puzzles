import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart'
    show DifficultyScore, GeneratedPuzzle, SizeOpt;

import '../../shared/models/puzzle_type.dart';
import '../../shared/providers/engine_provider.dart';
import '../../shared/services/generated_puzzle_difficulty.dart';
import '../../shared/services/generation_isolate.dart';
import '../../shared/services/slitherlink_on_demand_service.dart';
import 'daily_seed_generator.dart';

final dailySeedGeneratorProvider = Provider<DailySeedGenerator>((ref) {
  return DailySeedGenerator();
});

final dailyPuzzleProvider =
    FutureProvider.family<GeneratedPuzzle<dynamic>, String>((
      ref,
      puzzleTypeKey,
    ) async {
      final PuzzleType? puzzleType = PuzzleType.fromKey(puzzleTypeKey);
      if (puzzleType == null || !puzzleType.isDailyEligible) {
        throw StateError('Daily puzzle unavailable for $puzzleTypeKey');
      }

      final engine = ref.watch(engineProvider(puzzleTypeKey));
      if (engine == null) {
        throw StateError('Puzzle engine not found for $puzzleTypeKey');
      }

      final seedGenerator = ref.watch(dailySeedGeneratorProvider);
      final seed = seedGenerator.generate(puzzleTypeKey);
      final size = _defaultSizeFor(puzzleTypeKey);
      final difficulty = _defaultDifficultyFor(puzzleTypeKey);
      if (puzzleTypeKey == 'slitherlink_loop') {
        final generated = await ref
            .read(slitherlinkOnDemandProvider)
            .nextPuzzle(
              difficulty: difficulty.level,
              width: size.width,
              height: size.height,
              seed: seed.seedStr,
              timeBudget: const Duration(milliseconds: 900),
            );

        final GeneratedPuzzle<dynamic> normalized =
            normalizeGeneratedPuzzleDifficulty(
              puzzle: generated,
              requestedDifficulty: difficulty,
            );
        _logDailyGenerationSuccess(
          puzzleTypeKey: puzzleTypeKey,
          puzzle: normalized,
          requestedDifficulty: difficulty,
        );
        return normalized;
      }

      final GeneratedPuzzle<dynamic> generated = await ref
          .read(puzzleGenerationWorkerProvider)
          .generate(
            PuzzleGenerationRequest(
              engineId: puzzleTypeKey,
              seedStr: seed.seedStr,
              seed64: seed.seed64,
              size: size,
              difficulty: difficulty,
            ),
            timeout: const Duration(seconds: 2),
          );
      final GeneratedPuzzle<dynamic> normalized =
          normalizeGeneratedPuzzleDifficulty(
            puzzle: generated,
            requestedDifficulty: difficulty,
          );
      _logDailyGenerationSuccess(
        puzzleTypeKey: puzzleTypeKey,
        puzzle: normalized,
        requestedDifficulty: difficulty,
      );
      return normalized;
    });

void _logDailyGenerationSuccess({
  required String puzzleTypeKey,
  required GeneratedPuzzle<dynamic> puzzle,
  required DifficultyScore requestedDifficulty,
}) {
  if (!kDebugMode) {
    return;
  }
  debugPrint(
    '[DailyGeneration][Success] type=$puzzleTypeKey '
    '${generatedPuzzleDifficultyDebugFields(puzzle: puzzle, requestedDifficulty: requestedDifficulty)} '
    'seed=${puzzle.meta.seedStr} size=${puzzle.meta.size.id}',
  );
}

SizeOpt _defaultSizeFor(String puzzleTypeKey) {
  const Map<String, SizeOpt> defaults = {
    'sudoku_classic': SizeOpt(
      id: '9x9',
      description: '9x9',
      width: 9,
      height: 9,
    ),
    'nonogram_mono': SizeOpt(
      id: '10x10',
      description: '10x10',
      width: 10,
      height: 10,
    ),
    'slitherlink_loop': SizeOpt(
      id: '7x7',
      description: '7x7',
      width: 7,
      height: 7,
    ),
    'mathdoku_classic': SizeOpt(
      id: '9x9',
      description: '9x9',
      width: 9,
      height: 9,
    ),
    'killer_queens': SizeOpt(
      id: '8x8',
      description: '8x8',
      width: 8,
      height: 8,
    ),
    'takuzu_binary': SizeOpt(
      id: '8x8',
      description: '8x8',
      width: 8,
      height: 8,
    ),
  };
  return defaults[puzzleTypeKey] ??
      const SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);
}

DifficultyScore _defaultDifficultyFor(String puzzleTypeKey) {
  const Map<String, DifficultyScore> defaults = {
    'sudoku_classic': DifficultyScore(value: 0.3, level: 'easy'),
    'nonogram_mono': DifficultyScore(value: 0.3, level: 'easy'),
    'slitherlink_loop': DifficultyScore(value: 0.3, level: 'easy'),
    'mathdoku_classic': DifficultyScore(value: 0.3, level: 'easy'),
    'killer_queens': DifficultyScore(value: 0.3, level: 'easy'),
    'takuzu_binary': DifficultyScore(value: 0.3, level: 'easy'),
  };
  return defaults[puzzleTypeKey] ??
      const DifficultyScore(value: 0.3, level: 'easy');
}
