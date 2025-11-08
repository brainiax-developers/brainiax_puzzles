import '../validation/validator.dart';
import 'killer_queens_board.dart';

class KillerQueensValidator extends PuzzleValidator<KillerQueensBoard> {
  const KillerQueensValidator();

  @override
  ValidationSummary validatePuzzle(KillerQueensBoard board) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    _validateCommon(board, issues, enforceSolved: false);

    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  ValidationSummary validateSolution(
    KillerQueensBoard puzzle,
    KillerQueensBoard solution,
  ) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    if (puzzle.size != solution.size) {
      issues.add('size_mismatch');
    }
    if (!_listEquals(puzzle.blocked, solution.blocked)) {
      issues.add('blocked_mismatch');
    }
    if (!_listEquals(puzzle.cageByCell, solution.cageByCell)) {
      issues.add('cages_mismatch');
    }

    for (int i = 0; i < puzzle.cellCount; i++) {
      if (puzzle.blocked[i] && solution.cells[i] != 0) {
        issues.add('blocked_cell_nonzero');
        break;
      }
      if (puzzle.fixed[i] && solution.cells[i] != 1) {
        issues.add('given_not_preserved');
        break;
      }
    }

    _validateCommon(solution, issues, enforceSolved: true);

    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  bool isSolved(KillerQueensBoard board) {
    final List<String> issues = <String>[];
    _validateCommon(board, issues, enforceSolved: true);
    return issues.isEmpty;
  }

  void _validateCommon(
    KillerQueensBoard board,
    List<String> issues, {
    required bool enforceSolved,
  }) {
    final int size = board.size;
    final List<int> rowCounts = List<int>.filled(size, 0);
    final List<int> colCounts = List<int>.filled(size, 0);
    final List<int> cageCounts = List<int>.filled(board.cages.length, 0);
    final List<int> queenIndices = <int>[];

    for (int index = 0; index < board.cellCount; index++) {
      if (board.blocked[index]) {
        if (board.cells[index] != 0) {
          issues.add('blocked_cell_with_value');
          return;
        }
        continue;
      }
      final int value = board.cells[index];
      if (value != 0 && value != 1) {
        issues.add('invalid_value');
        return;
      }
      if (value == 1) {
        final int row = index ~/ size;
        final int col = index % size;
        rowCounts[row] += 1;
        colCounts[col] += 1;
        final int cageIndex = board.cageByCell[index];
        if (cageIndex >= 0) {
          cageCounts[cageIndex] += 1;
          if (cageCounts[cageIndex] > 1) {
            issues.add('cage_multiple_queens');
            return;
          }
        }
        queenIndices.add(index);
      }
    }

    if (enforceSolved) {
      for (int i = 0; i < size; i++) {
        if (rowCounts[i] != 1 || colCounts[i] != 1) {
          issues.add('row_col_queen_count');
          return;
        }
      }
      if (queenIndices.length != size) {
        issues.add('queen_total_mismatch');
        return;
      }
      for (int i = 0; i < queenIndices.length; i++) {
        final int index = queenIndices[i];
        final int row = index ~/ size;
        final int col = index % size;
        for (int j = i + 1; j < queenIndices.length; j++) {
          final int other = queenIndices[j];
          final int or = other ~/ size;
          final int oc = other % size;
          final int dr = (row - or).abs();
          final int dc = (col - oc).abs();
          if (dr <= 1 && dc <= 1) {
            issues.add('no_touch_violation');
            return;
          }
        }
      }
    } else {
      for (int r = 0; r < size; r++) {
        if (rowCounts[r] > 1) {
          issues.add('row_multiple_queens');
          return;
        }
        if (colCounts[r] > 1) {
          issues.add('column_multiple_queens');
          return;
        }
      }
      for (int i = 0; i < queenIndices.length; i++) {
        final int index = queenIndices[i];
        final int row = index ~/ size;
        final int col = index % size;
        for (int j = i + 1; j < queenIndices.length; j++) {
          final int other = queenIndices[j];
          final int or = other ~/ size;
          final int oc = other % size;
          final int dr = (row - or).abs();
          final int dc = (col - oc).abs();
          if (dr <= 1 && dc <= 1) {
            issues.add('no_touch_violation');
            return;
          }
        }
      }
    }
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
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
}
