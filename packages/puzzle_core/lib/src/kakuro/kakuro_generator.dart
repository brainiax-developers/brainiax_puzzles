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
const int _allDigitsMask = 0x3fe;

class KakuroGenerator extends PuzzleGenerator<KakuroBoard> {
  const KakuroGenerator({this.maxTemplateAttempts = 64});

  final int maxTemplateAttempts;

  static final DifficultyBucketConfig _difficultyConfig =
      const DifficultyConfigLoader().loadSync('assets/kakuro_difficulty_thresholds.json');

  static const KakuroDifficultyScorer _difficultyScorer = KakuroDifficultyScorer();

  @override
  PuzzleGenerationResult<KakuroBoard> generate(GeneratorContext context) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final _KakuroTemplate template = _KakuroTemplate.defaultTemplate();
    final KakuroSolver solver = const KakuroSolver();

    int attempts = 0;
    Map<String, Object?> telemetry = const <String, Object?>{};
    KakuroBoard? puzzle;

    final String requestedLevel = context.difficulty.level.trim().toLowerCase();
    final bool enforceDifficulty = requestedLevel.isNotEmpty &&
        requestedLevel != 'auto' &&
        _difficultyConfig.buckets
            .any((DifficultyBucketThreshold threshold) => threshold.id == requestedLevel);
    final int attemptLimit = enforceDifficulty ? maxTemplateAttempts * 2 : maxTemplateAttempts;

    while (attempts < attemptLimit) {
      attempts++;
      final _TemplateSolution? solution = template.buildSolution(context.rng);
      if (solution == null) {
        continue;
      }
      final KakuroBoard candidate = template.buildBoard(solution.entrySums);
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
      if (enforceDifficulty && bucket != requestedLevel) {
        continue;
      }

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

  static _KakuroTemplate? _cached;

  static _KakuroTemplate defaultTemplate() {
    return _cached ??= _build();
  }

  static _KakuroTemplate _build() {
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
    final int cellCount = width * height;
    final List<int> values = List<int>.filled(cellCount, 0);
    final Map<int, _EntryState> entryStates = _buildEntryStates();
    if (entryStates.isEmpty) {
      return null;
    }

    if (!_selectEntryCombinations(entryStates, rng)) {
      return null;
    }

    for (final _EntryState state in entryStates.values) {
      state.resetDigits();
    }

    final List<int> valueCells = <int>[];
    for (int index = 0; index < cellCount; index++) {
      if (kinds[index] == KakuroCellKind.value) {
        valueCells.add(index);
      }
    }

    if (!_assignDigits(values, valueCells, entryStates, rng)) {
      return null;
    }

    final Map<int, int> entrySums = <int, int>{};
    for (final _TemplateEntry entry in entries) {
      int sum = 0;
      for (final int cellIndex in entry.cells) {
        sum += values[cellIndex];
      }
      entrySums[entry.id] = sum;
    }

    return _TemplateSolution(values: values, entrySums: entrySums);
  }

  Map<int, _EntryState> _buildEntryStates() {
    final Map<int, _EntryState> entryStates = <int, _EntryState>{};
    for (final _TemplateEntry entry in entries) {
      final Map<int, Set<int>>? combos =
          KakuroDictionary.getCombinationsForLength(entry.length);
      if (combos == null || combos.isEmpty) {
        return <int, _EntryState>{};
      }
      final List<_CombinationOption> options = <_CombinationOption>[];
      combos.forEach((int sum, Set<int> masks) {
        for (final int mask in masks) {
          options.add(_CombinationOption(sum: sum, mask: mask));
        }
      });
      if (options.isEmpty) {
        return <int, _EntryState>{};
      }
      entryStates[entry.id] = _EntryState(entry: entry, options: options);
    }
    return entryStates;
  }

  bool _selectEntryCombinations(Map<int, _EntryState> entryStates, SeededRng rng) {
    final List<_EntryState> ordered = entryStates.values.toList()
      ..sort((_EntryState a, _EntryState b) =>
          b.entry.cells.length.compareTo(a.entry.cells.length));

    bool backtrack(int index) {
      if (index >= ordered.length) {
        return true;
      }
      final _EntryState state = ordered[index];
      final List<_CombinationOption> shuffled = rng.permute(state.options);
      for (final _CombinationOption option in shuffled) {
        if (!_isCompatible(state, option, entryStates)) {
          continue;
        }
        state.select(option);
        if (backtrack(index + 1)) {
          return true;
        }
        state.deselect();
      }
      return false;
    }

    return backtrack(0);
  }

  bool _isCompatible(
    _EntryState state,
    _CombinationOption option,
    Map<int, _EntryState> entryStates,
  ) {
    final int mask = option.mask;
    for (final int cellIndex in state.entry.cells) {
      final int neighbourId = state.entry.direction == KakuroDirection.across
          ? downEntryForCell[cellIndex]
          : acrossEntryForCell[cellIndex];
      if (neighbourId < 0) {
        continue;
      }
      final _EntryState? neighbour = entryStates[neighbourId];
      if (neighbour == null || neighbour.selected == null) {
        continue;
      }
      if ((mask & neighbour.selected!.mask) == 0) {
        return false;
      }
    }
    return true;
  }

  bool _assignDigits(
    List<int> values,
    List<int> valueCells,
    Map<int, _EntryState> entryStates,
    SeededRng rng,
  ) {
    int? targetIndex;
    List<int>? targetCandidates;

    for (final int index in valueCells) {
      if (values[index] != 0) {
        continue;
      }
      final List<int> candidates = _cellCandidates(index, entryStates);
      if (candidates.isEmpty) {
        return false;
      }
      if (targetIndex == null || candidates.length < targetCandidates!.length) {
        targetIndex = index;
        targetCandidates = candidates;
        if (candidates.length == 1) {
          break;
        }
      }
    }

    if (targetIndex == null) {
      return true;
    }

    final _EntryState? across = entryStates[acrossEntryForCell[targetIndex]];
    final _EntryState? down = entryStates[downEntryForCell[targetIndex]];
    final List<int> shuffled = rng.permute(targetCandidates!);
    for (final int digit in shuffled) {
      if (across != null && !across.canUseDigit(digit)) {
        continue;
      }
      if (down != null && !down.canUseDigit(digit)) {
        continue;
      }
      across?.useDigit(digit);
      down?.useDigit(digit);
      values[targetIndex] = digit;
      if (_assignDigits(values, valueCells, entryStates, rng)) {
        return true;
      }
      values[targetIndex] = 0;
      down?.releaseDigit(digit);
      across?.releaseDigit(digit);
    }

    return false;
  }

  List<int> _cellCandidates(int index, Map<int, _EntryState> entryStates) {
    int mask = _allDigitsMask;
    final _EntryState? across = entryStates[acrossEntryForCell[index]];
    final _EntryState? down = entryStates[downEntryForCell[index]];

    if (across != null) {
      if (!across.isSelected) {
        return const <int>[];
      }
      mask &= across.remainingMask;
    }
    if (down != null) {
      if (!down.isSelected) {
        return const <int>[];
      }
      mask &= down.remainingMask;
    }

    return _digitsFromMask(mask);
  }

  KakuroBoard buildBoard(Map<int, int> entrySums) {
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

class _EntryState {
  _EntryState({
    required this.entry,
    required this.options,
  });

  final _TemplateEntry entry;
  final List<_CombinationOption> options;

  _CombinationOption? selected;
  int remainingMask = 0;

  bool get isSelected => selected != null;

  void select(_CombinationOption option) {
    selected = option;
    remainingMask = option.mask;
  }

  void deselect() {
    selected = null;
    remainingMask = 0;
  }

  void resetDigits() {
    remainingMask = selected?.mask ?? 0;
  }

  bool canUseDigit(int digit) => (remainingMask & (1 << digit)) != 0;

  void useDigit(int digit) {
    remainingMask &= ~(1 << digit);
  }

  void releaseDigit(int digit) {
    remainingMask |= 1 << digit;
  }
}

class _CombinationOption {
  const _CombinationOption({
    required this.sum,
    required this.mask,
  });

  final int sum;
  final int mask;
}

List<int> _digitsFromMask(int mask) {
  if (mask == 0) {
    return const <int>[];
  }
  final List<int> digits = <int>[];
  for (int digit = 1; digit <= 9; digit++) {
    if ((mask & (1 << digit)) != 0) {
      digits.add(digit);
    }
  }
  return digits;
}
