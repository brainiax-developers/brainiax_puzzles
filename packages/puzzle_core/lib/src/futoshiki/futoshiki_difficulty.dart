import '../difficulty/telemetry.dart';
import 'futoshiki_board.dart';

class FutoshikiDifficultyScorer extends DifficultyScorer<FutoshikiBoard> {
  const FutoshikiDifficultyScorer();

  @override
  DifficultyTelemetry score({
    required FutoshikiBoard puzzle,
    required FutoshikiBoard solution,
    required DifficultyContext context,
  }) {
    final Map<String, Object?> solver = context.solverTelemetry;

    final int tightenings = (solver['tightenings'] as num?)?.toInt() ?? 0;
    final int firstGuessDepth = (solver['firstGuessDepth'] as num?)?.toInt() ?? 0;
    final int branches = (solver['branches'] as num?)?.toInt() ?? 0;

    final int cellCount = puzzle.cellCount;
    final double tightenScore = cellCount == 0
        ? 0.0
        : (tightenings / (cellCount * 4)).clamp(0.0, 20.0).toDouble();
    final double guessScore = firstGuessDepth == 0
        ? 0.0
        : 1.0 + (firstGuessDepth - 1) / cellCount;
    final double branchScore = branches == 0 ? 0.0 : branches / (cellCount * 0.6);

    final double rawScore = tightenScore + guessScore + branchScore;

    final Map<String, num> metrics = <String, num>{
      'tightenings': tightenings,
      'firstGuessDepth': firstGuessDepth,
      'branches': branches,
      'tightenScore': tightenScore,
      'guessScore': guessScore,
      'branchScore': branchScore,
    };

    return DifficultyTelemetry(
      rawScore: rawScore,
      bucket: 'pending',
      metrics: metrics,
    );
  }
}
