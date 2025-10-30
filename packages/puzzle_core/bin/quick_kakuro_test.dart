import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';

void main() {
  final engine = KakuroEngine();
  
  print('Quick Kakuro generation test\n');
  
  // Test each difficulty once
  final tests = [
    ('easy', 'test_easy_1', 5, 5),
    ('medium', 'test_medium_1', 7, 7),
    ('hard', 'test_hard_1', 9, 9),
  ];
  
  for (final test in tests) {
    final (level, seed, width, height) = test;
    print('Testing $level (${width}x$height)...');
    final seed64 = Seed.fromString(seed);
    
    try {
      final result = engine.generate(
        seedStr: seed,
        seed64: seed64,
        size: SizeOpt(id: '${width}x$height', description: '${width}x$height', width: width, height: height),
        difficulty: DifficultyScore(level: level, value: 0.0),
      );
      final board = result.state;
      print('  ✓ Generated ${board.width}x${board.height} puzzle with ${board.entries.length} entries');
      
      // Show a few entry sums as signature
      final sums = board.entries.take(3).map((e) => e.sum).join(', ');
      print('  First 3 sums: $sums\n');
    } catch (e) {
      print('  ✗ Failed: $e\n');
    }
  }
  
  print('Test complete!');
}
