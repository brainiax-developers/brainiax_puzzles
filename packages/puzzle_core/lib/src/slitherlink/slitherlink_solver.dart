import '../solver/solver.dart';
import '../util/seeded_rng.dart';
import 'slitherlink_board.dart';
import 'slitherlink_topology.dart';

class SlitherlinkSolver extends PuzzleSolver<SlitherlinkBoard> {
  const SlitherlinkSolver();

  @override
  SolverResult<SlitherlinkBoard> solve(
    SlitherlinkBoard board,
    SolverContext context,
  ) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final _SlitherlinkSolverMetrics metrics = _SlitherlinkSolverMetrics();
    final List<SlitherlinkBoard> solutions = <SlitherlinkBoard>[];

    final _SlitherlinkSolverState initialState =
        _SlitherlinkSolverState(board, metrics);
    if (!initialState.initializeFromBoard(board)) {
      stopwatch.stop();
      return SolverResult<SlitherlinkBoard>(
        solutions: const <SlitherlinkBoard>[],
        elapsed: stopwatch.elapsed,
        telemetry: metrics.toTelemetry(),
      );
    }

    final _SlitherlinkSearch search = _SlitherlinkSearch(
      initialState: initialState,
      context: context,
      metrics: metrics,
      solutions: solutions,
    );
    search.run();

    stopwatch.stop();
    return SolverResult<SlitherlinkBoard>(
      solutions: solutions,
      elapsed: stopwatch.elapsed,
      telemetry: metrics.toTelemetry(),
    );
  }
}

class _SlitherlinkSearch {
  _SlitherlinkSearch({
    required this.initialState,
    required this.context,
    required this.metrics,
    required this.solutions,
  });

  final _SlitherlinkSolverState initialState;
  final SolverContext context;
  final _SlitherlinkSolverMetrics metrics;
  final List<SlitherlinkBoard> solutions;

  void run() {
    _dfs(initialState, 0);
  }

  void _dfs(_SlitherlinkSolverState state, int depth) {
    if (solutions.length >= context.maxSolutions) {
      return;
    }

    if (!state.propagate()) {
      return;
    }

    if (state.isSolved) {
      metrics.solutionsExplored++;
      solutions.add(state.toBoard());
      return;
    }

    final int? edge = state.selectEdgeForGuess(context.rng);
    if (edge == null) {
      return;
    }

    metrics.speculativeSteps++;
    if (depth + 1 > metrics.maxDepth) {
      metrics.maxDepth = depth + 1;
    }

    for (final int guess in <int>[SlitherlinkBoard.edgeOn, SlitherlinkBoard.edgeOff]) {
      if (solutions.length >= context.maxSolutions) {
        break;
      }
      final _SlitherlinkSolverState branch = state.clone();
      if (!branch.enqueue(edge, guess, _AssignmentReason.decision)) {
        continue;
      }
      _dfs(branch, depth + 1);
    }
  }
}

enum _AssignmentReason { initial, local, global, decision }

class _SlitherlinkSolverMetrics {
  int totalAssignments = 0;
  int localAssignments = 0;
  int globalAssignments = 0;
  int speculativeSteps = 0;
  int maxDepth = 0;
  int solutionsExplored = 0;

  Map<String, Object?> toTelemetry() => <String, Object?>{
        'totalAssignments': totalAssignments,
        'localAssignments': localAssignments,
        'globalAssignments': globalAssignments,
        'speculativeSteps': speculativeSteps,
        'maxDepth': maxDepth,
        'solutionsExplored': solutionsExplored,
      };
}

class _SlitherlinkSolverState {
  _SlitherlinkSolverState._({
    required this.width,
    required this.height,
    required this.topology,
    required this.clues,
    required this.metrics,
  })  : edges =
            List<int>.filled(topology.edgeCount, SlitherlinkBoard.edgeUnknown),
        cellOn = List<int>.filled(width * height, 0),
        cellUnknown = List<int>.filled(width * height, 0),
        vertexOn = List<int>.filled(topology.vertexCount, 0),
        vertexUnknown = List<int>.filled(topology.vertexCount, 0),
        parent = List<int>.generate(topology.vertexCount, (int i) => i),
        size = List<int>.filled(topology.vertexCount, 1),
        componentVertices = List<int>.filled(topology.vertexCount, 1),
        componentOnEdges = List<int>.filled(topology.vertexCount, 0),
        _edgeQueue = <_QueuedAssignment>[],
        _cellQueue = <int>[],
        _vertexQueue = <int>[],
        _cellQueued =
            List<bool>.filled(width * height, false, growable: false),
        _vertexQueued = List<bool>.filled(
          topology.vertexCount,
          false,
          growable: false,
        );

  factory _SlitherlinkSolverState(
    SlitherlinkBoard board,
    _SlitherlinkSolverMetrics metrics,
  ) =>
      _SlitherlinkSolverState._(
        width: board.width,
        height: board.height,
        topology: board.topology,
        clues: board.clues,
        metrics: metrics,
      );

  _SlitherlinkSolverState._clone(_SlitherlinkSolverState other)
      : width = other.width,
        height = other.height,
        topology = other.topology,
        clues = other.clues,
        metrics = other.metrics,
        edges = List<int>.from(other.edges),
        cellOn = List<int>.from(other.cellOn),
        cellUnknown = List<int>.from(other.cellUnknown),
        vertexOn = List<int>.from(other.vertexOn),
        vertexUnknown = List<int>.from(other.vertexUnknown),
        parent = List<int>.from(other.parent),
        size = List<int>.from(other.size),
        componentVertices = List<int>.from(other.componentVertices),
        componentOnEdges = List<int>.from(other.componentOnEdges),
        _edgeQueue = <_QueuedAssignment>[],
        _cellQueue = <int>[],
        _vertexQueue = <int>[],
        _cellQueued = List<bool>.filled(other._cellQueued.length, false),
        _vertexQueued =
            List<bool>.filled(other._vertexQueued.length, false),
        totalOnEdges = other.totalOnEdges,
        unknownEdges = other.unknownEdges;

  final int width;
  final int height;
  final SlitherlinkTopology topology;
  final List<int?> clues;
  final List<int> edges;
  final List<int> cellOn;
  final List<int> cellUnknown;
  final List<int> vertexOn;
  final List<int> vertexUnknown;
  final List<int> parent;
  final List<int> size;
  final List<int> componentVertices;
  final List<int> componentOnEdges;
  final _SlitherlinkSolverMetrics metrics;

  final List<_QueuedAssignment> _edgeQueue;
  final List<int> _cellQueue;
  final List<int> _vertexQueue;
  final List<bool> _cellQueued;
  final List<bool> _vertexQueued;

  int totalOnEdges = 0;
  int unknownEdges = 0;
  bool get isSolved => !edges.contains(SlitherlinkBoard.edgeUnknown);

  bool initializeFromBoard(SlitherlinkBoard board) {
    totalOnEdges = 0;
    unknownEdges = edges.length;
    for (int i = 0; i < edges.length; i++) {
      edges[i] = SlitherlinkBoard.edgeUnknown;
    }
    for (int cell = 0; cell < board.cellCount; cell++) {
      cellOn[cell] = 0;
      cellUnknown[cell] = 4;
    }
    for (int vertex = 0; vertex < topology.vertexCount; vertex++) {
      vertexOn[vertex] = 0;
      vertexUnknown[vertex] = topology.vertexEdges[vertex].length;
      parent[vertex] = vertex;
      size[vertex] = 1;
      componentVertices[vertex] = 1;
      componentOnEdges[vertex] = 0;
    }
    _edgeQueue.clear();
    _cellQueue.clear();
    _vertexQueue.clear();
    for (int i = 0; i < _cellQueued.length; i++) {
      _cellQueued[i] = false;
    }
    for (int i = 0; i < _vertexQueued.length; i++) {
      _vertexQueued[i] = false;
    }

    for (int edge = 0; edge < board.edges.length; edge++) {
      final int value = board.edges[edge];
      if (value == SlitherlinkBoard.edgeUnknown) {
        continue;
      }
      if (!enqueue(edge, value, _AssignmentReason.initial)) {
        return false;
      }
    }
    return propagate();
  }

  _SlitherlinkSolverState clone() => _SlitherlinkSolverState._clone(this);

  bool enqueue(int edge, int value, _AssignmentReason reason) {
    _edgeQueue.add(_QueuedAssignment(edge, value, reason));
    return true;
  }

  bool propagate() {
    while (true) {
      if (!_drainEdgeQueue()) {
        return false;
      }
      if (!_drainCellQueue()) {
        return false;
      }
      if (!_drainVertexQueue()) {
        return false;
      }
      if (_edgeQueue.isEmpty && _cellQueue.isEmpty && _vertexQueue.isEmpty) {
        if (!_applyGlobalLoopConstraints()) {
          return false;
        }
        if (_edgeQueue.isEmpty) {
          break;
        }
      }
    }
    return true;
  }

  bool _drainEdgeQueue() {
    while (_edgeQueue.isNotEmpty) {
      final _QueuedAssignment next = _edgeQueue.removeLast();
      if (!_applyEdge(next.edge, next.value, next.reason)) {
        return false;
      }
    }
    return true;
  }

  bool _drainCellQueue() {
    while (_cellQueue.isNotEmpty) {
      final int cell = _cellQueue.removeLast();
      _cellQueued[cell] = false;
      if (!_evaluateCell(cell)) {
        return false;
      }
    }
    return true;
  }

  bool _drainVertexQueue() {
    while (_vertexQueue.isNotEmpty) {
      final int vertex = _vertexQueue.removeLast();
      _vertexQueued[vertex] = false;
      if (!_evaluateVertex(vertex)) {
        return false;
      }
    }
    return true;
  }

  bool _applyEdge(int edge, int value, _AssignmentReason reason) {
    final int current = edges[edge];
    if (current == value) {
      return true;
    }
    if (current != SlitherlinkBoard.edgeUnknown) {
      return false;
    }

    edges[edge] = value;
    unknownEdges--;
    metrics.totalAssignments++;
    switch (reason) {
      case _AssignmentReason.local:
        metrics.localAssignments++;
        break;
      case _AssignmentReason.global:
        metrics.globalAssignments++;
        break;
      default:
        break;
    }

    final int a = topology.edgeVertexA[edge];
    final int b = topology.edgeVertexB[edge];

    vertexUnknown[a]--;
    vertexUnknown[b]--;
    _scheduleVertex(a);
    _scheduleVertex(b);

    final List<int> incidentCells = _incidentCells(edge);
    for (final int cell in incidentCells) {
      cellUnknown[cell]--;
      _scheduleCell(cell);
    }

    if (value == SlitherlinkBoard.edgeOn) {
      totalOnEdges++;
      vertexOn[a]++;
      vertexOn[b]++;
      if (!_mergeForOnEdge(a, b)) {
        return false;
      }
      for (final int cell in incidentCells) {
        cellOn[cell]++;
      }
    }

    return true;
  }

  List<int> _incidentCells(int edge) {
    return List<int>.from(topology.edgeCells[edge]);
  }

  void _scheduleCell(int cell) {
    if (!_cellQueued[cell]) {
      _cellQueued[cell] = true;
      _cellQueue.add(cell);
    }
  }

  void _scheduleVertex(int vertex) {
    if (!_vertexQueued[vertex]) {
      _vertexQueued[vertex] = true;
      _vertexQueue.add(vertex);
    }
  }

  bool _evaluateCell(int cell) {
    final int? clue = clues[cell];
    if (clue == null) {
      return true;
    }
    final List<int> edgesForCell = topology.cellEdges[cell];
    int unknown = 0;
    for (final int edge in edgesForCell) {
      if (edges[edge] == SlitherlinkBoard.edgeUnknown) {
        unknown++;
      }
    }
    final int on = cellOn[cell];
    if (on > clue) {
      return false;
    }
    if (on + unknown < clue) {
      return false;
    }
    if (unknown == 0) {
      if (on != clue) {
        return false;
      }
      return true;
    }
    if (on == clue) {
      for (final int edge in edgesForCell) {
        if (edges[edge] == SlitherlinkBoard.edgeUnknown) {
          _edgeQueue.add(_QueuedAssignment(edge, SlitherlinkBoard.edgeOff,
              _AssignmentReason.local));
        }
      }
    } else if (on + unknown == clue) {
      for (final int edge in edgesForCell) {
        if (edges[edge] == SlitherlinkBoard.edgeUnknown) {
          _edgeQueue.add(_QueuedAssignment(edge, SlitherlinkBoard.edgeOn,
              _AssignmentReason.local));
        }
      }
    }
    return true;
  }

  bool _evaluateVertex(int vertex) {
    final int on = vertexOn[vertex];
    final int unknown = vertexUnknown[vertex];
    if (on > 2) {
      return false;
    }
    if (on == 1 && unknown == 0) {
      return false;
    }
    if (on > 0 && on + unknown < 2) {
      return false;
    }
    if (unknown == 0) {
      return on == 0 || on == 2;
    }
    if (on == 2) {
      for (final int edge in topology.vertexEdges[vertex]) {
        if (edges[edge] == SlitherlinkBoard.edgeUnknown) {
          _edgeQueue.add(_QueuedAssignment(edge, SlitherlinkBoard.edgeOff,
              _AssignmentReason.local));
        }
      }
    } else if (on == 1 && unknown == 1) {
      for (final int edge in topology.vertexEdges[vertex]) {
        if (edges[edge] == SlitherlinkBoard.edgeUnknown) {
          _edgeQueue.add(_QueuedAssignment(edge, SlitherlinkBoard.edgeOn,
              _AssignmentReason.local));
        }
      }
    }
    return true;
  }

  bool _applyGlobalLoopConstraints() {
    bool changed = false;
    for (int edge = 0; edge < edges.length; edge++) {
      if (edges[edge] != SlitherlinkBoard.edgeUnknown) {
        continue;
      }
      final int a = topology.edgeVertexA[edge];
      final int b = topology.edgeVertexB[edge];
      final int rootA = _find(a);
      final int rootB = _find(b);
      if (rootA != rootB) {
        continue;
      }
      final int componentEdges = componentOnEdges[rootA];
      if (componentEdges != totalOnEdges) {
        _edgeQueue.add(_QueuedAssignment(edge, SlitherlinkBoard.edgeOff,
            _AssignmentReason.global));
        changed = true;
      }
    }
    return changed ? _drainEdgeQueue() : true;
  }

  int? selectEdgeForGuess(SeededRng rng) {
    int? bestEdge;
    int bestScore = 1 << 30;
    for (int edge = 0; edge < edges.length; edge++) {
      if (edges[edge] != SlitherlinkBoard.edgeUnknown) {
        continue;
      }
      final int score = _edgeHeuristic(edge);
      if (score < bestScore) {
        bestScore = score;
        bestEdge = edge;
      } else if (score == bestScore && bestEdge != null) {
        if (rng.nextBool()) {
          bestEdge = edge;
        }
      }
    }
    return bestEdge;
  }

  int _edgeHeuristic(int edge) {
    final int a = topology.edgeVertexA[edge];
    final int b = topology.edgeVertexB[edge];
    int score = vertexUnknown[a] + vertexUnknown[b];
    for (final int cell in topology.edgeCells[edge]) {
      final int? clue = clues[cell];
      if (clue != null) {
        score += (cellUnknown[cell] - cellOn[cell]).abs();
      }
    }
    return score;
  }

  SlitherlinkBoard toBoard() => SlitherlinkBoard(
        width: width,
        height: height,
        clues: clues,
        edges: edges,
      );

  int _find(int vertex) {
    if (parent[vertex] != vertex) {
      parent[vertex] = _find(parent[vertex]);
    }
    return parent[vertex];
  }

  bool _mergeForOnEdge(int a, int b) {
    final int rootA = _find(a);
    final int rootB = _find(b);
    final int previousTotal = totalOnEdges - 1;

    if (rootA == rootB) {
      final int compEdges = componentOnEdges[rootA];
      final int compVertices = componentVertices[rootA];
      if (compEdges != previousTotal) {
        return false;
      }
      if (compEdges + 1 > compVertices) {
        return false;
      }
      componentOnEdges[rootA] = compEdges + 1;
      return true;
    }

    int mergedRootA = rootA;
    int mergedRootB = rootB;
    if (size[mergedRootA] < size[mergedRootB]) {
      final int temp = mergedRootA;
      mergedRootA = mergedRootB;
      mergedRootB = temp;
    }

    parent[mergedRootB] = mergedRootA;
    size[mergedRootA] += size[mergedRootB];
    componentVertices[mergedRootA] =
        componentVertices[rootA] + componentVertices[rootB];
    componentOnEdges[mergedRootA] =
        componentOnEdges[rootA] + componentOnEdges[rootB] + 1;
    return true;
  }
}

class _QueuedAssignment {
  _QueuedAssignment(this.edge, this.value, this.reason);

  final int edge;
  final int value;
  final _AssignmentReason reason;
}
