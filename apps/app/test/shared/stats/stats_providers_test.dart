import 'package:app/shared/models/models.dart';
import 'package:app/shared/providers/puzzle_local_store_providers.dart';
import 'package:app/shared/stats/stats_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'providers expose overall and per-puzzle stats and refresh after completion',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(AsyncValue.data(prefs)),
        ],
      );
      addTearDown(container.dispose);

      final emptyAggregate = await container.read(
        localStatsAggregateProvider.future,
      );
      expect(emptyAggregate.totalCompletions, 0);

      await container
          .read(puzzleCompletionControllerProvider)
          .recordCompletion(
            puzzleType: PuzzleType.sudokuClassic,
            difficulty: 'easy',
            completionTime: const Duration(seconds: 95),
            mode: PuzzleMode.random,
            completedAt: DateTime.utc(2026, 6, 21, 10),
            size: '9x9',
            seed: 'provider-seed',
            moveCount: 16,
            hintsUsed: 2,
          );

      final aggregate = await container.read(
        localStatsAggregateProvider.future,
      );
      final puzzleStats = await container.read(
        puzzleStatsProvider(PuzzleType.sudokuClassic).future,
      );
      final difficultyStats = await container.read(
        puzzleDifficultyStatsProvider((
          PuzzleType.sudokuClassic,
          'easy',
        )).future,
      );

      expect(aggregate.totalCompletions, 1);
      expect(aggregate.totalHintsUsed, 2);
      expect(aggregate.totalMoveCount, 16);
      expect(puzzleStats.totalCompletions, 1);
      expect(puzzleStats.bestTime, const Duration(seconds: 95));
      expect(difficultyStats.totalCompletions, 1);
      expect(difficultyStats.bestTime, const Duration(seconds: 95));
    },
  );
}
