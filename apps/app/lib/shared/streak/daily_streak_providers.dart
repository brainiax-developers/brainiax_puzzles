import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'daily_streak_service.dart';

/// Injectable UTC "now" used by Daily Challenge providers and tests.
final dailyNowProvider = Provider<DateTime>((ref) {
  return DateTime.now().toUtc();
});

/// Pure streak service shared by storage and provider layers.
final dailyStreakServiceProvider = Provider<DailyStreakService>((ref) {
  return const DailyStreakService();
});
