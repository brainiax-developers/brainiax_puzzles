import 'dart:typed_data';

import '../util/seeded_rng.dart';

class LoopSynthesisResult {
  LoopSynthesisResult({
    required this.colors,
    required this.width,
    required this.height,
    required this.stride,
    required this.solutionEdges,
    required this.flipCount,
  });

  final Uint8List colors; // (height + 2) x (width + 2)
  final int width; // inner width
  final int height; // inner height
  final int stride; // width + 2
  final Uint8List solutionEdges;
  final int flipCount;
}

LoopSynthesisResult synthesizeLoop({
  required int width,
  required int height,
  required SeededRng rng,
}) {
  final int stride = width + 2;
  final int total = (height + 2) * (width + 2);
  final Uint8List colors = Uint8List(total);
  final Uint8List solutionEdges = _emptyEdgeBuffer(width, height);

  _seedSplit(colors, width, height, stride);
  final int flipCount = _refineColors(colors, width, height, stride, rng);
  _deriveEdges(colors, width, height, stride, solutionEdges);

  return LoopSynthesisResult(
    colors: colors,
    width: width,
    height: height,
    stride: stride,
    solutionEdges: solutionEdges,
    flipCount: flipCount,
  );
}

void _seedSplit(Uint8List colors, int width, int height, int stride) {
  for (int row = 0; row < height + 2; row++) {
    for (int col = 0; col < width + 2; col++) {
      final bool padded = row == 0 || row == height + 1 || col == 0 || col == width + 1;
      if (padded) {
        colors[row * stride + col] = 0;
        continue;
      }
      final bool left = col <= (width + 1) ~/ 2;
      colors[row * stride + col] = left ? 1 : 0;
    }
  }
}

int _refineColors(
  Uint8List colors,
  int width,
  int height,
  int stride,
  SeededRng rng,
) {
  final int innerCellCount = width * height;
  final List<int> frontier = <int>[];
  final List<int> frontierPos = List<int>.filled(colors.length, -1);
  final List<int> orthOffsets = <int>[-1, 1, -stride, stride];
  final List<int> diagOffsets = <int>[
    -stride - 1,
    -stride + 1,
    stride - 1,
    stride + 1,
  ];

  void addFrontier(int index) {
    if (frontierPos[index] != -1) {
      return;
    }
    final int row = index ~/ stride;
    final int col = index % stride;
    if (row <= 0 || row >= height + 1 || col <= 0 || col >= width + 1) {
      return;
    }
    if (!_hasOppositeOrthNeighbor(colors, index, orthOffsets)) {
      return;
    }
    frontierPos[index] = frontier.length;
    frontier.add(index);
  }

  void removeFrontier(int index) {
    final int pos = frontierPos[index];
    if (pos == -1) {
      return;
    }
    final int last = frontier.removeLast();
    if (pos < frontier.length) {
      frontier[pos] = last;
      frontierPos[last] = pos;
    }
    frontierPos[index] = -1;
  }

  void refreshFrontier(int index) {
    final bool hasBoundary = _hasOppositeOrthNeighbor(colors, index, orthOffsets);
    if (hasBoundary) {
      addFrontier(index);
    } else {
      removeFrontier(index);
    }
  }

  for (int row = 1; row <= height; row++) {
    for (int col = 1; col <= width; col++) {
      final int idx = row * stride + col;
      if (_hasOppositeOrthNeighbor(colors, idx, orthOffsets)) {
        addFrontier(idx);
      }
    }
  }

  int flipsWithoutProgress = 0;
  const int stallLimitMultiplier = 4;

  int flipCount = 0;
  while (frontier.isNotEmpty && flipsWithoutProgress < innerCellCount * stallLimitMultiplier) {
    final int pick = rng.nextIntInRange(frontier.length);
    final int idx = frontier[pick];
    removeFrontier(idx);
    final int currentColor = colors[idx];
    final int newColor = currentColor ^ 1;
    if (_passesWiggliness(colors, idx, newColor, orthOffsets, diagOffsets) &&
        _preservesConnectivity(colors, idx, stride, newColor)) {
      colors[idx] = newColor;
      flipsWithoutProgress = 0;
      flipCount++;
      refreshFrontier(idx);
      for (final int offset in orthOffsets) {
        final int neighbor = idx + offset;
        refreshFrontier(neighbor);
      }
    } else {
      flipsWithoutProgress++;
      refreshFrontier(idx);
    }
  }
  return flipCount;
}

bool _hasOppositeOrthNeighbor(
  Uint8List colors,
  int index,
  List<int> orthOffsets,
) {
  final int color = colors[index];
  for (final int offset in orthOffsets) {
    if (colors[index + offset] != color) {
      return true;
    }
  }
  return false;
}

bool _passesWiggliness(
  Uint8List colors,
  int index,
  int newColor,
  List<int> orthOffsets,
  List<int> diagOffsets,
) {
  int sameOrth = 0;
  int diffOrth = 0;
  for (final int offset in orthOffsets) {
    if (colors[index + offset] == newColor) {
      sameOrth++;
    } else {
      diffOrth++;
    }
  }
  if (sameOrth > diffOrth) {
    return true;
  }
  if (sameOrth < diffOrth) {
    return false;
  }

  int sameDiag = 0;
  int diffDiag = 0;
  for (final int offset in diagOffsets) {
    if (colors[index + offset] == newColor) {
      sameDiag++;
    } else {
      diffDiag++;
    }
  }
  return sameDiag > diffDiag;
}

bool _preservesConnectivity(
  Uint8List colors,
  int index,
  int stride,
  int newColor,
) {
  final int oldColor = colors[index];
  final List<int> patch = List<int>.filled(9, 0);
  int k = 0;
  for (int dr = -1; dr <= 1; dr++) {
    for (int dc = -1; dc <= 1; dc++) {
      final int idx = index + dr * stride + dc;
      patch[k++] = colors[idx];
    }
  }
  patch[4] = newColor;
  if (!_isConnectedInPatch(patch, oldColor, includeCenter: false)) {
    return false;
  }
  if (!_isConnectedInPatch(patch, newColor, includeCenter: true)) {
    return false;
  }
  return true;
}

bool _isConnectedInPatch(List<int> patch, int color, {required bool includeCenter}) {
  final List<int> nodes = <int>[];
  for (int i = 0; i < patch.length; i++) {
    if (i == 4 && !includeCenter) {
      continue;
    }
    if (patch[i] == color) {
      nodes.add(i);
    }
  }
  if (nodes.length <= 1) {
    return true;
  }

  final List<bool> visited = List<bool>.filled(9, false);
  final List<int> queue = <int>[nodes.first];
  visited[nodes.first] = true;
  final Set<int> nodeSet = nodes.toSet();

  while (queue.isNotEmpty) {
    final int current = queue.removeLast();
    final int row = current ~/ 3;
    final int col = current % 3;
    for (final List<int> dir in _patchOrthDirs) {
      final int nr = row + dir[0];
      final int nc = col + dir[1];
      if (nr < 0 || nr >= 3 || nc < 0 || nc >= 3) {
        continue;
      }
      final int ni = nr * 3 + nc;
      if (!nodeSet.contains(ni)) {
        continue;
      }
      if (!visited[ni]) {
        visited[ni] = true;
        queue.add(ni);
      }
    }
  }

  for (final int node in nodes) {
    if (!visited[node]) {
      return false;
    }
  }
  return true;
}

void _deriveEdges(
  Uint8List colors,
  int width,
  int height,
  int stride,
  Uint8List edges,
) {
  final SlitherlinkEdgeWriter writer = SlitherlinkEdgeWriter(width: width, height: height);

  for (int row = 0; row <= height; row++) {
    for (int col = 0; col < width; col++) {
      final int a = colors[row * stride + (col + 1)];
      final int b = colors[(row + 1) * stride + (col + 1)];
      writer.setHorizontal(row, col, a != b ? 1 : 0, edges);
    }
  }

  for (int row = 0; row < height; row++) {
    for (int col = 0; col <= width; col++) {
      final int a = colors[(row + 1) * stride + col];
      final int b = colors[(row + 1) * stride + (col + 1)];
      writer.setVertical(row, col, a != b ? 1 : 0, edges);
    }
  }
}

Uint8List _emptyEdgeBuffer(int width, int height) {
  final SlitherlinkEdgeWriter writer = SlitherlinkEdgeWriter(width: width, height: height);
  return Uint8List(writer.edgeCount);
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

const List<List<int>> _patchOrthDirs = <List<int>>[
  <int>[-1, 0],
  <int>[1, 0],
  <int>[0, -1],
  <int>[0, 1],
];

