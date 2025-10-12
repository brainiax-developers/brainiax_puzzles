import '../difficulty/telemetry.dart';
import 'nonogram_board.dart';

class NonogramDifficultyScorer extends DifficultyScorer<NonogramBoard> {
  const NonogramDifficultyScorer();

  @override
  DifficultyTelemetry score({
    required NonogramBoard puzzle,
    required NonogramBoard solution,
    required DifficultyContext context,
  }) {
    final Map<String, Object?> solverTelemetry = context.solverTelemetry;
    final double logicCompletion = _asDouble(solverTelemetry['logicCompletion']);
    final int speculativeSteps = (solverTelemetry['speculativeSteps'] as num?)?.toInt() ?? 0;

    final double averageClueLength = _averageClueLength(puzzle);
    final double averageAlternations = _averageAlternations(puzzle);

    final double logicPenalty = (1.0 - logicCompletion).clamp(0.0, 1.0) * 60.0;
    final double speculationPenalty = speculativeSteps * 25.0;
    final double fragmentationPenalty = averageAlternations * 4.0;
    final double shortCluePenalty = averageClueLength <= 0
        ? 0.0
        : (averageClueLength < 4.0 ? (4.0 - averageClueLength) * 3.0 : 0.0);

    final double rawScore =
        logicPenalty + speculationPenalty + fragmentationPenalty + shortCluePenalty;

    final Map<String, num> metrics = <String, num>{
      'logicCompletion': logicCompletion,
      'speculativeSteps': speculativeSteps,
      'averageClueLength': averageClueLength,
      'averageAlternations': averageAlternations,
      'logicPenalty': logicPenalty,
      'speculationPenalty': speculationPenalty,
      'fragmentationPenalty': fragmentationPenalty,
      'shortCluePenalty': shortCluePenalty,
      'rawScore': rawScore,
    };

    return DifficultyTelemetry(
      rawScore: rawScore,
      bucket: 'pending',
      metrics: metrics,
    );
  }

  double _averageClueLength(NonogramBoard board) {
    int totalLength = 0;
    int totalClues = 0;

    for (final List<int> clues in board.rowClues) {
      for (final int value in clues) {
        totalLength += value;
        totalClues++;
      }
    }
    for (final List<int> clues in board.columnClues) {
      for (final int value in clues) {
        totalLength += value;
        totalClues++;
      }
    }

    if (totalClues == 0) {
      return 0.0;
    }
    return totalLength / totalClues;
  }

  double _averageAlternations(NonogramBoard board) {
    double totalGroups = 0;
    int lines = 0;

    for (final List<int> clues in board.rowClues) {
      totalGroups += clues.isEmpty ? 0 : clues.length.toDouble();
      lines++;
    }
    for (final List<int> clues in board.columnClues) {
      totalGroups += clues.isEmpty ? 0 : clues.length.toDouble();
      lines++;
    }

    if (lines == 0) {
      return 0.0;
    }
    return totalGroups / lines;
  }

  double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0.0;
  }
}
