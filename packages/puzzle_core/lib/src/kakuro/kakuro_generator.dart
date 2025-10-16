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
    final Map<int, int> entrySums = <int, int>{};
    final Map<int, List<int>> entryDigits = <int, List<int>>{};

    for (final _TemplateEntry entry in entries) {
      final Map<int, Set<int>>? combos =
          KakuroDictionary.getCombinationsForLength(entry.length);
      if (combos == null || combos.isEmpty) {
        return null;
      }
      final List<_CombinationOption> options = <_CombinationOption>[];
      combos.forEach((int sum, Set<int> masks) {
        for (final int mask in masks) {
          options.add(_CombinationOption(sum: sum, mask: mask));
        }
      });
      if (options.isEmpty) {
        return null;
      }
      final _CombinationOption choice = options[rng.nextIntInRange(options.length)];
      entrySums[entry.id] = choice.sum;
      entryDigits[entry.id] = _digitsFromMask(choice.mask);
    }

    final List<int> fillOrder = <int>[];
    for (int index = 0; index < cellCount; index++) {
      if (kinds[index] == KakuroCellKind.value) {
        fillOrder.add(index);
      }
    }
    rng.shuffle(fillOrder);

    final Map<int, List<int>> remaining = <int, List<int>>{};
    entryDigits.forEach((int id, List<int> digits) {
      remaining[id] = List<int>.from(digits);
    });

    if (_assignCell(0, fillOrder, values, remaining, rng)) {
      return _TemplateSolution(values: values, entrySums: entrySums);
    }
    return null;
  }

  bool _assignCell(
    int depth,
    List<int> order,
    List<int> values,
    Map<int, List<int>> remaining,
    SeededRng rng,
  ) {
    if (depth >= order.length) {
      return true;
    }
    final int index = order[depth];
    if (values[index] != 0) {
      return _assignCell(depth + 1, order, values, remaining, rng);
    }
    final int acrossId = acrossEntryForCell[index];
    final int downId = downEntryForCell[index];
    final List<int> acrossDigits = acrossId >= 0 ? remaining[acrossId]! : <int>[];
    final List<int> downDigits = downId >= 0 ? remaining[downId]! : <int>[];

    final Set<int> candidateSet = <int>{};
    if (acrossDigits.isEmpty && downDigits.isEmpty) {
      return false;
    } else if (acrossDigits.isEmpty) {
      candidateSet.addAll(downDigits);
    } else if (downDigits.isEmpty) {
      candidateSet.addAll(acrossDigits);
    } else {
      for (final int digit in acrossDigits) {
        if (downDigits.contains(digit)) {
          candidateSet.add(digit);
        }
      }
    }

    if (candidateSet.isEmpty) {
      return false;
    }

    final List<int> candidates = rng.permute(candidateSet);
    for (final int digit in candidates) {
      if (acrossId >= 0 && !remaining[acrossId]!.contains(digit)) {
        continue;
      }
      if (downId >= 0 && !remaining[downId]!.contains(digit)) {
        continue;
      }
      values[index] = digit;
      if (acrossId >= 0) {
        remaining[acrossId]!.remove(digit);
      }
      if (downId >= 0) {
        remaining[downId]!.remove(digit);
      }
      if (_assignCell(depth + 1, order, values, remaining, rng)) {
        return true;
      }
      if (acrossId >= 0) {
        remaining[acrossId]!.add(digit);
      }
      if (downId >= 0) {
        remaining[downId]!.add(digit);
      }
      values[index] = 0;
    }
    return false;
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

class _CombinationOption {
  const _CombinationOption({
    required this.sum,
    required this.mask,
  });

  final int sum;
  final int mask;
}

List<int> _digitsFromMask(int mask) {
  final List<int> digits = <int>[];
  for (int digit = 1; digit <= 9; digit++) {
    if ((mask & (1 << digit)) != 0) {
      digits.add(digit);
    }
  }
  return digits;
}
