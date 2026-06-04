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

    group('line placements', () {
      test('empty clue only permits an empty line', () {
        expect(
          NonogramLineSolver.generatePlacements(3, const <int>[]),
          equals(const <List<int>>[
            <int>[0, 0, 0],
          ]),
        );
        expect(
          NonogramLineSolver.propagate(const <int?>[
            null,
            null,
            null,
          ], const <int>[]).updated,
          equals(const <int?>[0, 0, 0]),
        );
      });

      test('full clue fills the entire line', () {
        expect(
          NonogramLineSolver.generatePlacements(3, const <int>[3]),
          equals(const <List<int>>[
            <int>[1, 1, 1],
          ]),
        );
        expect(
          NonogramLineSolver.propagate(
            const <int?>[null, null, null],
            const <int>[3],
          ).updated,
          equals(const <int?>[1, 1, 1]),
        );
      });

      test('[1,1] requires a separator and enumerates legal offsets', () {
        expect(
          NonogramLineSolver.generatePlacements(3, const <int>[1, 1]),
          equals(const <List<int>>[
            <int>[1, 0, 1],
          ]),
        );
        expect(
          NonogramLineSolver.generatePlacements(4, const <int>[1, 1]),
          equals(const <List<int>>[
            <int>[1, 0, 1, 0],
            <int>[1, 0, 0, 1],
            <int>[0, 1, 0, 1],
          ]),
        );
      });

      test('known filled and empty contradictions remove all placements', () {
        expect(
          NonogramLineSolver.generatePlacements(
            3,
            const <int>[],
            current: const <int?>[null, 1, null],
          ),
          isEmpty,
        );

        final NonogramPropagationResult result = NonogramLineSolver.propagate(
          const <int?>[null, 0, null],
          const <int>[3],
        );

        expect(result.contradiction, isTrue);
        expect(result.updated, equals(const <int?>[null, 0, null]));
      });

      test('intersection reports mustFill and mustEmpty cells', () {
        final List<List<int>> placements =
            NonogramLineSolver.generatePlacements(5, const <int>[3]);

        expect(
          placements,
          equals(const <List<int>>[
            <int>[1, 1, 1, 0, 0],
            <int>[0, 1, 1, 1, 0],
            <int>[0, 0, 1, 1, 1],
          ]),
        );
        expect(
          NonogramLineSolver.intersectPlacements(placements),
          equals(const <int?>[null, null, 1, null, null]),
        );
        expect(
          NonogramLineSolver.propagate(
            const <int?>[null, null, null, null, 0],
            const <int>[3],
          ).updated,
          equals(const <int?>[null, 1, 1, null, 0]),
        );
      });
    });
  });
}
