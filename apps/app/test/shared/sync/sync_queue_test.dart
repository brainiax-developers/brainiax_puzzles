import 'package:app/shared/sync/sync_queue.dart';
import 'package:app/shared/sync/sync_queue_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SharedPreferencesSyncQueue queue;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    queue = SharedPreferencesSyncQueue(prefs);
  });

  test('enqueue stores pending items in deterministic order', () async {
    await queue.enqueue(
      _item(id: 'second', createdAtUtc: DateTime.utc(2026, 6, 21, 9, 5)),
    );
    await queue.enqueue(
      _item(id: 'first', createdAtUtc: DateTime.utc(2026, 6, 21, 9)),
    );

    final List<SyncQueueItem> pending = await queue.pending();

    expect(pending.map((item) => item.id), <String>['first', 'second']);
    expect(
      pending.every((item) => item.status == SyncQueueItemStatus.pending),
      isTrue,
    );
  });

  test('duplicate enqueue is idempotent by item id', () async {
    await queue.enqueue(
      _item(id: 'completion:123', payload: <String, dynamic>{'seed': 'alpha'}),
    );
    await queue.enqueue(
      _item(
        id: 'completion:123',
        payload: <String, dynamic>{'seed': 'beta'},
        createdAtUtc: DateTime.utc(2026, 6, 21, 11),
      ),
    );

    final List<SyncQueueItem> items = await queue.all();

    expect(items, hasLength(1));
    expect(items.single.payload['seed'], 'alpha');
  });

  test('mark syncing increments attempts and clears stale errors', () async {
    final DateTime failedAtUtc = DateTime.utc(2026, 6, 21, 9, 20);
    final DateTime attemptedAtUtc = DateTime.utc(2026, 6, 21, 9, 25);

    await queue.enqueue(_item(id: 'completion:syncing'));
    await queue.markFailed(
      'completion:syncing',
      failedAtUtc: failedAtUtc,
      lastError: 'network unavailable',
    );
    await queue.markSyncing(
      'completion:syncing',
      attemptedAtUtc: attemptedAtUtc,
    );

    final SyncQueueItem item = (await queue.all()).single;

    expect(item.status, SyncQueueItemStatus.syncing);
    expect(item.attempts, 2);
    expect(item.lastAttemptAtUtc, attemptedAtUtc);
    expect(item.lastError, isNull);
    expect(await queue.pending(), isEmpty);
    expect(await queue.failed(), isEmpty);
  });

  test('mark synced moves the item out of pending and failed views', () async {
    final DateTime attemptedAtUtc = DateTime.utc(2026, 6, 21, 9, 30);

    await queue.enqueue(_item(id: 'completion:1'));
    await queue.markSyncing('completion:1', attemptedAtUtc: attemptedAtUtc);
    await queue.markSynced('completion:1', completedAtUtc: attemptedAtUtc);

    final SyncQueueItem item = (await queue.all()).single;

    expect(item.status, SyncQueueItemStatus.synced);
    expect(item.attempts, 1);
    expect(item.lastAttemptAtUtc, attemptedAtUtc);
    expect(item.lastError, isNull);
    expect(await queue.pending(), isEmpty);
    expect(await queue.failed(), isEmpty);
  });

  test('mark failed preserves the item and error details', () async {
    final DateTime attemptedAtUtc = DateTime.utc(2026, 6, 21, 9, 45);

    await queue.enqueue(_item(id: 'completion:2'));
    await queue.markSyncing('completion:2', attemptedAtUtc: attemptedAtUtc);
    await queue.markFailed(
      'completion:2',
      failedAtUtc: attemptedAtUtc,
      lastError: 'timeout',
    );

    final SyncQueueItem failedItem = (await queue.failed()).single;

    expect(failedItem.status, SyncQueueItemStatus.failed);
    expect(failedItem.attempts, 1);
    expect(failedItem.lastAttemptAtUtc, attemptedAtUtc);
    expect(failedItem.lastError, 'timeout');
  });

  test(
    'retry failed resets failed items to pending without losing attempts',
    () async {
      final DateTime attemptedAtUtc = DateTime.utc(2026, 6, 21, 10);

      await queue.enqueue(_item(id: 'completion:retry'));
      await queue.markFailed(
        'completion:retry',
        failedAtUtc: attemptedAtUtc,
        lastError: 'server-unavailable',
      );

      final int retried = await queue.retryFailed();
      final SyncQueueItem retriedItem = (await queue.pending()).single;

      expect(retried, 1);
      expect(await queue.failed(), isEmpty);
      expect(retriedItem.status, SyncQueueItemStatus.pending);
      expect(retriedItem.attempts, 1);
      expect(retriedItem.lastAttemptAtUtc, attemptedAtUtc);
      expect(retriedItem.lastError, isNull);
    },
  );

  test('corrupted json is cleared and recovered as an empty queue', () async {
    await prefs.setString(SharedPreferencesSyncQueue.storageKey, '{bad json');

    final List<SyncQueueItem> items = await queue.all();

    expect(items, isEmpty);
    expect(prefs.getString(SharedPreferencesSyncQueue.storageKey), isNull);
  });
}

SyncQueueItem _item({
  required String id,
  DateTime? createdAtUtc,
  Map<String, dynamic>? payload,
}) {
  return SyncQueueItem(
    id: id,
    type: SyncQueueItemType.puzzleCompletion,
    payload: payload ?? <String, dynamic>{'recordId': id},
    createdAtUtc: createdAtUtc ?? DateTime.utc(2026, 6, 21, 9),
    attempts: 0,
    lastAttemptAtUtc: null,
    status: SyncQueueItemStatus.pending,
    lastError: null,
  );
}
