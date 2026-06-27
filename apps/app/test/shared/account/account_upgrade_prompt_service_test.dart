import 'package:app/shared/account/account_upgrade_prompt_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AccountUpgradePromptService', () {
    test('shows only for anonymous users who meet the threshold', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DateTime nowUtc = DateTime.utc(2026, 6, 27, 12);
      final service = AccountUpgradePromptService(prefs, nowUtc: () => nowUtc);

      expect(
        service
            .evaluate(
              isAnonymous: false,
              totalCompletions: 8,
              currentDailyStreak: 4,
            )
            .shouldShow,
        isFalse,
      );

      expect(
        service
            .evaluate(
              isAnonymous: true,
              totalCompletions: 2,
              currentDailyStreak: 2,
            )
            .shouldShow,
        isFalse,
      );

      expect(
        service
            .evaluate(
              isAnonymous: true,
              totalCompletions: 3,
              currentDailyStreak: 0,
            )
            .shouldShow,
        isTrue,
      );

      expect(
        service
            .evaluate(
              isAnonymous: true,
              totalCompletions: 1,
              currentDailyStreak: 3,
            )
            .shouldShow,
        isTrue,
      );
    });

    test('dismiss hides the prompt for seven days', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DateTime nowUtc = DateTime.utc(2026, 6, 27, 12);
      final service = AccountUpgradePromptService(prefs, nowUtc: () => nowUtc);

      await service.dismiss();

      expect(
        prefs.getString(AccountUpgradePromptService.dismissedUntilKey),
        equals(
          nowUtc
              .add(AccountUpgradePromptService.dismissalDuration)
              .toIso8601String(),
        ),
      );
      expect(service.isDismissed(nowUtc: nowUtc), isTrue);
      expect(
        service.isDismissed(
          nowUtc: nowUtc.add(AccountUpgradePromptService.dismissalDuration),
        ),
        isFalse,
      );
    });

    test('stays hidden while dismissal is still active', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AccountUpgradePromptService.dismissedUntilKey: DateTime.utc(
          2099,
          1,
          1,
        ).toIso8601String(),
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final service = AccountUpgradePromptService(prefs);

      expect(
        service
            .evaluate(
              isAnonymous: true,
              totalCompletions: 10,
              currentDailyStreak: 10,
            )
            .shouldShow,
        isFalse,
      );
    });
  });
}
