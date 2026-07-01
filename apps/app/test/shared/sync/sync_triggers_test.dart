import 'package:app/shared/auth/auth_repository.dart';
import 'package:app/shared/auth/auth_state.dart';
import 'package:app/shared/auth/user_identity.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/stats/stats_models.dart';
import 'package:app/shared/stats/puzzle_run_result.dart';
import 'package:app/shared/sync/firestore_sync_repository.dart';
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

  test('flushPending retries failed items before processing pending', () async {
    final queue = _RecordingQueue();
    final service = SyncService(queue);
    final item = service
        .statsSnapshotQueueItem(
          PuzzleStatsAggregate.empty,
          createdAtUtc: DateTime.utc(2026, 6, 21, 12),
        )
        .copyWith(status: SyncQueueItemStatus.failed, lastError: 'offline');
    await queue.enqueue(item);
    final repository = _RecordingRepository();
    final engine = SyncEngine(
      queue: queue,
      repository: repository,
      authRepository: const _FakeAuthRepository(),
    );
    final triggers = SyncTriggers(syncService: service, syncEngine: engine);

    await triggers.flushPending();

    expect(queue.events.take(2), <String>['retryFailed', 'pending']);
    expect(repository.statsUploads, 1);
    expect((await queue.all()).single.status, SyncQueueItemStatus.synced);
  });
}

class _RecordingQueue implements SyncQueue {
  final List<SyncQueueItem> items = <SyncQueueItem>[];
  final List<String> events = <String>[];

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
    events.add('pending');
    return List<SyncQueueItem>.unmodifiable(
      items.where(
        (SyncQueueItem item) => item.status == SyncQueueItemStatus.pending,
      ),
    );
  }

  @override
  Future<List<SyncQueueItem>> failed() async {
    events.add('failed');
    return List<SyncQueueItem>.unmodifiable(
      items.where(
        (SyncQueueItem item) => item.status == SyncQueueItemStatus.failed,
      ),
    );
  }

  @override
  Future<void> markSyncing(String id, {DateTime? attemptedAtUtc}) async {
    _update(
      id,
      (item) => item.copyWith(
        status: SyncQueueItemStatus.syncing,
        attempts: item.attempts + 1,
        lastAttemptAtUtc: attemptedAtUtc,
        clearLastError: true,
      ),
    );
  }

  @override
  Future<void> markSynced(String id, {DateTime? completedAtUtc}) async {
    _update(
      id,
      (item) => item.copyWith(
        status: SyncQueueItemStatus.synced,
        lastAttemptAtUtc: completedAtUtc,
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
      (item) => item.copyWith(
        status: SyncQueueItemStatus.failed,
        lastError: lastError,
        lastAttemptAtUtc: failedAtUtc,
      ),
    );
  }

  @override
  Future<int> retryFailed() async {
    events.add('retryFailed');
    var retried = 0;
    for (var index = 0; index < items.length; index += 1) {
      final item = items[index];
      if (item.status != SyncQueueItemStatus.failed) {
        continue;
      }
      retried += 1;
      items[index] = item.copyWith(
        status: SyncQueueItemStatus.pending,
        clearLastError: true,
      );
    }
    return retried;
  }

  void _update(String id, SyncQueueItem Function(SyncQueueItem item) update) {
    final index = items.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    items[index] = update(items[index]);
  }
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

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository();

  @override
  AuthState get currentAuthState => const AuthState.authenticated(
    UserIdentity(uid: 'sync-user', isAnonymous: true),
  );

  @override
  Stream<AuthState> authStateChanges() =>
      Stream<AuthState>.value(currentAuthState);

  @override
  Future<AuthState> signInAnonymously({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return currentAuthState;
  }

  @override
  Future<GoogleSignInResult> signInWithGoogle() async {
    return GoogleSignInResult.signedIn(currentAuthState);
  }

  @override
  Future<AppleSignInResult> linkWithApple() async {
    return AppleSignInResult.signedIn(currentAuthState);
  }
}

class _RecordingRepository implements SyncRepository {
  int statsUploads = 0;

  @override
  Future<void> ensureUserProfile(UserIdentity identity) async {}

  @override
  Future<void> uploadRunResult(String uid, PuzzleRunResult result) async {}

  @override
  Future<void> upsertDailyStreak(String uid, DailyStreakStatus status) async {}

  @override
  Future<void> upsertFavourites(
    String uid,
    List<PuzzleType> favourites, {
    required DateTime updatedAtUtc,
  }) async {}

  @override
  Future<void> upsertStats(String uid, PuzzleStatsAggregate stats) async {
    statsUploads += 1;
  }
}
