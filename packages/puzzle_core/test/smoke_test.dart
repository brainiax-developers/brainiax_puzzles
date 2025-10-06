import 'package:flutter_test/flutter_test.dart'; // flutter_test works in packages too
import 'package:puzzle_core/puzzle_core.dart';

void main() {
  test('puzzle_core exports scaffold', () {
    expect(PuzzleType.sudoku.index >= 0, true);
    final rng = SeededRng(123);
    expect(rng.nextInt(10), isNonNegative);
  });
}
