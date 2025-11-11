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
    final int cages = puzzle.cages.length;
    final int givens = puzzle.fixed.where((bool value) => value).length;

    final Map<String, Object?> generator = context.generatorTelemetry;
    final Map<String, Object?> solver = context.solverTelemetry;
    final int attempts = (generator['attempts'] as num?)?.toInt() ?? 1;
    final int branches = (solver['branches'] as num?)?.toInt() ?? 0;

    // Enhanced difficulty calculation considering grid size and cage complexity
    final double avgCageSize = cages == 0 ? 1.0 : (size * size) / cages;

    // Grid size contributes significantly to difficulty (6x6=1.0, 8x8=1.6, 10x10=2.4, 12x12=3.4)
    final double sizeScore = (size - 4) * 0.8;

    // Cage complexity: larger average cage size increases difficulty
    final double cageComplexity = (avgCageSize - 2.0) * 1.2;

    // Givens ratio: fewer givens = harder (inverted scale)
    final double givensRatio = givens == 0 ? 0.0 : givens / size;
    final double givensAdjustment = (1.0 - givensRatio.clamp(0.0, 1.0)) * 4.0;

    // Solver complexity indicators
    final double branchAdjustment = branches / (size * 1.5);
    final double attemptAdjustment = attempts * 0.1;

    final double rawScore =
        sizeScore +
        cageComplexity +
        givensAdjustment +
        branchAdjustment +
        attemptAdjustment;

    final Map<String, num> metrics = <String, num>{
      'size': size,
      'cages': cages,
      'avgCageSize': avgCageSize,
      'givens': givens,
      'givensRatio': givensRatio,
      'attempts': attempts,
      'branches': branches,
      'sizeScore': sizeScore,
      'cageComplexity': cageComplexity,
      'givensAdjustment': givensAdjustment,
      'rawScore': rawScore,
    };

    return DifficultyTelemetry(
      rawScore: rawScore,
      bucket: 'pending',
      metrics: metrics,
    );
  }
}
