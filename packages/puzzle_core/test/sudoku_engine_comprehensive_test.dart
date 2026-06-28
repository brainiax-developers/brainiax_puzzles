import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';
import 'shared/test_utilities.dart';

void main() {
  group('Sudoku Engine Comprehensive Tests', () {
    late SudokuEngine engine;
    late EngineRegistry registry;

    setUp(() {
      registry = EngineRegistry();
      registry.clear();
      engine = SudokuEngine();
      registry.register(engine);
    });

    tearDown(() {
      registry.clear();
    });

    group('Seed Reproducibility', () {
      test('same seed produces identical puzzles', () async {
        const seed = 'test:sudoku_classic:0';
        final seed64 = seed.hashCode;
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

      test('daily seeds work correctly', () async {
        final date = DateTime.utc(2024, 1, 1);
        final seed = TestUtilities.generateDailySeed('sudoku_classic', date);
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        expect(puzzle.meta.seedStr, equals(seed));
        expect(seed, startsWith('sudoku_classic:20240101'));
      });

      test('random play seeds work correctly', () async {
        final seed = TestUtilities.generateRandomPlaySeed('sudoku_classic', 'user123', 'session456');
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        expect(puzzle.meta.seedStr, equals(seed));
        expect(seed, equals('sudoku_classic:user123:session456'));
      });
    });

    group('Sudoku-Specific Tests', () {
      test('generated board has valid Sudoku structure', () async {
        const seed = 'test:sudoku_classic:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        final board = puzzle.state;
        
        // Verify board dimensions
        expect(board.cells.length, equals(81)); // 9x9 = 81 cells
        expect(board.fixed.length, equals(81));
        
        // Verify all cells have valid values (0-9)
        for (final cell in board.cells) {
          expect(cell, inInclusiveRange(0, 9));
        }
        
        // Verify fixed cells are properly marked
        for (int i = 0; i < 81; i++) {
          if (board.fixed[i]) {
            expect(board.cells[i], inInclusiveRange(1, 9)); // Fixed cells should have values
          }
        }
      });

      test('board follows Sudoku rules', () async {
        const seed = 'test:sudoku_classic:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        final board = puzzle.state;
        
        // Check rows for duplicates
        for (int row = 0; row < 9; row++) {
          final rowValues = <int>{};
          for (int col = 0; col < 9; col++) {
            final value = board.cells[row * 9 + col];
            if (value != 0) {
              expect(rowValues, isNot(contains(value)), 
                reason: 'Duplicate value $value in row $row');
              rowValues.add(value);
            }
          }
        }
        
        // Check columns for duplicates
        for (int col = 0; col < 9; col++) {
          final colValues = <int>{};
          for (int row = 0; row < 9; row++) {
            final value = board.cells[row * 9 + col];
            if (value != 0) {
              expect(colValues, isNot(contains(value)), 
                reason: 'Duplicate value $value in column $col');
              colValues.add(value);
            }
          }
        }
        
        // Check 3x3 boxes for duplicates
        for (int boxRow = 0; boxRow < 3; boxRow++) {
          for (int boxCol = 0; boxCol < 3; boxCol++) {
            final boxValues = <int>{};
            for (int row = 0; row < 3; row++) {
              for (int col = 0; col < 3; col++) {
                final actualRow = boxRow * 3 + row;
                final actualCol = boxCol * 3 + col;
                final value = board.cells[actualRow * 9 + actualCol];
                if (value != 0) {
                  expect(boxValues, isNot(contains(value)), 
                    reason: 'Duplicate value $value in box ($boxRow, $boxCol)');
                  boxValues.add(value);
                }
              }
            }
          }
        }
      });
    });

    group('Move Validation', () {
      test('valid moves are accepted', () async {
        const seed = 'test:sudoku_classic:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        final board = puzzle.state;
        
        // Find an empty cell
        int emptyIndex = -1;
        for (int i = 0; i < 81; i++) {
          if (!board.fixed[i] && board.cells[i] == 0) {
            emptyIndex = i;
            break;
          }
        }
        
        if (emptyIndex != -1) {
          final row = emptyIndex ~/ 9;
          final col = emptyIndex % 9;
          final move = SudokuMove(row: row, col: col, digit: 1);
          
          final result = engine.validateMove(
            currentState: board,
            move: move,
          );

          expect(result.isValid, isTrue);
          expect(result.newState, isNotNull);
        }
      });

      test('invalid moves are rejected', () async {
        const seed = 'test:sudoku_classic:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        final board = puzzle.state;
        
        // Try to place a digit in a fixed cell
        int fixedIndex = -1;
        for (int i = 0; i < 81; i++) {
          if (board.fixed[i]) {
            fixedIndex = i;
            break;
          }
        }
        
        if (fixedIndex != -1) {
          final row = fixedIndex ~/ 9;
          final col = fixedIndex % 9;
          final move = SudokuMove(row: row, col: col, digit: 5);
          
          final result = engine.validateMove(
            currentState: board,
            move: move,
          );

          expect(result.isValid, isFalse);
          expect(result.errorMessage, isNotNull);
        }
      });

      test('out of bounds moves are rejected', () async {
        const seed = 'test:sudoku_classic:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        final board = puzzle.state;
        
        // Try invalid row
        final invalidRowMove = SudokuMove(row: 9, col: 0, digit: 1);
        final result1 = engine.validateMove(
          currentState: board,
          move: invalidRowMove,
        );
        expect(result1.isValid, isFalse);
        
        // Try invalid column
        final invalidColMove = SudokuMove(row: 0, col: 9, digit: 1);
        final result2 = engine.validateMove(
          currentState: board,
          move: invalidColMove,
        );
        expect(result2.isValid, isFalse);
        
        // Try invalid digit
        final invalidDigitMove = SudokuMove(row: 0, col: 0, digit: 10);
        final result3 = engine.validateMove(
          currentState: board,
          move: invalidDigitMove,
        );
        expect(result3.isValid, isFalse);
      });
    });

    group('Solvability Tests', () {
      test('generated puzzle is solvable', () async {
        const seed = 'test:sudoku_classic:0';
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

      test('puzzle has unique solution', () async {
        const seed = 'test:sudoku_classic:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        final hasUnique = await TestUtilities.hasUniqueSolution(engine, puzzle.state);
        expect(hasUnique, isTrue);
      });
    });

    group('Performance Tests', () {
      test('generation completes in reasonable time', () async {
        const seed = 'test:sudoku_classic:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final generationTime = await TestUtilities.measureTime(() async {
          engine.generate(
            seedStr: seed,
            seed64: seed.hashCode,
            size: size,
            difficulty: difficulty,
          );
        });

        // Should complete in under 5 seconds
        expect(generationTime.inMilliseconds, lessThan(5000));
      });

      test('validation completes in under 50ms', () async {
        const seed = 'test:sudoku_classic:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        final validationTime = await TestUtilities.measureTime(() async {
          TestUtilities.isValidPuzzleState(puzzle.state);
        });

        expect(validationTime.inMilliseconds, lessThan(50));
      });
    });

    group('Property Tests', () {
      test('property test over random seeds', () async {
        const testCount = 20; // Reduced for performance
        final testData = TestUtilities.generateTestData(
          count: testCount,
          engineIds: ['sudoku_classic'],
          difficulties: ['easy', 'medium', 'hard'],
          sizes: ['9x9'],
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

          final board = puzzle.state;
          
          // Property: All generated puzzles should be valid Sudoku boards
          expect(board.cells.length, equals(81));
          expect(board.fixed.length, equals(81));
          
          // Property: All puzzles should have metadata
          expect(puzzle.meta.engineVersion, isNotEmpty);
          expect(puzzle.meta.seedStr, equals(seed));
        }
      });
    });

    group('Serialization', () {
      test('SudokuBoard can be serialized and deserialized', () async {
        const seed = 'test:sudoku_classic:0';
        const difficulty = DifficultyScore(value: 0.6, level: 'medium');
        const size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

        final puzzle = engine.generate(
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: difficulty,
        );

        final board = puzzle.state;
        
        // Serialize
        final json = board.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['cells'], isA<List>());
        expect(json['fixed'], isA<List>());
        expect(json['cells'].length, equals(81));
        expect(json['fixed'].length, equals(81));

        // Deserialize
        final deserializedBoard = SudokuBoard.fromJson(json);
        expect(deserializedBoard.cells, equals(board.cells));
        expect(deserializedBoard.fixed, equals(board.fixed));
      });

      test('SudokuMove can be serialized and deserialized', () async {
        final move = SudokuMove(row: 5, col: 3, digit: 7);
        
        // Serialize
        final json = move.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['row'], equals(5));
        expect(json['col'], equals(3));
        expect(json['digit'], equals(7));

        // Deserialize
        final deserializedMove = SudokuMove.fromJson(json);
        expect(deserializedMove.row, equals(move.row));
        expect(deserializedMove.col, equals(move.col));
        expect(deserializedMove.digit, equals(move.digit));
      });
    });
  });
}
