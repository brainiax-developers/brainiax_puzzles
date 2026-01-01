import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/daily/daily_providers.dart';
import 'package:app/features/daily/daily_seed_generator.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main() {
  group('DailySeedGenerator', () {
    final generator = DailySeedGenerator();

    test('produces the same seed for the same puzzle type and day', () {
      final date = DateTime(2024, 5, 20, 13, 45);
      final seedA = generator.generate('sudoku_classic', date: date);
      final seedB = generator.generate('sudoku_classic', date: date.add(const Duration(hours: 5)));

      expect(seedA.seed64, equals(seedB.seed64));
      expect(seedA.seedStr, equals(seedB.seedStr));
      expect(seedA.formattedDate, equals('2024-05-20'));
    });

    test('produces different seeds for different days', () {
      final dateA = DateTime(2024, 5, 20, 23, 59);
      final dateB = DateTime(2024, 5, 21, 0, 0);

      final seedA = generator.generate('sudoku_classic', date: dateA);
      final seedB = generator.generate('sudoku_classic', date: dateB);

      expect(seedA.seed64, isNot(equals(seedB.seed64)));
      expect(seedA.seedStr, isNot(equals(seedB.seedStr)));
    });
  });

  group('dailyPuzzleProvider', () {
    final registry = EngineRegistry();

    setUp(() {
      registry.clear();
      registry.register(StubPuzzleEngine(engineId: 'sudoku_classic', engineName: 'Stub Sudoku'));
    });

    tearDown(() {
      registry.clear();
    });

    test('returns the same puzzle for the same day and type', () async {
      final fixedDate = DateTime(2024, 5, 22, 9, 30);
      final container = ProviderContainer(overrides: [
        dailySeedGeneratorProvider.overrideWithValue(
          DailySeedGenerator(clock: () => fixedDate),
        ),
      ]);
      addTearDown(container.dispose);

      final puzzleA = await container.read(dailyPuzzleProvider('sudoku_classic').future);
      container.invalidate(dailyPuzzleProvider('sudoku_classic'));
      final puzzleB = await container.read(dailyPuzzleProvider('sudoku_classic').future);

      expect(puzzleA.meta.seed64, equals(puzzleB.meta.seed64));
      expect(puzzleA.meta.seedStr, equals(puzzleB.meta.seedStr));
      expect(puzzleA, equals(puzzleB));
    });

    test('returns different puzzles for different days', () async {
      final containerA = ProviderContainer(overrides: [
        dailySeedGeneratorProvider.overrideWithValue(
          DailySeedGenerator(clock: () => DateTime(2024, 5, 23, 8, 0)),
        ),
      ]);
      final puzzleA = await containerA.read(dailyPuzzleProvider('sudoku_classic').future);
      containerA.dispose();

      final containerB = ProviderContainer(overrides: [
        dailySeedGeneratorProvider.overrideWithValue(
          DailySeedGenerator(clock: () => DateTime(2024, 5, 24, 8, 0)),
        ),
      ]);
      final puzzleB = await containerB.read(dailyPuzzleProvider('sudoku_classic').future);
      containerB.dispose();

      expect(puzzleA.meta.seed64, isNot(equals(puzzleB.meta.seed64)));
      expect(puzzleA.meta.seedStr, isNot(equals(puzzleB.meta.seedStr)));
      expect(puzzleA, isNot(equals(puzzleB)));
    });
  });
}
