import 'dart:math';

import '../generators/generator.dart';
import '../util/determinism.dart';
import '../util/seeded_rng.dart';
import 'mathdoku_board.dart';
import 'mathdoku_logic.dart';

class _DifficultyProfile {
  const _DifficultyProfile({
    required this.cageSizeWeights,
    required this.operationWeights,
    required this.nonCommutativeTarget,
    required this.maxCageSize,
  });

  /// Relative weights for selecting target cage sizes.
  final Map<int, int> cageSizeWeights;

  /// Relative weights for selecting operations.
  final Map<MathdokuOperation, int> operationWeights;

  /// Desired ratio of subtraction/division cages once generation is complete.
  final double nonCommutativeTarget;

  /// Maximum number of cells in a cage for this difficulty.
  final int maxCageSize;
}

class MathdokuGenerator extends PuzzleGenerator<MathdokuBoard> {
  const MathdokuGenerator();

  // Expanded to include 9x9 per Phase-3 UX requirements.
  static const List<int> _supportedSizes = <int>[4, 6, 9];

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
    final List<MathdokuCage> cages = _carveCages(
      context.rng,
      width,
      solution,
      context.difficulty,
    );

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

  List<MathdokuCage> _carveCages(
    SeededRng rng,
    int size,
    List<int> solution,
    DifficultyRequest difficulty,
  ) {
    final _DifficultyProfile profile =
        _profileForDifficulty(difficulty.level.toLowerCase());
    final int cellCount = size * size;
    final Set<int> remaining = <int>{for (int i = 0; i < cellCount; i++) i};
    final List<MathdokuCage> cages = <MathdokuCage>[];
    final Map<MathdokuOperation, int> opCounts = <MathdokuOperation, int>{};
    int cageId = 0;

    while (remaining.isNotEmpty) {
      final int startIndex = _popRandom(rng, remaining);
      final List<int> cageCells = <int>[startIndex];

      final int maxAdditional =
          min(profile.maxCageSize - 1, remaining.length);
      final List<int> sizeOptions =
          List<int>.generate(1 + maxAdditional, (int index) => index + 1);
      final List<int> weights = sizeOptions
          .map((int option) => _sizeWeight(profile, option))
          .toList(growable: false);
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
      final _OperationChoice choice = _selectOperation(
        rng,
        values: cageValues,
        profile: profile,
        opCounts: opCounts,
        placedCages: cageId == 0 ? 1 : cageId,
      );
      opCounts[choice.operation] = (opCounts[choice.operation] ?? 0) + 1;
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

  _OperationChoice _selectOperation(
    SeededRng rng, {
    required List<int> values,
    required _DifficultyProfile profile,
    required Map<MathdokuOperation, int> opCounts,
    required int placedCages,
  }) {
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

    // Safety fallback: if filtering removed all multi-cell ops, use addition.
    if (options.isEmpty) {
      options.add(_OperationChoice(MathdokuOperation.addition, sum));
    }

    final int cageSize = values.length;
    final List<int> weights = options
        .map((choice) => _operationWeight(
              choice: choice,
              profile: profile,
              opCounts: opCounts,
              placedCages: placedCages,
              cageSize: cageSize,
            ))
        .toList(growable: false);
    return rng.pickWeighted(options, weights);
  }

  Map<String, Object?> _buildTelemetry({
    required int size,
    required List<MathdokuCage> cages,
    required int durationUs,
  }) {
    final int cageCount = cages.length;
    int maxSize = 0;
    int totalCells = 0;
    int singleCageCount = 0;
    int longCageCount = 0;
    final Map<String, int> opCounts = <String, int>{
      'add': 0,
      'subtract': 0,
      'multiply': 0,
      'divide': 0,
      'equal': 0,
    };
    final Map<String, int> sizeHistogram = <String, int>{};
    for (final MathdokuCage cage in cages) {
      final int len = cage.cells.length;
      maxSize = max(maxSize, len);
      totalCells += len;
      if (len == 1) {
        singleCageCount++;
      } else if (len >= 3) {
        longCageCount++;
      }
      sizeHistogram['$len'] = (sizeHistogram['$len'] ?? 0) + 1;
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
      'singleCageCount': singleCageCount,
      'longCageCount': longCageCount,
      'sizeHistogram': sizeHistogram,
    };
  }
}

class _OperationChoice {
  final MathdokuOperation operation;
  final int target;

  const _OperationChoice(this.operation, this.target);
}

int _sizeWeight(_DifficultyProfile profile, int size) {
  final int weight = profile.cageSizeWeights[size] ?? 1;
  return weight < 1 ? 1 : weight;
}

int _operationWeight({
  required _OperationChoice choice,
  required _DifficultyProfile profile,
  required Map<MathdokuOperation, int> opCounts,
  required int placedCages,
  required int cageSize,
}) {
  double weight = (profile.operationWeights[choice.operation] ?? 1).toDouble();

  if (_isNonCommutative(choice.operation)) {
    weight *= _nonCommutativeMultiplier(profile, opCounts, placedCages);
    if (cageSize == 2) {
      // Two-cell subtraction/division cages are clear but still constraining.
      weight *= 1.1;
    }
  }

  if (choice.operation == MathdokuOperation.multiplication && cageSize >= 3) {
    weight *= 1.1;
  }
  if (choice.operation == MathdokuOperation.equality && cageSize == 1) {
    // Keep givens in circulation without overwhelming higher difficulties.
    weight *= 0.9;
  }

  final int rounded = weight.round();
  return rounded < 1 ? 1 : rounded;
}

bool _isNonCommutative(MathdokuOperation operation) {
  return operation == MathdokuOperation.subtraction ||
      operation == MathdokuOperation.division;
}

double _nonCommutativeMultiplier(
  _DifficultyProfile profile,
  Map<MathdokuOperation, int> opCounts,
  int placedCages,
) {
  final int total = placedCages <= 0 ? 1 : placedCages;
  final int currentNonCommutative =
      (opCounts[MathdokuOperation.subtraction] ?? 0) +
          (opCounts[MathdokuOperation.division] ?? 0);
  final double ratio = currentNonCommutative / total;
  if (ratio + 0.05 < profile.nonCommutativeTarget) {
    return 1.6;
  }
  if (ratio > profile.nonCommutativeTarget + 0.12) {
    return 0.85;
  }
  return 1.0;
}

_DifficultyProfile _profileForDifficulty(String level) {
  switch (level) {
    case 'easy':
      return const _DifficultyProfile(
        cageSizeWeights: <int, int>{1: 6, 2: 6, 3: 2},
        operationWeights: <MathdokuOperation, int>{
          MathdokuOperation.addition: 5,
          MathdokuOperation.subtraction: 1,
          MathdokuOperation.multiplication: 1,
          MathdokuOperation.division: 1,
          MathdokuOperation.equality: 5,
        },
        nonCommutativeTarget: 0.14,
        maxCageSize: 3,
      );
    case 'medium':
      return const _DifficultyProfile(
        cageSizeWeights: <int, int>{1: 5, 2: 6, 3: 4, 4: 2},
        operationWeights: <MathdokuOperation, int>{
          MathdokuOperation.addition: 4,
          MathdokuOperation.subtraction: 2,
          MathdokuOperation.multiplication: 2,
          MathdokuOperation.division: 2,
          MathdokuOperation.equality: 4,
        },
        nonCommutativeTarget: 0.24,
        maxCageSize: 4,
      );
    case 'hard':
      return const _DifficultyProfile(
        cageSizeWeights: <int, int>{1: 3, 2: 5, 3: 5, 4: 3},
        operationWeights: <MathdokuOperation, int>{
          MathdokuOperation.addition: 3,
          MathdokuOperation.subtraction: 3,
          MathdokuOperation.multiplication: 3,
          MathdokuOperation.division: 2,
          MathdokuOperation.equality: 2,
        },
        nonCommutativeTarget: 0.34,
        maxCageSize: 4,
      );
    case 'expert':
      return const _DifficultyProfile(
        cageSizeWeights: <int, int>{1: 2, 2: 4, 3: 5, 4: 5},
        operationWeights: <MathdokuOperation, int>{
          MathdokuOperation.addition: 3,
          MathdokuOperation.subtraction: 4,
          MathdokuOperation.multiplication: 4,
          MathdokuOperation.division: 3,
          MathdokuOperation.equality: 1,
        },
        nonCommutativeTarget: 0.46,
        maxCageSize: 4,
      );
    default:
      return const _DifficultyProfile(
        cageSizeWeights: <int, int>{1: 5, 2: 5, 3: 3, 4: 2},
        operationWeights: <MathdokuOperation, int>{
          MathdokuOperation.addition: 4,
          MathdokuOperation.subtraction: 2,
          MathdokuOperation.multiplication: 2,
          MathdokuOperation.division: 2,
          MathdokuOperation.equality: 3,
        },
        nonCommutativeTarget: 0.25,
        maxCageSize: 4,
      );
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
