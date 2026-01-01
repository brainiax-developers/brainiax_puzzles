import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

void main() {
  group('Killer Queens Grid Sizes by Difficulty', () {
    late KillerQueensEngine engine;

    setUp(() {
      engine = KillerQueensEngine();
    });

    test('Easy difficulty generates 6x6 grid', () {
      const String seedStr = 'kq_easy_test';
      final int seed64 = Seed.fromString(seedStr);
      final puzzle = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: SizeOpt(id: '6x6', description: '6x6', width: 6, height: 6),
        difficulty: DifficultyScore(value: 0.3, level: 'easy'),
      );

      expect(puzzle.state.size, equals(6));
      expect(puzzle.state.cells.length, equals(36));
    });

    test('Medium difficulty generates 8x8 grid', () {
      const String seedStr = 'kq_medium_test';
      final int seed64 = Seed.fromString(seedStr);
      final puzzle = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: SizeOpt(id: '8x8', description: '8x8', width: 8, height: 8),
        difficulty: DifficultyScore(value: 0.6, level: 'medium'),
      );

      expect(puzzle.state.size, equals(8));
      expect(puzzle.state.cells.length, equals(64));
    });

    test('Hard difficulty generates 10x10 grid', () {
      const String seedStr = 'kq_hard_test';
      final int seed64 = Seed.fromString(seedStr);
      final puzzle = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: SizeOpt(id: '10x10', description: '10x10', width: 10, height: 10),
        difficulty: DifficultyScore(value: 0.9, level: 'hard'),
      );

      expect(puzzle.state.size, equals(10));
      expect(puzzle.state.cells.length, equals(100));
    });

    test('Expert difficulty generates 12x12 grid', () {
      const String seedStr = 'kq_expert_test';
      final int seed64 = Seed.fromString(seedStr);
      final puzzle = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: SizeOpt(id: '12x12', description: '12x12', width: 12, height: 12),
        difficulty: DifficultyScore(value: 1.0, level: 'expert'),
      );

      expect(puzzle.state.size, equals(12));
      expect(puzzle.state.cells.length, equals(144));
    });

    test('All puzzles have no givens (all cells start empty)', () {
      final configs = [
        {'level': 'easy', 'size': 6},
        {'level': 'medium', 'size': 8},
        {'level': 'hard', 'size': 10},
        {'level': 'expert', 'size': 12},
      ];

      for (final config in configs) {
        final level = config['level'] as String;
        final size = config['size'] as int;
        final seedStr = 'kq_${level}_nogivens';
        final seed64 = Seed.fromString(seedStr);

        final puzzle = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: SizeOpt(
              id: '${size}x$size',
              description: '${size}x$size',
              width: size,
              height: size),
          difficulty: DifficultyScore(value: 0.5, level: level),
        );

        final givensCount = puzzle.state.fixed.where((f) => f).length;
        expect(givensCount, equals(0),
            reason: '$level should have no givens (all cells empty)');
      }
    });

    test('Easy puzzles have smaller cage sizes', () {
      const String seedStr = 'kq_easy_cages';
      final int seed64 = Seed.fromString(seedStr);
      final easyPuzzle = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: SizeOpt(id: '6x6', description: '6x6', width: 6, height: 6),
        difficulty: DifficultyScore(value: 0.3, level: 'easy'),
      );

      final avgCageSize = easyPuzzle.state.cells.length / easyPuzzle.state.cages.length;
      
      // Easy puzzles should have smaller average cage sizes
      expect(avgCageSize, lessThan(7.0));
    });

    test('Expert puzzles have larger cage sizes', () {
      const String seedStr = 'kq_expert_cages';
      final int seed64 = Seed.fromString(seedStr);
      final expertPuzzle = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: SizeOpt(id: '12x12', description: '12x12', width: 12, height: 12),
        difficulty: DifficultyScore(value: 1.0, level: 'expert'),
      );

      final avgCageSize = expertPuzzle.state.cells.length / expertPuzzle.state.cages.length;
      
      // Expert puzzles should have larger average cage sizes
      expect(avgCageSize, greaterThan(10.0));
    });

    test('All difficulty levels have exactly size number of cages', () {
      final configs = [
        {'level': 'easy', 'size': 6},
        {'level': 'medium', 'size': 8},
        {'level': 'hard', 'size': 10},
        {'level': 'expert', 'size': 12},
      ];

      for (final config in configs) {
        final level = config['level'] as String;
        final size = config['size'] as int;
        final seedStr = 'kq_${level}_cagecount';
        final seed64 = Seed.fromString(seedStr);
        
        final puzzle = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: SizeOpt(id: '${size}x$size', description: '${size}x$size', width: size, height: size),
          difficulty: DifficultyScore(value: 0.5, level: level),
        );

        expect(puzzle.state.cages.length, equals(size),
            reason: '$level should have exactly $size cages');
      }
    });
  });
}
