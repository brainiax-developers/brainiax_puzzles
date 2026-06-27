abstract final class AnalyticsEvents {
  static const String appOpen = 'app_open';
  static const String profileViewed = 'profile_viewed';
  static const String puzzleStarted = 'puzzle_started';
  static const String puzzleCompleted = 'puzzle_completed';
  static const String hintUsed = 'hint_used';
  static const String dailyStarted = 'daily_started';
  static const String dailyCompleted = 'daily_completed';
  static const String authUpgradePromptShown = 'auth_upgrade_prompt_shown';
  static const String authLinkSucceeded = 'auth_link_succeeded';
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
  static const String attempted = 'attempted';
  static const String synced = 'synced';
  static const String failed = 'failed';
  static const String reason = 'reason';
}
