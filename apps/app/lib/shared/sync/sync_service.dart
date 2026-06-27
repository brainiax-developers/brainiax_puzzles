import '../models/puzzle_completion_record.dart';
import '../models/puzzle_type.dart';
import '../stats/puzzle_run_result.dart';
import '../stats/stats_models.dart';
import '../streak/daily_streak_models.dart';
import 'sync_queue.dart';
import 'sync_queue_item.dart';

class SyncService {
  const SyncService(this._queue);

  final SyncQueue _queue;

  Future<void> enqueue(SyncQueueItem item) => _queue.enqueue(item);

  Future<void> enqueueCompletionRecord(PuzzleCompletionRecord record) {
    return enqueue(completionQueueItemForRecord(record));
  }

  Future<void> enqueueRunResult(PuzzleRunResult result) {
    return enqueue(runResultQueueItem(result));
  }

  Future<void> enqueueStatsSnapshot(
    PuzzleStatsAggregate stats, {
    DateTime? createdAtUtc,
  }) {
    return enqueue(statsSnapshotQueueItem(stats, createdAtUtc: createdAtUtc));
  }

  Future<void> enqueueDailyStreakSnapshot(
    DailyStreakStatus status, {
    DateTime? createdAtUtc,
  }) {
    return enqueue(
      dailyStreakSnapshotQueueItem(status, createdAtUtc: createdAtUtc),
    );
  }

  Future<void> enqueueFavouritesSnapshot(
    List<PuzzleType> favourites, {
    DateTime? createdAtUtc,
  }) {
    return enqueue(
      favouritesSnapshotQueueItem(favourites, createdAtUtc: createdAtUtc),
    );
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

  SyncQueueItem runResultQueueItem(PuzzleRunResult result) {
    return SyncQueueItem(
      id: 'completion:${result.id}',
      type: SyncQueueItemType.puzzleCompletion,
      payload: result.toJson(),
      createdAtUtc: result.completedAtUtc.toUtc(),
      attempts: 0,
      lastAttemptAtUtc: null,
      status: SyncQueueItemStatus.pending,
      lastError: null,
    );
  }

  SyncQueueItem statsSnapshotQueueItem(
    PuzzleStatsAggregate stats, {
    DateTime? createdAtUtc,
  }) {
    final DateTime resolvedCreatedAt =
        createdAtUtc?.toUtc() ??
        stats.lastCompletedAtUtc?.toUtc() ??
        DateTime.now().toUtc();

    return SyncQueueItem(
      id: <String>[
        'stats',
        stats.totalCompletions.toString(),
        stats.lastCompletedAtUtc?.toUtc().microsecondsSinceEpoch.toString() ??
            'empty',
      ].join(':'),
      type: SyncQueueItemType.statsSnapshot,
      payload: _statsAggregatePayload(stats),
      createdAtUtc: resolvedCreatedAt,
      attempts: 0,
      lastAttemptAtUtc: null,
      status: SyncQueueItemStatus.pending,
      lastError: null,
    );
  }

  SyncQueueItem dailyStreakSnapshotQueueItem(
    DailyStreakStatus status, {
    DateTime? createdAtUtc,
  }) {
    final DateTime resolvedCreatedAt =
        createdAtUtc?.toUtc() ?? DateTime.now().toUtc();

    return SyncQueueItem(
      id: <String>[
        'daily-streak',
        status.currentStreak.toString(),
        status.bestStreak.toString(),
        status.lastCompletedDateKeyUtc ?? 'empty',
      ].join(':'),
      type: SyncQueueItemType.dailyStreakSnapshot,
      payload: <String, dynamic>{
        'currentStreak': status.currentStreak,
        'bestStreak': status.bestStreak,
        'lastCompletedDateKeyUtc': status.lastCompletedDateKeyUtc,
      },
      createdAtUtc: resolvedCreatedAt,
      attempts: 0,
      lastAttemptAtUtc: null,
      status: SyncQueueItemStatus.pending,
      lastError: null,
    );
  }

  SyncQueueItem favouritesSnapshotQueueItem(
    List<PuzzleType> favourites, {
    DateTime? createdAtUtc,
  }) {
    final DateTime resolvedCreatedAt =
        createdAtUtc?.toUtc() ?? DateTime.now().toUtc();
    final List<String> favouriteKeys =
        favourites.map((PuzzleType type) => type.key).toSet().toList()..sort();

    return SyncQueueItem(
      id: 'favourites:${favouriteKeys.isEmpty ? 'empty' : favouriteKeys.join(',')}',
      type: SyncQueueItemType.favouritesSnapshot,
      payload: <String, dynamic>{
        'favourites': favouriteKeys,
        'updatedAtUtc': resolvedCreatedAt.toIso8601String(),
      },
      createdAtUtc: resolvedCreatedAt,
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

Map<String, dynamic> _statsAggregatePayload(PuzzleStatsAggregate stats) {
  return <String, dynamic>{
    'totalCompletions': stats.totalCompletions,
    'randomCompletions': stats.randomCompletions,
    'dailyCompletions': stats.dailyCompletions,
    'totalElapsedMs': stats.totalElapsedMs,
    'totalMoveCount': stats.totalMoveCount,
    'totalHintsUsed': stats.totalHintsUsed,
    'firstCompletedAtUtc': _dateTimeToJson(stats.firstCompletedAtUtc),
    'lastCompletedAtUtc': _dateTimeToJson(stats.lastCompletedAtUtc),
    'byPuzzle': stats.byPuzzle.map<String, dynamic>(
      (PuzzleType key, PuzzleTypeStats value) =>
          MapEntry<String, dynamic>(key.key, _puzzleTypeStatsPayload(value)),
    ),
  };
}

Map<String, dynamic> _puzzleTypeStatsPayload(PuzzleTypeStats stats) {
  return <String, dynamic>{
    'puzzleType': stats.puzzleType.key,
    'totalCompletions': stats.totalCompletions,
    'randomCompletions': stats.randomCompletions,
    'dailyCompletions': stats.dailyCompletions,
    'totalElapsedMs': stats.totalElapsedMs,
    'totalMoveCount': stats.totalMoveCount,
    'totalHintsUsed': stats.totalHintsUsed,
    'bestElapsedMs': stats.bestElapsedMs,
    'firstCompletedAtUtc': _dateTimeToJson(stats.firstCompletedAtUtc),
    'lastCompletedAtUtc': _dateTimeToJson(stats.lastCompletedAtUtc),
    'byDifficulty': stats.byDifficulty.map<String, dynamic>(
      (String key, PuzzleDifficultyStats value) =>
          MapEntry<String, dynamic>(key, _difficultyStatsPayload(value)),
    ),
  };
}

Map<String, dynamic> _difficultyStatsPayload(PuzzleDifficultyStats stats) {
  return <String, dynamic>{
    'difficulty': stats.difficulty,
    'totalCompletions': stats.totalCompletions,
    'randomCompletions': stats.randomCompletions,
    'dailyCompletions': stats.dailyCompletions,
    'totalElapsedMs': stats.totalElapsedMs,
    'totalMoveCount': stats.totalMoveCount,
    'totalHintsUsed': stats.totalHintsUsed,
    'bestElapsedMs': stats.bestElapsedMs,
    'firstCompletedAtUtc': _dateTimeToJson(stats.firstCompletedAtUtc),
    'lastCompletedAtUtc': _dateTimeToJson(stats.lastCompletedAtUtc),
  };
}

String? _dateTimeToJson(DateTime? value) => value?.toUtc().toIso8601String();
