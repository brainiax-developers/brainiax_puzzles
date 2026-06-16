import '../difficulty/telemetry.dart';
import 'slitherlink_board.dart';

class SlitherlinkDifficultyScorer extends DifficultyScorer<SlitherlinkBoard> {
  const SlitherlinkDifficultyScorer();

  @override
  DifficultyTelemetry score({
    required SlitherlinkBoard puzzle,
    required SlitherlinkBoard solution,
    required DifficultyContext context,
  }) {
    final Map<String, Object?> telemetry = context.solverTelemetry;
    final Map<String, Object?> generation = context.generatorTelemetry;
    final double totalAssignments = _asDouble(telemetry['totalAssignments']);
    final double localAssignments = _asDouble(telemetry['localAssignments']);
    final double globalAssignments = _asDouble(telemetry['globalAssignments']);
    final double speculativeSteps = _asDouble(telemetry['speculativeSteps']);
    final double maxDepth = _asDouble(telemetry['maxDepth']);
    final Map<String, Object?> clueHistogram =
        (generation['revealedClueHistogram'] as Map?)
            ?.cast<String, Object?>() ??
        (generation['clueHistogram'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};

    final double localRatio = totalAssignments <= 0
        ? 1.0
        : (localAssignments / totalAssignments).clamp(0.0, 1.0);
    final double globalRatio = totalAssignments <= 0
        ? 0.0
        : (globalAssignments / totalAssignments).clamp(0.0, 1.0);

    final double localPenalty = (1.0 - localRatio) * 45.0;
    final double globalPenalty = globalRatio * 30.0;
    final double speculationPenalty = speculativeSteps * 18.0;
    final double depthPenalty = maxDepth * 25.0;

    final double rawScore =
        localPenalty + globalPenalty + speculationPenalty + depthPenalty;

    final Map<String, num> metrics = <String, num>{
      'totalAssignments': totalAssignments,
      'localAssignments': localAssignments,
      'globalAssignments': globalAssignments,
      'speculativeSteps': speculativeSteps,
      'maxDepth': maxDepth,
      'clueDensity': _asDouble(generation['clueDensity']),
      'revealedClues': _asDouble(generation['revealedClues']),
      'hiddenClues': _asDouble(generation['hiddenClues']),
      'clue0': _asDouble(clueHistogram['0']),
      'clue1': _asDouble(clueHistogram['1']),
      'clue2': _asDouble(clueHistogram['2']),
      'clue3': _asDouble(clueHistogram['3']),
      'loopEdgeCount': _asDouble(generation['loopEdgeCount']),
      'localRatio': localRatio,
      'globalRatio': globalRatio,
      'localPenalty': localPenalty,
      'globalPenalty': globalPenalty,
      'speculationPenalty': speculationPenalty,
      'depthPenalty': depthPenalty,
      'rawScore': rawScore,
      'revealedZeroRatio': _asDouble(generation['revealedZeroRatio']),
      'nonZeroRevealedClues': _asDouble(generation['nonZeroRevealedClues']),
      'loopCoverageRatio': _asDouble(generation['loopCoverageRatio']),
      'loopTouchedRows': _asDouble(generation['loopTouchedRows']),
      'loopTouchedCols': _asDouble(generation['loopTouchedCols']),
      'loopBoundingBoxWidth': _asDouble(generation['loopBoundingBoxWidth']),
      'loopBoundingBoxHeight': _asDouble(generation['loopBoundingBoxHeight']),
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
