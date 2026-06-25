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
    final int searchNodes =
        (solver['searchNodes'] as num?)?.toInt() ??
        (solver['backtrackNodes'] as num?)?.toInt() ??
        0;
    final int backtracks = (solver['backtracks'] as num?)?.toInt() ?? 0;
    final int maxDepth = (solver['maxDepth'] as num?)?.toInt() ?? 0;
    final int maxBranchingFactor =
        (solver['maxBranchingFactor'] as num?)?.toInt() ?? 0;
    final int forcedAssignments =
        (solver['forcedAssignments'] as num?)?.toInt() ?? 0;
    final int candidateRemovals =
        (solver['candidateRemovals'] as num?)?.toInt() ?? 0;
    final double avgRunCombinationCount =
        (solver['avgRunCombinationCount'] as num?)?.toDouble() ?? 0.0;
    final double singleComboRunRatio =
        (solver['singleComboRunRatio'] as num?)?.toDouble() ?? 0.0;
    final int maxRunLength = (solver['maxRunLength'] as num?)?.toInt() ?? 0;
    final int runCount =
        (solver['runCount'] as num?)?.toInt() ?? puzzle.entries.length;
    final int whiteCellCount =
        (solver['whiteCellCount'] as num?)?.toInt() ??
        puzzle.kinds
            .where((KakuroCellKind kind) => kind == KakuroCellKind.value)
            .length;
    final double shrinkPercent =
        (solver['candidateShrinkPercent'] as num?)?.toDouble() ?? 0.0;
    final int propagationRounds =
        (solver['propagationRounds'] as num?)?.toInt() ?? 0;

    final int valueCells = whiteCellCount;
    final double forcedRatio = valueCells == 0
        ? 0.0
        : forcedAssignments / valueCells;
    final double removalsPerCell = valueCells == 0
        ? 0.0
        : candidateRemovals / valueCells;

    final double searchPressure =
        searchNodes * 6.0 +
        backtracks * 20.0 +
        maxDepth * 35.0 +
        maxBranchingFactor * 18.0;
    final double ambiguityPressure =
        (avgRunCombinationCount - 1.0).clamp(0.0, 8.0) * 120.0 +
        (1.0 - singleComboRunRatio.clamp(0.0, 1.0)) * 120.0 +
        maxRunLength * 2.0;
    final double structurePressure = valueCells * 0.35 + runCount * 0.9;
    final double logicRelief =
        forcedRatio.clamp(0.0, 1.0) * 60.0 +
        shrinkPercent.clamp(0.0, 1.0) * 45.0 +
        removalsPerCell.clamp(0.0, 6.0) * 6.0;
    final double propagationPenalty = propagationRounds * 1.8;

    final double rawScore =
        (searchPressure +
                ambiguityPressure +
                structurePressure +
                propagationPenalty -
                logicRelief)
            .clamp(0.0, 9999.0);

    final Map<String, num> metrics = <String, num>{
      'searchNodes': searchNodes,
      'backtracks': backtracks,
      'maxDepth': maxDepth,
      'maxBranchingFactor': maxBranchingFactor,
      'shrinkPercent': shrinkPercent,
      'forcedAssignments': forcedAssignments,
      'candidateRemovals': candidateRemovals,
      'avgRunCombinationCount': avgRunCombinationCount,
      'singleComboRunRatio': singleComboRunRatio,
      'maxRunLength': maxRunLength,
      'whiteCellCount': whiteCellCount,
      'runCount': runCount,
      'backtrackNodes': searchNodes,
      'propagationRounds': propagationRounds,
      'valueCells': valueCells,
      'runAmbiguityPressure': ambiguityPressure,
      'branchingPressure': searchPressure,
      'rawScore': rawScore,
    };

    return DifficultyTelemetry(
      rawScore: rawScore,
      bucket: 'pending',
      metrics: metrics,
    );
  }
}
