import 'package:puzzle_core/puzzle_core.dart';
import 'package:test/test.dart';

void main() {
  group('KillerQueensValidator', () {
    const KillerQueensValidator validator = KillerQueensValidator();

    test('accepts a valid solved fixture', () {
      final KillerQueensBoard puzzle = _board(cages: _rowRegions());
      final KillerQueensBoard solution = _board(
        cages: _rowRegions(),
        cells: _cellsWithQueens(const <int>[1, 7, 8, 14]),
      );

      final ValidationSummary puzzleSummary = validator.validatePuzzle(puzzle);
      final ValidationSummary solutionSummary = validator.validateSolution(
        puzzle,
        solution,
      );

      expect(
        puzzleSummary.isValid,
        isTrue,
        reason: puzzleSummary.issues.join(','),
      );
      expect(
        solutionSummary.isValid,
        isTrue,
        reason: solutionSummary.issues.join(','),
      );
      expect(validator.isSolved(solution), isTrue);
    });

    test('rejects an empty region', () {
      final KillerQueensBoard board = _board(
        cages: const <KillerQueensCage>[
          KillerQueensCage(cells: <int>[]),
          KillerQueensCage(cells: <int>[0, 1, 2, 3]),
          KillerQueensCage(cells: <int>[4, 5, 6, 7]),
          KillerQueensCage(cells: <int>[8, 9, 10, 11, 12, 13, 14, 15]),
        ],
      );

      final ValidationSummary summary = validator.validatePuzzle(board);

      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('region_empty:0'));
    });

    test('rejects a disconnected region', () {
      final KillerQueensBoard board = _board(
        cages: const <KillerQueensCage>[
          KillerQueensCage(cells: <int>[0, 15]),
          KillerQueensCage(cells: <int>[1, 2, 3, 7]),
          KillerQueensCage(cells: <int>[4, 5, 6]),
          KillerQueensCage(cells: <int>[8, 9, 10, 11, 12, 13, 14]),
        ],
      );

      final ValidationSummary summary = validator.validatePuzzle(board);

      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('region_disconnected:0'));
    });

    test('rejects the wrong region count', () {
      final KillerQueensBoard board = _board(
        cages: const <KillerQueensCage>[
          KillerQueensCage(cells: <int>[0, 1, 2, 3, 4, 5, 6, 7]),
          KillerQueensCage(cells: <int>[8, 9, 10, 11]),
          KillerQueensCage(cells: <int>[12, 13, 14, 15]),
        ],
      );

      final ValidationSummary summary = validator.validatePuzzle(board);

      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('region_count_mismatch'));
    });

    test('rejects duplicate cell assignment', () {
      final KillerQueensBoard board = _board(
        cages: const <KillerQueensCage>[
          KillerQueensCage(cells: <int>[0, 1, 2, 3]),
          KillerQueensCage(cells: <int>[0, 4, 5, 6, 7]),
          KillerQueensCage(cells: <int>[8, 9, 10, 11]),
          KillerQueensCage(cells: <int>[12, 13, 14, 15]),
        ],
      );

      final ValidationSummary summary = validator.validatePuzzle(board);

      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('cell_multiple_regions:0'));
    });

    test('rejects missing cell assignment', () {
      final KillerQueensBoard board = _board(
        cages: const <KillerQueensCage>[
          KillerQueensCage(cells: <int>[1, 2, 3]),
          KillerQueensCage(cells: <int>[4, 5, 6, 7]),
          KillerQueensCage(cells: <int>[8, 9, 10, 11]),
          KillerQueensCage(cells: <int>[12, 13, 14, 15]),
        ],
      );

      final ValidationSummary summary = validator.validatePuzzle(board);

      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('cell_missing_region:0'));
    });

    test('partial validation rejects duplicate row queens', () {
      final KillerQueensBoard board = _board(
        cages: _columnRegions(),
        cells: _cellsWithQueens(const <int>[0, 3]),
      );

      final ValidationSummary summary = validator.validatePuzzle(board);

      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('row_multiple_queens:0'));
    });

    test('partial validation rejects duplicate column queens', () {
      final KillerQueensBoard board = _board(
        cages: _rowRegions(),
        cells: _cellsWithQueens(const <int>[0, 12]),
      );

      final ValidationSummary summary = validator.validatePuzzle(board);

      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('column_multiple_queens:0'));
    });

    test('partial validation rejects duplicate region queens', () {
      final KillerQueensBoard board = _board(
        cages: const <KillerQueensCage>[
          KillerQueensCage(cells: <int>[0, 1, 2, 6, 10]),
          KillerQueensCage(cells: <int>[3, 7, 11, 15]),
          KillerQueensCage(cells: <int>[4, 5, 9, 13, 14]),
          KillerQueensCage(cells: <int>[8, 12]),
        ],
        cells: _cellsWithQueens(const <int>[0, 10]),
      );

      final ValidationSummary summary = validator.validatePuzzle(board);

      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('region_multiple_queens:0'));
    });

    test('partial validation rejects adjacent queens', () {
      final KillerQueensBoard board = _board(
        cages: _rowRegions(),
        cells: _cellsWithQueens(const <int>[0, 5]),
      );

      final ValidationSummary summary = validator.validatePuzzle(board);

      expect(summary.isValid, isFalse);
      expect(summary.issues, contains('no_touch_violation'));
    });

    test(
      'solved validation requires one queen per row, column, and region',
      () {
        final KillerQueensBoard puzzle = _board(cages: _rowRegions());
        final KillerQueensBoard solution = _board(
          cages: _rowRegions(),
          cells: _cellsWithQueens(const <int>[1, 7, 8]),
        );

        final ValidationSummary summary = validator.validateSolution(
          puzzle,
          solution,
        );

        expect(summary.isValid, isFalse);
        expect(summary.issues, contains('row_queen_count:3'));
        expect(summary.issues, contains('column_queen_count:2'));
        expect(summary.issues, contains('region_queen_count:3'));
        expect(summary.issues, contains('queen_total_mismatch'));
        expect(validator.isSolved(solution), isFalse);
      },
    );

    test('generated boards pass definition validation', () {
      const KillerQueensGenerator generator = KillerQueensGenerator();
      const List<String> seeds = <String>[
        'killer_queens_validator_generated_0',
        'killer_queens_validator_generated_1',
      ];

      for (final String seedStr in seeds) {
        final int seed64 = Seed.fromString(seedStr);
        final PuzzleGenerationResult<KillerQueensBoard> result = generator
            .generate(
              GeneratorContext(
                rng: SeededRng(seed64),
                seedStr: seedStr,
                seed64: seed64,
                size: const SizeOpt(
                  id: '6x6',
                  description: '6x6',
                  width: 6,
                  height: 6,
                ),
                difficulty: const DifficultyRequest(level: 'easy'),
              ),
            );

        final ValidationSummary summary = validator.validatePuzzle(
          result.board,
        );
        expect(
          summary.isValid,
          isTrue,
          reason: 'Seed $seedStr failed: ${summary.issues.join(',')}',
        );
      }
    });
  });
}

KillerQueensBoard _board({
  required List<KillerQueensCage> cages,
  List<int>? cells,
}) {
  return KillerQueensBoard(
    size: 4,
    cells: cells ?? List<int>.filled(16, 0),
    fixed: List<bool>.filled(16, false),
    cages: cages,
  );
}

List<int> _cellsWithQueens(List<int> queenIndices) {
  final List<int> cells = List<int>.filled(16, 0);
  for (final int index in queenIndices) {
    cells[index] = 1;
  }
  return cells;
}

List<KillerQueensCage> _rowRegions() {
  return const <KillerQueensCage>[
    KillerQueensCage(cells: <int>[0, 1, 2, 3]),
    KillerQueensCage(cells: <int>[4, 5, 6, 7]),
    KillerQueensCage(cells: <int>[8, 9, 10, 11]),
    KillerQueensCage(cells: <int>[12, 13, 14, 15]),
  ];
}

List<KillerQueensCage> _columnRegions() {
  return const <KillerQueensCage>[
    KillerQueensCage(cells: <int>[0, 4, 8, 12]),
    KillerQueensCage(cells: <int>[1, 5, 9, 13]),
    KillerQueensCage(cells: <int>[2, 6, 10, 14]),
    KillerQueensCage(cells: <int>[3, 7, 11, 15]),
  ];
}
