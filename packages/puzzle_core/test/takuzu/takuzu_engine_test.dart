import 'package:test/test.dart';

import 'package:puzzle_core/src/api_types.dart';
import 'package:puzzle_core/src/takuzu/takuzu_board.dart';
import 'package:puzzle_core/src/takuzu/takuzu_engine.dart';
import 'package:puzzle_core/src/takuzu/takuzu_move.dart';
import 'package:puzzle_core/src/takuzu/takuzu_solver.dart';
import 'package:puzzle_core/src/takuzu/takuzu_validator.dart';
import 'package:puzzle_core/src/util/seeded_rng.dart';
import 'package:puzzle_core/src/validation/validator.dart';
import 'package:puzzle_core/src/solver/solver.dart';

void main() {
  group('TakuzuEngine', () {
    final TakuzuEngine engine = TakuzuEngine();
    const TakuzuValidator validator = TakuzuValidator();
    const TakuzuSolver solver = TakuzuSolver();

    final SizeOpt size = const SizeOpt(
      id: '4x4',
      description: '4x4 Takuzu',
      width: 4,
      height: 4,
    );

    final DifficultyScore difficulty = DifficultyScore(value: 0.2, level: 'easy');

    test('generates puzzles with valid metadata and state', () {
      final GeneratedPuzzle<TakuzuBoard> generated = engine.generate(
        seedStr: 'engine_seed',
        seed64: 0xabc123,
        size: size,
        difficulty: difficulty,
      );

      expect(generated.meta.engineVersion, equals('1.0.0'));
      expect(generated.meta.size, equals(size));
      expect(generated.state.size, equals(4));

      final ValidationSummary summary = validator.validatePuzzle(generated.state);
      expect(summary.isValid, isTrue, reason: summary.issues.join(','));
    });

    test('validates moves against puzzle state', () {
      final GeneratedPuzzle<TakuzuBoard> generated = engine.generate(
        seedStr: 'move_seed',
        seed64: 424242,
        size: size,
        difficulty: difficulty,
      );

      final TakuzuBoard board = generated.state;

      final SolverResult<TakuzuBoard> result = solver.solve(
        board,
        SolverContext(rng: SeededRng(777777), maxSolutions: 1),
      );
      expect(result.hasSolution, isTrue);
      final TakuzuBoard solution = result.solutions.single;

      int editableIndex = board.cells.indexWhere((int value) => value == TakuzuBoard.emptyValue);
      expect(editableIndex, isNot(-1), reason: 'Expected at least one editable cell');
      final int row = editableIndex ~/ board.size;
      final int col = editableIndex % board.size;
      final int value = solution.cellAt(row, col);

      final MoveResult<TakuzuBoard> moveResult = engine.validateMove(
        currentState: board,
        move: TakuzuMove(row: row, col: col, value: value),
      );

      expect(moveResult.isValid, isTrue, reason: moveResult.errorMessage);
      expect(moveResult.newState?.cellAt(row, col), equals(value));

      final MoveResult<TakuzuBoard> badMove = engine.validateMove(
        currentState: board,
        move: const TakuzuMove(row: -1, col: 0, value: 1),
      );
      expect(badMove.isValid, isFalse);
    });
  });
}
