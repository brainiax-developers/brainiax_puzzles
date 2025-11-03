import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../engine/pipeline_engine.dart';
import '../util/determinism.dart';
import '../validation/validator.dart';
import 'sudoku_board.dart';
import 'sudoku_difficulty.dart';
import 'sudoku_generator.dart';
import 'sudoku_move.dart';
import 'sudoku_solver.dart';
import 'sudoku_validator.dart';

DifficultyBucketConfig _loadSudokuDifficultyConfig() {
  return const DifficultyConfigLoader().loadSync('assets/difficulty_thresholds.json');
}

class SudokuEngine extends PipelinePuzzleEngine<SudokuBoard, SudokuMove> {
  SudokuEngine({DifficultyBucketConfig? config})
      : super(
          engineId: 'sudoku_classic',
          engineName: 'Classic Sudoku',
          engineVersion: '1.0.0',
          generator: const SudokuGenerator(minClues: 22),
          solver: const SudokuSolver(),
          validator: const SudokuValidator(),
          difficultyScorer: const SudokuDifficultyScorer(),
          difficultyConfig: config ?? _loadSudokuDifficultyConfig(),
        );

  @override
  MoveResult<SudokuBoard> validateMove({
    required SudokuBoard currentState,
    required SudokuMove move,
  }) {
    if (move.row < 0 || move.row >= SudokuBoard.side) {
      return MoveResult.failure('row_out_of_range');
    }
    if (move.col < 0 || move.col >= SudokuBoard.side) {
      return MoveResult.failure('col_out_of_range');
    }
    if (move.digit < 0 || move.digit > 9) {
      return MoveResult.failure('digit_out_of_range');
    }

    final int index = move.row * SudokuBoard.side + move.col;
    if (currentState.fixed[index]) {
      return MoveResult.failure('cell_is_fixed');
    }

    final List<int> newCells = List<int>.from(currentState.cells);
    final List<bool> newFixed = List<bool>.from(currentState.fixed);
    newCells[index] = move.digit;
    final SudokuBoard updated = SudokuBoard(cells: newCells, fixed: newFixed);

    final ValidationSummary summary = validator.validatePuzzle(updated);
    if (!summary.isValid) {
      return MoveResult.failure(summary.issues.join(','));
    }

    DeterminismGuard.assertNoFloatsOrDateTimes(updated.toJson());

    return MoveResult.success(updated);
  }
}
