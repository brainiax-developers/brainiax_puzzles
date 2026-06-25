import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/mathdoku/mathdoku_solver.dart';
import 'package:puzzle_core/src/mathdoku/mathdoku_validator.dart';
import 'package:test/test.dart';

void main() {
  group('Mathdoku solver and validator fixtures', () {
    const MathdokuSolver solver = MathdokuSolver();
    const MathdokuValidator validator = MathdokuValidator();

    const List<int> latin4Solution = <int>[
      1, 2, 3, 4,
      2, 3, 4, 1,
      3, 4, 1, 2,
      4, 1, 2, 3,
    ];

    List<MathdokuCage> equalityCagesFromCells(List<int> cells) {
      return List<MathdokuCage>.generate(
        cells.length,
        (int index) => MathdokuCage(
          id: index,
          cells: <int>[index],
          operation: MathdokuOperation.equality,
          target: cells[index],
        ),
        growable: false,
      );
    }

    test('known unique-solution 4x4 fixture has exactly one solution', () {
      final MathdokuBoard uniquePuzzle = MathdokuBoard(
        size: 4,
        cells: List<int>.filled(16, 0),
        cages: equalityCagesFromCells(latin4Solution),
      );

      final SolverResult<MathdokuBoard> result = solver.solve(
        uniquePuzzle,
        SolverContext(rng: SeededRng(101), maxSolutions: 2),
      );

      expect(result.solutions.length, equals(1));
      expect(result.isUnique, isTrue);
      expect(result.solutions.first.cells, equals(latin4Solution));
      expect(validator.isSolved(result.solutions.first), isTrue);
    });

    test('known multi-solution 4x4 fixture counts up to maxSolutions=2', () {
      final MathdokuBoard multiPuzzle = MathdokuBoard(
        size: 4,
        cells: List<int>.filled(16, 0),
        cages: <MathdokuCage>[
          MathdokuCage(
            id: 0,
            cells: const <int>[0],
            operation: MathdokuOperation.equality,
            target: 1,
          ),
          MathdokuCage(
            id: 1,
            cells: const <int>[1],
            operation: MathdokuOperation.equality,
            target: 2,
          ),
          MathdokuCage(
            id: 2,
            cells: const <int>[2],
            operation: MathdokuOperation.equality,
            target: 3,
          ),
          MathdokuCage(
            id: 3,
            cells: const <int>[3],
            operation: MathdokuOperation.equality,
            target: 4,
          ),
          MathdokuCage(
            id: 4,
            cells: const <int>[4],
            operation: MathdokuOperation.equality,
            target: 2,
          ),
          MathdokuCage(
            id: 5,
            cells: const <int>[8],
            operation: MathdokuOperation.equality,
            target: 3,
          ),
          MathdokuCage(
            id: 6,
            cells: const <int>[12],
            operation: MathdokuOperation.equality,
            target: 4,
          ),
          MathdokuCage(
            id: 7,
            cells: const <int>[5, 6, 7, 9, 10, 11, 13, 14, 15],
            operation: MathdokuOperation.addition,
            target: 21,
          ),
        ],
      );

      final SolverResult<MathdokuBoard> result = solver.solve(
        multiPuzzle,
        SolverContext(rng: SeededRng(102), maxSolutions: 2),
      );

      expect(result.solutions.length, equals(2));
      expect(result.isUnique, isFalse);
      for (final MathdokuBoard solution in result.solutions) {
        expect(validator.isSolved(solution), isTrue);
      }
    });

    test('completed board with cage mismatch yields zero solutions', () {
      final List<int> wrongCageTargets = List<int>.from(latin4Solution)
        ..[5] = 4;
      final MathdokuBoard invalidCompletedBoard = MathdokuBoard(
        size: 4,
        cells: latin4Solution,
        cages: equalityCagesFromCells(wrongCageTargets),
      );

      final SolverResult<MathdokuBoard> result = solver.solve(
        invalidCompletedBoard,
        SolverContext(rng: SeededRng(103), maxSolutions: 2),
      );

      expect(result.solutions, isEmpty);
      expect(validator.isSolved(invalidCompletedBoard), isFalse);
      expect(
        validator
            .validateSolution(invalidCompletedBoard, invalidCompletedBoard)
            .issues,
        contains('cage_5_mismatch'),
      );
    });

    test('row duplicate is rejected', () {
      const List<int> rowDuplicateCells = <int>[
        1, 1, 3, 4,
        2, 3, 4, 1,
        3, 4, 1, 2,
        4, 2, 2, 3,
      ];
      final MathdokuBoard rowDuplicateBoard = MathdokuBoard(
        size: 4,
        cells: rowDuplicateCells,
        cages: equalityCagesFromCells(rowDuplicateCells),
      );

      final ValidationSummary validation =
          validator.validateSolution(rowDuplicateBoard, rowDuplicateBoard);
      expect(validation.isValid, isFalse);
      expect(validation.issues, contains('row_0_duplicate_1'));

      final SolverResult<MathdokuBoard> result = solver.solve(
        rowDuplicateBoard,
        SolverContext(rng: SeededRng(104), maxSolutions: 2),
      );
      expect(result.solutions, isEmpty);
    });

    test('column duplicate is rejected', () {
      const List<int> columnDuplicateCells = <int>[
        1, 2, 3, 4,
        1, 3, 4, 2,
        3, 4, 2, 1,
        4, 1, 2, 3,
      ];
      final MathdokuBoard columnDuplicateBoard = MathdokuBoard(
        size: 4,
        cells: columnDuplicateCells,
        cages: equalityCagesFromCells(columnDuplicateCells),
      );

      final ValidationSummary validation =
          validator.validateSolution(columnDuplicateBoard, columnDuplicateBoard);
      expect(validation.isValid, isFalse);
      expect(validation.issues, contains('col_0_duplicate_1'));

      final SolverResult<MathdokuBoard> result = solver.solve(
        columnDuplicateBoard,
        SolverContext(rng: SeededRng(105), maxSolutions: 2),
      );
      expect(result.solutions, isEmpty);
    });

    test('board serialization round-trip preserves cells and cages', () {
      final MathdokuBoard original = MathdokuBoard(
        size: 4,
        cells: List<int>.filled(16, 0),
        cages: equalityCagesFromCells(latin4Solution),
      );

      final Map<String, dynamic> encoded = original.toJson();
      final MathdokuBoard decoded = MathdokuBoard.fromJson(encoded);

      expect(decoded.size, equals(original.size));
      expect(decoded.cells, equals(original.cells));
      expect(decoded.cages, equals(original.cages));
      expect(decoded, equals(original));
    });
  });
}
