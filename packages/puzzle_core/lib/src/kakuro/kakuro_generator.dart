import '../generators/generator.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../util/kakuro_dictionary.dart';
import '../util/seeded_rng.dart';
import 'kakuro_board.dart';
import 'kakuro_solver.dart';

const int _solverSalt = 0x6f95c2c1ab7342ed;

class KakuroGenerator extends PuzzleGenerator<KakuroBoard> {
  const KakuroGenerator({this.maxTemplateAttempts = 64});

  final int maxTemplateAttempts;

  @override
  PuzzleGenerationResult<KakuroBoard> generate(GeneratorContext context) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final _KakuroTemplate template = _KakuroTemplate.defaultTemplate();
    final KakuroSolver solver = const KakuroSolver();

    int attempts = 0;
    Map<String, Object?> telemetry = const <String, Object?>{};
    KakuroBoard? puzzle;

    while (attempts < maxTemplateAttempts) {
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
      puzzle = candidate;
      telemetry = <String, Object?>{
        'attempts': attempts,
        'generationDurationUs': stopwatch.elapsedMicroseconds,
        'solverTelemetry': result.telemetry,
        'solutionSignature': solution.signature,
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
          final int start = col;
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
          final int start = row;
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
    final Map<int, _EntryState> entryStates = <int, _EntryState>{};
    for (final _TemplateEntry entry in entries) {
      final Map<int, Set<int>>? combos =
          KakuroDictionary.getCombinationsForLength(entry.length);
      if (combos == null || combos.isEmpty) {
        return null;
      }
      final List<_CombinationOption> options = <_CombinationOption>[];
      combos.forEach((int sum, Set<int> masks) {
        for (final int mask in masks) {
          options.add(
            _CombinationOption(
              sum: sum,
              mask: mask,
              digitCount: entry.length,
            ),
          );
        }
      });
      if (options.isEmpty) {
        return null;
      }
      entryStates[entry.id] = _EntryState(entry: entry, options: options);
    }

    final List<int> valueCells = <int>[];
    for (int index = 0; index < cellCount; index++) {
      if (kinds[index] == KakuroCellKind.value) {
        valueCells.add(index);
      }
    }

    if (!_fillCells(values, valueCells, entryStates, rng)) {
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

  bool _fillCells(
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
      final List<int> candidates = _candidateDigits(index, entryStates);
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
      if (across != null && !across.canAssignDigit(digit)) {
        continue;
      }
      if (down != null && !down.canAssignDigit(digit)) {
        continue;
      }
      across?.assignDigit(digit);
      down?.assignDigit(digit);
      values[targetIndex] = digit;
      if (_fillCells(values, valueCells, entryStates, rng)) {
        return true;
      }
      values[targetIndex] = 0;
      down?.unassignDigit(digit);
      across?.unassignDigit(digit);
    }

    return false;
  }

  List<int> _candidateDigits(
    int index,
    Map<int, _EntryState> entryStates,
  ) {
    Set<int>? candidates;
    final _EntryState? across = entryStates[acrossEntryForCell[index]];
    final _EntryState? down = entryStates[downEntryForCell[index]];

    if (across != null) {
      candidates = across.possibleDigits().toSet();
    }
    if (down != null) {
      final Set<int> downDigits = down.possibleDigits().toSet();
      if (candidates == null) {
        candidates = downDigits;
      } else {
        candidates.retainAll(downDigits);
      }
    }

    return candidates?.toList(growable: false) ?? const <int>[];
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
  }) : remainingCells = entry.cells.length;

  final _TemplateEntry entry;
  final List<_CombinationOption> options;

  int assignedMask = 0;
  int assignedCount = 0;
  int remainingCells;

  List<int> possibleDigits() {
    if (remainingCells == 0) {
      return const <int>[];
    }
    final List<int> digits = <int>[];
    for (int digit = 1; digit <= 9; digit++) {
      if (canAssignDigit(digit)) {
        digits.add(digit);
      }
    }
    return digits;
  }

  bool canAssignDigit(int digit) {
    final int bit = 1 << digit;
    if ((assignedMask & bit) != 0) {
      return false;
    }
    final int newMask = assignedMask | bit;
    final int newAssignedCount = assignedCount + 1;
    final int newRemaining = remainingCells - 1;
    for (final _CombinationOption option in options) {
      if ((option.mask & newMask) != newMask) {
        continue;
      }
      final int availableDigits = option.digitCount - newAssignedCount;
      if (availableDigits < newRemaining) {
        continue;
      }
      if (newRemaining == 0 && option.mask != newMask) {
        continue;
      }
      return true;
    }
    return false;
  }

  void assignDigit(int digit) {
    assignedMask |= 1 << digit;
    assignedCount++;
    remainingCells--;
  }

  void unassignDigit(int digit) {
    assignedMask &= ~(1 << digit);
    assignedCount--;
    remainingCells++;
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

class _CombinationOption {
  const _CombinationOption({
    required this.sum,
    required this.mask,
    required this.digitCount,
  });

  final int sum;
  final int mask;
  final int digitCount;
}
