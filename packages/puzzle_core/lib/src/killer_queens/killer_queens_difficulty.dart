import '../difficulty/telemetry.dart';
import 'killer_queens_board.dart';

class KillerQueensDifficultyScorer extends DifficultyScorer<KillerQueensBoard> {
  const KillerQueensDifficultyScorer();

  @override
  DifficultyTelemetry score({
    required KillerQueensBoard puzzle,
    required KillerQueensBoard solution,
    required DifficultyContext context,
  }) {
    final int size = puzzle.size;
    final int blocked = puzzle.blocked.where((bool value) => value).length;
    final int cages = puzzle.cages.length;
    final int givens = puzzle.fixed.where((bool value) => value).length;

    final Map<String, Object?> generator = context.generatorTelemetry;
    final Map<String, Object?> solver = context.solverTelemetry;
    final int attempts = (generator['attempts'] as num?)?.toInt() ?? 1;
    final int branches = (solver['branches'] as num?)?.toInt() ?? 0;

    final double cageDensity = cages == 0 ? 0.0 : (size * size) / cages;
    final double baseScore = size / 2.5 + blocked * 0.35 + cageDensity / 3.5;
    final double givensAdjustment = givens == 0 ? 1.6 : (givens / size).clamp(0.3, 1.2);
    final double branchAdjustment = branches / (size * 2.0);
    final double attemptAdjustment = attempts * 0.12;

    final double rawScore =
        baseScore + givensAdjustment + branchAdjustment + attemptAdjustment;

    final Map<String, num> metrics = <String, num>{
      'size': size,
      'blocked': blocked,
      'cages': cages,
      'givens': givens,
      'attempts': attempts,
      'branches': branches,
      'cageDensity': cageDensity,
      'baseScore': baseScore,
      'rawScore': rawScore,
    };

    return DifficultyTelemetry(
      rawScore: rawScore,
      bucket: 'pending',
      metrics: metrics,
    );
  }
}
