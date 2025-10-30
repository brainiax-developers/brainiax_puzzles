import '../difficulty/difficulty_config.dart';
import '../difficulty/telemetry.dart';
import '../generators/generator.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../util/seeded_rng.dart';
import 'kakuro_board.dart';
import 'kakuro_difficulty.dart';
import 'kakuro_solver.dart';

const int _solverSalt = 0x6f95c2c1ab7342ed;

class KakuroGenerator extends PuzzleGenerator<KakuroBoard> {
  const KakuroGenerator({this.maxTemplateAttempts = 64});

  final int maxTemplateAttempts;

  static final DifficultyBucketConfig _difficultyConfig =
      const DifficultyConfigLoader().loadSync('assets/kakuro_difficulty_thresholds.json');

  static const KakuroDifficultyScorer _difficultyScorer = KakuroDifficultyScorer();

  @override
  PuzzleGenerationResult<KakuroBoard> generate(GeneratorContext context) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final String requestedLevel = context.difficulty.level.trim().toLowerCase();
    final _KakuroTemplate template = _KakuroTemplate.templateForDifficulty(requestedLevel);
    final KakuroSolver solver = const KakuroSolver();

    int attempts = 0;
    Map<String, Object?> telemetry = const <String, Object?>{};
    KakuroBoard? puzzle;

    // Adjust attempt limit based on grid size - smaller grids need fewer attempts
    // Easy (5x5): 3x base, Medium (7x7): 8x base, Hard (9x9): 10x base
    final int multiplier = template.width <= 5 ? 3 : (template.width <= 7 ? 8 : 10);
    final int attemptLimit = maxTemplateAttempts * multiplier;

    while (attempts < attemptLimit) {
      attempts++;
      final _TemplateSolution? solution = template.buildSolution(context.rng);
      if (solution == null) {
        continue;
      }
      final KakuroBoard candidate = template.buildBoard(solution.entrySums, solution.givenCells, solution.values);
      final SolverResult<KakuroBoard> result = solver.solve(
        candidate,
        SolverContext(
          rng: SeededRng(context.seed64 ^ _solverSalt ^ attempts),
          maxSolutions: 2,
        ),
      );
      if (!result.isUnique || result.solutions.isEmpty) {
        continue;
      }
      final KakuroBoard solved = result.solutions.first;
      if (!_matchesSolution(solved, solution.values)) {
        continue;
      }

      final DifficultyTelemetry difficultyTelemetry = _difficultyScorer.score(
        puzzle: candidate,
        solution: solved,
        context: DifficultyContext(
          generatorTelemetry: const <String, Object?>{},
          solverTelemetry: result.telemetry,
        ),
      );
      final String bucket = _difficultyConfig.bucketFor(difficultyTelemetry.rawScore);
      // Difficulty enforcement disabled - accept any difficulty level
      // if (enforceDifficulty && bucket != requestedLevel) {
      //   continue;
      // }

      final Map<String, Object?> sanitizedSolverTelemetry =
          result.telemetry.map((String key, Object? value) {
        if (value is double) {
          return MapEntry<String, Object?>(key, (value * 1000).round());
        }
        return MapEntry<String, Object?>(key, value);
      });

      puzzle = candidate;
      telemetry = <String, Object?>{
        'attempts': attempts,
        'attemptLimit': attemptLimit,
        'generationDurationUs': stopwatch.elapsedMicroseconds,
        'solverTelemetry': sanitizedSolverTelemetry,
        'solutionSignature': solution.signature,
        'difficultyBucket': bucket,
        'requestedDifficulty': requestedLevel,
        'difficultyScoreMilli': (difficultyTelemetry.rawScore * 1000).round(),
      };
      break;
    }

    stopwatch.stop();

    if (puzzle == null) {
      throw StateError('Unable to generate unique Kakuro for seed ${context.seedStr}');
    }

    DeterminismGuard.assertNoFloatsOrDateTimes(telemetry);

    return PuzzleGenerationResult<KakuroBoard>(
      board: puzzle,
      snapshot: GenerationSnapshot(telemetry: telemetry),
    );
  }

  bool _matchesSolution(KakuroBoard solved, List<int> expectedValues) {
    if (solved.values.length != expectedValues.length) {
      return false;
    }
    for (int i = 0; i < solved.values.length; i++) {
      if (expectedValues[i] == 0) {
        continue;
      }
      if (solved.values[i] != expectedValues[i]) {
        return false;
      }
    }
    return true;
  }
}

class _TemplateSolution {
  _TemplateSolution({
    required this.values,
    required this.entrySums,
    this.givenCells = const <int>{},
  }) : signature = _computeSignature(values);

  final List<int> values;
  final Map<int, int> entrySums;
  final Set<int> givenCells;
  final String signature;

  static String _computeSignature(List<int> values) {
    final StringBuffer buffer = StringBuffer();
    for (final int value in values) {
      buffer.write(value);
    }
    return buffer.toString();
  }
}

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
  });

  final int width;
  final int height;
  final List<String> layout;
  final List<KakuroCellKind> kinds;
  final List<_TemplateEntry> entries;
  final List<int> acrossEntryForCell;
  final List<int> downEntryForCell;

  static _KakuroTemplate? _cachedEasy;
  static _KakuroTemplate? _cachedMedium;
  static _KakuroTemplate? _cachedHard;

  static _KakuroTemplate templateForDifficulty(String difficulty) {
    final String level = difficulty.trim().toLowerCase();
    switch (level) {
      case 'easy':
        return _cachedEasy ??= _buildEasy();
      case 'medium':
        return _cachedMedium ??= _buildMedium();
      case 'hard':
      default:
        return _cachedHard ??= _buildHard();
    }
  }

  static _KakuroTemplate _buildEasy() {
    // 5x5 grid - simpler layout for easy difficulty
    const List<String> layout = <String>[
      '#####',
      '#...#',
      '#...#',
      '#...#',
      '#####',
    ];
    return _buildFromLayout(layout);
  }

  static _KakuroTemplate _buildMedium() {
    // 7x7 grid - moderate complexity for medium difficulty
    const List<String> layout = <String>[
      '#######',
      '#.....#',
      '#.....#',
      '#..#..#',
      '#.....#',
      '#.....#',
      '#######',
    ];
    return _buildFromLayout(layout);
  }

  static _KakuroTemplate _buildHard() {
    // 9x9 grid - complex layout for hard difficulty
    const List<String> layout = <String>[
      '#########',
      '##.....##',
      '#.......#',
      '#...#...#',
      '#..###..#',
      '#...#...#',
      '#.......#',
      '##.....##',
      '#########',
    ];
    return _buildFromLayout(layout);
  }

  static _KakuroTemplate _buildFromLayout(List<String> layout) {
    final int height = layout.length;
    final int width = layout.first.length;
    final List<KakuroCellKind> kinds =
        List<KakuroCellKind>.generate(width * height, (int index) => KakuroCellKind.block);
    final List<int> acrossEntryForCell = List<int>.filled(width * height, -1);
    final List<int> downEntryForCell = List<int>.filled(width * height, -1);
    final List<_TemplateEntry> entries = <_TemplateEntry>[];

    int entryId = 0;
    // Across entries
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

    // Down entries
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

    return _KakuroTemplate(
      width: width,
      height: height,
      layout: layout,
      kinds: kinds,
      entries: entries,
      acrossEntryForCell: acrossEntryForCell,
      downEntryForCell: downEntryForCell,
    );
  }

  _TemplateSolution? buildSolution(SeededRng rng) {
    // Strategy: Generate random target sums for each entry within valid ranges,
    // then use solver to find a valid solution that satisfies those sums
    
    // Generate random but valid sums for each entry
    // Use a more conservative middle range to increase solvability
    final Map<int, int> targetSums = <int, int>{};
    for (final _TemplateEntry entry in entries) {
      final int length = entry.cells.length;
      // Minimum sum: 1+2+...+length
      final int minSum = (length * (length + 1)) ~/ 2;
      // Maximum sum: (9)+(9-1)+...+(9-length+1)
      int maxSum = 0;
      for (int i = 0; i < length; i++) {
        maxSum += (9 - i);
      }
      // Bias toward middle range for better solvability (25%-75% of range)
      final int range = maxSum - minSum;
      final int quarterRange = range ~/ 4;
      final int start = minSum + quarterRange;
      final int end = maxSum - quarterRange;
      final int sum = rng.randIntRange(start, end + 1);
      targetSums[entry.id] = sum;
    }
    
    final KakuroBoard tempBoard = buildBoard(targetSums);
    final KakuroSolver solver = const KakuroSolver(maxSearchDepth: 50);
    
    // Use solver to find ONE solution with the randomized RNG
    final SolverResult<KakuroBoard> result = solver.solve(
      tempBoard,
      SolverContext(rng: rng, maxSolutions: 1),
    );
    
    if (!result.hasSolution || result.solutions.isEmpty) {
      return null;
    }
    
    final KakuroBoard solved = result.solutions.first;
    final List<int> values = List<int>.from(solved.values);
    
    // Extract actual sums from the solution
    final Map<int, int> entrySums = <int, int>{};
    for (final _TemplateEntry entry in entries) {
      int sum = 0;
      for (final int cellIndex in entry.cells) {
        sum += values[cellIndex];
      }
      entrySums[entry.id] = sum;
    }

    // NEW: Add some pre-filled cells to increase uniqueness probability
    // Select 15-30% of cells to be givens, with variation based on RNG
    final List<int> playableCells = <int>[];
    for (int i = 0; i < values.length; i++) {
      if (kinds[i] == KakuroCellKind.value && values[i] != 0) {
        playableCells.add(i);
      }
    }
    
    // Randomize the percentage of givens between 15-30%
    final double givenRatio = 0.15 + (rng.nextIntInRange(16) / 100.0);
    final int givenCount = (playableCells.length * givenRatio).round();
    final List<int> shuffledCells = rng.permute(playableCells);
    final List<int> givenCells = shuffledCells.take(givenCount).toList();
    
    // Store which cells have pre-filled values
    final Set<int> givenSet = givenCells.toSet();
    
    return _TemplateSolution(
      values: values,
      entrySums: entrySums,
      givenCells: givenSet,
    );
  }

  KakuroBoard buildBoard(Map<int, int> entrySums, [Set<int> givenCells = const <int>{}, List<int>? solutionValues]) {
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

    // Initialize values - fill in given cells if provided
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
