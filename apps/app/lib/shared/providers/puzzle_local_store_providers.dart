import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/puzzle_local_store.dart';

typedef PuzzleDifficultyKey = (PuzzleType puzzleType, String difficulty);
typedef PuzzleDateKey = (PuzzleType puzzleType, DateTime date);

final sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final puzzleLocalStoreProvider = FutureProvider<PuzzleLocalStore>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SharedPreferencesPuzzleLocalStore(prefs);
});

final puzzleBestTimeProvider =
    FutureProvider.family<Duration?, PuzzleDifficultyKey>((ref, key) async {
  final store = await ref.watch(puzzleLocalStoreProvider.future);
  return store.bestTime(key.$1, key.$2);
});

final puzzleDailyCompletionProvider =
    FutureProvider.family<bool, PuzzleDateKey>((ref, key) async {
  final store = await ref.watch(puzzleLocalStoreProvider.future);
  return store.isCompletedOn(key.$1, key.$2);
});

final puzzleTodayCompletionProvider =
    FutureProvider.family<bool, PuzzleType>((ref, puzzleType) async {
  final store = await ref.watch(puzzleLocalStoreProvider.future);
  return store.isCompletedOn(puzzleType, DateTime.now());
});

final puzzleStreakProvider =
    FutureProvider.family<int, PuzzleType>((ref, puzzleType) async {
  final store = await ref.watch(puzzleLocalStoreProvider.future);
  return store.puzzleStreak(puzzleType);
});

final puzzleGlobalStreakProvider = FutureProvider<int>((ref) async {
  final store = await ref.watch(puzzleLocalStoreProvider.future);
  return store.globalStreak();
});

class PuzzleCompletionController {
  PuzzleCompletionController(this._ref);

  final Ref _ref;

  Future<void> recordCompletion({
    required PuzzleType puzzleType,
    required String difficulty,
    required Duration completionTime,
    DateTime? completedAt,
  }) async {
    final store = await _ref.read(puzzleLocalStoreProvider.future);
    final timestamp = completedAt ?? DateTime.now();
    await store.recordCompletion(
      puzzleType: puzzleType,
      difficulty: difficulty,
      completionTime: completionTime,
      completedAt: timestamp,
    );

    _ref.invalidate(puzzleBestTimeProvider((puzzleType, difficulty)));
    _ref.invalidate(
      puzzleDailyCompletionProvider((puzzleType, DateTime(
        timestamp.year,
        timestamp.month,
        timestamp.day,
      ))),
    );
    _ref.invalidate(puzzleTodayCompletionProvider(puzzleType));
    _ref.invalidate(puzzleStreakProvider(puzzleType));
    _ref.invalidate(puzzleGlobalStreakProvider);
  }
}

final puzzleCompletionControllerProvider =
    Provider<PuzzleCompletionController>((ref) {
  return PuzzleCompletionController(ref);
});
