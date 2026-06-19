import 'package:app/features/daily/daily_hub_provider.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/providers/daily_status_provider.dart';
import 'package:app/shared/providers/puzzle_local_store_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer buildContainer({
    required DateTime nowUtc,
    required List<PuzzleType> puzzleTypes,
    required Map<PuzzleType, DailyStatus> statuses,
    required DailyStreakStatus streak,
    required List<ActivePuzzleRun> activeRuns,
    required List<PuzzleCompletionRecord> completionRecords,
  }) {
    return ProviderContainer(
      overrides: [
        dailyNowProvider.overrideWith((ref) => nowUtc),
        dailyPuzzleTypesProvider.overrideWith((ref) => puzzleTypes),
        dailyStatusProvider.overrideWith((ref) async => statuses),
        dailyStreakStatusProvider.overrideWith((ref) async => streak),
        activeRunsProvider.overrideWith((ref) async => activeRuns),
        completionRecordsProvider.overrideWith(
          (ref) async => completionRecords,
        ),
      ],
    );
  }

  group('dailyHubProvider', () {
    test(
      'marks the week using any daily completion, not all daily puzzles',
      () async {
        final DateTime nowUtc = DateTime.utc(2026, 6, 19, 12);
        final Duration reset = const Duration(hours: 8, minutes: 42);
        final List<PuzzleType> puzzleTypes = <PuzzleType>[
          PuzzleType.sudokuClassic,
          PuzzleType.nonogramMono,
          PuzzleType.kakuroClassic,
        ];
        final ProviderContainer container = buildContainer(
          nowUtc: nowUtc,
          puzzleTypes: puzzleTypes,
          statuses: <PuzzleType, DailyStatus>{
            PuzzleType.sudokuClassic: DailyStatus(
              puzzleType: PuzzleType.sudokuClassic,
              isCompleted: true,
              completedAt: nowUtc,
              timeUntilReset: reset,
            ),
            PuzzleType.nonogramMono: DailyStatus(
              puzzleType: PuzzleType.nonogramMono,
              isCompleted: false,
              completedAt: null,
              timeUntilReset: reset,
            ),
            PuzzleType.kakuroClassic: DailyStatus(
              puzzleType: PuzzleType.kakuroClassic,
              isCompleted: false,
              completedAt: null,
              timeUntilReset: reset,
            ),
          },
          streak: const DailyStreakStatus(
            currentStreak: 5,
            bestStreak: 5,
            lastCompletedDateKeyUtc: '2026-06-19',
          ),
          activeRuns: const [],
          completionRecords: <PuzzleCompletionRecord>[
            _dailyRecord(
              puzzleType: PuzzleType.nonogramMono,
              dateKeyUtc: '2026-06-16',
              completedAtUtc: DateTime.utc(2026, 6, 16, 9),
              elapsedMs: const Duration(minutes: 8).inMilliseconds,
            ),
            _dailyRecord(
              puzzleType: PuzzleType.sudokuClassic,
              dateKeyUtc: '2026-06-19',
              completedAtUtc: DateTime.utc(2026, 6, 19, 10),
              elapsedMs: const Duration(minutes: 5, seconds: 20).inMilliseconds,
            ),
          ],
        );
        addTearDown(container.dispose);

        final DailyHubViewData view = await container.read(
          dailyHubProvider.future,
        );

        expect(view.completedCount, 1);
        expect(view.totalCount, 3);
        expect(view.hasAnyCompletedToday, isTrue);
        expect(view.statusCard.title, 'Streak secured for today 🔥');
        expect(view.week[0].state, DailyHubWeekdayState.unknown);
        expect(view.week[1].state, DailyHubWeekdayState.completed);
        expect(view.week[2].state, DailyHubWeekdayState.missed);
        expect(view.week[3].state, DailyHubWeekdayState.missed);
        expect(view.week[4].state, DailyHubWeekdayState.todayCompleted);
        expect(view.week[5].state, DailyHubWeekdayState.future);
        expect(view.week[6].state, DailyHubWeekdayState.future);
      },
    );

    test(
      'shows start your daily streak for a new user without a streak',
      () async {
        final DateTime nowUtc = DateTime.utc(2026, 6, 19, 12);
        final Duration reset = const Duration(hours: 8, minutes: 42);
        final ProviderContainer container = buildContainer(
          nowUtc: nowUtc,
          puzzleTypes: const <PuzzleType>[
            PuzzleType.sudokuClassic,
            PuzzleType.nonogramMono,
          ],
          statuses: <PuzzleType, DailyStatus>{
            PuzzleType.sudokuClassic: DailyStatus(
              puzzleType: PuzzleType.sudokuClassic,
              isCompleted: false,
              completedAt: null,
              timeUntilReset: reset,
            ),
            PuzzleType.nonogramMono: DailyStatus(
              puzzleType: PuzzleType.nonogramMono,
              isCompleted: false,
              completedAt: null,
              timeUntilReset: reset,
            ),
          },
          streak: DailyStreakStatus.empty,
          activeRuns: const [],
          completionRecords: const <PuzzleCompletionRecord>[],
        );
        addTearDown(container.dispose);

        final DailyHubViewData view = await container.read(
          dailyHubProvider.future,
        );

        expect(view.statusCard.title, 'Start your daily streak.');
        expect(view.statusCard.body, 'Complete any daily puzzle today.');
        expect(view.week[4].state, DailyHubWeekdayState.todayIncomplete);
      },
    );

    test(
      'builds play resume and completed card states from local data',
      () async {
        final DateTime nowUtc = DateTime.utc(2026, 6, 19, 12);
        final Duration reset = const Duration(hours: 8, minutes: 42);
        final ProviderContainer container = buildContainer(
          nowUtc: nowUtc,
          puzzleTypes: const <PuzzleType>[
            PuzzleType.sudokuClassic,
            PuzzleType.nonogramMono,
            PuzzleType.kakuroClassic,
          ],
          statuses: <PuzzleType, DailyStatus>{
            PuzzleType.sudokuClassic: DailyStatus(
              puzzleType: PuzzleType.sudokuClassic,
              isCompleted: true,
              completedAt: nowUtc,
              timeUntilReset: reset,
            ),
            PuzzleType.nonogramMono: DailyStatus(
              puzzleType: PuzzleType.nonogramMono,
              isCompleted: false,
              completedAt: null,
              timeUntilReset: reset,
            ),
            PuzzleType.kakuroClassic: DailyStatus(
              puzzleType: PuzzleType.kakuroClassic,
              isCompleted: false,
              completedAt: null,
              timeUntilReset: reset,
            ),
          },
          streak: const DailyStreakStatus(
            currentStreak: 2,
            bestStreak: 2,
            lastCompletedDateKeyUtc: '2026-06-18',
          ),
          activeRuns: <ActivePuzzleRun>[
            ActivePuzzleRun(
              puzzleType: PuzzleType.nonogramMono,
              mode: PuzzleMode.daily,
              difficulty: 'Daily',
              size: '10x10',
              seed: 'daily-nonogram',
              generatedPuzzleJson: const <String, Object?>{},
              createdAtUtc: DateTime.utc(2026, 6, 19, 8),
              updatedAtUtc: DateTime.utc(2026, 6, 19, 9),
              elapsedMs: const Duration(minutes: 3).inMilliseconds,
              moveCount: 0,
              hintsUsed: 0,
              isSolved: false,
              dailyDateKeyUtc: '2026-06-19',
            ),
          ],
          completionRecords: <PuzzleCompletionRecord>[
            _dailyRecord(
              puzzleType: PuzzleType.sudokuClassic,
              dateKeyUtc: '2026-06-19',
              completedAtUtc: DateTime.utc(2026, 6, 19, 7),
              elapsedMs: const Duration(minutes: 6, seconds: 10).inMilliseconds,
              difficulty: 'easy',
            ),
          ],
        );
        addTearDown(container.dispose);

        final DailyHubViewData view = await container.read(
          dailyHubProvider.future,
        );

        expect(view.entries[0].cardState, DailyHubCardState.completed);
        expect(
          view.entries[0].solvedDuration,
          const Duration(minutes: 6, seconds: 10),
        );
        expect(view.entries[1].cardState, DailyHubCardState.resume);
        expect(view.entries[2].cardState, DailyHubCardState.play);
        expect(view.uncompletedPuzzleTypes, <PuzzleType>[
          PuzzleType.nonogramMono,
          PuzzleType.kakuroClassic,
        ]);
      },
    );
  });
}

PuzzleCompletionRecord _dailyRecord({
  required PuzzleType puzzleType,
  required String dateKeyUtc,
  required DateTime completedAtUtc,
  required int elapsedMs,
  String difficulty = 'Daily',
}) {
  return PuzzleCompletionRecord(
    id: '${puzzleType.key}:$dateKeyUtc',
    puzzleType: puzzleType,
    mode: PuzzleMode.daily,
    difficulty: difficulty,
    size: 'daily',
    seed: 'seed-$dateKeyUtc',
    completedAtUtc: completedAtUtc,
    elapsedMs: elapsedMs,
    moveCount: 0,
    hintsUsed: 0,
    dailyDateKeyUtc: dateKeyUtc,
  );
}
