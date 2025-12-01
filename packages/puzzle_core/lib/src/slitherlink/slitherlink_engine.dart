import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../engine/pipeline_engine.dart';
import '../util/determinism.dart';
import 'slitherlink_board.dart';
import 'slitherlink_difficulty.dart';
import 'slitherlink_generator.dart';
import 'slitherlink_move.dart';
import 'slitherlink_solver.dart';
import 'slitherlink_topology.dart';
import 'slitherlink_validator.dart';

DifficultyBucketConfig _loadSlitherlinkDifficultyConfig() {
  return const DifficultyConfigLoader()
      .loadSync('assets/slitherlink_difficulty_thresholds.json');
}

class SlitherlinkEngine
    extends PipelinePuzzleEngine<SlitherlinkBoard, SlitherlinkMove> {
  SlitherlinkEngine({DifficultyBucketConfig? config})
      : super(
          engineId: 'slitherlink_loop',
          engineName: 'Slitherlink',
          engineVersion: '1.0.0',
          generator: const SlitherlinkPipelineGenerator(),
          solver: const SlitherlinkSolver(),
          validator: const SlitherlinkValidator(),
          difficultyScorer: const SlitherlinkDifficultyScorer(),
          difficultyConfig: config ?? _loadSlitherlinkDifficultyConfig(),
        );

  @override
  MoveResult<SlitherlinkBoard> validateMove({
    required SlitherlinkBoard currentState,
    required SlitherlinkMove move,
  }) {
    final SlitherlinkTopology topology = currentState.topology;

    if (move.horizontal) {
      if (move.row < 0 || move.row > currentState.height) {
        return MoveResult.failure('row_out_of_range');
      }
      if (move.col < 0 || move.col >= currentState.width) {
        return MoveResult.failure('col_out_of_range');
      }
    } else {
      if (move.row < 0 || move.row >= currentState.height) {
        return MoveResult.failure('row_out_of_range');
      }
      if (move.col < 0 || move.col > currentState.width) {
        return MoveResult.failure('col_out_of_range');
      }
    }

    if (move.value != SlitherlinkBoard.edgeUnknown &&
        move.value != SlitherlinkBoard.edgeOff &&
        move.value != SlitherlinkBoard.edgeOn) {
      return MoveResult.failure('value_out_of_range');
    }

    final int index = move.horizontal
        ? topology.horizontalEdgeIndex(move.row, move.col)
        : topology.verticalEdgeIndex(move.row, move.col);

    // Allow any edge to be toggled freely during play.
    // We intentionally do NOT run full puzzle validation here because
    // Slitherlink players are allowed to place lines that may later
    // contradict clues or create temporary branches. Final correctness
    // is enforced by validateSolution/isSolved.
    final List<int> newEdges = List<int>.from(currentState.edges);
    newEdges[index] = move.value;
    final SlitherlinkBoard updated = currentState.copyWith(edges: newEdges);

    DeterminismGuard.assertNoFloatsOrDateTimes(updated.toJson());

    return MoveResult.success(updated);
  }
}
