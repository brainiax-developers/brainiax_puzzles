import '../models/puzzle_completion_record.dart';
import '../models/puzzle_type.dart';
import '../services/puzzle_local_store.dart';
import 'puzzle_run_result.dart';
import 'stats_models.dart';

class LocalStatsService {
  const LocalStatsService(this._store);

  final PuzzleLocalStore _store;

  Future<List<PuzzleRunResult>> runResults() async {
    final List<PuzzleCompletionRecord> records = await _store
        .completionRecords();
    return runResultsFromRecords(records);
  }

  Future<PuzzleStatsAggregate> aggregateStats() async {
    final List<PuzzleCompletionRecord> records = await _store
        .completionRecords();
    return aggregateFromRecords(records);
  }

  List<PuzzleRunResult> runResultsFromRecords(
    Iterable<PuzzleCompletionRecord> records,
  ) {
    final List<PuzzleRunResult> results =
        records.map(PuzzleRunResult.fromCompletionRecord).toList()..sort(
          (PuzzleRunResult a, PuzzleRunResult b) =>
              a.completedAtUtc.compareTo(b.completedAtUtc),
        );
    return List<PuzzleRunResult>.unmodifiable(results);
  }

  PuzzleStatsAggregate aggregateFromRecords(
    Iterable<PuzzleCompletionRecord> records,
  ) {
    return aggregateFromRunResults(runResultsFromRecords(records));
  }

  PuzzleStatsAggregate aggregateFromRunResults(
    Iterable<PuzzleRunResult> runResults,
  ) {
    int totalCompletions = 0;
    int randomCompletions = 0;
    int dailyCompletions = 0;
    int totalElapsedMs = 0;
    int totalMoveCount = 0;
    int totalHintsUsed = 0;
    DateTime? firstCompletedAtUtc;
    DateTime? lastCompletedAtUtc;
    final Map<_PuzzleStatsKey, _PuzzleStatsBuilder> builders =
        <_PuzzleStatsKey, _PuzzleStatsBuilder>{};

    for (final PuzzleRunResult result in runResults) {
      totalCompletions += 1;
      totalElapsedMs += result.elapsedMs;
      totalMoveCount += result.moveCount;
      totalHintsUsed += result.hintsUsed;

      if (result.isDaily) {
        dailyCompletions += 1;
      } else {
        randomCompletions += 1;
      }

      firstCompletedAtUtc = _earliest(
        firstCompletedAtUtc,
        result.completedAtUtc,
      );
      lastCompletedAtUtc = _latest(lastCompletedAtUtc, result.completedAtUtc);

      builders
          .putIfAbsent(
            _PuzzleStatsKey.forPuzzle(result.puzzleType),
            () => _PuzzleStatsBuilder.forPuzzle(result.puzzleType),
          )
          .add(result);
      builders
          .putIfAbsent(
            _PuzzleStatsKey.forDifficulty(result.puzzleType, result.difficulty),
            () => _PuzzleStatsBuilder.forDifficulty(
              result.puzzleType,
              result.difficulty,
            ),
          )
          .add(result);
    }

    if (totalCompletions == 0) {
      return PuzzleStatsAggregate.empty;
    }

    final Map<PuzzleType, PuzzleTypeStats> byPuzzle =
        <PuzzleType, PuzzleTypeStats>{};
    final Map<_PuzzleStatsKey, PuzzleDifficultyStats> byDifficulty =
        <_PuzzleStatsKey, PuzzleDifficultyStats>{};

    for (final MapEntry<_PuzzleStatsKey, _PuzzleStatsBuilder> entry
        in builders.entries) {
      if (entry.key.difficulty == null) {
        byPuzzle[entry.key.puzzleType] = entry.value.buildPuzzleTypeStats();
      } else {
        byDifficulty[entry.key] = entry.value.buildDifficultyStats();
      }
    }

    final Map<PuzzleType, PuzzleTypeStats> byPuzzleTyped =
        <PuzzleType, PuzzleTypeStats>{};
    byPuzzle.forEach((PuzzleType puzzleType, PuzzleTypeStats puzzleStats) {
      byPuzzleTyped[puzzleType] = PuzzleTypeStats(
        puzzleType: puzzleStats.puzzleType,
        totalCompletions: puzzleStats.totalCompletions,
        randomCompletions: puzzleStats.randomCompletions,
        dailyCompletions: puzzleStats.dailyCompletions,
        totalElapsedMs: puzzleStats.totalElapsedMs,
        totalMoveCount: puzzleStats.totalMoveCount,
        totalHintsUsed: puzzleStats.totalHintsUsed,
        bestElapsedMs: puzzleStats.bestElapsedMs,
        firstCompletedAtUtc: puzzleStats.firstCompletedAtUtc,
        lastCompletedAtUtc: puzzleStats.lastCompletedAtUtc,
        byDifficulty: Map<String, PuzzleDifficultyStats>.unmodifiable({
          for (final MapEntry<_PuzzleStatsKey, PuzzleDifficultyStats>
              difficultyEntry
              in byDifficulty.entries)
            if (difficultyEntry.key.puzzleType == puzzleStats.puzzleType &&
                difficultyEntry.key.difficulty != null)
              difficultyEntry.key.difficulty!: difficultyEntry.value,
        }),
      );
    });

    return PuzzleStatsAggregate(
      totalCompletions: totalCompletions,
      randomCompletions: randomCompletions,
      dailyCompletions: dailyCompletions,
      totalElapsedMs: totalElapsedMs,
      totalMoveCount: totalMoveCount,
      totalHintsUsed: totalHintsUsed,
      firstCompletedAtUtc: firstCompletedAtUtc,
      lastCompletedAtUtc: lastCompletedAtUtc,
      byPuzzle: Map.unmodifiable(byPuzzleTyped),
    );
  }
}

class _PuzzleStatsBuilder {
  _PuzzleStatsBuilder.forPuzzle(this.puzzleType) : difficulty = null;

  _PuzzleStatsBuilder.forDifficulty(this.puzzleType, this.difficulty);

  final PuzzleType puzzleType;
  final String? difficulty;
  int totalCompletions = 0;
  int randomCompletions = 0;
  int dailyCompletions = 0;
  int totalElapsedMs = 0;
  int totalMoveCount = 0;
  int totalHintsUsed = 0;
  int? bestElapsedMs;
  DateTime? firstCompletedAtUtc;
  DateTime? lastCompletedAtUtc;

  void add(PuzzleRunResult result) {
    totalCompletions += 1;
    totalElapsedMs += result.elapsedMs;
    totalMoveCount += result.moveCount;
    totalHintsUsed += result.hintsUsed;
    bestElapsedMs = bestElapsedMs == null
        ? result.elapsedMs
        : (result.elapsedMs < bestElapsedMs!
              ? result.elapsedMs
              : bestElapsedMs);
    firstCompletedAtUtc = _earliest(firstCompletedAtUtc, result.completedAtUtc);
    lastCompletedAtUtc = _latest(lastCompletedAtUtc, result.completedAtUtc);

    if (result.isDaily) {
      dailyCompletions += 1;
    } else {
      randomCompletions += 1;
    }
  }

  PuzzleTypeStats buildPuzzleTypeStats() {
    return PuzzleTypeStats(
      puzzleType: puzzleType,
      totalCompletions: totalCompletions,
      randomCompletions: randomCompletions,
      dailyCompletions: dailyCompletions,
      totalElapsedMs: totalElapsedMs,
      totalMoveCount: totalMoveCount,
      totalHintsUsed: totalHintsUsed,
      bestElapsedMs: bestElapsedMs,
      firstCompletedAtUtc: firstCompletedAtUtc,
      lastCompletedAtUtc: lastCompletedAtUtc,
      byDifficulty: const <String, PuzzleDifficultyStats>{},
    );
  }

  PuzzleDifficultyStats buildDifficultyStats() {
    return PuzzleDifficultyStats(
      difficulty: difficulty ?? 'unknown',
      totalCompletions: totalCompletions,
      randomCompletions: randomCompletions,
      dailyCompletions: dailyCompletions,
      totalElapsedMs: totalElapsedMs,
      totalMoveCount: totalMoveCount,
      totalHintsUsed: totalHintsUsed,
      bestElapsedMs: bestElapsedMs,
      firstCompletedAtUtc: firstCompletedAtUtc,
      lastCompletedAtUtc: lastCompletedAtUtc,
    );
  }
}

class _PuzzleStatsKey {
  const _PuzzleStatsKey(this.puzzleType, this.difficulty);

  const _PuzzleStatsKey.forPuzzle(this.puzzleType) : difficulty = null;

  const _PuzzleStatsKey.forDifficulty(this.puzzleType, this.difficulty);

  final PuzzleType puzzleType;
  final String? difficulty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PuzzleStatsKey &&
          runtimeType == other.runtimeType &&
          puzzleType == other.puzzleType &&
          difficulty == other.difficulty;

  @override
  int get hashCode => Object.hash(puzzleType, difficulty);
}

DateTime? _earliest(DateTime? current, DateTime candidate) {
  if (current == null || candidate.isBefore(current)) {
    return candidate;
  }
  return current;
}

DateTime? _latest(DateTime? current, DateTime candidate) {
  if (current == null || candidate.isAfter(current)) {
    return candidate;
  }
  return current;
}
