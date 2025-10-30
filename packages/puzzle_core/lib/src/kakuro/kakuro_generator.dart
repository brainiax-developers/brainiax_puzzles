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

class _DifficultyProfile {
  const _DifficultyProfile({
    required this.level,
    required this.minGivenRatio,
    required this.maxGivenRatio,
  });

  final String level;
  final double minGivenRatio;
  final double maxGivenRatio;

  int minGivens(int total) {
    final int raw = (total * minGivenRatio).ceil();
    if (raw < 1) {
      return 1;
    }
    if (raw > total) {
      return total;
    }
    return raw;
  }

  int maxGivens(int total) {
    final int raw = (total * maxGivenRatio).round();
    final int min = minGivens(total);
    if (raw < 1) {
      return 1;
    }
    if (raw > total) {
      return total;
    }
    if (raw < min) {
      return min;
    }
    return raw;
  }

}

const Map<String, _DifficultyProfile> _difficultyProfiles = <String, _DifficultyProfile>{
  'easy': _DifficultyProfile(
    level: 'easy',
    minGivenRatio: 0.45,
    maxGivenRatio: 0.58,
  ),
  'medium': _DifficultyProfile(
    level: 'medium',
    minGivenRatio: 0.32,
    maxGivenRatio: 0.45,
  ),
  'hard': _DifficultyProfile(
    level: 'hard',
    minGivenRatio: 0.20,
    maxGivenRatio: 0.32,
  ),
  'expert': _DifficultyProfile(
    level: 'expert',
    minGivenRatio: 0.13,
    maxGivenRatio: 0.22,
  ),
};

int _deriveSolverSeed(int baseSeed, int attempt, int stage) {
  final int attemptSalt = (attempt * _mixMultiplier) & _mask64;
  final int combined = baseSeed ^ _solverSalt ^ attemptSalt ^ stage;
  return combined & _mask64;
}

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
    final _DifficultyProfile profile =
        _difficultyProfiles[requestedLevel] ?? _difficultyProfiles['hard']!;
    final KakuroSolver solver = const KakuroSolver();

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

      final _TemplateSolution? solution = template.buildSolvedSolution(
        rng: context.rng,
        solver: solver,
        solverRngFactory: nextSolverRng,
        maxTries: 48,
      );
      if (solution == null) {
        continue;
      }

      final _PuzzleCandidate? candidate = _carvePuzzle(
        template: template,
        solver: solver,
        solution: solution,
        profile: profile,
        rng: context.rng,
        nextSolverRng: nextSolverRng,
      );
      if (candidate == null) {
        continue;
      }

      if (candidate.uniqueResult.solutions.isEmpty) {
        continue;
      }

      final DifficultyTelemetry difficultyTelemetry = _difficultyScorer.score(
        puzzle: candidate.board,
        solution: candidate.uniqueResult.solutions.first,
        context: DifficultyContext(
          generatorTelemetry: <String, Object?>{
            'givens': candidate.givenCount,
            'valueCells': template.valueCellCount,
            'removalAttempts': candidate.removalAttempts,
            'removalAccepts': candidate.removalAccepts,
          },
          solverTelemetry: candidate.uniqueResult.telemetry,
        ),
      );
      final String bucket = _difficultyConfig.bucketFor(difficultyTelemetry.rawScore);
      if (bucket != profile.level) {
        if (attempts < attemptLimit) {
          continue;
        }
      }

      final Map<String, Object?> sanitizedSolverTelemetry =
          candidate.uniqueResult.telemetry.map((String key, Object? value) {
        if (value is double) {
          return MapEntry<String, Object?>(key, (value * 1000).round());
        }
        return MapEntry<String, Object?>(key, value);
      });

      puzzle = candidate.board;
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
        'givensCount': candidate.givenCount,
        'givenRatioMilli':
            candidate.givenCount * 1000 ~/ (template.valueCellCount == 0 ? 1 : template.valueCellCount),
        'removalAttempts': candidate.removalAttempts,
        'removalAccepts': candidate.removalAccepts,
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

  _PuzzleCandidate? _carvePuzzle({
    required _KakuroTemplate template,
    required KakuroSolver solver,
    required _TemplateSolution solution,
    required _DifficultyProfile profile,
    required SeededRng rng,
    required SeededRng Function() nextSolverRng,
  }) {
    final Set<int> givenCells = template.valueCells.toSet();
    final int valueCellCount = template.valueCellCount;
    final int minGivens = profile.minGivens(valueCellCount);
    final int maxGivens = profile.maxGivens(valueCellCount);

    final List<int> removalOrder = rng.permute(givenCells.toList(growable: false));
    int removalAttempts = 0;
    int removalAccepts = 0;

    for (final int cellIndex in removalOrder) {
      if (givenCells.length <= minGivens) {
        break;
      }
      removalAttempts++;
      givenCells.remove(cellIndex);
      final KakuroBoard trialBoard = template.buildBoard(
        solution.entrySums,
        givenCells,
        solution.values,
      );
      final SolverResult<KakuroBoard> uniquenessResult = solver.solve(
        trialBoard,
        SolverContext(
          rng: nextSolverRng(),
          maxSolutions: 2,
        ),
      );
      if (!uniquenessResult.isUnique) {
        givenCells.add(cellIndex);
        continue;
      }

      removalAccepts++;
    }

    final KakuroBoard puzzleBoard = template.buildBoard(
      solution.entrySums,
      givenCells,
      solution.values,
    );
    final SolverResult<KakuroBoard> finalResult = solver.solve(
      puzzleBoard,
      SolverContext(
        rng: nextSolverRng(),
        maxSolutions: 2,
      ),
    );
    if (!finalResult.isUnique) {
      return null;
    }

    final int givenCount = givenCells.length;
    if (givenCount < minGivens || givenCount > maxGivens) {
      return null;
    }

    return _PuzzleCandidate(
      board: puzzleBoard,
      uniqueResult: finalResult,
      givenCells: givenCells,
      removalAttempts: removalAttempts,
      removalAccepts: removalAccepts,
    );
  }
}

class _PuzzleCandidate {
  const _PuzzleCandidate({
    required this.board,
    required this.uniqueResult,
    required this.givenCells,
    required this.removalAttempts,
    required this.removalAccepts,
  });

  final KakuroBoard board;
  final SolverResult<KakuroBoard> uniqueResult;
  final Set<int> givenCells;
  final int removalAttempts;
  final int removalAccepts;

  int get givenCount => givenCells.length;
}

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

class _CombinationChoice {
  const _CombinationChoice({
    required this.sum,
    required this.mask,
  });

  final int sum;
  final int mask;
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

  static _KakuroTemplate? _cachedEasy;
  static _KakuroTemplate? _cachedMedium;
  static _KakuroTemplate? _cachedHard;
  static _KakuroTemplate? _cachedExpert;

  static _KakuroTemplate templateForDifficulty(String difficulty) {
    final String level = difficulty.trim().toLowerCase();
    switch (level) {
      case 'easy':
        return _cachedEasy ??= _buildEasy();
      case 'medium':
        return _cachedMedium ??= _buildMedium();
      case 'expert':
        return _cachedExpert ??= _buildHard();
      case 'hard':
      default:
        return _cachedHard ??= _buildHard();
    }
  }

  static _KakuroTemplate _buildEasy() {
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

  static final Map<int, List<_CombinationChoice>> _combinationCache =
      <int, List<_CombinationChoice>>{};

  static List<_CombinationChoice> _choicesForLength(int length) {
    return _combinationCache.putIfAbsent(length, () {
      final Map<int, Set<int>>? combos =
          KakuroDictionary.getCombinationsForLength(length);
      if (combos == null || combos.isEmpty) {
        return const <_CombinationChoice>[];
      }
      final List<_CombinationChoice> choices = <_CombinationChoice>[];
      combos.forEach((int sum, Set<int> masks) {
        for (final int mask in masks) {
          choices.add(_CombinationChoice(sum: sum, mask: mask));
        }
      });
      return choices;
    });
  }

  _TemplateSolution? buildSolvedSolution({
    required SeededRng rng,
    required KakuroSolver solver,
    required SeededRng Function() solverRngFactory,
    int maxTries = 32,
  }) {
    for (int attempt = 0; attempt < maxTries; attempt++) {
      final Map<int, int> entrySums = <int, int>{};
      bool valid = true;
      for (final _TemplateEntry entry in entries) {
        final List<_CombinationChoice> choices = _choicesForLength(entry.length);
        if (choices.isEmpty) {
          valid = false;
          break;
        }
        final _CombinationChoice choice =
            choices[rng.nextIntInRange(choices.length)];
        entrySums[entry.id] = choice.sum;
      }
      if (!valid) {
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
