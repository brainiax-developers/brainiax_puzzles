import 'dart:math' as math;

import '../generators/generator.dart';
import '../solver/solver.dart';
import '../util/seeded_rng.dart';
import 'killer_queens_board.dart';
import 'killer_queens_solver.dart';

const int _generatorSolverSalt = 0x41f1c3d5a7b92e11;

class KillerQueensGenerator extends PuzzleGenerator<KillerQueensBoard> {
  const KillerQueensGenerator();

  /// Map difficulty levels to grid sizes.
  /// Easy: 6x6, Medium: 8x8, Hard: 10x10, Expert: 12x12
  static int _getTargetSizeForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 6;
      case 'medium':
        return 8;
      case 'hard':
        return 10;
      case 'expert':
        return 12;
      default:
        return 8; // Default to medium if unknown
    }
  }

  /// Calculate max attempts based on difficulty and size for better quality puzzles.
  static int _calculateMaxAttempts(String tier, int size) {
    // Base attempts scale with grid size
    int base = 32 + (size * 2);

    // Increase attempts for harder difficulties to find better layouts
    switch (tier) {
      case 'easy':
        return base;
      case 'medium':
        return (base * 1.2).round();
      case 'hard':
        return (base * 1.5).round();
      case 'expert':
        return (base * 1.8).round();
      default:
        return base;
    }
  }

  @override
  PuzzleGenerationResult<KillerQueensBoard> generate(GeneratorContext context) {
    // Map difficulty to grid size - ALWAYS use difficulty-based sizing
    // Grid size is determined by difficulty level, not the size parameter
    final String difficultyLevel = context.difficulty.level.toLowerCase();
    final int targetSize = _getTargetSizeForDifficulty(difficultyLevel);

    // Use the target size based on difficulty (ignore context.size for Killer Queens)
    final int width = targetSize;
    final int height = targetSize;

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
    );

    // Scale max attempts based on difficulty and grid size for better puzzle quality
    final int maxAttempts = _calculateMaxAttempts(tier.tier, width);
    List<KillerQueensCage>? cages;
    List<int> queenIndices = const <int>[];
    int attempt = 0;
    int initialCageCount = 0;

    while (attempt < maxAttempts) {
      attempt += 1;
      final List<KillerQueensCage> initialCages = _buildInitialCages(
        width,
        tier,
        context.rng,
      );
      initialCageCount = initialCages.length;

      final List<int> layout = _solveLayout(width, initialCages, context.rng);
      if (layout.isEmpty) {
        continue;
      }

      final List<KillerQueensCage>? merged = _mergeCagesToMatchSize(
        size: width,
        cages: initialCages,
        queenIndices: layout,
        tier: tier,
        rng: context.rng,
      );
      if (merged == null) {
        continue;
      }

      cages = merged;
      queenIndices = layout;
      break;
    }

    if (cages == null || queenIndices.isEmpty) {
      throw StateError(
        'Failed to generate Killer Queens layout after $maxAttempts attempts',
      );
    }

    final int cellCount = width * width;
    final int queenCount = queenIndices.length;

    final List<int> solutionCells = List<int>.filled(cellCount, 0);
    final List<bool> puzzleFixed = List<bool>.filled(cellCount, false);
    for (final int index in queenIndices) {
      solutionCells[index] = 1;
      puzzleFixed[index] = true;
    }

    final List<int> puzzleCells = List<int>.from(solutionCells);
    final int targetGivens = tier.givensRange.$2;
    final int targetRemovals = math.max(0, queenCount - targetGivens);
    int removals = 0;
    int uniquenessChecks = 0;
    final List<int> removalOrder = List<int>.from(queenIndices);
    context.rng.shuffle(removalOrder);

    final KillerQueensSolver solver = const KillerQueensSolver();
    for (final int index in removalOrder) {
      if (removals >= targetRemovals) {
        break;
      }

      puzzleCells[index] = 0;
      puzzleFixed[index] = false;
      final KillerQueensBoard candidate = KillerQueensBoard(
        size: width,
        cells: puzzleCells,
        fixed: puzzleFixed,
        cages: cages,
      );

      uniquenessChecks += 1;
      final SolverResult<KillerQueensBoard> uniqueness = solver.solve(
        candidate,
        SolverContext(
          rng: SeededRng(
            context.seed64 ^ _generatorSolverSalt ^ uniquenessChecks,
          ),
          maxSolutions: 2,
        ),
      );
      if (uniqueness.solutionStatus == SolverStatus.unique) {
        removals += 1;
      } else {
        puzzleCells[index] = 1;
        puzzleFixed[index] = true;
      }
    }

    final KillerQueensBoard puzzle = KillerQueensBoard(
      size: width,
      cells: puzzleCells,
      fixed: puzzleFixed,
      cages: cages,
    );
    final int givens = puzzle.fixed.where((bool fixed) => fixed).length;

    return PuzzleGenerationResult<KillerQueensBoard>(
      board: puzzle,
      snapshot: GenerationSnapshot(
        telemetry: <String, Object?>{
          'tier': tier.tier,
          'attempts': attempt,
          'givens': givens,
          'cageCount': cages.length,
          'initialCageCount': initialCageCount,
          'removals': removals,
          'targetMinGivens': tier.givensRange.$1,
          'targetMaxGivens': tier.givensRange.$2,
          'uniquenessChecks': uniquenessChecks,
        },
      ),
    );
  }
}

class _TierParameters {
  _TierParameters({
    required this.tier,
    required this.initialCageSizeRange,
    required this.finalCageSizeRange,
    required this.givensRange,
  });

  final String tier;
  final (int min, int max) initialCageSizeRange;
  final (int min, int max) finalCageSizeRange;
  final (int min, int max) givensRange;

  static _TierParameters fromRequest(String requestedLevel, int size) {
    final String tier = _normalizeTier(requestedLevel, size);
    final (int min, int max) givens = _givensRangeFor(tier, size);
    final (int min, int max) finalRange = _finalCageRangeFor(tier, size);
    switch (tier) {
      case 'easy':
        return _TierParameters(
          tier: tier,
          initialCageSizeRange: (2, 2), // More uniform, smaller cages for easy
          finalCageSizeRange: finalRange,
          givensRange: givens,
        );
      case 'medium':
        return _TierParameters(
          tier: tier,
          initialCageSizeRange: (2, 3), // Slight variety
          finalCageSizeRange: finalRange,
          givensRange: givens,
        );
      case 'hard':
        return _TierParameters(
          tier: tier,
          initialCageSizeRange: (2, 4), // More variety in cage sizes
          finalCageSizeRange: finalRange,
          givensRange: givens,
        );
      case 'expert':
      default:
        return _TierParameters(
          tier: 'expert',
          initialCageSizeRange: (3, 5), // Larger, more complex cages
          finalCageSizeRange: finalRange,
          givensRange: givens,
        );
    }
  }

  static String _normalizeTier(String requestedLevel, int size) {
    final String normalized = requestedLevel.toLowerCase();
    if (normalized == 'easy' ||
        normalized == 'medium' ||
        normalized == 'hard' ||
        normalized == 'expert') {
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

  int sampleInitialCageSize(SeededRng rng) {
    final int min = initialCageSizeRange.$1;
    final int max = initialCageSizeRange.$2;
    if (min == max) {
      return min;
    }
    return rng.randIntRange(min, max + 1);
  }

  static (int min, int max) _finalCageRangeFor(String tier, int size) {
    int lowerOffset;
    int upperOffset;
    switch (tier) {
      case 'easy':
        // Easy: Smaller cage sizes, more predictable
        lowerOffset = 0;
        upperOffset = 1;
        break;
      case 'medium':
        // Medium: Moderate cage sizes
        lowerOffset = 1;
        upperOffset = 2;
        break;
      case 'hard':
        // Hard: Larger cage sizes
        lowerOffset = 2;
        upperOffset = 3;
        break;
      case 'expert':
      default:
        // Expert: Very large cage sizes
        lowerOffset = 3;
        upperOffset = 4;
        break;
    }

    final int min = math.max(3, size - lowerOffset);
    final int max = math.max(min, size + upperOffset);
    return (min, max);
  }

  static (int min, int max) _givensRangeFor(String tier, int size) {
    int queenCount = size;
    if (queenCount < 1) {
      queenCount = 1;
    } else if (queenCount > 64) {
      queenCount = 64;
    }

    (int min, int max) build(double minFraction, int maxReduction) {
      final int minGivens = math.max(1, (queenCount * minFraction).ceil());
      final int rawMax = math.max(minGivens, queenCount - maxReduction);
      final int boundedMax = math.max(minGivens, math.min(queenCount, rawMax));
      return (minGivens, boundedMax);
    }

    switch (tier) {
      case 'easy':
        // Easy: More givens (70-80% of queens), easier to solve
        return build(0.70, 1);
      case 'medium':
        // Medium: Moderate givens (55-65% of queens)
        return build(0.55, 2);
      case 'hard':
        // Hard: Fewer givens (40-50% of queens)
        return build(0.40, 3);
      case 'expert':
      default:
        // Expert: Minimal givens (25-35% of queens), very challenging
        return build(0.25, 4);
    }
  }
}

List<KillerQueensCage> _buildInitialCages(
  int size,
  _TierParameters tier,
  SeededRng rng,
) {
  final int cellCount = size * size;
  final List<int> assignments = List<int>.filled(cellCount, -1);
  final List<KillerQueensCage> cages = <KillerQueensCage>[];

  int cageIndex = 0;
  for (int index = 0; index < cellCount; index++) {
    if (assignments[index] != -1) {
      continue;
    }
    final int targetSize = tier.sampleInitialCageSize(rng);
    final List<int> cageCells = <int>[];
    final List<int> frontier = <int>[index];

    while (frontier.isNotEmpty && cageCells.length < targetSize) {
      final int candidate = frontier.removeLast();
      if (assignments[candidate] != -1) {
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
        if (assignments[neighbor] == -1) {
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

  for (int index = 0; index < cellCount; index++) {
    if (assignments[index] != -1) {
      continue;
    }
    assignments[index] = cageIndex;
    cages.add(KillerQueensCage(cells: <int>[index]));
    cageIndex += 1;
  }

  return cages;
}

List<KillerQueensCage>? _mergeCagesToMatchSize({
  required int size,
  required List<KillerQueensCage> cages,
  required List<int> queenIndices,
  required _TierParameters tier,
  required SeededRng rng,
}) {
  final int targetCageCount = size;
  if (cages.length < targetCageCount) {
    return null;
  }

  final int minCells = tier.finalCageSizeRange.$1;
  final int maxCells = tier.finalCageSizeRange.$2;

  final List<int> cageByCell = KillerQueensBoard.buildCageByCell(size, cages);
  final List<int> queenCages = <int>[];
  final Set<int> queenCageSet = <int>{};
  for (final int index in queenIndices) {
    final int cageIndex = cageByCell[index];
    queenCages.add(cageIndex);
    queenCageSet.add(cageIndex);
  }
  if (queenCageSet.length != queenCages.length) {
    return null;
  }

  if (cages.length == targetCageCount) {
    final bool withinRange = cages.every((KillerQueensCage cage) {
      final int count = cage.cells.length;
      return count >= minCells && count <= maxCells;
    });
    return withinRange ? List<KillerQueensCage>.from(cages) : null;
  }

  final List<Set<int>> adjacency = _buildCageAdjacency(size, cages, cageByCell);
  final Set<int> unassigned = Set<int>.from(
    List<int>.generate(cages.length, (int i) => i),
  );
  final List<Set<int>> groupCages = List<Set<int>>.generate(
    size,
    (int _) => <int>{},
  );
  final List<int> groupCellCounts = List<int>.filled(size, 0);
  final List<Set<int>> frontiers = List<Set<int>>.generate(
    size,
    (int _) => <int>{},
  );

  for (int i = 0; i < size; i++) {
    final int root = queenCages[i];
    final bool claimed = _claimCage(
      groupIndex: i,
      cageIndex: root,
      maxCells: maxCells,
      unassigned: unassigned,
      groupCages: groupCages,
      groupCellCounts: groupCellCounts,
      frontiers: frontiers,
      adjacency: adjacency,
      cages: cages,
    );
    if (!claimed) {
      return null;
    }
  }

  for (int i = 0; i < size; i++) {
    while (groupCellCounts[i] < minCells) {
      final List<int> candidates = frontiers[i]
          .where(
            (int cageIndex) =>
                groupCellCounts[i] + cages[cageIndex].cells.length <= maxCells,
          )
          .toList();
      if (candidates.isEmpty) {
        return null;
      }
      final int choice = candidates[rng.randIntRange(0, candidates.length)];
      final bool claimed = _claimCage(
        groupIndex: i,
        cageIndex: choice,
        maxCells: maxCells,
        unassigned: unassigned,
        groupCages: groupCages,
        groupCellCounts: groupCellCounts,
        frontiers: frontiers,
        adjacency: adjacency,
        cages: cages,
      );
      if (!claimed) {
        frontiers[i].remove(choice);
      }
    }
  }

  while (unassigned.isNotEmpty) {
    final List<int> eligibleGroups = <int>[];
    for (int i = 0; i < size; i++) {
      if (groupCellCounts[i] >= maxCells) {
        continue;
      }
      final Iterable<int> valid = frontiers[i].where(
        (int cageIndex) =>
            groupCellCounts[i] + cages[cageIndex].cells.length <= maxCells,
      );
      if (valid.isNotEmpty) {
        eligibleGroups.add(i);
      }
    }
    if (eligibleGroups.isEmpty) {
      return null;
    }
    final int groupIndex =
        eligibleGroups[rng.randIntRange(0, eligibleGroups.length)];
    final List<int> candidates = frontiers[groupIndex]
        .where(
          (int cageIndex) =>
              groupCellCounts[groupIndex] + cages[cageIndex].cells.length <=
              maxCells,
        )
        .toList();
    if (candidates.isEmpty) {
      continue;
    }
    final int choice = candidates[rng.randIntRange(0, candidates.length)];
    final bool claimed = _claimCage(
      groupIndex: groupIndex,
      cageIndex: choice,
      maxCells: maxCells,
      unassigned: unassigned,
      groupCages: groupCages,
      groupCellCounts: groupCellCounts,
      frontiers: frontiers,
      adjacency: adjacency,
      cages: cages,
    );
    if (!claimed) {
      frontiers[groupIndex].remove(choice);
    }
  }

  final List<KillerQueensCage> merged = <KillerQueensCage>[];
  for (int i = 0; i < size; i++) {
    final Set<int> assigned = groupCages[i];
    if (assigned.isEmpty) {
      return null;
    }
    final List<int> cells = <int>[];
    for (final int cageIndex in assigned) {
      cells.addAll(cages[cageIndex].cells);
    }
    cells.sort();
    final int totalCells = cells.length;
    if (totalCells < minCells || totalCells > maxCells) {
      return null;
    }
    merged.add(KillerQueensCage(cells: List<int>.unmodifiable(cells)));
  }

  return merged;
}

bool _claimCage({
  required int groupIndex,
  required int cageIndex,
  required int maxCells,
  required Set<int> unassigned,
  required List<Set<int>> groupCages,
  required List<int> groupCellCounts,
  required List<Set<int>> frontiers,
  required List<Set<int>> adjacency,
  required List<KillerQueensCage> cages,
}) {
  if (!unassigned.contains(cageIndex)) {
    return false;
  }

  final int nextCount =
      groupCellCounts[groupIndex] + cages[cageIndex].cells.length;
  if (nextCount > maxCells) {
    return false;
  }

  unassigned.remove(cageIndex);
  groupCages[groupIndex].add(cageIndex);
  groupCellCounts[groupIndex] = nextCount;
  frontiers[groupIndex].remove(cageIndex);

  for (final int neighbor in adjacency[cageIndex]) {
    if (unassigned.contains(neighbor)) {
      frontiers[groupIndex].add(neighbor);
    }
  }

  for (int other = 0; other < frontiers.length; other++) {
    if (other == groupIndex) {
      continue;
    }
    frontiers[other].remove(cageIndex);
  }

  return true;
}

List<Set<int>> _buildCageAdjacency(
  int size,
  List<KillerQueensCage> cages,
  List<int> cageByCell,
) {
  final List<Set<int>> adjacency = List<Set<int>>.generate(
    cages.length,
    (int _) => <int>{},
  );

  for (int index = 0; index < cageByCell.length; index++) {
    final int cageIndex = cageByCell[index];
    for (final int neighbor in _orthogonalNeighbors(index, size)) {
      final int neighborCage = cageByCell[neighbor];
      if (neighborCage == cageIndex) {
        continue;
      }
      adjacency[cageIndex].add(neighborCage);
      adjacency[neighborCage].add(cageIndex);
    }
  }

  return adjacency;
}

List<int> _orthogonalNeighbors(int index, int size) {
  final int row = index ~/ size;
  final int col = index % size;
  final List<int> neighbors = <int>[];
  if (row > 0) {
    neighbors.add(index - size);
  }
  if (row < size - 1) {
    neighbors.add(index + size);
  }
  if (col > 0) {
    neighbors.add(index - 1);
  }
  if (col < size - 1) {
    neighbors.add(index + 1);
  }
  return neighbors;
}

List<int> _solveLayout(int size, List<KillerQueensCage> cages, SeededRng rng) {
  final List<int> cageByCell = KillerQueensBoard.buildCageByCell(size, cages);
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
      if (columnUsed[col]) {
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
