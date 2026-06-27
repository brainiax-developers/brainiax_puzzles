import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/auth/auth_providers.dart';
import '../../shared/auth/auth_repository.dart';
import '../../shared/auth/auth_state.dart';
import '../../shared/models/puzzle_type.dart';
import '../../shared/providers/puzzle_local_store_providers.dart';
import '../../shared/stats/stats_models.dart';
import '../../shared/stats/stats_providers.dart';
import '../../shared/sync/sync_providers.dart';
import '../../shared/sync/sync_queue_item.dart';

enum ProfileAccountState { guest, anonymous, signedIn }

enum ProfileSyncState { localOnly, upToDate, pending, error }

class ProfilePuzzleSummary {
  const ProfilePuzzleSummary({
    required this.puzzleType,
    required this.totalCompletions,
    required this.randomCompletions,
    required this.dailyCompletions,
    required this.bestTime,
  });

  final PuzzleType puzzleType;
  final int totalCompletions;
  final int randomCompletions;
  final int dailyCompletions;
  final Duration? bestTime;
}

class ProfileSyncSummary {
  const ProfileSyncSummary({
    required this.state,
    required this.canSyncNow,
    required this.pendingCount,
    required this.failedCount,
    required this.latestError,
  });

  final ProfileSyncState state;
  final bool canSyncNow;
  final int pendingCount;
  final int failedCount;
  final String? latestError;
}

class ProfileDashboardData {
  const ProfileDashboardData({
    required this.accountState,
    required this.authAvailable,
    required this.overview,
    required this.aggregateStats,
    required this.dailyStreak,
    required this.syncSummary,
    required this.puzzleSummaries,
  });

  final ProfileAccountState accountState;
  final bool authAvailable;
  final HomeStatsSnapshot overview;
  final PuzzleStatsAggregate aggregateStats;
  final DailyStreakStatus dailyStreak;
  final ProfileSyncSummary syncSummary;
  final List<ProfilePuzzleSummary> puzzleSummaries;

  bool get hasPuzzleHistory => puzzleSummaries.isNotEmpty;
}

final profileDashboardProvider = FutureProvider<ProfileDashboardData>((
  ref,
) async {
  final AuthRepository authRepository = ref.watch(authRepositoryProvider);
  final AuthState authState =
      ref.watch(authStateProvider).asData?.value ??
      authRepository.currentAuthState;
  final HomeStatsSnapshot overview = await ref.watch(homeStatsProvider.future);
  final PuzzleStatsAggregate aggregateStats = await ref.watch(
    localStatsAggregateProvider.future,
  );
  final DailyStreakStatus dailyStreak = await ref.watch(
    dailyStreakStatusProvider.future,
  );
  final bool canSyncNow =
      await ref.watch(syncEngineProvider.future) != null;
  final List<SyncQueueItem> pendingItems = await ref.watch(
    pendingSyncQueueItemsProvider.future,
  );
  final List<SyncQueueItem> failedItems = await ref.watch(
    failedSyncQueueItemsProvider.future,
  );

  final List<ProfilePuzzleSummary> puzzleSummaries = aggregateStats.byPuzzle.values
      .where((stats) => stats.hasCompletions)
      .map(
        (stats) => ProfilePuzzleSummary(
          puzzleType: stats.puzzleType,
          totalCompletions: stats.totalCompletions,
          randomCompletions: stats.randomCompletions,
          dailyCompletions: stats.dailyCompletions,
          bestTime: stats.bestTime,
        ),
      )
      .toList()
    ..sort((a, b) {
      final int completionCompare = b.totalCompletions.compareTo(
        a.totalCompletions,
      );
      if (completionCompare != 0) {
        return completionCompare;
      }
      return a.puzzleType.displayName.compareTo(b.puzzleType.displayName);
    });

  return ProfileDashboardData(
    accountState: _mapAccountState(authState),
    authAvailable: authRepository is! UnavailableAuthRepository,
    overview: overview,
    aggregateStats: aggregateStats,
    dailyStreak: dailyStreak,
    syncSummary: _buildSyncSummary(
      canSyncNow: canSyncNow,
      pendingItems: pendingItems,
      failedItems: failedItems,
    ),
    puzzleSummaries: List<ProfilePuzzleSummary>.unmodifiable(puzzleSummaries),
  );
});

ProfileAccountState _mapAccountState(AuthState authState) {
  if (!authState.isAuthenticated) {
    return ProfileAccountState.guest;
  }
  if (authState.isAnonymous) {
    return ProfileAccountState.anonymous;
  }
  return ProfileAccountState.signedIn;
}

ProfileSyncSummary _buildSyncSummary({
  required bool canSyncNow,
  required List<SyncQueueItem> pendingItems,
  required List<SyncQueueItem> failedItems,
}) {
  final String latestError = failedItems
      .map((item) => item.lastError?.trim())
      .whereType<String>()
      .firstWhere(
        (value) => value.isNotEmpty,
        orElse: () => '',
      );

  return ProfileSyncSummary(
    state: !canSyncNow
        ? ProfileSyncState.localOnly
        : failedItems.isNotEmpty
        ? ProfileSyncState.error
        : pendingItems.isNotEmpty
        ? ProfileSyncState.pending
        : ProfileSyncState.upToDate,
    canSyncNow: canSyncNow,
    pendingCount: pendingItems.length,
    failedCount: failedItems.length,
    latestError: latestError.isEmpty ? null : latestError,
  );
}
