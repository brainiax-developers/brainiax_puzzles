import '../../models/slitherlink_models.dart';

class SlitherlinkDifficultyProfile {
  final Map<SlitherlinkDifficulty, SlitherlinkDifficultyTuning> _tunings;

  const SlitherlinkDifficultyProfile(this._tunings);

  SlitherlinkDifficultyTuning resolve(SlitherlinkDifficulty difficulty) =>
      _tunings[difficulty] ?? _tunings[SlitherlinkDifficulty.medium]!;
}

class SlitherlinkDifficultyTuning {
  final Duration generationTimeBudget;
  final Duration removalTimeBudget;
  final int solverMaxDepth;
  final double targetClueFraction;
  final double binarySearchFraction;
  final int maxFailedRemovals;
  final int maxRestarts;

  const SlitherlinkDifficultyTuning({
    required this.generationTimeBudget,
    required this.removalTimeBudget,
    required this.solverMaxDepth,
    required this.targetClueFraction,
    required this.binarySearchFraction,
    required this.maxFailedRemovals,
    required this.maxRestarts,
  });
}

SlitherlinkDifficultyProfile defaultSlitherlinkDifficultyProfile() {
  return SlitherlinkDifficultyProfile({
    SlitherlinkDifficulty.easy: const SlitherlinkDifficultyTuning(
      generationTimeBudget: Duration(milliseconds: 500),
      removalTimeBudget: Duration(milliseconds: 320),
      solverMaxDepth: 1200,
      targetClueFraction: 0.65,
      binarySearchFraction: 0.3,
      maxFailedRemovals: 75,
      maxRestarts: 32,
    ),
    SlitherlinkDifficulty.medium: const SlitherlinkDifficultyTuning(
      generationTimeBudget: Duration(milliseconds: 650),
      removalTimeBudget: Duration(milliseconds: 420),
      solverMaxDepth: 2000,
      targetClueFraction: 0.55,
      binarySearchFraction: 0.35,
      maxFailedRemovals: 90,
      maxRestarts: 36,
    ),
    SlitherlinkDifficulty.hard: const SlitherlinkDifficultyTuning(
      generationTimeBudget: Duration(milliseconds: 800),
      removalTimeBudget: Duration(milliseconds: 560),
      solverMaxDepth: 3200,
      targetClueFraction: 0.45,
      binarySearchFraction: 0.4,
      maxFailedRemovals: 120,
      maxRestarts: 40,
    ),
    SlitherlinkDifficulty.expert: const SlitherlinkDifficultyTuning(
      generationTimeBudget: Duration(milliseconds: 1000),
      removalTimeBudget: Duration(milliseconds: 700),
      solverMaxDepth: 4500,
      targetClueFraction: 0.38,
      binarySearchFraction: 0.45,
      maxFailedRemovals: 150,
      maxRestarts: 40,
    ),
  });
}
