import '../validation/validator.dart';
import 'futoshiki_board.dart';

class FutoshikiValidator extends PuzzleValidator<FutoshikiBoard> {
  const FutoshikiValidator();

  @override
  ValidationSummary validatePuzzle(FutoshikiBoard board) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    for (int row = 0; row < board.size; row++) {
      final Set<int> seen = <int>{};
      for (int col = 0; col < board.size; col++) {
        final int value = board.cellAt(row, col);
        if (value == 0) {
          continue;
        }
        if (!seen.add(value)) {
          issues.add('Duplicate value $value in row $row');
        }
      }
    }

    for (int col = 0; col < board.size; col++) {
      final Set<int> seen = <int>{};
      for (int row = 0; row < board.size; row++) {
        final int value = board.cellAt(row, col);
        if (value == 0) {
          continue;
        }
        if (!seen.add(value)) {
          issues.add('Duplicate value $value in column $col');
        }
      }
    }

    for (final FutoshikiInequality inequality in board.inequalities) {
      final int lesserValue = board.cells[inequality.lesser];
      final int greaterValue = board.cells[inequality.greater];
      if (lesserValue != 0 && greaterValue != 0 && lesserValue >= greaterValue) {
        issues.add('Inequality violated at ${inequality.lesser} < ${inequality.greater}');
      }
    }

    stopwatch.stop();
    if (issues.isEmpty) {
      return ValidationSummary.success(stopwatch.elapsed);
    }
    return ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  ValidationSummary validateSolution(
      FutoshikiBoard board, FutoshikiBoard solution) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    if (board.size != solution.size) {
      issues.add('Solution size mismatch');
    }

    final int size = board.size;
    for (int index = 0; index < board.cellCount; index++) {
      if (board.fixed[index] && board.cells[index] != solution.cells[index]) {
        issues.add('Solution differs from fixed cell at index $index');
      }
    }

    for (int row = 0; row < size; row++) {
      final Set<int> seen = <int>{};
      for (int col = 0; col < size; col++) {
        final int value = solution.cellAt(row, col);
        if (value < 1 || value > size) {
          issues.add('Invalid value $value at row $row column $col');
        }
        if (!seen.add(value)) {
          issues.add('Duplicate value $value in solution row $row');
        }
      }
      if (seen.length != size) {
        issues.add('Row $row missing values');
      }
    }

    for (int col = 0; col < size; col++) {
      final Set<int> seen = <int>{};
      for (int row = 0; row < size; row++) {
        final int value = solution.cellAt(row, col);
        if (!seen.add(value)) {
          issues.add('Duplicate value $value in solution column $col');
        }
      }
      if (seen.length != size) {
        issues.add('Column $col missing values');
      }
    }

    for (final FutoshikiInequality inequality in board.inequalities) {
      final int lesserValue = solution.cells[inequality.lesser];
      final int greaterValue = solution.cells[inequality.greater];
      if (lesserValue >= greaterValue) {
        issues.add(
            'Solution violates inequality at ${inequality.lesser} < ${inequality.greater}');
      }
    }

    stopwatch.stop();
    if (issues.isEmpty) {
      return ValidationSummary.success(stopwatch.elapsed);
    }
    return ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  bool isSolved(FutoshikiBoard board) {
    if (!board.isComplete) {
      return false;
    }
    final int size = board.size;
    for (int row = 0; row < size; row++) {
      final Set<int> seen = <int>{};
      for (int col = 0; col < size; col++) {
        final int value = board.cellAt(row, col);
        if (!seen.add(value)) {
          return false;
        }
      }
      if (seen.length != size) {
        return false;
      }
    }
    for (int col = 0; col < size; col++) {
      final Set<int> seen = <int>{};
      for (int row = 0; row < size; row++) {
        final int value = board.cellAt(row, col);
        if (!seen.add(value)) {
          return false;
        }
      }
      if (seen.length != size) {
        return false;
      }
    }
    for (final FutoshikiInequality inequality in board.inequalities) {
      final int lesserValue = board.cells[inequality.lesser];
      final int greaterValue = board.cells[inequality.greater];
      if (lesserValue >= greaterValue) {
        return false;
      }
    }
    return true;
  }
}
