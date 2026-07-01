import 'package:app/shared/firestore/firestore_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'firestore document providers return null before Firebase is initialized',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(firestoreProvider), isNull);
      expect(container.read(userProfileDocumentProvider('uid-1')), isNull);
      expect(
        container.read(
          userStatsDocumentProvider((uid: 'uid-1', puzzleType: 'kakuro')),
        ),
        isNull,
      );
      expect(
        container.read(userRunDocumentProvider((uid: 'uid-1', runId: 'run-1'))),
        isNull,
      );
      expect(container.read(userRunsCollectionProvider('uid-1')), isNull);
      expect(container.read(dailyStreakDocumentProvider('uid-1')), isNull);
      expect(
        container.read(
          leaderboardEntryDocumentProvider((
            periodId: '2026-07',
            puzzleType: 'kakuro',
            entryId: 'entry-1',
          )),
        ),
        isNull,
      );
      expect(
        container.read(
          leaderboardEntriesCollectionProvider((
            periodId: '2026-07',
            puzzleType: 'kakuro',
          )),
        ),
        isNull,
      );
      expect(container.read(appConfigDocumentProvider), isNull);
    },
  );
}
