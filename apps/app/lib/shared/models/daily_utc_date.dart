/// Canonical UTC day helpers for Daily Challenges.
class DailyUtcDate {
  const DailyUtcDate._();

  static DateTime today({DateTime? now}) {
    final DateTime utcNow = (now ?? DateTime.now()).toUtc();
    return DateTime.utc(utcNow.year, utcNow.month, utcNow.day);
  }

  static String todayKey({DateTime? now}) => keyFor(now ?? DateTime.now());

  static String keyFor(DateTime date) {
    final DateTime utc = date.toUtc();
    return keyForUtcParts(utc.year, utc.month, utc.day);
  }

  static String keyForUtcParts(int year, int month, int day) {
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  static DateTime parseKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid UTC date key: $key');
    }
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static DateTime nextReset({DateTime? now}) {
    final DateTime todayUtc = today(now: now);
    return DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day + 1);
  }

  static Duration timeUntilReset({DateTime? now}) {
    final DateTime utcNow = (now ?? DateTime.now()).toUtc();
    final Duration remaining = nextReset(now: utcNow).difference(utcNow);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static bool isNextDayKey(String previousKey, String currentKey) {
    final DateTime previous = parseKey(previousKey);
    final DateTime current = parseKey(currentKey);
    return previous.add(const Duration(days: 1)) == current;
  }
}
