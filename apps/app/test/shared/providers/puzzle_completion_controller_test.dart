import 'package:app/shared/auth/auth_repository.dart';
import 'package:app/shared/auth/auth_state.dart';
import 'package:app/shared/auth/user_identity.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/providers/puzzle_local_store_providers.dart';
import 'package:app/shared/services/puzzle_progress_service.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_puzzle_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'completion updates local stats immediately and enqueues run result metadata',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final PuzzleProgressService progress = PuzzleProgressService(prefs);
      final puzzle = buildSudokuPuzzle(difficulty: 'hard');
      await progress.saveRunForPuzzle(
        puzzleType: PuzzleType.sudokuClassic,
        mode: PuzzleMode.random,
        puzzle: puzzle,
        elapsed: const Duration(seconds: 50),
        moveCount: 12,
        hintsUsed: 1,
      );
      final ActivePuzzleRun seededRun = (await progress.loadActiveRunFor(
        type: PuzzleType.sudokuClassic,
        mode: PuzzleMode.random,
      ))!;
      final ProviderContainer container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(AsyncValue.data(prefs)),
        ],
      );
      addTearDown(container.dispose);

      final DateTime completedAt = DateTime.utc(2026, 6, 21, 10);
      final PuzzleCompletionStatus status = await container
          .read(puzzleCompletionControllerProvider)
          .recordCompletion(
            puzzleType: PuzzleType.sudokuClassic,
            difficulty: 'hard',
            completionTime: const Duration(seconds: 95),
            mode: PuzzleMode.random,
            completedAt: completedAt,
            size: '9x9',
            seed: 'random-seed',
            moveCount: 16,
            hintsUsed: 2,
          );

      final HomeStatsSnapshot homeStats = await container.read(
        homeStatsProvider.future,
      );
      final PuzzleStatsAggregate aggregate = await container.read(
        localStatsAggregateProvider.future,
      );
      final List<PuzzleCompletionRecord> records = await container.read(
        completionRecordsProvider.future,
      );
      final List<SyncQueueItem> queueItems = await container.read(
        pendingSyncQueueItemsProvider.future,
      );
      final SyncQueueItem runItem = queueItems.singleWhere(
        (SyncQueueItem item) => item.type == SyncQueueItemType.puzzleCompletion,
      );

      expect(status.bestTime, const Duration(seconds: 95));
      expect(homeStats.totalSolved, 1);
      expect(aggregate.totalCompletions, 1);
      expect(aggregate.totalMoveCount, 16);
      expect(
        queueItems.map((SyncQueueItem item) => item.type),
        <SyncQueueItemType>[
          SyncQueueItemType.puzzleCompletion,
          SyncQueueItemType.statsSnapshot,
        ],
      );
      expect(runItem.id, 'completion:${records.single.id}');
      expect(runItem.payload['id'], records.single.id);
      expect(
        runItem.payload['startedAtUtc'],
        seededRun.createdAtUtc.toUtc().toIso8601String(),
      );
      expect(
        runItem.payload['sessionUpdatedAtUtc'],
        seededRun.updatedAtUtc.toUtc().toIso8601String(),
      );
      expect(runItem.payload.containsKey('generatedPuzzleJson'), isFalse);
      expect(runItem.payload.containsKey('board'), isFalse);
    },
  );

  test(
    'duplicate recordCompletion calls with the same run id do not duplicate queue items',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(AsyncValue.data(prefs)),
        ],
      );
      addTearDown(container.dispose);

      final DateTime completedAt = DateTime.utc(2026, 6, 21, 12);
      final PuzzleCompletionController controller = container.read(
        puzzleCompletionControllerProvider,
      );

      for (int attempt = 0; attempt < 2; attempt += 1) {
        await controller.recordCompletion(
          puzzleType: PuzzleType.nonogramMono,
          difficulty: 'normal',
          completionTime: const Duration(minutes: 4),
          mode: PuzzleMode.daily,
          completedAt: completedAt,
          size: '5x5',
          seed: 'daily-seed',
          moveCount: 20,
          hintsUsed: 0,
          dailyDateKeyUtc: '2026-06-21',
        );
      }

      final List<PuzzleCompletionRecord> records = await container.read(
        completionRecordsProvider.future,
      );
      final List<SyncQueueItem> queueItems = await container.read(
        pendingSyncQueueItemsProvider.future,
      );

      expect(records, hasLength(1));
      expect(queueItems, hasLength(3));
      expect(
        queueItems
            .where(
              (SyncQueueItem item) =>
                  item.type == SyncQueueItemType.puzzleCompletion,
            )
            .single
            .id,
        'completion:${records.single.id}',
      );
      expect(
        queueItems.where(
          (SyncQueueItem item) => item.type == SyncQueueItemType.statsSnapshot,
        ),
        hasLength(1),
      );
      expect(
        queueItems.where(
          (SyncQueueItem item) =>
              item.type == SyncQueueItemType.dailyStreakSnapshot,
        ),
        hasLength(1),
      );
    },
  );

  test('background sync failure does not break completion recording', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final _ThrowingSyncEngine syncEngine = _ThrowingSyncEngine();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(AsyncValue.data(prefs)),
        syncEngineProvider.overrideWithValue(AsyncValue.data(syncEngine)),
      ],
    );
    addTearDown(container.dispose);

    final PuzzleCompletionStatus status = await container
        .read(puzzleCompletionControllerProvider)
        .recordCompletion(
          puzzleType: PuzzleType.takuzuBinary,
          difficulty: 'medium',
          completionTime: const Duration(seconds: 88),
          mode: PuzzleMode.random,
          completedAt: DateTime.utc(2026, 6, 21, 15),
          size: '8x8',
          seed: 'sync-failure-seed',
          moveCount: 18,
          hintsUsed: 1,
        );
    await Future<void>.delayed(Duration.zero);

    final List<SyncQueueItem> queueItems = await container.read(
      pendingSyncQueueItemsProvider.future,
    );

    expect(status.bestTime, const Duration(seconds: 88));
    expect(queueItems, hasLength(2));
    expect(syncEngine.calls, 1);
  });

  test('favourite toggle updates local state and enqueues a favourites update', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(AsyncValue.data(prefs)),
      ],
    );
    addTearDown(container.dispose);

    final FavouritePuzzleController controller = container.read(
      favouritePuzzleControllerProvider,
    );

    expect(
      await container.read(favouritePuzzleTypesProvider.future),
      isEmpty,
    );

    expect(await controller.toggle(PuzzleType.sudokuClassic), isTrue);

    final List<PuzzleType> favourites = await container.read(
      favouritePuzzleTypesProvider.future,
    );
    final List<SyncQueueItem> queueItems = await container.read(
      pendingSyncQueueItemsProvider.future,
    );
    final SyncQueueItem item = queueItems.single;

    expect(favourites, <PuzzleType>[PuzzleType.sudokuClassic]);
    expect(item.type, SyncQueueItemType.favouritesUpdate);
    expect(item.payload['favourites'], <String>['sudoku_classic']);
    expect(item.payload['updatedAtUtc'], isA<String>());
    expect(item.payload.containsKey('board'), isFalse);
    expect(item.payload.containsKey('solution'), isFalse);
  });
}

class _ThrowingSyncEngine extends SyncEngine {
  _ThrowingSyncEngine()
    : super(
        queue: _UnusedSyncQueue(),
        repository: _UnusedSyncRepository(),
        authRepository: _UnusedAuthRepository(),
      );

  int calls = 0;

  @override
  Future<SyncEngineResult> processPending({int? limit}) async {
    calls += 1;
    throw StateError('sync failed');
  }
}

class _UnusedAuthRepository implements AuthRepository {
  @override
  AuthState get currentAuthState => const AuthState.authenticated(
    UserIdentity(uid: 'unused', isAnonymous: true),
  );

  @override
  Stream<AuthState> authStateChanges() {
    return Stream<AuthState>.value(currentAuthState);
  }

  @override
  Future<AuthState> signInAnonymously({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return currentAuthState;
  }
}

class _UnusedSyncRepository implements SyncRepository {
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
  }
  ) async {}

  @override
  Future<void> upsertStats(String uid, PuzzleStatsAggregate stats) async {}
}

class _UnusedSyncQueue implements SyncQueue {
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
