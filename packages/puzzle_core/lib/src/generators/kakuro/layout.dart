part of puzzle_core_kakuro_generator;

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

class KakuroLayout {
  KakuroLayout({
    required this.width,
    required this.height,
    required this.layout,
    required this.kinds,
    required this.entries,
    required this.acrossEntryForCell,
    required this.downEntryForCell,
    required this.valueCells,
  });

  final int width;
  final int height;
  final List<String> layout;
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
  }) {
    final int w = width.clamp(9, 14);
    final int h = height.clamp(9, 14);
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

    final List<List<int>> grid =
        List<List<int>>.generate(h, (_) => List<int>.filled(w, 0));

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
    return _buildFromLayout(layout);
  }

  static KakuroLayout _buildFromLayout(List<String> layout) {
    final int height = layout.length;
    final int width = layout.first.length;

    final List<KakuroCellKind> kinds =
        List<KakuroCellKind>.filled(width * height, KakuroCellKind.block);
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
