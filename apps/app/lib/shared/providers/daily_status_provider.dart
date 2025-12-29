import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'puzzle_local_store_providers.dart';

DateTime _nowUtc() => DateTime.now().toUtc();

DateTime _todayUtc(DateTime nowUtc) =>
    DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);

Duration _timeUntilNextUtcReset(DateTime nowUtc) {
  final DateTime nextReset =
      DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day + 1);
  final Duration remaining = nextReset.difference(nowUtc);
  return remaining.isNegative ? Duration.zero : remaining;
}

/// Daily completion status for a specific puzzle type.
class DailyStatus {
  const DailyStatus({
    required this.puzzleType,
    required this.isCompleted,
    required this.completedAt,
    required this.timeUntilReset,
  });

  final PuzzleType puzzleType;
  final bool isCompleted;
  final DateTime? completedAt;
  final Duration timeUntilReset;

  /// Get the next reset time (shared UTC midnight).
  DateTime get nextResetTime => _nowUtc().add(timeUntilReset);

  /// Get formatted time until reset (e.g., "2h 15m" or "23m").
  String get formattedTimeUntilReset {
    final hours = timeUntilReset.inHours;
    final minutes = timeUntilReset.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Check if the daily challenge is available (not completed today).
  bool get isAvailable => !isCompleted;

  /// Get the completion percentage for today (0.0 to 1.0).
  double get completionPercentage => isCompleted ? 1.0 : 0.0;
}

/// Overall daily completion status.
class DailyOverallStatus {
  const DailyOverallStatus({
    required this.completedCount,
    required this.totalCount,
    required this.completionPercentage,
    required this.timeUntilReset,
  });

  final int completedCount;
  final int totalCount;
  final double completionPercentage;
  final Duration timeUntilReset;

  /// Get formatted time until reset.
  String get formattedTimeUntilReset {
    final hours = timeUntilReset.inHours;
    final minutes = timeUntilReset.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Check if all puzzles are completed today.
  bool get isAllCompleted => completedCount == totalCount;

  /// Get completion text (e.g., "3 of 5 completed").
  String get completionText => '$completedCount of $totalCount completed';
}

/// List of puzzle types that participate in Daily Challenges.
final dailyPuzzleTypesProvider = Provider<List<PuzzleType>>((ref) {
  return PuzzleType.dailyChallengeTypes;
});

/// Provider for all daily statuses keyed by puzzle type for today's UTC date.
final dailyStatusProvider =
    FutureProvider<Map<PuzzleType, DailyStatus>>((ref) async {
  final DateTime nowUtc = _nowUtc();
  final DateTime todayUtc = _todayUtc(nowUtc);
  final Duration timeUntilReset = _timeUntilNextUtcReset(nowUtc);

  final Map<PuzzleType, DailyStatus> statuses = {};
  for (final puzzleType in ref.watch(dailyPuzzleTypesProvider)) {
    final bool isCompleted = await ref
        .watch(puzzleDailyCompletionProvider((puzzleType, todayUtc)).future);
    statuses[puzzleType] = DailyStatus(
      puzzleType: puzzleType,
      isCompleted: isCompleted,
      completedAt: isCompleted ? todayUtc : null,
      timeUntilReset: timeUntilReset,
    );
  }
  return statuses;
});

/// Provider for overall daily status.
final dailyOverallStatusProvider =
    Provider<AsyncValue<DailyOverallStatus>>((ref) {
  final AsyncValue<Map<PuzzleType, DailyStatus>> statusMap =
      ref.watch(dailyStatusProvider);

  return statusMap.whenData((statuses) {
    final int totalCount = ref.watch(dailyPuzzleTypesProvider).length;
    final int completedCount =
        statuses.values.where((status) => status.isCompleted).length;
    final Duration timeUntilReset = statuses.values.isNotEmpty
        ? statuses.values.first.timeUntilReset
        : _timeUntilNextUtcReset(_nowUtc());
    final double completionPercentage =
        totalCount > 0 ? completedCount / totalCount : 0.0;

    return DailyOverallStatus(
      completedCount: completedCount,
      totalCount: totalCount,
      completionPercentage: completionPercentage,
      timeUntilReset: timeUntilReset,
    );
  });
});

/// Provider for a specific puzzle type's daily status.
final dailyStatusForPuzzleProvider =
    Provider.family<AsyncValue<DailyStatus?>, PuzzleType>((ref, puzzleType) {
  final AsyncValue<Map<PuzzleType, DailyStatus>> statusMap =
      ref.watch(dailyStatusProvider);
  return statusMap.whenData((statuses) => statuses[puzzleType]);
});
