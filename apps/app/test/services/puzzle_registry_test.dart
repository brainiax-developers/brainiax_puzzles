import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import 'package:app/shared/services/puzzle_registry.dart';
import 'package:app/shared/models/puzzle_type.dart' as app;

class _HintlessEngine extends core.StubPuzzleEngine {
  _HintlessEngine({required String engineId})
      : super(engineId: engineId, engineName: 'Hintless Engine');

  @override
  core.PuzzleCapabilities get capabilities => const core.PuzzleCapabilities();

  @override
  core.PuzzleHint? requestHint({
    required core.StubPuzzleState currentState,
    core.PuzzleHintRequest? request,
  }) {
    return null;
  }
}

void main() {
  group('PuzzleRegistry', () {
    late PuzzleRegistry registry;

    setUp(() {
      registry = PuzzleRegistry();
      // Clear the engine registry to start fresh
      core.EngineRegistry().clear();
    });

    tearDown(() {
      core.EngineRegistry().clear();
    });

    test('should initialize with no engines when none are registered', () {
      registry.initialize();
      
      expect(registry.availablePuzzleCount, equals(0));
      expect(registry.getAvailablePuzzleTypes(), isEmpty);
      expect(registry.getAllPuzzleMetadata(), isEmpty);
    });

    test('should initialize with available engines', () {
      // Register some engines with correct IDs
      core.EngineRegistry().register(core.StubPuzzleEngine(engineId: 'sudoku_classic'));
      core.EngineRegistry().register(core.StubPuzzleEngine(engineId: 'nonogram_mono'));
      
      registry.initialize();
      
      expect(registry.availablePuzzleCount, greaterThan(0));
      expect(registry.getAvailablePuzzleTypes(), isNotEmpty);
      expect(registry.getAllPuzzleMetadata(), isNotEmpty);
    });

    test('should return null for unavailable puzzle types', () {
      registry.initialize();
      
      expect(registry.getMetadata(app.PuzzleType.sudokuClassic), isNull);
      expect(registry.isPuzzleTypeAvailable(app.PuzzleType.sudokuClassic), isFalse);
    });

    test('should return metadata for available puzzle types', () {
      // Register a sudoku engine with correct ID
      core.EngineRegistry().register(core.StubPuzzleEngine(engineId: 'sudoku_classic'));
      
      registry.initialize();
      
      final metadata = registry.getMetadata(app.PuzzleType.sudokuClassic);
      expect(metadata, isNotNull);
      expect(metadata!.type, equals(app.PuzzleType.sudokuClassic));
      expect(metadata.displayName, equals('Classic Sudoku'));
      expect(metadata.supportedSizes, isNotEmpty);
      expect(metadata.supportedDifficulties, isNotEmpty);
      expect(metadata.supportsHints, isTrue);
    });

    test('should have correct metadata for all puzzle types', () {
      // Register engines with correct IDs
      core.EngineRegistry().register(core.StubPuzzleEngine(engineId: 'sudoku_classic'));
      core.EngineRegistry().register(core.StubPuzzleEngine(engineId: 'nonogram_mono'));
      
      registry.initialize();
      
      for (final puzzleType in app.PuzzleType.values) {
        final metadata = registry.getMetadata(puzzleType);
        if (metadata != null) {
          expect(metadata.type, equals(puzzleType));
          expect(metadata.displayName, equals(puzzleType.displayName));
          expect(metadata.accentColors, isNotEmpty);
          expect(metadata.supportedSizes, isNotEmpty);
          expect(metadata.supportedDifficulties, isNotEmpty);
          expect(metadata.supportsHints, isA<bool>());
        }
      }
    });

    test('should provide primary and secondary accent colors', () {
      // Register a sudoku engine with correct ID
      core.EngineRegistry().register(core.StubPuzzleEngine(engineId: 'sudoku_classic'));

      registry.initialize();

      final metadata = registry.getMetadata(app.PuzzleType.sudokuClassic);
      expect(metadata, isNotNull);
      expect(metadata!.primaryAccentColor, isNotNull);
      expect(metadata.secondaryAccentColor, isNotNull);
    });

    test('uses engine capability probe for hint support', () {
      core.EngineRegistry().register(
        _HintlessEngine(engineId: 'sudoku_classic'),
      );

      registry.initialize();

      final metadata = registry.getMetadata(app.PuzzleType.sudokuClassic);
      expect(metadata, isNotNull);
      expect(metadata!.supportsHints, isFalse);
    });

    test('exposes only shipping-safe Kakuro profiles in app metadata', () {
      core.EngineRegistry().register(
        core.StubPuzzleEngine(engineId: 'kakuro_classic'),
      );

      registry.initialize();

      final metadata = registry.getMetadata(app.PuzzleType.kakuroClassic);
      expect(metadata, isNotNull);
      expect(metadata!.supportedSizes, equals(<String>['7x7']));
      expect(metadata.supportedDifficulties, equals(<String>['Easy']));
    });
  });
}
