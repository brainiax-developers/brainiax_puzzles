import 'package:app/features/profile/profile_screen.dart';
import 'package:app/shared/account/account_upgrade_prompt_service.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject(List<Object> overrides) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
    );
  }

  testWidgets('renders an offline-first empty profile safely', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildSubject([
        authRepositoryProvider.overrideWithValue(
          const UnavailableAuthRepository('auth disabled'),
        ),
        homeStatsProvider.overrideWith(
          (ref) async => const HomeStatsSnapshot(
            totalSolved: 0,
            todayCompleted: 0,
            completedThisWeek: 0,
          ),
        ),
        localStatsAggregateProvider.overrideWith(
          (ref) async => PuzzleStatsAggregate.empty,
        ),
        dailyStreakStatusProvider.overrideWith(
          (ref) async => DailyStreakStatus.empty,
        ),
        syncEngineProvider.overrideWithValue(const AsyncValue.data(null)),
        pendingSyncQueueItemsProvider.overrideWith((ref) async => const []),
        failedSyncQueueItemsProvider.overrideWith((ref) async => const []),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Local only'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No puzzle history yet'), 300);
    await tester.pumpAndSettle();
    expect(find.text('No puzzle history yet'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
    expect(find.byKey(const ValueKey('profile-sync-now-button')), findsNothing);
    expect(find.text('Leaderboard'), findsNothing);
  });

  testWidgets('shows signed-in sync error state and puzzle breakdown', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildSubject([
        authRepositoryProvider.overrideWithValue(
          const _FakeAuthRepository(
            AuthState.authenticated(
              UserIdentity(uid: 'signed-in-user', isAnonymous: false),
            ),
          ),
        ),
        homeStatsProvider.overrideWith(
          (ref) async => const HomeStatsSnapshot(
            totalSolved: 2,
            todayCompleted: 1,
            completedThisWeek: 2,
          ),
        ),
        localStatsAggregateProvider.overrideWith(
          (ref) async => const PuzzleStatsAggregate(
            totalCompletions: 2,
            randomCompletions: 1,
            dailyCompletions: 1,
            totalElapsedMs: 190000,
            totalMoveCount: 0,
            totalHintsUsed: 0,
            firstCompletedAtUtc: null,
            lastCompletedAtUtc: null,
            byPuzzle: <PuzzleType, PuzzleTypeStats>{
              PuzzleType.sudokuClassic: PuzzleTypeStats(
                puzzleType: PuzzleType.sudokuClassic,
                totalCompletions: 2,
                randomCompletions: 1,
                dailyCompletions: 1,
                totalElapsedMs: 190000,
                totalMoveCount: 0,
                totalHintsUsed: 0,
                bestElapsedMs: 95000,
                firstCompletedAtUtc: null,
                lastCompletedAtUtc: null,
                byDifficulty: <String, PuzzleDifficultyStats>{},
              ),
            },
          ),
        ),
        dailyStreakStatusProvider.overrideWith(
          (ref) async => const DailyStreakStatus(
            currentStreak: 6,
            bestStreak: 8,
            lastCompletedDateKeyUtc: '2026-06-27',
          ),
        ),
        syncEngineProvider.overrideWithValue(
          AsyncValue.data(_buildSyncEngine()),
        ),
        pendingSyncQueueItemsProvider.overrideWith(
          (ref) async => <SyncQueueItem>[_queueItem('pending-sync')],
        ),
        failedSyncQueueItemsProvider.overrideWith(
          (ref) async => <SyncQueueItem>[
            _queueItem('failed-sync', status: SyncQueueItemStatus.failed),
          ],
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Signed in'), findsOneWidget);
    expect(find.text('Sync error'), findsOneWidget);
    expect(
      find.textContaining('Latest issue: sync failed for test'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile-sync-now-button')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Classic Sudoku'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Classic Sudoku'), findsOneWidget);
    expect(find.text('2 completions'), findsOneWidget);
    expect(find.text('Best 1:35'), findsOneWidget);
  });

  testWidgets('shows and dismisses the anonymous account upgrade prompt', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      buildSubject([
        authRepositoryProvider.overrideWithValue(
          const _FakeAuthRepository(
            AuthState.authenticated(
              UserIdentity(uid: 'anon-user', isAnonymous: true),
            ),
          ),
        ),
        homeStatsProvider.overrideWith(
          (ref) async => const HomeStatsSnapshot(
            totalSolved: 3,
            todayCompleted: 1,
            completedThisWeek: 2,
          ),
        ),
        localStatsAggregateProvider.overrideWith(
          (ref) async => const PuzzleStatsAggregate(
            totalCompletions: 3,
            randomCompletions: 2,
            dailyCompletions: 1,
            totalElapsedMs: 190000,
            totalMoveCount: 0,
            totalHintsUsed: 0,
            firstCompletedAtUtc: null,
            lastCompletedAtUtc: null,
            byPuzzle: <PuzzleType, PuzzleTypeStats>{},
          ),
        ),
        dailyStreakStatusProvider.overrideWith(
          (ref) async => const DailyStreakStatus(
            currentStreak: 3,
            bestStreak: 4,
            lastCompletedDateKeyUtc: '2026-06-27',
          ),
        ),
        syncEngineProvider.overrideWithValue(const AsyncValue.data(null)),
        pendingSyncQueueItemsProvider.overrideWith((ref) async => const []),
        failedSyncQueueItemsProvider.overrideWith((ref) async => const []),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Save progress with an account'),
      300,
    );
    await tester.pumpAndSettle();
    expect(find.text('Save progress with an account'), findsOneWidget);
    expect(find.text('3 completions'), findsOneWidget);
    expect(find.text('3 day streak'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.text('Save progress with an account'), findsNothing);
    expect(find.text('Dismiss'), findsNothing);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(AccountUpgradePromptService.dismissedUntilKey),
      isNotNull,
    );
  });
}

SyncQueueItem _queueItem(
  String id, {
  SyncQueueItemStatus status = SyncQueueItemStatus.pending,
}) {
  return SyncQueueItem(
    id: id,
    type: SyncQueueItemType.statsSnapshot,
    payload: const <String, dynamic>{},
    createdAtUtc: DateTime.utc(2026, 6, 27, 12),
    attempts: 1,
    lastAttemptAtUtc: DateTime.utc(2026, 6, 27, 12, 5),
    status: status,
    lastError: status == SyncQueueItemStatus.failed
        ? 'sync failed for test'
        : null,
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

  @override
  Future<GoogleSignInResult> signInWithGoogle() async {
    return GoogleSignInResult.signedIn(_state);
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
