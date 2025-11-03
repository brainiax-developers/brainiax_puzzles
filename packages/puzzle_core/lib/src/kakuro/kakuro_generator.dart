import '../difficulty/difficulty_config.dart';
import '../difficulty/telemetry.dart';
import '../generators/generator.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../util/kakuro_dictionary.dart';
import '../util/seeded_rng.dart';
import 'kakuro_board.dart';
import 'kakuro_difficulty.dart';
import 'kakuro_solver.dart';

const int _solverSalt = 0x6f95c2c1ab7342ed;
const int _mixMultiplier = 0x9e3779b97f4a7c15;
const int _mask64 = 0xffffffffffffffff;

// Difficulty profiles were used for sum-biasing; newspaper mode relies on
// solver telemetry-based gating instead of sum weighting.

int _deriveSolverSeed(int baseSeed, int attempt, int stage) {
  final int attemptSalt = (attempt * _mixMultiplier) & _mask64;
  final int combined = baseSeed ^ _solverSalt ^ attemptSalt ^ stage;
  return combined & _mask64;
}

class KakuroGenerator extends PuzzleGenerator<KakuroBoard> {
  const KakuroGenerator({this.maxTemplateAttempts = 160});

  final int maxTemplateAttempts;

  static final DifficultyBucketConfig _difficultyConfig =
      const DifficultyConfigLoader().loadSync('assets/kakuro_difficulty_thresholds.json');

  static const KakuroDifficultyScorer _difficultyScorer = KakuroDifficultyScorer();

  @override
  PuzzleGenerationResult<KakuroBoard> generate(GeneratorContext context) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final String requestedLevelRaw = context.difficulty.level.trim().toLowerCase();
    final String requestedLevel = requestedLevelRaw == 'auto' ? 'easy' : requestedLevelRaw;
  // Use a strict solver (no node cap) for correctness; gating uses telemetry.
    final KakuroSolver strictSolver = const KakuroSolver(maxSearchDepth: 26);

    // Decide grid size. Prefer 10-14 for production; respect provided size when present (incl. 9x9 for tests).
    final int targetWidth = _chooseWidth(context);
    final int targetHeight = _chooseHeight(context);
    final _KakuroTemplate template = _KakuroTemplate.buildNewspaper(
      rng: context.rng,
      width: targetWidth,
      height: targetHeight,
      difficulty: requestedLevel,
    );

    int attempts = 0;
    Map<String, Object?> telemetry = const <String, Object?>{};
    KakuroBoard? puzzle;

    final int multiplier = template.attemptMultiplier;
    final int attemptLimit = maxTemplateAttempts * multiplier;

    while (attempts < attemptLimit) {
      attempts++;
      int solverStage = 0;
      SeededRng nextSolverRng() {
        solverStage++;
        return SeededRng(
          _deriveSolverSeed(context.seed64, attempts, solverStage),
        );
      }

      final _TemplateSolution? solution = _constructSolution(template, context.rng);
      if (solution == null) {
        continue;
      }

      // Build a pure-sums puzzle (no digit givens); verify uniqueness and logic thresholds.
      final KakuroBoard candidateBoard = template.buildBoard(
        solution.entrySums,
        const <int>{},
        null,
      );
      final SolverResult<KakuroBoard> uniqueness = strictSolver.solve(
        candidateBoard,
        SolverContext(
          rng: nextSolverRng(),
          maxSolutions: 2,
        ),
      );
      if (!uniqueness.isUnique) {
        continue;
      }

      // Gate by backtrack/logic thresholds per difficulty.
      if (!_meetsLogicThresholds(requestedLevel, uniqueness.telemetry)) {
        continue;
      }

      // Score difficulty using the fast solver telemetry; engine will re-score later.
      final DifficultyTelemetry difficultyTelemetry = _difficultyScorer.score(
        puzzle: candidateBoard,
        solution: candidateBoard, // unused by scorer logic
        context: DifficultyContext(
          generatorTelemetry: <String, Object?>{
            'givens': 0,
            'valueCells': template.valueCellCount,
            'width': template.width,
            'height': template.height,
          },
          solverTelemetry: uniqueness.telemetry,
        ),
      );
      final String bucket = _difficultyConfig.bucketFor(difficultyTelemetry.rawScore);

      final Map<String, Object?> sanitizedSolverTelemetry =
          uniqueness.telemetry.map((String key, Object? value) {
        if (value is double) {
          return MapEntry<String, Object?>(key, (value * 1000).round());
        }
        return MapEntry<String, Object?>(key, value);
      });

      puzzle = candidateBoard;
      telemetry = <String, Object?>{
        'attempts': attempts,
        'attemptLimit': attemptLimit,
        'generationDurationUs': stopwatch.elapsedMicroseconds,
        'solverTelemetry': sanitizedSolverTelemetry,
        'solutionSignature': solution.signature,
        'difficultyBucket': bucket,
        'requestedDifficulty': requestedLevel,
        'difficultyScoreMilli': (difficultyTelemetry.rawScore * 1000).round(),
        'valueCellCount': template.valueCellCount,
        'givensCount': 0,
        'givenRatioMilli': 0,
        'width': template.width,
        'height': template.height,
      };
      break;
    }

    stopwatch.stop();

    if (puzzle == null) {
      // Deterministic fallback: try a few alternative layouts, then throw.
      for (int alt = 0; alt < 3 && puzzle == null; alt++) {
        final _KakuroTemplate altTemplate = _KakuroTemplate.buildNewspaper(
          rng: SeededRng(_deriveSolverSeed(context.seed64, 1234, alt + 1)),
          width: targetWidth,
          height: targetHeight,
          difficulty: requestedLevel,
        );
        final _TemplateSolution? sol = _constructSolution(altTemplate, context.rng);
        if (sol == null) continue;
        final KakuroBoard board = altTemplate.buildBoard(sol.entrySums);
        final SolverResult<KakuroBoard> uniqueness = strictSolver.solve(
          board,
          SolverContext(rng: SeededRng(_deriveSolverSeed(context.seed64, 4321, alt + 1)), maxSolutions: 2),
        );
        if (uniqueness.isUnique && _meetsLogicThresholds(requestedLevel, uniqueness.telemetry)) {
          puzzle = board;
          telemetry = <String, Object?>{
            'attempts': attempts,
            'attemptLimit': attemptLimit,
            'generationDurationUs': stopwatch.elapsedMicroseconds,
            'fallback': true,
            'valueCellCount': altTemplate.valueCellCount,
            'width': altTemplate.width,
            'height': altTemplate.height,
          };
        }
      }
      if (puzzle == null) {
        throw StateError('Unable to generate unique Kakuro for seed ${context.seedStr}');
      }
    }

    DeterminismGuard.assertNoFloatsOrDateTimes(telemetry);

    return PuzzleGenerationResult<KakuroBoard>(
      board: puzzle,
      snapshot: GenerationSnapshot(telemetry: telemetry),
    );
  }

  // Removal-based carving is no longer used; generation produces classic Kakuro
  // puzzles with sums only (no digit givens) and relies on uniqueness checks.
}

// Legacy candidate container removed: generation no longer uses digit givens.

class _TemplateSolution {
  _TemplateSolution({
    required this.values,
    required this.entrySums,
  }) : signature = _computeSignature(values);

  final List<int> values;
  final Map<int, int> entrySums;
  final String signature;

  static String _computeSignature(List<int> values) {
    final StringBuffer buffer = StringBuffer();
    for (final int value in values) {
      buffer.write(value);
    }
    return buffer.toString();
  }
}

// CombinationChoice no longer needed with weighted sum selection.

class _TemplateEntry {
  _TemplateEntry({
    required this.id,
    required this.direction,
    required this.cells,
  });

  final int id;
  final KakuroDirection direction;
  final List<int> cells;

  int get length => cells.length;
}

class _KakuroTemplate {
  _KakuroTemplate({
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
  final List<_TemplateEntry> entries;
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

  /// Build a randomized, newspaper-style template with symmetric black cells,
  /// runs length 2..9, and a solid black border to host clue cells.
  static _KakuroTemplate buildNewspaper({
    required SeededRng rng,
    required int width,
    required int height,
    required String difficulty,
  }) {
    // Allow 9x9 for compatibility (tests), otherwise clamp to 10..14.
    final int w = width.clamp(9, 14);
    final int h = height.clamp(9, 14);
    final int minRun = 2;
    final int maxRun = 9;

    // Target block density by difficulty.
    final double density = () {
      switch (difficulty) {
        case 'easy':
          return 0.42; // more blocks, shorter runs
        case 'medium':
          return 0.36;
        case 'hard':
          return 0.30;
        default:
          return 0.34;
      }
    }();

    List<List<int>> grid = List<List<int>>.generate(
      h,
      (_) => List<int>.filled(w, 0),
    );

    // Start with black border.
    for (int r = 0; r < h; r++) {
      for (int c = 0; c < w; c++) {
        if (r == 0 || c == 0 || r == h - 1 || c == w - 1) {
          grid[r][c] = 1; // block
        }
      }
    }

    // Seed with an open interior, then add symmetric blocks to meet density and run constraints.
    int interiorCells = (w - 2) * (h - 2);
    int targetBlocks = (density * interiorCells).round();

    // 180-degree rotational symmetry placement helper.
    void placeSym(int r, int c, int val) {
      grid[r][c] = val;
      grid[h - 1 - r][w - 1 - c] = val;
    }

    // Randomly sprinkle blocks with symmetry, while keeping runs valid.
    final List<List<int>> candidates = <List<int>>[];
    for (int r = 1; r < h - 1; r++) {
      for (int c = 1; c < w - 1; c++) {
        // Only consider one of each symmetric pair.
        if (r > h - 1 - r || (r == h - 1 - r && c > w - 1 - c)) continue;
        candidates.add(<int>[r, c]);
      }
    }
    final List<List<int>> order = rng.permute(candidates);
    int placed = 0;
    for (final List<int> rc in order) {
      if (placed >= targetBlocks) break;
      final int r = rc[0], c = rc[1];
      if (grid[r][c] == 1) continue;
      // Tentatively place and validate.
      placeSym(r, c, 1);
      if (!_runsValid(grid, minRun, maxRun)) {
        // Revert if invalid.
        placeSym(r, c, 0);
        continue;
      }
      placed += (r == h - 1 - r && c == w - 1 - c) ? 1 : 2;
    }

    // Repair any remaining violations by splitting long runs and removing singletons.
    _repairRuns(rng, grid, minRun, maxRun);

    // Convert to layout strings ('.' = value, '#' = block)
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

  // Legacy fixed template builder removed; layouts are randomized per seed.

  // Previously cached per-length (sum,mask) choices; replaced by direct lookup.

  _TemplateSolution? buildSolvedSolution({
    required SeededRng rng,
    required KakuroSolver solver,
    required SeededRng Function() solverRngFactory,
    int maxTries = 32,
    double comboBias = 0.0,
    double minSingleComboRatio = 0.0,
  }) {
    for (int attempt = 0; attempt < maxTries; attempt++) {
      final Map<int, int> entrySums = <int, int>{};
      bool valid = true;
      int singleComboCount = 0;
      for (final _TemplateEntry entry in entries) {
        final Map<int, Set<int>>? combos = KakuroDictionary.getCombinationsForLength(entry.length);
        if (combos == null || combos.isEmpty) {
          valid = false;
          break;
        }
        // Weighted selection of sums based on number of combination masks.
        // comboBias < 0 prefers fewer combos; > 0 prefers more combos.
        final List<int> sums = combos.keys.toList(growable: false);
        final List<int> weights = sums.map((int sum) {
          final int k = combos[sum]!.length;
          // Map bias to integer weights deterministically.
          // When bias == 0 -> uniform weights (1).
          if (comboBias == 0.0) return 1;
          final double base = k.toDouble().clamp(1.0, 32.0);
          final double scaled = comboBias > 0 ? powd(base, comboBias) : 1.0 / powd(base, -comboBias);
          final int w = scaled.isNaN || scaled.isInfinite ? 1 : (scaled * 128.0).clamp(1.0, 1e9).toInt();
          return w <= 0 ? 1 : w;
        }).toList(growable: false);
        final int sumChoice = _weightedPick(rng, sums, weights);
        entrySums[entry.id] = sumChoice;
        if ((combos[sumChoice]?.length ?? 0) == 1) {
          singleComboCount++;
        }
      }
      if (!valid) {
        continue;
      }

      // Quick gate: require enough single-combo entries by difficulty
      final int entryCount = entries.length == 0 ? 1 : entries.length;
      final double singleRatio = singleComboCount / entryCount;
      if (singleRatio + 1e-9 < minSingleComboRatio) {
        continue;
      }

      final KakuroBoard board = buildBoard(entrySums);
      final SolverResult<KakuroBoard> result = solver.solve(
        board,
        SolverContext(
          rng: solverRngFactory(),
          maxSolutions: 1,
        ),
      );
      if (!result.hasSolution || result.solutions.isEmpty) {
        continue;
      }
      return _TemplateSolution(
        values: List<int>.from(result.solutions.first.values),
        entrySums: entrySums,
      );
    }
    return null;
  }

  // Deterministic lightweight power for doubles.
  static double powd(double base, double exp) {
    // Fast exp via integer steps when possible.
    if (exp == 1.0) return base;
    if (exp == 2.0) return base * base;
    double result = 1.0;
    final int steps = exp.abs().round();
    final double factor = exp >= 0 ? base : 1.0 / base;
    for (int i = 0; i < steps; i++) {
      result *= factor;
    }
    return result;
  }

  static int _weightedPick(SeededRng rng, List<int> values, List<int> weights) {
    int total = 0;
    for (final int w in weights) {
      total += w;
    }
    if (total <= 0) {
      return values[rng.nextIntInRange(values.length)];
    }
    int pick = rng.nextIntInRange(total);
    int acc = 0;
    for (int i = 0; i < values.length; i++) {
      acc += weights[i];
      if (pick < acc || i == values.length - 1) {
        return values[i];
      }
    }
    return values.last;
  }

  static _KakuroTemplate _buildFromLayout(List<String> layout) {
    final int height = layout.length;
    final int width = layout.first.length;
    final List<KakuroCellKind> kinds =
        List<KakuroCellKind>.generate(width * height, (int _) => KakuroCellKind.block);
    final List<int> acrossEntryForCell = List<int>.filled(width * height, -1);
    final List<int> downEntryForCell = List<int>.filled(width * height, -1);
    final List<_TemplateEntry> entries = <_TemplateEntry>[];

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
            final _TemplateEntry entry = _TemplateEntry(
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
            final _TemplateEntry entry = _TemplateEntry(
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

    return _KakuroTemplate(
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
    for (final _TemplateEntry entry in entries) {
      final int sum = entrySums[entry.id] ?? 0;
      boardEntries.add(
        KakuroEntry(
          id: entry.id,
          direction: entry.direction,
          cells: entry.cells,
          sum: sum,
        ),
      );
      if (entry.cells.isEmpty) {
        continue;
      }
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

// Fallback carving path removed in newspaper mode.

_TemplateSolution? _constructSolution(_KakuroTemplate template, SeededRng rng) {
  final int cellCount = template.width * template.height;
  final List<int> values = List<int>.filled(cellCount, 0);
  // Entry used digit sets
  final Map<int, Set<int>> usedAcross = <int, Set<int>>{};
  final Map<int, Set<int>> usedDown = <int, Set<int>>{};

  final List<int> cells = List<int>.from(template.valueCells);
  // Heuristic order: by (acrossLen + downLen) ascending
  cells.sort((int a, int b) {
    int al = 0, bl = 0;
    final int ae = template.acrossEntryForCell[a];
    final int be = template.acrossEntryForCell[b];
    final int ad = template.downEntryForCell[a];
    final int bd = template.downEntryForCell[b];
    if (ae >= 0) {
      al += template.entries[ae].length;
    }
    if (ad >= 0) {
      al += template.entries[ad].length;
    }
    if (be >= 0) {
      bl += template.entries[be].length;
    }
    if (bd >= 0) {
      bl += template.entries[bd].length;
    }
    return al.compareTo(bl);
  });

  bool backtrack(int index) {
    if (index >= cells.length) {
      return true;
    }
    final int cell = cells[index];
    final int ae = template.acrossEntryForCell[cell];
    final int de = template.downEntryForCell[cell];
    final Set<int> ua = usedAcross.putIfAbsent(ae, () => <int>{});
    final Set<int> ud = usedDown.putIfAbsent(de, () => <int>{});
    final List<int> digits = <int>[];
    for (int d = 1; d <= 9; d++) {
      if (!ua.contains(d) && !ud.contains(d)) {
        digits.add(d);
      }
    }
    if (digits.isEmpty) {
      return false;
    }
    final List<int> order = rng.permute(digits);
    for (final int d in order) {
      ua.add(d);
      ud.add(d);
      values[cell] = d;
      if (backtrack(index + 1)) {
        return true;
      }
      values[cell] = 0;
      ua.remove(d);
      ud.remove(d);
    }
    return false;
  }

  final bool ok = backtrack(0);
  if (!ok) {
    return null;
  }

  // Compute sums per entry
  final Map<int, int> entrySums = <int, int>{};
  for (final _TemplateEntry entry in template.entries) {
    int sum = 0;
    final Set<int> seen = <int>{};
    for (final int idx in entry.cells) {
      final int v = values[idx];
      if (v == 0 || !seen.add(v)) {
        return null; // should not happen
      }
      sum += v;
    }
    entrySums[entry.id] = sum;
  }

  return _TemplateSolution(values: values, entrySums: entrySums);
}

// Helper: choose width/height based on provided size or difficulty defaults.
int _chooseWidth(GeneratorContext context) {
  final int provided = context.size.width;
  if (provided > 0) return provided;
  // Default range 10..14.
  return 10 + (context.rng.nextIntInRange(5));
}

int _chooseHeight(GeneratorContext context) {
  final int provided = context.size.height;
  if (provided > 0) return provided;
  return 10 + (context.rng.nextIntInRange(5));
}

bool _meetsLogicThresholds(String level, Map<String, Object?> telemetry) {
  final int backtrackNodes = (telemetry['backtrackNodes'] as int?) ?? 0;
  final int propagationRounds = (telemetry['propagationRounds'] as int?) ?? 0;
  switch (level) {
    case 'easy':
      return backtrackNodes == 0 && propagationRounds <= 40;
    case 'medium':
      return backtrackNodes <= 8 && propagationRounds <= 80;
    case 'hard':
      return backtrackNodes <= 40 && propagationRounds <= 160;
    default:
      return backtrackNodes <= 80;
  }
}

bool _runsValid(List<List<int>> grid, int minRun, int maxRun) {
  final int h = grid.length;
  final int w = grid.first.length;
  // Check rows
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
  // Check columns
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

  // Helper to place with 180-symmetry.
  void placeSym(int r, int c, int val) {
    grid[r][c] = val;
    grid[h - 1 - r][w - 1 - c] = val;
  }

  // Split overlong runs by inserting blocks not adjacent to create length 1.
  bool changed = true;
  int safety = 0;
  while (changed && safety < 400) {
    safety++;
    changed = false;
    // Rows
    for (int r = 1; r < h - 1; r++) {
      int c = 0;
      while (c < w) {
        // Skip blocks
        while (c < w && grid[r][c] == 1) c++;
        int start = c;
        while (c < w && grid[r][c] == 0) c++;
        int end = c - 1;
        final int len = end - start + 1;
        if (len >= 1 && (len < minRun || len > maxRun)) {
          // Choose split positions to keep parts within [minRun, maxRun].
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
                // revert
                placeSym(r, pick, 0);
              }
            }
          }
        }
      }
    }
    // Columns
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
