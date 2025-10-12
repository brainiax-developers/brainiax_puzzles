import '../generators/generator.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../util/seeded_rng.dart';
import 'slitherlink_board.dart';
import 'slitherlink_solver.dart';
import 'slitherlink_topology.dart';
import 'slitherlink_validator.dart';

class SlitherlinkGenerator extends PuzzleGenerator<SlitherlinkBoard> {
  const SlitherlinkGenerator();

  static const List<int> _supportedWidths = <int>[5, 6, 7];
  static const List<int> _supportedHeights = <int>[5, 6, 7];

  @override
  PuzzleGenerationResult<SlitherlinkBoard> generate(GeneratorContext context) {
    final int width = context.size.width;
    final int height = context.size.height;
    if (!_supportedWidths.contains(width) || !_supportedHeights.contains(height)) {
      throw ArgumentError('Unsupported Slitherlink size: ${width}x$height');
    }

    final Stopwatch stopwatch = Stopwatch()..start();

    final SlitherlinkTopology topology = SlitherlinkTopology.forSize(width, height);
    final List<int> solutionEdges = _buildSolutionLoop(context.rng, topology);
    final List<int?> allClues = _deriveClues(topology, solutionEdges);

    final List<int?> puzzleClues = List<int?>.from(allClues);

    final SlitherlinkSolver solver = const SlitherlinkSolver();
    final SlitherlinkValidator validator = const SlitherlinkValidator();
    final int solverSeed = context.rng.nextInt64();
    int solverInvocation = 0;

    bool _isUnique(List<int?> candidate) {
      final SlitherlinkBoard puzzle = SlitherlinkBoard.empty(
        width: width,
        height: height,
        clues: candidate,
      );
      final SolverContext solverContext = SolverContext(
        rng: SeededRng(solverSeed ^ solverInvocation++),
        maxSolutions: 2,
      );
      final SolverResult<SlitherlinkBoard> result =
          solver.solve(puzzle, solverContext);
      if (!result.hasSolution || !result.isUnique) {
        return false;
      }
      final SlitherlinkBoard solved = result.solutions.first;
      for (int edge = 0; edge < solutionEdges.length; edge++) {
        if (solved.edges[edge] != solutionEdges[edge]) {
          return false;
        }
      }
      return validator.validatePuzzle(puzzle).isValid;
    }

    if (!_isUnique(puzzleClues)) {
      throw StateError('Failed to produce solvable Slitherlink board');
    }

    final List<int> clueOrder = context.rng
        .permute(List<int>.generate(puzzleClues.length, (int i) => i));

    for (final int idx in clueOrder) {
      if (puzzleClues[idx] == null) {
        continue;
      }
      final int? saved = puzzleClues[idx];
      puzzleClues[idx] = null;
      if (!_isUnique(puzzleClues)) {
        puzzleClues[idx] = saved;
      }
    }

    final SlitherlinkBoard puzzle = SlitherlinkBoard.empty(
      width: width,
      height: height,
      clues: puzzleClues,
    );

    stopwatch.stop();

    final Map<String, Object?> telemetry = <String, Object?>{
      'width': width,
      'height': height,
      'loopEdges': solutionEdges.where((int v) => v == SlitherlinkBoard.edgeOn).length,
      'remainingClues': puzzleClues.where((int? c) => c != null).length,
      'generationUs': stopwatch.elapsedMicroseconds,
    };

    DeterminismGuard.assertNoFloatsOrDateTimes(puzzle.toJson());

    return PuzzleGenerationResult<SlitherlinkBoard>(
      board: puzzle,
      snapshot: GenerationSnapshot(telemetry: telemetry),
    );
  }

  List<int> _buildSolutionLoop(SeededRng rng, SlitherlinkTopology topology) {
    final int vertexCount = topology.vertexCount;
    final int edgeCount = topology.edgeCount;
    final List<List<_Neighbor>> adjacency = List<List<_Neighbor>>.generate(
      vertexCount,
      (_) => <_Neighbor>[],
      growable: false,
    );
    for (int edge = 0; edge < edgeCount; edge++) {
      final int a = topology.edgeVertexA[edge];
      final int b = topology.edgeVertexB[edge];
      adjacency[a].add(_Neighbor(b, edge));
      adjacency[b].add(_Neighbor(a, edge));
    }

    final List<bool> visited = List<bool>.filled(vertexCount, false);
    final List<int> parent = List<int>.filled(vertexCount, -1);
    final List<int> parentEdge = List<int>.filled(vertexCount, -1);
    final List<int> depth = List<int>.filled(vertexCount, 0);
    final List<int> stack = <int>[];
    final List<int> neighborIndex = List<int>.filled(vertexCount, 0);
    final List<List<_Neighbor>> shuffledNeighbors = List<List<_Neighbor>>.generate(
      vertexCount,
      (int v) {
        final List<_Neighbor> copy = List<_Neighbor>.from(adjacency[v]);
        rng.shuffle(copy);
        return copy;
      },
      growable: false,
    );

    final int start = rng.nextIntInRange(vertexCount);
    stack.add(start);
    visited[start] = true;

    final Set<int> treeEdges = <int>{};

    while (stack.isNotEmpty) {
      final int v = stack.last;
      if (neighborIndex[v] >= shuffledNeighbors[v].length) {
        stack.removeLast();
        continue;
      }
      final _Neighbor next = shuffledNeighbors[v][neighborIndex[v]++];
      if (visited[next.vertex]) {
        continue;
      }
      visited[next.vertex] = true;
      parent[next.vertex] = v;
      parentEdge[next.vertex] = next.edge;
      depth[next.vertex] = depth[v] + 1;
      stack.add(next.vertex);
      treeEdges.add(next.edge);
    }

    final List<int> nonTree = <int>[];
    for (int edge = 0; edge < edgeCount; edge++) {
      if (!treeEdges.contains(edge)) {
        nonTree.add(edge);
      }
    }
    if (nonTree.isEmpty) {
      throw StateError('Failed to build loop - no non-tree edges');
    }
    rng.shuffle(nonTree);

    for (final int candidate in nonTree) {
      final Set<int> loopEdges = _extractCycle(
        candidate,
        topology,
        parent,
        parentEdge,
        depth,
      );
      if (loopEdges.length < 4) {
        continue;
      }
      if (_containsFourEdgeCell(loopEdges, topology)) {
        continue;
      }
      final List<int> solution =
          List<int>.filled(edgeCount, SlitherlinkBoard.edgeOff);
      for (final int edge in loopEdges) {
        solution[edge] = SlitherlinkBoard.edgeOn;
      }
      return solution;
    }

    throw StateError('Failed to derive a valid loop for Slitherlink');
  }

  Set<int> _extractCycle(
    int extraEdge,
    SlitherlinkTopology topology,
    List<int> parent,
    List<int> parentEdge,
    List<int> depth,
  ) {
    final int u = topology.edgeVertexA[extraEdge];
    final int v = topology.edgeVertexB[extraEdge];
    final Set<int> loopEdges = <int>{extraEdge};
    int a = u;
    int b = v;
    while (a != b) {
      if (depth[a] >= depth[b]) {
        final int edge = parentEdge[a];
        if (edge < 0) {
          return <int>{};
        }
        loopEdges.add(edge);
        a = parent[a];
      } else {
        final int edge = parentEdge[b];
        if (edge < 0) {
          return <int>{};
        }
        loopEdges.add(edge);
        b = parent[b];
      }
    }
    return loopEdges;
  }

  bool _containsFourEdgeCell(Set<int> loopEdges, SlitherlinkTopology topology) {
    for (int cell = 0; cell < topology.width * topology.height; cell++) {
      int count = 0;
      for (final int edge in topology.cellEdges[cell]) {
        if (loopEdges.contains(edge)) {
          count++;
        }
      }
      if (count == 4) {
        return true;
      }
    }
    return false;
  }

  List<int?> _deriveClues(SlitherlinkTopology topology, List<int> solutionEdges) {
    final List<int?> clues = List<int?>.filled(topology.width * topology.height, 0);
    for (int cell = 0; cell < clues.length; cell++) {
      int count = 0;
      for (final int edge in topology.cellEdges[cell]) {
        if (solutionEdges[edge] == SlitherlinkBoard.edgeOn) {
          count++;
        }
      }
      clues[cell] = count;
    }
    return clues;
  }
}

class _Neighbor {
  const _Neighbor(this.vertex, this.edge);

  final int vertex;
  final int edge;
}
