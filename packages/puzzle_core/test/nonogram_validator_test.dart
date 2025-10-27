import 'package:puzzle_core/src/nonogram/nonogram_board.dart';
import 'package:puzzle_core/src/nonogram/nonogram_validator.dart';
import 'package:test/test.dart';

void main() {
  group('Nonogram validator', () {
    const NonogramValidator validator = NonogramValidator();

    test('flags row clues that cannot fit the board', () {
      final NonogramBoard board = NonogramBoard.empty(
        width: 5,
        height: 1,
        rowClues: const <List<int>>[
          <int>[3, 3],
        ],
        columnClues: const <List<int>>[
          <int>[],
          <int>[],
          <int>[],
          <int>[],
          <int>[],
        ],
      );

      final summary = validator.validatePuzzle(board);
      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('row_clues_overflow:0'));
    });

    test('flags column clues that cannot fit the board', () {
      final NonogramBoard board = NonogramBoard.empty(
        width: 1,
        height: 5,
        rowClues: const <List<int>>[
          <int>[],
          <int>[],
          <int>[],
          <int>[],
          <int>[],
        ],
        columnClues: const <List<int>>[
          <int>[4, 1],
        ],
      );

      final summary = validator.validatePuzzle(board);
      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('column_clues_overflow:0'));
    });

    test('accepts a puzzle with consistent clues', () {
      final NonogramBoard board = NonogramBoard.empty(
        width: 5,
        height: 5,
        rowClues: const <List<int>>[
          <int>[1],
          <int>[3],
          <int>[5],
          <int>[3],
          <int>[1],
        ],
        columnClues: const <List<int>>[
          <int>[1],
          <int>[3],
          <int>[5],
          <int>[3],
          <int>[1],
        ],
      );

      final summary = validator.validatePuzzle(board);
      expect(summary.isValid, isTrue);
    });
  });
}
