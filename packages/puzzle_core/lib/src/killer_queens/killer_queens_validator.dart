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
    if (!_listEquals(puzzle.cageByCell, solution.cageByCell)) {
      issues.add('cages_mismatch');
    }

    for (int i = 0; i < puzzle.cellCount; i++) {
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
    _validateDefinition(board, issues);
    _validateQueenPlacement(board, issues, enforceSolved: enforceSolved);
  }

  void _validateDefinition(KillerQueensBoard board, List<String> issues) {
    final int size = board.size;
    final int cellCount = board.cellCount;

    if (board.cages.length != size) {
      issues.add('region_count_mismatch');
    }

    final List<int> assignmentCounts = List<int>.filled(cellCount, 0);
    for (int regionIndex = 0; regionIndex < board.cages.length; regionIndex++) {
      final KillerQueensCage region = board.cages[regionIndex];
      if (region.cells.isEmpty) {
        issues.add('region_empty:$regionIndex');
        continue;
      }

      final List<int> validCells = <int>[];
      for (final int cell in region.cells) {
        if (cell < 0 || cell >= cellCount) {
          issues.add('region_cell_out_of_range:$regionIndex:$cell');
          continue;
        }
        assignmentCounts[cell] += 1;
        if (assignmentCounts[cell] == 2) {
          issues.add('cell_multiple_regions:$cell');
        }
        validCells.add(cell);
      }

      if (validCells.isNotEmpty &&
          !_isOrthogonallyConnected(validCells, size)) {
        issues.add('region_disconnected:$regionIndex');
      }
    }

    for (int index = 0; index < assignmentCounts.length; index++) {
      if (assignmentCounts[index] == 0) {
        issues.add('cell_missing_region:$index');
      }
    }
  }

  void _validateQueenPlacement(
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
      final int value = board.cells[index];
      if (value != 0 && value != 1 && value != 2) {
        issues.add('invalid_value');
        return;
      }
      if (value == 1) {
        final int row = index ~/ size;
        final int col = index % size;
        rowCounts[row] += 1;
        colCounts[col] += 1;
        final int cageIndex = board.cageByCell[index];
        if (cageIndex >= 0 && cageIndex < cageCounts.length) {
          cageCounts[cageIndex] += 1;
        }
        queenIndices.add(index);
      }
    }

    if (enforceSolved) {
      for (int i = 0; i < size; i++) {
        if (rowCounts[i] != 1) {
          issues.add('row_queen_count:$i');
        }
        if (colCounts[i] != 1) {
          issues.add('column_queen_count:$i');
        }
      }
      for (int i = 0; i < cageCounts.length; i++) {
        if (cageCounts[i] != 1) {
          issues.add('region_queen_count:$i');
        }
      }
      if (queenIndices.length != size) {
        issues.add('queen_total_mismatch');
      }
    } else {
      for (int r = 0; r < size; r++) {
        if (rowCounts[r] > 1) {
          issues.add('row_multiple_queens:$r');
        }
        if (colCounts[r] > 1) {
          issues.add('column_multiple_queens:$r');
        }
      }
    }

    for (int i = 0; i < cageCounts.length; i++) {
      if (cageCounts[i] > 1) {
        issues.add('region_multiple_queens:$i');
      }
    }
    _validateNoTouch(queenIndices, size, issues);
  }

  void _validateNoTouch(List<int> queenIndices, int size, List<String> issues) {
    for (int i = 0; i < queenIndices.length; i++) {
      final int index = queenIndices[i];
      final int row = index ~/ size;
      final int col = index % size;
      for (int j = i + 1; j < queenIndices.length; j++) {
        final int other = queenIndices[j];
        final int otherRow = other ~/ size;
        final int otherCol = other % size;
        final int dr = (row - otherRow).abs();
        final int dc = (col - otherCol).abs();
        if (dr <= 1 && dc <= 1) {
          issues.add('no_touch_violation');
          return;
        }
      }
    }
  }

  bool _isOrthogonallyConnected(List<int> cells, int size) {
    final Set<int> cellSet = cells.toSet();
    if (cellSet.length <= 1) {
      return true;
    }

    final Set<int> visited = <int>{};
    final List<int> stack = <int>[cellSet.first];
    while (stack.isNotEmpty) {
      final int index = stack.removeLast();
      if (!visited.add(index)) {
        continue;
      }

      final int row = index ~/ size;
      final int col = index % size;
      final List<int> neighbors = <int>[
        if (row > 0) index - size,
        if (row < size - 1) index + size,
        if (col > 0) index - 1,
        if (col < size - 1) index + 1,
      ];
      for (final int neighbor in neighbors) {
        if (cellSet.contains(neighbor) && !visited.contains(neighbor)) {
          stack.add(neighbor);
        }
      }
    }

    return visited.length == cellSet.length;
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
