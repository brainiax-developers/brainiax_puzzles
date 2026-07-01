import 'dart:async';

import '../models/puzzle_completion_record.dart';
import '../models/puzzle_type.dart';
import '../stats/stats_models.dart';
import '../streak/daily_streak_models.dart';
import 'sync_engine.dart';
import 'sync_service.dart';

class SyncTriggers {
  SyncTriggers({
    required SyncService syncService,
    SyncEngine? syncEngine,
    SyncFailureReporter? failureReporter,
  }) : _syncService = syncService,
       _syncEngine = syncEngine,
       _failureReporter = failureReporter;

  final SyncService _syncService;
  final SyncEngine? _syncEngine;
  final SyncFailureReporter? _failureReporter;

  Future<void> afterCompletionRecorded({
    required PuzzleCompletionRecord record,
    required PuzzleStatsAggregate stats,
    required DailyStreakStatus dailyStreak,
  }) {
    return _guard('completion-recorded', () async {
      await _syncService.enqueueCompletionRecord(record);
      await _syncService.enqueueStatsSnapshot(stats);
      await _syncService.enqueueDailyStreakSnapshot(dailyStreak);
    });
  }

  Future<void> afterStatsChanged(PuzzleStatsAggregate stats) {
    return _guard('stats-changed', () {
      return _syncService.enqueueStatsSnapshot(stats);
    });
  }

  Future<void> afterDailyStreakChanged(DailyStreakStatus status) {
    return _guard('daily-streak-changed', () {
      return _syncService.enqueueDailyStreakSnapshot(status);
    });
  }

  Future<void> afterFavouritesChanged(List<PuzzleType> favourites) {
    return _guard('favourites-changed', () {
      return _syncService.enqueueFavouritesSnapshot(favourites);
    });
  }

  Future<void> flushPending() async {
    await _retryFailedAndProcessPending('trigger-flush');
  }

  Future<void> _retryFailedAndProcessPending(String operation) async {
    final SyncEngine? engine = _syncEngine;
    if (engine == null) {
      return;
    }
    try {
      await _syncService.retryFailed();
    } catch (error, stackTrace) {
      await _reportFailure(
        error,
        stackTrace,
        operation: '$operation-retry-failed-sync-items',
      );
    }
    await engine.processPending();
  }

  Future<void> _guard(String operation, Future<void> Function() action) async {
    try {
      await action();
      _startEngine(operation);
    } catch (error, stackTrace) {
      await _reportFailure(error, stackTrace, operation: operation);
    }
  }

  void _startEngine(String operation) {
    final SyncEngine? engine = _syncEngine;
    if (engine == null) {
      return;
    }

    unawaited(
      _retryFailedAndProcessPending('$operation-background-sync').catchError((
        Object error,
        StackTrace stackTrace,
      ) async {
        await _reportFailure(
          error,
          stackTrace,
          operation: '$operation-background-sync',
        );
      }),
    );
  }

  Future<void> _reportFailure(
    Object error,
    StackTrace stackTrace, {
    required String operation,
  }) async {
    final SyncFailureReporter? reporter = _failureReporter;
    if (reporter == null) {
      // TODO(BX-0415): Route sync trigger failures to Crashlytics.
      return;
    }

    try {
      await reporter.recordSyncFailure(error, stackTrace, operation: operation);
    } catch (_) {
      // Reporting must never turn sync into a local gameplay dependency.
    }
  }
}
