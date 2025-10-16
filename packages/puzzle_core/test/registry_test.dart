import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main() {
  group('EngineRegistry', () {
    late EngineRegistry registry;
    
    setUp(() {
      registry = EngineRegistry();
      registry.clear(); // Ensure clean state for each test
    });
    
    test('can register and fetch engines by id', () {
      final engine = StubPuzzleEngine();
      
      registry.register(engine);
      
      expect(registry.hasEngine(engine.id), isTrue);
      expect(registry.getEngine(engine.id), equals(engine));
      expect(registry.registeredIds, contains(engine.id));
    });
    
    test('rejects duplicate registrations', () {
      final engine1 = StubPuzzleEngine();
      final engine2 = StubPuzzleEngine();
      
      registry.register(engine1);
      
      expect(
        () => registry.register(engine2),
        throwsA(isA<ArgumentError>()),
      );
    });
    
    test('returns null for non-existent engine', () {
      expect(registry.getEngine('non_existent'), isNull);
      expect(registry.hasEngine('non_existent'), isFalse);
    });
    
    test('can register multiple different engines', () {
      final stubEngine = StubPuzzleEngine();
      final sudokuEngine = StubSudokuEngine();
      
      registry.register(stubEngine);
      registry.register(sudokuEngine);
      
      expect(registry.engineCount, equals(2));
      expect(registry.registeredIds, containsAll([stubEngine.id, sudokuEngine.id]));
      expect(registry.getEngine(stubEngine.id), equals(stubEngine));
      expect(registry.getEngine(sudokuEngine.id), equals(sudokuEngine));
    });
    
    test('can clear all engines', () {
      final engine = StubPuzzleEngine();
      registry.register(engine);
      
      expect(registry.engineCount, equals(1));
      
      registry.clear();
      
      expect(registry.engineCount, equals(0));
      expect(registry.registeredIds, isEmpty);
      expect(registry.getEngine(engine.id), isNull);
    });
    
    test('extension methods work correctly', () {
      final engine = StubPuzzleEngine();
      registry.register(engine);
      
      expect(registry.hasEngine(engine.id), isTrue);
      expect(registry.engineCount, equals(1));
      expect(registry.allEngines, contains(engine));
      
      final typedEngine = registry.getEngineAs<PuzzleEngine>(engine.id);
      expect(typedEngine, equals(engine));
      
      // Test that wrong type returns null (this will throw at runtime, which is expected)
      expect(() => registry.getEngineAs<String>(engine.id), throwsA(isA<TypeError>()));
    });
  });
}
