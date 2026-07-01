import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_metadata/app_metadata_providers.dart';
import '../analytics/analytics_providers.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_repository.dart';
import '../crash/crash_reporting_providers.dart';
import '../crash/crash_reporting_service.dart';
import '../firestore/firestore_providers.dart';
import '../models/puzzle_completion_record.dart';
import '../models/puzzle_type.dart';
import '../providers/shared_preferences_provider.dart';
import '../stats/puzzle_run_result.dart';
import '../stats/stats_models.dart';
import '../streak/daily_streak_models.dart';
import 'firestore_sync_repository.dart';
import 'sync_engine.dart';
import 'sync_lifecycle_controller.dart';
import 'sync_queue.dart';
import 'sync_queue_item.dart';
import 'sync_service.dart';
import 'sync_triggers.dart';

final syncQueueProvider = FutureProvider<SyncQueue>((ref) async {
  final SharedPreferences prefs = await ref.watch(
    sharedPreferencesProvider.future,
  );
  return SharedPreferencesSyncQueue(prefs);
});

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final SyncQueue queue = await ref.watch(syncQueueProvider.future);
  return SyncService(queue);
});

final firestoreSyncRepositoryProvider = Provider<SyncRepository?>((ref) {
  final FirebaseFirestore? firestore = ref.watch(firestoreProvider);
  if (firestore == null) {
    return null;
  }
  return FirestoreSyncRepository(
    firestore,
    appMetadata: ref.watch(appBuildMetadataProvider),
  );
});

final syncFailureReporterProvider = Provider<SyncFailureReporter?>((ref) {
  final CrashReportingService crashReporting = ref.watch(
    crashReportingServiceProvider,
  );
  return _CrashReportingSyncFailureReporter(crashReporting);
});

final syncEngineProvider = FutureProvider<SyncEngine?>((ref) async {
  final SyncRepository? repository = ref.watch(firestoreSyncRepositoryProvider);
  if (repository == null) {
    return null;
  }
  final SyncQueue queue = await ref.watch(syncQueueProvider.future);
  final AuthRepository authRepository = ref.watch(authRepositoryProvider);
  final SyncFailureReporter? failureReporter = ref.watch(
    syncFailureReporterProvider,
  );

  return SyncEngine(
    queue: queue,
    repository: repository,
    authRepository: authRepository,
    analyticsService: ref.watch(analyticsServiceProvider),
    failureReporter: failureReporter,
  );
});

final syncTriggersProvider = FutureProvider<SyncTriggers>((ref) async {
  final SyncService service = await ref.watch(syncServiceProvider.future);
  final SyncEngine? engine = await ref.watch(syncEngineProvider.future);
  final SyncFailureReporter? failureReporter = ref.watch(
    syncFailureReporterProvider,
  );
  return SyncTriggers(
    syncService: service,
    syncEngine: engine,
    failureReporter: failureReporter,
  );
});

final syncQueueItemsProvider = FutureProvider<List<SyncQueueItem>>((ref) async {
  final SyncService service = await ref.watch(syncServiceProvider.future);
  return service.all();
});

final pendingSyncQueueItemsProvider = FutureProvider<List<SyncQueueItem>>((
  ref,
) async {
  final SyncService service = await ref.watch(syncServiceProvider.future);
  return service.pending();
});

final failedSyncQueueItemsProvider = FutureProvider<List<SyncQueueItem>>((
  ref,
) async {
  final SyncService service = await ref.watch(syncServiceProvider.future);
  return service.failed();
});

class SyncController {
  SyncController(this._ref);

  final Ref _ref;

  Future<void> enqueue(SyncQueueItem item) async {
    final SyncService service = await _ref.read(syncServiceProvider.future);
    await service.enqueue(item);
    _invalidateQueueProviders();
  }

  Future<void> enqueueCompletionRecord(PuzzleCompletionRecord record) async {
    final SyncService service = await _ref.read(syncServiceProvider.future);
    await service.enqueueCompletionRecord(record);
    _invalidateQueueProviders();
  }

  Future<void> enqueueRunResult(PuzzleRunResult result) async {
    final SyncService service = await _ref.read(syncServiceProvider.future);
    await service.enqueueRunResult(result);
    _invalidateQueueProviders();
  }

  Future<void> enqueueStatsSnapshot(PuzzleStatsAggregate stats) async {
    final SyncService service = await _ref.read(syncServiceProvider.future);
    await service.enqueueStatsSnapshot(stats);
    _invalidateQueueProviders();
  }

  Future<void> enqueueDailyStreakSnapshot(DailyStreakStatus status) async {
    final SyncService service = await _ref.read(syncServiceProvider.future);
    await service.enqueueDailyStreakSnapshot(status);
    _invalidateQueueProviders();
  }

  Future<void> enqueueFavouritesSnapshot(
    List<PuzzleType> favourites, {
    DateTime? createdAtUtc,
  }) async {
    final SyncService service = await _ref.read(syncServiceProvider.future);
    await service.enqueueFavouritesSnapshot(
      favourites,
      createdAtUtc: createdAtUtc,
    );
    _invalidateQueueProviders();
  }

  Future<SyncEngineResult> processPending({int? limit}) async {
    final SyncEngine? engine = await _ref.read(syncEngineProvider.future);
    if (engine == null) {
      return const SyncEngineResult.skipped('firestore-unavailable');
    }

    final SyncEngineResult result = await engine.processPending(limit: limit);
    _invalidateQueueProviders();
    return result;
  }

  Future<SyncEngineResult> retryFailedAndProcessPending({int? limit}) async {
    int retriedFailed = 0;
    bool retryFailed = false;
    String? retryFailureReason;

    try {
      final SyncService service = await _ref.read(syncServiceProvider.future);
      retriedFailed = await service.retryFailed();
    } catch (error, stackTrace) {
      retryFailed = true;
      retryFailureReason = 'retry-failed';
      await _reportFailure(
        error,
        stackTrace,
        operation: 'retry-failed-sync-items',
      );
    } finally {
      _invalidateQueueProviders();
    }

    final SyncEngineResult result = await processPending(limit: limit);
    return result.withRetry(
      retriedFailed: retriedFailed,
      retryFailed: retryFailed,
      retryFailureReason: retryFailureReason,
    );
  }

  Future<void> markSyncing(String id, {DateTime? attemptedAtUtc}) async {
    final SyncService service = await _ref.read(syncServiceProvider.future);
    await service.markSyncing(id, attemptedAtUtc: attemptedAtUtc);
    _invalidateQueueProviders();
  }

  Future<void> markSynced(String id, {DateTime? completedAtUtc}) async {
    final SyncService service = await _ref.read(syncServiceProvider.future);
    await service.markSynced(id, completedAtUtc: completedAtUtc);
    _invalidateQueueProviders();
  }

  Future<void> markFailed(
    String id, {
    String? lastError,
    DateTime? failedAtUtc,
  }) async {
    final SyncService service = await _ref.read(syncServiceProvider.future);
    await service.markFailed(
      id,
      lastError: lastError,
      failedAtUtc: failedAtUtc,
    );
    _invalidateQueueProviders();
  }

  Future<int> retryFailed() async {
    final SyncService service = await _ref.read(syncServiceProvider.future);
    final int retried = await service.retryFailed();
    _invalidateQueueProviders();
    return retried;
  }

  Future<void> _reportFailure(
    Object error,
    StackTrace stackTrace, {
    required String operation,
  }) async {
    final SyncFailureReporter? reporter = _ref.read(
      syncFailureReporterProvider,
    );
    if (reporter == null) {
      return;
    }

    try {
      await reporter.recordSyncFailure(error, stackTrace, operation: operation);
    } catch (_) {
      // Sync retries are best-effort and must never affect local gameplay.
    }
  }

  void _invalidateQueueProviders() {
    _ref.invalidate(syncServiceProvider);
    _ref.invalidate(syncQueueItemsProvider);
    _ref.invalidate(pendingSyncQueueItemsProvider);
    _ref.invalidate(failedSyncQueueItemsProvider);
  }
}

final syncControllerProvider = Provider<SyncController>(SyncController.new);

final syncLifecycleControllerProvider = Provider<SyncLifecycleController>((
  ref,
) {
  final SyncController syncController = ref.watch(syncControllerProvider);
  final SyncFailureReporter? failureReporter = ref.watch(
    syncFailureReporterProvider,
  );
  return SyncLifecycleController(
    retryFailedAndProcessPending: syncController.retryFailedAndProcessPending,
    failureReporter: failureReporter,
  );
});

class _CrashReportingSyncFailureReporter implements SyncFailureReporter {
  const _CrashReportingSyncFailureReporter(this._crashReporting);

  final CrashReportingService _crashReporting;

  @override
  Future<void> recordSyncFailure(
    Object error,
    StackTrace stackTrace, {
    SyncQueueItem? item,
    String? operation,
  }) {
    return _crashReporting.reportNonFatal(
      reason: 'sync_failure',
      error: error,
      stackTrace: stackTrace,
      context: <String, Object?>{
        'operation': operation,
        'syncItemId': item?.id,
        'syncItemType': item?.type.key,
        'syncItemAttempts': item?.attempts,
      },
    );
  }
}
