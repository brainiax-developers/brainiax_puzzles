import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';
import 'package:test/test.dart';

void main() {
  test('numeric difficulties 0..3 normalize to Easy..Expert', () {
    final Map<String, String> expectation = {
      '0': 'easy',
      '1': 'medium',
      '2': 'hard',
      '3': 'expert',
    };

    expectation.forEach((input, expected) {
      final requested = KakuroGenerator.normalizeDifficultyForTest(input);
      expect(requested, expected);
    });
  });

  test('text difficulties pass through including expert', () {
    for (final level in ['easy', 'medium', 'hard', 'expert']) {
      final requested = KakuroGenerator.normalizeDifficultyForTest(level);
      expect(requested, level);
    }
  });
}
