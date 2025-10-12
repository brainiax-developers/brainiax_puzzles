import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main() {
  group('Determinism Tests', () {
    test('same parameters produce identical output for stub engine', () {
      final engine = StubPuzzleEngine();
      
      final size = SizeOpt(
        id: '9x9',
        description: 'Standard 9x9',
        width: 9,
        height: 9,
      );
      
      final difficulty = DifficultyScore(
        value: 0.5,
        level: 'Medium',
      );
      
      const seedStr = 'test_seed_123';
      const seed64 = 12345;
      
      // Generate puzzle twice with same parameters
      final puzzle1 = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: size,
        difficulty: difficulty,
      );
      
      final puzzle2 = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: size,
        difficulty: difficulty,
      );
      
      // Verify metadata is identical
      expect(puzzle1.meta.engineVersion, equals(puzzle2.meta.engineVersion));
      expect(puzzle1.meta.rngId, equals(puzzle2.meta.rngId));
      expect(puzzle1.meta.size, equals(puzzle2.meta.size));
      expect(puzzle1.meta.difficulty, equals(puzzle2.meta.difficulty));
      expect(puzzle1.meta.seedStr, equals(puzzle2.meta.seedStr));
      expect(puzzle1.meta.seed64, equals(puzzle2.meta.seed64));
      
      // Verify state is identical
      expect(puzzle1.state.id, equals(puzzle2.state.id));
      expect(puzzle1.state.data, equals(puzzle2.state.data));
      
      // Verify the puzzles are equal
      expect(puzzle1, equals(puzzle2));
    });
    
    test('same parameters produce identical output for sudoku engine', () {
      final engine = StubSudokuEngine();
      
      final size = SizeOpt(
        id: '9x9',
        description: 'Standard 9x9',
        width: 9,
        height: 9,
      );
      
      final difficulty = DifficultyScore(
        value: 0.7,
        level: 'Hard',
      );
      
      const seedStr = 'sudoku_seed_456';
      const seed64 = 67890;
      
      // Generate puzzle twice with same parameters
      final puzzle1 = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: size,
        difficulty: difficulty,
      );
      
      final puzzle2 = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: size,
        difficulty: difficulty,
      );
      
      // Verify metadata is identical
      expect(puzzle1.meta.engineVersion, equals(puzzle2.meta.engineVersion));
      expect(puzzle1.meta.rngId, equals(puzzle2.meta.rngId));
      expect(puzzle1.meta.size, equals(puzzle2.meta.size));
      expect(puzzle1.meta.difficulty, equals(puzzle2.meta.difficulty));
      expect(puzzle1.meta.seedStr, equals(puzzle2.meta.seedStr));
      expect(puzzle1.meta.seed64, equals(puzzle2.meta.seed64));
      
      // Verify state is identical
      expect(puzzle1.state.id, equals(puzzle2.state.id));
      expect(puzzle1.state.data, equals(puzzle2.state.data));
      
      // Verify the puzzles are equal
      expect(puzzle1, equals(puzzle2));
    });
    
    test('different seeds produce different output', () {
      final engine = StubPuzzleEngine();
      
      final size = SizeOpt(
        id: '9x9',
        description: 'Standard 9x9',
        width: 9,
        height: 9,
      );
      
      final difficulty = DifficultyScore(
        value: 0.5,
        level: 'Medium',
      );
      
      // Generate puzzles with different seeds
      final puzzle1 = engine.generate(
        seedStr: 'seed_1',
        seed64: 11111,
        size: size,
        difficulty: difficulty,
      );
      
      final puzzle2 = engine.generate(
        seedStr: 'seed_2',
        seed64: 22222,
        size: size,
        difficulty: difficulty,
      );
      
      // Verify they are different
      expect(puzzle1, isNot(equals(puzzle2)));
      expect(puzzle1.state.id, isNot(equals(puzzle2.state.id)));
      expect(puzzle1.meta.seedStr, isNot(equals(puzzle2.meta.seedStr)));
      expect(puzzle1.meta.seed64, isNot(equals(puzzle2.meta.seed64)));
    });
    
    test('different difficulty produces different output', () {
      final engine = StubPuzzleEngine();
      
      final size = SizeOpt(
        id: '9x9',
        description: 'Standard 9x9',
        width: 9,
        height: 9,
      );
      
      const seedStr = 'same_seed';
      const seed64 = 12345;
      
      // Generate puzzles with different difficulties
      final puzzle1 = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: size,
        difficulty: DifficultyScore(value: 0.3, level: 'Easy'),
      );
      
      final puzzle2 = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: size,
        difficulty: DifficultyScore(value: 0.8, level: 'Hard'),
      );
      
      // Verify they are different
      expect(puzzle1, isNot(equals(puzzle2)));
      expect(puzzle1.state.id, isNot(equals(puzzle2.state.id)));
      expect(puzzle1.meta.difficulty, isNot(equals(puzzle2.meta.difficulty)));
    });
    
    test('different size produces different output', () {
      final engine = StubPuzzleEngine();
      
      final difficulty = DifficultyScore(
        value: 0.5,
        level: 'Medium',
      );
      
      const seedStr = 'same_seed';
      const seed64 = 12345;
      
      // Generate puzzles with different sizes
      final puzzle1 = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: SizeOpt(id: '6x6', description: 'Small', width: 6, height: 6),
        difficulty: difficulty,
      );
      
      final puzzle2 = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: SizeOpt(id: '9x9', description: 'Standard', width: 9, height: 9),
        difficulty: difficulty,
      );
      
      // Verify they are different
      expect(puzzle1, isNot(equals(puzzle2)));
      expect(puzzle1.state.id, isNot(equals(puzzle2.state.id)));
      expect(puzzle1.meta.size, isNot(equals(puzzle2.meta.size)));
    });
    
    test('RNG produces deterministic sequence', () {
      final rng1 = SeededRng(12345);
      final rng2 = SeededRng(12345);
      
      // Generate sequences from both RNGs
      final sequence1 = <int>[];
      final sequence2 = <int>[];
      
      for (int i = 0; i < 10; i++) {
        sequence1.add(rng1.nextInt());
        sequence2.add(rng2.nextInt());
      }
      
      // Verify sequences are identical
      expect(sequence1, equals(sequence2));
    });
    
    test('RNG produces different sequences for different seeds', () {
      final rng1 = SeededRng(11111);
      final rng2 = SeededRng(22222);
      
      // Generate sequences from both RNGs
      final sequence1 = <int>[];
      final sequence2 = <int>[];
      
      for (int i = 0; i < 10; i++) {
        sequence1.add(rng1.nextInt());
        sequence2.add(rng2.nextInt());
      }
      
      // Verify sequences are different
      expect(sequence1, isNot(equals(sequence2)));
    });
  });
}
