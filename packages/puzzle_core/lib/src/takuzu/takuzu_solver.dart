import '../solver/solver.dart';
import '../util/seeded_rng.dart';
import 'takuzu_board.dart';

class TakuzuSolver extends PuzzleSolver<TakuzuBoard> {
  const TakuzuSolver();

  @override
  SolverResult<TakuzuBoard> solve(TakuzuBoard board, SolverContext context) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final _TakuzuSearch search =
        _TakuzuSearch(board, context.rng, context.maxSolutions);
    search.solve();
    stopwatch.stop();
    return SolverResult<TakuzuBoard>(
      solutions: search.solutions,
      elapsed: stopwatch.elapsed,
      telemetry: search.telemetry,
    );
  }
}

class _TakuzuSearch {
  _TakuzuSearch(this.board, this.rng, this.maxSolutions)
      : size = board.size,
        limit = board.size ~/ 2,
        cells = List<int>.from(board.cells);

  final TakuzuBoard board;
  final SeededRng rng;
  final int maxSolutions;
  final int size;
  final int limit;
  final List<int> cells;

  final List<TakuzuBoard> solutions = <TakuzuBoard>[];

  int forcedAssignments = 0;
  int totalAssignments = 0;
  int guesses = 0;
  int adjacencySteps = 0;
  int paritySteps = 0;
  int uniquenessSteps = 0;
  int mirrorSteps = 0;
  int longestChain = 0;
  int _currentChain = 0;

  Map<String, Object?> get telemetry => <String, Object?>{
        'forcedAssignments': forcedAssignments,
        'totalAssignments': totalAssignments,
        'guesses': guesses,
        'adjacencySteps': adjacencySteps,
        'paritySteps': paritySteps,
        'uniquenessSteps': uniquenessSteps,
        'mirrorSteps': mirrorSteps,
        'longestChain': longestChain,
      };

  void solve() {
    _search(List<int>.from(cells));
  }

  void _search(List<int> state) {
    if (solutions.length >= maxSolutions) {
      return;
    }

    final _LogicResult logic = _applyLogic(state);
    if (logic.contradiction) {
      return;
    }

    if (logic.assignments > 0) {
      _currentChain += logic.assignments;
      if (_currentChain > longestChain) {
        longestChain = _currentChain;
      }
    }

    if (_isSolved(state)) {
      final TakuzuBoard solved = TakuzuBoard(
        size: size,
        cells: state,
        fixed: board.fixed,
      );
      solutions.add(solved);
      return;
    }

    final int guessIndex = _selectGuessCell(state);
    if (guessIndex < 0) {
      return;
    }

    guesses++;
    _currentChain = 0;

    final List<int> order = <int>[0, 1];
    // Deterministic but stable random tie-breaking for variety.
    if (rng.nextIntInRange(2) == 1) {
      order.swap(0, 1);
    }

    for (final int value in order) {
      final List<int> next = List<int>.from(state);
      next[guessIndex] = value;
      totalAssignments++;
      _search(next);
      if (solutions.length >= maxSolutions) {
        return;
      }
    }
  }

  _LogicResult _applyLogic(List<int> state) {
    bool contradiction = false;
    int assignments = 0;
    bool progress = true;
    while (progress && !contradiction) {
      progress = false;

      final _RuleResult adjacency = _applyAdjacency(state);
      if (adjacency.contradiction) {
        contradiction = true;
        break;
      }
      if (adjacency.assignments > 0) {
        adjacencySteps++;
        assignments += adjacency.assignments;
        forcedAssignments += adjacency.assignments;
        totalAssignments += adjacency.assignments;
        progress = true;
      }

      final _RuleResult parity = _applyParity(state);
      if (parity.contradiction) {
        contradiction = true;
        break;
      }
      if (parity.assignments > 0) {
        paritySteps++;
        assignments += parity.assignments;
        forcedAssignments += parity.assignments;
        totalAssignments += parity.assignments;
        progress = true;
      }

      final _RuleResult uniqueness = _applyUniqueness(state);
      if (uniqueness.contradiction) {
        contradiction = true;
        break;
      }
      if (uniqueness.assignments > 0) {
        uniquenessSteps++;
        assignments += uniqueness.assignments;
        forcedAssignments += uniqueness.assignments;
        totalAssignments += uniqueness.assignments;
        progress = true;
      }

      final _RuleResult mirror = _applyMirror(state);
      if (mirror.contradiction) {
        contradiction = true;
        break;
      }
      if (mirror.assignments > 0) {
        mirrorSteps++;
        assignments += mirror.assignments;
        forcedAssignments += mirror.assignments;
        totalAssignments += mirror.assignments;
        progress = true;
      }
    }

    return _LogicResult(assignments: assignments, contradiction: contradiction);
  }

  bool _isSolved(List<int> state) => !state.contains(TakuzuBoard.emptyValue);

  int _selectGuessCell(List<int> state) {
    int bestIndex = -1;
    int bestScore = 3;
    for (int index = 0; index < state.length; index++) {
      if (state[index] != TakuzuBoard.emptyValue) {
        continue;
      }
      final int row = index ~/ size;
      final int col = index % size;
      final int zeroCountRow = _countValueInRow(state, row, 0);
      final int oneCountRow = _countValueInRow(state, row, 1);
      final int zeroCountCol = _countValueInCol(state, col, 0);
      final int oneCountCol = _countValueInCol(state, col, 1);
      int score = 0;
      if (zeroCountRow >= limit - 1 || oneCountRow >= limit - 1) {
        score++;
      }
      if (zeroCountCol >= limit - 1 || oneCountCol >= limit - 1) {
        score++;
      }
      if (score < bestScore) {
        bestScore = score;
        bestIndex = index;
        if (score == 0) {
          break;
        }
      }
    }
    return bestIndex;
  }

  int _countValueInRow(List<int> state, int row, int value) {
    int count = 0;
    for (int col = 0; col < size; col++) {
      if (state[row * size + col] == value) {
        count++;
      }
    }
    return count;
  }

  int _countValueInCol(List<int> state, int col, int value) {
    int count = 0;
    for (int row = 0; row < size; row++) {
      if (state[row * size + col] == value) {
        count++;
      }
    }
    return count;
  }

  _RuleResult _applyAdjacency(List<int> state) {
    int assignments = 0;

    for (int row = 0; row < size; row++) {
      for (int col = 0; col < size; col++) {
        final int index = row * size + col;
        if (state[index] == TakuzuBoard.emptyValue) {
          continue;
        }
        final int value = state[index];
        if (col >= 2) {
          final int left1 = state[row * size + col - 1];
          final int left2 = state[row * size + col - 2];
          if (left1 == value && left2 == value) {
            return const _RuleResult.contradiction();
          }
        }
        if (col <= size - 3) {
          final int right1 = state[row * size + col + 1];
          final int right2 = state[row * size + col + 2];
          if (right1 == value && right2 == value) {
            return const _RuleResult.contradiction();
          }
        }
      }

      for (int col = 0; col < size - 2; col++) {
        final int a = state[row * size + col];
        final int b = state[row * size + col + 1];
        final int c = state[row * size + col + 2];
        if (a != TakuzuBoard.emptyValue && a == b && c == TakuzuBoard.emptyValue) {
          final int forced = 1 - a;
          final int targetIndex = row * size + col + 2;
          if (state[targetIndex] == TakuzuBoard.emptyValue) {
            state[targetIndex] = forced;
            assignments++;
          } else if (state[targetIndex] != forced) {
            return const _RuleResult.contradiction();
          }
        }
        if (c != TakuzuBoard.emptyValue && b == c && a == TakuzuBoard.emptyValue) {
          final int forced = 1 - c;
          final int targetIndex = row * size + col;
          if (state[targetIndex] == TakuzuBoard.emptyValue) {
            state[targetIndex] = forced;
            assignments++;
          } else if (state[targetIndex] != forced) {
            return const _RuleResult.contradiction();
          }
        }
        if (a != TakuzuBoard.emptyValue && c != TakuzuBoard.emptyValue && b == TakuzuBoard.emptyValue && a == c) {
          final int forced = 1 - a;
          final int targetIndex = row * size + col + 1;
          if (state[targetIndex] == TakuzuBoard.emptyValue) {
            state[targetIndex] = forced;
            assignments++;
          } else if (state[targetIndex] != forced) {
            return const _RuleResult.contradiction();
          }
        }
      }
    }

    for (int col = 0; col < size; col++) {
      for (int row = 0; row < size; row++) {
        final int index = row * size + col;
        if (state[index] == TakuzuBoard.emptyValue) {
          continue;
        }
        final int value = state[index];
        if (row >= 2) {
          final int up1 = state[(row - 1) * size + col];
          final int up2 = state[(row - 2) * size + col];
          if (up1 == value && up2 == value) {
            return const _RuleResult.contradiction();
          }
        }
        if (row <= size - 3) {
          final int down1 = state[(row + 1) * size + col];
          final int down2 = state[(row + 2) * size + col];
          if (down1 == value && down2 == value) {
            return const _RuleResult.contradiction();
          }
        }
      }

      for (int row = 0; row < size - 2; row++) {
        final int a = state[row * size + col];
        final int b = state[(row + 1) * size + col];
        final int c = state[(row + 2) * size + col];
        if (a != TakuzuBoard.emptyValue && a == b && c == TakuzuBoard.emptyValue) {
          final int forced = 1 - a;
          final int targetIndex = (row + 2) * size + col;
          if (state[targetIndex] == TakuzuBoard.emptyValue) {
            state[targetIndex] = forced;
            assignments++;
          } else if (state[targetIndex] != forced) {
            return const _RuleResult.contradiction();
          }
        }
        if (c != TakuzuBoard.emptyValue && b == c && a == TakuzuBoard.emptyValue) {
          final int forced = 1 - c;
          final int targetIndex = row * size + col;
          if (state[targetIndex] == TakuzuBoard.emptyValue) {
            state[targetIndex] = forced;
            assignments++;
          } else if (state[targetIndex] != forced) {
            return const _RuleResult.contradiction();
          }
        }
        if (a != TakuzuBoard.emptyValue && c != TakuzuBoard.emptyValue && b == TakuzuBoard.emptyValue && a == c) {
          final int forced = 1 - a;
          final int targetIndex = (row + 1) * size + col;
          if (state[targetIndex] == TakuzuBoard.emptyValue) {
            state[targetIndex] = forced;
            assignments++;
          } else if (state[targetIndex] != forced) {
            return const _RuleResult.contradiction();
          }
        }
      }
    }

    return _RuleResult(assignments: assignments);
  }

  _RuleResult _applyParity(List<int> state) {
    int assignments = 0;

    for (int row = 0; row < size; row++) {
      int zeros = 0;
      int ones = 0;
      final List<int> empties = <int>[];
      for (int col = 0; col < size; col++) {
        final int value = state[row * size + col];
        if (value == 0) {
          zeros++;
        } else if (value == 1) {
          ones++;
        } else {
          empties.add(row * size + col);
        }
      }
      if (zeros > limit || ones > limit) {
        return const _RuleResult.contradiction();
      }
      if (zeros == limit && empties.isNotEmpty) {
        for (final int index in empties) {
          if (state[index] == TakuzuBoard.emptyValue) {
            state[index] = 1;
            assignments++;
          } else if (state[index] != 1) {
            return const _RuleResult.contradiction();
          }
        }
      } else if (ones == limit && empties.isNotEmpty) {
        for (final int index in empties) {
          if (state[index] == TakuzuBoard.emptyValue) {
            state[index] = 0;
            assignments++;
          } else if (state[index] != 0) {
            return const _RuleResult.contradiction();
          }
        }
      }
    }

    for (int col = 0; col < size; col++) {
      int zeros = 0;
      int ones = 0;
      final List<int> empties = <int>[];
      for (int row = 0; row < size; row++) {
        final int value = state[row * size + col];
        if (value == 0) {
          zeros++;
        } else if (value == 1) {
          ones++;
        } else {
          empties.add(row * size + col);
        }
      }
      if (zeros > limit || ones > limit) {
        return const _RuleResult.contradiction();
      }
      if (zeros == limit && empties.isNotEmpty) {
        for (final int index in empties) {
          if (state[index] == TakuzuBoard.emptyValue) {
            state[index] = 1;
            assignments++;
          } else if (state[index] != 1) {
            return const _RuleResult.contradiction();
          }
        }
      } else if (ones == limit && empties.isNotEmpty) {
        for (final int index in empties) {
          if (state[index] == TakuzuBoard.emptyValue) {
            state[index] = 0;
            assignments++;
          } else if (state[index] != 0) {
            return const _RuleResult.contradiction();
          }
        }
      }
    }

    return _RuleResult(assignments: assignments);
  }

  _RuleResult _applyUniqueness(List<int> state) {
    int assignments = 0;

    final Map<String, int> completedRows = <String, int>{};
    final List<int> incompleteRows = <int>[];
    for (int row = 0; row < size; row++) {
      final StringBuffer buffer = StringBuffer();
      bool complete = true;
      for (int col = 0; col < size; col++) {
        final int value = state[row * size + col];
        if (value == TakuzuBoard.emptyValue) {
          buffer.write('?');
          complete = false;
        } else {
          buffer.write(value);
        }
      }
      final String signature = buffer.toString();
      if (complete) {
        if (completedRows.containsKey(signature)) {
          return const _RuleResult.contradiction();
        }
        completedRows[signature] = row;
      } else {
        incompleteRows.add(row);
      }
    }

    for (final int row in incompleteRows) {
      final List<int> rowIndices = <int>[];
      for (int col = 0; col < size; col++) {
        if (state[row * size + col] == TakuzuBoard.emptyValue) {
          rowIndices.add(col);
        }
      }
      if (rowIndices.isEmpty) {
        continue;
      }
      for (final MapEntry<String, int> entry in completedRows.entries) {
        final String completed = entry.key;
        bool matches = true;
        for (int col = 0; col < size; col++) {
          final int value = state[row * size + col];
          final int completedValue = completed.codeUnitAt(col) - 48;
          if (value != TakuzuBoard.emptyValue && value != completedValue) {
            matches = false;
            break;
          }
        }
        if (matches) {
          for (final int col in rowIndices) {
            final int completedValue = completed.codeUnitAt(col) - 48;
            final int forced = 1 - completedValue;
            final int index = row * size + col;
            if (state[index] == TakuzuBoard.emptyValue) {
              state[index] = forced;
              assignments++;
            } else if (state[index] != forced) {
              return const _RuleResult.contradiction();
            }
          }
        }
      }
    }

    // Column uniqueness mirrored logic.
    final Map<String, int> completedCols = <String, int>{};
    final List<int> incompleteCols = <int>[];
    for (int col = 0; col < size; col++) {
      final StringBuffer buffer = StringBuffer();
      bool complete = true;
      for (int row = 0; row < size; row++) {
        final int value = state[row * size + col];
        if (value == TakuzuBoard.emptyValue) {
          buffer.write('?');
          complete = false;
        } else {
          buffer.write(value);
        }
      }
      final String signature = buffer.toString();
      if (complete) {
        if (completedCols.containsKey(signature)) {
          return const _RuleResult.contradiction();
        }
        completedCols[signature] = col;
      } else {
        incompleteCols.add(col);
      }
    }

    for (final int col in incompleteCols) {
      final List<int> colIndices = <int>[];
      for (int row = 0; row < size; row++) {
        if (state[row * size + col] == TakuzuBoard.emptyValue) {
          colIndices.add(row);
        }
      }
      if (colIndices.isEmpty) {
        continue;
      }
      for (final MapEntry<String, int> entry in completedCols.entries) {
        final String completed = entry.key;
        bool matches = true;
        for (int row = 0; row < size; row++) {
          final int value = state[row * size + col];
          final int completedValue = completed.codeUnitAt(row) - 48;
          if (value != TakuzuBoard.emptyValue && value != completedValue) {
            matches = false;
            break;
          }
        }
        if (matches) {
          for (final int rowIndex in colIndices) {
            final int completedValue = completed.codeUnitAt(rowIndex) - 48;
            final int forced = 1 - completedValue;
            final int index = rowIndex * size + col;
            if (state[index] == TakuzuBoard.emptyValue) {
              state[index] = forced;
              assignments++;
            } else if (state[index] != forced) {
              return const _RuleResult.contradiction();
            }
          }
        }
      }
    }

    return _RuleResult(assignments: assignments);
  }

  _RuleResult _applyMirror(List<int> state) {
    int assignments = 0;

    final Map<String, String> complements = <String, String>{};
    for (int row = 0; row < size; row++) {
      final StringBuffer buffer = StringBuffer();
      final StringBuffer inverse = StringBuffer();
      bool complete = true;
      for (int col = 0; col < size; col++) {
        final int value = state[row * size + col];
        if (value == TakuzuBoard.emptyValue) {
          buffer.write('?');
          inverse.write('?');
          complete = false;
        } else {
          buffer.write(value);
          inverse.write(1 - value);
        }
      }
      if (complete) {
        complements[buffer.toString()] = inverse.toString();
      }
    }

    for (int row = 0; row < size; row++) {
      final StringBuffer buffer = StringBuffer();
      final List<int> empties = <int>[];
      bool hasValue = false;
      for (int col = 0; col < size; col++) {
        final int value = state[row * size + col];
        if (value == TakuzuBoard.emptyValue) {
          buffer.write('?');
          empties.add(col);
        } else {
          buffer.write(value);
          hasValue = true;
        }
      }
      if (empties.isEmpty || !hasValue) {
        continue;
      }
      for (final MapEntry<String, String> entry in complements.entries) {
        final String pattern = entry.key;
        final String inverse = entry.value;
        bool matchesPattern = true;
        bool matchesInverse = true;
        for (int col = 0; col < size; col++) {
          final int value = state[row * size + col];
          final int patternValue = pattern.codeUnitAt(col) - 48;
          final int inverseValue = inverse.codeUnitAt(col) - 48;
          if (value != TakuzuBoard.emptyValue) {
            if (value != patternValue) {
              matchesPattern = false;
            }
            if (value != inverseValue) {
              matchesInverse = false;
            }
          }
        }
        if (matchesPattern) {
          for (final int col in empties) {
            final int forced = 1 - (pattern.codeUnitAt(col) - 48);
            final int index = row * size + col;
            if (state[index] == TakuzuBoard.emptyValue) {
              state[index] = forced;
              assignments++;
            } else if (state[index] != forced) {
              return const _RuleResult.contradiction();
            }
          }
        } else if (matchesInverse) {
          for (final int col in empties) {
            final int forced = 1 - (inverse.codeUnitAt(col) - 48);
            final int index = row * size + col;
            if (state[index] == TakuzuBoard.emptyValue) {
              state[index] = forced;
              assignments++;
            } else if (state[index] != forced) {
              return const _RuleResult.contradiction();
            }
          }
        }
      }
    }

    // Mirror logic for columns.
    final Map<String, String> colComplements = <String, String>{};
    for (int col = 0; col < size; col++) {
      final StringBuffer buffer = StringBuffer();
      final StringBuffer inverse = StringBuffer();
      bool complete = true;
      for (int row = 0; row < size; row++) {
        final int value = state[row * size + col];
        if (value == TakuzuBoard.emptyValue) {
          buffer.write('?');
          inverse.write('?');
          complete = false;
        } else {
          buffer.write(value);
          inverse.write(1 - value);
        }
      }
      if (complete) {
        colComplements[buffer.toString()] = inverse.toString();
      }
    }

    for (int col = 0; col < size; col++) {
      final StringBuffer buffer = StringBuffer();
      final List<int> empties = <int>[];
      bool hasValue = false;
      for (int row = 0; row < size; row++) {
        final int value = state[row * size + col];
        if (value == TakuzuBoard.emptyValue) {
          buffer.write('?');
          empties.add(row);
        } else {
          buffer.write(value);
          hasValue = true;
        }
      }
      if (empties.isEmpty || !hasValue) {
        continue;
      }
      for (final MapEntry<String, String> entry in colComplements.entries) {
        final String pattern = entry.key;
        final String inverse = entry.value;
        bool matchesPattern = true;
        bool matchesInverse = true;
        for (int row = 0; row < size; row++) {
          final int value = state[row * size + col];
          final int patternValue = pattern.codeUnitAt(row) - 48;
          final int inverseValue = inverse.codeUnitAt(row) - 48;
          if (value != TakuzuBoard.emptyValue) {
            if (value != patternValue) {
              matchesPattern = false;
            }
            if (value != inverseValue) {
              matchesInverse = false;
            }
          }
        }
        if (matchesPattern) {
          for (final int rowIndex in empties) {
            final int forced = 1 - (pattern.codeUnitAt(rowIndex) - 48);
            final int index = rowIndex * size + col;
            if (state[index] == TakuzuBoard.emptyValue) {
              state[index] = forced;
              assignments++;
            } else if (state[index] != forced) {
              return const _RuleResult.contradiction();
            }
          }
        } else if (matchesInverse) {
          for (final int rowIndex in empties) {
            final int forced = 1 - (inverse.codeUnitAt(rowIndex) - 48);
            final int index = rowIndex * size + col;
            if (state[index] == TakuzuBoard.emptyValue) {
              state[index] = forced;
              assignments++;
            } else if (state[index] != forced) {
              return const _RuleResult.contradiction();
            }
          }
        }
      }
    }

    return _RuleResult(assignments: assignments);
  }
}

class _LogicResult {
  const _LogicResult({
    required this.assignments,
    required this.contradiction,
  });

  final int assignments;
  final bool contradiction;
}

class _RuleResult {
  const _RuleResult({this.assignments = 0}) : contradiction = false;

  const _RuleResult.contradiction()
      : assignments = 0,
        contradiction = true;

  final int assignments;
  final bool contradiction;
}

extension on List<int> {
  void swap(int a, int b) {
    if (a == b) {
      return;
    }
    final int tmp = this[a];
    this[a] = this[b];
    this[b] = tmp;
  }
}
