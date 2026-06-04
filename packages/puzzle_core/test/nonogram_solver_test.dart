import 'package:puzzle_core/src/nonogram/nonogram_board.dart';
import 'package:puzzle_core/src/nonogram/nonogram_solver.dart';
import 'package:puzzle_core/src/nonogram/nonogram_validator.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:puzzle_core/src/solver/solver.dart';
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
      final NonogramBoard puzzle = _twoSolutionPuzzle();

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
      final NonogramBoard puzzle = _twoSolutionPuzzle();

      final SolverResult<NonogramBoard> result = const NonogramSolver(
        maxSearchDepth: 0,
      ).solve(puzzle, SolverContext(rng: SeededRng(105), maxSolutions: 2));

      expect(result.status, equals(SolverStatus.unknown));
      expect(result.solutionStatus, equals(SolverStatus.unknown));
      expect(result.isUnique, isFalse);
      expect(result.telemetry['depthCapHit'], isTrue);
    });

    test('reports unknown when speculative budget prevents proof', () {
      final NonogramBoard puzzle = _twoSolutionPuzzle();

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
  });
}

NonogramBoard _twoSolutionPuzzle() {
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
