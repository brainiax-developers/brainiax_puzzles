import 'dart:math';

import '../difficulty/telemetry.dart';
import 'mathdoku_board.dart';

class MathdokuDifficultyScorer extends DifficultyScorer<MathdokuBoard> {
  const MathdokuDifficultyScorer();

  @override
  DifficultyTelemetry score({
    required MathdokuBoard puzzle,
    required MathdokuBoard solution,
    required DifficultyContext context,
  }) {
    final Map<String, Object?> generator = context.generatorTelemetry;
    final Map<String, Object?> solver = context.solverTelemetry;

    final int cageCount = (generator['cageCount'] as num?)?.toInt() ?? puzzle.cages.length;
    final double avgCageSize =
        (generator['avgCageSize'] as num?)?.toDouble() ?? _avgCageSize(puzzle);
    final int maxCageSize =
        (generator['maxCageSize'] as num?)?.toInt() ?? _maxCageSize(puzzle);
    final double graphDensity =
        (generator['graphDensity'] as num?)?.toDouble() ?? _graphDensity(puzzle);

    final Map<String, num> opCounts = <String, num>{};
    final Map<String, Object?> rawOpCounts =
        (generator['opCounts'] as Map?)?.cast<String, Object?>() ?? const <String, Object?>{};
    for (final MapEntry<String, Object?> entry in rawOpCounts.entries) {
      final num? value = entry.value as num?;
      if (value != null) {
        opCounts[entry.key] = value;
      }
    }

    final double subtractionRatio = cageCount == 0
        ? 0.0
        : ((opCounts['subtract'] ?? 0).toDouble() + (opCounts['divide'] ?? 0).toDouble()) /
            cageCount;
    final double multiplicationRatio = cageCount == 0
        ? 0.0
        : (opCounts['multiply'] ?? 0).toDouble() / cageCount;

    final double propagationDepth =
        (solver['propagationDepth'] as num?)?.toDouble() ?? 0.0;
    final double searchDepth = (solver['searchDepth'] as num?)?.toDouble() ?? 0.0;
    final double searchNodes = (solver['searchNodes'] as num?)?.toDouble() ?? 0.0;

    final double cageComplexity = avgCageSize * 1.6 + maxCageSize * 2.4;
    final double opPressure = subtractionRatio * 38.0 + multiplicationRatio * 15.0;
    final double solverPressure = propagationDepth * 3.0 + searchDepth * 5.2 + searchNodes / 9.0;
    final double adjacencyPressure = graphDensity * 26.0;

    final double rawScore = cageComplexity + opPressure + solverPressure + adjacencyPressure;

    final Map<String, num> metrics = <String, num>{
      'cageCount': cageCount,
      'avgCageSize': avgCageSize,
      'maxCageSize': maxCageSize,
      'graphDensity': graphDensity,
      'subtractiveRatio': subtractionRatio,
      'multiplicativeRatio': multiplicationRatio,
      'propagationDepth': propagationDepth,
      'searchDepth': searchDepth,
      'searchNodes': searchNodes,
    };

    return DifficultyTelemetry(
      rawScore: rawScore,
      bucket: 'pending',
      metrics: metrics,
    );
  }

  double _avgCageSize(MathdokuBoard board) {
    if (board.cages.isEmpty) {
      return 0.0;
    }
    final int total = board.cages.fold<int>(0, (int sum, MathdokuCage cage) => sum + cage.cells.length);
    return total / board.cages.length;
  }

  int _maxCageSize(MathdokuBoard board) {
    if (board.cages.isEmpty) {
      return 0;
    }
    return board.cages.map<int>((MathdokuCage cage) => cage.cells.length).reduce(max);
  }

  double _graphDensity(MathdokuBoard board) {
    final int cageCount = board.cages.length;
    if (cageCount <= 1) {
      return 0.0;
    }
    final Map<int, int> cageIndexByCell = <int, int>{};
    for (int i = 0; i < board.cages.length; i++) {
      for (final int cell in board.cages[i].cells) {
        cageIndexByCell[cell] = i;
      }
    }
    final Set<int> edges = <int>{};
    for (int index = 0; index < board.cellCount; index++) {
      final int cageA = cageIndexByCell[index]!;
      final int row = index ~/ board.size;
      final int col = index % board.size;
      void consider(int neighbour) {
        final int cageB = cageIndexByCell[neighbour]!;
        if (cageA == cageB) {
          return;
        }
        final int key = cageA < cageB ? (cageA << 16) | cageB : (cageB << 16) | cageA;
        edges.add(key);
      }

      if (row > 0) {
        consider(index - board.size);
      }
      if (row < board.size - 1) {
        consider(index + board.size);
      }
      if (col > 0) {
        consider(index - 1);
      }
      if (col < board.size - 1) {
        consider(index + 1);
      }
    }

    final int possibleEdges = cageCount * (cageCount - 1) ~/ 2;
    if (possibleEdges == 0) {
      return 0.0;
    }
    return edges.length / possibleEdges;
  }
}
