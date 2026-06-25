import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/models.dart';
import '../../shared/providers/daily_status_provider.dart';
import '../../shared/providers/puzzle_local_store_providers.dart';

enum DailyHubCardState { play, resume, completed }

enum DailyHubWeekdayState {
  completed,
  missed,
  todayIncomplete,
  todayCompleted,
  future,
  unknown,
}

class DailyHubWeekday {
  const DailyHubWeekday({
    required this.dateUtc,
    required this.dateKeyUtc,
    required this.label,
    required this.state,
  });

  final DateTime dateUtc;
  final String dateKeyUtc;
  final String label;
  final DailyHubWeekdayState state;
}

class DailyHubPuzzleEntry {
  const DailyHubPuzzleEntry({
    required this.puzzleType,
    required this.cardState,
    required this.solvedDuration,
    required this.difficultyLabel,
  });

  final PuzzleType puzzleType;
  final DailyHubCardState cardState;
  final Duration? solvedDuration;
  final String difficultyLabel;

  bool get isCompleted => cardState == DailyHubCardState.completed;
}

class DailyHubStatusCard {
  const DailyHubStatusCard({
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.isActionEnabled,
  });

  final String title;
  final String body;
  final String ctaLabel;
  final bool isActionEnabled;
}

class DailyHubViewData {
  const DailyHubViewData({
    required this.streakCount,
    required this.timeUntilReset,
    required this.completedCount,
    required this.totalCount,
    required this.week,
    required this.entries,
    required this.statusCard,
    required this.uncompletedPuzzleTypes,
  });

  final int streakCount;
  final Duration timeUntilReset;
  final int completedCount;
  final int totalCount;
  final List<DailyHubWeekday> week;
  final List<DailyHubPuzzleEntry> entries;
  final DailyHubStatusCard statusCard;
  final List<PuzzleType> uncompletedPuzzleTypes;

  bool get hasAnyCompletedToday => completedCount > 0;
  bool get allCompleted => totalCount > 0 && completedCount == totalCount;
  int get remainingCount => totalCount - completedCount;
}

final dailyHubProvider = FutureProvider<DailyHubViewData>((ref) async {
  final DateTime nowUtc = ref.watch(dailyNowProvider);
  final DateTime todayUtc = DailyUtcDate.today(now: nowUtc);
  final String todayKey = DailyUtcDate.keyFor(todayUtc);
  final List<PuzzleType> puzzleTypes = ref.watch(dailyPuzzleTypesProvider);
  final Map<PuzzleType, DailyStatus> statuses = await ref.watch(
    dailyStatusProvider.future,
  );
  final DailyStreakStatus streak = await ref.watch(
    dailyStreakStatusProvider.future,
  );
  final List<ActivePuzzleRun> activeRuns = await ref.watch(
    activeRunsProvider.future,
  );
  final List<PuzzleCompletionRecord> completionRecords = await ref.watch(
    completionRecordsProvider.future,
  );

  final Duration timeUntilReset = statuses.values.isNotEmpty
      ? statuses.values.first.timeUntilReset
      : DailyUtcDate.timeUntilReset(now: nowUtc);
  final List<PuzzleCompletionRecord> dailyRecords = completionRecords
      .where((record) => record.mode == PuzzleMode.daily)
      .toList(growable: false);
  final Map<PuzzleType, PuzzleCompletionRecord> todayCompletionsByType =
      _latestCompletionByType(
        dailyRecords.where((record) => record.dailyDateKeyUtc == todayKey),
      );
  final Map<PuzzleType, ActivePuzzleRun> todayDailyRunsByType = {
    for (final run in activeRuns)
      if (run.mode == PuzzleMode.daily && run.dailyDateKeyUtc == todayKey)
        run.puzzleType: run,
  };

  final List<DailyHubPuzzleEntry> entries = <DailyHubPuzzleEntry>[
    for (final puzzleType in puzzleTypes)
      _buildEntry(
        puzzleType: puzzleType,
        completion: todayCompletionsByType[puzzleType],
        activeRun: todayDailyRunsByType[puzzleType],
      ),
  ];
  final List<PuzzleType> uncompletedPuzzleTypes = entries
      .where((entry) => !entry.isCompleted)
      .map((entry) => entry.puzzleType)
      .toList(growable: false);
  final int completedCount = entries.where((entry) => entry.isCompleted).length;

  return DailyHubViewData(
    streakCount: streak.currentStreak,
    timeUntilReset: timeUntilReset,
    completedCount: completedCount,
    totalCount: puzzleTypes.length,
    week: _buildWeek(todayUtc: todayUtc, dailyRecords: dailyRecords),
    entries: entries,
    statusCard: _buildStatusCard(
      streakCount: streak.currentStreak,
      completedCount: completedCount,
      totalCount: puzzleTypes.length,
      timeUntilReset: timeUntilReset,
    ),
    uncompletedPuzzleTypes: uncompletedPuzzleTypes,
  );
});

DailyHubPuzzleEntry _buildEntry({
  required PuzzleType puzzleType,
  required PuzzleCompletionRecord? completion,
  required ActivePuzzleRun? activeRun,
}) {
  if (completion != null) {
    return DailyHubPuzzleEntry(
      puzzleType: puzzleType,
      cardState: DailyHubCardState.completed,
      solvedDuration: Duration(milliseconds: completion.elapsedMs),
      difficultyLabel: completion.difficulty,
    );
  }

  if (activeRun != null) {
    return DailyHubPuzzleEntry(
      puzzleType: puzzleType,
      cardState: DailyHubCardState.resume,
      solvedDuration: null,
      difficultyLabel: activeRun.difficulty,
    );
  }

  return DailyHubPuzzleEntry(
    puzzleType: puzzleType,
    cardState: DailyHubCardState.play,
    solvedDuration: null,
    difficultyLabel: 'Daily',
  );
}

List<DailyHubWeekday> _buildWeek({
  required DateTime todayUtc,
  required List<PuzzleCompletionRecord> dailyRecords,
}) {
  final DateTime weekStart = todayUtc.subtract(
    Duration(days: todayUtc.weekday - 1),
  );
  final Set<String> completedKeys = dailyRecords
      .map((record) => record.dailyDateKeyUtc)
      .whereType<String>()
      .toSet();
  DateTime? firstTrackedDateUtc;
  for (final record in dailyRecords) {
    final String? dayKey = record.dailyDateKeyUtc;
    if (dayKey == null) {
      continue;
    }
    final DateTime parsed = DailyUtcDate.parseKey(dayKey);
    if (firstTrackedDateUtc == null || parsed.isBefore(firstTrackedDateUtc)) {
      firstTrackedDateUtc = parsed;
    }
  }

  return List<DailyHubWeekday>.generate(7, (index) {
    final DateTime dateUtc = weekStart.add(Duration(days: index));
    final String dateKeyUtc = DailyUtcDate.keyFor(dateUtc);
    final DailyHubWeekdayState state;
    if (dateUtc.isAfter(todayUtc)) {
      state = DailyHubWeekdayState.future;
    } else if (completedKeys.contains(dateKeyUtc)) {
      state = dateUtc == todayUtc
          ? DailyHubWeekdayState.todayCompleted
          : DailyHubWeekdayState.completed;
    } else if (dateUtc == todayUtc) {
      state = DailyHubWeekdayState.todayIncomplete;
    } else if (firstTrackedDateUtc != null &&
        !dateUtc.isBefore(firstTrackedDateUtc)) {
      state = DailyHubWeekdayState.missed;
    } else {
      state = DailyHubWeekdayState.unknown;
    }

    return DailyHubWeekday(
      dateUtc: dateUtc,
      dateKeyUtc: dateKeyUtc,
      label: _weekdayLabel(dateUtc.weekday),
      state: state,
    );
  });
}

DailyHubStatusCard _buildStatusCard({
  required int streakCount,
  required int completedCount,
  required int totalCount,
  required Duration timeUntilReset,
}) {
  final String resetText = _formatResetCountdown(timeUntilReset);
  if (totalCount > 0 && completedCount == totalCount) {
    return DailyHubStatusCard(
      title: 'Daily set complete!',
      body: 'Next set unlocks in $resetText.',
      ctaLabel: 'All done today',
      isActionEnabled: false,
    );
  }

  if (completedCount > 0) {
    final int remainingCount = totalCount - completedCount;
    final String puzzleLabel = remainingCount == 1 ? 'puzzle' : 'puzzles';
    return DailyHubStatusCard(
      title: 'Streak secured for today \u{1F525}',
      body:
          '$remainingCount $puzzleLabel left if you want more. Next set in $resetText.',
      ctaLabel: 'Play another',
      isActionEnabled: true,
    );
  }

  if (streakCount > 0) {
    return const DailyHubStatusCard(
      title: 'Keep your streak alive!',
      body: 'Complete any daily puzzle before reset.',
      ctaLabel: 'Keep streak going',
      isActionEnabled: true,
    );
  }

  return const DailyHubStatusCard(
    title: 'Start your daily streak.',
    body: 'Complete any daily puzzle today.',
    ctaLabel: 'Play a puzzle',
    isActionEnabled: true,
  );
}

Map<PuzzleType, PuzzleCompletionRecord> _latestCompletionByType(
  Iterable<PuzzleCompletionRecord> records,
) {
  final Map<PuzzleType, PuzzleCompletionRecord> byType = {};
  for (final record in records) {
    final PuzzleCompletionRecord? current = byType[record.puzzleType];
    if (current == null ||
        record.completedAtUtc.isAfter(current.completedAtUtc)) {
      byType[record.puzzleType] = record;
    }
  }
  return byType;
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Mon';
    case DateTime.tuesday:
      return 'Tue';
    case DateTime.wednesday:
      return 'Wed';
    case DateTime.thursday:
      return 'Thu';
    case DateTime.friday:
      return 'Fri';
    case DateTime.saturday:
      return 'Sat';
    case DateTime.sunday:
      return 'Sun';
  }
  return '';
}

String _formatResetCountdown(Duration duration) {
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}
