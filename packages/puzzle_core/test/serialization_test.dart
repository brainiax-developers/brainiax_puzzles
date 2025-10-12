import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main() {
  group('Serialization Tests', () {
    test('GeneratedPuzzle round-trip serialization', () {
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
      
      final meta = PuzzleMetadata(
        engineVersion: '1.0.0',
        rngId: 'test_rng',
        size: size,
        difficulty: difficulty,
        seedStr: 'test_seed',
        seed64: 12345,
      );
      
      final state = StubPuzzleState(
        id: 'test_puzzle',
        data: {'test': 'data', 'number': 42},
      );
      
      final telemetry = GenerationTelemetry(
        difficulty: const DifficultyTelemetry(
          rawScore: 0.42,
          bucket: 'medium',
          metrics: {'givens': 30},
        ),
        extras: {
          'generator': {'durationMs': 1.2},
          'solver': {'nodes': 12},
        },
      );

      final puzzle = GeneratedPuzzle(
        state: state,
        meta: meta,
        telemetry: telemetry,
      );
      
      // Serialize to JSON
      final json = puzzle.toJson();
      
      // Deserialize from JSON
      final restoredPuzzle = GeneratedPuzzle.fromJson(
        json,
        (json) => StubPuzzleState.fromJson(json),
      );
      
      // Verify metadata is preserved
      expect(restoredPuzzle.meta.engineVersion, equals(meta.engineVersion));
      expect(restoredPuzzle.meta.rngId, equals(meta.rngId));
      expect(restoredPuzzle.meta.size, equals(meta.size));
      expect(restoredPuzzle.meta.difficulty, equals(meta.difficulty));
      expect(restoredPuzzle.meta.seedStr, equals(meta.seedStr));
      expect(restoredPuzzle.meta.seed64, equals(meta.seed64));

      // Verify state is preserved
      expect(restoredPuzzle.state.id, equals(state.id));
      expect(restoredPuzzle.state.data, equals(state.data));

      // Verify telemetry is preserved
      expect(restoredPuzzle.telemetry?.difficulty.bucket, equals('medium'));
      expect(restoredPuzzle.telemetry?.difficulty.rawScore, equals(0.42));
      expect(restoredPuzzle.telemetry?.extras['generator'], equals({'durationMs': 1.2}));
    });
    
    test('PuzzleMetadata round-trip serialization', () {
      final size = SizeOpt(
        id: '6x6',
        description: 'Small 6x6',
        width: 6,
        height: 6,
      );
      
      final difficulty = DifficultyScore(
        value: 0.8,
        level: 'Hard',
      );
      
      final meta = PuzzleMetadata(
        engineVersion: '2.0.0',
        rngId: 'advanced_rng',
        size: size,
        difficulty: difficulty,
        seedStr: 'daily:20240101',
        seed64: 98765,
      );
      
      // Serialize to JSON
      final json = meta.toJson();
      
      // Deserialize from JSON
      final restoredMeta = PuzzleMetadata.fromJson(json);
      
      // Verify all fields are preserved
      expect(restoredMeta.engineVersion, equals(meta.engineVersion));
      expect(restoredMeta.rngId, equals(meta.rngId));
      expect(restoredMeta.size, equals(meta.size));
      expect(restoredMeta.difficulty, equals(meta.difficulty));
      expect(restoredMeta.seedStr, equals(meta.seedStr));
      expect(restoredMeta.seed64, equals(meta.seed64));
    });
    
    test('SizeOpt round-trip serialization', () {
      final size = SizeOpt(
        id: 'custom',
        description: 'Custom size',
        width: 12,
        height: 8,
      );
      
      final json = size.toJson();
      final restoredSize = SizeOpt.fromJson(json);
      
      expect(restoredSize.id, equals(size.id));
      expect(restoredSize.description, equals(size.description));
      expect(restoredSize.width, equals(size.width));
      expect(restoredSize.height, equals(size.height));
    });
    
    test('DifficultyScore round-trip serialization', () {
      final difficulty = DifficultyScore(
        value: 0.3,
        level: 'Easy',
      );
      
      final json = difficulty.toJson();
      final restoredDifficulty = DifficultyScore.fromJson(json);
      
      expect(restoredDifficulty.value, equals(difficulty.value));
      expect(restoredDifficulty.level, equals(difficulty.level));
    });
    
    test('StubPuzzleState round-trip serialization', () {
      final state = StubPuzzleState(
        id: 'complex_state',
        data: {
          'numbers': [1, 2, 3],
          'nested': {'key': 'value'},
          'boolean': true,
        },
      );
      
      final json = state.toJson();
      final restoredState = StubPuzzleState.fromJson(json);
      
      expect(restoredState.id, equals(state.id));
      expect(restoredState.data, equals(state.data));
    });
    
    test('StubPuzzleMove round-trip serialization', () {
      final move = StubPuzzleMove(
        type: 'place_number',
        data: {
          'row': 5,
          'col': 3,
          'value': 7,
        },
      );
      
      final json = move.toJson();
      final restoredMove = StubPuzzleMove.fromJson(json);
      
      expect(restoredMove.type, equals(move.type));
      expect(restoredMove.data, equals(move.data));
    });
  });
}
