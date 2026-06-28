import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

void main() {
  final SudokuEngine engine = SudokuEngine();
  const SizeOpt size = SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);
  const Map<String, List<int>> expectedRanges = <String, List<int>>{
    'easy': <int>[38, 49],
    'medium': <int>[32, 37],
    'hard': <int>[27, 31],
    'expert': <int>[24, 26],
  };

  group('SudokuGenerator difficulty buckets', () {
    expectedRanges.forEach((String difficulty, List<int> range) {
      test('"$difficulty" difficulty respects clue range', () {
        int i = 0;
        GeneratedPuzzle? puzzle;
        while (puzzle == null) {
          final String seed = 'test:sudoku_classic:$difficulty:$i';
          final GeneratedPuzzle attempt = engine.generate(
            seedStr: seed,
            seed64: Seed.fromString(seed),
            size: size,
            difficulty: DifficultyScore(value: 0, level: difficulty),
          );
          if (attempt.meta.difficulty.level == difficulty) {
            puzzle = attempt;
          }
          i++;
        }

        final SudokuBoard board = puzzle!.state as SudokuBoard;
        expect(board.clueCount, inInclusiveRange(range[0], range[1]));
        expect(puzzle.meta.difficulty.level, equals(difficulty));
      });
    });
  });
}
