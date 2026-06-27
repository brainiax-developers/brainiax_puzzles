abstract final class AnalyticsEvents {
  static const String appOpen = 'app_open';
  static const String profileViewed = 'profile_viewed';
  static const String puzzleStarted = 'puzzle_started';
  static const String puzzleCompleted = 'puzzle_completed';
  static const String hintUsed = 'hint_used';
  static const String dailyStarted = 'daily_started';
  static const String dailyCompleted = 'daily_completed';
  static const String authUpgradePromptShown = 'auth_upgrade_prompt_shown';
  static const String authAnonymousBootstrapStarted =
      'auth_anonymous_bootstrap_started';
  static const String authAnonymousBootstrapSucceeded =
      'auth_anonymous_bootstrap_succeeded';
  static const String authAnonymousBootstrapFailed =
      'auth_anonymous_bootstrap_failed';
  static const String authLinkStarted = 'auth_link_started';
  static const String authLinkSucceeded = 'auth_link_succeeded';
  static const String authLinkFailed = 'auth_link_failed';
  static const String authLinkCancelled = 'auth_link_cancelled';
  static const String authLinkUnavailable = 'auth_link_unavailable';
  static const String authSignInStarted = 'auth_sign_in_started';
  static const String authSignInSucceeded = 'auth_sign_in_succeeded';
  static const String authSignInFailed = 'auth_sign_in_failed';
  static const String authSignInCancelled = 'auth_sign_in_cancelled';
  static const String authSignInUnavailable = 'auth_sign_in_unavailable';
  static const String syncSucceeded = 'sync_succeeded';
  static const String syncFailed = 'sync_failed';
}

abstract final class AnalyticsParameters {
  static const String screenName = 'screen_name';
  static const String screenClass = 'screen_class';
  static const String puzzleType = 'puzzle_type';
  static const String mode = 'mode';
  static const String difficulty = 'difficulty';
  static const String size = 'size';
  static const String elapsedMs = 'elapsed_ms';
  static const String moveCount = 'move_count';
  static const String hintsUsed = 'hints_used';
  static const String totalCompletions = 'total_completions';
  static const String currentDailyStreak = 'current_daily_streak';
  static const String provider = 'provider';
  static const String upgradePath = 'upgrade_path';
  static const String resultStatus = 'result_status';
  static const String attempted = 'attempted';
  static const String synced = 'synced';
  static const String failed = 'failed';
  static const String reason = 'reason';
}
