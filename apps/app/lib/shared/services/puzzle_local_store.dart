import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Contract for persisting puzzle completion progress locally.
abstract class PuzzleLocalStore {
  /// Record a puzzle completion.
  Future<void> recordCompletion({
    required PuzzleType puzzleType,
    required String difficulty,
    required Duration completionTime,
    required PuzzleMode mode,
    DateTime? completedAt,
  });

  /// Retrieve the best completion time for a puzzle type/difficulty.
  Future<Duration?> bestTime(PuzzleType puzzleType, String difficulty);

  /// Whether the given puzzle type is marked complete on [date].
  Future<bool> isCompletedOn(PuzzleType puzzleType, DateTime date);

  /// Current streak for the given puzzle type.
  Future<int> puzzleStreak(PuzzleType puzzleType);

  /// Global streak across all puzzle types.
  Future<int> globalStreak();
}

/// SharedPreferences backed implementation of [PuzzleLocalStore].
class SharedPreferencesPuzzleLocalStore implements PuzzleLocalStore {
  SharedPreferencesPuzzleLocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _storageNamespace = 'puzzle_local_store.v1';
  static const _bestTimePrefix = '$_storageNamespace.best_time';
  static const _dailyCompletionPrefix = '$_storageNamespace.daily_completion';
  static const _puzzleStreakPrefix = '$_storageNamespace.streak';
  static const _puzzleLastCompletionPrefix =
      '$_storageNamespace.last_completion';
  static const _globalStreakKey = '$_storageNamespace.global_streak';
  static const _globalLastCompletionKey =
      '$_storageNamespace.global_last_completion';

  @override
  Future<void> recordCompletion({
    required PuzzleType puzzleType,
    required String difficulty,
    required Duration completionTime,
    required PuzzleMode mode,
    DateTime? completedAt,
  }) async {
    final DateTime timestamp = completedAt ?? DateTime.now();
    // Daily challenges use UTC to ensure the same calendar day globally.
    final DateTime normalizedUtc = _normalizeDate(timestamp.toUtc(), useUtc: true);
    // Streaks and non-daily progress remain tied to the user's local day.
    final DateTime normalizedLocal = _normalizeDate(timestamp);

    await _updateBestTime(puzzleType, difficulty, completionTime);
    if (mode == PuzzleMode.daily) {
      await _saveDailyCompletion(
        puzzleType,
        _dateKey(normalizedUtc),
        timestamp.toUtc(),
      );
    }
    await _updatePuzzleStreak(puzzleType, normalizedLocal);
    await _updateGlobalStreak(normalizedLocal);
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
  Future<bool> isCompletedOn(PuzzleType puzzleType, DateTime date) async {
    final dateKey = _dateKey(_normalizeDate(date, useUtc: date.isUtc));
    final key = _dailyCompletionKey(puzzleType, dateKey);
    return _prefs.containsKey(key);
  }

  @override
  Future<int> puzzleStreak(PuzzleType puzzleType) async {
    final key = _puzzleStreakKey(puzzleType);
    return _prefs.getInt(key) ?? 0;
  }

  @override
  Future<int> globalStreak() async {
    return _prefs.getInt(_globalStreakKey) ?? 0;
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

  Future<void> _saveDailyCompletion(
    PuzzleType puzzleType,
    String dateKey,
    DateTime completedAt,
  ) async {
    final key = _dailyCompletionKey(puzzleType, dateKey);
    await _prefs.setString(key, completedAt.toIso8601String());
  }

  Future<void> _updatePuzzleStreak(
    PuzzleType puzzleType,
    DateTime completionDate,
  ) async {
    final streakKey = _puzzleStreakKey(puzzleType);
    final lastCompletionKey = _puzzleLastCompletionKey(puzzleType);

    final lastDateString = _prefs.getString(lastCompletionKey);
    final lastDate =
        lastDateString != null ? _parseDateKey(lastDateString) : null;
    var streak = _prefs.getInt(streakKey) ?? 0;

    if (lastDate == null) {
      streak = 1;
    } else if (_isSameDay(lastDate, completionDate)) {
      streak = streak == 0 ? 1 : streak;
    } else if (_isNextDay(lastDate, completionDate)) {
      streak += 1;
    } else {
      streak = 1;
    }

    await _prefs.setInt(streakKey, streak);
    await _prefs.setString(lastCompletionKey, _dateKey(completionDate));
  }

  Future<void> _updateGlobalStreak(DateTime completionDate) async {
    final lastDateString = _prefs.getString(_globalLastCompletionKey);
    final lastDate =
        lastDateString != null ? _parseDateKey(lastDateString) : null;
    var streak = _prefs.getInt(_globalStreakKey) ?? 0;

    if (lastDate == null) {
      streak = 1;
    } else if (_isSameDay(lastDate, completionDate)) {
      streak = streak == 0 ? 1 : streak;
    } else if (_isNextDay(lastDate, completionDate)) {
      streak += 1;
    } else {
      streak = 1;
    }

    await _prefs.setInt(_globalStreakKey, streak);
    await _prefs.setString(_globalLastCompletionKey, _dateKey(completionDate));
  }

  String _bestTimeKey(PuzzleType puzzleType, String difficulty) {
    return '$_bestTimePrefix.${puzzleType.key}.$difficulty';
  }

  String _dailyCompletionKey(PuzzleType puzzleType, String dateKey) {
    return '$_dailyCompletionPrefix.${puzzleType.key}.$dateKey';
  }

  String _puzzleStreakKey(PuzzleType puzzleType) {
    return '$_puzzleStreakPrefix.${puzzleType.key}';
  }

  String _puzzleLastCompletionKey(PuzzleType puzzleType) {
    return '$_puzzleLastCompletionPrefix.${puzzleType.key}';
  }

  DateTime _normalizeDate(DateTime date, {bool useUtc = false}) {
    if (useUtc) {
      return DateTime.utc(date.year, date.month, date.day);
    }
    return DateTime(date.year, date.month, date.day);
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime _parseDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid date key: $dateKey');
    }
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    return DateTime(year, month, day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isNextDay(DateTime previous, DateTime current) {
    final previousNextDay = previous.add(const Duration(days: 1));
    return _isSameDay(previousNextDay, current);
  }
}
