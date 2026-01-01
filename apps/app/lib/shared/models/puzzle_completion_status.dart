import 'package:flutter/foundation.dart';

/// Snapshot of completion metrics after solving a puzzle.
@immutable
class PuzzleCompletionStatus {
  const PuzzleCompletionStatus({
    required this.bestTime,
    required this.isDailyCompleted,
    required this.puzzleStreak,
    required this.globalStreak,
  });

  /// Best recorded time for the puzzle type/difficulty.
  final Duration? bestTime;

  /// Whether the daily puzzle for the date was completed.
  final bool isDailyCompleted;

  /// Current streak for the puzzle type.
  final int puzzleStreak;

  /// Current global streak across all puzzles.
  final int globalStreak;
}
