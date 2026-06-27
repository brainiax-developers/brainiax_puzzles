import 'package:app/shared/account/account_upgrade_prompt_service.dart';
import 'package:app/shared/analytics/analytics_events.dart';
import 'package:app/shared/analytics/analytics_service.dart';
import 'package:app/shared/models/models.dart';

class LoggedAnalyticsEvent {
  const LoggedAnalyticsEvent({
    required this.name,
    this.parameters = const <String, Object?>{},
  });

  final String name;
  final Map<String, Object?> parameters;
}

class FakeAnalyticsService implements AnalyticsService {
  final List<LoggedAnalyticsEvent> events = <LoggedAnalyticsEvent>[];

  LoggedAnalyticsEvent? lastEventNamed(String name) {
    for (final LoggedAnalyticsEvent event in events.reversed) {
      if (event.name == name) {
        return event;
      }
    }
    return null;
  }

  @override
  Future<void> appOpen() async {
    events.add(const LoggedAnalyticsEvent(name: AnalyticsEvents.appOpen));
  }

  @override
  Future<void> profileViewed() async {
    events.add(
      const LoggedAnalyticsEvent(
        name: AnalyticsEvents.profileViewed,
        parameters: <String, Object?>{
          AnalyticsParameters.screenName: 'profile',
          AnalyticsParameters.screenClass: 'ProfileScreen',
        },
      ),
    );
  }

  @override
  Future<void> puzzleStarted({
    required PuzzleType puzzleType,
    required PuzzleMode mode,
    required String difficulty,
    required String size,
  }) async {
    events.add(
      LoggedAnalyticsEvent(
        name: AnalyticsEvents.puzzleStarted,
        parameters: <String, Object?>{
          AnalyticsParameters.puzzleType: puzzleType.key,
          AnalyticsParameters.mode: mode.key,
          AnalyticsParameters.difficulty: difficulty,
          AnalyticsParameters.size: size,
        },
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
  }) async {
    events.add(
      LoggedAnalyticsEvent(
        name: AnalyticsEvents.puzzleCompleted,
        parameters: <String, Object?>{
          AnalyticsParameters.puzzleType: puzzleType.key,
          AnalyticsParameters.mode: mode.key,
          AnalyticsParameters.difficulty: difficulty,
          AnalyticsParameters.size: size,
          AnalyticsParameters.elapsedMs: elapsed.inMilliseconds,
          AnalyticsParameters.moveCount: moveCount,
          AnalyticsParameters.hintsUsed: hintsUsed,
        },
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
  }) async {
    events.add(
      LoggedAnalyticsEvent(
        name: AnalyticsEvents.hintUsed,
        parameters: <String, Object?>{
          AnalyticsParameters.puzzleType: puzzleType.key,
          AnalyticsParameters.mode: mode.key,
          AnalyticsParameters.difficulty: difficulty,
          AnalyticsParameters.size: size,
          AnalyticsParameters.hintsUsed: hintsUsed,
        },
      ),
    );
  }

  @override
  Future<void> dailyStarted({
    required PuzzleType puzzleType,
    required String difficulty,
    required String size,
  }) async {
    events.add(
      LoggedAnalyticsEvent(
        name: AnalyticsEvents.dailyStarted,
        parameters: <String, Object?>{
          AnalyticsParameters.puzzleType: puzzleType.key,
          AnalyticsParameters.mode: PuzzleMode.daily.key,
          AnalyticsParameters.difficulty: difficulty,
          AnalyticsParameters.size: size,
        },
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
  }) async {
    events.add(
      LoggedAnalyticsEvent(
        name: AnalyticsEvents.dailyCompleted,
        parameters: <String, Object?>{
          AnalyticsParameters.puzzleType: puzzleType.key,
          AnalyticsParameters.mode: PuzzleMode.daily.key,
          AnalyticsParameters.difficulty: difficulty,
          AnalyticsParameters.size: size,
          AnalyticsParameters.elapsedMs: elapsed.inMilliseconds,
          AnalyticsParameters.moveCount: moveCount,
          AnalyticsParameters.hintsUsed: hintsUsed,
        },
      ),
    );
  }

  @override
  Future<void> authUpgradePromptShown(
    AccountUpgradePromptEligibility prompt,
  ) async {
    events.add(
      LoggedAnalyticsEvent(
        name: AnalyticsEvents.authUpgradePromptShown,
        parameters: <String, Object?>{
          AnalyticsParameters.totalCompletions: prompt.totalCompletions,
          AnalyticsParameters.currentDailyStreak: prompt.currentDailyStreak,
        },
      ),
    );
  }

  @override
  Future<void> authAnonymousBootstrapStarted() async {
    events.add(
      const LoggedAnalyticsEvent(
        name: AnalyticsEvents.authAnonymousBootstrapStarted,
      ),
    );
  }

  @override
  Future<void> authAnonymousBootstrapSucceeded() async {
    events.add(
      const LoggedAnalyticsEvent(
        name: AnalyticsEvents.authAnonymousBootstrapSucceeded,
      ),
    );
  }

  @override
  Future<void> authAnonymousBootstrapFailed({String? reason}) async {
    events.add(
      LoggedAnalyticsEvent(
        name: AnalyticsEvents.authAnonymousBootstrapFailed,
        parameters: _reasonParameters(reason),
      ),
    );
  }

  @override
  Future<void> authFlowStarted({
    required String provider,
    required String upgradePath,
  }) async {
    _addAuthFlowEvent(
      linkEvent: AnalyticsEvents.authLinkStarted,
      signInEvent: AnalyticsEvents.authSignInStarted,
      provider: provider,
      upgradePath: upgradePath,
    );
  }

  @override
  Future<void> authFlowSucceeded({
    required String provider,
    required String upgradePath,
    String? resultStatus,
  }) async {
    _addAuthFlowEvent(
      linkEvent: AnalyticsEvents.authLinkSucceeded,
      signInEvent: AnalyticsEvents.authSignInSucceeded,
      provider: provider,
      upgradePath: upgradePath,
      resultStatus: resultStatus,
    );
  }

  @override
  Future<void> authFlowFailed({
    required String provider,
    required String upgradePath,
    String? reason,
    String? resultStatus,
  }) async {
    _addAuthFlowEvent(
      linkEvent: AnalyticsEvents.authLinkFailed,
      signInEvent: AnalyticsEvents.authSignInFailed,
      provider: provider,
      upgradePath: upgradePath,
      reason: reason,
      resultStatus: resultStatus,
    );
  }

  @override
  Future<void> authFlowCancelled({
    required String provider,
    required String upgradePath,
    String? resultStatus,
  }) async {
    _addAuthFlowEvent(
      linkEvent: AnalyticsEvents.authLinkCancelled,
      signInEvent: AnalyticsEvents.authSignInCancelled,
      provider: provider,
      upgradePath: upgradePath,
      resultStatus: resultStatus,
    );
  }

  @override
  Future<void> authFlowUnavailable({
    required String provider,
    required String upgradePath,
    String? reason,
    String? resultStatus,
  }) async {
    _addAuthFlowEvent(
      linkEvent: AnalyticsEvents.authLinkUnavailable,
      signInEvent: AnalyticsEvents.authSignInUnavailable,
      provider: provider,
      upgradePath: upgradePath,
      reason: reason,
      resultStatus: resultStatus,
    );
  }

  @override
  Future<void> authLinkSucceeded({
    required String provider,
    required String upgradePath,
  }) async {
    await authFlowSucceeded(provider: provider, upgradePath: upgradePath);
  }

  @override
  Future<void> syncSucceeded({
    required int attempted,
    required int synced,
  }) async {
    events.add(
      LoggedAnalyticsEvent(
        name: AnalyticsEvents.syncSucceeded,
        parameters: <String, Object?>{
          AnalyticsParameters.attempted: attempted,
          AnalyticsParameters.synced: synced,
        },
      ),
    );
  }

  @override
  Future<void> syncFailed({
    required int attempted,
    required int failed,
    String? reason,
  }) async {
    final Map<String, Object?> parameters = <String, Object?>{
      AnalyticsParameters.attempted: attempted,
      AnalyticsParameters.failed: failed,
    };
    if (reason != null) {
      parameters[AnalyticsParameters.reason] = reason;
    }
    events.add(
      LoggedAnalyticsEvent(
        name: AnalyticsEvents.syncFailed,
        parameters: parameters,
      ),
    );
  }

  void _addAuthFlowEvent({
    required String linkEvent,
    required String signInEvent,
    required String provider,
    required String upgradePath,
    String? reason,
    String? resultStatus,
  }) {
    final Map<String, Object?> parameters = <String, Object?>{
      AnalyticsParameters.provider: provider,
      AnalyticsParameters.upgradePath: upgradePath,
    };
    if (reason != null && reason.isNotEmpty) {
      parameters[AnalyticsParameters.reason] = reason;
    }
    if (resultStatus != null && resultStatus.isNotEmpty) {
      parameters[AnalyticsParameters.resultStatus] = resultStatus;
    }
    events.add(
      LoggedAnalyticsEvent(
        name: upgradePath == 'anonymous_link' ? linkEvent : signInEvent,
        parameters: parameters,
      ),
    );
  }

  Map<String, Object?> _reasonParameters(String? reason) {
    if (reason == null || reason.isEmpty) {
      return const <String, Object?>{};
    }
    return <String, Object?>{AnalyticsParameters.reason: reason};
  }
}
