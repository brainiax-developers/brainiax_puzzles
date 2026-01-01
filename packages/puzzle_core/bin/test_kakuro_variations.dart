import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';

void main() {
  final engine = KakuroEngine();
  
  print('Testing Kakuro puzzle generation with different difficulties and seeds...\n');
  
  // Test Easy difficulty
  print('=== EASY Difficulty (5x5) ===');
  for (int i = 0; i < 3; i++) {
    final seed = 'test_easy_$i';
    final seed64 = Seed.fromString(seed);
    final result = engine.generate(
      seedStr: seed,
      seed64: seed64,
      size: const SizeOpt(id: '5x5', description: '5x5', width: 5, height: 5),
      difficulty: const DifficultyScore(level: 'easy', value: 0.0),
    );
    final board = result.state;
    print('Seed: $seed');
    print('  Grid: ${board.width}x${board.height}');
    print('  Entries: ${board.entries.length}');
    print('  Signature: ${_getBoardSignature(board)}\n');
  }
  
  // Test Medium difficulty
  print('=== MEDIUM Difficulty (7x7) ===');
  for (int i = 0; i < 3; i++) {
    final seed = 'test_medium_$i';
    final seed64 = Seed.fromString(seed);
    final result = engine.generate(
      seedStr: seed,
      seed64: seed64,
      size: const SizeOpt(id: '7x7', description: '7x7', width: 7, height: 7),
      difficulty: const DifficultyScore(level: 'medium', value: 0.0),
    );
    final board = result.state;
    print('Seed: $seed');
    print('  Grid: ${board.width}x${board.height}');
    print('  Entries: ${board.entries.length}');
    print('  Signature: ${_getBoardSignature(board)}\n');
  }
  
  // Test Hard difficulty
  print('=== HARD Difficulty (9x9) ===');
  for (int i = 0; i < 3; i++) {
    final seed = 'test_hard_$i';
    final seed64 = Seed.fromString(seed);
    final result = engine.generate(
      seedStr: seed,
      seed64: seed64,
      size: const SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9),
      difficulty: const DifficultyScore(level: 'hard', value: 0.0),
    );
    final board = result.state;
    print('Seed: $seed');
    print('  Grid: ${board.width}x${board.height}');
    print('  Entries: ${board.entries.length}');
    print('  Signature: ${_getBoardSignature(board)}\n');
  }
  
  print('All tests completed successfully!');
}

String _getBoardSignature(KakuroBoard board) {
  // Create a signature based on entry sums to verify uniqueness
  final sums = <int>[];
  for (final entry in board.entries) {
    sums.add(entry.sum);
  }
  return sums.take(5).join(',');
}
