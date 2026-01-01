import '../util/nonogram.dart';
import '../validation/validator.dart';
import 'nonogram_board.dart';

class NonogramValidator extends PuzzleValidator<NonogramBoard> {
  const NonogramValidator();

  @override
  ValidationSummary validatePuzzle(NonogramBoard board) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    if (board.rowClues.length != board.height) {
      issues.add('row_count_mismatch');
    }
    if (board.columnClues.length != board.width) {
      issues.add('column_count_mismatch');
    }

    if (board.cells.length != board.cellCount) {
      issues.add('cell_count_mismatch');
    }

    for (final List<int> rowClue in board.rowClues) {
      if (rowClue.any((int value) => value <= 0)) {
        issues.add('invalid_row_clue');
        break;
      }
    }
    for (final List<int> columnClue in board.columnClues) {
      if (columnClue.any((int value) => value <= 0)) {
        issues.add('invalid_column_clue');
        break;
      }
    }

    for (int i = 0; i < board.cells.length; i++) {
      final int? value = board.cells[i];
      if (value == null) {
        continue;
      }
      if (value != NonogramLineSolver.filled && value != NonogramLineSolver.empty) {
        issues.add('cell_out_of_range');
        break;
      }
    }

    if (issues.isEmpty && board.rowClues.length == board.height) {
      for (int row = 0; row < board.height; row++) {
        if (_minimumRequiredLength(board.rowClues[row]) > board.width) {
          issues.add('row_clues_overflow:$row');
          break;
        }
      }
    }

    if (issues.isEmpty && board.columnClues.length == board.width) {
      for (int col = 0; col < board.width; col++) {
        if (_minimumRequiredLength(board.columnClues[col]) > board.height) {
          issues.add('column_clues_overflow:$col');
          break;
        }
      }
    }

    if (issues.isEmpty) {
      for (int row = 0; row < board.height; row++) {
        final List<int?> values = board.rowValues(row);
        final NonogramPropagationResult propagation =
            NonogramLineSolver.propagate(values, board.rowClues[row]);
        if (propagation.contradiction) {
          issues.add('row_contradiction:$row');
          break;
        }
      }
    }

    if (issues.isEmpty) {
      for (int col = 0; col < board.width; col++) {
        final List<int?> values = board.columnValues(col);
        final NonogramPropagationResult propagation =
            NonogramLineSolver.propagate(values, board.columnClues[col]);
        if (propagation.contradiction) {
          issues.add('column_contradiction:$col');
          break;
        }
      }
    }

    stopwatch.stop();
    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  ValidationSummary validateSolution(NonogramBoard board, NonogramBoard solution) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    if (solution.width != board.width || solution.height != board.height) {
      issues.add('dimension_mismatch');
    }

    if (solution.cells.length != solution.cellCount) {
      issues.add('cell_count_mismatch');
    }

    if (issues.isEmpty) {
      for (int i = 0; i < solution.cells.length; i++) {
        final int? value = solution.cells[i];
        if (value != NonogramLineSolver.filled && value != NonogramLineSolver.empty) {
          issues.add('solution_value_out_of_range:$i');
          break;
        }
      }
    }

    if (issues.isEmpty) {
      for (int row = 0; row < board.height; row++) {
        final List<int?> rowValues = solution.rowValues(row);
        final List<int> derived = _deriveClues(rowValues);
        if (!_cluesEqual(derived, board.rowClues[row])) {
          issues.add('row_mismatch:$row');
          break;
        }
      }
    }

    if (issues.isEmpty) {
      for (int col = 0; col < board.width; col++) {
        final List<int?> columnValues = solution.columnValues(col);
        final List<int> derived = _deriveClues(columnValues);
        if (!_cluesEqual(derived, board.columnClues[col])) {
          issues.add('column_mismatch:$col');
          break;
        }
      }
    }

    stopwatch.stop();
    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  bool isSolved(NonogramBoard board) {
    for (int row = 0; row < board.height; row++) {
      if (!_cluesEqual(_deriveClues(board.rowValues(row)), board.rowClues[row])) {
        return false;
      }
    }
    for (int col = 0; col < board.width; col++) {
      if (!_cluesEqual(_deriveClues(board.columnValues(col)), board.columnClues[col])) {
        return false;
      }
    }
    return true;
  }

  List<int> _deriveClues(List<int?> values) {
    final List<int> clues = <int>[];
    int runLength = 0;
    for (final int? value in values) {
      if (value == NonogramLineSolver.filled) {
        runLength++;
      } else {
        if (runLength > 0) {
          clues.add(runLength);
          runLength = 0;
        }
      }
    }
    if (runLength > 0) {
      clues.add(runLength);
    }
    return clues;
  }

  bool _cluesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  int _minimumRequiredLength(List<int> clues) {
    if (clues.isEmpty) {
      return 0;
    }
    int total = 0;
    for (final int clue in clues) {
      total += clue;
    }
    return total + clues.length - 1;
  }
}
