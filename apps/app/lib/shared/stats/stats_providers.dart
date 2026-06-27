import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/puzzle_type.dart';
import '../providers/puzzle_local_store_providers.dart';
import 'local_stats_service.dart';
import 'stats_models.dart';

typedef PuzzleStatsDifficultyKey = (PuzzleType puzzleType, String difficulty);

final localStatsServiceProvider = FutureProvider<LocalStatsService>((
  ref,
) async {
  final store = await ref.watch(puzzleLocalStoreProvider.future);
  return LocalStatsService(store);
});

final localStatsAggregateProvider = FutureProvider<PuzzleStatsAggregate>((
  ref,
) async {
  await ref.watch(completionRecordsProvider.future);
  final service = await ref.watch(localStatsServiceProvider.future);
  return service.aggregateStats();
});

final puzzleStatsProvider = FutureProvider.family<PuzzleTypeStats, PuzzleType>((
  ref,
  puzzleType,
) async {
  final aggregate = await ref.watch(localStatsAggregateProvider.future);
  return aggregate.statsForPuzzle(puzzleType);
});

final puzzleDifficultyStatsProvider =
    FutureProvider.family<PuzzleDifficultyStats, PuzzleStatsDifficultyKey>((
      ref,
      key,
    ) async {
      final puzzleStats = await ref.watch(puzzleStatsProvider(key.$1).future);
      return puzzleStats.statsForDifficulty(key.$2);
    });
