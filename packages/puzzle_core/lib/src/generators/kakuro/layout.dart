part of puzzle_core_kakuro_generator;

const String _defaultKakuroLayoutFamilyId = 'newspaper_random_v1';

class KakuroLayoutEntry {
  KakuroLayoutEntry({
    required this.id,
    required this.direction,
    required this.cells,
  });

  final int id;
  final KakuroDirection direction;
  final List<int> cells;

  int get length => cells.length;
}

class KakuroLayoutMetrics {
  const KakuroLayoutMetrics({
    required this.layoutHash,
    required this.layoutFamilyId,
    required this.width,
    required this.height,
    required this.totalCells,
    required this.whiteCellCount,
    required this.blockCellCount,
    required this.clueCellCount,
    required this.whiteCellDensityMilli,
    required this.clueCellDensityMilli,
    required this.acrossRunCount,
    required this.downRunCount,
    required this.totalRunCount,
    required this.runLengthHistogram,
    required this.maxRunLength,
    required this.averageRunLengthMilli,
    required this.shortRunCount,
    required this.longRunCount,
    required this.shortRunRatioMilli,
    required this.longRunRatioMilli,
    required this.runGraphNodeCount,
    required this.runGraphEdgeCount,
    required this.minRunGraphDegree,
    required this.runGraphComponentCount,
    required this.largestRunGraphComponentNodeCount,
    required this.runGraphConnectivityMilli,
    required this.unpairedValueCellCount,
  });

  final String layoutHash;
  final String layoutFamilyId;
  final int width;
  final int height;
  final int totalCells;
  final int whiteCellCount;
  final int blockCellCount;
  final int clueCellCount;
  final int whiteCellDensityMilli;
  final int clueCellDensityMilli;
  final int acrossRunCount;
  final int downRunCount;
  final int totalRunCount;
  final Map<String, int> runLengthHistogram;
  final int maxRunLength;
  final int averageRunLengthMilli;
  final int shortRunCount;
  final int longRunCount;
  final int shortRunRatioMilli;
  final int longRunRatioMilli;
  final int runGraphNodeCount;
  final int runGraphEdgeCount;
  final int minRunGraphDegree;
  final int runGraphComponentCount;
  final int largestRunGraphComponentNodeCount;
  final int runGraphConnectivityMilli;
  final int unpairedValueCellCount;

  Map<String, Object?> toTelemetry() {
    return <String, Object?>{
      'layoutHash': layoutHash,
      'layoutFamilyId': layoutFamilyId,
      'whiteCellCount': whiteCellCount,
      'blockCellCount': blockCellCount,
      'clueCellCount': clueCellCount,
      'blackOrClueCellCount': blockCellCount,
      'whiteCellDensityMilli': whiteCellDensityMilli,
      'clueCellDensityMilli': clueCellDensityMilli,
      'acrossRunCount': acrossRunCount,
      'downRunCount': downRunCount,
      'totalRunCount': totalRunCount,
      'runLengthHistogram': runLengthHistogram,
      'maxRunLength': maxRunLength,
      'averageRunLengthMilli': averageRunLengthMilli,
      'shortRunCount': shortRunCount,
      'longRunCount': longRunCount,
      'shortRunRatioMilli': shortRunRatioMilli,
      'longRunRatioMilli': longRunRatioMilli,
      'runGraphNodeCount': runGraphNodeCount,
      'runGraphEdgeCount': runGraphEdgeCount,
      'minRunGraphDegree': minRunGraphDegree,
      'runGraphComponentCount': runGraphComponentCount,
      'largestRunGraphComponentNodeCount': largestRunGraphComponentNodeCount,
      'runGraphConnectivityMilli': runGraphConnectivityMilli,
      'unpairedValueCellCount': unpairedValueCellCount,
    };
  }
}

class KakuroLayoutPreScoreResult {
  const KakuroLayoutPreScoreResult({
    required this.accepted,
    required this.reason,
    required this.scoreMilli,
    required this.metrics,
  });

  final bool accepted;
  final String reason;
  final int scoreMilli;
  final KakuroLayoutMetrics metrics;
}

class KakuroLayoutPreScorer {
  const KakuroLayoutPreScorer();

  KakuroLayoutPreScoreResult score({
    required KakuroLayout layout,
    required String difficulty,
  }) {
    final KakuroLayoutMetrics metrics = layout.computeMetrics();
    final _KakuroLayoutThresholdProfile? profile = _thresholdProfileFor(
      width: layout.width,
      height: layout.height,
      difficulty: difficulty,
    );

    if (metrics.totalRunCount == 0 || metrics.whiteCellCount == 0) {
      return KakuroLayoutPreScoreResult(
        accepted: false,
        reason: 'invalid_no_runs',
        scoreMilli: 0,
        metrics: metrics,
      );
    }
    if (metrics.unpairedValueCellCount > 0) {
      return KakuroLayoutPreScoreResult(
        accepted: false,
        reason: 'invalid_unpaired_value_cells',
        scoreMilli: 0,
        metrics: metrics,
      );
    }
    if (metrics.runGraphComponentCount > 1) {
      return KakuroLayoutPreScoreResult(
        accepted: false,
        reason: 'invalid_disconnected_run_graph',
        scoreMilli: 0,
        metrics: metrics,
      );
    }

    final int scoreMilli = _scoreMetrics(metrics, profile);
    if (profile == null) {
      return KakuroLayoutPreScoreResult(
        accepted: true,
        reason: 'gate_skipped',
        scoreMilli: scoreMilli,
        metrics: metrics,
      );
    }

    if (metrics.whiteCellDensityMilli < profile.minWhiteDensityMilli) {
      return KakuroLayoutPreScoreResult(
        accepted: false,
        reason: 'white_density_low',
        scoreMilli: scoreMilli,
        metrics: metrics,
      );
    }
    if (metrics.whiteCellDensityMilli > profile.maxWhiteDensityMilli) {
      return KakuroLayoutPreScoreResult(
        accepted: false,
        reason: 'white_density_high',
        scoreMilli: scoreMilli,
        metrics: metrics,
      );
    }
    if (metrics.longRunCount > profile.maxLongRuns ||
        metrics.longRunRatioMilli > profile.maxLongRunRatioMilli) {
      return KakuroLayoutPreScoreResult(
        accepted: false,
        reason: 'long_runs_heavy',
        scoreMilli: scoreMilli,
        metrics: metrics,
      );
    }
    if (metrics.shortRunCount < profile.minShortRuns ||
        metrics.shortRunRatioMilli < profile.minShortRunRatioMilli) {
      return KakuroLayoutPreScoreResult(
        accepted: false,
        reason: 'short_runs_sparse',
        scoreMilli: scoreMilli,
        metrics: metrics,
      );
    }
    if (metrics.maxRunLength > profile.maxRunLength) {
      return KakuroLayoutPreScoreResult(
        accepted: false,
        reason: 'max_run_length_exceeded',
        scoreMilli: scoreMilli,
        metrics: metrics,
      );
    }
    if (metrics.minRunGraphDegree < profile.minRunGraphDegree ||
        metrics.runGraphConnectivityMilli <
            profile.minRunGraphConnectivityMilli) {
      return KakuroLayoutPreScoreResult(
        accepted: false,
        reason: 'run_graph_connectivity_weak',
        scoreMilli: scoreMilli,
        metrics: metrics,
      );
    }
    if (_isPathologicalHistogram(metrics, profile)) {
      return KakuroLayoutPreScoreResult(
        accepted: false,
        reason: 'run_histogram_pathological',
        scoreMilli: scoreMilli,
        metrics: metrics,
      );
    }

    return KakuroLayoutPreScoreResult(
      accepted: true,
      reason: 'accepted',
      scoreMilli: scoreMilli,
      metrics: metrics,
    );
  }
}

class _KakuroLayoutThresholdProfile {
  const _KakuroLayoutThresholdProfile({
    required this.minWhiteDensityMilli,
    required this.maxWhiteDensityMilli,
    required this.maxLongRuns,
    required this.maxLongRunRatioMilli,
    required this.minShortRuns,
    required this.minShortRunRatioMilli,
    required this.maxRunLength,
    required this.minRunGraphDegree,
    required this.minRunGraphConnectivityMilli,
    required this.minSmallRunLengthBins,
    required this.maxDominantRunLengthRatioMilli,
  });

  final int minWhiteDensityMilli;
  final int maxWhiteDensityMilli;
  final int maxLongRuns;
  final int maxLongRunRatioMilli;
  final int minShortRuns;
  final int minShortRunRatioMilli;
  final int maxRunLength;
  final int minRunGraphDegree;
  final int minRunGraphConnectivityMilli;
  final int minSmallRunLengthBins;
  final int maxDominantRunLengthRatioMilli;
}

_KakuroLayoutThresholdProfile? _thresholdProfileFor({
  required int width,
  required int height,
  required String difficulty,
}) {
  if (width != height) {
    return null;
  }
  if (width == 9 &&
      (difficulty == 'medium' ||
          difficulty == 'hard' ||
          difficulty == 'expert')) {
    return const _KakuroLayoutThresholdProfile(
      minWhiteDensityMilli: 320,
      maxWhiteDensityMilli: 560,
      maxLongRuns: 8,
      maxLongRunRatioMilli: 360,
      minShortRuns: 12,
      minShortRunRatioMilli: 560,
      maxRunLength: 8,
      minRunGraphDegree: 1,
      minRunGraphConnectivityMilli: 1000,
      minSmallRunLengthBins: 2,
      maxDominantRunLengthRatioMilli: 780,
    );
  }
  return null;
}

int _scoreMetrics(
  KakuroLayoutMetrics metrics,
  _KakuroLayoutThresholdProfile? profile,
) {
  int score = 1000;
  final int targetDensity = profile == null
      ? 430
      : (profile.minWhiteDensityMilli + profile.maxWhiteDensityMilli) ~/ 2;
  score -= ((metrics.whiteCellDensityMilli - targetDensity).abs() * 2);
  score -= (metrics.longRunRatioMilli * 3) ~/ 4;
  score += (metrics.shortRunRatioMilli * 3) ~/ 5;
  score += metrics.runGraphConnectivityMilli ~/ 2;
  score -= metrics.unpairedValueCellCount * 180;
  if (score < 0) {
    return 0;
  }
  if (score > 1000) {
    return 1000;
  }
  return score;
}

bool _isPathologicalHistogram(
  KakuroLayoutMetrics metrics,
  _KakuroLayoutThresholdProfile profile,
) {
  if (metrics.totalRunCount <= 0) {
    return true;
  }
  int dominantCount = 0;
  int smallRunLengthBins = 0;
  for (final MapEntry<String, int> entry
      in metrics.runLengthHistogram.entries) {
    final int len = int.tryParse(entry.key) ?? 0;
    final int count = entry.value;
    if (count > dominantCount) {
      dominantCount = count;
    }
    if (len >= 2 && len <= 4 && count > 0) {
      smallRunLengthBins++;
    }
  }
  final int dominantRatioMilli =
      (dominantCount * 1000) ~/ metrics.totalRunCount;
  return dominantRatioMilli > profile.maxDominantRunLengthRatioMilli ||
      smallRunLengthBins < profile.minSmallRunLengthBins;
}

class KakuroLayout {
  KakuroLayout({
    required this.width,
    required this.height,
    required this.layout,
    this.layoutFamilyId = _defaultKakuroLayoutFamilyId,
    required this.kinds,
    required this.entries,
    required this.acrossEntryForCell,
    required this.downEntryForCell,
    required this.valueCells,
  });

  final int width;
  final int height;
  final List<String> layout;
  final String layoutFamilyId;
  final List<KakuroCellKind> kinds;
  final List<KakuroLayoutEntry> entries;
  final List<int> acrossEntryForCell;
  final List<int> downEntryForCell;
  final List<int> valueCells;

  int get valueCellCount => valueCells.length;

  int get attemptMultiplier {
    if (width <= 5) {
      return 3;
    }
    if (width <= 7) {
      return 8;
    }
    return 10;
  }

  /// Build a randomized, newspaper-style layout with symmetric blocks and
  /// runs constrained to length 2..9.
  static KakuroLayout buildNewspaper({
    required SeededRng rng,
    required int width,
    required int height,
    required String difficulty,
    String layoutFamilyId = _defaultKakuroLayoutFamilyId,
  }) {
    final int w = width;
    final int h = height;
    const int minRun = 2;
    const int maxRun = 9;

    final double density = () {
      switch (difficulty) {
        case 'easy':
          return 0.42;
        case 'medium':
          return 0.36;
        case 'hard':
          return 0.30;
        default:
          return 0.34;
      }
    }();

    final List<List<int>> grid = List<List<int>>.generate(
      h,
      (_) => List<int>.filled(w, 0),
    );

    for (int r = 0; r < h; r++) {
      for (int c = 0; c < w; c++) {
        if (r == 0 || c == 0 || r == h - 1 || c == w - 1) {
          grid[r][c] = 1;
        }
      }
    }

    final int interiorCells = (w - 2) * (h - 2);
    final int targetBlocks = (density * interiorCells).round();

    void placeSym(int r, int c, int val) {
      grid[r][c] = val;
      grid[h - 1 - r][w - 1 - c] = val;
    }

    final List<List<int>> candidates = <List<int>>[];
    for (int r = 1; r < h - 1; r++) {
      for (int c = 1; c < w - 1; c++) {
        if (r > h - 1 - r || (r == h - 1 - r && c > w - 1 - c)) {
          continue;
        }
        candidates.add(<int>[r, c]);
      }
    }
    final List<List<int>> order = rng.permute(candidates);
    int placed = 0;
    for (final List<int> rc in order) {
      if (placed >= targetBlocks) break;
      final int r = rc[0], c = rc[1];
      if (grid[r][c] == 1) continue;
      placeSym(r, c, 1);
      if (!_runsValid(grid, minRun, maxRun)) {
        placeSym(r, c, 0);
        continue;
      }
      placed += (r == h - 1 - r && c == w - 1 - c) ? 1 : 2;
    }

    _repairRuns(rng, grid, minRun, maxRun);

    final List<String> layout = <String>[];
    for (int r = 0; r < h; r++) {
      final StringBuffer row = StringBuffer();
      for (int c = 0; c < w; c++) {
        row.write(grid[r][c] == 1 ? '#' : '.');
      }
      layout.add(row.toString());
    }
    return _buildFromLayout(layout, layoutFamilyId: layoutFamilyId);
  }

  static KakuroLayout fromRows(
    List<String> rows, {
    String layoutFamilyId = _defaultKakuroLayoutFamilyId,
  }) {
    if (rows.isEmpty) {
      throw ArgumentError('Kakuro layout rows must not be empty.');
    }
    final int width = rows.first.length;
    if (width == 0) {
      throw ArgumentError('Kakuro layout rows must not be empty strings.');
    }
    final List<String> normalized = <String>[];
    for (int r = 0; r < rows.length; r++) {
      final String row = rows[r];
      if (row.length != width) {
        throw ArgumentError(
          'Kakuro layout row $r has width ${row.length}; expected $width.',
        );
      }
      final StringBuffer buffer = StringBuffer();
      for (int c = 0; c < row.length; c++) {
        buffer.write(row[c] == '.' ? '.' : '#');
      }
      normalized.add(buffer.toString());
    }
    return _buildFromLayout(normalized, layoutFamilyId: layoutFamilyId);
  }

  static KakuroLayout _buildFromLayout(
    List<String> layout, {
    String layoutFamilyId = _defaultKakuroLayoutFamilyId,
  }) {
    final int height = layout.length;
    final int width = layout.first.length;

    final List<KakuroCellKind> kinds = List<KakuroCellKind>.filled(
      width * height,
      KakuroCellKind.block,
    );
    final List<KakuroLayoutEntry> entries = <KakuroLayoutEntry>[];
    final List<int> acrossEntryForCell = List<int>.filled(width * height, -1);
    final List<int> downEntryForCell = List<int>.filled(width * height, -1);

    int entryId = 0;

    for (int row = 0; row < height; row++) {
      int col = 0;
      while (col < width) {
        if (layout[row][col] == '.') {
          final List<int> cells = <int>[];
          while (col < width && layout[row][col] == '.') {
            final int index = row * width + col;
            kinds[index] = KakuroCellKind.value;
            cells.add(index);
            col++;
          }
          if (cells.length >= 2) {
            final entry = KakuroLayoutEntry(
              id: entryId++,
              direction: KakuroDirection.across,
              cells: cells,
            );
            entries.add(entry);
            for (final int index in cells) {
              acrossEntryForCell[index] = entry.id;
            }
          }
        } else {
          col++;
        }
      }
    }

    for (int col = 0; col < width; col++) {
      int row = 0;
      while (row < height) {
        if (layout[row][col] == '.') {
          final List<int> cells = <int>[];
          while (row < height && layout[row][col] == '.') {
            final int index = row * width + col;
            kinds[index] = KakuroCellKind.value;
            cells.add(index);
            row++;
          }
          if (cells.length >= 2) {
            final entry = KakuroLayoutEntry(
              id: entryId++,
              direction: KakuroDirection.down,
              cells: cells,
            );
            entries.add(entry);
            for (final int index in cells) {
              downEntryForCell[index] = entry.id;
            }
          }
        } else {
          row++;
        }
      }
    }

    final List<int> valueCells = <int>[];
    for (int i = 0; i < kinds.length; i++) {
      if (kinds[i] == KakuroCellKind.value) {
        valueCells.add(i);
      }
    }

    return KakuroLayout(
      width: width,
      height: height,
      layout: layout,
      layoutFamilyId: layoutFamilyId,
      kinds: kinds,
      entries: entries,
      acrossEntryForCell: acrossEntryForCell,
      downEntryForCell: downEntryForCell,
      valueCells: valueCells,
    );
  }

  KakuroBoard buildBoard(
    Map<int, int> entrySums, [
    Set<int> givenCells = const <int>{},
    List<int>? solutionValues,
  ]) {
    final int cellCount = width * height;
    final List<int?> acrossClues = List<int?>.filled(cellCount, null);
    final List<int?> downClues = List<int?>.filled(cellCount, null);

    final List<KakuroEntry> boardEntries = <KakuroEntry>[];
    for (final KakuroLayoutEntry entry in entries) {
      final int sum = entrySums[entry.id] ?? 0;
      boardEntries.add(
        KakuroEntry(
          id: entry.id,
          direction: entry.direction,
          cells: entry.cells,
          sum: sum,
        ),
      );
      if (entry.cells.isEmpty) continue;
      final int first = entry.cells.first;
      final int row = first ~/ width;
      final int col = first % width;
      if (entry.direction == KakuroDirection.across && col > 0) {
        final int clueIndex = row * width + (col - 1);
        acrossClues[clueIndex] = sum;
      }
      if (entry.direction == KakuroDirection.down && row > 0) {
        final int clueIndex = (row - 1) * width + col;
        downClues[clueIndex] = sum;
      }
    }

    final List<int> values = List<int>.filled(cellCount, 0);
    if (solutionValues != null) {
      for (final int cellIndex in givenCells) {
        if (cellIndex >= 0 && cellIndex < cellCount) {
          values[cellIndex] = solutionValues[cellIndex];
        }
      }
    }

    return KakuroBoard(
      width: width,
      height: height,
      kinds: kinds,
      values: values,
      acrossClues: acrossClues,
      downClues: downClues,
      entries: boardEntries,
      acrossEntryForCell: acrossEntryForCell,
      downEntryForCell: downEntryForCell,
    );
  }

  Map<String, Object?> buildStructuralTelemetry({Map<int, int>? entrySums}) {
    final KakuroLayoutMetrics metrics = computeMetrics();

    int averageRunCombinationCountMilli = 0;
    int singleCombinationRunRatioMilli = 0;
    if (entrySums != null && entries.isNotEmpty) {
      int comboTotal = 0;
      int singleComboRuns = 0;
      for (final KakuroLayoutEntry entry in entries) {
        final int sum = entrySums[entry.id] ?? 0;
        final Set<int>? combos = KakuroDictionary.getCombinations(
          entry.length,
          sum,
        );
        final int comboCount = combos?.length ?? 0;
        comboTotal += comboCount;
        if (comboCount == 1) {
          singleComboRuns++;
        }
      }
      averageRunCombinationCountMilli = (comboTotal * 1000) ~/ entries.length;
      singleCombinationRunRatioMilli =
          (singleComboRuns * 1000) ~/ entries.length;
    }

    return <String, Object?>{
      ...metrics.toTelemetry(),
      if (entrySums != null)
        'averageRunCombinationCountMilli': averageRunCombinationCountMilli,
      if (entrySums != null)
        'singleCombinationRunRatioMilli': singleCombinationRunRatioMilli,
    };
  }

  KakuroLayoutMetrics computeMetrics() {
    final int totalCells = width * height;
    final int whiteCellCount = valueCellCount;
    final int blockCellCount = totalCells - whiteCellCount;
    int acrossRunCount = 0;
    int downRunCount = 0;
    final Set<int> clueCells = <int>{};
    final Map<int, int> runLengthHistogram = <int, int>{};
    int maxRunLength = 0;
    int runLengthTotal = 0;
    int shortRunCount = 0;
    int longRunCount = 0;
    final Map<int, Set<int>> runGraphAdjacency = <int, Set<int>>{};

    for (final KakuroLayoutEntry entry in entries) {
      runGraphAdjacency.putIfAbsent(entry.id, () => <int>{});
      if (entry.direction == KakuroDirection.across) {
        acrossRunCount++;
        if (entry.cells.isNotEmpty) {
          final int first = entry.cells.first;
          final int row = first ~/ width;
          final int col = first % width;
          if (col > 0) {
            clueCells.add(row * width + (col - 1));
          }
        }
      } else {
        downRunCount++;
        if (entry.cells.isNotEmpty) {
          final int first = entry.cells.first;
          final int row = first ~/ width;
          final int col = first % width;
          if (row > 0) {
            clueCells.add((row - 1) * width + col);
          }
        }
      }
      final int length = entry.length;
      runLengthTotal += length;
      if (length > maxRunLength) {
        maxRunLength = length;
      }
      runLengthHistogram[length] = (runLengthHistogram[length] ?? 0) + 1;
      if (length >= 2 && length <= 4) {
        shortRunCount++;
      }
      if (length >= 6) {
        longRunCount++;
      }
    }
    final int totalRunCount = entries.length;
    final int averageRunLengthMilli = totalRunCount == 0
        ? 0
        : (runLengthTotal * 1000) ~/ totalRunCount;

    final Map<int, int> runDegree = <int, int>{};
    int runGraphEdgeCount = 0;
    int unpairedValueCellCount = 0;
    for (final int cell in valueCells) {
      final int acrossId = acrossEntryForCell[cell];
      final int downId = downEntryForCell[cell];
      if (acrossId >= 0 && downId >= 0) {
        runGraphEdgeCount++;
        runDegree[acrossId] = (runDegree[acrossId] ?? 0) + 1;
        runDegree[downId] = (runDegree[downId] ?? 0) + 1;
        if (acrossId != downId) {
          runGraphAdjacency.putIfAbsent(acrossId, () => <int>{}).add(downId);
          runGraphAdjacency.putIfAbsent(downId, () => <int>{}).add(acrossId);
        }
      } else {
        unpairedValueCellCount++;
      }
    }

    int minRunGraphDegree = 0;
    if (entries.isNotEmpty) {
      minRunGraphDegree = 1 << 30;
      for (final KakuroLayoutEntry entry in entries) {
        final int degree = runDegree[entry.id] ?? 0;
        if (degree < minRunGraphDegree) {
          minRunGraphDegree = degree;
        }
      }
      if (minRunGraphDegree == 1 << 30) {
        minRunGraphDegree = 0;
      }
    }

    int runGraphComponentCount = 0;
    int largestRunGraphComponentNodeCount = 0;
    if (entries.isNotEmpty) {
      final Set<int> visited = <int>{};
      for (final KakuroLayoutEntry entry in entries) {
        if (!visited.add(entry.id)) {
          continue;
        }
        runGraphComponentCount++;
        int componentSize = 0;
        final List<int> stack = <int>[entry.id];
        while (stack.isNotEmpty) {
          final int current = stack.removeLast();
          componentSize++;
          final Set<int> neighbors =
              runGraphAdjacency[current] ?? const <int>{};
          for (final int neighbor in neighbors) {
            if (visited.add(neighbor)) {
              stack.add(neighbor);
            }
          }
        }
        if (componentSize > largestRunGraphComponentNodeCount) {
          largestRunGraphComponentNodeCount = componentSize;
        }
      }
    }
    final int runGraphConnectivityMilli = totalRunCount == 0
        ? 0
        : (largestRunGraphComponentNodeCount * 1000) ~/ totalRunCount;

    final List<int> sortedRunLengths = runLengthHistogram.keys.toList()..sort();
    final Map<String, int> stableHistogram = <String, int>{};
    for (final int key in sortedRunLengths) {
      stableHistogram[key.toString()] = runLengthHistogram[key]!;
    }

    final int shortRunRatioMilli = totalRunCount == 0
        ? 0
        : (shortRunCount * 1000) ~/ totalRunCount;
    final int longRunRatioMilli = totalRunCount == 0
        ? 0
        : (longRunCount * 1000) ~/ totalRunCount;
    final int whiteCellDensityMilli = totalCells == 0
        ? 0
        : (whiteCellCount * 1000) ~/ totalCells;
    final int clueCellDensityMilli = totalCells == 0
        ? 0
        : (clueCells.length * 1000) ~/ totalCells;

    return KakuroLayoutMetrics(
      layoutHash: _computeLayoutHash(layout),
      layoutFamilyId: layoutFamilyId,
      width: width,
      height: height,
      totalCells: totalCells,
      whiteCellCount: whiteCellCount,
      blockCellCount: blockCellCount,
      clueCellCount: clueCells.length,
      whiteCellDensityMilli: whiteCellDensityMilli,
      clueCellDensityMilli: clueCellDensityMilli,
      acrossRunCount: acrossRunCount,
      downRunCount: downRunCount,
      totalRunCount: totalRunCount,
      runLengthHistogram: stableHistogram,
      maxRunLength: maxRunLength,
      averageRunLengthMilli: averageRunLengthMilli,
      shortRunCount: shortRunCount,
      longRunCount: longRunCount,
      shortRunRatioMilli: shortRunRatioMilli,
      longRunRatioMilli: longRunRatioMilli,
      runGraphNodeCount: totalRunCount,
      runGraphEdgeCount: runGraphEdgeCount,
      minRunGraphDegree: minRunGraphDegree,
      runGraphComponentCount: runGraphComponentCount,
      largestRunGraphComponentNodeCount: largestRunGraphComponentNodeCount,
      runGraphConnectivityMilli: runGraphConnectivityMilli,
      unpairedValueCellCount: unpairedValueCellCount,
    );
  }
}

String _computeLayoutHash(List<String> layout) {
  // Stable, deterministic FNV-1a 64-bit hash over block/value topology.
  const int offset = 0xcbf29ce484222325;
  const int prime = 0x100000001b3;
  const int mask = 0xffffffffffffffff;
  int hash = offset;
  for (final String row in layout) {
    for (int i = 0; i < row.length; i++) {
      final int code = row.codeUnitAt(i);
      final int normalized = code == 35 ? 35 : 46; // '#' or '.'
      hash ^= normalized;
      hash = (hash * prime) & mask;
    }
    hash ^= 124; // row separator '|'
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

bool _runsValid(List<List<int>> grid, int minRun, int maxRun) {
  final int h = grid.length;
  final int w = grid.first.length;
  for (int r = 0; r < h; r++) {
    int run = 0;
    for (int c = 0; c < w; c++) {
      if (grid[r][c] == 0) {
        run++;
      } else {
        if (run == 1) return false;
        if (run > maxRun) return false;
        run = 0;
      }
    }
    if (run == 1) return false;
    if (run > maxRun) return false;
  }
  for (int c = 0; c < w; c++) {
    int run = 0;
    for (int r = 0; r < h; r++) {
      if (grid[r][c] == 0) {
        run++;
      } else {
        if (run == 1) return false;
        if (run > maxRun) return false;
        run = 0;
      }
    }
    if (run == 1) return false;
    if (run > maxRun) return false;
  }
  return true;
}

void _repairRuns(SeededRng rng, List<List<int>> grid, int minRun, int maxRun) {
  final int h = grid.length;
  final int w = grid.first.length;

  void placeSym(int r, int c, int val) {
    grid[r][c] = val;
    grid[h - 1 - r][w - 1 - c] = val;
  }

  bool changed = true;
  int safety = 0;
  while (changed && safety < 400) {
    safety++;
    changed = false;
    for (int r = 1; r < h - 1; r++) {
      int c = 0;
      while (c < w) {
        while (c < w && grid[r][c] == 1) c++;
        int start = c;
        while (c < w && grid[r][c] == 0) c++;
        int end = c - 1;
        final int len = end - start + 1;
        if (len >= 1 && (len < minRun || len > maxRun)) {
          final List<int> options = <int>[];
          for (int split = start + minRun; split <= end - minRun + 1; split++) {
            options.add(split);
          }
          if (options.isNotEmpty) {
            final int pick = options[rng.nextIntInRange(options.length)];
            if (grid[r][pick] == 0 && grid[h - 1 - r][w - 1 - pick] == 0) {
              placeSym(r, pick, 1);
              if (_runsValid(grid, minRun, maxRun)) {
                changed = true;
              } else {
                placeSym(r, pick, 0);
              }
            }
          }
        }
      }
    }
    for (int c = 1; c < w - 1; c++) {
      int r = 0;
      while (r < h) {
        while (r < h && grid[r][c] == 1) r++;
        int start = r;
        while (r < h && grid[r][c] == 0) r++;
        int end = r - 1;
        final int len = end - start + 1;
        if (len >= 1 && (len < minRun || len > maxRun)) {
          final List<int> options = <int>[];
          for (int split = start + minRun; split <= end - minRun + 1; split++) {
            options.add(split);
          }
          if (options.isNotEmpty) {
            final int pick = options[rng.nextIntInRange(options.length)];
            if (grid[pick][c] == 0 && grid[h - 1 - pick][w - 1 - c] == 0) {
              placeSym(pick, c, 1);
              if (_runsValid(grid, minRun, maxRun)) {
                changed = true;
              } else {
                placeSym(pick, c, 0);
              }
            }
          }
        }
      }
    }
  }
}
