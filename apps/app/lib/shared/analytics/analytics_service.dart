import 'package:firebase_analytics/firebase_analytics.dart';

import '../account/account_upgrade_prompt_service.dart';
import '../models/puzzle_mode.dart';
import '../models/puzzle_type.dart';
import 'analytics_events.dart';

abstract interface class AnalyticsService {
  Future<void> appOpen();

  Future<void> profileViewed();

  Future<void> puzzleStarted({
    required PuzzleType puzzleType,
    required PuzzleMode mode,
    required String difficulty,
    required String size,
  });

  Future<void> puzzleCompleted({
    required PuzzleType puzzleType,
    required PuzzleMode mode,
    required String difficulty,
    required String size,
    required Duration elapsed,
    required int moveCount,
    required int hintsUsed,
  });

  Future<void> hintUsed({
    required PuzzleType puzzleType,
    required PuzzleMode mode,
    required String difficulty,
    required String size,
    required int hintsUsed,
  });

  Future<void> dailyStarted({
    required PuzzleType puzzleType,
    required String difficulty,
    required String size,
  });

  Future<void> dailyCompleted({
    required PuzzleType puzzleType,
    required String difficulty,
    required String size,
    required Duration elapsed,
    required int moveCount,
    required int hintsUsed,
  });

  Future<void> authUpgradePromptShown(AccountUpgradePromptEligibility prompt);

  Future<void> authLinkSucceeded({
    required String provider,
    required String upgradePath,
  });

  Future<void> syncSucceeded({required int attempted, required int synced});

  Future<void> syncFailed({
    required int attempted,
    required int failed,
    String? reason,
  });
}

abstract interface class AnalyticsClient {
  Future<void> logAppOpen();

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  });

  Future<void> logScreenView({String? screenName, String? screenClass});
}

class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({
    FirebaseAnalytics? analytics,
    AnalyticsClient? client,
  }) : _client =
           client ??
           FirebaseAnalyticsClient(analytics ?? FirebaseAnalytics.instance);

  final AnalyticsClient _client;

  @override
  Future<void> appOpen() {
    return _guard(_client.logAppOpen);
  }

  @override
  Future<void> profileViewed() {
    return _guard(
      () => _client.logScreenView(
        screenName: 'profile',
        screenClass: 'ProfileScreen',
      ),
    );
  }

  @override
  Future<void> puzzleStarted({
    required PuzzleType puzzleType,
    required PuzzleMode mode,
    required String difficulty,
    required String size,
  }) {
    return _logEvent(
      AnalyticsEvents.puzzleStarted,
      _puzzleParameters(
        puzzleType: puzzleType,
        mode: mode,
        difficulty: difficulty,
        size: size,
      ),
    );
  }

  @override
  Future<void> puzzleCompleted({
    required PuzzleType puzzleType,
    required PuzzleMode mode,
    required String difficulty,
    required String size,
    required Duration elapsed,
    required int moveCount,
    required int hintsUsed,
  }) {
    return _logEvent(
      AnalyticsEvents.puzzleCompleted,
      _puzzleParameters(
        puzzleType: puzzleType,
        mode: mode,
        difficulty: difficulty,
        size: size,
        elapsed: elapsed,
        moveCount: moveCount,
        hintsUsed: hintsUsed,
      ),
    );
  }

  @override
  Future<void> hintUsed({
    required PuzzleType puzzleType,
    required PuzzleMode mode,
    required String difficulty,
    required String size,
    required int hintsUsed,
  }) {
    return _logEvent(
      AnalyticsEvents.hintUsed,
      _puzzleParameters(
        puzzleType: puzzleType,
        mode: mode,
        difficulty: difficulty,
        size: size,
        hintsUsed: hintsUsed,
      ),
    );
  }

  @override
  Future<void> dailyStarted({
    required PuzzleType puzzleType,
    required String difficulty,
    required String size,
  }) {
    return _logEvent(
      AnalyticsEvents.dailyStarted,
      _puzzleParameters(
        puzzleType: puzzleType,
        mode: PuzzleMode.daily,
        difficulty: difficulty,
        size: size,
      ),
    );
  }

  @override
  Future<void> dailyCompleted({
    required PuzzleType puzzleType,
    required String difficulty,
    required String size,
    required Duration elapsed,
    required int moveCount,
    required int hintsUsed,
  }) {
    return _logEvent(
      AnalyticsEvents.dailyCompleted,
      _puzzleParameters(
        puzzleType: puzzleType,
        mode: PuzzleMode.daily,
        difficulty: difficulty,
        size: size,
        elapsed: elapsed,
        moveCount: moveCount,
        hintsUsed: hintsUsed,
      ),
    );
  }

  @override
  Future<void> authUpgradePromptShown(AccountUpgradePromptEligibility prompt) {
    return _logEvent(AnalyticsEvents.authUpgradePromptShown, <String, Object>{
      AnalyticsParameters.totalCompletions: prompt.totalCompletions,
      AnalyticsParameters.currentDailyStreak: prompt.currentDailyStreak,
    });
  }

  @override
  Future<void> authLinkSucceeded({
    required String provider,
    required String upgradePath,
  }) {
    return _logEvent(AnalyticsEvents.authLinkSucceeded, <String, Object>{
      AnalyticsParameters.provider: provider,
      AnalyticsParameters.upgradePath: upgradePath,
    });
  }

  @override
  Future<void> syncSucceeded({required int attempted, required int synced}) {
    return _logEvent(AnalyticsEvents.syncSucceeded, <String, Object>{
      AnalyticsParameters.attempted: attempted,
      AnalyticsParameters.synced: synced,
    });
  }

  @override
  Future<void> syncFailed({
    required int attempted,
    required int failed,
    String? reason,
  }) {
    final Map<String, Object> parameters = <String, Object>{
      AnalyticsParameters.attempted: attempted,
      AnalyticsParameters.failed: failed,
    };
    if (reason != null && reason.isNotEmpty) {
      parameters[AnalyticsParameters.reason] = reason;
    }
    return _logEvent(AnalyticsEvents.syncFailed, parameters);
  }

  Map<String, Object> _puzzleParameters({
    required PuzzleType puzzleType,
    required PuzzleMode mode,
    required String difficulty,
    required String size,
    Duration? elapsed,
    int? moveCount,
    int? hintsUsed,
  }) {
    final Map<String, Object> parameters = <String, Object>{
      AnalyticsParameters.puzzleType: puzzleType.key,
      AnalyticsParameters.mode: mode.key,
      AnalyticsParameters.difficulty: difficulty,
      AnalyticsParameters.size: size,
    };
    if (elapsed != null) {
      parameters[AnalyticsParameters.elapsedMs] = elapsed.inMilliseconds;
    }
    if (moveCount != null) {
      parameters[AnalyticsParameters.moveCount] = moveCount;
    }
    if (hintsUsed != null) {
      parameters[AnalyticsParameters.hintsUsed] = hintsUsed;
    }
    return parameters;
  }

  Future<void> _logEvent(String name, Map<String, Object> parameters) {
    return _guard(() => _client.logEvent(name: name, parameters: parameters));
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Analytics must never affect gameplay or account flows.
    }
  }
}

class FirebaseAnalyticsClient implements AnalyticsClient {
  FirebaseAnalyticsClient(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logAppOpen() {
    return _analytics.logAppOpen();
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> logScreenView({String? screenName, String? screenClass}) {
    return _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }
}

class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> appOpen() async {}

  @override
  Future<void> authLinkSucceeded({
    required String provider,
    required String upgradePath,
  }) async {}

  @override
  Future<void> authUpgradePromptShown(
    AccountUpgradePromptEligibility prompt,
  ) async {}

  @override
  Future<void> dailyCompleted({
    required PuzzleType puzzleType,
    required String difficulty,
    required String size,
    required Duration elapsed,
    required int moveCount,
    required int hintsUsed,
  }) async {}

  @override
  Future<void> dailyStarted({
    required PuzzleType puzzleType,
    required String difficulty,
    required String size,
  }) async {}

  @override
  Future<void> hintUsed({
    required PuzzleType puzzleType,
    required PuzzleMode mode,
    required String difficulty,
    required String size,
    required int hintsUsed,
  }) async {}

  @override
  Future<void> profileViewed() async {}

  @override
  Future<void> puzzleCompleted({
    required PuzzleType puzzleType,
    required PuzzleMode mode,
    required String difficulty,
    required String size,
    required Duration elapsed,
    required int moveCount,
    required int hintsUsed,
  }) async {}

  @override
  Future<void> puzzleStarted({
    required PuzzleType puzzleType,
    required PuzzleMode mode,
    required String difficulty,
    required String size,
  }) async {}

  @override
  Future<void> syncFailed({
    required int attempted,
    required int failed,
    String? reason,
  }) async {}

  @override
  Future<void> syncSucceeded({
    required int attempted,
    required int synced,
  }) async {}
}
