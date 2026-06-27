import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/puzzle_completion_record.dart';
import '../providers/puzzle_local_store_providers.dart';
import 'sync_queue.dart';
import 'sync_queue_item.dart';
import 'sync_service.dart';

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

  void _invalidateQueueProviders() {
    _ref.invalidate(syncServiceProvider);
    _ref.invalidate(syncQueueItemsProvider);
    _ref.invalidate(pendingSyncQueueItemsProvider);
    _ref.invalidate(failedSyncQueueItemsProvider);
  }
}

final syncControllerProvider = Provider<SyncController>(SyncController.new);
