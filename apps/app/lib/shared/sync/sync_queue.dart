import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sync_queue_item.dart';

abstract class SyncQueue {
  Future<void> enqueue(SyncQueueItem item);

  Future<List<SyncQueueItem>> all();

  Future<List<SyncQueueItem>> pending();

  Future<List<SyncQueueItem>> failed();

  Future<void> markSyncing(String id, {DateTime? attemptedAtUtc});

  Future<void> markSynced(String id, {DateTime? completedAtUtc});

  Future<void> markFailed(
    String id, {
    String? lastError,
    DateTime? failedAtUtc,
  });

  Future<int> retryFailed();
}

class SharedPreferencesSyncQueue implements SyncQueue {
  SharedPreferencesSyncQueue(this._prefs);

  final SharedPreferences _prefs;

  static const String storageNamespace = 'sync_queue.v1';
  static const String storageKey = '$storageNamespace.items';

  @override
  Future<void> enqueue(SyncQueueItem item) async {
    final List<SyncQueueItem> items = List<SyncQueueItem>.from(
      await _readItems(),
    );
    if (items.any((existing) => existing.id == item.id)) {
      return;
    }

    items.add(
      item.copyWith(
        createdAtUtc: item.createdAtUtc,
        lastAttemptAtUtc: item.lastAttemptAtUtc,
      ),
    );
    await _writeItems(items);
  }

  @override
  Future<List<SyncQueueItem>> all() async {
    return List<SyncQueueItem>.unmodifiable(await _readItems());
  }

  @override
  Future<List<SyncQueueItem>> pending() async {
    return List<SyncQueueItem>.unmodifiable(
      (await _readItems()).where(
        (item) => item.status == SyncQueueItemStatus.pending,
      ),
    );
  }

  @override
  Future<List<SyncQueueItem>> failed() async {
    return List<SyncQueueItem>.unmodifiable(
      (await _readItems()).where(
        (item) => item.status == SyncQueueItemStatus.failed,
      ),
    );
  }

  @override
  Future<void> markSyncing(String id, {DateTime? attemptedAtUtc}) {
    return _updateItem(
      id,
      (item) => item.copyWith(
        attempts: item.attempts + 1,
        lastAttemptAtUtc: (attemptedAtUtc ?? DateTime.now()).toUtc(),
        status: SyncQueueItemStatus.syncing,
        clearLastError: true,
      ),
    );
  }

  @override
  Future<void> markSynced(String id, {DateTime? completedAtUtc}) {
    return _updateItem(
      id,
      (item) => _completeAttempt(
        item,
        status: SyncQueueItemStatus.synced,
        attemptedAtUtc: completedAtUtc,
      ),
    );
  }

  @override
  Future<void> markFailed(
    String id, {
    String? lastError,
    DateTime? failedAtUtc,
  }) {
    return _updateItem(
      id,
      (item) => _completeAttempt(
        item,
        status: SyncQueueItemStatus.failed,
        attemptedAtUtc: failedAtUtc,
        lastError: lastError,
      ),
    );
  }

  @override
  Future<int> retryFailed() async {
    final List<SyncQueueItem> items = await _readItems();
    int retriedCount = 0;

    final List<SyncQueueItem> updated = items.map((item) {
      if (item.status != SyncQueueItemStatus.failed) {
        return item;
      }
      retriedCount += 1;
      return item.copyWith(
        status: SyncQueueItemStatus.pending,
        clearLastError: true,
      );
    }).toList();

    if (retriedCount > 0) {
      await _writeItems(updated);
    }

    return retriedCount;
  }

  Future<List<SyncQueueItem>> _readItems() async {
    final String? encoded = _prefs.getString(storageKey);
    if (encoded == null || encoded.isEmpty) {
      return const <SyncQueueItem>[];
    }

    try {
      final List<dynamic> rawItems = jsonDecode(encoded) as List<dynamic>;
      final List<SyncQueueItem> items = rawItems
          .map(
            (entry) =>
                SyncQueueItem.fromJson(Map<String, dynamic>.from(entry as Map)),
          )
          .toList();
      return _sortedItems(items);
    } catch (_) {
      await _prefs.remove(storageKey);
      return const <SyncQueueItem>[];
    }
  }

  Future<void> _writeItems(List<SyncQueueItem> items) async {
    final List<SyncQueueItem> sorted = _sortedItems(items);
    await _prefs.setString(
      storageKey,
      jsonEncode(sorted.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _updateItem(
    String id,
    SyncQueueItem Function(SyncQueueItem item) update,
  ) async {
    final List<SyncQueueItem> items = await _readItems();
    bool found = false;
    final List<SyncQueueItem> updated = items.map((item) {
      if (item.id != id) {
        return item;
      }
      found = true;
      return update(item);
    }).toList();

    if (!found) {
      return;
    }

    await _writeItems(updated);
  }

  SyncQueueItem _completeAttempt(
    SyncQueueItem item, {
    required SyncQueueItemStatus status,
    required DateTime? attemptedAtUtc,
    String? lastError,
  }) {
    final DateTime resolvedAttemptAt = (attemptedAtUtc ?? DateTime.now())
        .toUtc();
    final bool needsAttemptIncrement =
        item.status != SyncQueueItemStatus.syncing;

    return item.copyWith(
      attempts: needsAttemptIncrement ? item.attempts + 1 : item.attempts,
      lastAttemptAtUtc: resolvedAttemptAt,
      status: status,
      lastError: lastError,
      clearLastError: lastError == null,
    );
  }

  List<SyncQueueItem> _sortedItems(List<SyncQueueItem> items) {
    final List<SyncQueueItem> sorted = List<SyncQueueItem>.from(items);
    sorted.sort((a, b) {
      final int createdAtComparison = a.createdAtUtc.compareTo(b.createdAtUtc);
      if (createdAtComparison != 0) {
        return createdAtComparison;
      }
      return a.id.compareTo(b.id);
    });
    return sorted;
  }
}
