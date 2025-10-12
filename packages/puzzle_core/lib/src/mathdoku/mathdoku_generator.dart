import 'dart:math';

import '../generators/generator.dart';
import '../util/determinism.dart';
import '../util/seeded_rng.dart';
import 'mathdoku_board.dart';
import 'mathdoku_logic.dart';

class MathdokuGenerator extends PuzzleGenerator<MathdokuBoard> {
  const MathdokuGenerator();

  static const List<int> _supportedSizes = <int>[4, 6];

  @override
  PuzzleGenerationResult<MathdokuBoard> generate(GeneratorContext context) {
    final int width = context.size.width;
    final int height = context.size.height;
    if (width != height) {
      throw ArgumentError('Mathdoku requires square grids; got ${width}x$height');
    }
    if (!_supportedSizes.contains(width)) {
      throw ArgumentError('Unsupported Mathdoku size: ${width}x$height');
    }

    final Stopwatch stopwatch = Stopwatch()..start();

    final List<int> solution = _buildLatinSolution(context.rng, width);
    final List<MathdokuCage> cages = _carveCages(context.rng, width, solution);

    final MathdokuBoard puzzle = MathdokuBoard.empty(size: width, cages: cages);

    stopwatch.stop();

    final Map<String, Object?> telemetry = _buildTelemetry(
      size: width,
      cages: cages,
      durationUs: stopwatch.elapsedMicroseconds,
    );

    DeterminismGuard.assertNoFloatsOrDateTimes(puzzle.toJson());

    return PuzzleGenerationResult<MathdokuBoard>(
      board: puzzle,
      snapshot: GenerationSnapshot(telemetry: telemetry),
    );
  }

  List<int> _buildLatinSolution(SeededRng rng, int size) {
    final List<List<int>> base = List<List<int>>.generate(
      size,
      (int row) => List<int>.generate(size, (int col) => ((row + col) % size) + 1),
      growable: false,
    );

    final List<int> digitMap = List<int>.generate(size, (int index) => index + 1);
    rng.shuffle(digitMap);

    final List<int> rowOrder = rng.permute(List<int>.generate(size, (int i) => i));
    final List<int> colOrder = rng.permute(List<int>.generate(size, (int i) => i));

    final List<int> cells = List<int>.filled(size * size, 0);
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final int value = base[rowOrder[r]][colOrder[c]];
        cells[r * size + c] = digitMap[value - 1];
      }
    }
    return cells;
  }

  List<MathdokuCage> _carveCages(SeededRng rng, int size, List<int> solution) {
    final int cellCount = size * size;
    final Set<int> remaining = <int>{for (int i = 0; i < cellCount; i++) i};
    final List<MathdokuCage> cages = <MathdokuCage>[];
    int cageId = 0;

    while (remaining.isNotEmpty) {
      final int startIndex = _popRandom(rng, remaining);
      final List<int> cageCells = <int>[startIndex];

      final int maxAdditional = min(3, remaining.length);
      final List<int> sizeOptions =
          List<int>.generate(1 + maxAdditional, (int index) => index + 1);
      final List<int> weights = sizeOptions.map(_sizeWeight).toList();
      final int targetSize = rng.pickWeighted(sizeOptions, weights);

      while (cageCells.length < targetSize) {
        final List<int> neighbours =
            _availableNeighbours(cageCells, remaining, size);
        if (neighbours.isEmpty) {
          break;
        }
        final int next = neighbours[rng.nextIntInRange(neighbours.length)];
        cageCells.add(next);
        remaining.remove(next);
      }

      cageCells.sort();
      final List<int> cageValues =
          cageCells.map((int index) => solution[index]).toList(growable: false);
      final _OperationChoice choice = _selectOperation(rng, cageValues);
      cages.add(MathdokuCage(
        id: cageId++,
        cells: cageCells,
        operation: choice.operation,
        target: choice.target,
      ));
    }

    return cages;
  }

  int _popRandom(SeededRng rng, Set<int> pool) {
    final int index = rng.nextIntInRange(pool.length);
    final int value = pool.elementAt(index);
    pool.remove(value);
    return value;
  }

  List<int> _availableNeighbours(List<int> cageCells, Set<int> remaining, int size) {
    final Set<int> neighbours = <int>{};
    for (final int index in cageCells) {
      final int row = index ~/ size;
      final int col = index % size;
      if (row > 0) {
        final int up = index - size;
        if (remaining.contains(up)) {
          neighbours.add(up);
        }
      }
      if (row < size - 1) {
        final int down = index + size;
        if (remaining.contains(down)) {
          neighbours.add(down);
        }
      }
      if (col > 0) {
        final int left = index - 1;
        if (remaining.contains(left)) {
          neighbours.add(left);
        }
      }
      if (col < size - 1) {
        final int right = index + 1;
        if (remaining.contains(right)) {
          neighbours.add(right);
        }
      }
    }
    return neighbours.toList(growable: false);
  }

  _OperationChoice _selectOperation(SeededRng rng, List<int> values) {
    if (values.length == 1) {
      return _OperationChoice(MathdokuOperation.equality, values.first);
    }

    final List<_OperationChoice> options = <_OperationChoice>[];
    final int sum = values.reduce((int a, int b) => a + b);
    final int product = values.reduce((int a, int b) => a * b);
    options.add(_OperationChoice(MathdokuOperation.addition, sum));
    options.add(_OperationChoice(MathdokuOperation.multiplication, product));

    final Set<int> subtractionTargets = mathdokuSubtractionTargets(values);
    for (final int target in subtractionTargets) {
      options.add(_OperationChoice(MathdokuOperation.subtraction, target));
    }
    final Set<int> divisionTargets = mathdokuDivisionTargets(values);
    for (final int target in divisionTargets) {
      options.add(_OperationChoice(MathdokuOperation.division, target));
    }

    final List<int> weights =
        options.map((choice) => _operationWeight(choice.operation)).toList();
    final _OperationChoice choice = rng.pickWeighted(options, weights);
    return choice;
  }

  Map<String, Object?> _buildTelemetry({
    required int size,
    required List<MathdokuCage> cages,
    required int durationUs,
  }) {
    final int cageCount = cages.length;
    int maxSize = 0;
    int totalCells = 0;
    final Map<String, int> opCounts = <String, int>{
      'add': 0,
      'subtract': 0,
      'multiply': 0,
      'divide': 0,
      'equal': 0,
    };
    for (final MathdokuCage cage in cages) {
      maxSize = max(maxSize, cage.cells.length);
      totalCells += cage.cells.length;
      opCounts[cage.operation.jsonValue] =
          (opCounts[cage.operation.jsonValue] ?? 0) + 1;
    }
    final double avgSize = totalCells / cageCount;
    final _AdjacencyStats adjacency = _AdjacencyStats.fromCages(size, cages);

    return <String, Object?>{
      'durationUs': durationUs,
      'cageCount': cageCount,
      'maxCageSize': maxSize,
      'avgCageSize': avgSize,
      'opCounts': opCounts,
      'adjacentEdges': adjacency.edges,
      'graphDensity': adjacency.density,
    };
  }
}

class _OperationChoice {
  final MathdokuOperation operation;
  final int target;

  const _OperationChoice(this.operation, this.target);
}

int _sizeWeight(int size) {
  switch (size) {
    case 1:
      return 3;
    case 2:
      return 4;
    case 3:
      return 3;
    case 4:
      return 2;
    default:
      return 1;
  }
}

int _operationWeight(MathdokuOperation op) {
  switch (op) {
    case MathdokuOperation.addition:
      return 4;
    case MathdokuOperation.multiplication:
      return 3;
    case MathdokuOperation.subtraction:
      return 2;
    case MathdokuOperation.division:
      return 2;
    case MathdokuOperation.equality:
      return 5;
  }
}

class _AdjacencyStats {
  final int edges;
  final double density;

  const _AdjacencyStats({required this.edges, required this.density});

  factory _AdjacencyStats.fromCages(int size, List<MathdokuCage> cages) {
    final Map<int, int> cageIndexByCell = <int, int>{};
    for (int i = 0; i < cages.length; i++) {
      for (final int cell in cages[i].cells) {
        cageIndexByCell[cell] = i;
      }
    }
    final Set<int> seenPairs = <int>{};
    int edgeCount = 0;
    for (int index = 0; index < size * size; index++) {
      final int cageA = cageIndexByCell[index]!;
      final int row = index ~/ size;
      final int col = index % size;
      void consider(int neighbour) {
        final int cageB = cageIndexByCell[neighbour]!;
        if (cageA == cageB) {
          return;
        }
        final int key = cageA < cageB
            ? (cageA << 16) | cageB
            : (cageB << 16) | cageA;
        if (seenPairs.add(key)) {
          edgeCount++;
        }
      }

      if (row > 0) {
        consider(index - size);
      }
      if (row < size - 1) {
        consider(index + size);
      }
      if (col > 0) {
        consider(index - 1);
      }
      if (col < size - 1) {
        consider(index + 1);
      }
    }

    final int cageCount = cages.length;
    final int possibleEdges = cageCount <= 1 ? 0 : cageCount * (cageCount - 1) ~/ 2;
    final double density = possibleEdges == 0 ? 0.0 : edgeCount / possibleEdges;
    return _AdjacencyStats(edges: edgeCount, density: density);
  }
}
