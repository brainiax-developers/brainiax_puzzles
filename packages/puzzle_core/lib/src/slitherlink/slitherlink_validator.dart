import '../validation/validator.dart';
import 'slitherlink_board.dart';
import 'slitherlink_topology.dart';

class SlitherlinkValidator extends PuzzleValidator<SlitherlinkBoard> {
  const SlitherlinkValidator();

  @override
  ValidationSummary validatePuzzle(SlitherlinkBoard board) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    final SlitherlinkTopology topology = board.topology;

    if (board.clues.length != board.cellCount) {
      issues.add('clue_count_mismatch');
    }
    if (board.edges.length != topology.edgeCount) {
      issues.add('edge_count_mismatch');
    }

    for (int i = 0; i < board.clues.length && issues.isEmpty; i++) {
      final int? clue = board.clues[i];
      if (clue != null && (clue < 0 || clue > 3)) {
        issues.add('invalid_clue:$i');
      }
    }

    for (int i = 0; i < board.edges.length && issues.isEmpty; i++) {
      final int value = board.edges[i];
      if (value != SlitherlinkBoard.edgeOn &&
          value != SlitherlinkBoard.edgeOff &&
          value != SlitherlinkBoard.edgeUnknown) {
        issues.add('invalid_edge_value:$i');
      }
    }

    if (issues.isEmpty) {
      final _LoopTracker tracker = _LoopTracker(topology);
      final List<int> vertexOn = List<int>.filled(topology.vertexCount, 0);
      final List<int> vertexUnknown =
          List<int>.filled(topology.vertexCount, 0);

      for (int edge = 0; edge < board.edges.length; edge++) {
        final int value = board.edges[edge];
        final int a = topology.edgeVertexA[edge];
        final int b = topology.edgeVertexB[edge];
        if (value == SlitherlinkBoard.edgeOn) {
          vertexOn[a]++;
          vertexOn[b]++;
          if (!tracker.addEdge(edge)) {
            issues.add('multi_cycle_detected');
            break;
          }
        } else if (value == SlitherlinkBoard.edgeUnknown) {
          vertexUnknown[a]++;
          vertexUnknown[b]++;
        }
      }

      if (issues.isEmpty) {
        if (!_validateCells(board)) {
          issues.add('cell_constraint_violation');
        } else if (!_validateVertices(vertexOn, vertexUnknown)) {
          issues.add('vertex_constraint_violation');
        }
      }
    }

    stopwatch.stop();
    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  ValidationSummary validateSolution(
    SlitherlinkBoard board,
    SlitherlinkBoard solution,
  ) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    if (solution.width != board.width || solution.height != board.height) {
      issues.add('dimension_mismatch');
    }

    final SlitherlinkTopology topology = solution.topology;

    if (solution.edges.length != topology.edgeCount) {
      issues.add('edge_count_mismatch');
    }

    if (issues.isEmpty) {
      for (int i = 0; i < solution.edges.length; i++) {
        final int value = solution.edges[i];
        if (value != SlitherlinkBoard.edgeOn && value != SlitherlinkBoard.edgeOff) {
          issues.add('solution_edge_unknown:$i');
          break;
        }
      }
    }

    if (issues.isEmpty) {
      for (int i = 0; i < board.clues.length; i++) {
        final int? clue = board.clues[i];
        if (clue == null) {
          continue;
        }
        final List<int> cellEdges = topology.cellEdges[i];
        int onCount = 0;
        for (final int edge in cellEdges) {
          if (solution.edges[edge] == SlitherlinkBoard.edgeOn) {
            onCount++;
          }
        }
        if (onCount != clue) {
          issues.add('clue_mismatch:$i');
          break;
        }
      }
    }

    if (issues.isEmpty) {
      final _LoopTracker tracker = _LoopTracker(topology);
      final List<int> vertexOn = List<int>.filled(topology.vertexCount, 0);

      for (int edge = 0; edge < solution.edges.length; edge++) {
        final int value = solution.edges[edge];
        if (value != SlitherlinkBoard.edgeOn) {
          continue;
        }
        final int a = topology.edgeVertexA[edge];
        final int b = topology.edgeVertexB[edge];
        vertexOn[a]++;
        vertexOn[b]++;
        if (!tracker.addEdge(edge)) {
          issues.add('multi_cycle_detected');
          break;
        }
      }

      if (issues.isEmpty) {
        for (int vertex = 0; vertex < vertexOn.length; vertex++) {
          final int degree = vertexOn[vertex];
          if (degree != 0 && degree != 2) {
            issues.add('vertex_degree_violation:$vertex');
            break;
          }
        }
      }

      if (issues.isEmpty) {
        final bool singleLoop = tracker.isSingleLoop();
        if (!singleLoop) {
          issues.add('not_single_loop');
        }
      }
    }

    stopwatch.stop();
    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  bool isSolved(SlitherlinkBoard board) {
    if (!board.isComplete) {
      return false;
    }
    final ValidationSummary summary = validateSolution(board, board);
    return summary.isValid;
  }

  bool _validateCells(SlitherlinkBoard board) {
    final SlitherlinkTopology topology = board.topology;
    for (int cell = 0; cell < board.cellCount; cell++) {
      final int? clue = board.clues[cell];
      if (clue == null) {
        continue;
      }
      int onCount = 0;
      int unknownCount = 0;
      for (final int edge in topology.cellEdges[cell]) {
        final int value = board.edges[edge];
        if (value == SlitherlinkBoard.edgeOn) {
          onCount++;
        } else if (value == SlitherlinkBoard.edgeUnknown) {
          unknownCount++;
        }
      }
      if (onCount > clue) {
        return false;
      }
      if (onCount + unknownCount < clue) {
        return false;
      }
    }
    return true;
  }

  bool _validateVertices(List<int> on, List<int> unknown) {
    for (int vertex = 0; vertex < on.length; vertex++) {
      final int degreeOn = on[vertex];
      final int degreeUnknown = unknown[vertex];
      if (degreeOn > 2) {
        return false;
      }
      if (degreeOn == 1 && degreeUnknown == 0) {
        return false;
      }
      if (degreeOn > 0 && degreeOn + degreeUnknown < 2) {
        return false;
      }
    }
    return true;
  }
}

class _LoopTracker {
  _LoopTracker(this.topology)
      : parent = List<int>.generate(topology.vertexCount, (int i) => i),
        size = List<int>.filled(topology.vertexCount, 1),
        componentVertices = List<int>.filled(topology.vertexCount, 1),
        componentOnEdges = List<int>.filled(topology.vertexCount, 0);

  final SlitherlinkTopology topology;
  final List<int> parent;
  final List<int> size;
  final List<int> componentVertices;
  final List<int> componentOnEdges;
  int totalOnEdges = 0;
  int? firstRoot;

  int find(int x) {
    if (parent[x] != x) {
      parent[x] = find(parent[x]);
    }
    return parent[x];
  }

  bool addEdge(int edge) {
    final int a = topology.edgeVertexA[edge];
    final int b = topology.edgeVertexB[edge];
    final int rootA = find(a);
    final int rootB = find(b);
    final int previousTotal = totalOnEdges;

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
      totalOnEdges = previousTotal + 1;
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
    totalOnEdges = previousTotal + 1;

    if (firstRoot == null) {
      firstRoot = mergedRootA;
    } else {
      firstRoot = find(firstRoot!);
    }

    return true;
  }

  bool isSingleLoop() {
    if (totalOnEdges == 0) {
      return false;
    }
    final int representative = find(firstRoot ?? 0);
    final int compEdges = componentOnEdges[representative];
    final int compVertices = componentVertices[representative];
    if (compEdges != compVertices) {
      return false;
    }
    if (compEdges != totalOnEdges) {
      return false;
    }
    return true;
  }
}
