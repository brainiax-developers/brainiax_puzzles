import 'package:flutter/foundation.dart';

/// Snapshot of completion metrics after solving a puzzle.
@immutable
class PuzzleCompletionStatus {
  const PuzzleCompletionStatus({
    required this.bestTime,
    required this.isDailyCompleted,
    required this.dailyStreak,
    required this.bestDailyStreak,
  });

  /// Best recorded time for the puzzle type/difficulty.
  final Duration? bestTime;

  /// Whether the daily puzzle for the date was completed.
  final bool isDailyCompleted;

  /// Current Daily Challenge streak.
  final int dailyStreak;

  /// Best Daily Challenge streak.
  final int bestDailyStreak;

  @Deprecated('Use dailyStreak. Puzzle-specific streaks are not used in V1.')
  int get puzzleStreak => dailyStreak;

  @Deprecated('Use dailyStreak. Global streaks are not used in V1.')
  int get globalStreak => dailyStreak;
}
