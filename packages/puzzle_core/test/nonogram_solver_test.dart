import 'package:puzzle_core/src/nonogram/nonogram_board.dart';
import 'package:puzzle_core/src/nonogram/nonogram_solver.dart';
import 'package:puzzle_core/src/nonogram/nonogram_validator.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:puzzle_core/src/solver/solver.dart';
import 'package:puzzle_core/src/util/nonogram.dart';
import 'package:test/test.dart';

void main() {
  group('Nonogram solver', () {
    test('reports unique only after exhaustive search', () {
      final NonogramBoard puzzle = NonogramBoard.empty(
        width: 2,
        height: 2,
        rowClues: const <List<int>>[
          <int>[2],
          <int>[],
        ],
        columnClues: const <List<int>>[
          <int>[1],
          <int>[1],
        ],
      );

      final SolverResult<NonogramBoard> result = const NonogramSolver().solve(
        puzzle,
        SolverContext(rng: SeededRng(101), maxSolutions: 2),
      );

      expect(result.status, equals(SolverStatus.unique));
      expect(result.solutionStatus, equals(SolverStatus.unique));
      expect(result.solutions.length, equals(1));
    });

    test('reports multiple as soon as two solutions are found', () {
      final NonogramBoard puzzle = _twoSolutionPuzzle();

      final SolverResult<NonogramBoard> result = const NonogramSolver().solve(
        puzzle,
        SolverContext(rng: SeededRng(102), maxSolutions: 2),
      );

      expect(result.status, equals(SolverStatus.multiple));
      expect(result.solutionStatus, equals(SolverStatus.multiple));
      expect(result.solutions.length, equals(2));
    });

    test('reports deterministic search cache telemetry', () {
      final SolverResult<NonogramBoard> result = const NonogramSolver().solve(
        _twoSolutionPuzzle(),
        SolverContext(rng: SeededRng(107), maxSolutions: 2),
      );

      expect(result.status, equals(SolverStatus.multiple));
      expect(result.telemetry['visitedNodes'], isA<int>());
      expect(result.telemetry['maxDepthReached'], isA<int>());
      expect(result.telemetry['branchCount'], isA<int>());
      expect(result.telemetry['contradictionCount'], isA<int>());
      expect(result.telemetry['cacheHits'], isA<int>());
      expect(result.telemetry['cacheMisses'], isA<int>());
      expect(result.telemetry['branchCount'], greaterThan(0));
      expect(result.telemetry['cacheMisses'], greaterThan(0));
    });

    test('reports noSolution only for a fully proven contradiction', () {
      final NonogramBoard puzzle = NonogramBoard.empty(
        width: 2,
        height: 2,
        rowClues: const <List<int>>[
          <int>[2],
          <int>[2],
        ],
        columnClues: const <List<int>>[
          <int>[1],
          <int>[1],
        ],
      );

      final SolverResult<NonogramBoard> result = const NonogramSolver().solve(
        puzzle,
        SolverContext(rng: SeededRng(103), maxSolutions: 2),
      );

      expect(result.status, equals(SolverStatus.noSolution));
      expect(result.solutionStatus, equals(SolverStatus.noSolution));
      expect(result.solutions, isEmpty);
    });

    test('reports unknown when maxSolutions cap prevents uniqueness proof', () {
      final NonogramBoard puzzle = _multiSolutionPuzzle();

      final SolverResult<NonogramBoard> result = const NonogramSolver().solve(
        puzzle,
        SolverContext(rng: SeededRng(104), maxSolutions: 1),
      );

      expect(result.solutions.length, equals(1));
      expect(result.status, equals(SolverStatus.unknown));
      expect(result.solutionStatus, equals(SolverStatus.unknown));
      expect(result.isUnique, isFalse);
      expect(result.telemetry['maxSolutionsCapHit'], isTrue);
    });

    test('reports unknown when depth cap prevents proof', () {
      final NonogramBoard puzzle = _multiSolutionPuzzle();

      final SolverResult<NonogramBoard> result = const NonogramSolver(
        maxSearchDepth: 0,
      ).solve(puzzle, SolverContext(rng: SeededRng(105), maxSolutions: 2));

      expect(result.status, equals(SolverStatus.unknown));
      expect(result.solutionStatus, equals(SolverStatus.unknown));
      expect(result.isUnique, isFalse);
      expect(result.telemetry['depthCapHit'], isTrue);
    });

    test('reports unknown when speculative budget prevents proof', () {
      final NonogramBoard puzzle = _multiSolutionPuzzle();

      final SolverResult<NonogramBoard> result = const NonogramSolver().solve(
        puzzle,
        SolverContext(
          rng: SeededRng(106),
          maxSolutions: 2,
          speculativeStepBudget: 0,
        ),
      );

      expect(result.status, equals(SolverStatus.unknown));
      expect(result.solutionStatus, equals(SolverStatus.unknown));
      expect(result.isUnique, isFalse);
      expect(result.telemetry['speculativeStepBudgetHit'], isTrue);
    });

    test('solves a handcrafted symmetric puzzle', () {
      final NonogramBoard puzzle = NonogramBoard.empty(
        width: 5,
        height: 5,
        rowClues: const <List<int>>[
          <int>[1, 1, 1],
          <int>[3],
          <int>[2, 2],
          <int>[3],
          <int>[1, 1, 1],
        ],
        columnClues: const <List<int>>[
          <int>[1, 1, 1],
          <int>[3],
          <int>[2, 2],
          <int>[3],
          <int>[1, 1, 1],
        ],
      );

      final NonogramSolver solver = const NonogramSolver();
      final SolverResult<NonogramBoard> result = solver.solve(
        puzzle,
        SolverContext(rng: SeededRng(12345), maxSolutions: 2),
      );

      expect(result.hasSolution, isTrue);
      expect(result.solutions.length, equals(1));
      expect(result.status, equals(SolverStatus.unique));

      final NonogramBoard solution = result.solutions.first;
      final NonogramValidator validator = const NonogramValidator();
      expect(validator.isSolved(solution), isTrue);
      expect(validator.validateSolution(puzzle, solution).isValid, isTrue);

      final double logicCompletion =
          (result.telemetry['logicCompletion'] as num?)?.toDouble() ?? 0.0;
      expect(logicCompletion, greaterThan(0.2));
    });

    test('does not infer noSolution when assumptions exceed depth limit', () {
      final NonogramBoard puzzle = NonogramBoard(
        width: 4,
        height: 4,
        rowClues: const <List<int>>[
          <int>[2],
          <int>[1],
          <int>[1],
          <int>[2],
        ],
        columnClues: const <List<int>>[
          <int>[1, 1],
          <int>[1],
          <int>[1],
          <int>[1, 1],
        ],
        cells: List<int?>.filled(16, null),
      );

      final NonogramSolver solver = const NonogramSolver(maxSearchDepth: 1);
      final SolverResult<NonogramBoard> result = solver.solve(
        puzzle,
        SolverContext(rng: SeededRng(9876), maxSolutions: 2),
      );

      expect(result.solutionStatus, isNot(SolverStatus.noSolution));
    });

    test(
      'fixed fixtures report unique multiple noSolution and capped unknown',
      () {
        final Map<NonogramBoard, SolverStatus> fixtures =
            <NonogramBoard, SolverStatus>{
              _uniquePuzzle(): SolverStatus.unique,
              _multiSolutionPuzzle(): SolverStatus.multiple,
              _noSolutionPuzzle(): SolverStatus.noSolution,
            };

        for (final MapEntry<NonogramBoard, SolverStatus> fixture
            in fixtures.entries) {
          final SolverResult<NonogramBoard> result =
              const NonogramSolver(maxSearchDepth: 9).solve(
                fixture.key,
                SolverContext(rng: SeededRng(200), maxSolutions: 2),
              );

          expect(result.status, equals(fixture.value));
          expect(result.solutionStatus, equals(fixture.value));
        }

        final SolverResult<NonogramBoard> capped =
            const NonogramSolver(maxSearchDepth: 9).solve(
              _multiSolutionPuzzle(),
              SolverContext(rng: SeededRng(201), maxSolutions: 1),
            );

        expect(capped.solutions.length, equals(1));
        expect(capped.status, equals(SolverStatus.unknown));
        expect(capped.solutionStatus, equals(SolverStatus.unknown));
        expect(capped.telemetry['maxSolutionsCapHit'], isTrue);
      },
    );

    test('matches brute-force oracle for all 2x2 clue combinations', () {
      _expectSolverMatchesOracleForAllClues(width: 2, height: 2);
    });

    test(
      'matches brute-force oracle for every realizable 3x3 clue signature',
      () {
        final Set<_ClueSignature> signatures = <_ClueSignature>{};
        for (int mask = 0; mask < (1 << 9); mask++) {
          signatures.add(_signatureForMask(width: 3, height: 3, mask: mask));
        }

        for (final _ClueSignature signature in signatures) {
          _expectSolverMatchesOracle(
            NonogramBoard.empty(
              width: 3,
              height: 3,
              rowClues: signature.rows,
              columnClues: signature.columns,
            ),
          );
        }
      },
    );
  });
}

NonogramBoard _twoSolutionPuzzle() {
  return _multiSolutionPuzzle();
}

NonogramBoard _uniquePuzzle() {
  return NonogramBoard.empty(
    width: 2,
    height: 2,
    rowClues: const <List<int>>[
      <int>[2],
      <int>[],
    ],
    columnClues: const <List<int>>[
      <int>[1],
      <int>[1],
    ],
  );
}

NonogramBoard _multiSolutionPuzzle() {
  return NonogramBoard.empty(
    width: 2,
    height: 2,
    rowClues: const <List<int>>[
      <int>[1],
      <int>[1],
    ],
    columnClues: const <List<int>>[
      <int>[1],
      <int>[1],
    ],
  );
}

NonogramBoard _noSolutionPuzzle() {
  return NonogramBoard.empty(
    width: 2,
    height: 2,
    rowClues: const <List<int>>[
      <int>[2],
      <int>[2],
    ],
    columnClues: const <List<int>>[
      <int>[1],
      <int>[1],
    ],
  );
}

void _expectSolverMatchesOracleForAllClues({
  required int width,
  required int height,
}) {
  final List<List<int>> rowClueOptions = _allLineClues(width);
  final List<List<int>> columnClueOptions = _allLineClues(height);

  void visitRows(List<List<int>> rows) {
    void visitColumns(List<List<int>> columns) {
      _expectSolverMatchesOracle(
        NonogramBoard.empty(
          width: width,
          height: height,
          rowClues: rows,
          columnClues: columns,
        ),
      );
    }

    _visitClueLists(columnClueOptions, width, visitColumns);
  }

  _visitClueLists(rowClueOptions, height, visitRows);
}

void _expectSolverMatchesOracle(NonogramBoard puzzle) {
  final int bruteForceCount = _bruteForceSolutionCount(puzzle, cap: 2);
  final SolverResult<NonogramBoard> result = const NonogramSolver(
    maxSearchDepth: 9,
  ).solve(puzzle, SolverContext(rng: SeededRng(301), maxSolutions: 2));

  if (bruteForceCount == 0) {
    expect(result.status, equals(SolverStatus.noSolution));
    expect(result.solutions, isEmpty);
  } else if (bruteForceCount == 1) {
    expect(
      result.status,
      equals(SolverStatus.unique),
      reason: 'False uniqueness or incomplete proof for $puzzle',
    );
    expect(result.solutions.length, equals(1));
  } else {
    expect(
      result.status,
      equals(SolverStatus.multiple),
      reason: 'False uniqueness for $puzzle',
    );
    expect(result.solutions.length, equals(2));
  }
}

int _bruteForceSolutionCount(NonogramBoard puzzle, {required int cap}) {
  int count = 0;
  for (int mask = 0; mask < (1 << puzzle.cellCount); mask++) {
    final _ClueSignature signature = _signatureForMask(
      width: puzzle.width,
      height: puzzle.height,
      mask: mask,
    );
    if (_sameClues(signature.rows, puzzle.rowClues) &&
        _sameClues(signature.columns, puzzle.columnClues)) {
      count++;
      if (count >= cap) {
        return count;
      }
    }
  }
  return count;
}

_ClueSignature _signatureForMask({
  required int width,
  required int height,
  required int mask,
}) {
  final List<List<int>> rows = <List<int>>[];
  final List<List<int>> columns = <List<int>>[];

  for (int row = 0; row < height; row++) {
    rows.add(
      _lineClues(
        List<int>.generate(
          width,
          (int col) => (mask >> (row * width + col)) & 1,
        ),
      ),
    );
  }
  for (int col = 0; col < width; col++) {
    columns.add(
      _lineClues(
        List<int>.generate(
          height,
          (int row) => (mask >> (row * width + col)) & 1,
        ),
      ),
    );
  }

  return _ClueSignature(rows, columns);
}

List<int> _lineClues(List<int> line) {
  final List<int> clues = <int>[];
  int run = 0;
  for (final int value in line) {
    if (value == NonogramLineSolver.filled) {
      run++;
    } else if (run > 0) {
      clues.add(run);
      run = 0;
    }
  }
  if (run > 0) {
    clues.add(run);
  }
  return clues;
}

List<List<int>> _allLineClues(int length) {
  final Set<String> seen = <String>{};
  final List<List<int>> clues = <List<int>>[];
  for (int mask = 0; mask < (1 << length); mask++) {
    final List<int> clue = _lineClues(
      List<int>.generate(length, (int index) => (mask >> index) & 1),
    );
    final String key = clue.join(',');
    if (seen.add(key)) {
      clues.add(clue);
    }
  }
  return clues;
}

void _visitClueLists(
  List<List<int>> options,
  int lineCount,
  void Function(List<List<int>>) visitor,
) {
  void dfs(int index, List<List<int>> buffer) {
    if (index == lineCount) {
      visitor(<List<int>>[
        for (final List<int> clue in buffer) <int>[...clue],
      ]);
      return;
    }
    for (final List<int> option in options) {
      buffer.add(option);
      dfs(index + 1, buffer);
      buffer.removeLast();
    }
  }

  dfs(0, <List<int>>[]);
}

bool _sameClues(List<List<int>> a, List<List<int>> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i].length != b[i].length) {
      return false;
    }
    for (int j = 0; j < a[i].length; j++) {
      if (a[i][j] != b[i][j]) {
        return false;
      }
    }
  }
  return true;
}

class _ClueSignature {
  _ClueSignature(List<List<int>> rows, List<List<int>> columns)
    : rows = List<List<int>>.unmodifiable(
        rows.map((List<int> row) => List<int>.unmodifiable(row)),
      ),
      columns = List<List<int>>.unmodifiable(
        columns.map((List<int> column) => List<int>.unmodifiable(column)),
      );

  final List<List<int>> rows;
  final List<List<int>> columns;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ClueSignature &&
          _sameClues(rows, other.rows) &&
          _sameClues(columns, other.columns);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(rows.map(Object.hashAll)),
    Object.hashAll(columns.map(Object.hashAll)),
  );
}
