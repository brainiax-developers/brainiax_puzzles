import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main() {
  test('library loads and basic API works', () {
    // Test that the main API types are available
    expect(PuzzleType.values.isNotEmpty, isTrue);
    
    // Test that we can create basic types
    final size = SizeOpt(
      id: 'test',
      description: 'Test size',
      width: 9,
      height: 9,
    );
    expect(size.id, equals('test'));
    
    final difficulty = DifficultyScore(
      value: 0.5,
      level: 'Medium',
    );
    expect(difficulty.value, equals(0.5));
    
    // Test that registry works
    final registry = EngineRegistry();
    expect(registry.engineCount, equals(0));
    
    // Test that stub engines can be created
    final stubEngine = StubPuzzleEngine();
    expect(stubEngine.id, equals('stub'));
    
    final sudokuEngine = StubSudokuEngine();
    expect(sudokuEngine.id, equals('stub_sudoku'));
  });
}
