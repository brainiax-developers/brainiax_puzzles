import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main() {
  group('Serialization Tests', () {
    group('Stub Engine Serialization', () {
      test('StubPuzzleState serialization', () {
        final state = StubPuzzleState(
          id: 'test-id',
          data: {
            'key1': 'value1',
            'key2': 42,
            'key3': [1, 2, 3],
            'key4': {'nested': 'value'},
          },
        );

        // Serialize
        final json = state.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['id'], equals('test-id'));
        expect(json['data'], isA<Map<String, dynamic>>());
        expect(json['data']['key1'], equals('value1'));
        expect(json['data']['key2'], equals(42));
        expect(json['data']['key3'], equals([1, 2, 3]));
        expect(json['data']['key4'], equals({'nested': 'value'}));

        // Deserialize
        final deserialized = StubPuzzleState.fromJson(json);
        expect(deserialized.id, equals(state.id));
        expect(deserialized.data, equals(state.data));
      });

      test('StubPuzzleMove serialization', () {
        final move = StubPuzzleMove(
          type: 'test-move',
          data: {
            'param1': 'value1',
            'param2': 123,
            'param3': true,
          },
        );

        // Serialize
        final json = move.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['type'], equals('test-move'));
        expect(json['data'], isA<Map<String, dynamic>>());
        expect(json['data']['param1'], equals('value1'));
        expect(json['data']['param2'], equals(123));
        expect(json['data']['param3'], equals(true));

        // Deserialize
        final deserialized = StubPuzzleMove.fromJson(json);
        expect(deserialized.type, equals(move.type));
        expect(deserialized.data, equals(move.data));
      });

      test('GeneratedPuzzle serialization', () {
        final state = StubPuzzleState(
          id: 'test-id',
          data: {'test': 'data'},
        );

        final meta = PuzzleMetadata(
          engineVersion: '1.0.0',
          rngId: 'test-rng',
          size: const SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9),
          difficulty: const DifficultyScore(value: 0.6, level: 'medium'),
          seedStr: 'test:stub:0',
          seed64: 12345,
        );

        final telemetry = GenerationTelemetry(
          difficulty: const DifficultyTelemetry(
            rawScore: 0.6,
            bucket: 'medium',
            metrics: {'metric1': 1.0, 'metric2': 2.0},
          ),
          extras: {'extra1': 'value1', 'extra2': 42},
        );

        final puzzle = GeneratedPuzzle(
          state: state,
          meta: meta,
          telemetry: telemetry,
        );

        // Serialize
        final json = puzzle.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['state'], isA<Map<String, dynamic>>());
        expect(json['meta'], isA<Map<String, dynamic>>());
        expect(json['telemetry'], isA<Map<String, dynamic>>());

        // Verify metadata
        final metaJson = json['meta'] as Map<String, dynamic>;
        expect(metaJson['engineVersion'], equals('1.0.0'));
        expect(metaJson['rngId'], equals('test-rng'));
        expect(metaJson['seedStr'], equals('test:stub:0'));
        expect(metaJson['seed64'], equals(12345));

        // Verify telemetry
        final telemetryJson = json['telemetry'] as Map<String, dynamic>;
        expect(telemetryJson['difficulty'], isA<Map<String, dynamic>>());
        expect(telemetryJson['extras'], isA<Map<String, dynamic>>());

        // Deserialize
        final deserialized = GeneratedPuzzle.fromJson(
          json,
          (stateJson) => StubPuzzleState.fromJson(stateJson),
        );
        expect(deserialized.meta.engineVersion, equals(puzzle.meta.engineVersion));
        expect(deserialized.meta.seedStr, equals(puzzle.meta.seedStr));
        expect(deserialized.telemetry?.difficulty.rawScore, equals(puzzle.telemetry?.difficulty.rawScore));
      });
    });

    group('Sudoku Engine Serialization', () {
      test('SudokuBoard serialization', () {
        final cells = List.generate(81, (index) => index % 10);
        final fixed = List.generate(81, (index) => index % 3 == 0);
        
        final board = SudokuBoard(cells: cells, fixed: fixed);

        // Serialize
        final json = board.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['cells'], isA<List>());
        expect(json['fixed'], isA<List>());
        expect(json['cells'].length, equals(81));
        expect(json['fixed'].length, equals(81));

        // Verify data integrity
        for (int i = 0; i < 81; i++) {
          expect(json['cells'][i], equals(board.cells[i]));
          expect(json['fixed'][i], equals(board.fixed[i]));
        }

        // Deserialize
        final deserialized = SudokuBoard.fromJson(json);
        expect(deserialized.cells, equals(board.cells));
        expect(deserialized.fixed, equals(board.fixed));
      });

      test('SudokuMove serialization', () {
        final move = SudokuMove(row: 5, col: 3, digit: 7);

        // Serialize
        final json = move.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['row'], equals(5));
        expect(json['col'], equals(3));
        expect(json['digit'], equals(7));

        // Deserialize
        final deserialized = SudokuMove.fromJson(json);
        expect(deserialized.row, equals(move.row));
        expect(deserialized.col, equals(move.col));
        expect(deserialized.digit, equals(move.digit));
      });
    });

    group('Core Types Serialization', () {
      test('SizeOpt serialization', () {
        const size = SizeOpt(
          id: '9x9',
          description: '9x9 Sudoku',
          width: 9,
          height: 9,
        );

        // Serialize
        final json = size.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['id'], equals('9x9'));
        expect(json['description'], equals('9x9 Sudoku'));
        expect(json['width'], equals(9));
        expect(json['height'], equals(9));

        // Deserialize
        final deserialized = SizeOpt.fromJson(json);
        expect(deserialized.id, equals(size.id));
        expect(deserialized.description, equals(size.description));
        expect(deserialized.width, equals(size.width));
        expect(deserialized.height, equals(size.height));
      });

      test('DifficultyScore serialization', () {
        const difficulty = DifficultyScore(value: 0.75, level: 'hard');

        // Serialize
        final json = difficulty.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['value'], equals(0.75));
        expect(json['level'], equals('hard'));

        // Deserialize
        final deserialized = DifficultyScore.fromJson(json);
        expect(deserialized.value, equals(difficulty.value));
        expect(deserialized.level, equals(difficulty.level));
      });

      test('PuzzleMetadata serialization', () {
        const meta = PuzzleMetadata(
          engineVersion: '2.0.0',
          rngId: 'xoroshiro128',
          size: SizeOpt(id: '6x6', description: '6x6', width: 6, height: 6),
          difficulty: DifficultyScore(value: 0.4, level: 'easy'),
          seedStr: 'sudoku:20240101',
          seed64: 98765,
        );

        // Serialize
        final json = meta.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['engineVersion'], equals('2.0.0'));
        expect(json['rngId'], equals('xoroshiro128'));
        expect(json['seedStr'], equals('sudoku:20240101'));
        expect(json['seed64'], equals(98765));
        expect(json['size'], isA<Map<String, dynamic>>());
        expect(json['difficulty'], isA<Map<String, dynamic>>());

        // Deserialize
        final deserialized = PuzzleMetadata.fromJson(json);
        expect(deserialized.engineVersion, equals(meta.engineVersion));
        expect(deserialized.rngId, equals(meta.rngId));
        expect(deserialized.seedStr, equals(meta.seedStr));
        expect(deserialized.seed64, equals(meta.seed64));
        expect(deserialized.size.id, equals(meta.size.id));
        expect(deserialized.difficulty.value, equals(meta.difficulty.value));
      });

      test('DifficultyTelemetry serialization', () {
        const telemetry = DifficultyTelemetry(
          rawScore: 0.8,
          bucket: 'hard',
          metrics: {
            'complexity': 0.7,
            'constraints': 0.9,
            'solving_time': 120.5,
          },
        );

        // Serialize
        final json = telemetry.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['rawScore'], equals(0.8));
        expect(json['bucket'], equals('hard'));
        expect(json['metrics'], isA<Map<String, dynamic>>());
        expect(json['metrics']['complexity'], equals(0.7));
        expect(json['metrics']['constraints'], equals(0.9));
        expect(json['metrics']['solving_time'], equals(120.5));

        // Deserialize
        final deserialized = DifficultyTelemetry.fromJson(json);
        expect(deserialized.rawScore, equals(telemetry.rawScore));
        expect(deserialized.bucket, equals(telemetry.bucket));
        expect(deserialized.metrics, equals(telemetry.metrics));
      });

      test('GenerationTelemetry serialization', () {
        const telemetry = GenerationTelemetry(
          difficulty: DifficultyTelemetry(
            rawScore: 0.6,
            bucket: 'medium',
            metrics: {'metric1': 1.0},
          ),
          extras: {
            'generation_time': 50.0,
            'iterations': 100,
            'success': true,
          },
        );

        // Serialize
        final json = telemetry.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['difficulty'], isA<Map<String, dynamic>>());
        expect(json['extras'], isA<Map<String, dynamic>>());
        expect(json['extras']['generation_time'], equals(50.0));
        expect(json['extras']['iterations'], equals(100));
        expect(json['extras']['success'], equals(true));

        // Deserialize
        final deserialized = GenerationTelemetry.fromJson(json);
        expect(deserialized.difficulty.rawScore, equals(telemetry.difficulty.rawScore));
        expect(deserialized.extras, equals(telemetry.extras));
      });
    });

    group('Move Result Serialization', () {
      test('MoveResult.success serialization', () {
        final state = StubPuzzleState(id: 'test', data: {'test': 'data'});
        final result = MoveResult.success(state);

        // Note: MoveResult doesn't have toJson/fromJson methods
        // This test verifies the structure is correct for serialization
        expect(result.isValid, isTrue);
        expect(result.newState, equals(state));
        expect(result.errorMessage, isNull);
      });

      test('MoveResult.failure serialization', () {
        final result = MoveResult.failure('Invalid move');

        // Note: MoveResult doesn't have toJson/fromJson methods
        // This test verifies the structure is correct for serialization
        expect(result.isValid, isFalse);
        expect(result.newState, isNull);
        expect(result.errorMessage, equals('Invalid move'));
      });
    });

    group('Round-trip Serialization', () {
      test('complete puzzle round-trip', () {
        // Create a complete puzzle
        final state = StubPuzzleState(
          id: 'round-trip-test',
          data: {
            'complex': {
              'nested': {
                'array': [1, 2, 3],
                'string': 'test',
                'number': 42.5,
                'boolean': true,
              },
            },
            'simple': 'value',
          },
        );

        const meta = PuzzleMetadata(
          engineVersion: '1.0.0',
          rngId: 'test-rng',
          size: SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9),
          difficulty: DifficultyScore(value: 0.6, level: 'medium'),
          seedStr: 'test:stub:0',
          seed64: 12345,
        );

        const telemetry = GenerationTelemetry(
          difficulty: DifficultyTelemetry(
            rawScore: 0.6,
            bucket: 'medium',
            metrics: {'metric1': 1.0, 'metric2': 2.0},
          ),
          extras: {'extra1': 'value1'},
        );

        final originalPuzzle = GeneratedPuzzle(
          state: state,
          meta: meta,
          telemetry: telemetry,
        );

        // Round-trip serialization
        final json = originalPuzzle.toJson();
        final deserializedPuzzle = GeneratedPuzzle.fromJson(
          json,
          (stateJson) => StubPuzzleState.fromJson(stateJson),
        );

        // Verify all components are preserved
        expect(deserializedPuzzle.meta.engineVersion, equals(originalPuzzle.meta.engineVersion));
        expect(deserializedPuzzle.meta.seedStr, equals(originalPuzzle.meta.seedStr));
        expect(deserializedPuzzle.meta.seed64, equals(originalPuzzle.meta.seed64));
        expect(deserializedPuzzle.telemetry?.difficulty.rawScore, equals(originalPuzzle.telemetry?.difficulty.rawScore));
        expect(deserializedPuzzle.telemetry?.extras, equals(originalPuzzle.telemetry?.extras));

        // Verify state is preserved
        final deserializedState = deserializedPuzzle.state;
        expect(deserializedState.id, equals(state.id));
        expect(deserializedState.data, equals(state.data));
      });
    });
  });
}