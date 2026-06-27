import 'package:app/shared/models/models.dart';
import 'package:app/shared/providers/puzzle_local_store_providers.dart';
import 'package:app/shared/sync/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sync providers refresh after enqueue and retry operations', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(AsyncValue.data(prefs)),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(pendingSyncQueueItemsProvider.future), isEmpty);

    final PuzzleCompletionRecord record = PuzzleCompletionRecord(
      id: 'provider-record',
      puzzleType: PuzzleType.takuzuBinary,
      mode: PuzzleMode.random,
      difficulty: 'medium',
      size: '8x8',
      seed: 'provider-seed',
      completedAtUtc: DateTime.utc(2026, 6, 21, 14),
      elapsedMs: 15000,
      moveCount: 20,
      hintsUsed: 1,
      dailyDateKeyUtc: null,
    );

    await container
        .read(syncControllerProvider)
        .enqueueCompletionRecord(record);

    final pendingAfterEnqueue = await container.read(
      pendingSyncQueueItemsProvider.future,
    );
    expect(pendingAfterEnqueue, hasLength(1));

    await container
        .read(syncControllerProvider)
        .markFailed(
          pendingAfterEnqueue.single.id,
          lastError: 'offline',
          failedAtUtc: DateTime.utc(2026, 6, 21, 14, 5),
        );

    final failedAfterMark = await container.read(
      failedSyncQueueItemsProvider.future,
    );
    expect(failedAfterMark, hasLength(1));
    expect(failedAfterMark.single.lastError, 'offline');

    final int retried = await container
        .read(syncControllerProvider)
        .retryFailed();
    final pendingAfterRetry = await container.read(
      pendingSyncQueueItemsProvider.future,
    );

    expect(retried, 1);
    expect(await container.read(failedSyncQueueItemsProvider.future), isEmpty);
    expect(pendingAfterRetry, hasLength(1));
    expect(pendingAfterRetry.single.lastError, isNull);
  });
}
