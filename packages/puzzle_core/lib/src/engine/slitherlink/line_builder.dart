import 'dart:math' as math;
import 'dart:typed_data';

import '../../util/seeded_rng.dart';

class LoopSynthesisResult {
  LoopSynthesisResult({
    required this.width,
    required this.height,
    required this.solutionEdges,
    required this.loopLength,
  });

  final int width;
  final int height;
  final Uint8List solutionEdges;
  final int loopLength;
}

LoopSynthesisResult synthesizeLoop({
  required int width,
  required int height,
  required SeededRng rng,
}) {
  final _LoopBuilder builder = _LoopBuilder(
    width: width,
    height: height,
    rng: rng,
  );
  final Set<int> loopEdges = builder.buildLoop();
  final Uint8List edges = builder.encodeLoop(loopEdges);
  return LoopSynthesisResult(
    width: width,
    height: height,
    solutionEdges: edges,
    loopLength: loopEdges.length,
  );
}

class _LoopBuilder {
  _LoopBuilder({
    required this.width,
    required this.height,
    required this.rng,
  })  : rows = height + 1,
        cols = width + 1,
        vertexCount = (height + 1) * (width + 1);

  final int width;
  final int height;
  final int rows;
  final int cols;
  final int vertexCount;
  final SeededRng rng;

  late final List<List<int>> _treeAdj =
      List<List<int>>.generate(vertexCount, (_) => <int>[]);
  final Set<int> _treeEdges = <int>{};

  Set<int> buildLoop() {
    _growTree();
    final List<_Edge> candidates = _allEdges()
        .where((edge) => !_treeEdges.contains(edge.key))
        .toList();
    rng.shuffle(candidates);

    const int minCycleLength = 8;
    for (final _Edge candidate in candidates) {
      final List<int> path = _pathBetween(candidate.a, candidate.b);
      if (path.isEmpty) {
        continue;
      }
      final Set<int> loop = <int>{};
      for (int i = 0; i < path.length - 1; i++) {
        final int u = path[i];
        final int v = path[i + 1];
        loop.add(_edgeKey(u, v));
      }
      loop.add(candidate.key);
      if (loop.length >= minCycleLength) {
        return loop;
      }
    }
    return _perimeterLoop();
  }

  Uint8List encodeLoop(Set<int> loopEdges) {
    final SlitherlinkEdgeWriter writer =
        SlitherlinkEdgeWriter(width: width, height: height);
    final Uint8List buffer = Uint8List(writer.edgeCount);
    for (final int key in loopEdges) {
      final int a = key >> 32;
      final int b = key & 0xffffffff;
      final int ar = _rowOf(a);
      final int ac = _colOf(a);
      final int br = _rowOf(b);
      final int bc = _colOf(b);
      if (ar == br) {
        final int row = ar;
        final int col = math.min(ac, bc);
        writer.setHorizontal(row, col, 1, buffer);
      } else {
        final int col = ac;
        final int row = math.min(ar, br);
        writer.setVertical(row, col, 1, buffer);
      }
    }
    return buffer;
  }

  void _growTree() {
    final List<bool> visited = List<bool>.filled(vertexCount, false);
    final List<int> stack = <int>[];
    final int start = rng.nextIntInRange(vertexCount);
    stack.add(start);
    visited[start] = true;

    while (stack.isNotEmpty) {
      final int current = stack.last;
      final List<int> unvisited = _neighbors(current)
          .where((neighbor) => !visited[neighbor])
          .toList();
      if (unvisited.isEmpty) {
        stack.removeLast();
        continue;
      }
      final int next = unvisited[rng.nextIntInRange(unvisited.length)];
      visited[next] = true;
      _treeAdj[current].add(next);
      _treeAdj[next].add(current);
      _treeEdges.add(_edgeKey(current, next));
      stack.add(next);
    }

    // If the graph wasn't fully explored due to unlucky RNG, connect remaining vertices.
    for (int vertex = 0; vertex < vertexCount; vertex++) {
      if (visited[vertex]) {
        continue;
      }
      // Connect to the closest visited neighbor.
      final List<int> neigh = _neighbors(vertex).toList();
      if (neigh.isEmpty) {
        continue;
      }
      final int neighbor = neigh.firstWhere(
        (n) => visited[n],
        orElse: () => neigh.first,
      );
      visited[vertex] = true;
      _treeAdj[vertex].add(neighbor);
      _treeAdj[neighbor].add(vertex);
      _treeEdges.add(_edgeKey(vertex, neighbor));
      stack
        ..clear()
        ..add(vertex);
      while (stack.isNotEmpty) {
        final int current = stack.last;
        final List<int> unvisited =
            _neighbors(current).where((n) => !visited[n]).toList();
        if (unvisited.isEmpty) {
          stack.removeLast();
          continue;
        }
        final int next = unvisited[rng.nextIntInRange(unvisited.length)];
        visited[next] = true;
        _treeAdj[current].add(next);
        _treeAdj[next].add(current);
        _treeEdges.add(_edgeKey(current, next));
        stack.add(next);
      }
    }
  }

  Iterable<int> _neighbors(int vertex) sync* {
    final int row = _rowOf(vertex);
    final int col = _colOf(vertex);
    if (row > 0) yield vertex - cols;
    if (row + 1 < rows) yield vertex + cols;
    if (col > 0) yield vertex - 1;
    if (col + 1 < cols) yield vertex + 1;
  }

  List<_Edge> _allEdges() {
    final List<_Edge> edges = <_Edge>[];
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final int v = _vertex(row, col);
        if (col + 1 < cols) {
          final int east = _vertex(row, col + 1);
          edges.add(_Edge(v, east));
        }
        if (row + 1 < rows) {
          final int south = _vertex(row + 1, col);
          edges.add(_Edge(v, south));
        }
      }
    }
    return edges;
  }

  List<int> _pathBetween(int start, int goal) {
    final List<int> prev = List<int>.filled(vertexCount, -1);
    final List<int> queue = <int>[start];
    prev[start] = start;
    int head = 0;
    while (head < queue.length) {
      final int current = queue[head++];
      if (current == goal) {
        break;
      }
      for (final int neighbor in _treeAdj[current]) {
        if (prev[neighbor] != -1) {
          continue;
        }
        prev[neighbor] = current;
        queue.add(neighbor);
      }
    }
    if (prev[goal] == -1) {
      return const <int>[];
    }
    final List<int> path = <int>[];
    int node = goal;
    while (node != start) {
      path.add(node);
      node = prev[node];
    }
    path.add(start);
    return path.reversed.toList();
  }

  Set<int> _perimeterLoop() {
    final Set<int> loop = <int>{};
    // Top edge
    for (int col = 0; col < width; col++) {
      loop.add(_edgeKey(_vertex(0, col), _vertex(0, col + 1)));
    }
    // Bottom edge
    for (int col = 0; col < width; col++) {
      loop.add(_edgeKey(_vertex(rows - 1, col), _vertex(rows - 1, col + 1)));
    }
    // Left edge
    for (int row = 0; row < height; row++) {
      loop.add(_edgeKey(_vertex(row, 0), _vertex(row + 1, 0)));
    }
    // Right edge
    for (int row = 0; row < height; row++) {
      loop.add(
        _edgeKey(_vertex(row, cols - 1), _vertex(row + 1, cols - 1)),
      );
    }
    return loop;
  }

  int _vertex(int row, int col) => row * cols + col;
  int _rowOf(int vertex) => vertex ~/ cols;
  int _colOf(int vertex) => vertex % cols;
}

class _Edge {
  _Edge(this.a, this.b)
      : key = _edgeKey(a, b);

  final int a;
  final int b;
  final int key;
}

int _edgeKey(int a, int b) {
  final int minV = math.min(a, b);
  final int maxV = math.max(a, b);
  return (minV << 32) | maxV;
}

class SlitherlinkEdgeWriter {
  SlitherlinkEdgeWriter({
    required this.width,
    required this.height,
  })  : horizontalEdgeCount = (height + 1) * width,
        verticalEdgeCount = (width + 1) * height,
        edgeCount = (height + 1) * width + (width + 1) * height;

  final int width;
  final int height;
  final int horizontalEdgeCount;
  final int verticalEdgeCount;
  final int edgeCount;

  void setHorizontal(int row, int col, int value, Uint8List edges) {
    final int idx = row * width + col;
    edges[idx] = value;
  }

  void setVertical(int row, int col, int value, Uint8List edges) {
    final int idx = horizontalEdgeCount + row * (width + 1) + col;
    edges[idx] = value;
  }
}
