import 'dart:convert';

import 'package:app/shared/models/models.dart';
import 'package:app/shared/services/favourite_puzzle_service.dart';
import 'package:app/shared/services/puzzle_local_store.dart';
import 'package:app/shared/services/puzzle_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_puzzle_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late PuzzleLocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = SharedPreferencesPuzzleLocalStore(prefs);
  });

  Map<String, Object> snapshotPrefs(SharedPreferences prefs) {
    return {for (final key in prefs.getKeys()) key: prefs.get(key) as Object};
  }

  group('DailyUtcDate', () {
    test('uses yyyy-MM-dd UTC date keys', () {
      final date = DateTime.parse('2024-01-01T23:30:00-05:00');

      expect(DailyUtcDate.keyFor(date), '2024-01-02');
      expect(DailyUtcDate.parseKey('2024-01-02'), DateTime.utc(2024, 1, 2));
    });

    test('time until reset points to next UTC midnight', () {
      final now = DateTime.utc(2024, 1, 1, 22, 30);

      expect(
        DailyUtcDate.timeUntilReset(now: now),
        const Duration(hours: 1, minutes: 30),
      );
      expect(DailyUtcDate.nextReset(now: now), DateTime.utc(2024, 1, 2));
    });
  });

  group('SharedPreferencesPuzzleLocalStore', () {
    test('persists and returns best times per puzzle and difficulty', () async {
      final type = PuzzleType.sudokuClassic;
      final day = DateTime.utc(2024, 1, 1, 12);

      await store.recordCompletion(
        puzzleType: type,
        difficulty: 'easy',
        completionTime: const Duration(seconds: 90),
        mode: PuzzleMode.random,
        completedAt: day,
        size: '9x9',
        seed: 'slow',
      );

      await store.recordCompletion(
        puzzleType: type,
        difficulty: 'easy',
        completionTime: const Duration(seconds: 120),
        mode: PuzzleMode.random,
        completedAt: day,
        size: '9x9',
        seed: 'slower',
      );

      await store.recordCompletion(
        puzzleType: type,
        difficulty: 'medium',
        completionTime: const Duration(seconds: 80),
        mode: PuzzleMode.random,
        completedAt: day,
        size: '9x9',
        seed: 'medium',
      );

      expect(await store.bestTime(type, 'easy'), const Duration(seconds: 90));
      expect(await store.bestTime(type, 'medium'), const Duration(seconds: 80));
    });

    test(
      'daily streak increments once per UTC day and random does not affect it',
      () async {
        final day1 = DateTime.utc(2024, 3, 1, 9);
        final day2 = day1.add(const Duration(days: 1));
        final day4 = day1.add(const Duration(days: 3));

        await store.recordCompletion(
          puzzleType: PuzzleType.nonogramMono,
          difficulty: 'normal',
          completionTime: const Duration(minutes: 7),
          mode: PuzzleMode.daily,
          completedAt: day1,
          dailyDateKeyUtc: DailyUtcDate.keyFor(day1),
        );
        expect((await store.dailyStreakStatus()).currentStreak, 1);
        expect((await store.dailyStreakStatus()).bestStreak, 1);

        await store.recordCompletion(
          puzzleType: PuzzleType.kakuroClassic,
          difficulty: 'normal',
          completionTime: const Duration(minutes: 6),
          mode: PuzzleMode.daily,
          completedAt: day1.add(const Duration(hours: 1)),
          dailyDateKeyUtc: DailyUtcDate.keyFor(day1),
        );
        expect((await store.dailyStreakStatus()).currentStreak, 1);

        await store.recordCompletion(
          puzzleType: PuzzleType.sudokuClassic,
          difficulty: 'normal',
          completionTime: const Duration(minutes: 5),
          mode: PuzzleMode.random,
          completedAt: day2,
        );
        expect((await store.dailyStreakStatus()).currentStreak, 1);

        await store.recordCompletion(
          puzzleType: PuzzleType.sudokuClassic,
          difficulty: 'normal',
          completionTime: const Duration(minutes: 4),
          mode: PuzzleMode.daily,
          completedAt: day2,
          dailyDateKeyUtc: DailyUtcDate.keyFor(day2),
        );
        expect((await store.dailyStreakStatus()).currentStreak, 2);
        expect((await store.dailyStreakStatus()).bestStreak, 2);

        await store.recordCompletion(
          puzzleType: PuzzleType.sudokuClassic,
          difficulty: 'normal',
          completionTime: const Duration(minutes: 3),
          mode: PuzzleMode.daily,
          completedAt: day4,
          dailyDateKeyUtc: DailyUtcDate.keyFor(day4),
        );
        expect((await store.dailyStreakStatus()).currentStreak, 1);
        expect((await store.dailyStreakStatus()).bestStreak, 2);
      },
    );

    test(
      'daily completion status and next uncompleted type use UTC keys',
      () async {
        const dateKey = '2024-05-20';

        await store.recordCompletion(
          puzzleType: PuzzleType.slitherlinkLoop,
          difficulty: 'expert',
          completionTime: const Duration(minutes: 12),
          mode: PuzzleMode.daily,
          completedAt: DateTime.utc(2024, 5, 20, 12),
          dailyDateKeyUtc: dateKey,
        );

        expect(
          await store.isDailyCompleted(PuzzleType.slitherlinkLoop, dateKey),
          isTrue,
        );
        expect(await store.completedDailyCount(dateKey), 1);
        expect(await store.anyDailyCompleted(dateKey), isTrue);
        expect(
          await store.nextUncompletedDailyPuzzleType(utcDayKey: dateKey),
          PuzzleType.sudokuClassic,
        );

        for (final type in PuzzleType.dailyChallengeTypes) {
          if (type == PuzzleType.slitherlinkLoop) continue;
          await store.recordCompletion(
            puzzleType: type,
            difficulty: 'easy',
            completionTime: const Duration(minutes: 2),
            mode: PuzzleMode.daily,
            completedAt: DateTime.utc(2024, 5, 20, 13),
            dailyDateKeyUtc: dateKey,
          );
        }

        expect(
          await store.completedDailyCount(dateKey),
          PuzzleType.dailyChallengeTypes.length,
        );
        expect(
          await store.nextUncompletedDailyPuzzleType(utcDayKey: dateKey),
          isNull,
        );
      },
    );

    test('completion records preserve random and daily metadata', () async {
      final randomRecord = await store.recordCompletion(
        puzzleType: PuzzleType.sudokuClassic,
        difficulty: 'expert',
        completionTime: const Duration(milliseconds: 123456),
        mode: PuzzleMode.random,
        completedAt: DateTime.utc(2024, 6, 1, 10),
        size: '9x9',
        seed: 'actual-seed',
        moveCount: 42,
        hintsUsed: 3,
      );
      final dailyRecord = await store.recordCompletion(
        puzzleType: PuzzleType.killerQueens,
        difficulty: 'hard',
        completionTime: const Duration(seconds: 77),
        mode: PuzzleMode.daily,
        completedAt: DateTime.utc(2024, 6, 1, 11),
        size: '8x8',
        seed: 'daily-seed',
        moveCount: 11,
        hintsUsed: 1,
        dailyDateKeyUtc: '2024-06-01',
      );

      final records = await store.completionRecords();
      expect(records.map((record) => record.id), contains(randomRecord.id));
      expect(records.map((record) => record.id), contains(dailyRecord.id));
      expect(randomRecord.difficulty, 'expert');
      expect(randomRecord.mode, PuzzleMode.random);
      expect(randomRecord.dailyDateKeyUtc, isNull);
      expect(randomRecord.size, '9x9');
      expect(randomRecord.seed, 'actual-seed');
      expect(randomRecord.elapsedMs, 123456);
      expect(randomRecord.moveCount, 42);
      expect(randomRecord.hintsUsed, 3);
      expect(dailyRecord.dailyDateKeyUtc, '2024-06-01');
      expect(await store.totalSolved(), 2);
      expect(
        await store.completedTodayCount(now: DateTime.utc(2024, 6, 1, 23)),
        2,
      );
    });

    test('keeps old SharedPreferences streak keys untouched', () async {
      await prefs.setInt('puzzle_local_store.v1.global_streak', 7);

      await store.recordCompletion(
        puzzleType: PuzzleType.sudokuClassic,
        difficulty: 'easy',
        completionTime: const Duration(minutes: 1),
        mode: PuzzleMode.daily,
        completedAt: DateTime.utc(2024, 1, 1),
        dailyDateKeyUtc: '2024-01-01',
      );

      expect(prefs.getInt('puzzle_local_store.v1.global_streak'), 7);
      expect(
        prefs.containsKey('puzzle_local_store.v2.daily_streak.current'),
        isTrue,
      );
      expect(
        prefs.containsKey(
          'puzzle_local_store.v2.best_time.sudoku_classic.easy',
        ),
        isTrue,
      );
    });
  });

  group('PuzzleProgressService active runs', () {
    test('saves, restores, updates, and clears an active random run', () async {
      final puzzle = buildSudokuPuzzle();
      final service = PuzzleProgressService(prefs);

      await service.saveRunForPuzzle(
        puzzleType: PuzzleType.sudokuClassic,
        mode: PuzzleMode.random,
        puzzle: puzzle,
        elapsed: const Duration(seconds: 9),
        moveCount: 4,
        hintsUsed: 1,
        notes: const <int, Set<int>>{
          0: <int>{1, 3},
          8: <int>{9},
        },
      );

      SharedPreferences.setMockInitialValues(snapshotPrefs(prefs));
      final reloadedPrefs = await SharedPreferences.getInstance();
      final reloadedService = PuzzleProgressService(reloadedPrefs);
      final run = await reloadedService.loadActiveRun(PuzzleType.sudokuClassic);
      final restoredPuzzle = reloadedService.load(PuzzleType.sudokuClassic);

      expect(run, isNotNull);
      expect(run!.mode, PuzzleMode.random);
      expect(run.difficulty, puzzle.meta.difficulty.level);
      expect(run.size, puzzle.meta.size.id);
      expect(run.seed, puzzle.meta.seedStr);
      expect(run.elapsedMs, 9000);
      expect(run.moveCount, 4);
      expect(run.hintsUsed, 1);
      expect(run.notes[0], containsAll(<int>{1, 3}));
      expect(run.notes[8], contains(9));
      expect(restoredPuzzle?.meta.seedStr, puzzle.meta.seedStr);

      await reloadedService.updateStats(
        PuzzleType.sudokuClassic,
        elapsed: const Duration(seconds: 12),
        moveCount: 6,
        hintsUsed: 2,
      );
      final updated = await reloadedService.loadActiveRun(
        PuzzleType.sudokuClassic,
      );
      expect(updated!.generatedPuzzleJson, run.generatedPuzzleJson);
      expect(updated.elapsedMs, 12000);
      expect(updated.moveCount, 6);
      expect(updated.hintsUsed, 2);

      await reloadedService.clear(PuzzleType.sudokuClassic);
      expect(reloadedService.exists(PuzzleType.sudokuClassic), isFalse);
      expect(
        await reloadedService.loadActiveRun(PuzzleType.sudokuClassic),
        isNull,
      );
    });

    test(
      'wraps old progress.v1 payloads and clears invalid legacy payloads',
      () async {
        final puzzle = buildSudokuPuzzle();
        final service = PuzzleProgressService(prefs);
        await prefs.setString(
          'progress.v1.sudoku_classic',
          jsonEncode(puzzle.toJson()),
        );

        final run = await service.loadActiveRun(PuzzleType.sudokuClassic);
        expect(run, isNotNull);
        expect(run!.mode, PuzzleMode.random);
        expect(run.elapsedMs, 0);
        expect(run.moveCount, 0);
        expect(run.hintsUsed, 0);
        expect(run.seed, puzzle.meta.seedStr);

        await prefs.setString('progress.v1.kakuro_classic', '{"bad": true}');
        expect(await service.loadActiveRun(PuzzleType.kakuroClassic), isNull);
        expect(prefs.containsKey('progress.v1.kakuro_classic'), isFalse);
      },
    );

    test('saves active daily run with UTC date key', () async {
      final core.GeneratedPuzzle<core.SudokuBoard> puzzle = buildSudokuPuzzle();
      final service = PuzzleProgressService(prefs);

      await service.saveRunForPuzzle(
        puzzleType: PuzzleType.sudokuClassic,
        mode: PuzzleMode.daily,
        puzzle: puzzle,
        elapsed: const Duration(seconds: 5),
        moveCount: 2,
        hintsUsed: 0,
        dailyDateKeyUtc: '2024-02-03',
      );

      final run = await service.loadActiveRun(PuzzleType.sudokuClassic);
      expect(run!.mode, PuzzleMode.daily);
      expect(run.dailyDateKeyUtc, '2024-02-03');
    });
  });

  group('FavouritePuzzleService', () {
    test('toggles and persists favourite puzzle types', () async {
      final service = FavouritePuzzleService(prefs);

      expect(service.isFavourite(PuzzleType.sudokuClassic), isFalse);
      expect(await service.toggle(PuzzleType.sudokuClassic), isTrue);
      expect(await service.toggle(PuzzleType.kakuroClassic), isTrue);
      expect(service.favourites(), [
        PuzzleType.sudokuClassic,
        PuzzleType.kakuroClassic,
      ]);
      expect(await service.toggle(PuzzleType.sudokuClassic), isFalse);
      expect(service.favourites(), [PuzzleType.kakuroClassic]);

      SharedPreferences.setMockInitialValues(snapshotPrefs(prefs));
      final reloadedPrefs = await SharedPreferences.getInstance();
      final reloaded = FavouritePuzzleService(reloadedPrefs);
      expect(reloaded.favourites(), [PuzzleType.kakuroClassic]);
    });
  });
}
