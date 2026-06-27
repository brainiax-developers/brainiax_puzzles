class FirestorePaths {
  const FirestorePaths._();

  static const usersCollection = 'users';
  static const statsCollection = 'stats';
  static const runsCollection = 'runs';
  static const dailyStreakCollection = 'dailyStreak';
  static const dailyStreakDocument = 'state';
  static const leaderboardsCollection = 'leaderboards';
  static const puzzleTypesCollection = 'puzzleTypes';
  static const entriesCollection = 'entries';
  static const configCollection = 'config';
  static const appConfigDocument = 'appConfig';

  static String user(String uid) => '$usersCollection/${_segment(uid)}';

  static String userStatsCollection(String uid) =>
      '${user(uid)}/$statsCollection';

  static String userStats({required String uid, required String puzzleType}) {
    return '${userStatsCollection(uid)}/${_segment(puzzleType)}';
  }

  static String userRunsCollection(String uid) =>
      '${user(uid)}/$runsCollection';

  static String userRun({required String uid, required String runId}) {
    return '${userRunsCollection(uid)}/${_segment(runId)}';
  }

  static String dailyStreak(String uid) {
    return '${user(uid)}/$dailyStreakCollection/$dailyStreakDocument';
  }

  static String leaderboardPeriod(String periodId) {
    return '$leaderboardsCollection/${_segment(periodId)}';
  }

  static String leaderboardPuzzleType({
    required String periodId,
    required String puzzleType,
  }) {
    return '${leaderboardPeriod(periodId)}/$puzzleTypesCollection/'
        '${_segment(puzzleType)}';
  }

  static String leaderboardEntriesCollection({
    required String periodId,
    required String puzzleType,
  }) {
    return '${leaderboardPuzzleType(periodId: periodId, puzzleType: puzzleType)}/$entriesCollection';
  }

  static String leaderboardEntry({
    required String periodId,
    required String puzzleType,
    required String entryId,
  }) {
    return '${leaderboardEntriesCollection(periodId: periodId, puzzleType: puzzleType)}/${_segment(entryId)}';
  }

  static String appConfig() => '$configCollection/$appConfigDocument';

  static String _segment(String value) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, 'value', 'Path segment is empty.');
    }
    if (value.contains('/')) {
      throw ArgumentError.value(
        value,
        'value',
        'Path segment must not contain "/".',
      );
    }
    return value;
  }
}
