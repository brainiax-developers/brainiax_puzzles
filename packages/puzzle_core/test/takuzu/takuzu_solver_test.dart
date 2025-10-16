import 'package:test/test.dart';

import 'package:puzzle_core/src/solver/solver.dart';
import 'package:puzzle_core/src/takuzu/takuzu_board.dart';
import 'package:puzzle_core/src/takuzu/takuzu_solver.dart';
import 'package:puzzle_core/src/takuzu/takuzu_validator.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';

void main() {
  group('TakuzuSolver', () {
    const TakuzuSolver solver = TakuzuSolver();
    const TakuzuValidator validator = TakuzuValidator();

    test('solves a logic-driven puzzle without ambiguity', () {
      final List<int> cells = <int>[
        0, TakuzuBoard.emptyValue, 1, TakuzuBoard.emptyValue,
        1, TakuzuBoard.emptyValue, 0, TakuzuBoard.emptyValue,
        1, 0, TakuzuBoard.emptyValue, TakuzuBoard.emptyValue,
        TakuzuBoard.emptyValue, 1, TakuzuBoard.emptyValue, 0,
      ];
      final List<bool> fixed =
          cells.map((int value) => value != TakuzuBoard.emptyValue).toList(growable: false);

      final TakuzuBoard board = TakuzuBoard(size: 4, cells: cells, fixed: fixed);

      final SolverResult<TakuzuBoard> result = solver.solve(
        board,
        SolverContext(rng: SeededRng(123456789), maxSolutions: 2),
      );

      expect(result.hasSolution, isTrue);
      expect(result.isUnique, isTrue);

      final TakuzuBoard solution = result.solutions.single;
      expect(validator.isSolved(solution), isTrue);
      expect(
        solution.cells,
        equals(<int>[
          0, 0, 1, 1,
          1, 1, 0, 0,
          1, 0, 0, 1,
          0, 1, 1, 0,
        ]),
      );

      expect(result.telemetry['forcedAssignments'], isA<num>());
      expect(result.telemetry['longestChain'], isA<num>());
    });
  });
}
