import 'package:app/shared/models/models.dart';
import 'package:app/shared/services/puzzle_local_store.dart';
import 'package:app/shared/stats/local_stats_service.dart';
import 'package:app/shared/stats/stats_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PuzzleLocalStore store;
  late LocalStatsService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = SharedPreferencesPuzzleLocalStore(prefs);
    service = LocalStatsService(store);
  });

  test('returns empty aggregate state when no completions exist', () async {
    final stats = await service.aggregateStats();

    expect(await service.runResults(), isEmpty);
    expect(stats.hasCompletions, isFalse);
    expect(stats.totalCompletions, 0);
    expect(stats.randomCompletions, 0);
    expect(stats.dailyCompletions, 0);
    expect(stats.totalHintsUsed, 0);
    expect(stats.totalMoveCount, 0);
    expect(stats.firstCompletedAtUtc, isNull);
    expect(stats.lastCompletedAtUtc, isNull);
    expect(
      stats.statsForPuzzle(PuzzleType.sudokuClassic).statsForDifficulty('easy'),
      isA<PuzzleDifficultyStats>().having(
        (value) => value.totalCompletions,
        'totalCompletions',
        0,
      ),
    );
  });

  test(
    'captures first completion into aggregate and per-difficulty stats',
    () async {
      final completedAt = DateTime.utc(2026, 6, 20, 10);

      await store.recordCompletion(
        puzzleType: PuzzleType.sudokuClassic,
        difficulty: 'easy',
        completionTime: const Duration(seconds: 90),
        mode: PuzzleMode.random,
        completedAt: completedAt,
        size: '9x9',
        seed: 'seed-a',
        moveCount: 14,
        hintsUsed: 1,
      );

      final stats = await service.aggregateStats();
      final puzzleStats = stats.statsForPuzzle(PuzzleType.sudokuClassic);
      final difficultyStats = puzzleStats.statsForDifficulty('easy');

      expect(stats.totalCompletions, 1);
      expect(stats.randomCompletions, 1);
      expect(stats.dailyCompletions, 0);
      expect(stats.firstCompletedAtUtc, completedAt);
      expect(stats.lastCompletedAtUtc, completedAt);
      expect(puzzleStats.totalCompletions, 1);
      expect(puzzleStats.bestTime, const Duration(seconds: 90));
      expect(difficultyStats.totalCompletions, 1);
      expect(difficultyStats.bestTime, const Duration(seconds: 90));
      expect(difficultyStats.randomCompletions, 1);
      expect(difficultyStats.dailyCompletions, 0);
    },
  );

  test('updates best time when a faster completion is recorded', () async {
    final completedAt = DateTime.utc(2026, 6, 20, 10);

    await store.recordCompletion(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'medium',
      completionTime: const Duration(seconds: 120),
      mode: PuzzleMode.random,
      completedAt: completedAt,
      size: '9x9',
      seed: 'slow',
    );
    await store.recordCompletion(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'medium',
      completionTime: const Duration(seconds: 80),
      mode: PuzzleMode.random,
      completedAt: completedAt.add(const Duration(minutes: 1)),
      size: '9x9',
      seed: 'fast',
    );

    final difficultyStats = (await service.aggregateStats())
        .statsForPuzzle(PuzzleType.sudokuClassic)
        .statsForDifficulty('medium');

    expect(difficultyStats.totalCompletions, 2);
    expect(difficultyStats.bestTime, const Duration(seconds: 80));
  });

  test('keeps best time unchanged for a slower non-best completion', () async {
    final completedAt = DateTime.utc(2026, 6, 20, 10);

    await store.recordCompletion(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'hard',
      completionTime: const Duration(seconds: 75),
      mode: PuzzleMode.random,
      completedAt: completedAt,
      size: '9x9',
      seed: 'best',
    );
    await store.recordCompletion(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'hard',
      completionTime: const Duration(seconds: 105),
      mode: PuzzleMode.random,
      completedAt: completedAt.add(const Duration(minutes: 3)),
      size: '9x9',
      seed: 'slower',
    );

    final difficultyStats = (await service.aggregateStats())
        .statsForPuzzle(PuzzleType.sudokuClassic)
        .statsForDifficulty('hard');

    expect(difficultyStats.totalCompletions, 2);
    expect(difficultyStats.bestTime, const Duration(seconds: 75));
  });

  test('separates daily and random completions in aggregate stats', () async {
    await store.recordCompletion(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'easy',
      completionTime: const Duration(seconds: 70),
      mode: PuzzleMode.random,
      completedAt: DateTime.utc(2026, 6, 20, 8),
      size: '9x9',
      seed: 'random-seed',
    );
    await store.recordCompletion(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'easy',
      completionTime: const Duration(seconds: 65),
      mode: PuzzleMode.daily,
      completedAt: DateTime.utc(2026, 6, 20, 9),
      size: '9x9',
      seed: 'daily-seed',
      dailyDateKeyUtc: '2026-06-20',
    );

    final stats = await service.aggregateStats();
    final puzzleStats = stats.statsForPuzzle(PuzzleType.sudokuClassic);

    expect(stats.totalCompletions, 2);
    expect(stats.randomCompletions, 1);
    expect(stats.dailyCompletions, 1);
    expect(puzzleStats.randomCompletions, 1);
    expect(puzzleStats.dailyCompletions, 1);
  });

  test('sums hint counts across completions', () async {
    await store.recordCompletion(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'easy',
      completionTime: const Duration(seconds: 70),
      mode: PuzzleMode.random,
      completedAt: DateTime.utc(2026, 6, 20, 8),
      size: '9x9',
      seed: 'a',
      hintsUsed: 2,
    );
    await store.recordCompletion(
      puzzleType: PuzzleType.nonogramMono,
      difficulty: 'normal',
      completionTime: const Duration(minutes: 3),
      mode: PuzzleMode.daily,
      completedAt: DateTime.utc(2026, 6, 20, 9),
      size: '10x10',
      seed: 'b',
      hintsUsed: 1,
      dailyDateKeyUtc: '2026-06-20',
    );

    final stats = await service.aggregateStats();

    expect(stats.totalHintsUsed, 3);
    expect(stats.statsForPuzzle(PuzzleType.sudokuClassic).totalHintsUsed, 2);
    expect(stats.statsForPuzzle(PuzzleType.nonogramMono).totalHintsUsed, 1);
  });

  test('sums move counts across completions', () async {
    await store.recordCompletion(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'easy',
      completionTime: const Duration(seconds: 70),
      mode: PuzzleMode.random,
      completedAt: DateTime.utc(2026, 6, 20, 8),
      size: '9x9',
      seed: 'a',
      moveCount: 12,
    );
    await store.recordCompletion(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'easy',
      completionTime: const Duration(seconds: 65),
      mode: PuzzleMode.daily,
      completedAt: DateTime.utc(2026, 6, 20, 9),
      size: '9x9',
      seed: 'b',
      moveCount: 9,
      dailyDateKeyUtc: '2026-06-20',
    );

    final stats = await service.aggregateStats();
    final difficultyStats = stats
        .statsForPuzzle(PuzzleType.sudokuClassic)
        .statsForDifficulty('easy');

    expect(stats.totalMoveCount, 21);
    expect(difficultyStats.totalMoveCount, 21);
  });
}
