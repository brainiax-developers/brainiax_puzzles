import '../difficulty/telemetry.dart';
import 'kakuro_board.dart';

class KakuroDifficultyScorer extends DifficultyScorer<KakuroBoard> {
  const KakuroDifficultyScorer();

  @override
  DifficultyTelemetry score({
    required KakuroBoard puzzle,
    required KakuroBoard solution,
    required DifficultyContext context,
  }) {
    final Map<String, Object?> solver = context.solverTelemetry;
    final double shrinkPercent =
        (solver['candidateShrinkPercent'] as num?)?.toDouble() ?? 0.0;
    final int forcedAssignments = (solver['forcedAssignments'] as num?)?.toInt() ?? 0;
    final int backtrackNodes = (solver['backtrackNodes'] as num?)?.toInt() ?? 0;
    final int propagationRounds = (solver['propagationRounds'] as num?)?.toInt() ?? 0;

    final int valueCells = puzzle.kinds
        .where((KakuroCellKind kind) => kind == KakuroCellKind.value)
        .length;
    final double forcedRatio = valueCells == 0 ? 0.0 : forcedAssignments / valueCells;

    final double searchPenalty = backtrackNodes * 6.0;
    final double logicPenalty = (1.0 - shrinkPercent.clamp(0.0, 1.0)) * 32.0;
    final double forcedPenalty = (1.0 - forcedRatio.clamp(0.0, 1.0)) * 18.0;
    final double propagationBonus = propagationRounds * 0.4;

    final double rawScore = searchPenalty + logicPenalty + forcedPenalty + propagationBonus;

    final Map<String, num> metrics = <String, num>{
      'shrinkPercent': shrinkPercent,
      'forcedAssignments': forcedAssignments,
      'backtrackNodes': backtrackNodes,
      'propagationRounds': propagationRounds,
      'valueCells': valueCells,
      'rawScore': rawScore,
    };

    return DifficultyTelemetry(
      rawScore: rawScore,
      bucket: 'pending',
      metrics: metrics,
    );
  }
}
