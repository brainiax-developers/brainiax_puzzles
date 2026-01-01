import '../../models/slitherlink_models.dart';

class SlitherlinkDifficultyProfile {
  final Map<SlitherlinkDifficulty, SlitherlinkDifficultyTuning> _tunings;

  const SlitherlinkDifficultyProfile(this._tunings);

  SlitherlinkDifficultyTuning resolve(SlitherlinkDifficulty difficulty) =>
      _tunings[difficulty] ??
      _tunings[SlitherlinkDifficulty.medium]!;
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
      generationTimeBudget: Duration(milliseconds: 250),
      removalTimeBudget: Duration(milliseconds: 160),
      solverMaxDepth: 600,
      targetClueFraction: 0.65,
      binarySearchFraction: 0.3,
      maxFailedRemovals: 18,
      maxRestarts: 16,
    ),
    SlitherlinkDifficulty.medium: const SlitherlinkDifficultyTuning(
      generationTimeBudget: Duration(milliseconds: 320),
      removalTimeBudget: Duration(milliseconds: 210),
      solverMaxDepth: 900,
      targetClueFraction: 0.55,
      binarySearchFraction: 0.35,
      maxFailedRemovals: 24,
      maxRestarts: 24,
    ),
    SlitherlinkDifficulty.hard: const SlitherlinkDifficultyTuning(
      generationTimeBudget: Duration(milliseconds: 400),
      removalTimeBudget: Duration(milliseconds: 260),
      solverMaxDepth: 1500,
      targetClueFraction: 0.45,
      binarySearchFraction: 0.4,
      maxFailedRemovals: 30,
      maxRestarts: 32,
    ),
    SlitherlinkDifficulty.expert: const SlitherlinkDifficultyTuning(
      generationTimeBudget: Duration(milliseconds: 520),
      removalTimeBudget: Duration(milliseconds: 320),
      solverMaxDepth: 2200,
      targetClueFraction: 0.38,
      binarySearchFraction: 0.45,
      maxFailedRemovals: 36,
      maxRestarts: 40,
    ),
  });
}
