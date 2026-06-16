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

class LoopSynthesisConstraints {
  const LoopSynthesisConstraints({
    required this.minLoopEdgeCount,
    required this.minTouchedRows,
    required this.minTouchedCols,
    required this.minBoundingBoxWidth,
    required this.minBoundingBoxHeight,
    required this.maxFullZeroRatio,
  });

  final int minLoopEdgeCount;
  final int minTouchedRows;
  final int minTouchedCols;
  final int minBoundingBoxWidth;
  final int minBoundingBoxHeight;
  final double maxFullZeroRatio;
}

LoopSynthesisResult synthesizeLoop({
  required int width,
  required int height,
  required SeededRng rng,
  LoopSynthesisConstraints? constraints,
}) {
  final _LoopBuilder builder = _LoopBuilder(
    width: width,
    height: height,
    rng: rng,
  );
  final Set<int> loopEdges = builder.buildLoop(constraints: constraints);
  final Uint8List edges = builder.encodeLoop(loopEdges);
  return LoopSynthesisResult(
    width: width,
    height: height,
    solutionEdges: edges,
    loopLength: loopEdges.length,
  );
}

class _LoopBuilder {
  _LoopBuilder({required this.width, required this.height, required this.rng})
    : rows = height + 1,
      cols = width + 1,
      vertexCount = (height + 1) * (width + 1);

  final int width;
  final int height;
  final int rows;
  final int cols;
  final int vertexCount;
  final SeededRng rng;

  late final List<List<int>> _treeAdj = List<List<int>>.generate(
    vertexCount,
    (_) => <int>[],
  );
  final Set<int> _treeEdges = <int>{};

  Set<int> buildLoop({LoopSynthesisConstraints? constraints}) {
    _growTree();
    final List<_Edge> candidates = _allEdges()
        .where((edge) => !_treeEdges.contains(edge.key))
        .toList();
    rng.shuffle(candidates);

    final int minCycleLength = constraints?.minLoopEdgeCount ?? 8;
    _LoopCandidate? best;
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
      if (loop.length < minCycleLength) {
        continue;
      }
      final _LoopCandidate scored = _scoreLoop(loop, constraints);
      if (constraints != null && !scored.passesConstraints) {
        continue;
      }
      if (best == null || scored.score > best.score) {
        best = scored;
      }
    }
    if (best != null) {
      return best.edges;
    }
    if (constraints != null) {
      throw StateError('No Slitherlink loop candidate passed quality gates');
    }
    return _perimeterLoop();
  }

  Uint8List encodeLoop(Set<int> loopEdges) {
    final SlitherlinkEdgeWriter writer = SlitherlinkEdgeWriter(
      width: width,
      height: height,
    );
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
      final List<int> unvisited = _neighbors(
        current,
      ).where((neighbor) => !visited[neighbor]).toList();
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
        final List<int> unvisited = _neighbors(
          current,
        ).where((n) => !visited[n]).toList();
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
      loop.add(_edgeKey(_vertex(row, cols - 1), _vertex(row + 1, cols - 1)));
    }
    return loop;
  }

  _LoopCandidate _scoreLoop(
    Set<int> loopEdges,
    LoopSynthesisConstraints? constraints,
  ) {
    final Set<int> touchedRows = <int>{};
    final Set<int> touchedCols = <int>{};
    int minRow = rows;
    int maxRow = -1;
    int minCol = cols;
    int maxCol = -1;
    int boundaryEdges = 0;
    for (final int key in loopEdges) {
      final int a = key >> 32;
      final int b = key & 0xffffffff;
      final int ar = _rowOf(a);
      final int ac = _colOf(a);
      final int br = _rowOf(b);
      final int bc = _colOf(b);
      if (ar == 0 && br == 0 ||
          ar == height && br == height ||
          ac == 0 && bc == 0 ||
          ac == width && bc == width) {
        boundaryEdges++;
      }
      for (final int vertex in <int>[a, b]) {
        final int row = _rowOf(vertex);
        final int col = _colOf(vertex);
        touchedRows.add(row);
        touchedCols.add(col);
        minRow = math.min(minRow, row);
        maxRow = math.max(maxRow, row);
        minCol = math.min(minCol, col);
        maxCol = math.max(maxCol, col);
      }
    }

    final int bboxWidth = maxCol - minCol + 1;
    final int bboxHeight = maxRow - minRow + 1;
    final Map<int, int> clueHistogram = _fullClueHistogram(loopEdges);
    final int zeroClues = clueHistogram[0] ?? 0;
    final int totalCells = width * height;
    final double zeroRatio = totalCells == 0 ? 0.0 : zeroClues / totalCells;
    final int nonZeroClues = totalCells - zeroClues;
    final double coverage = loopEdges.length / edgeCount;
    final double bboxCoverage =
        (bboxWidth * bboxHeight) / math.max(1, (width + 1) * (height + 1));
    final bool perimeterHeavy = boundaryEdges / loopEdges.length > 0.72;
    final bool cornerLocal =
        bboxWidth <= math.max(3, (width + 1) ~/ 2) &&
        bboxHeight <= math.max(3, (height + 1) ~/ 2) &&
        ((minRow == 0 || maxRow == height) && (minCol == 0 || maxCol == width));
    final double score =
        loopEdges.length * 4.0 +
        coverage * 120.0 +
        bboxCoverage * 90.0 +
        (touchedRows.length + touchedCols.length) * 5.0 +
        nonZeroClues * 1.5 -
        zeroRatio * 85.0 -
        (perimeterHeavy ? 45.0 : 0.0) -
        (cornerLocal ? 35.0 : 0.0);

    final bool passesConstraints =
        constraints == null ||
        (loopEdges.length >= constraints.minLoopEdgeCount &&
            touchedRows.length >= constraints.minTouchedRows &&
            touchedCols.length >= constraints.minTouchedCols &&
            bboxWidth >= constraints.minBoundingBoxWidth &&
            bboxHeight >= constraints.minBoundingBoxHeight &&
            zeroRatio <= constraints.maxFullZeroRatio);
    return _LoopCandidate(
      edges: Set<int>.from(loopEdges),
      score: score,
      passesConstraints: passesConstraints,
    );
  }

  Map<int, int> _fullClueHistogram(Set<int> loopEdges) {
    final Map<int, int> histogram = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};
    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        final int top = _edgeKey(_vertex(row, col), _vertex(row, col + 1));
        final int bottom = _edgeKey(
          _vertex(row + 1, col),
          _vertex(row + 1, col + 1),
        );
        final int left = _edgeKey(_vertex(row, col), _vertex(row + 1, col));
        final int right = _edgeKey(
          _vertex(row, col + 1),
          _vertex(row + 1, col + 1),
        );
        int count = 0;
        if (loopEdges.contains(top)) count++;
        if (loopEdges.contains(right)) count++;
        if (loopEdges.contains(bottom)) count++;
        if (loopEdges.contains(left)) count++;
        histogram[count] = (histogram[count] ?? 0) + 1;
      }
    }
    return histogram;
  }

  int _vertex(int row, int col) => row * cols + col;
  int _rowOf(int vertex) => vertex ~/ cols;
  int _colOf(int vertex) => vertex % cols;
  int get edgeCount => rows * width + cols * height;
}

class _LoopCandidate {
  const _LoopCandidate({
    required this.edges,
    required this.score,
    required this.passesConstraints,
  });

  final Set<int> edges;
  final double score;
  final bool passesConstraints;
}

class _Edge {
  _Edge(this.a, this.b) : key = _edgeKey(a, b);

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
  SlitherlinkEdgeWriter({required this.width, required this.height})
    : horizontalEdgeCount = (height + 1) * width,
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
