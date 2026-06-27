import 'package:app/shared/firestore/firestore_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestorePaths', () {
    test('constructs user document paths', () {
      expect(FirestorePaths.user('uid-123'), 'users/uid-123');
      expect(
        FirestorePaths.userStats(uid: 'uid-123', puzzleType: 'sudoku_classic'),
        'users/uid-123/stats/sudoku_classic',
      );
      expect(
        FirestorePaths.userRun(uid: 'uid-123', runId: 'run-456'),
        'users/uid-123/runs/run-456',
      );
      expect(
        FirestorePaths.dailyStreak('uid-123'),
        'users/uid-123/dailyStreak/state',
      );
    });

    test('constructs leaderboard and config paths', () {
      expect(
        FirestorePaths.leaderboardEntry(
          periodId: '2026-06',
          puzzleType: 'nonogram_mono',
          entryId: 'entry-1',
        ),
        'leaderboards/2026-06/puzzleTypes/nonogram_mono/entries/entry-1',
      );
      expect(FirestorePaths.appConfig(), 'config/appConfig');
    });

    test('rejects unsafe path segments', () {
      expect(() => FirestorePaths.user(''), throwsArgumentError);
      expect(
        () => FirestorePaths.userRun(uid: 'uid-123', runId: 'bad/run'),
        throwsArgumentError,
      );
    });
  });
}
