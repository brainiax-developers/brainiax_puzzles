import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

void main() {
  const SudokuValidator validator = SudokuValidator();
  const String solvedString =
      '534678912672195348198342567859761423426853791713924856961537284287419635345286179';
  final SudokuBoard solvedBoard = SudokuBoard.fromSolutionString(solvedString);

  group('SudokuValidator', () {
    test('valid puzzle passes validation', () {
      final List<int> puzzleCells = List<int>.from(solvedBoard.cells);
      puzzleCells[0] = 0;
      puzzleCells[10] = 0;
      final SudokuBoard puzzle = SudokuBoard(
        cells: puzzleCells,
        fixed: puzzleCells.map((int value) => value != 0).toList(growable: false),
      );

      final ValidationSummary summary = validator.validatePuzzle(puzzle);
      expect(summary.isValid, isTrue);
    });

    test('detects row conflicts and out-of-range values', () {
      final List<int> conflictCells = List<int>.from(solvedBoard.cells);
      conflictCells[1] = conflictCells[0];
      conflictCells[5] = -1;
      final SudokuBoard puzzle = SudokuBoard(
        cells: conflictCells,
        fixed: conflictCells.map((int value) => value != 0).toList(growable: false),
      );

      final ValidationSummary summary = validator.validatePuzzle(puzzle);
      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('unit_conflict'));
      expect(summary.issues.where((issue) => issue.startsWith('out_of_range')).length, greaterThan(0));
    });

    test('validateSolution catches mismatched fixed clues and invalid digits', () {
      final ValidationSummary ok = validator.validateSolution(solvedBoard, solvedBoard);
      expect(ok.isValid, isTrue);

      final List<int> wrongCells = List<int>.from(solvedBoard.cells);
      wrongCells[10] = (wrongCells[10] % 9) + 1;
      final SudokuBoard wrongSolution = SudokuBoard(
        cells: wrongCells,
        fixed: List<bool>.filled(SudokuBoard.cellCount, true),
      );
      final ValidationSummary mismatch = validator.validateSolution(solvedBoard, wrongSolution);
      expect(mismatch.isValid, isFalse);
      expect(mismatch.issues, contains('fixed_mismatch:10'));

      wrongCells[0] = 0;
      final SudokuBoard invalidDigits = SudokuBoard(
        cells: wrongCells,
        fixed: List<bool>.filled(SudokuBoard.cellCount, true),
      );
      final ValidationSummary invalid = validator.validateSolution(solvedBoard, invalidDigits);
      expect(invalid.isValid, isFalse);
      expect(invalid.issues.where((issue) => issue.startsWith('invalid_digit')).length, greaterThan(0));
    });

    test('isSolved returns correct status', () {
      expect(validator.isSolved(solvedBoard), isTrue);

      final SudokuBoard unsolved = SudokuBoard(
        cells: List<int>.from(solvedBoard.cells)..[40] = 0,
        fixed: List<bool>.filled(SudokuBoard.cellCount, true),
      );
      expect(validator.isSolved(unsolved), isFalse);
    });
  });
}
