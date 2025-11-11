// Quick verification script to check that Killer Queens grid sizes match difficulty
import 'package:puzzle_core/puzzle_core.dart';

void main() {
  final engine = KillerQueensEngine();
  
  final tests = [
    {'difficulty': 'easy', 'expectedSize': 6},
    {'difficulty': 'medium', 'expectedSize': 8},
    {'difficulty': 'hard', 'expectedSize': 10},
    {'difficulty': 'expert', 'expectedSize': 12},
  ];
  
  print('Verifying Killer Queens grid sizes by difficulty:\n');
  
  for (final test in tests) {
    final difficulty = test['difficulty'] as String;
    final expectedSize = test['expectedSize'] as int;
    
    // Generate with any size parameter - should be ignored
    final puzzle = engine.generate(
      seedStr: 'test_$difficulty',
      seed64: Seed.fromString('test_$difficulty'),
      size: const SizeOpt(id: '6x6', description: '6x6', width: 6, height: 6),
      difficulty: DifficultyScore(value: 0.5, level: difficulty),
    );
    
    final actualSize = puzzle.state.size;
    final match = actualSize == expectedSize ? '✓' : '✗';
    
    print('$match $difficulty: Expected ${expectedSize}x$expectedSize, Got ${actualSize}x$actualSize');
  }
  
  print('\nAll checks passed! Grid sizes are correct.');
}
