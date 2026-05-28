import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/kakuro/kakuro_board.dart';
import 'package:puzzle_core/src/kakuro/kakuro_engine.dart';
import 'package:puzzle_core/src/kakuro/kakuro_move.dart';
import 'package:puzzle_core/src/kakuro/kakuro_solver.dart';
import 'package:puzzle_core/src/kakuro/kakuro_validator.dart';
import 'package:puzzle_core/src/solver/solver.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:puzzle_core/src/validation/validator.dart';
import 'package:test/test.dart';

void main() {
  final KakuroEngine engine = KakuroEngine();
  final SizeOpt size = const SizeOpt(
    id: 'template9x9',
    description: 'Template 9x9',
    width: 9,
    height: 9,
  );
  const DifficultyScore difficulty = DifficultyScore(value: 0.0, level: 'auto');

  test('engine generates puzzle with metadata and difficulty telemetry', () {
    final int seed64 = Seed.fromString('kakuro_engine_seed');
    final generated = engine.generate(
      seedStr: 'kakuro_engine_seed',
      seed64: seed64,
      size: size,
      difficulty: difficulty,
    );

    expect(generated.state.width, equals(9));
    expect(generated.meta.seed64, equals(seed64));
    expect(generated.telemetry, isNotNull);
    expect(
      generated.telemetry!.difficulty.metrics.containsKey('rawScore'),
      isTrue,
    );

    final KakuroSolver solver = const KakuroSolver();
    final SolverResult<KakuroBoard> solved = solver.solve(
      generated.state,
      SolverContext(
        rng: SeededRng(seed64 ^ 0x1375a9b3f18c4461),
        maxSolutions: 1,
      ),
    );
    expect(solved.hasSolution, isTrue);
    final KakuroBoard solution = solved.solutions.first;

    final ValidationSummary summary = engine.validator.validateSolution(
      generated.state,
      solution,
    );
    expect(summary.isValid, isTrue, reason: summary.issues.join(','));
  });

  test('validateMove enforces bounds and rules', () {
    final int seed64 = Seed.fromString('kakuro_move_seed');
    final generated = engine.generate(
      seedStr: 'kakuro_move_seed',
      seed64: seed64,
      size: size,
      difficulty: difficulty,
    );
    final KakuroBoard puzzle = generated.state;
    final KakuroSolver solver = const KakuroSolver();
    final KakuroBoard solution = solver
        .solve(puzzle, SolverContext(rng: SeededRng(seed64), maxSolutions: 1))
        .solutions
        .first;

    int targetIndex = -1;
    for (int i = 0; i < puzzle.cellCount; i++) {
      if (puzzle.isPlayableIndex(i)) {
        targetIndex = i;
        break;
      }
    }
    expect(targetIndex, isNot(-1));
    final int row = targetIndex ~/ puzzle.width;
    final int col = targetIndex % puzzle.width;
    final int correctDigit = solution.values[targetIndex];

    final moveResult = engine.validateMove(
      currentState: puzzle,
      move: KakuroMove(row: row, col: col, digit: correctDigit),
    );
    expect(moveResult.isValid, isTrue);

    final invalidResult = engine.validateMove(
      currentState: puzzle,
      move: const KakuroMove(row: -1, col: 0, digit: 5),
    );
    expect(invalidResult.isValid, isFalse);
  });

  group('structural and contradiction validation fixtures', () {
    const KakuroValidator validator = KakuroValidator();

    final Map<String, ({KakuroBoard board, String expectedIssuePrefix})>
    fixtures = <String, ({KakuroBoard board, String expectedIssuePrefix})>{
      'orphan_cell': (
        board: _fixtureBoard(acrossEntryForCell: const <int>[-1, 0, 1, 1]),
        expectedIssuePrefix: 'missing_across_entry',
      ),
      'one_cell_run': (
        board: _fixtureBoard(
          entries: const <KakuroEntry>[
            KakuroEntry(
              id: 0,
              direction: KakuroDirection.across,
              cells: <int>[0],
              sum: 4,
            ),
            KakuroEntry(
              id: 1,
              direction: KakuroDirection.across,
              cells: <int>[1],
              sum: 6,
            ),
            KakuroEntry(
              id: 2,
              direction: KakuroDirection.across,
              cells: <int>[2, 3],
              sum: 7,
            ),
            KakuroEntry(
              id: 3,
              direction: KakuroDirection.down,
              cells: <int>[0, 2],
              sum: 5,
            ),
            KakuroEntry(
              id: 4,
              direction: KakuroDirection.down,
              cells: <int>[1, 3],
              sum: 12,
            ),
          ],
          acrossEntryForCell: const <int>[0, 1, 2, 2],
          downEntryForCell: const <int>[3, 4, 3, 4],
        ),
        expectedIssuePrefix: 'entry_length',
      ),
      'impossible_sum': (
        board: _fixtureBoard(
          entries: const <KakuroEntry>[
            KakuroEntry(
              id: 0,
              direction: KakuroDirection.across,
              cells: <int>[0, 1],
              sum: 2,
            ),
            KakuroEntry(
              id: 1,
              direction: KakuroDirection.across,
              cells: <int>[2, 3],
              sum: 7,
            ),
            KakuroEntry(
              id: 2,
              direction: KakuroDirection.down,
              cells: <int>[0, 2],
              sum: 5,
            ),
            KakuroEntry(
              id: 3,
              direction: KakuroDirection.down,
              cells: <int>[1, 3],
              sum: 12,
            ),
          ],
        ),
        expectedIssuePrefix: 'invalid_clue',
      ),
      'duplicate_digits': (
        board: _fixtureBoard(values: const <int>[4, 4, 0, 0]),
        expectedIssuePrefix: 'duplicate_digit',
      ),
      'sum_exceeded': (
        board: _fixtureBoard(values: const <int>[9, 8, 0, 0]),
        expectedIssuePrefix: 'sum_exceeded',
      ),
      'incompatible_partial_digits': (
        board: _fixtureBoard(values: const <int>[5, 0, 0, 0]),
        expectedIssuePrefix: 'incompatible_digits',
      ),
    };

    test('invalid fixtures are rejected by validator', () {
      for (final MapEntry<
            String,
            ({KakuroBoard board, String expectedIssuePrefix})
          >
          fixture
          in fixtures.entries) {
        final ValidationSummary summary = validator.validatePuzzle(
          fixture.value.board,
        );
        expect(summary.isValid, isFalse, reason: fixture.key);
        expect(
          summary.issues.any(
            (String issue) =>
                issue.startsWith(fixture.value.expectedIssuePrefix),
          ),
          isTrue,
          reason: '${fixture.key}: ${summary.issues.join(',')}',
        );
      }
    });

    test('illegal moves are rejected through validateMove', () {
      final KakuroBoard start = _fixtureBoard();

      final move1 = engine.validateMove(
        currentState: start,
        move: const KakuroMove(row: 0, col: 0, digit: 4),
      );
      expect(move1.isValid, isTrue);

      final duplicateMove = engine.validateMove(
        currentState: move1.newState!,
        move: const KakuroMove(row: 0, col: 1, digit: 4),
      );
      expect(duplicateMove.isValid, isFalse);
      expect(duplicateMove.errorMessage, contains('duplicate_digit'));

      final sumExceededMove = engine.validateMove(
        currentState: _fixtureBoard(values: const <int>[8, 0, 0, 0]),
        move: const KakuroMove(row: 0, col: 1, digit: 9),
      );
      expect(sumExceededMove.isValid, isFalse);
      expect(sumExceededMove.errorMessage, contains('sum_exceeded'));

      final incompatibleMove = engine.validateMove(
        currentState: start,
        move: const KakuroMove(row: 0, col: 0, digit: 5),
      );
      expect(incompatibleMove.isValid, isFalse);
      expect(incompatibleMove.errorMessage, contains('incompatible_digits'));
    });

    test('incomplete but still possible board is valid and not solved', () {
      final KakuroBoard partial = _fixtureBoard(
        values: const <int>[1, 0, 0, 0],
      );
      final ValidationSummary summary = validator.validatePuzzle(partial);
      expect(summary.isValid, isTrue, reason: summary.issues.join(','));
      expect(validator.isSolved(partial), isFalse);
    });

    test('solved board requires exact sums and unique digits', () {
      final KakuroBoard solved = _fixtureBoard(values: const <int>[1, 9, 4, 3]);
      final ValidationSummary summary = validator.validatePuzzle(solved);
      expect(summary.isValid, isTrue, reason: summary.issues.join(','));
      expect(validator.isSolved(solved), isTrue);

      final KakuroBoard wrongSum = _fixtureBoard(
        values: const <int>[2, 8, 4, 3],
      );
      expect(validator.isSolved(wrongSum), isFalse);

      final KakuroBoard duplicate = _fixtureBoard(
        values: const <int>[4, 4, 5, 3],
      );
      expect(validator.isSolved(duplicate), isFalse);
    });
  });
}

KakuroBoard _fixtureBoard({
  List<int>? values,
  List<KakuroEntry>? entries,
  List<int>? acrossEntryForCell,
  List<int>? downEntryForCell,
}) {
  final List<KakuroEntry> resolvedEntries =
      entries ??
      const <KakuroEntry>[
        KakuroEntry(
          id: 0,
          direction: KakuroDirection.across,
          cells: <int>[0, 1],
          sum: 10,
        ),
        KakuroEntry(
          id: 1,
          direction: KakuroDirection.across,
          cells: <int>[2, 3],
          sum: 7,
        ),
        KakuroEntry(
          id: 2,
          direction: KakuroDirection.down,
          cells: <int>[0, 2],
          sum: 5,
        ),
        KakuroEntry(
          id: 3,
          direction: KakuroDirection.down,
          cells: <int>[1, 3],
          sum: 12,
        ),
      ];

  return KakuroBoard(
    width: 2,
    height: 2,
    kinds: const <KakuroCellKind>[
      KakuroCellKind.value,
      KakuroCellKind.value,
      KakuroCellKind.value,
      KakuroCellKind.value,
    ],
    values: values ?? const <int>[0, 0, 0, 0],
    acrossClues: const <int?>[null, null, null, null],
    downClues: const <int?>[null, null, null, null],
    entries: resolvedEntries,
    acrossEntryForCell: acrossEntryForCell ?? const <int>[0, 0, 1, 1],
    downEntryForCell: downEntryForCell ?? const <int>[2, 3, 2, 3],
  );
}
