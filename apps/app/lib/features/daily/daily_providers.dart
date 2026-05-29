import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart';
import '../../shared/services/generation_isolate.dart';

import '../../shared/providers/engine_provider.dart';
import 'daily_seed_generator.dart';

final dailySeedGeneratorProvider = Provider<DailySeedGenerator>((ref) {
  return DailySeedGenerator();
});

final dailyPuzzleProvider =
    FutureProvider.family<GeneratedPuzzle<dynamic>, String>((
      ref,
      puzzleTypeKey,
    ) async {
      final engine = ref.watch(engineProvider(puzzleTypeKey));
      if (engine == null) {
        throw StateError('Puzzle engine not found for $puzzleTypeKey');
      }

      final seedGenerator = ref.watch(dailySeedGeneratorProvider);
      final seed = seedGenerator.generate(puzzleTypeKey);
      final size = _defaultSizeFor(puzzleTypeKey);
      final difficulty = _defaultDifficultyFor(puzzleTypeKey);
      if (puzzleTypeKey == 'kakuro_classic') {
        const Duration cap = Duration(seconds: 8);
        const int maxAttempts = 3;
        final Stopwatch watch = Stopwatch()..start();
        Object? lastError;
        StackTrace? lastStackTrace;
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
          final Duration remaining = cap - watch.elapsed;
          if (remaining <= Duration.zero) {
            break;
          }
          final String attemptSeedStr = attempt == 1
              ? seed.seedStr
              : '${seed.seedStr}#attempt$attempt';
          final int attemptSeed64 = Seed.fromString(attemptSeedStr);
          try {
            return await generatePuzzleIsolated(
              engineId: puzzleTypeKey,
              seedStr: attemptSeedStr,
              seed64: attemptSeed64,
              size: size,
              difficulty: difficulty,
            ).timeout(remaining);
          } catch (error, stackTrace) {
            lastError = error;
            lastStackTrace = stackTrace;
          }
        }
        if (lastError != null) {
          Error.throwWithStackTrace(
            lastError,
            lastStackTrace ?? StackTrace.current,
          );
        }
        throw TimeoutException(
          'Daily kakuro generation budget exceeded for $puzzleTypeKey',
          cap,
        );
      }

      return generatePuzzleIsolated(
        engineId: puzzleTypeKey,
        seedStr: seed.seedStr,
        seed64: seed.seed64,
        size: size,
        difficulty: difficulty,
      ).timeout(const Duration(seconds: 2));
    });

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
    'kakuro_classic': SizeOpt(
      id: '7x7',
      description: '7x7',
      width: 7,
      height: 7,
    ),
    'slitherlink_loop': SizeOpt(
      id: '7x7',
      description: '7x7',
      width: 7,
      height: 7,
    ),
    // Updated default to 9x9 per Phase-3 requirement.
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
    'kakuro_classic': DifficultyScore(value: 0.3, level: 'easy'),
    'slitherlink_loop': DifficultyScore(value: 0.3, level: 'easy'),
    'mathdoku_classic': DifficultyScore(value: 0.3, level: 'easy'),
    'killer_queens': DifficultyScore(value: 0.3, level: 'easy'),
    'takuzu_binary': DifficultyScore(value: 0.3, level: 'easy'),
  };
  return defaults[puzzleTypeKey] ??
      const DifficultyScore(value: 0.3, level: 'easy');
}
