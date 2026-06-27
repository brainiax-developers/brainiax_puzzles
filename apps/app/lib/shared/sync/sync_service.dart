import '../models/puzzle_completion_record.dart';
import 'sync_queue.dart';
import 'sync_queue_item.dart';

class SyncService {
  const SyncService(this._queue);

  final SyncQueue _queue;

  Future<void> enqueue(SyncQueueItem item) => _queue.enqueue(item);

  Future<void> enqueueCompletionRecord(PuzzleCompletionRecord record) {
    return enqueue(completionQueueItemForRecord(record));
  }

  SyncQueueItem completionQueueItemForRecord(PuzzleCompletionRecord record) {
    return SyncQueueItem(
      id: 'completion:${record.id}',
      type: SyncQueueItemType.puzzleCompletion,
      payload: <String, dynamic>{
        'recordId': record.id,
        'puzzleType': record.puzzleType.key,
        'mode': record.mode.key,
        'difficulty': record.difficulty,
        'size': record.size,
        'seed': record.seed,
        'completedAtUtc': record.completedAtUtc.toUtc().toIso8601String(),
        'elapsedMs': record.elapsedMs,
        'moveCount': record.moveCount,
        'hintsUsed': record.hintsUsed,
        'dailyDateKeyUtc': record.dailyDateKeyUtc,
      },
      createdAtUtc: record.completedAtUtc.toUtc(),
      attempts: 0,
      lastAttemptAtUtc: null,
      status: SyncQueueItemStatus.pending,
      lastError: null,
    );
  }

  Future<List<SyncQueueItem>> all() => _queue.all();

  Future<List<SyncQueueItem>> pending() => _queue.pending();

  Future<List<SyncQueueItem>> failed() => _queue.failed();

  Future<void> markSyncing(String id, {DateTime? attemptedAtUtc}) {
    return _queue.markSyncing(id, attemptedAtUtc: attemptedAtUtc);
  }

  Future<void> markSynced(String id, {DateTime? completedAtUtc}) {
    return _queue.markSynced(id, completedAtUtc: completedAtUtc);
  }

  Future<void> markFailed(
    String id, {
    String? lastError,
    DateTime? failedAtUtc,
  }) {
    return _queue.markFailed(
      id,
      lastError: lastError,
      failedAtUtc: failedAtUtc,
    );
  }

  Future<int> retryFailed() => _queue.retryFailed();
}
