import 'package:app/shared/account/account_upgrade_prompt_service.dart';
import 'package:app/shared/analytics/analytics_events.dart';
import 'package:app/shared/analytics/analytics_service.dart';
import 'package:app/shared/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseAnalyticsService', () {
    test('logs only sanitized puzzle payload fields', () async {
      final client = _FakeAnalyticsClient();
      final service = FirebaseAnalyticsService(client: client);

      await service.puzzleCompleted(
        puzzleType: PuzzleType.sudokuClassic,
        mode: PuzzleMode.random,
        difficulty: 'easy',
        size: '9x9',
        elapsed: const Duration(seconds: 42),
        moveCount: 12,
        hintsUsed: 1,
      );

      expect(client.loggedEvents, hasLength(1));
      expect(client.loggedEvents.single.name, AnalyticsEvents.puzzleCompleted);
      expect(client.loggedEvents.single.parameters, <String, Object>{
        AnalyticsParameters.puzzleType: PuzzleType.sudokuClassic.key,
        AnalyticsParameters.mode: PuzzleMode.random.key,
        AnalyticsParameters.difficulty: 'easy',
        AnalyticsParameters.size: '9x9',
        AnalyticsParameters.elapsedMs: 42000,
        AnalyticsParameters.moveCount: 12,
        AnalyticsParameters.hintsUsed: 1,
      });
      expect(
        client.loggedEvents.single.parameters.keys,
        isNot(
          contains(
            anyOf(
              'board',
              'solution',
              'puzzle_json',
              'player_state',
              'notes',
              'seed',
            ),
          ),
        ),
      );
    });

    test('logs upgrade prompt with aggregate-only fields', () async {
      final client = _FakeAnalyticsClient();
      final service = FirebaseAnalyticsService(client: client);

      await service.authUpgradePromptShown(
        AccountUpgradePromptEligibility(
          isAnonymous: true,
          totalCompletions: 3,
          currentDailyStreak: 4,
          dismissedUntilUtc: null,
          evaluatedAtUtc: DateTime.utc(2026, 6, 27, 12),
          shouldShow: true,
        ),
      );

      expect(client.loggedEvents.single.parameters, <String, Object>{
        AnalyticsParameters.totalCompletions: 3,
        AnalyticsParameters.currentDailyStreak: 4,
      });
    });

    test('swallows analytics client failures', () async {
      final client = _FakeAnalyticsClient(throwOnLog: true);
      final service = FirebaseAnalyticsService(client: client);

      await expectLater(service.appOpen(), completes);
      await expectLater(
        service.syncFailed(attempted: 2, failed: 1, reason: 'network'),
        completes,
      );
    });
  });
}

class _FakeAnalyticsClient implements AnalyticsClient {
  _FakeAnalyticsClient({this.throwOnLog = false});

  final bool throwOnLog;
  final List<_LoggedClientEvent> loggedEvents = <_LoggedClientEvent>[];

  @override
  Future<void> logAppOpen() async {
    if (throwOnLog) {
      throw StateError('logAppOpen failed');
    }
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (throwOnLog) {
      throw StateError('logEvent failed');
    }
    loggedEvents.add(
      _LoggedClientEvent(
        name: name,
        parameters: Map<String, Object>.unmodifiable(
          parameters ?? const <String, Object>{},
        ),
      ),
    );
  }

  @override
  Future<void> logScreenView({String? screenName, String? screenClass}) async {
    if (throwOnLog) {
      throw StateError('logScreenView failed');
    }
  }
}

class _LoggedClientEvent {
  const _LoggedClientEvent({required this.name, required this.parameters});

  final String name;
  final Map<String, Object> parameters;
}
