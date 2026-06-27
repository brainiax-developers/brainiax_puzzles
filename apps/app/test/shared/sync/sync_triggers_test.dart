import 'package:app/shared/models/models.dart';
import 'package:app/shared/stats/stats_models.dart';
import 'package:app/shared/sync/sync_engine.dart';
import 'package:app/shared/sync/sync_queue.dart';
import 'package:app/shared/sync/sync_queue_item.dart';
import 'package:app/shared/sync/sync_service.dart';
import 'package:app/shared/sync/sync_triggers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completion trigger enqueues metadata-only sync items', () async {
    final queue = _RecordingQueue();
    final triggers = SyncTriggers(syncService: SyncService(queue));

    await triggers.afterCompletionRecorded(
      record: PuzzleCompletionRecord(
        id: 'record-1',
        puzzleType: PuzzleType.sudokuClassic,
        mode: PuzzleMode.daily,
        difficulty: 'easy',
        size: '9x9',
        seed: 'local-seed',
        completedAtUtc: DateTime.utc(2026, 6, 21, 12),
        elapsedMs: 90000,
        moveCount: 20,
        hintsUsed: 1,
        dailyDateKeyUtc: '2026-06-21',
      ),
      stats: PuzzleStatsAggregate.empty,
      dailyStreak: const DailyStreakStatus(
        currentStreak: 1,
        bestStreak: 1,
        lastCompletedDateKeyUtc: '2026-06-21',
      ),
    );

    final items = await queue.all();
    expect(items.map((SyncQueueItem item) => item.type), <SyncQueueItemType>[
      SyncQueueItemType.puzzleCompletion,
      SyncQueueItemType.statsSnapshot,
      SyncQueueItemType.dailyStreakSnapshot,
    ]);
    expect(
      items.first.payload.keys.toSet().intersection(<String>{
        'board',
        'cells',
        'grid',
        'generatedPuzzleJson',
        'solution',
        'activeRunState',
        'moves',
      }),
      isEmpty,
    );
  });

  test('trigger queue failures are reported without throwing', () async {
    final reporter = _FakeFailureReporter();
    final triggers = SyncTriggers(
      syncService: SyncService(_FailingQueue()),
      failureReporter: reporter,
    );

    await expectLater(
      triggers.afterFavouritesChanged(<PuzzleType>[PuzzleType.nonogramMono]),
      completes,
    );

    expect(reporter.operations, <String>['favourites-changed']);
  });
}

class _RecordingQueue implements SyncQueue {
  final List<SyncQueueItem> items = <SyncQueueItem>[];

  @override
  Future<void> enqueue(SyncQueueItem item) async {
    items.add(item);
  }

  @override
  Future<List<SyncQueueItem>> all() async {
    return List<SyncQueueItem>.unmodifiable(items);
  }

  @override
  Future<List<SyncQueueItem>> pending() async {
    return List<SyncQueueItem>.unmodifiable(
      items.where(
        (SyncQueueItem item) => item.status == SyncQueueItemStatus.pending,
      ),
    );
  }

  @override
  Future<List<SyncQueueItem>> failed() async {
    return List<SyncQueueItem>.unmodifiable(
      items.where(
        (SyncQueueItem item) => item.status == SyncQueueItemStatus.failed,
      ),
    );
  }

  @override
  Future<void> markSyncing(String id, {DateTime? attemptedAtUtc}) async {}

  @override
  Future<void> markSynced(String id, {DateTime? completedAtUtc}) async {}

  @override
  Future<void> markFailed(
    String id, {
    String? lastError,
    DateTime? failedAtUtc,
  }) async {}

  @override
  Future<int> retryFailed() async => 0;
}

class _FailingQueue extends _RecordingQueue {
  @override
  Future<void> enqueue(SyncQueueItem item) {
    throw StateError('queue unavailable');
  }
}

class _FakeFailureReporter implements SyncFailureReporter {
  final List<String> operations = <String>[];

  @override
  Future<void> recordSyncFailure(
    Object error,
    StackTrace stackTrace, {
    SyncQueueItem? item,
    String? operation,
  }) async {
    operations.add(operation ?? 'unknown');
  }
}
