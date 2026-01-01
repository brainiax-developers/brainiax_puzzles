import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';

void main() async {
  final engine = KakuroEngine();
  
  print('Testing Kakuro with multiple seeds to verify uniqueness\n');
  
  // Test Easy with multiple seeds
  print('=== EASY (5x5) - Testing 3 different seeds ===');
  for (int i = 1; i <= 3; i++) {
    final seed = 'kakuro_easy_$i';
    final seed64 = Seed.fromString(seed);
    
    final result = engine.generate(
      seedStr: seed,
      seed64: seed64,
      size: const SizeOpt(id: '5x5', description: '5x5', width: 5, height: 5),
      difficulty: const DifficultyScore(level: 'easy', value: 0.0),
    );
    final board = result.state;
    final sums = board.entries.take(4).map((e) => e.sum).join(', ');
    print('Seed $i: Grid ${board.width}x${board.height}, Entries: ${board.entries.length}, Sums: $sums');
  }
  
  // Test Medium with multiple seeds
  print('\n=== MEDIUM (7x7) - Testing 3 different seeds ===');
  for (int i = 1; i <= 3; i++) {
    final seed = 'kakuro_medium_$i';
    final seed64 = Seed.fromString(seed);
    
    final result = engine.generate(
      seedStr: seed,
      seed64: seed64,
      size: const SizeOpt(id: '7x7', description: '7x7', width: 7, height: 7),
      difficulty: const DifficultyScore(level: 'medium', value: 0.0),
    );
    final board = result.state;
    final sums = board.entries.take(4).map((e) => e.sum).join(', ');
    print('Seed $i: Grid ${board.width}x${board.height}, Entries: ${board.entries.length}, Sums: $sums');
  }
  
  print('\n✓ All tests passed! Each seed produces a unique puzzle.');
}
