import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../lib/shared/models/models.dart';
import '../../../lib/shared/services/puzzle_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late PuzzleLocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = SharedPreferencesPuzzleLocalStore(prefs);
  });

  group('SharedPreferencesPuzzleLocalStore', () {
    test('persists and returns best times per puzzle and difficulty', () async {
      final type = PuzzleType.sudokuClassic;
      final day = DateTime(2024, 1, 1, 12);

      await store.recordCompletion(
        puzzleType: type,
        difficulty: 'easy',
        completionTime: const Duration(seconds: 90),
        completedAt: day,
      );

      await store.recordCompletion(
        puzzleType: type,
        difficulty: 'easy',
        completionTime: const Duration(seconds: 120),
        completedAt: day,
      );

      await store.recordCompletion(
        puzzleType: type,
        difficulty: 'medium',
        completionTime: const Duration(seconds: 80),
        completedAt: day,
      );

      expect(
        await store.bestTime(type, 'easy'),
        const Duration(seconds: 90),
      );
      expect(
        await store.bestTime(type, 'medium'),
        const Duration(seconds: 80),
      );
    });

    test('stores daily completion per date', () async {
      final type = PuzzleType.kakuroClassic;
      final completion = DateTime(2024, 2, 14, 20, 30);
      final nextDay = completion.add(const Duration(days: 1));

      await store.recordCompletion(
        puzzleType: type,
        difficulty: 'hard',
        completionTime: const Duration(minutes: 5),
        completedAt: completion,
      );

      expect(await store.isCompletedOn(type, completion), isTrue);
      expect(await store.isCompletedOn(type, nextDay), isFalse);
    });

    test('increments streak for consecutive days and resets on breaks', () async {
      final type = PuzzleType.nonogramMono;
      final day1 = DateTime(2024, 3, 1, 9);
      final day2 = day1.add(const Duration(days: 1));
      final day4 = day1.add(const Duration(days: 3));

      await store.recordCompletion(
        puzzleType: type,
        difficulty: 'normal',
        completionTime: const Duration(minutes: 7),
        completedAt: day1,
      );
      expect(await store.puzzleStreak(type), 1);

      await store.recordCompletion(
        puzzleType: type,
        difficulty: 'normal',
        completionTime: const Duration(minutes: 6),
        completedAt: day2,
      );
      expect(await store.puzzleStreak(type), 2);

      await store.recordCompletion(
        puzzleType: type,
        difficulty: 'normal',
        completionTime: const Duration(minutes: 5),
        completedAt: day4,
      );
      expect(await store.puzzleStreak(type), 1);
    });

    test('global streak counts distinct days only once', () async {
      final sudokuDay1 = DateTime(2024, 4, 5, 11);
      final sudokuDay2 = sudokuDay1.add(const Duration(days: 1));
      final sudokuDay4 = sudokuDay1.add(const Duration(days: 3));

      await store.recordCompletion(
        puzzleType: PuzzleType.sudokuClassic,
        difficulty: 'easy',
        completionTime: const Duration(minutes: 4),
        completedAt: sudokuDay1,
      );
      expect(await store.globalStreak(), 1);

      await store.recordCompletion(
        puzzleType: PuzzleType.kakuroClassic,
        difficulty: 'easy',
        completionTime: const Duration(minutes: 6),
        completedAt: sudokuDay1,
      );
      expect(await store.globalStreak(), 1, reason: 'same day should not double count');

      await store.recordCompletion(
        puzzleType: PuzzleType.sudokuClassic,
        difficulty: 'easy',
        completionTime: const Duration(minutes: 3),
        completedAt: sudokuDay2,
      );
      expect(await store.globalStreak(), 2);

      await store.recordCompletion(
        puzzleType: PuzzleType.sudokuClassic,
        difficulty: 'easy',
        completionTime: const Duration(minutes: 2),
        completedAt: sudokuDay4,
      );
      expect(await store.globalStreak(), 1);
    });

    test('uses migration safe keys for stored values', () async {
      final type = PuzzleType.slitherlinkLoop;
      final completion = DateTime(2024, 5, 20);

      await store.recordCompletion(
        puzzleType: type,
        difficulty: 'expert',
        completionTime: const Duration(minutes: 12),
        completedAt: completion,
      );

      final keys = prefs.getKeys();
      expect(
        keys.contains('puzzle_local_store.v1.best_time.${type.key}.expert'),
        isTrue,
      );
      expect(
        keys.contains(
          'puzzle_local_store.v1.daily_completion.${type.key}.2024-05-20',
        ),
        isTrue,
      );
      expect(
        keys.contains('puzzle_local_store.v1.streak.${type.key}'),
        isTrue,
      );
      expect(
        keys.contains('puzzle_local_store.v1.last_completion.${type.key}'),
        isTrue,
      );
      expect(keys.contains('puzzle_local_store.v1.global_streak'), isTrue);
      expect(
        keys.contains('puzzle_local_store.v1.global_last_completion'),
        isTrue,
      );
    });
  });
}
