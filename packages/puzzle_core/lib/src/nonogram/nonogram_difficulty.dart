import '../difficulty/telemetry.dart';
import '../util/nonogram.dart';
import 'nonogram_board.dart';

class NonogramDifficultyScorer extends DifficultyScorer<NonogramBoard> {
  const NonogramDifficultyScorer();

  @override
  DifficultyTelemetry score({
    required NonogramBoard puzzle,
    required NonogramBoard solution,
    required DifficultyContext context,
  }) {
    final Map<String, Object?> solverTelemetry = context.solverTelemetry;
    final double logicCompletion = _bounded(
      _asDouble(solverTelemetry['logicCompletion']),
      0.0,
      1.0,
    );
    final int propagationRounds = _asInt(
      solverTelemetry['propagationRounds'] ?? solverTelemetry['lineIterations'],
    );
    final int visitedNodes = _asInt(solverTelemetry['visitedNodes']);
    final int maxDepth = _asInt(
      solverTelemetry['maxDepth'] ?? solverTelemetry['maxDepthReached'],
    );
    final int branchCount = _asInt(solverTelemetry['branchCount']);
    final int contradictionCount = _asInt(
      solverTelemetry['contradictionCount'],
    );
    final int speculativeSteps = _asInt(solverTelemetry['speculativeSteps']);
    final bool proofIncomplete = solverTelemetry['proofIncomplete'] == true;

    final _StructureMetrics structure = _structureMetrics(puzzle);
    final _VisualMetrics visual = _visualMetrics(solution);

    final double lineCount = (puzzle.width + puzzle.height).toDouble();
    final double logicPenalty = (1.0 - logicCompletion) * 45.0;
    final double propagationPenalty =
        _bounded(propagationRounds / (lineCount * 0.55), 0.0, 2.0) * 7.0;
    final double searchPenalty =
        speculativeSteps * 4.0 +
        visitedNodes * 2.5 +
        maxDepth * 9.0 +
        branchCount * 10.0 +
        contradictionCount * 5.0 +
        (proofIncomplete ? 18.0 : 0.0);

    final double densityPenalty = (structure.fillDensity - 0.45).abs() * 12.0;
    final double clueCountPenalty = structure.averageCluesPerLine * 8.0;
    final double maxCluePenalty = structure.maxCluesPerLine * 2.0;
    final double shortCluePenalty = structure.averageClueLength <= 0.0
        ? 0.0
        : (structure.averageClueLength < 3.2
              ? (3.2 - structure.averageClueLength) * 5.0
              : 0.0);
    final double longCluePenalty = structure.averageClueLength > 7.0
        ? (structure.averageClueLength - 7.0) * 1.5
        : 0.0;
    final double fragmentationPenalty =
        _positive(structure.fragmentation - 0.9) * 8.0 +
        _positive(structure.alternation - 1.1) * 8.0;
    final double structuralPenalty =
        densityPenalty +
        clueCountPenalty +
        maxCluePenalty +
        shortCluePenalty +
        longCluePenalty +
        fragmentationPenalty;

    final double singletonPenalty = visual.isolatedSingletonRatio * 40.0;
    final double checkerboardPenalty = visual.checkerboardAlternation > 0.62
        ? (visual.checkerboardAlternation - 0.62) * 55.0
        : 0.0;
    final double blobPenalty = visual.giantSolidBlobRatio > 0.75
        ? (visual.giantSolidBlobRatio - 0.75) * 12.0
        : 0.0;
    final double emptyFullLinePenalty = visual.emptyFullLineRatio * 12.0;
    final double visualPenalty =
        singletonPenalty +
        checkerboardPenalty +
        blobPenalty +
        emptyFullLinePenalty;

    final double rawScore =
        logicPenalty +
        propagationPenalty +
        searchPenalty +
        structuralPenalty +
        visualPenalty;

    final Map<String, num> metrics = <String, num>{
      'logicCompletion': logicCompletion,
      'propagationRounds': propagationRounds,
      'visitedNodes': visitedNodes,
      'maxDepth': maxDepth,
      'branchCount': branchCount,
      'contradictionCount': contradictionCount,
      'speculativeSteps': speculativeSteps,
      'fillDensity': structure.fillDensity,
      'averageCluesPerLine': structure.averageCluesPerLine,
      'maxCluesPerLine': structure.maxCluesPerLine,
      'averageClueLength': structure.averageClueLength,
      'alternation': structure.alternation,
      'fragmentation': structure.fragmentation,
      'isolatedSingletonRatio': visual.isolatedSingletonRatio,
      'checkerboardAlternation': visual.checkerboardAlternation,
      'giantSolidBlobRatio': visual.giantSolidBlobRatio,
      'emptyFullLineRatio': visual.emptyFullLineRatio,
      'logicPenalty': logicPenalty,
      'propagationPenalty': propagationPenalty,
      'searchPenalty': searchPenalty,
      'densityPenalty': densityPenalty,
      'clueCountPenalty': clueCountPenalty,
      'maxCluePenalty': maxCluePenalty,
      'fragmentationPenalty': fragmentationPenalty,
      'shortCluePenalty': shortCluePenalty,
      'longCluePenalty': longCluePenalty,
      'structuralPenalty': structuralPenalty,
      'singletonPenalty': singletonPenalty,
      'checkerboardPenalty': checkerboardPenalty,
      'blobPenalty': blobPenalty,
      'emptyFullLinePenalty': emptyFullLinePenalty,
      'visualPenalty': visualPenalty,
      'rawScore': rawScore,
    };

    return DifficultyTelemetry(
      rawScore: rawScore,
      bucket: 'pending',
      metrics: metrics,
    );
  }

  _StructureMetrics _structureMetrics(NonogramBoard board) {
    int totalLength = 0;
    int totalClues = 0;
    int maxCluesPerLine = 0;
    int nonEmptyLines = 0;

    for (final List<int> clues in board.rowClues) {
      if (clues.isNotEmpty) {
        nonEmptyLines++;
      }
      if (clues.length > maxCluesPerLine) {
        maxCluesPerLine = clues.length;
      }
      for (final int value in clues) {
        totalLength += value;
        totalClues++;
      }
    }
    for (final List<int> clues in board.columnClues) {
      if (clues.isNotEmpty) {
        nonEmptyLines++;
      }
      if (clues.length > maxCluesPerLine) {
        maxCluesPerLine = clues.length;
      }
      for (final int value in clues) {
        totalLength += value;
        totalClues++;
      }
    }

    final int lineCount = board.width + board.height;
    final double averageCluesPerLine = lineCount == 0
        ? 0.0
        : totalClues / lineCount;
    final double averageClueLength = totalClues == 0
        ? 0.0
        : totalLength / totalClues;
    final double fillDensity = board.cellCount == 0
        ? 0.0
        : totalLength / (board.cellCount * 2.0);
    final double fragmentation = lineCount == 0 ? 0.0 : totalClues / lineCount;
    final double alternation = nonEmptyLines == 0
        ? 0.0
        : totalClues / nonEmptyLines;

    return _StructureMetrics(
      fillDensity: fillDensity,
      averageCluesPerLine: averageCluesPerLine,
      maxCluesPerLine: maxCluesPerLine.toDouble(),
      averageClueLength: averageClueLength,
      alternation: alternation,
      fragmentation: fragmentation,
    );
  }

  _VisualMetrics _visualMetrics(NonogramBoard solution) {
    final int cellCount = solution.cellCount;
    if (cellCount == 0) {
      return const _VisualMetrics(
        isolatedSingletonRatio: 0.0,
        checkerboardAlternation: 0.0,
        giantSolidBlobRatio: 0.0,
        emptyFullLineRatio: 0.0,
      );
    }

    int filledCount = 0;
    int isolatedSingletons = 0;
    int differentNeighborPairs = 0;
    int neighborPairs = 0;
    int emptyOrFullLines = 0;

    for (int row = 0; row < solution.height; row++) {
      int rowFilled = 0;
      for (int col = 0; col < solution.width; col++) {
        if (_isFilled(solution, row, col)) {
          filledCount++;
          rowFilled++;
        }
        if (col + 1 < solution.width) {
          neighborPairs++;
          if (_isFilled(solution, row, col) !=
              _isFilled(solution, row, col + 1)) {
            differentNeighborPairs++;
          }
        }
        if (row + 1 < solution.height) {
          neighborPairs++;
          if (_isFilled(solution, row, col) !=
              _isFilled(solution, row + 1, col)) {
            differentNeighborPairs++;
          }
        }
      }
      if (rowFilled == 0 || rowFilled == solution.width) {
        emptyOrFullLines++;
      }
    }

    for (int col = 0; col < solution.width; col++) {
      int columnFilled = 0;
      for (int row = 0; row < solution.height; row++) {
        if (_isFilled(solution, row, col)) {
          columnFilled++;
        }
      }
      if (columnFilled == 0 || columnFilled == solution.height) {
        emptyOrFullLines++;
      }
    }

    if (filledCount == 0) {
      final double emptyFullLineRatio =
          emptyOrFullLines / (solution.width + solution.height);
      return _VisualMetrics(
        isolatedSingletonRatio: 0.0,
        checkerboardAlternation: neighborPairs == 0
            ? 0.0
            : differentNeighborPairs / neighborPairs,
        giantSolidBlobRatio: 0.0,
        emptyFullLineRatio: emptyFullLineRatio,
      );
    }

    for (int row = 0; row < solution.height; row++) {
      for (int col = 0; col < solution.width; col++) {
        if (!_isFilled(solution, row, col)) {
          continue;
        }
        if (!_hasFilledNeighbor(solution, row, col)) {
          isolatedSingletons++;
        }
      }
    }

    final double emptyFullLineRatio =
        emptyOrFullLines / (solution.width + solution.height);
    return _VisualMetrics(
      isolatedSingletonRatio: isolatedSingletons / filledCount,
      checkerboardAlternation: neighborPairs == 0
          ? 0.0
          : differentNeighborPairs / neighborPairs,
      giantSolidBlobRatio: _largestFilledComponent(solution) / filledCount,
      emptyFullLineRatio: emptyFullLineRatio,
    );
  }

  bool _isFilled(NonogramBoard board, int row, int col) {
    return board.cellAt(row, col) == NonogramLineSolver.filled;
  }

  bool _hasFilledNeighbor(NonogramBoard board, int row, int col) {
    return (row > 0 && _isFilled(board, row - 1, col)) ||
        (row + 1 < board.height && _isFilled(board, row + 1, col)) ||
        (col > 0 && _isFilled(board, row, col - 1)) ||
        (col + 1 < board.width && _isFilled(board, row, col + 1));
  }

  int _largestFilledComponent(NonogramBoard board) {
    final List<bool> visited = List<bool>.filled(board.cellCount, false);
    int largest = 0;

    for (int index = 0; index < board.cellCount; index++) {
      if (visited[index] || board.cells[index] != NonogramLineSolver.filled) {
        continue;
      }
      int size = 0;
      final List<int> stack = <int>[index];
      visited[index] = true;
      while (stack.isNotEmpty) {
        final int current = stack.removeLast();
        size++;
        final int row = current ~/ board.width;
        final int col = current % board.width;
        _pushFilledNeighbor(board, visited, stack, row - 1, col);
        _pushFilledNeighbor(board, visited, stack, row + 1, col);
        _pushFilledNeighbor(board, visited, stack, row, col - 1);
        _pushFilledNeighbor(board, visited, stack, row, col + 1);
      }
      if (size > largest) {
        largest = size;
      }
    }

    return largest;
  }

  void _pushFilledNeighbor(
    NonogramBoard board,
    List<bool> visited,
    List<int> stack,
    int row,
    int col,
  ) {
    if (row < 0 || row >= board.height || col < 0 || col >= board.width) {
      return;
    }
    final int index = board.indexOf(row, col);
    if (visited[index] || board.cells[index] != NonogramLineSolver.filled) {
      return;
    }
    visited[index] = true;
    stack.add(index);
  }

  int _asInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  double _bounded(double value, double min, double max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  double _positive(double value) {
    return value > 0.0 ? value : 0.0;
  }

  double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0.0;
  }
}

class _StructureMetrics {
  const _StructureMetrics({
    required this.fillDensity,
    required this.averageCluesPerLine,
    required this.maxCluesPerLine,
    required this.averageClueLength,
    required this.alternation,
    required this.fragmentation,
  });

  final double fillDensity;
  final double averageCluesPerLine;
  final double maxCluesPerLine;
  final double averageClueLength;
  final double alternation;
  final double fragmentation;
}

class _VisualMetrics {
  const _VisualMetrics({
    required this.isolatedSingletonRatio,
    required this.checkerboardAlternation,
    required this.giantSolidBlobRatio,
    required this.emptyFullLineRatio,
  });

  final double isolatedSingletonRatio;
  final double checkerboardAlternation;
  final double giantSolidBlobRatio;
  final double emptyFullLineRatio;
}
