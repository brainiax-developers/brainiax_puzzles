class DifficultyScore {
  final int value; // e.g., 1..10
  final String label; // "easy" | "medium" | "hard"...
  const DifficultyScore(this.value, this.label);
}

abstract class DifficultyScorer<TBoard> {
  const DifficultyScorer();
  DifficultyScore score(TBoard board);
}
