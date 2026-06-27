import 'package:app/shared/account/account_upgrade_prompt_providers.dart';
import 'package:app/shared/account/account_upgrade_prompt_service.dart';
import 'package:app/shared/auth/auth_providers.dart';
import 'package:app/shared/auth/auth_repository.dart';
import 'package:app/shared/auth/auth_state.dart';
import 'package:app/shared/auth/user_identity.dart';
import 'package:app/shared/models/puzzle_type.dart';
import 'package:app/shared/providers/puzzle_local_store_providers.dart';
import 'package:app/shared/stats/stats_models.dart';
import 'package:app/shared/stats/stats_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('accountUpgradePromptEligibilityProvider', () {
    test('shows for anonymous users with sufficient completions', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(AsyncValue.data(prefs)),
          authRepositoryProvider.overrideWithValue(
            const _FakeAuthRepository(
              AuthState.authenticated(
                UserIdentity(uid: 'anon-user', isAnonymous: true),
              ),
            ),
          ),
          localStatsAggregateProvider.overrideWith(
            (ref) async => const PuzzleStatsAggregate(
              totalCompletions: 3,
              randomCompletions: 2,
              dailyCompletions: 1,
              totalElapsedMs: 0,
              totalMoveCount: 0,
              totalHintsUsed: 0,
              firstCompletedAtUtc: null,
              lastCompletedAtUtc: null,
              byPuzzle: <PuzzleType, PuzzleTypeStats>{},
            ),
          ),
          dailyStreakStatusProvider.overrideWith(
            (ref) async => const DailyStreakStatus(
              currentStreak: 1,
              bestStreak: 1,
              lastCompletedDateKeyUtc: null,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(accountUpgradePromptServiceProvider.future);
      await container.read(localStatsAggregateProvider.future);
      await container.read(dailyStreakStatusProvider.future);
      final AccountUpgradePromptEligibility prompt = container.read(
        accountUpgradePromptEligibilityProvider,
      );

      expect(prompt.shouldShow, isTrue);
      expect(prompt.isAnonymous, isTrue);
      expect(prompt.meetsThreshold, isTrue);
    });

    test('shows for anonymous users with a streak milestone', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(AsyncValue.data(prefs)),
          authRepositoryProvider.overrideWithValue(
            const _FakeAuthRepository(
              AuthState.authenticated(
                UserIdentity(uid: 'anon-user', isAnonymous: true),
              ),
            ),
          ),
          localStatsAggregateProvider.overrideWith(
            (ref) async => const PuzzleStatsAggregate(
              totalCompletions: 1,
              randomCompletions: 1,
              dailyCompletions: 0,
              totalElapsedMs: 0,
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
              bestStreak: 3,
              lastCompletedDateKeyUtc: null,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(accountUpgradePromptServiceProvider.future);
      await container.read(localStatsAggregateProvider.future);
      await container.read(dailyStreakStatusProvider.future);
      final AccountUpgradePromptEligibility prompt = container.read(
        accountUpgradePromptEligibilityProvider,
      );

      expect(prompt.shouldShow, isTrue);
      expect(prompt.currentDailyStreak, 3);
    });

    test('does not show for signed-in non-anonymous users', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(AsyncValue.data(prefs)),
          authRepositoryProvider.overrideWithValue(
            const _FakeAuthRepository(
              AuthState.authenticated(
                UserIdentity(uid: 'signed-in', isAnonymous: false),
              ),
            ),
          ),
          localStatsAggregateProvider.overrideWith(
            (ref) async => const PuzzleStatsAggregate(
              totalCompletions: 10,
              randomCompletions: 8,
              dailyCompletions: 2,
              totalElapsedMs: 0,
              totalMoveCount: 0,
              totalHintsUsed: 0,
              firstCompletedAtUtc: null,
              lastCompletedAtUtc: null,
              byPuzzle: <PuzzleType, PuzzleTypeStats>{},
            ),
          ),
          dailyStreakStatusProvider.overrideWith(
            (ref) async => const DailyStreakStatus(
              currentStreak: 8,
              bestStreak: 8,
              lastCompletedDateKeyUtc: null,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(accountUpgradePromptServiceProvider.future);
      await container.read(localStatsAggregateProvider.future);
      await container.read(dailyStreakStatusProvider.future);
      final AccountUpgradePromptEligibility prompt = container.read(
        accountUpgradePromptEligibilityProvider,
      );

      expect(prompt.shouldShow, isFalse);
      expect(prompt.isAnonymous, isFalse);
    });

    test('respects active dismissal windows', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AccountUpgradePromptService.dismissedUntilKey: DateTime.utc(
          2099,
          1,
          1,
        ).toIso8601String(),
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(AsyncValue.data(prefs)),
          authRepositoryProvider.overrideWithValue(
            const _FakeAuthRepository(
              AuthState.authenticated(
                UserIdentity(uid: 'anon-user', isAnonymous: true),
              ),
            ),
          ),
          localStatsAggregateProvider.overrideWith(
            (ref) async => const PuzzleStatsAggregate(
              totalCompletions: 4,
              randomCompletions: 4,
              dailyCompletions: 0,
              totalElapsedMs: 0,
              totalMoveCount: 0,
              totalHintsUsed: 0,
              firstCompletedAtUtc: null,
              lastCompletedAtUtc: null,
              byPuzzle: <PuzzleType, PuzzleTypeStats>{},
            ),
          ),
          dailyStreakStatusProvider.overrideWith(
            (ref) async => const DailyStreakStatus(
              currentStreak: 0,
              bestStreak: 0,
              lastCompletedDateKeyUtc: null,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(accountUpgradePromptServiceProvider.future);
      await container.read(localStatsAggregateProvider.future);
      await container.read(dailyStreakStatusProvider.future);
      final AccountUpgradePromptEligibility prompt = container.read(
        accountUpgradePromptEligibilityProvider,
      );

      expect(prompt.shouldShow, isFalse);
      expect(prompt.isDismissed, isTrue);
    });
  });
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
