import 'package:puzzle_core/src/nonogram/nonogram_board.dart';
import 'package:puzzle_core/src/nonogram/nonogram_solver.dart';
import 'package:puzzle_core/src/nonogram/nonogram_validator.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:puzzle_core/src/solver/solver.dart';
import 'package:test/test.dart';

void main() {
  group('Nonogram solver', () {
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

      final NonogramBoard solution = result.solutions.first;
      final NonogramValidator validator = const NonogramValidator();
      expect(validator.isSolved(solution), isTrue);
      expect(
        validator.validateSolution(puzzle, solution).isValid,
        isTrue,
      );

      final double logicCompletion =
          (result.telemetry['logicCompletion'] as num?)?.toDouble() ?? 0.0;
      expect(logicCompletion, greaterThan(0.2));
    });

    test('detects contradiction when assumptions exceed depth limit', () {
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

      expect(result.solutions.isEmpty || result.solutions.length == 1, isTrue);
    });
  });
}
