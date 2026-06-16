import 'dart:math' as math;
import 'dart:typed_data';

import '../../slitherlink/slitherlink_board.dart';
import '../../slitherlink/slitherlink_topology.dart';

class SlitherlinkQualityProfile {
  const SlitherlinkQualityProfile({
    required this.width,
    required this.height,
    required this.difficulty,
    required this.minLoopEdgeCount,
    required this.minTouchedRows,
    required this.minTouchedCols,
    required this.minBoundingBoxWidth,
    required this.minBoundingBoxHeight,
    required this.maxFullZeroRatio,
    required this.maxRevealedZeroRatio,
    required this.minNonZeroRevealedClues,
    required this.minClueDensity,
    required this.maxClueDensity,
  });

  final int width;
  final int height;
  final String difficulty;
  final int minLoopEdgeCount;
  final int minTouchedRows;
  final int minTouchedCols;
  final int minBoundingBoxWidth;
  final int minBoundingBoxHeight;
  final double maxFullZeroRatio;
  final double maxRevealedZeroRatio;
  final int minNonZeroRevealedClues;
  final double minClueDensity;
  final double maxClueDensity;

  double get targetClueDensity => (minClueDensity + maxClueDensity) / 2.0;

  String? loopRejectReason(SlitherlinkQualityMetrics metrics) {
    if (metrics.loopEdgeCount < minLoopEdgeCount) {
      return 'loop_edge_count_below_min';
    }
    if (metrics.loopBoundingBoxWidth < minBoundingBoxWidth) {
      return 'loop_bounding_box_width_below_min';
    }
    if (metrics.loopBoundingBoxHeight < minBoundingBoxHeight) {
      return 'loop_bounding_box_height_below_min';
    }
    if (metrics.loopTouchedRows < minTouchedRows) {
      return 'loop_touched_rows_below_min';
    }
    if (metrics.loopTouchedCols < minTouchedCols) {
      return 'loop_touched_cols_below_min';
    }
    if (metrics.fullZeroRatio > maxFullZeroRatio) {
      return 'full_zero_ratio_above_max';
    }
    return null;
  }

  String? finalRejectReason(SlitherlinkQualityMetrics metrics) {
    return loopRejectReason(metrics) ??
        finalClueSetRejectReason(metrics.revealedClues);
  }

  String? finalClueSetRejectReason(List<int?> revealedClues) {
    final SlitherlinkClueSetMetrics metrics = SlitherlinkClueSetMetrics.from(
      clues: revealedClues,
    );
    if (metrics.clueDensity < minClueDensity) {
      return 'clue_density_below_target';
    }
    if (metrics.clueDensity > maxClueDensity) {
      return 'clue_density_above_target';
    }
    if (metrics.revealedZeroRatio > maxRevealedZeroRatio) {
      return 'revealed_zero_ratio_above_max';
    }
    if (metrics.nonZeroRevealedClueCount < minNonZeroRevealedClues) {
      return 'non_zero_revealed_clues_below_min';
    }
    return null;
  }

  Map<String, Object?> toTelemetry() => <String, Object?>{
    'minLoopEdgeCount': minLoopEdgeCount,
    'minTouchedRows': minTouchedRows,
    'minTouchedCols': minTouchedCols,
    'minBoundingBoxWidth': minBoundingBoxWidth,
    'minBoundingBoxHeight': minBoundingBoxHeight,
    'maxFullZeroRatio': maxFullZeroRatio,
    'maxRevealedZeroRatio': maxRevealedZeroRatio,
    'minNonZeroRevealedClues': minNonZeroRevealedClues,
    'minClueDensity': minClueDensity,
    'maxClueDensity': maxClueDensity,
  };
}

class SlitherlinkQualityMetrics {
  const SlitherlinkQualityMetrics({
    required this.width,
    required this.height,
    required this.loopEdgeCount,
    required this.loopCoverageRatio,
    required this.loopBoundingBoxWidth,
    required this.loopBoundingBoxHeight,
    required this.loopTouchedRows,
    required this.loopTouchedCols,
    required this.fullClueHistogram,
    required this.revealedClueHistogram,
    required this.fullZeroRatio,
    required this.revealedZeroRatio,
    required this.nonZeroRevealedClueCount,
    required this.clueDensity,
    required this.revealedClues,
  });

  final int width;
  final int height;
  final int loopEdgeCount;
  final double loopCoverageRatio;
  final int loopBoundingBoxWidth;
  final int loopBoundingBoxHeight;
  final int loopTouchedRows;
  final int loopTouchedCols;
  final Map<String, int> fullClueHistogram;
  final Map<String, int> revealedClueHistogram;
  final double fullZeroRatio;
  final double revealedZeroRatio;
  final int nonZeroRevealedClueCount;
  final double clueDensity;
  final List<int?> revealedClues;

  factory SlitherlinkQualityMetrics.analyze({
    required int width,
    required int height,
    required Uint8List solutionEdges,
    required List<int> fullClues,
    required List<int?> revealedClues,
  }) {
    final SlitherlinkTopology topology = SlitherlinkTopology.forSize(
      width,
      height,
    );
    int loopEdges = 0;
    int minRow = height + 1;
    int maxRow = -1;
    int minCol = width + 1;
    int maxCol = -1;
    final Set<int> touchedRows = <int>{};
    final Set<int> touchedCols = <int>{};
    for (int edge = 0; edge < solutionEdges.length; edge++) {
      if (solutionEdges[edge] != SlitherlinkBoard.edgeOn) {
        continue;
      }
      loopEdges++;
      final int a = topology.edgeVertexA[edge];
      final int b = topology.edgeVertexB[edge];
      for (final int vertex in <int>[a, b]) {
        final int row = vertex ~/ (width + 1);
        final int col = vertex % (width + 1);
        minRow = math.min(minRow, row);
        maxRow = math.max(maxRow, row);
        minCol = math.min(minCol, col);
        maxCol = math.max(maxCol, col);
        touchedRows.add(row);
        touchedCols.add(col);
      }
    }

    final Map<String, int> fullHistogram = clueHistogram(fullClues);
    final SlitherlinkClueSetMetrics clueSet = SlitherlinkClueSetMetrics.from(
      clues: revealedClues,
    );
    final int totalCells = width * height;
    return SlitherlinkQualityMetrics(
      width: width,
      height: height,
      loopEdgeCount: loopEdges,
      loopCoverageRatio: topology.edgeCount == 0
          ? 0.0
          : loopEdges / topology.edgeCount,
      loopBoundingBoxWidth: loopEdges == 0 ? 0 : maxCol - minCol + 1,
      loopBoundingBoxHeight: loopEdges == 0 ? 0 : maxRow - minRow + 1,
      loopTouchedRows: touchedRows.length,
      loopTouchedCols: touchedCols.length,
      fullClueHistogram: fullHistogram,
      revealedClueHistogram: clueSet.histogram,
      fullZeroRatio: totalCells == 0
          ? 0.0
          : (fullHistogram['0'] ?? 0) / totalCells,
      revealedZeroRatio: clueSet.revealedZeroRatio,
      nonZeroRevealedClueCount: clueSet.nonZeroRevealedClueCount,
      clueDensity: clueSet.clueDensity,
      revealedClues: List<int?>.unmodifiable(revealedClues),
    );
  }

  Map<String, Object?> toTelemetry() => <String, Object?>{
    'loopEdgeCount': loopEdgeCount,
    'loopCoverageRatio': loopCoverageRatio,
    'loopTouchedRows': loopTouchedRows,
    'loopTouchedCols': loopTouchedCols,
    'loopBoundingBoxWidth': loopBoundingBoxWidth,
    'loopBoundingBoxHeight': loopBoundingBoxHeight,
    'fullClueHistogram': fullClueHistogram,
    'revealedClueHistogram': revealedClueHistogram,
    'fullZeroRatio': fullZeroRatio,
    'revealedZeroRatio': revealedZeroRatio,
    'nonZeroRevealedClues': nonZeroRevealedClueCount,
    'clueDensity': clueDensity,
  };
}

class SlitherlinkClueSetMetrics {
  const SlitherlinkClueSetMetrics({
    required this.histogram,
    required this.revealedZeroRatio,
    required this.nonZeroRevealedClueCount,
    required this.clueDensity,
  });

  final Map<String, int> histogram;
  final double revealedZeroRatio;
  final int nonZeroRevealedClueCount;
  final double clueDensity;

  factory SlitherlinkClueSetMetrics.from({required List<int?> clues}) {
    final Map<String, int> histogram = <String, int>{
      '0': 0,
      '1': 0,
      '2': 0,
      '3': 0,
    };
    int revealed = 0;
    int nonZero = 0;
    for (final int? clue in clues) {
      if (clue == null) {
        continue;
      }
      revealed++;
      if (clue > 0) {
        nonZero++;
      }
      final String key = clue.toString();
      if (histogram.containsKey(key)) {
        histogram[key] = histogram[key]! + 1;
      }
    }
    return SlitherlinkClueSetMetrics(
      histogram: Map<String, int>.unmodifiable(histogram),
      revealedZeroRatio: revealed == 0 ? 0.0 : (histogram['0'] ?? 0) / revealed,
      nonZeroRevealedClueCount: nonZero,
      clueDensity: clues.isEmpty ? 0.0 : revealed / clues.length,
    );
  }
}

SlitherlinkQualityProfile slitherlinkQualityProfileFor({
  required int width,
  required int height,
  required String difficulty,
}) {
  final int size = math.min(width, height);
  final _LoopGateSeed seed = _loopGateSeedFor(size);
  final _DensityBand band = _densityBandFor(difficulty, size: size);
  return SlitherlinkQualityProfile(
    width: width,
    height: height,
    difficulty: difficulty.toLowerCase(),
    minLoopEdgeCount: seed.minLoopEdgeCount,
    minTouchedRows: seed.minTouchedRows,
    minTouchedCols: seed.minTouchedCols,
    minBoundingBoxWidth: seed.minBoundingBoxWidth,
    minBoundingBoxHeight: seed.minBoundingBoxHeight,
    maxFullZeroRatio: seed.maxFullZeroRatio,
    maxRevealedZeroRatio: seed.maxRevealedZeroRatio,
    minNonZeroRevealedClues: seed.minNonZeroRevealedClues,
    minClueDensity: band.min,
    maxClueDensity: band.max,
  );
}

Map<String, int> clueHistogram(Iterable<int?> clues) {
  final Map<String, int> histogram = <String, int>{
    '0': 0,
    '1': 0,
    '2': 0,
    '3': 0,
  };
  for (final int? clue in clues) {
    if (clue == null) {
      continue;
    }
    final String key = clue.toString();
    if (histogram.containsKey(key)) {
      histogram[key] = histogram[key]! + 1;
    }
  }
  return histogram;
}

_LoopGateSeed _loopGateSeedFor(int size) {
  if (size <= 5) {
    return const _LoopGateSeed(
      minLoopEdgeCount: 16,
      minTouchedRows: 4,
      minTouchedCols: 4,
      minBoundingBoxWidth: 4,
      minBoundingBoxHeight: 4,
      maxFullZeroRatio: 0.60,
      maxRevealedZeroRatio: 0.50,
      minNonZeroRevealedClues: 6,
    );
  }
  if (size <= 7) {
    final double t = (size - 5) / 2.0;
    return _LoopGateSeed.lerp(_gate5, _gate7, t);
  }
  if (size <= 10) {
    final double t = (size - 7) / 3.0;
    return _LoopGateSeed.lerp(_gate7, _gate10, t);
  }
  final double scale = size / 10.0;
  return _LoopGateSeed(
    minLoopEdgeCount: (42 * scale).round(),
    minTouchedRows: math.max(7, (size * 0.7).round()),
    minTouchedCols: math.max(7, (size * 0.7).round()),
    minBoundingBoxWidth: math.max(7, (size * 0.7).round()),
    minBoundingBoxHeight: math.max(7, (size * 0.7).round()),
    maxFullZeroRatio: 0.65,
    maxRevealedZeroRatio: 0.52,
    minNonZeroRevealedClues: (16 * scale).round(),
  );
}

_DensityBand _densityBandFor(String difficulty, {required int size}) {
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return const _DensityBand(0.58, 0.72);
    case 'medium':
      if (size >= 10) {
        return const _DensityBand(0.48, 0.85);
      }
      if (size >= 7) {
        return const _DensityBand(0.48, 0.68);
      }
      return const _DensityBand(0.48, 0.64);
    case 'hard':
      if (size <= 6) {
        return const _DensityBand(0.40, 0.60);
      }
      return const _DensityBand(0.38, 0.56);
    case 'expert':
      if (size <= 6) {
        return const _DensityBand(0.36, 0.56);
      }
      return const _DensityBand(0.32, 0.50);
    default:
      return const _DensityBand(0.48, 0.64);
  }
}

const _LoopGateSeed _gate5 = _LoopGateSeed(
  minLoopEdgeCount: 16,
  minTouchedRows: 4,
  minTouchedCols: 4,
  minBoundingBoxWidth: 4,
  minBoundingBoxHeight: 4,
  maxFullZeroRatio: 0.60,
  maxRevealedZeroRatio: 0.50,
  minNonZeroRevealedClues: 6,
);

const _LoopGateSeed _gate7 = _LoopGateSeed(
  minLoopEdgeCount: 26,
  minTouchedRows: 5,
  minTouchedCols: 5,
  minBoundingBoxWidth: 5,
  minBoundingBoxHeight: 5,
  maxFullZeroRatio: 0.62,
  maxRevealedZeroRatio: 0.50,
  minNonZeroRevealedClues: 10,
);

const _LoopGateSeed _gate10 = _LoopGateSeed(
  minLoopEdgeCount: 42,
  minTouchedRows: 7,
  minTouchedCols: 7,
  minBoundingBoxWidth: 7,
  minBoundingBoxHeight: 7,
  maxFullZeroRatio: 0.65,
  maxRevealedZeroRatio: 0.52,
  minNonZeroRevealedClues: 16,
);

class _LoopGateSeed {
  const _LoopGateSeed({
    required this.minLoopEdgeCount,
    required this.minTouchedRows,
    required this.minTouchedCols,
    required this.minBoundingBoxWidth,
    required this.minBoundingBoxHeight,
    required this.maxFullZeroRatio,
    required this.maxRevealedZeroRatio,
    required this.minNonZeroRevealedClues,
  });

  final int minLoopEdgeCount;
  final int minTouchedRows;
  final int minTouchedCols;
  final int minBoundingBoxWidth;
  final int minBoundingBoxHeight;
  final double maxFullZeroRatio;
  final double maxRevealedZeroRatio;
  final int minNonZeroRevealedClues;

  static _LoopGateSeed lerp(_LoopGateSeed a, _LoopGateSeed b, double t) {
    int intLerp(int left, int right) => (left + (right - left) * t).round();
    double doubleLerp(double left, double right) => left + (right - left) * t;
    return _LoopGateSeed(
      minLoopEdgeCount: intLerp(a.minLoopEdgeCount, b.minLoopEdgeCount),
      minTouchedRows: intLerp(a.minTouchedRows, b.minTouchedRows),
      minTouchedCols: intLerp(a.minTouchedCols, b.minTouchedCols),
      minBoundingBoxWidth: intLerp(
        a.minBoundingBoxWidth,
        b.minBoundingBoxWidth,
      ),
      minBoundingBoxHeight: intLerp(
        a.minBoundingBoxHeight,
        b.minBoundingBoxHeight,
      ),
      maxFullZeroRatio: doubleLerp(a.maxFullZeroRatio, b.maxFullZeroRatio),
      maxRevealedZeroRatio: doubleLerp(
        a.maxRevealedZeroRatio,
        b.maxRevealedZeroRatio,
      ),
      minNonZeroRevealedClues: intLerp(
        a.minNonZeroRevealedClues,
        b.minNonZeroRevealedClues,
      ),
    );
  }
}

class _DensityBand {
  const _DensityBand(this.min, this.max);

  final double min;
  final double max;
}
