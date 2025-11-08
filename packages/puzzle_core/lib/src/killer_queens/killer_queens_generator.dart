import '../generators/generator.dart';
import '../util/seeded_rng.dart';
import 'killer_queens_board.dart';

class KillerQueensGenerator extends PuzzleGenerator<KillerQueensBoard> {
  const KillerQueensGenerator();

  @override
  PuzzleGenerationResult<KillerQueensBoard> generate(GeneratorContext context) {
    final int width = context.size.width;
    final int height = context.size.height;
    if (width != height) {
      throw ArgumentError(
        'Killer Queens requires square grids; got ${width}x$height',
      );
    }
    if (width < 6 || width > 12) {
      throw ArgumentError(
        'Unsupported Killer Queens size: ${width}x$height. Supported: 6-12',
      );
    }

    final _TierParameters tier = _TierParameters.fromRequest(
      context.difficulty.level,
      width,
      context.rng,
    );

    final int maxAttempts = 24;
    late List<bool> blocked;
    late List<KillerQueensCage> cages;
    late List<int> queenIndices;
    int attempt = 0;

    while (attempt < maxAttempts) {
      attempt += 1;
      blocked = _buildBlocked(width, tier, context.rng);
      cages = _buildCages(width, blocked, tier, context.rng);
      queenIndices = _solveLayout(width, blocked, cages, context.rng);
      if (queenIndices.isNotEmpty) {
        break;
      }
    }

    if (queenIndices.isEmpty) {
      throw StateError('Failed to generate Killer Queens layout after $maxAttempts attempts');
    }

    final int cellCount = width * width;
    final List<int> puzzleCells = List<int>.filled(cellCount, 0);
    final List<bool> fixed = List<bool>.filled(cellCount, false);

    final int givens = tier.sampleGivens(context.rng, queenIndices.length);
    final List<int> givensPool = List<int>.from(queenIndices);
    context.rng.shuffle(givensPool);
    for (int i = 0; i < givens; i++) {
      final int index = givensPool[i];
      puzzleCells[index] = 1;
      fixed[index] = true;
    }

    final KillerQueensBoard puzzle = KillerQueensBoard(
      size: width,
      cells: puzzleCells,
      fixed: fixed,
      blocked: blocked,
      cages: cages,
    );

    return PuzzleGenerationResult<KillerQueensBoard>(
      board: puzzle,
      snapshot: GenerationSnapshot(
        telemetry: <String, Object?>{
          'tier': tier.tier,
          'attempts': attempt,
          'blockedCells': blocked.where((bool value) => value).length,
          'givens': givens,
          'cageCount': cages.length,
        },
      ),
    );
  }
}

class _TierParameters {
  _TierParameters({
    required this.tier,
    required this.blockedRange,
    required this.cageSizeRange,
    required this.givensRange,
  });

  final String tier;
  final (int min, int max) blockedRange;
  final (int min, int max) cageSizeRange;
  final (int min, int max) givensRange;

  static _TierParameters fromRequest(String requestedLevel, int size, SeededRng rng) {
    final String tier = _normalizeTier(requestedLevel, size);
    switch (tier) {
      case 'easy':
        return _TierParameters(
          tier: tier,
          blockedRange: (0, 0),
          cageSizeRange: (2, 3),
          givensRange: (2, 4),
        );
      case 'medium':
        return _TierParameters(
          tier: tier,
          blockedRange: (0, 2),
          cageSizeRange: (3, 4),
          givensRange: (1, 3),
        );
      case 'hard':
        return _TierParameters(
          tier: tier,
          blockedRange: (2, 4),
          cageSizeRange: (4, 5),
          givensRange: (0, 0),
        );
      case 'expert':
      default:
        return _TierParameters(
          tier: 'expert',
          blockedRange: (3, 6),
          cageSizeRange: (3, 6),
          givensRange: (0, 0),
        );
    }
  }

  static String _normalizeTier(String requestedLevel, int size) {
    final String normalized = requestedLevel.toLowerCase();
    if (normalized == 'easy' || normalized == 'medium' || normalized == 'hard' || normalized == 'expert') {
      return normalized;
    }
    if (size <= 7) {
      return 'easy';
    }
    if (size <= 9) {
      return 'medium';
    }
    if (size <= 10) {
      return 'hard';
    }
    return 'expert';
  }

  int sampleBlocked(SeededRng rng) {
    final int min = blockedRange.$1;
    final int max = blockedRange.$2;
    if (min == max) {
      return min;
    }
    return rng.randIntRange(min, max + 1);
  }

  int sampleCageSize(SeededRng rng) {
    final int min = cageSizeRange.$1;
    final int max = cageSizeRange.$2;
    if (min == max) {
      return min;
    }
    return rng.randIntRange(min, max + 1);
  }

  int sampleGivens(SeededRng rng, int queenCount) {
    final int min = givensRange.$1;
    final int max = givensRange.$2;
    if (max == 0) {
      return 0;
    }
    if (min == max) {
      return min.clamp(0, queenCount);
    }
    final int sampled = rng.randIntRange(min, max + 1);
    return sampled.clamp(0, queenCount);
  }
}

List<bool> _buildBlocked(int size, _TierParameters tier, SeededRng rng) {
  final int cellCount = size * size;
  final List<bool> blocked = List<bool>.filled(cellCount, false);
  final int blockedCells = tier.sampleBlocked(rng).clamp(0, cellCount ~/ 2);
  if (blockedCells == 0) {
    return blocked;
  }

  final List<int> positions = List<int>.generate(cellCount, (int index) => index);
  rng.shuffle(positions);
  int placed = 0;
  final List<int> rowCounts = List<int>.filled(size, 0);
  final List<int> colCounts = List<int>.filled(size, 0);
  for (final int index in positions) {
    final int row = index ~/ size;
    final int col = index % size;
    if (rowCounts[row] >= size - 1 || colCounts[col] >= size - 1) {
      continue;
    }
    blocked[index] = true;
    rowCounts[row] += 1;
    colCounts[col] += 1;
    placed += 1;
    if (placed >= blockedCells) {
      break;
    }
  }
  return blocked;
}

List<KillerQueensCage> _buildCages(
  int size,
  List<bool> blocked,
  _TierParameters tier,
  SeededRng rng,
) {
  final int cellCount = size * size;
  final List<int> assignments = List<int>.filled(cellCount, -1);
  final List<KillerQueensCage> cages = <KillerQueensCage>[];

  int cageIndex = 0;
  for (int index = 0; index < cellCount; index++) {
    if (blocked[index] || assignments[index] != -1) {
      continue;
    }
    final int targetSize = tier.sampleCageSize(rng);
    final List<int> cageCells = <int>[];
    final List<int> frontier = <int>[index];

    while (frontier.isNotEmpty && cageCells.length < targetSize) {
      final int candidate = frontier.removeLast();
      if (assignments[candidate] != -1 || blocked[candidate]) {
        continue;
      }
      assignments[candidate] = cageIndex;
      cageCells.add(candidate);

      final int row = candidate ~/ size;
      final int col = candidate % size;
      final List<int> neighbors = <int>[
        if (row > 0) candidate - size,
        if (row < size - 1) candidate + size,
        if (col > 0) candidate - 1,
        if (col < size - 1) candidate + 1,
      ];
      rng.shuffle(neighbors);
      for (final int neighbor in neighbors) {
        if (!blocked[neighbor] && assignments[neighbor] == -1) {
          frontier.add(neighbor);
        }
      }
    }

    if (cageCells.isEmpty) {
      continue;
    }

    cages.add(KillerQueensCage(cells: List<int>.unmodifiable(cageCells)));
    cageIndex += 1;
  }

  // Assign any leftover single cells to their own cages.
  for (int index = 0; index < cellCount; index++) {
    if (blocked[index] || assignments[index] != -1) {
      continue;
    }
    assignments[index] = cageIndex;
    cages.add(KillerQueensCage(cells: <int>[index]));
    cageIndex += 1;
  }

  return cages;
}

List<int> _solveLayout(
  int size,
  List<bool> blocked,
  List<KillerQueensCage> cages,
  SeededRng rng,
) {
  final List<int> cageByCell = KillerQueensBoard.buildCageByCell(size, blocked, cages);
  final List<int> rowOrder = List<int>.generate(size, (int index) => index);
  final List<int> columnOrder = List<int>.generate(size, (int index) => index);
  rng.shuffle(rowOrder);
  rng.shuffle(columnOrder);

  final List<int> rowAssignments = List<int>.filled(size, -1);
  final List<bool> columnUsed = List<bool>.filled(size, false);
  final List<int> cageUsage = List<int>.filled(cages.length, 0);
  final List<int> queens = <int>[];

  bool search(int depth) {
    if (depth >= size) {
      return true;
    }
    final int row = rowOrder[depth];
    final List<int> candidates = List<int>.from(columnOrder);
    rng.shuffle(candidates);

    for (final int col in candidates) {
      final int index = row * size + col;
      if (blocked[index] || columnUsed[col]) {
        continue;
      }
      final int cageIndex = cageByCell[index];
      if (cageIndex != -1 && cageUsage[cageIndex] >= 1) {
        continue;
      }
      bool clashes = false;
      for (final int queen in queens) {
        final int qr = queen ~/ size;
        final int qc = queen % size;
        if (qc == col || qr == row) {
          clashes = true;
          break;
        }
        final int dr = (qr - row).abs();
        final int dc = (qc - col).abs();
        if (dr <= 1 && dc <= 1) {
          clashes = true;
          break;
        }
      }
      if (clashes) {
        continue;
      }

      rowAssignments[row] = col;
      columnUsed[col] = true;
      if (cageIndex != -1) {
        cageUsage[cageIndex] += 1;
      }
      queens.add(index);

      if (search(depth + 1)) {
        return true;
      }

      queens.removeLast();
      rowAssignments[row] = -1;
      columnUsed[col] = false;
      if (cageIndex != -1) {
        cageUsage[cageIndex] -= 1;
      }
    }

    return false;
  }

  final bool solved = search(0);
  if (!solved) {
    return const <int>[];
  }
  return List<int>.from(queens)..sort();
}
