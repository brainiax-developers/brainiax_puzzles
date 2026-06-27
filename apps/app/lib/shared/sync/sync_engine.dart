import '../auth/auth_repository.dart';
import '../auth/user_identity.dart';
import '../models/puzzle_type.dart';
import '../stats/puzzle_run_result.dart';
import '../stats/stats_models.dart';
import '../streak/daily_streak_models.dart';
import 'firestore_sync_repository.dart';
import 'sync_queue.dart';
import 'sync_queue_item.dart';

abstract interface class SyncFailureReporter {
  Future<void> recordSyncFailure(
    Object error,
    StackTrace stackTrace, {
    SyncQueueItem? item,
    String? operation,
  });
}

class SyncEngineResult {
  const SyncEngineResult({
    required this.attempted,
    required this.synced,
    required this.failed,
    this.skippedReason,
  });

  const SyncEngineResult.skipped(String reason)
    : attempted = 0,
      synced = 0,
      failed = 0,
      skippedReason = reason;

  final int attempted;
  final int synced;
  final int failed;
  final String? skippedReason;

  bool get skipped => skippedReason != null;
}

class SyncEngine {
  SyncEngine({
    required SyncQueue queue,
    required SyncRepository repository,
    required AuthRepository authRepository,
    SyncFailureReporter? failureReporter,
    Duration authTimeout = const Duration(seconds: 5),
    DateTime Function()? nowUtc,
  }) : _queue = queue,
       _repository = repository,
       _authRepository = authRepository,
       _failureReporter = failureReporter,
       _authTimeout = authTimeout,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final SyncQueue _queue;
  final SyncRepository _repository;
  final AuthRepository _authRepository;
  final SyncFailureReporter? _failureReporter;
  final Duration _authTimeout;
  final DateTime Function() _nowUtc;

  bool _isProcessing = false;

  Future<SyncEngineResult> processPending({int? limit}) async {
    if (_isProcessing) {
      return const SyncEngineResult.skipped('already-processing');
    }

    _isProcessing = true;
    try {
      final UserIdentity? identity = await _ensureIdentity();
      if (identity == null) {
        return const SyncEngineResult.skipped('auth-unavailable');
      }

      final List<SyncQueueItem> pendingItems = await _queue.pending();
      final List<SyncQueueItem> items = limit == null
          ? pendingItems
          : pendingItems.take(limit).toList();

      if (items.isEmpty) {
        return const SyncEngineResult(attempted: 0, synced: 0, failed: 0);
      }

      try {
        await _repository.ensureUserProfile(identity);
      } catch (error, stackTrace) {
        await _reportFailure(
          error,
          stackTrace,
          operation: 'ensure-user-profile',
        );
        await _markItemsFailed(items, error, failedAtUtc: _nowUtc().toUtc());
        return SyncEngineResult(
          attempted: items.length,
          synced: 0,
          failed: items.length,
        );
      }

      int synced = 0;
      int failed = 0;

      for (final SyncQueueItem item in items) {
        final DateTime attemptedAtUtc = _nowUtc().toUtc();
        try {
          await _queue.markSyncing(item.id, attemptedAtUtc: attemptedAtUtc);
          await _uploadItem(identity.uid, item);
          await _queue.markSynced(item.id, completedAtUtc: _nowUtc().toUtc());
          synced += 1;
        } catch (error, stackTrace) {
          failed += 1;
          await _reportFailure(
            error,
            stackTrace,
            item: item,
            operation: item.type.key,
          );
          await _markItemFailed(item.id, error, failedAtUtc: _nowUtc().toUtc());
        }
      }

      return SyncEngineResult(
        attempted: items.length,
        synced: synced,
        failed: failed,
      );
    } finally {
      _isProcessing = false;
    }
  }

  Future<UserIdentity?> _ensureIdentity() async {
    final UserIdentity? currentIdentity =
        _authRepository.currentAuthState.identity;
    if (currentIdentity != null) {
      return currentIdentity;
    }

    try {
      final authState = await _authRepository.signInAnonymously(
        timeout: _authTimeout,
      );
      return authState.identity;
    } catch (error, stackTrace) {
      await _reportFailure(error, stackTrace, operation: 'anonymous-auth');
      return null;
    }
  }

  Future<void> _uploadItem(String uid, SyncQueueItem item) {
    switch (item.type) {
      case SyncQueueItemType.puzzleCompletion:
        return _repository.uploadRunResult(uid, _runResultFromPayload(item));
      case SyncQueueItemType.statsSnapshot:
        return _repository.upsertStats(uid, _statsAggregateFromPayload(item));
      case SyncQueueItemType.dailyStreakSnapshot:
        return _repository.upsertDailyStreak(
          uid,
          _dailyStreakFromPayload(item),
        );
      case SyncQueueItemType.favouritesUpdate:
        return _repository.upsertFavourites(
          uid,
          _favouritesFromPayload(item),
          updatedAtUtc: _favouritesUpdatedAtUtcFromPayload(item),
        );
    }
  }

  PuzzleRunResult _runResultFromPayload(SyncQueueItem item) {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(
      item.payload,
    );
    payload['id'] ??= payload['recordId'];
    payload['seed'] ??= '';
    return PuzzleRunResult.fromJson(payload);
  }

  PuzzleStatsAggregate _statsAggregateFromPayload(SyncQueueItem item) {
    final Map<String, dynamic> payload = item.payload;
    final Map<String, dynamic> byPuzzleJson = _jsonMap(payload['byPuzzle']);
    final Map<PuzzleType, PuzzleTypeStats> byPuzzle =
        <PuzzleType, PuzzleTypeStats>{};

    for (final MapEntry<String, dynamic> entry in byPuzzleJson.entries) {
      final PuzzleType? puzzleType = PuzzleType.fromKey(entry.key);
      if (puzzleType == null) {
        throw FormatException('Invalid stats puzzle type: ${entry.key}');
      }
      byPuzzle[puzzleType] = _puzzleTypeStatsFromPayload(
        puzzleType,
        _jsonMap(entry.value),
      );
    }

    return PuzzleStatsAggregate(
      totalCompletions: _int(payload['totalCompletions']),
      randomCompletions: _int(payload['randomCompletions']),
      dailyCompletions: _int(payload['dailyCompletions']),
      totalElapsedMs: _int(payload['totalElapsedMs']),
      totalMoveCount: _int(payload['totalMoveCount']),
      totalHintsUsed: _int(payload['totalHintsUsed']),
      firstCompletedAtUtc: _dateTimeOrNull(payload['firstCompletedAtUtc']),
      lastCompletedAtUtc: _dateTimeOrNull(payload['lastCompletedAtUtc']),
      byPuzzle: Map<PuzzleType, PuzzleTypeStats>.unmodifiable(byPuzzle),
    );
  }

  PuzzleTypeStats _puzzleTypeStatsFromPayload(
    PuzzleType puzzleType,
    Map<String, dynamic> payload,
  ) {
    final Map<String, dynamic> byDifficultyJson = _jsonMap(
      payload['byDifficulty'],
    );
    final Map<String, PuzzleDifficultyStats> byDifficulty =
        <String, PuzzleDifficultyStats>{};

    for (final MapEntry<String, dynamic> entry in byDifficultyJson.entries) {
      byDifficulty[entry.key] = _difficultyStatsFromPayload(
        entry.key,
        _jsonMap(entry.value),
      );
    }

    return PuzzleTypeStats(
      puzzleType: puzzleType,
      totalCompletions: _int(payload['totalCompletions']),
      randomCompletions: _int(payload['randomCompletions']),
      dailyCompletions: _int(payload['dailyCompletions']),
      totalElapsedMs: _int(payload['totalElapsedMs']),
      totalMoveCount: _int(payload['totalMoveCount']),
      totalHintsUsed: _int(payload['totalHintsUsed']),
      bestElapsedMs: _nullableInt(payload['bestElapsedMs']),
      firstCompletedAtUtc: _dateTimeOrNull(payload['firstCompletedAtUtc']),
      lastCompletedAtUtc: _dateTimeOrNull(payload['lastCompletedAtUtc']),
      byDifficulty: Map<String, PuzzleDifficultyStats>.unmodifiable(
        byDifficulty,
      ),
    );
  }

  PuzzleDifficultyStats _difficultyStatsFromPayload(
    String fallbackDifficulty,
    Map<String, dynamic> payload,
  ) {
    return PuzzleDifficultyStats(
      difficulty: _stringOrNull(payload['difficulty']) ?? fallbackDifficulty,
      totalCompletions: _int(payload['totalCompletions']),
      randomCompletions: _int(payload['randomCompletions']),
      dailyCompletions: _int(payload['dailyCompletions']),
      totalElapsedMs: _int(payload['totalElapsedMs']),
      totalMoveCount: _int(payload['totalMoveCount']),
      totalHintsUsed: _int(payload['totalHintsUsed']),
      bestElapsedMs: _nullableInt(payload['bestElapsedMs']),
      firstCompletedAtUtc: _dateTimeOrNull(payload['firstCompletedAtUtc']),
      lastCompletedAtUtc: _dateTimeOrNull(payload['lastCompletedAtUtc']),
    );
  }

  DailyStreakStatus _dailyStreakFromPayload(SyncQueueItem item) {
    return DailyStreakStatus(
      currentStreak: _int(item.payload['currentStreak']),
      bestStreak: _int(item.payload['bestStreak']),
      lastCompletedDateKeyUtc: _stringOrNull(
        item.payload['lastCompletedDateKeyUtc'],
      ),
    );
  }

  List<PuzzleType> _favouritesFromPayload(SyncQueueItem item) {
    final List<PuzzleType> favourites = <PuzzleType>[];
    for (final String key in _stringList(
      item.payload['favourites'] ?? item.payload['favoritePuzzleTypes'],
    )) {
      final PuzzleType? puzzleType = PuzzleType.fromKey(key);
      if (puzzleType == null) {
        throw FormatException('Invalid favourite puzzle type: $key');
      }
      if (!favourites.contains(puzzleType)) {
        favourites.add(puzzleType);
      }
    }
    return List<PuzzleType>.unmodifiable(favourites);
  }

  DateTime _favouritesUpdatedAtUtcFromPayload(SyncQueueItem item) {
    final DateTime? updatedAtUtc = _dateTimeOrNull(item.payload['updatedAtUtc']);
    return updatedAtUtc ?? item.createdAtUtc.toUtc();
  }

  Future<void> _markItemsFailed(
    List<SyncQueueItem> items,
    Object error, {
    required DateTime failedAtUtc,
  }) async {
    for (final SyncQueueItem item in items) {
      await _markItemFailed(item.id, error, failedAtUtc: failedAtUtc);
    }
  }

  Future<void> _markItemFailed(
    String id,
    Object error, {
    required DateTime failedAtUtc,
  }) async {
    try {
      await _queue.markFailed(
        id,
        lastError: _errorText(error),
        failedAtUtc: failedAtUtc,
      );
    } catch (markError, stackTrace) {
      await _reportFailure(
        markError,
        stackTrace,
        operation: 'mark-sync-failed',
      );
    }
  }

  Future<void> _reportFailure(
    Object error,
    StackTrace stackTrace, {
    SyncQueueItem? item,
    String? operation,
  }) async {
    final SyncFailureReporter? reporter = _failureReporter;
    if (reporter == null) {
      return;
    }

    try {
      await reporter.recordSyncFailure(
        error,
        stackTrace,
        item: item,
        operation: operation,
      );
    } catch (_) {
      // Failure reporting must never affect local play or queue progress.
    }
  }

  String _errorText(Object error) {
    final String text = error.toString();
    return text.length <= 500 ? text : text.substring(0, 500);
  }
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value == null) {
    return const <String, dynamic>{};
  }
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map<String, dynamic>(
      (dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
  }
  throw FormatException('Expected JSON map: $value');
}

List<String> _stringList(Object? value) {
  if (value == null) {
    return const <String>[];
  }
  if (value is String) {
    return <String>[value];
  }
  if (value is Iterable) {
    return List<String>.unmodifiable(value.map((item) => item.toString()));
  }
  throw FormatException('Expected string list: $value');
}

String? _stringOrNull(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value).toUtc();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  }
  throw FormatException('Invalid date value: $value');
}

int _int(Object? value, {int defaultValue = 0}) {
  if (value == null) {
    return defaultValue;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString()) ?? defaultValue;
}

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _int(value);
}
