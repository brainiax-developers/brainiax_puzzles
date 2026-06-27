import 'package:app/features/profile/profile_dashboard.dart';
import 'package:app/shared/auth/auth_providers.dart';
import 'package:app/shared/auth/auth_repository.dart';
import 'package:app/shared/auth/auth_state.dart';
import 'package:app/shared/auth/user_identity.dart';
import 'package:app/shared/models/puzzle_type.dart';
import 'package:app/shared/providers/puzzle_local_store_providers.dart';
import 'package:app/shared/stats/puzzle_run_result.dart';
import 'package:app/shared/stats/stats_models.dart';
import 'package:app/shared/stats/stats_providers.dart';
import 'package:app/shared/sync/firestore_sync_repository.dart';
import 'package:app/shared/sync/sync_engine.dart';
import 'package:app/shared/sync/sync_providers.dart';
import 'package:app/shared/sync/sync_queue.dart';
import 'package:app/shared/sync/sync_queue_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('profileDashboardProvider', () {
    test('builds a guest local-only dashboard from offline providers', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const UnavailableAuthRepository('auth disabled'),
          ),
          homeStatsProvider.overrideWith(
            (ref) async => const HomeStatsSnapshot(
              totalSolved: 3,
              todayCompleted: 1,
              completedThisWeek: 2,
            ),
          ),
          localStatsAggregateProvider.overrideWith(
            (ref) async => PuzzleStatsAggregate(
              totalCompletions: 3,
              randomCompletions: 2,
              dailyCompletions: 1,
              totalElapsedMs: 0,
              totalMoveCount: 0,
              totalHintsUsed: 0,
              firstCompletedAtUtc: null,
              lastCompletedAtUtc: null,
              byPuzzle: <PuzzleType, PuzzleTypeStats>{
                PuzzleType.sudokuClassic: _puzzleStats(
                  puzzleType: PuzzleType.sudokuClassic,
                  totalCompletions: 3,
                  randomCompletions: 2,
                  dailyCompletions: 1,
                  bestElapsedMs: 95 * 1000,
                ),
              },
            ),
          ),
          dailyStreakStatusProvider.overrideWith(
            (ref) async => const DailyStreakStatus(
              currentStreak: 4,
              bestStreak: 9,
              lastCompletedDateKeyUtc: '2026-06-26',
            ),
          ),
          syncEngineProvider.overrideWithValue(const AsyncValue.data(null)),
          pendingSyncQueueItemsProvider.overrideWith((ref) async => const []),
          failedSyncQueueItemsProvider.overrideWith((ref) async => const []),
        ],
      );
      addTearDown(container.dispose);

      final dashboard = await container.read(profileDashboardProvider.future);

      expect(dashboard.accountState, ProfileAccountState.guest);
      expect(dashboard.authAvailable, isFalse);
      expect(dashboard.syncSummary.state, ProfileSyncState.localOnly);
      expect(dashboard.syncSummary.canSyncNow, isFalse);
      expect(dashboard.overview.totalSolved, 3);
      expect(dashboard.puzzleSummaries, hasLength(1));
      expect(
        dashboard.puzzleSummaries.single.bestTime,
        const Duration(seconds: 95),
      );
    });

    test('builds an anonymous dashboard with pending sync work', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const _FakeAuthRepository(
              AuthState.authenticated(
                UserIdentity(uid: 'anon-user', isAnonymous: true),
              ),
            ),
          ),
          homeStatsProvider.overrideWith(
            (ref) async => const HomeStatsSnapshot(
              totalSolved: 5,
              todayCompleted: 0,
              completedThisWeek: 3,
            ),
          ),
          localStatsAggregateProvider.overrideWith(
            (ref) async => PuzzleStatsAggregate(
              totalCompletions: 5,
              randomCompletions: 5,
              dailyCompletions: 0,
              totalElapsedMs: 0,
              totalMoveCount: 0,
              totalHintsUsed: 0,
              firstCompletedAtUtc: null,
              lastCompletedAtUtc: null,
              byPuzzle: <PuzzleType, PuzzleTypeStats>{
                PuzzleType.nonogramMono: _puzzleStats(
                  puzzleType: PuzzleType.nonogramMono,
                  totalCompletions: 4,
                  randomCompletions: 4,
                  dailyCompletions: 0,
                  bestElapsedMs: 135 * 1000,
                ),
                PuzzleType.sudokuClassic: _puzzleStats(
                  puzzleType: PuzzleType.sudokuClassic,
                  totalCompletions: 1,
                  randomCompletions: 1,
                  dailyCompletions: 0,
                  bestElapsedMs: 210 * 1000,
                ),
              },
            ),
          ),
          dailyStreakStatusProvider.overrideWith(
            (ref) async => const DailyStreakStatus(
              currentStreak: 0,
              bestStreak: 2,
              lastCompletedDateKeyUtc: null,
            ),
          ),
          syncEngineProvider.overrideWithValue(
            AsyncValue.data(_buildSyncEngine()),
          ),
          pendingSyncQueueItemsProvider.overrideWith(
            (ref) async => <SyncQueueItem>[
              _pendingQueueItem('p1'),
              _pendingQueueItem('p2'),
            ],
          ),
          failedSyncQueueItemsProvider.overrideWith((ref) async => const []),
        ],
      );
      addTearDown(container.dispose);

      final dashboard = await container.read(profileDashboardProvider.future);

      expect(dashboard.accountState, ProfileAccountState.anonymous);
      expect(dashboard.syncSummary.state, ProfileSyncState.pending);
      expect(dashboard.syncSummary.pendingCount, 2);
      expect(dashboard.syncSummary.canSyncNow, isTrue);
      expect(
        dashboard.puzzleSummaries.first.puzzleType,
        PuzzleType.nonogramMono,
      );
    });
  });
}

PuzzleTypeStats _puzzleStats({
  required PuzzleType puzzleType,
  required int totalCompletions,
  required int randomCompletions,
  required int dailyCompletions,
  required int bestElapsedMs,
}) {
  return PuzzleTypeStats(
    puzzleType: puzzleType,
    totalCompletions: totalCompletions,
    randomCompletions: randomCompletions,
    dailyCompletions: dailyCompletions,
    totalElapsedMs: bestElapsedMs * totalCompletions,
    totalMoveCount: 0,
    totalHintsUsed: 0,
    bestElapsedMs: bestElapsedMs,
    firstCompletedAtUtc: null,
    lastCompletedAtUtc: null,
    byDifficulty: const <String, PuzzleDifficultyStats>{},
  );
}

SyncQueueItem _pendingQueueItem(String id) {
  return SyncQueueItem(
    id: id,
    type: SyncQueueItemType.statsSnapshot,
    payload: const <String, dynamic>{},
    createdAtUtc: DateTime.utc(2026, 6, 27, 12),
    attempts: 0,
    lastAttemptAtUtc: null,
    status: SyncQueueItemStatus.pending,
    lastError: null,
  );
}

SyncEngine _buildSyncEngine() {
  return SyncEngine(
    queue: const _FakeSyncQueue(),
    repository: const _FakeSyncRepository(),
    authRepository: const _FakeAuthRepository(
      AuthState.authenticated(
        UserIdentity(uid: 'signed-in-user', isAnonymous: false),
      ),
    ),
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
}

class _FakeSyncQueue implements SyncQueue {
  const _FakeSyncQueue();

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
  Future<int> retryFailed() async => 0;
}

class _FakeSyncRepository implements SyncRepository {
  const _FakeSyncRepository();

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
  Future<void> upsertStats(String uid, PuzzleStatsAggregate stats) async {}
}
