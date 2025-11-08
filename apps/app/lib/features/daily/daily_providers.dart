import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart';
import '../../shared/services/generation_isolate.dart';

import '../../shared/providers/engine_provider.dart';
import 'daily_seed_generator.dart';

final dailySeedGeneratorProvider = Provider<DailySeedGenerator>((ref) {
  return DailySeedGenerator();
});

final dailyPuzzleProvider = FutureProvider.family<GeneratedPuzzle<dynamic>, String>((ref, puzzleTypeKey) async {
  final engine = ref.watch(engineProvider(puzzleTypeKey));
  if (engine == null) {
    throw StateError('Puzzle engine not found for $puzzleTypeKey');
  }

  final seedGenerator = ref.watch(dailySeedGeneratorProvider);
  final seed = seedGenerator.generate(puzzleTypeKey);
  final size = _defaultSizeFor(puzzleTypeKey);
  final difficulty = _defaultDifficultyFor(puzzleTypeKey);

  final Duration timeout = puzzleTypeKey == 'kakuro_classic'
      ? const Duration(seconds: 3)
      : const Duration(seconds: 2);
  return generatePuzzleIsolated(
    engineId: puzzleTypeKey,
    seedStr: seed.seedStr,
    seed64: seed.seed64,
    size: size,
    difficulty: difficulty,
  ).timeout(timeout);
});

SizeOpt _defaultSizeFor(String puzzleTypeKey) {
  const Map<String, SizeOpt> defaults = {
    'sudoku_classic': SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9),
    'nonogram_mono': SizeOpt(id: '10x10', description: '10x10', width: 10, height: 10),
    'kakuro_classic': SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9),
    'slitherlink_loop': SizeOpt(id: '7x7', description: '7x7', width: 7, height: 7),
  // Updated default to 9x9 per Phase-3 requirement.
  'mathdoku_classic': SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9),
    'futoshiki_classic': SizeOpt(id: '6x6', description: '6x6', width: 6, height: 6),
    'takuzu_binary': SizeOpt(id: '8x8', description: '8x8', width: 8, height: 8),
  };
  return defaults[puzzleTypeKey] ??
      const SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);
}

DifficultyScore _defaultDifficultyFor(String puzzleTypeKey) {
  const Map<String, DifficultyScore> defaults = {
    'sudoku_classic': DifficultyScore(value: 0.6, level: 'medium'),
    'nonogram_mono': DifficultyScore(value: 0.6, level: 'medium'),
    'kakuro_classic': DifficultyScore(value: 0.6, level: 'medium'),
    'slitherlink_loop': DifficultyScore(value: 0.6, level: 'medium'),
    'mathdoku_classic': DifficultyScore(value: 0.6, level: 'medium'),
    'futoshiki_classic': DifficultyScore(value: 0.6, level: 'medium'),
    'takuzu_binary': DifficultyScore(value: 0.6, level: 'medium'),
  };
  return defaults[puzzleTypeKey] ??
      const DifficultyScore(value: 0.6, level: 'medium');
}
