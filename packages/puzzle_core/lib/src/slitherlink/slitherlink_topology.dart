class SlitherlinkTopology {
  final int width;
  final int height;
  final int horizontalEdgeCount;
  final int verticalEdgeCount;
  final int edgeCount;
  final int vertexCount;
  final List<List<int>> cellEdges;
  final List<List<int>> vertexEdges;
  final List<List<int>> edgeCells;
  final List<int> edgeVertexA;
  final List<int> edgeVertexB;

  const SlitherlinkTopology._({
    required this.width,
    required this.height,
    required this.horizontalEdgeCount,
    required this.verticalEdgeCount,
    required this.edgeCount,
    required this.vertexCount,
    required this.cellEdges,
    required this.vertexEdges,
    required this.edgeCells,
    required this.edgeVertexA,
    required this.edgeVertexB,
  });

  static final Map<String, SlitherlinkTopology> _cache =
      <String, SlitherlinkTopology>{};

  factory SlitherlinkTopology.forSize(int width, int height) {
    final String key = '$widthx$height';
    return _cache.putIfAbsent(key, () => _build(width, height));
  }

  static SlitherlinkTopology _build(int width, int height) {
    final int horizontalEdgeCount = (height + 1) * width;
    final int verticalEdgeCount = (width + 1) * height;
    final int edgeCount = horizontalEdgeCount + verticalEdgeCount;
    final int vertexCount = (width + 1) * (height + 1);

    final List<List<int>> cellEdges =
        List<List<int>>.generate(width * height, (int _) => <int>[]);
    final List<List<int>> vertexEdges =
        List<List<int>>.generate(vertexCount, (int _) => <int>[]);
    final List<int> edgeVertexA = List<int>.filled(edgeCount, 0);
    final List<int> edgeVertexB = List<int>.filled(edgeCount, 0);
    final List<List<int>> edgeCells =
        List<List<int>>.generate(edgeCount, (int _) => <int>[]);

    int horizontalIndex(int row, int col) => row * width + col;
    int verticalIndex(int row, int col) =>
        horizontalEdgeCount + row * (width + 1) + col;
    int vertexIndex(int row, int col) => row * (width + 1) + col;

    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        final int cell = row * width + col;
        final int top = horizontalIndex(row, col);
        final int bottom = horizontalIndex(row + 1, col);
        final int left = verticalIndex(row, col);
        final int right = verticalIndex(row, col + 1);

        cellEdges[cell] = <int>[top, right, bottom, left];
        edgeCells[top].add(cell);
        edgeCells[right].add(cell);
        edgeCells[bottom].add(cell);
        edgeCells[left].add(cell);
      }
    }

    for (int row = 0; row <= height; row++) {
      for (int col = 0; col < width; col++) {
        final int edge = horizontalIndex(row, col);
        final int a = vertexIndex(row, col);
        final int b = vertexIndex(row, col + 1);
        edgeVertexA[edge] = a;
        edgeVertexB[edge] = b;
        vertexEdges[a].add(edge);
        vertexEdges[b].add(edge);
      }
    }

    for (int row = 0; row < height; row++) {
      for (int col = 0; col <= width; col++) {
        final int edge = verticalIndex(row, col);
        final int a = vertexIndex(row, col);
        final int b = vertexIndex(row + 1, col);
        edgeVertexA[edge] = a;
        edgeVertexB[edge] = b;
        vertexEdges[a].add(edge);
        vertexEdges[b].add(edge);
      }
    }

    return SlitherlinkTopology._(
      width: width,
      height: height,
      horizontalEdgeCount: horizontalEdgeCount,
      verticalEdgeCount: verticalEdgeCount,
      edgeCount: edgeCount,
      vertexCount: vertexCount,
      cellEdges: List<List<int>>.unmodifiable(
        cellEdges.map((List<int> edges) => List<int>.unmodifiable(edges)),
      ),
      vertexEdges: List<List<int>>.unmodifiable(
        vertexEdges.map((List<int> edges) => List<int>.unmodifiable(edges)),
      ),
      edgeCells: List<List<int>>.unmodifiable(
        edgeCells.map((List<int> cells) => List<int>.unmodifiable(cells)),
      ),
      edgeVertexA: List<int>.unmodifiable(edgeVertexA),
      edgeVertexB: List<int>.unmodifiable(edgeVertexB),
    );
  }

  int horizontalEdgeIndex(int row, int col) {
    assert(row >= 0 && row <= height);
    assert(col >= 0 && col < width);
    return row * width + col;
  }

  int verticalEdgeIndex(int row, int col) {
    assert(row >= 0 && row < height);
    assert(col >= 0 && col <= width);
    return horizontalEdgeCount + row * (width + 1) + col;
  }

  int vertexIndex(int row, int col) {
    assert(row >= 0 && row <= height);
    assert(col >= 0 && col <= width);
    return row * (width + 1) + col;
  }
}
