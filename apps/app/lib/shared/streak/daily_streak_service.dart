import '../models/daily_utc_date.dart';
import 'daily_streak_models.dart';

/// Pure streak transition rules for Daily Challenge completion.
///
/// Keep this free of storage, network, and ad-related behavior so local stats
/// and future sync layers can share the same logic.
class DailyStreakService {
  const DailyStreakService();

  DailyStreakStatus recordCompletion({
    required DailyStreakStatus current,
    required DateTime completedAtUtc,
    String? completedDateKeyUtc,
  }) {
    final String resolvedDateKeyUtc =
        completedDateKeyUtc ?? DailyUtcDate.keyFor(completedAtUtc);
    final int currentStreak = _nextCurrentStreak(
      previous: current,
      completedDateKeyUtc: resolvedDateKeyUtc,
    );
    final int bestStreak = currentStreak > current.bestStreak
        ? currentStreak
        : current.bestStreak;

    return DailyStreakStatus(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      lastCompletedDateKeyUtc: resolvedDateKeyUtc,
    );
  }

  DailyStreakStatus normalizeForToday({
    required DailyStreakStatus stored,
    required DateTime nowUtc,
  }) {
    final String? lastCompletedDateKeyUtc = stored.lastCompletedDateKeyUtc;
    if (lastCompletedDateKeyUtc == null) {
      return stored;
    }

    final String todayKey = DailyUtcDate.todayKey(now: nowUtc);
    final String yesterdayKey = DailyUtcDate.keyFor(
      DailyUtcDate.today(now: nowUtc).subtract(const Duration(days: 1)),
    );
    if (lastCompletedDateKeyUtc == todayKey ||
        lastCompletedDateKeyUtc == yesterdayKey) {
      return stored;
    }

    return DailyStreakStatus(
      currentStreak: 0,
      bestStreak: stored.bestStreak,
      lastCompletedDateKeyUtc: lastCompletedDateKeyUtc,
    );
  }

  int _nextCurrentStreak({
    required DailyStreakStatus previous,
    required String completedDateKeyUtc,
  }) {
    final String? lastDateKeyUtc = previous.lastCompletedDateKeyUtc;
    if (lastDateKeyUtc == null) {
      return 1;
    }

    if (lastDateKeyUtc == completedDateKeyUtc) {
      return previous.currentStreak == 0 ? 1 : previous.currentStreak;
    }

    if (DailyUtcDate.isNextDayKey(lastDateKeyUtc, completedDateKeyUtc)) {
      return previous.currentStreak + 1;
    }

    return 1;
  }
}
