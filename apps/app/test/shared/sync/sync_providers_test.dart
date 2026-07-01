import 'package:app/shared/auth/auth_repository.dart';
import 'package:app/shared/auth/auth_state.dart';
import 'package:app/shared/auth/auth_providers.dart';
import 'package:app/shared/auth/user_identity.dart';
import 'package:app/shared/sync/firestore_sync_repository.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/providers/puzzle_local_store_providers.dart';
import 'package:app/shared/services/puzzle_local_store.dart';
import 'package:app/shared/stats/puzzle_run_result.dart';
import 'package:app/shared/stats/stats_models.dart';
import 'package:app/shared/sync/sync_engine.dart';
import 'package:app/shared/sync/sync_providers.dart';
import 'package:app/shared/sync/sync_queue.dart';
import 'package:app/shared/sync/sync_queue_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sync providers refresh after enqueue and retry operations', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(AsyncValue.data(prefs)),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(pendingSyncQueueItemsProvider.future), isEmpty);

    final PuzzleCompletionRecord record = PuzzleCompletionRecord(
      id: 'provider-record',
      puzzleType: PuzzleType.takuzuBinary,
      mode: PuzzleMode.random,
      difficulty: 'medium',
      size: '8x8',
      seed: 'provider-seed',
      completedAtUtc: DateTime.utc(2026, 6, 21, 14),
      elapsedMs: 15000,
      moveCount: 20,
      hintsUsed: 1,
      dailyDateKeyUtc: null,
    );

    await container
        .read(syncControllerProvider)
        .enqueueCompletionRecord(record);

    final pendingAfterEnqueue = await container.read(
      pendingSyncQueueItemsProvider.future,
    );
    expect(pendingAfterEnqueue, hasLength(1));

    await container
        .read(syncControllerProvider)
        .markFailed(
          pendingAfterEnqueue.single.id,
          lastError: 'offline',
          failedAtUtc: DateTime.utc(2026, 6, 21, 14, 5),
        );

    final failedAfterMark = await container.read(
      failedSyncQueueItemsProvider.future,
    );
    expect(failedAfterMark, hasLength(1));
    expect(failedAfterMark.single.lastError, 'offline');

    final int retried = await container
        .read(syncControllerProvider)
        .retryFailed();
    final pendingAfterRetry = await container.read(
      pendingSyncQueueItemsProvider.future,
    );

    expect(retried, 1);
    expect(await container.read(failedSyncQueueItemsProvider.future), isEmpty);
    expect(pendingAfterRetry, hasLength(1));
    expect(pendingAfterRetry.single.lastError, isNull);
  });

  test('manual retry flush retries failed completion and uploads it', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final repository = _RecordingSyncRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(AsyncValue.data(prefs)),
        authRepositoryProvider.overrideWithValue(_authenticatedRepository()),
        firestoreSyncRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final PuzzleCompletionRecord record = _completionRecord('manual-retry');
    await container
        .read(syncControllerProvider)
        .enqueueCompletionRecord(record);
    final pending = await container.read(pendingSyncQueueItemsProvider.future);
    await container
        .read(syncControllerProvider)
        .markFailed(
          pending.single.id,
          lastError: 'offline',
          failedAtUtc: DateTime.utc(2026, 6, 21, 14, 5),
        );

    final result = await container
        .read(syncControllerProvider)
        .retryFailedAndProcessPending();

    expect(result.retriedFailed, 1);
    expect(result.attempted, 1);
    expect(result.synced, 1);
    expect(result.failed, 0);
    expect(repository.uploadedRunIds, <String>['manual-retry']);
    expect(await container.read(pendingSyncQueueItemsProvider.future), isEmpty);
    expect(await container.read(failedSyncQueueItemsProvider.future), isEmpty);
  });

  test('retry upload failures keep local completion data intact', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final repository = _RecordingSyncRepository(failRunUploads: true);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(AsyncValue.data(prefs)),
        authRepositoryProvider.overrideWithValue(_authenticatedRepository()),
        firestoreSyncRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final PuzzleCompletionRecord record = _completionRecord('retry-fails');
    final store = SharedPreferencesPuzzleLocalStore(prefs);
    await store.recordCompletion(
      puzzleType: record.puzzleType,
      difficulty: record.difficulty,
      completionTime: Duration(milliseconds: record.elapsedMs),
      mode: record.mode,
      size: record.size,
      seed: record.seed,
      moveCount: record.moveCount,
      hintsUsed: record.hintsUsed,
      dailyDateKeyUtc: record.dailyDateKeyUtc,
    );
    await container
        .read(syncControllerProvider)
        .enqueueCompletionRecord(record);
    final pending = await container.read(pendingSyncQueueItemsProvider.future);
    await container.read(syncControllerProvider).markFailed(pending.single.id);

    final result = await container
        .read(syncControllerProvider)
        .retryFailedAndProcessPending();

    expect(result.retriedFailed, 1);
    expect(result.failed, 1);
    expect(await store.completionRecords(), hasLength(1));
    expect(
      (await container.read(failedSyncQueueItemsProvider.future)).single.id,
      pending.single.id,
    );
  });

  test('retry queue failures are non-fatal and reported', () async {
    final reporter = _RecordingFailureReporter();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        syncQueueProvider.overrideWithValue(
          AsyncValue.data(_RetryFailingQueue()),
        ),
        authRepositoryProvider.overrideWithValue(_authenticatedRepository()),
        firestoreSyncRepositoryProvider.overrideWithValue(
          _RecordingSyncRepository(),
        ),
        syncFailureReporterProvider.overrideWithValue(reporter),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(syncControllerProvider)
        .retryFailedAndProcessPending();

    expect(result.retryFailed, isTrue);
    expect(result.retryFailureReason, 'retry-failed');
    expect(result.attempted, 0);
    expect(reporter.operations, <String>['retry-failed-sync-items']);
  });
}

PuzzleCompletionRecord _completionRecord(String id) {
  return PuzzleCompletionRecord(
    id: id,
    puzzleType: PuzzleType.takuzuBinary,
    mode: PuzzleMode.random,
    difficulty: 'medium',
    size: '8x8',
    seed: 'provider-seed',
    completedAtUtc: DateTime.utc(2026, 6, 21, 14),
    elapsedMs: 15000,
    moveCount: 20,
    hintsUsed: 1,
    dailyDateKeyUtc: null,
  );
}

AuthRepository _authenticatedRepository() {
  return const _FakeAuthRepository(
    AuthState.authenticated(UserIdentity(uid: 'sync-user', isAnonymous: true)),
  );
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository(this._state);

  final AuthState _state;

  @override
  AuthState get currentAuthState => _state;

  @override
  Stream<AuthState> authStateChanges() => Stream<AuthState>.value(_state);

  @override
  Future<AuthState> signInAnonymously({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return _state;
  }

  @override
  Future<GoogleSignInResult> signInWithGoogle() async {
    return GoogleSignInResult.signedIn(_state);
  }

  @override
  Future<AppleSignInResult> linkWithApple() async {
    return AppleSignInResult.signedIn(_state);
  }
}

class _RecordingSyncRepository implements SyncRepository {
  _RecordingSyncRepository({this.failRunUploads = false});

  final bool failRunUploads;
  final List<String> uploadedRunIds = <String>[];

  @override
  Future<void> ensureUserProfile(UserIdentity identity) async {}

  @override
  Future<void> uploadRunResult(String uid, PuzzleRunResult result) async {
    if (failRunUploads) {
      throw StateError('run upload failed');
    }
    uploadedRunIds.add(result.id);
  }

  @override
  Future<void> upsertDailyStreak(String uid, DailyStreakStatus status) async {}

  @override
  Future<void> upsertFavourites(
    String uid,
    List<PuzzleType> favourites, {
    required DateTime updatedAtUtc,
  }) async {}

  @override
  Future<void> upsertStats(String uid, PuzzleStatsAggregate stats) async {}
}

class _RetryFailingQueue implements SyncQueue {
  @override
  Future<List<SyncQueueItem>> all() async => const <SyncQueueItem>[];

  @override
  Future<void> enqueue(SyncQueueItem item) async {}

  @override
  Future<List<SyncQueueItem>> failed() async => const <SyncQueueItem>[];

  @override
  Future<void> markFailed(
    String id, {
    String? lastError,
    DateTime? failedAtUtc,
  }) async {}

  @override
  Future<void> markSynced(String id, {DateTime? completedAtUtc}) async {}

  @override
  Future<void> markSyncing(String id, {DateTime? attemptedAtUtc}) async {}

  @override
  Future<List<SyncQueueItem>> pending() async => const <SyncQueueItem>[];

  @override
  Future<int> retryFailed() {
    throw StateError('retry storage failed');
  }
}

class _RecordingFailureReporter implements SyncFailureReporter {
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
