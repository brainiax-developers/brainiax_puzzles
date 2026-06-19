/// Daily Challenge streak state.
class DailyStreakStatus {
  const DailyStreakStatus({
    required this.currentStreak,
    required this.bestStreak,
    required this.lastCompletedDateKeyUtc,
  });

  final int currentStreak;
  final int bestStreak;
  final String? lastCompletedDateKeyUtc;

  static const empty = DailyStreakStatus(
    currentStreak: 0,
    bestStreak: 0,
    lastCompletedDateKeyUtc: null,
  );
}
