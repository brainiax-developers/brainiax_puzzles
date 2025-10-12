import '../solver/solver.dart';
import 'mathdoku_board.dart';
import 'mathdoku_logic.dart';

class MathdokuSolver extends PuzzleSolver<MathdokuBoard> {
  const MathdokuSolver();

  @override
  SolverResult<MathdokuBoard> solve(MathdokuBoard board, SolverContext context) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final _SearchState search = _SearchState(board, context.maxSolutions);
    final List<List<int>> solutionCells = search.solve();
    stopwatch.stop();

    final List<MathdokuBoard> solutions = solutionCells
        .map((List<int> cells) => MathdokuBoard(
              size: board.size,
              cells: cells,
              cages: board.cages,
            ))
        .toList(growable: false);

    final Map<String, Object?> telemetry = <String, Object?>{
      'searchNodes': search.searchNodes,
      'searchDepth': search.maxDepth,
      'propagationDepth': search.maxPropagationDepth,
      'branchDecisions': search.branchDecisions,
    };

    return SolverResult<MathdokuBoard>(
      solutions: solutions,
      elapsed: stopwatch.elapsed,
      telemetry: telemetry,
    );
  }
}

class _SearchState {
  _SearchState(MathdokuBoard board, this.maxSolutions)
      : size = board.size,
        cellCount = board.cellCount,
        assignments = List<int>.from(board.cells),
        domains = List<int>.filled(board.cellCount, 0),
        rowMask = List<int>.filled(board.size, 0),
        colMask = List<int>.filled(board.size, 0),
        cages = board.cages,
        cageCombos = List<List<List<int>>>.generate(
          board.cages.length,
          (int index) => _generateCombos(board.cages[index], board.size),
          growable: false,
        );

  final int size;
  final int cellCount;
  final int maxSolutions;
  final List<int> assignments;
  final List<int> domains;
  final List<int> rowMask;
  final List<int> colMask;
  final List<MathdokuCage> cages;
  final List<List<List<int>>> cageCombos;

  final List<List<int>> _solutions = <List<int>>[];

  int searchNodes = 0;
  int maxDepth = 0;
  int maxPropagationDepth = 0;
  int branchDecisions = 0;
  bool _unsatisfiable = false;

  static int _allMask(int size) => (1 << size) - 1;
  static int _bitFor(int value) => 1 << (value - 1);

  List<List<int>> solve() {
    _initialise();
    if (_unsatisfiable) {
      return _solutions;
    }
    _search(0);
    return _solutions;
  }

  void _initialise() {
    final int allMask = _allMask(size);
    for (int index = 0; index < cellCount; index++) {
      final int value = assignments[index];
      if (value == 0) {
        domains[index] = allMask;
        continue;
      }
      if (value < 0 || value > size) {
        _unsatisfiable = true;
        return;
      }
      final int mask = _bitFor(value);
      final int row = index ~/ size;
      final int col = index % size;
      if ((rowMask[row] & mask) != 0 || (colMask[col] & mask) != 0) {
        _unsatisfiable = true;
        return;
      }
      rowMask[row] |= mask;
      colMask[col] |= mask;
      domains[index] = mask;
    }
    final int propagation = _propagate();
    if (propagation < 0) {
      _unsatisfiable = true;
    } else {
      maxPropagationDepth = propagation;
    }
  }

  void _search(int depth) {
    if (_unsatisfiable || _solutions.length >= maxSolutions) {
      return;
    }
    maxDepth = depth > maxDepth ? depth : maxDepth;

    final int cell = _selectCell();
    if (cell == -1) {
      _solutions.add(List<int>.from(assignments));
      return;
    }

    final List<int> values = _domainValues(domains[cell]);
    if (values.isEmpty) {
      return;
    }
    branchDecisions += values.length > 1 ? 1 : 0;

    for (final int value in values) {
      if (_solutions.length >= maxSolutions) {
        break;
      }
      final _Snapshot snapshot = _Snapshot.capture(assignments, domains, rowMask, colMask);
      searchNodes++;
      final bool success = _applyAssignment(cell, value);
      if (success) {
        _search(depth + 1);
      }
      snapshot.restore(assignments, domains, rowMask, colMask);
    }
  }

  bool _applyAssignment(int cell, int value) {
    final int mask = _bitFor(value);
    final int row = cell ~/ size;
    final int col = cell % size;
    if ((rowMask[row] & mask) != 0 || (colMask[col] & mask) != 0) {
      return false;
    }

    assignments[cell] = value;
    domains[cell] = mask;
    rowMask[row] |= mask;
    colMask[col] |= mask;

    final int propagation = _propagate();
    if (propagation < 0) {
      return false;
    }
    if (propagation > maxPropagationDepth) {
      maxPropagationDepth = propagation;
    }
    return true;
  }

  int _selectCell() {
    int bestIndex = -1;
    int bestOptions = size + 1;
    for (int index = 0; index < cellCount; index++) {
      if (assignments[index] != 0) {
        continue;
      }
      final int options = _countBits(domains[index]);
      if (options == 0) {
        return index;
      }
      if (options < bestOptions) {
        bestOptions = options;
        bestIndex = index;
        if (options == 1) {
          break;
        }
      }
    }
    return bestIndex;
  }

  int _propagate() {
    final int allMask = _allMask(size);
    bool changed = true;
    int iterations = 0;

    while (changed) {
      iterations++;
      changed = false;

      for (int index = 0; index < cellCount; index++) {
        if (assignments[index] != 0) {
          continue;
        }
        final int row = index ~/ size;
        final int col = index % size;
        final int allowed = domains[index] & ~rowMask[row] & ~colMask[col] & allMask;
        if (allowed == 0) {
          return -1;
        }
        if (allowed != domains[index]) {
          domains[index] = allowed;
          changed = true;
        }
      }

      for (int cageIndex = 0; cageIndex < cages.length; cageIndex++) {
        final MathdokuCage cage = cages[cageIndex];
        final List<int> allowedMasks = List<int>.filled(cage.cells.length, 0);
        for (final List<int> combo in cageCombos[cageIndex]) {
          bool fits = true;
          for (int i = 0; i < cage.cells.length; i++) {
            final int cell = cage.cells[i];
            final int value = combo[i];
            final int mask = _bitFor(value);
            if (assignments[cell] != 0) {
              if (assignments[cell] != value) {
                fits = false;
                break;
              }
              continue;
            }
            final int row = cell ~/ size;
            final int col = cell % size;
            if ((rowMask[row] & mask) != 0 || (colMask[col] & mask) != 0) {
              fits = false;
              break;
            }
            if ((domains[cell] & mask) == 0) {
              fits = false;
              break;
            }
          }
          if (!fits) {
            continue;
          }
          for (int i = 0; i < cage.cells.length; i++) {
            allowedMasks[i] |= _bitFor(combo[i]);
          }
        }
        for (int i = 0; i < cage.cells.length; i++) {
          final int cell = cage.cells[i];
          if (assignments[cell] != 0) {
            continue;
          }
          final int newMask = domains[cell] & allowedMasks[i];
          if (newMask == 0) {
            return -1;
          }
          if (newMask != domains[cell]) {
            domains[cell] = newMask;
            changed = true;
          }
        }
      }
    }

    return iterations;
  }

  static int _countBits(int mask) {
    int count = 0;
    int value = mask;
    while (value != 0) {
      value &= value - 1;
      count++;
    }
    return count;
  }

  List<int> _domainValues(int mask) {
    final List<int> values = <int>[];
    int remaining = mask;
    while (remaining != 0) {
      final int bit = remaining & -remaining;
      values.add(_maskToDigit(bit));
      remaining ^= bit;
    }
    return values;
  }

  int _maskToDigit(int mask) {
    int digit = 1;
    int value = mask;
    while (value > 1) {
      value >>= 1;
      digit++;
    }
    return digit;
  }

  static List<List<int>> _generateCombos(MathdokuCage cage, int maxDigit) {
    if (cage.operation == MathdokuOperation.equality) {
      return <List<int>>[
        <int>[cage.target],
      ];
    }
    final int length = cage.cells.length;
    final List<List<int>> combos = <List<int>>[];
    final List<int> current = List<int>.filled(length, 0);

    void backtrack(int depth) {
      if (depth == length) {
        if (mathdokuMatches(cage.operation, cage.target, current)) {
          combos.add(List<int>.from(current));
        }
        return;
      }
      for (int value = 1; value <= maxDigit; value++) {
        current[depth] = value;
        if (_partialFeasible(cage, current, depth + 1, maxDigit)) {
          backtrack(depth + 1);
        }
      }
    }

    backtrack(0);
    return combos;
  }

  static bool _partialFeasible(
    MathdokuCage cage,
    List<int> current,
    int depth,
    int maxDigit,
  ) {
    switch (cage.operation) {
      case MathdokuOperation.equality:
        return depth == 1 ? current[0] == cage.target : false;
      case MathdokuOperation.addition:
        int sum = 0;
        for (int i = 0; i < depth; i++) {
          sum += current[i];
        }
        if (sum > cage.target) {
          return false;
        }
        final int remaining = cage.cells.length - depth;
        final int maxPossible = sum + remaining * maxDigit;
        return maxPossible >= cage.target;
      case MathdokuOperation.multiplication:
        int product = 1;
        for (int i = 0; i < depth; i++) {
          product *= current[i];
          if (product > cage.target) {
            return false;
          }
        }
        if (cage.target % product != 0) {
          return false;
        }
        final int remaining = cage.cells.length - depth;
        int maxProduct = product;
        for (int i = 0; i < remaining; i++) {
          maxProduct *= maxDigit;
          if (maxProduct > cage.target) {
            break;
          }
        }
        return maxProduct >= cage.target;
      case MathdokuOperation.subtraction:
      case MathdokuOperation.division:
        return true;
    }
  }
}

class _Snapshot {
  _Snapshot._(this.assignments, this.domains, this.rowMask, this.colMask);

  final List<int> assignments;
  final List<int> domains;
  final List<int> rowMask;
  final List<int> colMask;

  factory _Snapshot.capture(
    List<int> assignments,
    List<int> domains,
    List<int> rowMask,
    List<int> colMask,
  ) {
    return _Snapshot._(
      List<int>.from(assignments),
      List<int>.from(domains),
      List<int>.from(rowMask),
      List<int>.from(colMask),
    );
  }

  void restore(
    List<int> assignments,
    List<int> domains,
    List<int> rowMask,
    List<int> colMask,
  ) {
    for (int i = 0; i < assignments.length; i++) {
      assignments[i] = this.assignments[i];
      domains[i] = this.domains[i];
    }
    for (int i = 0; i < rowMask.length; i++) {
      rowMask[i] = this.rowMask[i];
      colMask[i] = this.colMask[i];
    }
  }
}
