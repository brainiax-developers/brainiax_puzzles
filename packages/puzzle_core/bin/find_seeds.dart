import 'package:puzzle_core/puzzle_core.dart';

void main() {
  final SudokuEngine engine = SudokuEngine();
  const SizeOpt size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);

  final List<String> levels = ['easy', 'medium', 'hard', 'expert'];
  for (final level in levels) {
    int i = 0;
    while (true) {
      final String seedStr = 'find_seed:$level:$i';
      final GeneratedPuzzle puzzle = engine.generate(
        seedStr: seedStr,
        seed64: Seed.fromString(seedStr),
        size: size,
        difficulty: DifficultyScore(value: 0, level: level),
      );
      if (puzzle.meta.difficulty.level == level) {
        print('Found seed for $level: $seedStr');
        break;
      }
      i++;
    }
  }
}
