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
    final int searchNodes = (solver['searchNodes'] as num?)?.toInt() ??
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
    final int runCount = (solver['runCount'] as num?)?.toInt() ?? puzzle.entries.length;
    final int whiteCellCount = (solver['whiteCellCount'] as num?)?.toInt() ??
        puzzle.kinds
            .where((KakuroCellKind kind) => kind == KakuroCellKind.value)
            .length;
    final double shrinkPercent =
        (solver['candidateShrinkPercent'] as num?)?.toDouble() ?? 0.0;
    final int propagationRounds = (solver['propagationRounds'] as num?)?.toInt() ?? 0;

    final int valueCells = whiteCellCount;
    final double forcedRatio = valueCells == 0 ? 0.0 : forcedAssignments / valueCells;
    final double removalsPerCell =
        valueCells == 0 ? 0.0 : candidateRemovals / valueCells;

    final double searchPressure = searchNodes * 1.2 +
        backtracks * 2.1 +
        maxDepth * 4.5 +
        maxBranchingFactor * 3.5;
    final double ambiguityPressure = avgRunCombinationCount * 6.5 +
        (1.0 - singleComboRunRatio.clamp(0.0, 1.0)) * 14.0 +
        maxRunLength * 2.5;
    final double structurePressure = valueCells * 0.28 + runCount * 0.75;
    final double logicRelief = forcedRatio.clamp(0.0, 1.0) * 24.0 +
        (removalsPerCell / 8.0).clamp(0.0, 1.0) * 10.0 +
        shrinkPercent.clamp(0.0, 1.0) * 12.0;
    final double propagationPenalty = propagationRounds * 0.12;

    final double rawScore = (searchPressure +
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
