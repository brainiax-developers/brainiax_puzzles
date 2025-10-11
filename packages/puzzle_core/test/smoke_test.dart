import 'package:test/test.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main() {
  test('library loads', () {
    // reference something so import isn't unused
    expect(PuzzleType.values.isNotEmpty, isTrue);
  });
}
