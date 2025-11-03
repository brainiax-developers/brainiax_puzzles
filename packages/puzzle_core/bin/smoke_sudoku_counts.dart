import 'package:puzzle_core/puzzle_core.dart';

void main() {
  final engine = SudokuEngine();
  for (final level in ['easy','medium','hard','expert']) {
    final generated = engine.generate(
      seedStr: 'random',
      seed64: 123456789,
      size: const SizeOpt(id: '9x9', description: 'Standard 9x9', width: 9, height: 9),
      difficulty: DifficultyScore(level: level, value: 0.5),
    );
    final board = generated.state as SudokuBoard;
    final clues = board.clueCount;
    print('level=$level clues=$clues bucket=${generated.meta.difficulty.level}');
  }
}
