import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Contract for persisting puzzle completion progress locally.
abstract class PuzzleLocalStore {
  /// Record a puzzle completion.
  Future<PuzzleCompletionRecord> recordCompletion({
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
  });

  /// Retrieve the best completion time for a puzzle type/difficulty.
  Future<Duration?> bestTime(PuzzleType puzzleType, String difficulty);

  /// Whether the given puzzle type is marked complete on [date].
  Future<bool> isCompletedOn(PuzzleType puzzleType, DateTime date);

  Future<bool> isDailyCompleted(PuzzleType puzzleType, String utcDayKey);

  Future<bool> anyDailyCompleted(String utcDayKey);

  Future<int> completedDailyCount(String utcDayKey);

  Future<PuzzleType?> nextUncompletedDailyPuzzleType({String? utcDayKey});

  Future<DailyStreakStatus> dailyStreakStatus();

  Future<List<PuzzleCompletionRecord>> completionRecords();

  Future<int> totalSolved();

  Future<int> completedTodayCount({DateTime? now});

  Future<int> completedThisWeekCount({DateTime? now});

  @Deprecated('Use dailyStreakStatus. Puzzle-specific streaks are not used.')
  Future<int> puzzleStreak(PuzzleType puzzleType);

  @Deprecated('Use dailyStreakStatus. Global streaks are not used.')
  Future<int> globalStreak();
}

/// SharedPreferences backed implementation of [PuzzleLocalStore].
class SharedPreferencesPuzzleLocalStore implements PuzzleLocalStore {
  SharedPreferencesPuzzleLocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _storageNamespace = 'puzzle_local_store.v2';
  static const _bestTimePrefix = '$_storageNamespace.best_time';
  static const _completionRecordsKey = '$_storageNamespace.completion_records';
  static const _dailyStreakCurrentKey =
      '$_storageNamespace.daily_streak.current';
  static const _dailyStreakBestKey = '$_storageNamespace.daily_streak.best';
  static const _dailyStreakLastDateKey =
      '$_storageNamespace.daily_streak.last_date_utc';

  @override
  Future<PuzzleCompletionRecord> recordCompletion({
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
    final DateTime completedAtUtc = (completedAt ?? DateTime.now()).toUtc();
    final String? resolvedDailyKey = mode == PuzzleMode.daily
        ? (dailyDateKeyUtc ?? DailyUtcDate.keyFor(completedAtUtc))
        : null;

    final record = PuzzleCompletionRecord(
      id: _recordId(puzzleType, mode, completedAtUtc, seed ?? ''),
      puzzleType: puzzleType,
      mode: mode,
      difficulty: difficulty,
      size: size ?? 'unknown',
      seed: seed ?? '',
      completedAtUtc: completedAtUtc,
      elapsedMs: completionTime.inMilliseconds,
      moveCount: moveCount,
      hintsUsed: hintsUsed,
      dailyDateKeyUtc: resolvedDailyKey,
    );

    await _appendCompletionRecord(record);
    await _updateBestTime(puzzleType, difficulty, completionTime);
    if (mode == PuzzleMode.daily && resolvedDailyKey != null) {
      await _updateDailyStreak(resolvedDailyKey);
    }
    return record;
  }

  @override
  Future<Duration?> bestTime(PuzzleType puzzleType, String difficulty) async {
    final key = _bestTimeKey(puzzleType, difficulty);
    final milliseconds = _prefs.getInt(key);
    if (milliseconds == null) {
      return null;
    }
    return Duration(milliseconds: milliseconds);
  }

  @override
  Future<bool> isCompletedOn(PuzzleType puzzleType, DateTime date) {
    return isDailyCompleted(puzzleType, DailyUtcDate.keyFor(date));
  }

  @override
  Future<bool> isDailyCompleted(PuzzleType puzzleType, String utcDayKey) async {
    final records = await completionRecords();
    return records.any(
      (record) =>
          record.mode == PuzzleMode.daily &&
          record.puzzleType == puzzleType &&
          record.dailyDateKeyUtc == utcDayKey,
    );
  }

  @override
  Future<bool> anyDailyCompleted(String utcDayKey) async {
    final records = await completionRecords();
    return records.any(
      (record) =>
          record.mode == PuzzleMode.daily &&
          record.dailyDateKeyUtc == utcDayKey,
    );
  }

  @override
  Future<int> completedDailyCount(String utcDayKey) async {
    final records = await completionRecords();
    return records
        .where(
          (record) =>
              record.mode == PuzzleMode.daily &&
              record.dailyDateKeyUtc == utcDayKey,
        )
        .map((record) => record.puzzleType)
        .toSet()
        .length;
  }

  @override
  Future<PuzzleType?> nextUncompletedDailyPuzzleType({
    String? utcDayKey,
  }) async {
    final String key = utcDayKey ?? DailyUtcDate.todayKey();
    for (final type in PuzzleType.dailyChallengeTypes) {
      if (!await isDailyCompleted(type, key)) {
        return type;
      }
    }
    return null;
  }

  @override
  Future<DailyStreakStatus> dailyStreakStatus() async {
    return DailyStreakStatus(
      currentStreak: _prefs.getInt(_dailyStreakCurrentKey) ?? 0,
      bestStreak: _prefs.getInt(_dailyStreakBestKey) ?? 0,
      lastCompletedDateKeyUtc: _prefs.getString(_dailyStreakLastDateKey),
    );
  }

  @override
  Future<List<PuzzleCompletionRecord>> completionRecords() async {
    final String? encoded = _prefs.getString(_completionRecordsKey);
    if (encoded == null || encoded.isEmpty) {
      return const <PuzzleCompletionRecord>[];
    }
    try {
      final list = jsonDecode(encoded) as List<dynamic>;
      return list
          .map(
            (entry) => PuzzleCompletionRecord.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList();
    } catch (_) {
      await _prefs.remove(_completionRecordsKey);
      return const <PuzzleCompletionRecord>[];
    }
  }

  @override
  Future<int> totalSolved() async => (await completionRecords()).length;

  @override
  Future<int> completedTodayCount({DateTime? now}) {
    return completedDailyCount(DailyUtcDate.todayKey(now: now));
  }

  @override
  Future<int> completedThisWeekCount({DateTime? now}) async {
    final DateTime utcToday = DailyUtcDate.today(now: now);
    final DateTime weekStart = utcToday.subtract(
      Duration(days: utcToday.weekday - 1),
    );
    final records = await completionRecords();
    return records.where((record) {
      final completedDay = DailyUtcDate.today(now: record.completedAtUtc);
      return !completedDay.isBefore(weekStart) &&
          completedDay.isBefore(weekStart.add(const Duration(days: 7)));
    }).length;
  }

  @override
  Future<int> puzzleStreak(PuzzleType puzzleType) async {
    return (await dailyStreakStatus()).currentStreak;
  }

  @override
  Future<int> globalStreak() async {
    return (await dailyStreakStatus()).currentStreak;
  }

  Future<void> _appendCompletionRecord(PuzzleCompletionRecord record) async {
    final records = await completionRecords();
    final updated = <PuzzleCompletionRecord>[
      ...records.where((existing) => existing.id != record.id),
      record,
    ];
    await _prefs.setString(
      _completionRecordsKey,
      jsonEncode(updated.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _updateBestTime(
    PuzzleType puzzleType,
    String difficulty,
    Duration completionTime,
  ) async {
    final key = _bestTimeKey(puzzleType, difficulty);
    final existing = _prefs.getInt(key);
    final currentMillis = completionTime.inMilliseconds;
    if (existing == null || currentMillis < existing) {
      await _prefs.setInt(key, currentMillis);
    }
  }

  Future<void> _updateDailyStreak(String utcDayKey) async {
    final String? lastDate = _prefs.getString(_dailyStreakLastDateKey);
    int streak = _prefs.getInt(_dailyStreakCurrentKey) ?? 0;

    if (lastDate == null) {
      streak = 1;
    } else if (lastDate == utcDayKey) {
      streak = streak == 0 ? 1 : streak;
    } else if (DailyUtcDate.isNextDayKey(lastDate, utcDayKey)) {
      streak += 1;
    } else {
      streak = 1;
    }

    final int best = _prefs.getInt(_dailyStreakBestKey) ?? 0;
    await _prefs.setInt(_dailyStreakCurrentKey, streak);
    if (streak > best) {
      await _prefs.setInt(_dailyStreakBestKey, streak);
    }
    await _prefs.setString(_dailyStreakLastDateKey, utcDayKey);
  }

  String _bestTimeKey(PuzzleType puzzleType, String difficulty) {
    return '$_bestTimePrefix.${puzzleType.key}.$difficulty';
  }

  String _recordId(
    PuzzleType puzzleType,
    PuzzleMode mode,
    DateTime completedAtUtc,
    String seed,
  ) {
    final safeSeed = seed.replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_');
    return [
      puzzleType.key,
      mode.key,
      completedAtUtc.microsecondsSinceEpoch.toString(),
      safeSeed,
    ].join(':');
  }
}
