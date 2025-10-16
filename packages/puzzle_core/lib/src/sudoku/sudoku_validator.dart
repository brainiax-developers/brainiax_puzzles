import '../validation/validator.dart';
import 'sudoku_board.dart';

class SudokuValidator extends PuzzleValidator<SudokuBoard> {
  const SudokuValidator();

  @override
  ValidationSummary validatePuzzle(SudokuBoard board) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    for (int i = 0; i < SudokuBoard.cellCount; i++) {
      final int value = board.cells[i];
      final bool fixed = board.fixed[i];
      if (fixed && value == 0) {
        issues.add('fixed_zero:$i');
      }
      if (value < 0 || value > 9) {
        issues.add('out_of_range:$i');
      }
    }

    if (!_unitsAreValid(board.cells, allowEmpty: true)) {
      issues.add('unit_conflict');
    }

    stopwatch.stop();
    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  ValidationSummary validateSolution(SudokuBoard board, SudokuBoard solution) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    for (int i = 0; i < SudokuBoard.cellCount; i++) {
      final int original = board.cells[i];
      final bool fixed = board.fixed[i];
      final int solved = solution.cells[i];
      if (fixed && original != solved) {
        issues.add('fixed_mismatch:$i');
      }
      if (solved < 1 || solved > 9) {
        issues.add('invalid_digit:$i');
      }
    }

    if (!_unitsAreValid(solution.cells, allowEmpty: false)) {
      issues.add('unit_conflict');
    }

    stopwatch.stop();
    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  bool isSolved(SudokuBoard board) {
    if (!board.isComplete) {
      return false;
    }
    return _unitsAreValid(board.cells, allowEmpty: false);
  }

  bool _unitsAreValid(List<int> cells, {required bool allowEmpty}) {
    for (final List<int> unit in SudokuBoard.allUnits) {
      int seenMask = 0;
      for (final int index in unit) {
        final int value = cells[index];
        if (value == 0) {
          if (allowEmpty) {
            continue;
          } else {
            return false;
          }
        }
        if (value < 1 || value > 9) {
          return false;
        }
        final int bit = 1 << (value - 1);
        if ((seenMask & bit) != 0) {
          return false;
        }
        seenMask |= bit;
      }
    }
    return true;
  }
}
