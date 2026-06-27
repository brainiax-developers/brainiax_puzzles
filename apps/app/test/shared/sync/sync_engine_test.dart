import 'package:app/shared/auth/auth_repository.dart';
import 'package:app/shared/auth/auth_state.dart';
import 'package:app/shared/auth/user_identity.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/stats/puzzle_run_result.dart';
import 'package:app/shared/stats/stats_models.dart';
import 'package:app/shared/sync/firestore_sync_repository.dart';
import 'package:app/shared/sync/sync_engine.dart';
import 'package:app/shared/sync/sync_queue.dart';
import 'package:app/shared/sync/sync_queue_item.dart';
import 'package:app/shared/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'auth failure exits gracefully and leaves pending items untouched',
    () async {
      final queue = _FakeSyncQueue(<SyncQueueItem>[
        _completionItem(queueId: 'completion:run-1', runId: 'run-1'),
      ]);
      final repository = _FakeSyncRepository();
      final reporter = _FakeFailureReporter();
      final authRepository = _FakeAuthRepository(
        currentState: const AuthState.signedOut(),
        signInError: StateError('offline'),
      );
      final engine = SyncEngine(
        queue: queue,
        repository: repository,
        authRepository: authRepository,
        failureReporter: reporter,
        nowUtc: () => DateTime.utc(2026, 6, 21, 12),
      );

      final result = await engine.processPending();
      final item = (await queue.all()).single;

      expect(result.skipped, isTrue);
      expect(result.skippedReason, 'auth-unavailable');
      expect(authRepository.signInCalls, 1);
      expect(repository.uploadRunCalls, 0);
      expect(item.status, SyncQueueItemStatus.pending);
      expect(item.attempts, 0);
      expect(reporter.operations, contains('anonymous-auth'));
    },
  );

  test(
    'duplicate run payloads upsert one deterministic remote document',
    () async {
      final queue = _FakeSyncQueue(<SyncQueueItem>[
        _completionItem(queueId: 'completion:run-1:a', runId: 'run-1'),
        _completionItem(queueId: 'completion:run-1:b', runId: 'run-1'),
      ]);
      final repository = _FakeSyncRepository();
      final engine = SyncEngine(
        queue: queue,
        repository: repository,
        authRepository: _authenticatedRepository(),
        nowUtc: () => DateTime.utc(2026, 6, 21, 12),
      );

      final result = await engine.processPending();

      expect(result.attempted, 2);
      expect(result.synced, 2);
      expect(result.failed, 0);
      expect(repository.ensureProfileCalls, 1);
      expect(repository.uploadRunCalls, 2);
      expect(repository.runDocuments.keys, <String>['run-1']);
      expect(
        (await queue.all()).map((SyncQueueItem item) => item.status),
        everyElement(SyncQueueItemStatus.synced),
      );
    },
  );

  test(
    'upload failure marks item failed without mutating queued payload',
    () async {
      final Map<String, dynamic> payload = _completionPayload('run-fails');
      final queue = _FakeSyncQueue(<SyncQueueItem>[
        _item(
          id: 'completion:run-fails',
          type: SyncQueueItemType.puzzleCompletion,
          payload: payload,
        ),
      ]);
      final reporter = _FakeFailureReporter();
      final engine = SyncEngine(
        queue: queue,
        repository: _FakeSyncRepository(failRunUploads: true),
        authRepository: _authenticatedRepository(),
        failureReporter: reporter,
        nowUtc: () => DateTime.utc(2026, 6, 21, 12),
      );

      final result = await engine.processPending();
      final item = (await queue.all()).single;

      expect(result.failed, 1);
      expect(item.status, SyncQueueItemStatus.failed);
      expect(item.attempts, 1);
      expect(item.payload, payload);
      expect(item.lastError, contains('run upload failed'));
      expect(
        reporter.operations,
        contains(SyncQueueItemType.puzzleCompletion.key),
      );
    },
  );

  test('processes stats, daily streak, and favourites snapshots', () async {
    final queue = _FakeSyncQueue();
    final service = SyncService(queue);
    final stats = _statsAggregate();
    await service.enqueueStatsSnapshot(
      stats,
      createdAtUtc: DateTime.utc(2026, 6, 21, 12),
    );
    await service.enqueueDailyStreakSnapshot(
      const DailyStreakStatus(
        currentStreak: 3,
        bestStreak: 5,
        lastCompletedDateKeyUtc: '2026-06-21',
      ),
      createdAtUtc: DateTime.utc(2026, 6, 21, 12),
    );
    await service.enqueueFavouritesSnapshot(<PuzzleType>[
      PuzzleType.nonogramMono,
      PuzzleType.sudokuClassic,
    ], createdAtUtc: DateTime.utc(2026, 6, 21, 12));
    final repository = _FakeSyncRepository();
    final engine = SyncEngine(
      queue: queue,
      repository: repository,
      authRepository: _authenticatedRepository(),
      nowUtc: () => DateTime.utc(2026, 6, 21, 12),
    );

    final result = await engine.processPending();

    expect(result.synced, 3);
    expect(repository.statsUploads.single.totalCompletions, 1);
    expect(repository.statsUploads.single.byPuzzle.keys, <PuzzleType>[
      PuzzleType.sudokuClassic,
    ]);
    expect(repository.dailyStreak?.currentStreak, 3);
    expect(repository.favourites, <PuzzleType>[
      PuzzleType.nonogramMono,
      PuzzleType.sudokuClassic,
    ]);
    expect(
      repository.favouritesUpdatedAtUtc,
      DateTime.utc(2026, 6, 21, 12),
    );
    expect(await queue.failed(), isEmpty);
  });
}

AuthRepository _authenticatedRepository() {
  return _FakeAuthRepository(
    currentState: const AuthState.authenticated(
      UserIdentity(uid: 'uid-123', isAnonymous: true),
    ),
  );
}

SyncQueueItem _completionItem({
  required String queueId,
  required String runId,
}) {
  return _item(
    id: queueId,
    type: SyncQueueItemType.puzzleCompletion,
    payload: _completionPayload(runId),
  );
}

Map<String, dynamic> _completionPayload(String runId) {
  return <String, dynamic>{
    'recordId': runId,
    'puzzleType': PuzzleType.sudokuClassic.key,
    'mode': PuzzleMode.daily.key,
    'difficulty': 'easy',
    'size': '9x9',
    'seed': 'local-seed',
    'completedAtUtc': '2026-06-21T12:00:00.000Z',
    'elapsedMs': 90000,
    'moveCount': 20,
    'hintsUsed': 1,
    'dailyDateKeyUtc': '2026-06-21',
  };
}

SyncQueueItem _item({
  required String id,
  required SyncQueueItemType type,
  required Map<String, dynamic> payload,
}) {
  return SyncQueueItem(
    id: id,
    type: type,
    payload: payload,
    createdAtUtc: DateTime.utc(2026, 6, 21, 12),
    attempts: 0,
    lastAttemptAtUtc: null,
    status: SyncQueueItemStatus.pending,
    lastError: null,
  );
}

PuzzleStatsAggregate _statsAggregate() {
  final completedAt = DateTime.utc(2026, 6, 21, 12);
  return PuzzleStatsAggregate(
    totalCompletions: 1,
    randomCompletions: 0,
    dailyCompletions: 1,
    totalElapsedMs: 90000,
    totalMoveCount: 20,
    totalHintsUsed: 1,
    firstCompletedAtUtc: completedAt,
    lastCompletedAtUtc: completedAt,
    byPuzzle: <PuzzleType, PuzzleTypeStats>{
      PuzzleType.sudokuClassic: PuzzleTypeStats(
        puzzleType: PuzzleType.sudokuClassic,
        totalCompletions: 1,
        randomCompletions: 0,
        dailyCompletions: 1,
        totalElapsedMs: 90000,
        totalMoveCount: 20,
        totalHintsUsed: 1,
        bestElapsedMs: 90000,
        firstCompletedAtUtc: completedAt,
        lastCompletedAtUtc: completedAt,
        byDifficulty: <String, PuzzleDifficultyStats>{
          'easy': PuzzleDifficultyStats(
            difficulty: 'easy',
            totalCompletions: 1,
            randomCompletions: 0,
            dailyCompletions: 1,
            totalElapsedMs: 90000,
            totalMoveCount: 20,
            totalHintsUsed: 1,
            bestElapsedMs: 90000,
            firstCompletedAtUtc: completedAt,
            lastCompletedAtUtc: completedAt,
          ),
        },
      ),
    },
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required AuthState currentState, this.signInError})
    : _currentState = currentState;

  final Object? signInError;

  final AuthState _currentState;
  int signInCalls = 0;

  @override
  AuthState get currentAuthState => _currentState;

  @override
  Stream<AuthState> authStateChanges() =>
      Stream<AuthState>.value(_currentState);

  @override
  Future<AuthState> signInAnonymously({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    signInCalls += 1;
    if (signInError != null) {
      throw signInError!;
    }
    return _currentState;
  }

  @override
  Future<GoogleSignInResult> signInWithGoogle() async {
    return GoogleSignInResult.signedIn(_currentState);
  }
}

class _FakeSyncRepository implements SyncRepository {
  _FakeSyncRepository({this.failRunUploads = false});

  final bool failRunUploads;

  int ensureProfileCalls = 0;
  int uploadRunCalls = 0;
  final Map<String, PuzzleRunResult> runDocuments = <String, PuzzleRunResult>{};
  final List<PuzzleStatsAggregate> statsUploads = <PuzzleStatsAggregate>[];
  DailyStreakStatus? dailyStreak;
  List<PuzzleType>? favourites;
  DateTime? favouritesUpdatedAtUtc;

  @override
  Future<void> ensureUserProfile(UserIdentity identity) async {
    ensureProfileCalls += 1;
  }

  @override
  Future<void> uploadRunResult(String uid, PuzzleRunResult result) async {
    uploadRunCalls += 1;
    if (failRunUploads) {
      throw StateError('run upload failed');
    }
    runDocuments[result.id] = result;
  }

  @override
  Future<void> upsertStats(String uid, PuzzleStatsAggregate stats) async {
    statsUploads.add(stats);
  }

  @override
  Future<void> upsertDailyStreak(String uid, DailyStreakStatus status) async {
    dailyStreak = status;
  }

  @override
  Future<void> upsertFavourites(
    String uid,
    List<PuzzleType> favourites, {
    required DateTime updatedAtUtc,
  }) async {
    this.favourites = List<PuzzleType>.unmodifiable(favourites);
    favouritesUpdatedAtUtc = updatedAtUtc.toUtc();
  }
}

class _FakeFailureReporter implements SyncFailureReporter {
  final List<String?> operations = <String?>[];

  @override
  Future<void> recordSyncFailure(
    Object error,
    StackTrace stackTrace, {
    SyncQueueItem? item,
    String? operation,
  }) async {
    operations.add(operation);
  }
}

class _FakeSyncQueue implements SyncQueue {
  _FakeSyncQueue([List<SyncQueueItem>? items])
    : _items = List<SyncQueueItem>.from(items ?? const <SyncQueueItem>[]);

  final List<SyncQueueItem> _items;

  @override
  Future<void> enqueue(SyncQueueItem item) async {
    if (_items.any((SyncQueueItem existing) => existing.id == item.id)) {
      return;
    }
    _items.add(item);
  }

  @override
  Future<List<SyncQueueItem>> all() async {
    return List<SyncQueueItem>.unmodifiable(_items);
  }

  @override
  Future<List<SyncQueueItem>> pending() async {
    return List<SyncQueueItem>.unmodifiable(
      _items.where(
        (SyncQueueItem item) => item.status == SyncQueueItemStatus.pending,
      ),
    );
  }

  @override
  Future<List<SyncQueueItem>> failed() async {
    return List<SyncQueueItem>.unmodifiable(
      _items.where(
        (SyncQueueItem item) => item.status == SyncQueueItemStatus.failed,
      ),
    );
  }

  @override
  Future<void> markSyncing(String id, {DateTime? attemptedAtUtc}) async {
    _update(
      id,
      (SyncQueueItem item) => item.copyWith(
        attempts: item.attempts + 1,
        lastAttemptAtUtc: attemptedAtUtc,
        status: SyncQueueItemStatus.syncing,
        clearLastError: true,
      ),
    );
  }

  @override
  Future<void> markSynced(String id, {DateTime? completedAtUtc}) async {
    _update(
      id,
      (SyncQueueItem item) => item.copyWith(
        lastAttemptAtUtc: completedAtUtc,
        status: SyncQueueItemStatus.synced,
        clearLastError: true,
      ),
    );
  }

  @override
  Future<void> markFailed(
    String id, {
    String? lastError,
    DateTime? failedAtUtc,
  }) async {
    _update(
      id,
      (SyncQueueItem item) => item.copyWith(
        attempts: item.status == SyncQueueItemStatus.syncing
            ? item.attempts
            : item.attempts + 1,
        lastAttemptAtUtc: failedAtUtc,
        status: SyncQueueItemStatus.failed,
        lastError: lastError,
      ),
    );
  }

  @override
  Future<int> retryFailed() async {
    int retried = 0;
    for (int index = 0; index < _items.length; index += 1) {
      final SyncQueueItem item = _items[index];
      if (item.status != SyncQueueItemStatus.failed) {
        continue;
      }
      retried += 1;
      _items[index] = item.copyWith(
        status: SyncQueueItemStatus.pending,
        clearLastError: true,
      );
    }
    return retried;
  }

  void _update(String id, SyncQueueItem Function(SyncQueueItem item) update) {
    final int index = _items.indexWhere((SyncQueueItem item) => item.id == id);
    if (index == -1) {
      return;
    }
    _items[index] = update(_items[index]);
  }
}
