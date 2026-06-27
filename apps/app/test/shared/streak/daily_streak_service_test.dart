import 'package:app/shared/models/daily_utc_date.dart';
import 'package:app/shared/streak/daily_streak_models.dart';
import 'package:app/shared/streak/daily_streak_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const DailyStreakService service = DailyStreakService();

  test('keeps same-day completions idempotent and preserves best streak', () {
    const initial = DailyStreakStatus(
      currentStreak: 3,
      bestStreak: 5,
      lastCompletedDateKeyUtc: '2024-03-01',
    );

    final updated = service.recordCompletion(
      current: initial,
      completedAtUtc: DateTime.utc(2024, 3, 1, 23, 59, 59),
    );

    expect(updated.currentStreak, 3);
    expect(updated.bestStreak, 5);
    expect(updated.lastCompletedDateKeyUtc, '2024-03-01');
  });

  test('increments on the next UTC day across a timezone boundary', () {
    final firstCompletion = service.recordCompletion(
      current: DailyStreakStatus.empty,
      completedAtUtc: DateTime.parse('2024-03-01T23:30:00-05:00'),
    );
    final secondCompletion = service.recordCompletion(
      current: firstCompletion,
      completedAtUtc: DateTime.parse('2024-03-02T23:30:00-05:00'),
    );

    expect(
      DailyUtcDate.keyFor(DateTime.parse('2024-03-01T23:30:00-05:00')),
      '2024-03-02',
    );
    expect(firstCompletion.currentStreak, 1);
    expect(firstCompletion.lastCompletedDateKeyUtc, '2024-03-02');
    expect(secondCompletion.currentStreak, 2);
    expect(secondCompletion.bestStreak, 2);
    expect(secondCompletion.lastCompletedDateKeyUtc, '2024-03-03');
  });

  test('resets after a missed day and keeps the best streak', () {
    final day1 = service.recordCompletion(
      current: DailyStreakStatus.empty,
      completedAtUtc: DateTime.utc(2024, 4, 1, 9),
    );
    final day2 = service.recordCompletion(
      current: day1,
      completedAtUtc: DateTime.utc(2024, 4, 2, 9),
    );
    final day4 = service.recordCompletion(
      current: day2,
      completedAtUtc: DateTime.utc(2024, 4, 4, 9),
    );

    expect(day1.currentStreak, 1);
    expect(day2.currentStreak, 2);
    expect(day4.currentStreak, 1);
    expect(day4.bestStreak, 2);
    expect(day4.lastCompletedDateKeyUtc, '2024-04-04');
  });

  test('normalizes stale streaks to zero after the active window passes', () {
    const stored = DailyStreakStatus(
      currentStreak: 7,
      bestStreak: 11,
      lastCompletedDateKeyUtc: '2024-05-01',
    );

    final normalized = service.normalizeForToday(
      stored: stored,
      nowUtc: DateTime.utc(2024, 5, 4, 12),
    );

    expect(normalized.currentStreak, 0);
    expect(normalized.bestStreak, 11);
    expect(normalized.lastCompletedDateKeyUtc, '2024-05-01');
  });
}
