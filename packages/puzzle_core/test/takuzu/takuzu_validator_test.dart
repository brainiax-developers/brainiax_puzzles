import 'package:test/test.dart';

import 'package:puzzle_core/src/takuzu/takuzu_board.dart';
import 'package:puzzle_core/src/takuzu/takuzu_validator.dart';
import 'package:puzzle_core/src/validation/validator.dart';

void main() {
  group('TakuzuValidator', () {
    const TakuzuValidator validator = TakuzuValidator();

    test('detects invalid triples in puzzle state', () {
      final TakuzuBoard board = TakuzuBoard(
        size: 4,
        cells: <int>[
          0, 0, 0, TakuzuBoard.empty,
          1, 1, TakuzuBoard.empty, 0,
          1, 0, 1, 0,
          TakuzuBoard.empty, 1, 0, 1,
        ],
        fixed: List<bool>.filled(16, false),
      );

      final ValidationSummary summary = validator.validatePuzzle(board);
      expect(summary.isValid, isFalse);
      expect(summary.issues, contains(contains('Row 0')));
    });

    test('accepts valid solution and detects solved state', () {
      final TakuzuBoard solution = TakuzuBoard(
        size: 4,
        cells: const <int>[
          0, 0, 1, 1,
          1, 1, 0, 0,
          1, 0, 0, 1,
          0, 1, 1, 0,
        ],
        fixed: List<bool>.filled(16, true),
      );

      final ValidationSummary check = validator.validateSolution(solution, solution);
      expect(check.isValid, isTrue);
      expect(validator.isSolved(solution), isTrue);
    });
  });
}
