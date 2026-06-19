import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/favourite_puzzle_service.dart';
import '../services/puzzle_local_store.dart';

typedef PuzzleDifficultyKey = (PuzzleType puzzleType, String difficulty);
typedef PuzzleDateKey = (PuzzleType puzzleType, DateTime date);

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
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

final puzzleTodayCompletionProvider = FutureProvider.family<bool, PuzzleType>((
  ref,
  puzzleType,
) async {
  final store = await ref.watch(puzzleLocalStoreProvider.future);
  return store.isDailyCompleted(puzzleType, DailyUtcDate.todayKey());
});

final dailyStreakStatusProvider = FutureProvider<DailyStreakStatus>((
  ref,
) async {
  final store = await ref.watch(puzzleLocalStoreProvider.future);
  return store.dailyStreakStatus();
});

final dailyCompletedCountProvider = FutureProvider.family<int, String>((
  ref,
  utcDayKey,
) async {
  final store = await ref.watch(puzzleLocalStoreProvider.future);
  return store.completedDailyCount(utcDayKey);
});

final nextUncompletedDailyPuzzleTypeProvider =
    FutureProvider.family<PuzzleType?, String?>((ref, utcDayKey) async {
      final store = await ref.watch(puzzleLocalStoreProvider.future);
      return store.nextUncompletedDailyPuzzleType(utcDayKey: utcDayKey);
    });

@Deprecated(
  'Use dailyStreakStatusProvider. Puzzle-specific streaks are not used.',
)
final puzzleStreakProvider = FutureProvider.family<int, PuzzleType>((
  ref,
  puzzleType,
) async {
  final status = await ref.watch(dailyStreakStatusProvider.future);
  return status.currentStreak;
});

@Deprecated('Use dailyStreakStatusProvider. Global streaks are not used.')
final puzzleGlobalStreakProvider = FutureProvider<int>((ref) async {
  final status = await ref.watch(dailyStreakStatusProvider.future);
  return status.currentStreak;
});

final favouritePuzzleServiceProvider = FutureProvider<FavouritePuzzleService>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return FavouritePuzzleService(prefs);
});

final favouritePuzzleTypesProvider = FutureProvider<List<PuzzleType>>((
  ref,
) async {
  final service = await ref.watch(favouritePuzzleServiceProvider.future);
  return service.favourites();
});

final isFavouritePuzzleTypeProvider = FutureProvider.family<bool, PuzzleType>((
  ref,
  puzzleType,
) async {
  final service = await ref.watch(favouritePuzzleServiceProvider.future);
  return service.isFavourite(puzzleType);
});

class FavouritePuzzleController {
  FavouritePuzzleController(this._ref);

  final Ref _ref;

  Future<bool> toggle(PuzzleType puzzleType) async {
    final service = await _ref.read(favouritePuzzleServiceProvider.future);
    final result = await service.toggle(puzzleType);
    _ref.invalidate(favouritePuzzleTypesProvider);
    _ref.invalidate(isFavouritePuzzleTypeProvider(puzzleType));
    return result;
  }
}

final favouritePuzzleControllerProvider = Provider<FavouritePuzzleController>(
  FavouritePuzzleController.new,
);

class PuzzleCompletionController {
  PuzzleCompletionController(this._ref);

  final Ref _ref;

  Future<PuzzleCompletionStatus> recordCompletion({
    required PuzzleType puzzleType,
    required String difficulty,
    required Duration completionTime,
    required PuzzleMode mode,
    DateTime? completedAt,
    String? size,
    String? seed,
    int moveCount = 0,
    int hintsUsed = 0,
    String? dailyDateKeyUtc,
  }) async {
    final store = await _ref.read(puzzleLocalStoreProvider.future);
    final timestamp = completedAt ?? DateTime.now();
    final String utcDayKey = dailyDateKeyUtc ?? DailyUtcDate.keyFor(timestamp);
    await store.recordCompletion(
      puzzleType: puzzleType,
      difficulty: difficulty,
      completionTime: completionTime,
      mode: mode,
      completedAt: timestamp,
      size: size,
      seed: seed,
      moveCount: moveCount,
      hintsUsed: hintsUsed,
      dailyDateKeyUtc: dailyDateKeyUtc,
    );

    _ref.invalidate(puzzleBestTimeProvider((puzzleType, difficulty)));
    if (mode == PuzzleMode.daily) {
      _ref.invalidate(
        puzzleDailyCompletionProvider((
          puzzleType,
          DailyUtcDate.parseKey(utcDayKey),
        )),
      );
      _ref.invalidate(puzzleTodayCompletionProvider(puzzleType));
      _ref.invalidate(dailyCompletedCountProvider(utcDayKey));
      _ref.invalidate(nextUncompletedDailyPuzzleTypeProvider(utcDayKey));
    }
    _ref.invalidate(dailyStreakStatusProvider);

    final Duration? bestTime = await store.bestTime(puzzleType, difficulty);
    final bool isDailyCompleted =
        mode == PuzzleMode.daily &&
        await store.isDailyCompleted(puzzleType, utcDayKey);
    final DailyStreakStatus dailyStreak = await store.dailyStreakStatus();

    return PuzzleCompletionStatus(
      bestTime: bestTime,
      isDailyCompleted: isDailyCompleted,
      dailyStreak: dailyStreak.currentStreak,
      bestDailyStreak: dailyStreak.bestStreak,
    );
  }
}

final puzzleCompletionControllerProvider = Provider<PuzzleCompletionController>(
  (ref) {
    return PuzzleCompletionController(ref);
  },
);
