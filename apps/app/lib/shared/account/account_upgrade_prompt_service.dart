import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed state for the account upgrade prompt.
class AccountUpgradePromptService {
  AccountUpgradePromptService(this._prefs, {DateTime Function()? nowUtc})
    : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final SharedPreferences _prefs;
  final DateTime Function() _nowUtc;

  static const String storageNamespace = 'account_upgrade_prompt.v1';
  static const String dismissedUntilKey =
      '$storageNamespace.dismissed_until_utc';
  static const Duration dismissalDuration = Duration(days: 7);
  static const int minimumCompletions = 3;
  static const int minimumDailyStreak = 3;

  DateTime? dismissedUntilUtc() {
    final String? rawValue = _prefs.getString(dismissedUntilKey);
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }
    return DateTime.tryParse(rawValue)?.toUtc();
  }

  bool isDismissed({DateTime? nowUtc}) {
    final DateTime? dismissedUntil = dismissedUntilUtc();
    if (dismissedUntil == null) {
      return false;
    }

    final DateTime resolvedNowUtc = (nowUtc ?? _nowUtc()).toUtc();
    return resolvedNowUtc.isBefore(dismissedUntil);
  }

  Future<void> dismiss({DateTime? nowUtc}) async {
    final DateTime resolvedNowUtc = (nowUtc ?? _nowUtc()).toUtc();
    final DateTime dismissedUntil = resolvedNowUtc.add(dismissalDuration);
    await _prefs.setString(dismissedUntilKey, dismissedUntil.toIso8601String());
  }

  AccountUpgradePromptEligibility evaluate({
    required bool isAnonymous,
    required int totalCompletions,
    required int currentDailyStreak,
    DateTime? nowUtc,
  }) {
    final DateTime resolvedNowUtc = (nowUtc ?? _nowUtc()).toUtc();
    final DateTime? dismissedUntil = dismissedUntilUtc();
    final bool isCurrentlyDismissed =
        dismissedUntil != null && resolvedNowUtc.isBefore(dismissedUntil);
    final bool meetsThreshold =
        totalCompletions >= minimumCompletions ||
        currentDailyStreak >= minimumDailyStreak;

    return AccountUpgradePromptEligibility(
      isAnonymous: isAnonymous,
      totalCompletions: totalCompletions,
      currentDailyStreak: currentDailyStreak,
      dismissedUntilUtc: dismissedUntil,
      evaluatedAtUtc: resolvedNowUtc,
      shouldShow: isAnonymous && meetsThreshold && !isCurrentlyDismissed,
    );
  }
}

class AccountUpgradePromptEligibility {
  const AccountUpgradePromptEligibility({
    required this.isAnonymous,
    required this.totalCompletions,
    required this.currentDailyStreak,
    required this.dismissedUntilUtc,
    required this.evaluatedAtUtc,
    required this.shouldShow,
  });

  final bool isAnonymous;
  final int totalCompletions;
  final int currentDailyStreak;
  final DateTime? dismissedUntilUtc;
  final DateTime evaluatedAtUtc;
  final bool shouldShow;

  bool get meetsThreshold =>
      totalCompletions >= AccountUpgradePromptService.minimumCompletions ||
      currentDailyStreak >= AccountUpgradePromptService.minimumDailyStreak;

  bool get isDismissed =>
      dismissedUntilUtc != null && evaluatedAtUtc.isBefore(dismissedUntilUtc!);
}
