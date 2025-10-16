import '../difficulty/telemetry.dart';
import 'sudoku_board.dart';

class SudokuDifficultyScorer extends DifficultyScorer<SudokuBoard> {
  const SudokuDifficultyScorer();

  static const Map<String, double> _techniqueWeights = <String, double>{
    'nakedSingle': 0.3,
    'hiddenSingle': 0.6,
    'nakedSubset': 1.5,
    'pointing': 1.2,
    'claiming': 1.2,
    'xWing': 3.5,
    'swordfish': 5.0,
  };

  @override
  DifficultyTelemetry score({
    required SudokuBoard puzzle,
    required SudokuBoard solution,
    required DifficultyContext context,
  }) {
    final Map<String, Object?> solverTelemetry = context.solverTelemetry;
    final Map<String, Object?> generatorTelemetry = context.generatorTelemetry;

    final int humanAssignments = (solverTelemetry['humanAssignments'] as int?) ?? 0;
    final Map<String, int> techniqueCounts = <String, int>{};
    final Map<String, Object?> rawTechniques =
        (solverTelemetry['techniqueCounts'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{};
    for (final MapEntry<String, Object?> entry in rawTechniques.entries) {
      techniqueCounts[entry.key] = (entry.value as num).toInt();
    }

    double advancedWeight = 0;
    for (final MapEntry<String, int> entry in techniqueCounts.entries) {
      final double weight = _techniqueWeights[entry.key] ?? 0.8;
      advancedWeight += weight * entry.value;
    }

    final int searchDepth = (solverTelemetry['searchDepth'] as int?) ?? 0;
    final int searchNodes = (solverTelemetry['searchNodes'] as int?) ?? 0;

    final int clues = (generatorTelemetry['clues'] as int?) ?? puzzle.clueCount;
    final int removals = (generatorTelemetry['removals'] as int?) ??
        (SudokuBoard.cellCount - clues);

    final double clueFactor = (SudokuBoard.cellCount - clues) * 0.35;
    final double logicScore = humanAssignments * 0.8 + advancedWeight;
    final double searchPenalty = searchDepth * 6.0 + searchNodes / 120.0;
    final double removalBonus = removals * 0.25;

    final double rawScore = logicScore + clueFactor + searchPenalty + removalBonus;

    final Map<String, num> metrics = <String, num>{
      'humanAssignments': humanAssignments,
      'advancedWeight': advancedWeight,
      'searchDepth': searchDepth,
      'searchNodes': searchNodes,
      'clues': clues,
      'rawScore': rawScore,
    };

    return DifficultyTelemetry(
      rawScore: rawScore,
      bucket: 'pending',
      metrics: metrics,
    );
  }
}
