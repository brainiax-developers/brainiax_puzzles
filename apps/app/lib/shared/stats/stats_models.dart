import '../models/puzzle_type.dart';

class PuzzleDifficultyStats {
  const PuzzleDifficultyStats({
    required this.difficulty,
    required this.totalCompletions,
    required this.randomCompletions,
    required this.dailyCompletions,
    required this.totalElapsedMs,
    required this.totalMoveCount,
    required this.totalHintsUsed,
    required this.bestElapsedMs,
    required this.firstCompletedAtUtc,
    required this.lastCompletedAtUtc,
  });

  const PuzzleDifficultyStats.empty(String difficulty)
    : this(
        difficulty: difficulty,
        totalCompletions: 0,
        randomCompletions: 0,
        dailyCompletions: 0,
        totalElapsedMs: 0,
        totalMoveCount: 0,
        totalHintsUsed: 0,
        bestElapsedMs: null,
        firstCompletedAtUtc: null,
        lastCompletedAtUtc: null,
      );

  final String difficulty;
  final int totalCompletions;
  final int randomCompletions;
  final int dailyCompletions;
  final int totalElapsedMs;
  final int totalMoveCount;
  final int totalHintsUsed;
  final int? bestElapsedMs;
  final DateTime? firstCompletedAtUtc;
  final DateTime? lastCompletedAtUtc;

  Duration? get bestTime =>
      bestElapsedMs == null ? null : Duration(milliseconds: bestElapsedMs!);

  bool get hasCompletions => totalCompletions > 0;
}

class PuzzleTypeStats {
  const PuzzleTypeStats({
    required this.puzzleType,
    required this.totalCompletions,
    required this.randomCompletions,
    required this.dailyCompletions,
    required this.totalElapsedMs,
    required this.totalMoveCount,
    required this.totalHintsUsed,
    required this.bestElapsedMs,
    required this.firstCompletedAtUtc,
    required this.lastCompletedAtUtc,
    required this.byDifficulty,
  });

  const PuzzleTypeStats.empty(PuzzleType puzzleType)
    : this(
        puzzleType: puzzleType,
        totalCompletions: 0,
        randomCompletions: 0,
        dailyCompletions: 0,
        totalElapsedMs: 0,
        totalMoveCount: 0,
        totalHintsUsed: 0,
        bestElapsedMs: null,
        firstCompletedAtUtc: null,
        lastCompletedAtUtc: null,
        byDifficulty: const <String, PuzzleDifficultyStats>{},
      );

  final PuzzleType puzzleType;
  final int totalCompletions;
  final int randomCompletions;
  final int dailyCompletions;
  final int totalElapsedMs;
  final int totalMoveCount;
  final int totalHintsUsed;
  final int? bestElapsedMs;
  final DateTime? firstCompletedAtUtc;
  final DateTime? lastCompletedAtUtc;
  final Map<String, PuzzleDifficultyStats> byDifficulty;

  Duration? get bestTime =>
      bestElapsedMs == null ? null : Duration(milliseconds: bestElapsedMs!);

  bool get hasCompletions => totalCompletions > 0;

  PuzzleDifficultyStats statsForDifficulty(String difficulty) {
    return byDifficulty[difficulty] ?? PuzzleDifficultyStats.empty(difficulty);
  }
}

class PuzzleStatsAggregate {
  const PuzzleStatsAggregate({
    required this.totalCompletions,
    required this.randomCompletions,
    required this.dailyCompletions,
    required this.totalElapsedMs,
    required this.totalMoveCount,
    required this.totalHintsUsed,
    required this.firstCompletedAtUtc,
    required this.lastCompletedAtUtc,
    required this.byPuzzle,
  });

  static const empty = PuzzleStatsAggregate(
    totalCompletions: 0,
    randomCompletions: 0,
    dailyCompletions: 0,
    totalElapsedMs: 0,
    totalMoveCount: 0,
    totalHintsUsed: 0,
    firstCompletedAtUtc: null,
    lastCompletedAtUtc: null,
    byPuzzle: <PuzzleType, PuzzleTypeStats>{},
  );

  final int totalCompletions;
  final int randomCompletions;
  final int dailyCompletions;
  final int totalElapsedMs;
  final int totalMoveCount;
  final int totalHintsUsed;
  final DateTime? firstCompletedAtUtc;
  final DateTime? lastCompletedAtUtc;
  final Map<PuzzleType, PuzzleTypeStats> byPuzzle;

  bool get hasCompletions => totalCompletions > 0;

  PuzzleTypeStats statsForPuzzle(PuzzleType puzzleType) {
    return byPuzzle[puzzleType] ?? PuzzleTypeStats.empty(puzzleType);
  }
}
