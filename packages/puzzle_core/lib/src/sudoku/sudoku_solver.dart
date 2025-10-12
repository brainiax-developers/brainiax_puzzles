import '../solver/solver.dart';
import '../util/determinism.dart';
import 'sudoku_board.dart';

const int _allCandidatesMask = 0x1ff; // Bits 0-8 represent digits 1-9.

int _digitToMask(int digit) => 1 << (digit - 1);

int _maskToDigit(int mask) {
  if (mask == 0) {
    return 0;
  }
  int digit = 1;
  int tmp = mask;
  while (tmp > 1) {
    tmp >>= 1;
    digit++;
  }
  return digit;
}

int _countBits(int mask) {
  int count = 0;
  int value = mask;
  while (value != 0) {
    value &= value - 1;
    count++;
  }
  return count;
}

class _HumanSolveResult {
  final List<int> cells;
  final Map<String, int> techniqueCounts;
  final int assignments;
  final bool solved;

  const _HumanSolveResult({
    required this.cells,
    required this.techniqueCounts,
    required this.assignments,
    required this.solved,
  });
}

class _HumanLogicSolver {
  _HumanLogicSolver(this.initialBoard)
      : cells = List<int>.from(initialBoard.cells),
        fixed = List<bool>.from(initialBoard.fixed),
        candidates = List<int>.filled(SudokuBoard.cellCount, _allCandidatesMask),
        techniqueCounts = <String, int>{};

  final SudokuBoard initialBoard;
  final List<int> cells;
  final List<bool> fixed;
  final List<int> candidates;
  final Map<String, int> techniqueCounts;

  int assignments = 0;

  _HumanSolveResult solve() {
    _initialiseCandidates();

    bool progress = true;
    while (progress) {
      progress = false;
      if (_applyNakedSingles()) {
        progress = true;
        continue;
      }
      if (_applyHiddenSingles()) {
        progress = true;
        continue;
      }
      bool eliminationProgress = false;
      eliminationProgress |= _applyNakedSubsets();
      eliminationProgress |= _applyPointingClaiming();
      eliminationProgress |= _applyXWing();
      eliminationProgress |= _applySwordfish();
      if (eliminationProgress) {
        progress = true;
      }
    }

    final bool solved = cells.every((int value) => value != 0) &&
        _isValidSolution(cells);

    return _HumanSolveResult(
      cells: cells,
      techniqueCounts: techniqueCounts,
      assignments: assignments,
      solved: solved,
    );
  }

  void _initialiseCandidates() {
    for (int index = 0; index < SudokuBoard.cellCount; index++) {
      final int value = cells[index];
      if (value != 0) {
        final int mask = _digitToMask(value);
        candidates[index] = mask;
        for (final int peer in SudokuBoard.peers[index]) {
          candidates[peer] &= ~mask;
        }
      }
    }
  }

  bool _applyNakedSingles() {
    bool progress = false;
    for (int i = 0; i < SudokuBoard.cellCount; i++) {
      if (cells[i] == 0 && _countBits(candidates[i]) == 1) {
        final int digit = _maskToDigit(candidates[i]);
        _assign(i, digit, 'nakedSingle');
        progress = true;
      }
    }
    return progress;
  }

  bool _applyHiddenSingles() {
    bool progress = false;
    for (final List<int> unit in SudokuBoard.allUnits) {
      final Map<int, int> counts = <int, int>{};
      for (final int index in unit) {
        if (cells[index] != 0) {
          continue;
        }
        int mask = candidates[index];
        while (mask != 0) {
          final int bit = mask & -mask;
          counts[bit] = (counts[bit] ?? 0) + 1;
          mask ^= bit;
        }
      }
      for (final MapEntry<int, int> entry in counts.entries) {
        if (entry.value == 1) {
          final int digitMask = entry.key;
          final int digit = _maskToDigit(digitMask);
          for (final int index in unit) {
            if (cells[index] == 0 && (candidates[index] & digitMask) != 0) {
              _assign(index, digit, 'hiddenSingle');
              progress = true;
              break;
            }
          }
        }
      }
    }
    return progress;
  }

  bool _applyNakedSubsets() {
    bool progress = false;
    for (final List<int> unit in SudokuBoard.allUnits) {
      final Map<int, List<int>> occurrences = <int, List<int>>{};
      for (final int index in unit) {
        if (cells[index] != 0) {
          continue;
        }
        final int mask = candidates[index];
        final int bits = _countBits(mask);
        if (bits >= 2 && bits <= 3) {
          occurrences.putIfAbsent(mask, () => <int>[]).add(index);
        }
      }
      for (final MapEntry<int, List<int>> entry in occurrences.entries) {
        final int mask = entry.key;
        final List<int> indexes = entry.value;
        final int size = _countBits(mask);
        if (indexes.length == size && size >= 2) {
          bool unitChanged = false;
          for (final int index in unit) {
            if (indexes.contains(index) || cells[index] != 0) {
              continue;
            }
            final int before = candidates[index];
            final int after = before & ~mask;
            if (after != before) {
              candidates[index] = after;
              unitChanged = true;
            }
          }
          if (unitChanged) {
            _increment('nakedSubset');
            progress = true;
          }
        }
      }
    }
    return progress;
  }

  bool _applyPointingClaiming() {
    bool progress = false;

    // Pointing: check each box and digit to remove from row/column outside the box.
    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        final List<int> boxIndices = SudokuBoard.boxIndices(boxRow * 3, boxCol * 3);
        for (int digit = 1; digit <= 9; digit++) {
          final int digitMask = _digitToMask(digit);
          int rowMask = 0;
          int colMask = 0;
          final List<int> positions = <int>[];
          for (final int index in boxIndices) {
            if (cells[index] == 0 && (candidates[index] & digitMask) != 0) {
              positions.add(index);
              final int row = index ~/ SudokuBoard.side;
              final int col = index % SudokuBoard.side;
              rowMask |= 1 << row;
              colMask |= 1 << col;
            }
          }
          if (positions.isEmpty) {
            continue;
          }
          if (_countBits(rowMask) == 1) {
            final int row = positions.first ~/ SudokuBoard.side;
            for (int col = 0; col < SudokuBoard.side; col++) {
              final int idx = row * SudokuBoard.side + col;
              if (!boxIndices.contains(idx) && cells[idx] == 0) {
                final int before = candidates[idx];
                final int after = before & ~digitMask;
                if (after != before) {
                  candidates[idx] = after;
                  progress = true;
                }
              }
            }
            if (progress) {
              _increment('pointing');
            }
          }
          if (_countBits(colMask) == 1) {
            final int col = positions.first % SudokuBoard.side;
            for (int row = 0; row < SudokuBoard.side; row++) {
              final int idx = row * SudokuBoard.side + col;
              if (!boxIndices.contains(idx) && cells[idx] == 0) {
                final int before = candidates[idx];
                final int after = before & ~digitMask;
                if (after != before) {
                  candidates[idx] = after;
                  progress = true;
                }
              }
            }
            if (progress) {
              _increment('pointing');
            }
          }
        }
      }
    }

    // Claiming: check rows/columns to remove candidates within the intersecting box.
    for (int row = 0; row < SudokuBoard.side; row++) {
      final List<int> rowIndices = SudokuBoard.rowIndices(row);
      for (int digit = 1; digit <= 9; digit++) {
        final int digitMask = _digitToMask(digit);
        int boxMask = 0;
        final List<int> positions = <int>[];
        for (final int idx in rowIndices) {
          if (cells[idx] == 0 && (candidates[idx] & digitMask) != 0) {
            positions.add(idx);
            final int box = ((idx ~/ SudokuBoard.side) ~/ 3) * 3 + ((idx % SudokuBoard.side) ~/ 3);
            boxMask |= 1 << box;
          }
        }
        if (_countBits(boxMask) == 1 && positions.isNotEmpty) {
          final int boxRow = row ~/ 3 * 3;
          final int boxCol = (positions.first % SudokuBoard.side) ~/ 3 * 3;
          final List<int> boxIndices = SudokuBoard.boxIndices(boxRow, boxCol);
          bool changed = false;
          for (final int idx in boxIndices) {
            if (!positions.contains(idx) && cells[idx] == 0) {
              final int before = candidates[idx];
              final int after = before & ~digitMask;
              if (after != before) {
                candidates[idx] = after;
                changed = true;
              }
            }
          }
          if (changed) {
            _increment('claiming');
            progress = true;
          }
        }
      }
    }

    for (int col = 0; col < SudokuBoard.side; col++) {
      final List<int> columnIndices = SudokuBoard.columnIndices(col);
      for (int digit = 1; digit <= 9; digit++) {
        final int digitMask = _digitToMask(digit);
        int boxMask = 0;
        final List<int> positions = <int>[];
        for (final int idx in columnIndices) {
          if (cells[idx] == 0 && (candidates[idx] & digitMask) != 0) {
            positions.add(idx);
            final int box = ((idx ~/ SudokuBoard.side) ~/ 3) * 3 + ((idx % SudokuBoard.side) ~/ 3);
            boxMask |= 1 << box;
          }
        }
        if (_countBits(boxMask) == 1 && positions.isNotEmpty) {
          final int boxRow = (positions.first ~/ SudokuBoard.side) ~/ 3 * 3;
          final int boxCol = col ~/ 3 * 3;
          final List<int> boxIndices = SudokuBoard.boxIndices(boxRow, boxCol);
          bool changed = false;
          for (final int idx in boxIndices) {
            if (!positions.contains(idx) && cells[idx] == 0) {
              final int before = candidates[idx];
              final int after = before & ~digitMask;
              if (after != before) {
                candidates[idx] = after;
                changed = true;
              }
            }
          }
          if (changed) {
            _increment('claiming');
            progress = true;
          }
        }
      }
    }

    return progress;
  }

  bool _applyXWing() {
    bool progress = false;
    for (int digit = 1; digit <= 9; digit++) {
      final int digitMask = _digitToMask(digit);

      final List<int> rowPatterns = List<int>.filled(SudokuBoard.side, 0);
      final List<int> colPatterns = List<int>.filled(SudokuBoard.side, 0);

      for (int row = 0; row < SudokuBoard.side; row++) {
        int pattern = 0;
        for (int col = 0; col < SudokuBoard.side; col++) {
          final int idx = row * SudokuBoard.side + col;
          if (cells[idx] == 0 && (candidates[idx] & digitMask) != 0) {
            pattern |= 1 << col;
          }
        }
        rowPatterns[row] = pattern;
      }

      for (int col = 0; col < SudokuBoard.side; col++) {
        int pattern = 0;
        for (int row = 0; row < SudokuBoard.side; row++) {
          final int idx = row * SudokuBoard.side + col;
          if (cells[idx] == 0 && (candidates[idx] & digitMask) != 0) {
            pattern |= 1 << row;
          }
        }
        colPatterns[col] = pattern;
      }

      // Row-based X-Wing
      for (int r1 = 0; r1 < SudokuBoard.side - 1; r1++) {
        final int p1 = rowPatterns[r1];
        if (_countBits(p1) != 2) {
          continue;
        }
        for (int r2 = r1 + 1; r2 < SudokuBoard.side; r2++) {
          final int p2 = rowPatterns[r2];
          if (p1 == p2 && p1 != 0) {
            final List<int> cols = <int>[];
            int pattern = p1;
            for (int col = 0; col < SudokuBoard.side; col++) {
              if ((pattern & (1 << col)) != 0) {
                cols.add(col);
              }
            }
            bool changed = false;
            for (int row = 0; row < SudokuBoard.side; row++) {
              if (row == r1 || row == r2) {
                continue;
              }
              for (final int col in cols) {
                final int idx = row * SudokuBoard.side + col;
                if (cells[idx] == 0 && (candidates[idx] & digitMask) != 0) {
                  candidates[idx] &= ~digitMask;
                  changed = true;
                }
              }
            }
            if (changed) {
              _increment('xWing');
              progress = true;
            }
          }
        }
      }

      // Column-based X-Wing
      for (int c1 = 0; c1 < SudokuBoard.side - 1; c1++) {
        final int p1 = colPatterns[c1];
        if (_countBits(p1) != 2) {
          continue;
        }
        for (int c2 = c1 + 1; c2 < SudokuBoard.side; c2++) {
          final int p2 = colPatterns[c2];
          if (p1 == p2 && p1 != 0) {
            final List<int> rows = <int>[];
            int pattern = p1;
            for (int row = 0; row < SudokuBoard.side; row++) {
              if ((pattern & (1 << row)) != 0) {
                rows.add(row);
              }
            }
            bool changed = false;
            for (int col = 0; col < SudokuBoard.side; col++) {
              if (col == c1 || col == c2) {
                continue;
              }
              for (final int row in rows) {
                final int idx = row * SudokuBoard.side + col;
                if (cells[idx] == 0 && (candidates[idx] & digitMask) != 0) {
                  candidates[idx] &= ~digitMask;
                  changed = true;
                }
              }
            }
            if (changed) {
              _increment('xWing');
              progress = true;
            }
          }
        }
      }
    }
    return progress;
  }

  bool _applySwordfish() {
    bool progress = false;
    for (int digit = 1; digit <= 9; digit++) {
      final int digitMask = _digitToMask(digit);
      final List<int> rowPatterns = <int>[];
      for (int row = 0; row < SudokuBoard.side; row++) {
        int pattern = 0;
        for (int col = 0; col < SudokuBoard.side; col++) {
          final int idx = row * SudokuBoard.side + col;
          if (cells[idx] == 0 && (candidates[idx] & digitMask) != 0) {
            pattern |= 1 << col;
          }
        }
        if (_countBits(pattern) >= 2 && _countBits(pattern) <= 3) {
          rowPatterns.add((row << 16) | pattern);
        }
      }
      if (rowPatterns.length >= 3) {
        for (int i = 0; i < rowPatterns.length - 2; i++) {
          for (int j = i + 1; j < rowPatterns.length - 1; j++) {
            for (int k = j + 1; k < rowPatterns.length; k++) {
              final int r1 = rowPatterns[i] >> 16;
              final int r2 = rowPatterns[j] >> 16;
              final int r3 = rowPatterns[k] >> 16;
              final int mask =
                  (rowPatterns[i] & 0xffff) | (rowPatterns[j] & 0xffff) | (rowPatterns[k] & 0xffff);
              if (_countBits(mask) == 3) {
                final List<int> cols = <int>[];
                for (int col = 0; col < SudokuBoard.side; col++) {
                  if ((mask & (1 << col)) != 0) {
                    cols.add(col);
                  }
                }
                bool changed = false;
                for (int row = 0; row < SudokuBoard.side; row++) {
                  if (row == r1 || row == r2 || row == r3) {
                    continue;
                  }
                  for (final int col in cols) {
                    final int idx = row * SudokuBoard.side + col;
                    if (cells[idx] == 0 && (candidates[idx] & digitMask) != 0) {
                      candidates[idx] &= ~digitMask;
                      changed = true;
                    }
                  }
                }
                if (changed) {
                  _increment('swordfish');
                  progress = true;
                }
              }
            }
          }
        }
      }

      final List<int> colPatterns = <int>[];
      for (int col = 0; col < SudokuBoard.side; col++) {
        int pattern = 0;
        for (int row = 0; row < SudokuBoard.side; row++) {
          final int idx = row * SudokuBoard.side + col;
          if (cells[idx] == 0 && (candidates[idx] & digitMask) != 0) {
            pattern |= 1 << row;
          }
        }
        if (_countBits(pattern) >= 2 && _countBits(pattern) <= 3) {
          colPatterns.add((col << 16) | pattern);
        }
      }
      if (colPatterns.length >= 3) {
        for (int i = 0; i < colPatterns.length - 2; i++) {
          for (int j = i + 1; j < colPatterns.length - 1; j++) {
            for (int k = j + 1; k < colPatterns.length; k++) {
              final int c1 = colPatterns[i] >> 16;
              final int c2 = colPatterns[j] >> 16;
              final int c3 = colPatterns[k] >> 16;
              final int mask =
                  (colPatterns[i] & 0xffff) | (colPatterns[j] & 0xffff) | (colPatterns[k] & 0xffff);
              if (_countBits(mask) == 3) {
                final List<int> rows = <int>[];
                for (int row = 0; row < SudokuBoard.side; row++) {
                  if ((mask & (1 << row)) != 0) {
                    rows.add(row);
                  }
                }
                bool changed = false;
                for (int col = 0; col < SudokuBoard.side; col++) {
                  if (col == c1 || col == c2 || col == c3) {
                    continue;
                  }
                  for (final int row in rows) {
                    final int idx = row * SudokuBoard.side + col;
                    if (cells[idx] == 0 && (candidates[idx] & digitMask) != 0) {
                      candidates[idx] &= ~digitMask;
                      changed = true;
                    }
                  }
                }
                if (changed) {
                  _increment('swordfish');
                  progress = true;
                }
              }
            }
          }
        }
      }
    }
    return progress;
  }

  bool _isValidSolution(List<int> state) {
    for (int unit = 0; unit < SudokuBoard.allUnits.length; unit++) {
      final List<int> indices = SudokuBoard.allUnits[unit];
      final Set<int> seen = <int>{};
      for (final int index in indices) {
        final int value = state[index];
        if (value == 0 || !seen.add(value)) {
          return false;
        }
      }
    }
    return true;
  }

  void _assign(int index, int digit, String technique) {
    cells[index] = digit;
    assignments++;
    candidates[index] = _digitToMask(digit);
    for (final int peer in SudokuBoard.peers[index]) {
      candidates[peer] &= ~_digitToMask(digit);
    }
    _increment(technique);
  }

  void _increment(String key) {
    techniqueCounts[key] = (techniqueCounts[key] ?? 0) + 1;
  }
}

class _SearchResult {
  final List<List<int>> solutions;
  final int nodesVisited;
  final int maxDepth;

  const _SearchResult({
    required this.solutions,
    required this.nodesVisited,
    required this.maxDepth,
  });
}

class _BacktrackingSearch {
  _BacktrackingSearch(this.board);

  final SudokuBoard board;

  _SearchResult search({required int maxSolutions}) {
    final List<int> working = List<int>.from(board.cells);
    final List<List<int>> solutions = <List<int>>[];
    int nodes = 0;
    int maxDepth = 0;

    void dfs(int depth) {
      if (solutions.length >= maxSolutions) {
        return;
      }
      if (depth > maxDepth) {
        maxDepth = depth;
      }
      int nextIndex = -1;
      int bestCount = 10;
      for (int i = 0; i < SudokuBoard.cellCount; i++) {
        if (working[i] == 0) {
          final int count = _availableDigitsCount(working, i);
          if (count == 0) {
            return;
          }
          if (count < bestCount) {
            bestCount = count;
            nextIndex = i;
            if (count == 1) {
              break;
            }
          }
        }
      }
      if (nextIndex == -1) {
        solutions.add(List<int>.from(working));
        return;
      }

      final List<int> digits = _availableDigits(working, nextIndex);
      for (final int digit in digits) {
        working[nextIndex] = digit;
        nodes++;
        dfs(depth + 1);
        working[nextIndex] = 0;
        if (solutions.length >= maxSolutions) {
          return;
        }
      }
    }

    dfs(0);

    return _SearchResult(
      solutions: solutions,
      nodesVisited: nodes,
      maxDepth: maxDepth,
    );
  }

  List<int> _availableDigits(List<int> state, int index) {
    final Set<int> used = <int>{};
    for (final int peer in SudokuBoard.peers[index]) {
      final int value = state[peer];
      if (value != 0) {
        used.add(value);
      }
    }
    final List<int> digits = <int>[];
    for (int digit = 1; digit <= 9; digit++) {
      if (!used.contains(digit)) {
        digits.add(digit);
      }
    }
    return digits;
  }

  int _availableDigitsCount(List<int> state, int index) {
    final Set<int> used = <int>{};
    for (final int peer in SudokuBoard.peers[index]) {
      final int value = state[peer];
      if (value != 0) {
        used.add(value);
      }
    }
    return 9 - used.length;
  }
}

class SudokuSolver extends PuzzleSolver<SudokuBoard> {
  const SudokuSolver();

  @override
  SolverResult<SudokuBoard> solve(SudokuBoard board, SolverContext context) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final _HumanLogicSolver logicSolver = _HumanLogicSolver(board);
    final _HumanSolveResult logicResult = logicSolver.solve();

    final _BacktrackingSearch backtracking = _BacktrackingSearch(
      SudokuBoard(cells: logicResult.cells, fixed: board.fixed),
    );
    final _SearchResult searchResult = backtracking.search(
      maxSolutions: context.maxSolutions,
    );

    final List<SudokuBoard> solvedBoards = <SudokuBoard>[];
    for (final List<int> solution in searchResult.solutions) {
      solvedBoards.add(SudokuBoard(cells: solution, fixed: board.fixed));
    }

    stopwatch.stop();

    final Map<String, Object?> telemetry = <String, Object?>{
      'humanAssignments': logicResult.assignments,
      'techniqueCounts': logicResult.techniqueCounts,
      'logicSolved': logicResult.solved,
      'searchNodes': searchResult.nodesVisited,
      'searchDepth': searchResult.maxDepth,
      'solutionsFound': solvedBoards.length,
    };

    DeterminismGuard.assertNoFloatsOrDateTimes(telemetry);

    return SolverResult<SudokuBoard>(
      solutions: solvedBoards,
      elapsed: stopwatch.elapsed,
      telemetry: telemetry,
    );
  }
}
