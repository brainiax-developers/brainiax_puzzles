import '../difficulty/telemetry.dart';
import 'takuzu_board.dart';

class TakuzuDifficultyScorer extends DifficultyScorer<TakuzuBoard> {
  const TakuzuDifficultyScorer();

  @override
  DifficultyTelemetry score({
    required TakuzuBoard puzzle,
    required TakuzuBoard solution,
    required DifficultyContext context,
  }) {
    final int totalCells = puzzle.cellCount;
    final int givens = puzzle.cells.where((int value) => value != TakuzuBoard.emptyValue).length;
    final double givenDensity = totalCells == 0 ? 1.0 : givens / totalCells;

    final Map<String, Object?> telemetry = context.solverTelemetry;
    final double forcedAssignments = _asDouble(telemetry['forcedAssignments']);
    final double totalAssignments = _asDouble(telemetry['totalAssignments']);
    final double longestChain = _asDouble(telemetry['longestChain']);

    final double forcedRatio = totalAssignments <= 0
        ? 1.0
        : (forcedAssignments / totalAssignments).clamp(0.0, 1.0);

    final double densityPenalty = (1.0 - givenDensity) * 30.0;
    final double forcedPenalty = (1.0 - forcedRatio) * 40.0;
    final double chainPenalty = longestChain * 6.0;

    final double rawScore = densityPenalty + forcedPenalty + chainPenalty;

    final Map<String, num> metrics = <String, num>{
      'cells': totalCells,
      'givens': givens,
      'givenDensity': givenDensity,
      'forcedAssignments': forcedAssignments,
      'totalAssignments': totalAssignments,
      'forcedRatio': forcedRatio,
      'longestChain': longestChain,
      'densityPenalty': densityPenalty,
      'forcedPenalty': forcedPenalty,
      'chainPenalty': chainPenalty,
      'rawScore': rawScore,
    };

    return DifficultyTelemetry(
      rawScore: rawScore,
      bucket: 'pending',
      metrics: metrics,
    );
  }

  double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0.0;
  }
}
