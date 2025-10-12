import '../solver/solver.dart';
import '../util/nonogram.dart';
import 'nonogram_board.dart';

class NonogramSolver extends PuzzleSolver<NonogramBoard> {
  const NonogramSolver({
    this.maxSearchDepth = 3,
    this.maxLineIterations = 256,
  });

  final int maxSearchDepth;
  final int maxLineIterations;

  @override
  SolverResult<NonogramBoard> solve(
    NonogramBoard board,
    SolverContext context,
  ) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final _NonogramSearch search = _NonogramSearch(
      board: board,
      maxDepth: maxSearchDepth,
      maxLineIterations: maxLineIterations,
      maxSolutions: context.maxSolutions,
    );
    final _SearchResult result = search.solve();
    stopwatch.stop();

    final Map<String, Object?> telemetry = <String, Object?>{
      'logicAssignments': result.logicAssignments,
      'initialLogicAssignments': result.initialLogicAssignments,
      'logicCompletion': result.logicCompletion,
      'speculativeSteps': result.speculativeSteps,
      'visitedNodes': result.visitedNodes,
      'lineIterations': result.lineIterations,
    };

    return SolverResult<NonogramBoard>(
      solutions: result.solutions,
      elapsed: stopwatch.elapsed,
      telemetry: telemetry,
    );
  }
}

class _NonogramSearch {
  _NonogramSearch({
    required this.board,
    required this.maxDepth,
    required this.maxLineIterations,
    required this.maxSolutions,
  });

  final NonogramBoard board;
  final int maxDepth;
  final int maxLineIterations;
  final int maxSolutions;

  final List<NonogramBoard> solutions = <NonogramBoard>[];
  int logicAssignments = 0;
  int initialLogicAssignments = 0;
  int speculativeSteps = 0;
  int visitedNodes = 0;
  int lineIterations = 0;

  _SearchResult solve() {
    final _SearchState root = _SearchState(board);
    final _LogicResult rootLogic = _applyLogic(root, trackAssignments: true);
    lineIterations += rootLogic.iterations;
    logicAssignments += rootLogic.assignments;
    initialLogicAssignments = rootLogic.assignments;
    if (rootLogic.contradiction) {
      return _SearchResult(
        solutions: const <NonogramBoard>[],
        logicAssignments: logicAssignments,
        initialLogicAssignments: initialLogicAssignments,
        logicCompletion: _logicCompletion(board, initialLogicAssignments),
        speculativeSteps: speculativeSteps,
        visitedNodes: visitedNodes,
        lineIterations: lineIterations,
      );
    }

    if (root.isSolved) {
      solutions.add(root.toBoard());
      return _SearchResult(
        solutions: solutions,
        logicAssignments: logicAssignments,
        initialLogicAssignments: initialLogicAssignments,
        logicCompletion: _logicCompletion(board, initialLogicAssignments),
        speculativeSteps: speculativeSteps,
        visitedNodes: visitedNodes,
        lineIterations: lineIterations,
      );
    }

    _search(root, depth: 0);

    return _SearchResult(
      solutions: solutions,
      logicAssignments: logicAssignments,
      initialLogicAssignments: initialLogicAssignments,
      logicCompletion: _logicCompletion(board, initialLogicAssignments),
      speculativeSteps: speculativeSteps,
      visitedNodes: visitedNodes,
      lineIterations: lineIterations,
    );
  }

  void _search(_SearchState state, {required int depth}) {
    if (solutions.length >= maxSolutions) {
      return;
    }
    visitedNodes++;

    final int? cellIndex = state.firstUnsolvedCell();
    if (cellIndex == null) {
      solutions.add(state.toBoard());
      return;
    }

    if (depth >= maxDepth) {
      return;
    }

    speculativeSteps++;
    for (final int assumption in <int>[NonogramLineSolver.filled, NonogramLineSolver.empty]) {
      final _SearchState child = state.clone();
      child.cells[cellIndex] = assumption;
      final _LogicResult logicResult = _applyLogic(child, trackAssignments: false);
      lineIterations += logicResult.iterations;
      if (logicResult.contradiction) {
        continue;
      }
      if (child.isSolved) {
        solutions.add(child.toBoard());
        if (solutions.length >= maxSolutions) {
          return;
        }
        continue;
      }
      _search(child, depth: depth + 1);
      if (solutions.length >= maxSolutions) {
        return;
      }
    }
  }

  _LogicResult _applyLogic(_SearchState state, {required bool trackAssignments}) {
    bool changed = true;
    int iterations = 0;
    int assignments = 0;

    while (changed && iterations < maxLineIterations) {
      changed = false;
      iterations++;

      for (int row = 0; row < board.height; row++) {
        final List<int?> values = state.row(row);
        final NonogramPropagationResult propagation =
            NonogramLineSolver.propagate(values, board.rowClues[row]);
        if (propagation.contradiction) {
          return _LogicResult(contradiction: true);
        }
        for (int col = 0; col < board.width; col++) {
          final int index = row * board.width + col;
          final int? prior = state.cells[index];
          final int? updated = propagation.updated[col];
          if (prior != updated) {
            state.cells[index] = updated;
            if (trackAssignments && prior == null && updated != null) {
              assignments++;
            }
            changed = true;
          }
        }
      }

      for (int col = 0; col < board.width; col++) {
        final List<int?> values = state.column(col);
        final NonogramPropagationResult propagation =
            NonogramLineSolver.propagate(values, board.columnClues[col]);
        if (propagation.contradiction) {
          return _LogicResult(contradiction: true);
        }
        for (int row = 0; row < board.height; row++) {
          final int index = row * board.width + col;
          final int? prior = state.cells[index];
          final int? updated = propagation.updated[row];
          if (prior != updated) {
            state.cells[index] = updated;
            if (trackAssignments && prior == null && updated != null) {
              assignments++;
            }
            changed = true;
          }
        }
      }
    }

    return _LogicResult(
      contradiction: false,
      assignments: assignments,
      iterations: iterations,
    );
  }

  double _logicCompletion(NonogramBoard board, int assignments) {
    if (board.cellCount == 0) {
      return 1.0;
    }
    return assignments / board.cellCount;
  }
}

class _SearchState {
  _SearchState(NonogramBoard board)
      : width = board.width,
        height = board.height,
        cells = List<int?>.from(board.cells),
        rowClues = board.rowClues,
        columnClues = board.columnClues;

  _SearchState._internal({
    required this.width,
    required this.height,
    required this.cells,
    required this.rowClues,
    required this.columnClues,
  });

  final int width;
  final int height;
  final List<int?> cells;
  final List<List<int>> rowClues;
  final List<List<int>> columnClues;

  bool get isSolved => !cells.contains(null);

  _SearchState clone() {
    return _SearchState._internal(
      width: width,
      height: height,
      cells: List<int?>.from(cells),
      rowClues: rowClues,
      columnClues: columnClues,
    );
  }

  NonogramBoard toBoard() {
    return NonogramBoard(
      width: width,
      height: height,
      rowClues: rowClues,
      columnClues: columnClues,
      cells: cells,
    );
  }

  int? firstUnsolvedCell() {
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] == null) {
        return i;
      }
    }
    return null;
  }

  List<int?> row(int row) {
    final int offset = row * width;
    return List<int?>.generate(width, (int index) => cells[offset + index]);
  }

  List<int?> column(int col) {
    return List<int?>.generate(height, (int row) => cells[row * width + col]);
  }
}

class _LogicResult {
  const _LogicResult({
    required this.contradiction,
    this.assignments = 0,
    this.iterations = 0,
  });

  final bool contradiction;
  final int assignments;
  final int iterations;
}

class _SearchResult {
  const _SearchResult({
    required this.solutions,
    required this.logicAssignments,
    required this.initialLogicAssignments,
    required this.logicCompletion,
    required this.speculativeSteps,
    required this.visitedNodes,
    required this.lineIterations,
  });

  final List<NonogramBoard> solutions;
  final int logicAssignments;
  final int initialLogicAssignments;
  final double logicCompletion;
  final int speculativeSteps;
  final int visitedNodes;
  final int lineIterations;
}
