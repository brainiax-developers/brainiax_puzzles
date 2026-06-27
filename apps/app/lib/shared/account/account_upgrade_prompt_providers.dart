import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_providers.dart';
import '../auth/auth_repository.dart';
import '../auth/auth_state.dart';
import '../providers/puzzle_local_store_providers.dart';
import '../stats/stats_providers.dart';
import 'account_upgrade_prompt_service.dart';

final accountUpgradePromptServiceProvider =
    FutureProvider<AccountUpgradePromptService>((ref) async {
      final SharedPreferences prefs = await ref.watch(
        sharedPreferencesProvider.future,
      );
      return AccountUpgradePromptService(prefs);
    });

final accountUpgradePromptEligibilityProvider =
    Provider<AccountUpgradePromptEligibility>((ref) {
      final AccountUpgradePromptService? service = ref
          .watch(accountUpgradePromptServiceProvider)
          .maybeWhen(data: (value) => value, orElse: () => null);
      if (service == null) {
        return AccountUpgradePromptEligibility(
          isAnonymous: false,
          totalCompletions: 0,
          currentDailyStreak: 0,
          dismissedUntilUtc: null,
          evaluatedAtUtc: DateTime.now().toUtc(),
          shouldShow: false,
        );
      }

      final AuthRepository authRepository = ref.watch(authRepositoryProvider);
      final AuthState authState = ref
          .watch(authStateProvider)
          .maybeWhen(
            data: (value) => value,
            orElse: () => authRepository.currentAuthState,
          );
      final aggregateStats = ref
          .watch(localStatsAggregateProvider)
          .maybeWhen(data: (value) => value, orElse: () => null);
      final dailyStreak = ref
          .watch(dailyStreakStatusProvider)
          .maybeWhen(data: (value) => value, orElse: () => null);

      return service.evaluate(
        isAnonymous: authState.isAuthenticated && authState.isAnonymous,
        totalCompletions: aggregateStats?.totalCompletions ?? 0,
        currentDailyStreak: dailyStreak?.currentStreak ?? 0,
      );
    });

class AccountUpgradePromptController {
  AccountUpgradePromptController(this._ref);

  final Ref _ref;

  Future<void> dismiss() async {
    final AccountUpgradePromptService service = await _ref.read(
      accountUpgradePromptServiceProvider.future,
    );
    await service.dismiss();
    _ref.invalidate(accountUpgradePromptEligibilityProvider);
  }
}

final accountUpgradePromptControllerProvider =
    Provider<AccountUpgradePromptController>(
      AccountUpgradePromptController.new,
    );
