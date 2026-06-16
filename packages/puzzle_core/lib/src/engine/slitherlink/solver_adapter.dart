import 'dart:typed_data';

import '../../slitherlink/slitherlink_board.dart';
import '../../solver/solver.dart';
import '../../util/seeded_rng.dart';
import 'solver.dart';

class SlitherlinkUniquenessResult {
  const SlitherlinkUniquenessResult({
    required this.solutionCount,
    required this.elapsed,
    required this.maxDepth,
    required this.hitSpeculativeBudget,
    this.solution,
  });

  final int solutionCount;
  final Duration elapsed;
  final int maxDepth;
  final bool hitSpeculativeBudget;
  final SlitherlinkBoard? solution;
}

class SlitherlinkUniqueness {
  const SlitherlinkUniqueness(this._solver);

  final SlitherlinkSolver _solver;

  SlitherlinkUniquenessResult evaluate({
    required List<int?> clues,
    required int width,
    required int height,
    required int maxSolutions,
    required int maxBacktrackDepth,
    required String salt,
    Uint8List? outSolutionEdges,
  }) {
    final SlitherlinkBoard board = SlitherlinkBoard.empty(
      width: width,
      height: height,
      clues: clues,
    );
    final String signature =
        'slitherlink_unique:$width:$height:$salt:${clues.map((int? c) => c?.toString() ?? '_').join(',')}';
    final SolverContext context = SolverContext(
      rng: SeededRng(Seed.fromString(signature)),
      maxSolutions: maxSolutions,
      speculativeStepBudget: maxBacktrackDepth,
    );
    final Stopwatch stopwatch = Stopwatch()..start();
    final SolverResult<SlitherlinkBoard> result = _solver.solve(board, context);
    stopwatch.stop();
    SlitherlinkBoard? solution =
        result.solutions.isNotEmpty ? result.solutions.first : null;
    if (result.solutions.length == 1 &&
        solution != null &&
        outSolutionEdges != null &&
        outSolutionEdges.length == solution.edges.length) {
      for (int i = 0; i < solution.edges.length; i++) {
        outSolutionEdges[i] = solution.edges[i];
      }
    }
    final int maxDepth = (result.telemetry['maxDepth'] as int?) ?? 0;
    final bool hitSpeculativeBudget =
        result.telemetry['speculativeStepBudgetHit'] as bool? ?? false;
    return SlitherlinkUniquenessResult(
      solutionCount: result.solutions.length,
      elapsed: stopwatch.elapsed,
      maxDepth: maxDepth,
      hitSpeculativeBudget: hitSpeculativeBudget,
      solution: solution,
    );
  }
}
