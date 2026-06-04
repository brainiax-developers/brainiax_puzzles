import 'package:puzzle_core/src/nonogram/nonogram_board.dart';
import 'package:puzzle_core/src/nonogram/nonogram_validator.dart';
import 'package:puzzle_core/src/util/nonogram.dart';
import 'package:puzzle_core/src/validation/validator.dart';
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

    test(
      'isSolved rejects incomplete boards even when known cells match clues',
      () {
        final NonogramBoard board = NonogramBoard(
          width: 2,
          height: 2,
          rowClues: const <List<int>>[
            <int>[1],
            <int>[],
          ],
          columnClues: const <List<int>>[
            <int>[1],
            <int>[],
          ],
          cells: const <int?>[NonogramLineSolver.filled, null, null, null],
        );

        expect(validator.isSolved(board), isFalse);
      },
    );

    test('accepts a fully completed valid board', () {
      final NonogramBoard puzzle = NonogramBoard.empty(
        width: 2,
        height: 2,
        rowClues: const <List<int>>[
          <int>[1],
          <int>[],
        ],
        columnClues: const <List<int>>[
          <int>[1],
          <int>[],
        ],
      );
      final NonogramBoard solution = puzzle.copyWith(
        cells: const <int?>[
          NonogramLineSolver.filled,
          NonogramLineSolver.empty,
          NonogramLineSolver.empty,
          NonogramLineSolver.empty,
        ],
      );

      expect(validator.isSolved(solution), isTrue);
      expect(validator.validateSolution(puzzle, solution).isValid, isTrue);
    });

    test('rejects a fully completed invalid board', () {
      final NonogramBoard puzzle = NonogramBoard.empty(
        width: 2,
        height: 2,
        rowClues: const <List<int>>[
          <int>[1],
          <int>[],
        ],
        columnClues: const <List<int>>[
          <int>[1],
          <int>[],
        ],
      );
      final NonogramBoard solution = puzzle.copyWith(
        cells: const <int?>[
          NonogramLineSolver.filled,
          NonogramLineSolver.empty,
          NonogramLineSolver.empty,
          NonogramLineSolver.filled,
        ],
      );

      expect(validator.isSolved(solution), isFalse);
      expect(validator.validateSolution(puzzle, solution).isValid, isFalse);
    });

    test('validateSolution rejects null and out-of-range solution cells', () {
      final NonogramBoard puzzle = NonogramBoard.empty(
        width: 1,
        height: 1,
        rowClues: const <List<int>>[
          <int>[1],
        ],
        columnClues: const <List<int>>[
          <int>[1],
        ],
      );

      final ValidationSummary nullSummary = validator.validateSolution(
        puzzle,
        puzzle.copyWith(cells: const <int?>[null]),
      );
      final ValidationSummary outOfRangeSummary = validator.validateSolution(
        puzzle,
        puzzle.copyWith(cells: const <int?>[2]),
      );

      expect(nullSummary.isValid, isFalse);
      expect(nullSummary.issues, contains('solution_value_out_of_range:0'));
      expect(outOfRangeSummary.isValid, isFalse);
      expect(
        outOfRangeSummary.issues,
        contains('solution_value_out_of_range:0'),
      );
    });

    test('empty-line clues remain valid for completed empty boards', () {
      final NonogramBoard puzzle = NonogramBoard.empty(
        width: 2,
        height: 2,
        rowClues: const <List<int>>[<int>[], <int>[]],
        columnClues: const <List<int>>[<int>[], <int>[]],
      );
      final NonogramBoard solution = puzzle.copyWith(
        cells: const <int?>[
          NonogramLineSolver.empty,
          NonogramLineSolver.empty,
          NonogramLineSolver.empty,
          NonogramLineSolver.empty,
        ],
      );

      expect(validator.validatePuzzle(puzzle).isValid, isTrue);
      expect(validator.isSolved(solution), isTrue);
      expect(validator.validateSolution(puzzle, solution).isValid, isTrue);
    });
  });
}
