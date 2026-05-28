import '../validation/validator.dart';
import 'mathdoku_board.dart';
import 'mathdoku_logic.dart';

class MathdokuValidator extends PuzzleValidator<MathdokuBoard> {
  const MathdokuValidator();

  @override
  ValidationSummary validatePuzzle(MathdokuBoard board) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    if (board.size <= 0) {
      issues.add('invalid_size');
    }

    issues.addAll(_checkLatinConstraints(board));
    issues.addAll(_checkCages(board, strict: false));

    stopwatch.stop();
    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  ValidationSummary validateSolution(
    MathdokuBoard puzzle,
    MathdokuBoard solution,
  ) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    if (puzzle.size != solution.size) {
      issues.add('size_mismatch');
    }
    if (puzzle.cages.length != solution.cages.length) {
      issues.add('cage_mismatch');
    }

    issues.addAll(_checkLatinConstraints(solution, requireFilled: true));
    issues.addAll(_checkCages(solution, strict: true));

    stopwatch.stop();
    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  bool isSolved(MathdokuBoard board) {
    if (!board.isComplete) {
      return false;
    }
    if (_hasLatinConflict(board)) {
      return false;
    }
    return _checkCages(board, strict: true).isEmpty;
  }

  List<String> _checkLatinConstraints(
    MathdokuBoard board, {
    bool requireFilled = false,
  }) {
    final List<String> issues = <String>[];
    final int size = board.size;
    for (int row = 0; row < size; row++) {
      final Set<int> seen = <int>{};
      for (final int index in board.rowIndices(row)) {
        final int value = board.cells[index];
        if (value == 0) {
          if (requireFilled) {
            issues.add('row_${row}_incomplete');
          }
          continue;
        }
        if (value < 0 || value > size) {
          issues.add('row_${row}_out_of_range');
          continue;
        }
        if (!seen.add(value)) {
          issues.add('row_${row}_duplicate_$value');
        }
      }
    }

    for (int col = 0; col < size; col++) {
      final Set<int> seen = <int>{};
      for (final int index in board.columnIndices(col)) {
        final int value = board.cells[index];
        if (value == 0) {
          if (requireFilled) {
            issues.add('col_${col}_incomplete');
          }
          continue;
        }
        if (value < 0 || value > size) {
          issues.add('col_${col}_out_of_range');
          continue;
        }
        if (!seen.add(value)) {
          issues.add('col_${col}_duplicate_$value');
        }
      }
    }

    return issues;
  }

  bool _hasLatinConflict(MathdokuBoard board) {
    final int size = board.size;
    for (int row = 0; row < size; row++) {
      final Set<int> seen = <int>{};
      for (final int index in board.rowIndices(row)) {
        final int value = board.cells[index];
        if (value == 0 || !seen.add(value)) {
          return true;
        }
      }
    }
    for (int col = 0; col < size; col++) {
      final Set<int> seen = <int>{};
      for (final int index in board.columnIndices(col)) {
        final int value = board.cells[index];
        if (value == 0 || !seen.add(value)) {
          return true;
        }
      }
    }
    return false;
  }

  List<String> _checkCages(MathdokuBoard board, {required bool strict}) {
    final List<String> issues = <String>[];
    final Set<int> seenCageIds = <int>{};

    for (final MathdokuCage cage in board.cages) {
      if (!seenCageIds.add(cage.id)) {
        issues.add('duplicate_cage_id_${cage.id}');
      }
      if (!_isOrthogonallyConnected(cage.cells, board.size)) {
        issues.add('cage_${cage.id}_disconnected');
      }
      if (cage.operation == MathdokuOperation.equality &&
          cage.cells.length != 1) {
        issues.add('cage_${cage.id}_invalid_equality');
      }
      if (cage.operation == MathdokuOperation.subtraction &&
          cage.cells.length != 2) {
        issues.add('cage_${cage.id}_invalid_subtract_size');
      }
      if (cage.operation == MathdokuOperation.division &&
          cage.cells.length != 2) {
        issues.add('cage_${cage.id}_invalid_divide_size');
      }
      if (cage.target <= 0) {
        issues.add('cage_${cage.id}_target_non_positive');
      } else if (!_isTargetPlausible(cage, board.size)) {
        issues.add('cage_${cage.id}_target_out_of_range');
      }
      final List<int> values = cage.cells
          .map((int index) => board.cells[index])
          .toList(growable: false);
      if (values.any((int value) => value < 0 || value > board.size)) {
        issues.add('cage_${cage.id}_value_out_of_range');
        continue;
      }
      if (strict) {
        if (values.contains(0)) {
          issues.add('cage_${cage.id}_incomplete');
          continue;
        }
        if (!mathdokuMatches(cage.operation, cage.target, values)) {
          issues.add('cage_${cage.id}_mismatch');
        }
      } else {
        if (cage.operation == MathdokuOperation.equality) {
          if (values.first != 0 && values.first != cage.target) {
            issues.add('cage_${cage.id}_conflict');
          }
        }
      }
    }
    return issues;
  }

  bool _isTargetPlausible(MathdokuCage cage, int size) {
    switch (cage.operation) {
      case MathdokuOperation.equality:
        return cage.target >= 1 && cage.target <= size;
      case MathdokuOperation.addition:
        final int min = cage.cells.length;
        final int max = cage.cells.length * size;
        return cage.target >= min && cage.target <= max;
      case MathdokuOperation.multiplication:
        final int max = _powInt(size, cage.cells.length);
        return cage.target >= 1 && cage.target <= max;
      case MathdokuOperation.subtraction:
        return cage.target >= 1 && cage.target <= size - 1;
      case MathdokuOperation.division:
        return cage.target >= 1 && cage.target <= size;
    }
  }

  int _powInt(int base, int exponent) {
    int result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  bool _isOrthogonallyConnected(List<int> cells, int size) {
    if (cells.length <= 1) {
      return true;
    }

    final Set<int> cellSet = cells.toSet();
    final Set<int> visited = <int>{};
    final List<int> stack = <int>[cells.first];

    while (stack.isNotEmpty) {
      final int index = stack.removeLast();
      if (!visited.add(index)) {
        continue;
      }

      final int row = index ~/ size;
      final int col = index % size;
      final List<int> neighbours = <int>[
        if (row > 0) index - size,
        if (row < size - 1) index + size,
        if (col > 0) index - 1,
        if (col < size - 1) index + 1,
      ];
      for (final int neighbour in neighbours) {
        if (cellSet.contains(neighbour) && !visited.contains(neighbour)) {
          stack.add(neighbour);
        }
      }
    }

    return visited.length == cellSet.length;
  }
}
