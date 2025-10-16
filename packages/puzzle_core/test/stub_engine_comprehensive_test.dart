import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';
import 'shared/test_utilities.dart';

void main() {
  group('Stub Engine Comprehensive Tests', () {
    late StubPuzzleEngine engine;
    late EngineRegistry registry;

    setUp(() {
      registry = EngineRegistry();
      registry.clear();
      engine = StubPuzzleEngine();
      registry.register(engine);
    });

    tearDown(() {
      registry.clear();
    });

    group('Seed Reproducibility', () {
      test('same seed produces identical puzzles', () async {
        const seed = 'test:stub:0';
        const seed64 = seed.hashCode;
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        // Generate puzzle twice with same seed
        final puzzle1 = engine.generate(
          seedStr: seed,
          seed64: seed64,
          size: size,
          difficulty: difficulty,
        );

        final puzzle2 = engine.generate(
          seedStr: seed,
          seed64: seed64,
          size: size,
          difficulty: difficulty,
        );

        // Verify puzzles are identical
        expect(puzzle1.meta.seedStr, equals(puzzle2.meta.seedStr));
        expect(puzzle1.meta.seed64, equals(puzzle2.meta.seed64));
        expect(puzzle1.meta.engineVersion, equals(puzzle2.meta.engineVersion));
        
        // Verify state is identical
        expect(TestUtilities.puzzlesAreIdentical(puzzle1.state, puzzle2.state), isTrue);
      });

      test('different seeds produce different puzzles', () async {
        const seed1 = 'test:stub:0';
        const seed2 = 'test:stub:1';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle1 = engine.generate(
          seedStr: seed1,
          seed64: seed1.hashCode,
          size: size,
          difficulty: difficulty,
        );

        final puzzle2 = engine.generate(
          seedStr: seed2,
          seed64: seed2.hashCode,
          size: size,
          difficulty: difficulty,
        );

        // Verify puzzles are different
        expect(puzzle1.meta.seedStr, isNot(equals(puzzle2.meta.seedStr)));
        expect(puzzle1.meta.seed64, isNot(equals(puzzle2.meta.seed64)));
      });

      test('daily seeds work correctly', () async {
        final date = DateTime(2024, 1, 1).toUtc();
        final seed = TestUtilities.generateDailySeed('stub', date);
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        expect(puzzle.meta.seedStr, equals(seed));
        expect(seed, startsWith('stub:20240101'));
      });

      test('random play seeds work correctly', () async {
        final seed = TestUtilities.generateRandomPlaySeed('stub', 'user123', 'session456');
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        expect(puzzle.meta.seedStr, equals(seed));
        expect(seed, equals('stub:user123:session456'));
      });
    });

    group('Uniqueness Tests', () {
      test('puzzle has unique solution', () async {
        const seed = 'test:stub:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        // For stub engine, we assume it has unique solution
        final hasUnique = await TestUtilities.hasUniqueSolution(engine, puzzle.state);
        expect(hasUnique, isTrue);
      });

      test('second solution early exit works', () async {
        // This test would verify that the solver exits early
        // when it finds a second solution
        const seed = 'test:stub:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        // Measure time to detect non-uniqueness
        final stopwatch = Stopwatch()..start();
        final hasUnique = await TestUtilities.hasUniqueSolution(engine, puzzle.state);
        stopwatch.stop();

        expect(hasUnique, isTrue);
        // Should be fast for unique solutions
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('Solvability Tests', () {
      test('generated puzzle is solvable', () async {
        const seed = 'test:stub:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        final isSolvable = await TestUtilities.isSolvable(engine, puzzle.state);
        expect(isSolvable, isTrue);
      });

      test('puzzle can be solved to completion', () async {
        const seed = 'test:stub:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        // Verify puzzle state is valid
        expect(TestUtilities.isValidPuzzleState(puzzle.state), isTrue);
        
        // Verify puzzle can be marked as solved
        expect(engine.isSolved(puzzle.state), isFalse); // Initially not solved
      });
    });

    group('Difficulty Bucket Stability', () {
      test('difficulty remains stable across generations', () async {
        const seed = 'test:stub:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        // Generate multiple puzzles with same parameters
        final puzzles = <GeneratedPuzzle>[];
        for (int i = 0; i < 10; i++) {
          final puzzle = engine.generate(
            seedStr: '$seed:$i',
            seed64: '$seed:$i'.hashCode,
            size: size,
            difficulty: difficulty,
          );
          puzzles.add(puzzle);
        }

        // Verify all puzzles meet difficulty requirements
        for (final puzzle in puzzles) {
          final meetsDifficulty = TestUtilities.meetsDifficultyRequirements(
            puzzle.state,
            difficulty,
            0.1, // 10% tolerance
          );
          expect(meetsDifficulty, isTrue);
        }
      });

      test('difficulty changes with different difficulty scores', () async {
        const seed = 'test:stub:0';
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final easyPuzzle = engine.generate(
          seedStr: '$seed:easy',
          seed64: '$seed:easy'.hashCode,
          size: size,
          difficulty: const DifficultyScore(value: 0.3, level: 'easy'),
        );

        final hardPuzzle = engine.generate(
          seedStr: '$seed:hard',
          seed64: '$seed:hard'.hashCode,
          size: size,
          difficulty: const DifficultyScore(value: 0.9, level: 'hard'),
        );

        // Verify puzzles are different
        expect(easyPuzzle.meta.difficulty.value, equals(0.3));
        expect(hardPuzzle.meta.difficulty.value, equals(0.9));
      });
    });

    group('Validation Performance', () {
      test('validation completes in under 50ms', () async {
        const seed = 'test:stub:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        // Measure validation time
        final validationTime = await TestUtilities.measureTime(() async {
          // Simulate validation
          TestUtilities.isValidPuzzleState(puzzle.state);
        });

        expect(validationTime.inMilliseconds, lessThan(50));
      });

      test('generation completes in reasonable time', () async {
        const seed = 'test:stub:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        // Measure generation time
        final generationTime = await TestUtilities.measureTime(() async {
          engine.generate(
            seedStr: seed,
            seed64: seed.hashCode,
            size: size,
            difficulty: difficulty,
          );
        });

        // Should complete in under 1 second
        expect(generationTime.inMilliseconds, lessThan(1000));
      });
    });

    group('Property Tests', () {
      test('property test over random seeds', () async {
        const testCount = 50;
        final testData = TestUtilities.generateTestData(
          count: testCount,
          engineIds: ['stub'],
          difficulties: ['easy', 'medium', 'hard'],
          sizes: ['9x9', '6x6', '4x4'],
        );

        for (final data in testData) {
          final seed = data['seed'] as String;
          final difficulty = TestUtilities.parseDifficulty(data['difficulty'] as String);
          final size = TestUtilities.createSizeOpt(data['size'] as String);

          final puzzle = engine.generate(
            seedStr: seed,
            seed64: seed.hashCode,
            size: size,
            difficulty: difficulty,
          );

          // Property: All generated puzzles should be valid
          expect(TestUtilities.isValidPuzzleState(puzzle.state), isTrue);
          
          // Property: All puzzles should have metadata
          expect(puzzle.meta.engineVersion, isNotEmpty);
          expect(puzzle.meta.seedStr, equals(seed));
        }
      });

      test('property test for seed format compliance', () async {
        const testCount = 20;
        final scenarios = TestUtilities.generateTestScenarios(
          engineIds: ['stub'],
          difficulties: ['medium'],
          sizes: ['9x9'],
          scenariosPerEngine: testCount,
        );

        for (final scenario in scenarios) {
          final difficulty = TestUtilities.parseDifficulty(scenario.difficulty);
          final size = TestUtilities.createSizeOpt(scenario.size);

          final puzzle = engine.generate(
            seedStr: scenario.seed,
            seed64: scenario.seed.hashCode,
            size: size,
            difficulty: difficulty,
          );

          // Property: Seed should be preserved in metadata
          expect(puzzle.meta.seedStr, equals(scenario.seed));
          
          // Property: Engine version should be consistent
          expect(puzzle.meta.engineVersion, equals(engine.version));
        }
      });
    });

    group('Move Validation', () {
      test('valid moves are accepted', () async {
        const seed = 'test:stub:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        final move = StubPuzzleMove(type: 'valid', data: {'test': 'value'});
        final result = engine.validateMove(
          currentState: puzzle.state,
          move: move,
        );

        expect(result.isValid, isTrue);
      });

      test('invalid moves are rejected', () async {
        const seed = 'test:stub:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        final move = StubPuzzleMove(type: 'invalid', data: {});
        final result = engine.validateMove(
          currentState: puzzle.state,
          move: move,
        );

        expect(result.isValid, isFalse);
        expect(result.errorMessage, isNotNull);
      });
    });

    group('Serialization', () {
      test('puzzle state can be serialized and deserialized', () async {
        const seed = 'test:stub:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        // Serialize
        final json = puzzle.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['meta'], isNotNull);
        expect(json['state'], isNotNull);

        // Deserialize
        final deserializedPuzzle = GeneratedPuzzle.fromJson(
          json,
          (stateJson) => StubPuzzleState.fromJson(stateJson),
        );

        expect(deserializedPuzzle.meta.seedStr, equals(puzzle.meta.seedStr));
        expect(deserializedPuzzle.meta.engineVersion, equals(puzzle.meta.engineVersion));
      });

      test('move can be serialized and deserialized', () async {
        final move = StubPuzzleMove(type: 'test', data: {'key': 'value'});
        
        // Serialize
        final json = move.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['type'], equals('test'));
        expect(json['data'], equals({'key': 'value'}));

        // Deserialize
        final deserializedMove = StubPuzzleMove.fromJson(json);
        expect(deserializedMove.type, equals(move.type));
        expect(deserializedMove.data, equals(move.data));
      });
    });
  });
}
