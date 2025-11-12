import 'dart:math' as math;
import 'dart:typed_data';

import '../util/seeded_rng.dart';
import 'solver_adapter.dart';

class ClueRemovalConfig {
  const ClueRemovalConfig({
    required this.width,
    required this.height,
    required this.timeBudget,
    required this.maxBacktrackDepth,
  });

  final int width;
  final int height;
  final Duration timeBudget;
  final int maxBacktrackDepth;
}

class ClueRemovalStats {
  const ClueRemovalStats({
    required this.solverCalls,
    required this.maxDepthHit,
    required this.elapsed,
    required this.removedClueCount,
    required this.hitTimeBudget,
  });

  final int solverCalls;
  final int maxDepthHit;
  final Duration elapsed;
  final int removedClueCount;
  final bool hitTimeBudget;
}

class ClueRemovalResult {
  const ClueRemovalResult({
    required this.clues,
    required this.stats,
  });

  final List<int?> clues;
  final ClueRemovalStats stats;
}

ClueRemovalResult removeClues({
  required List<int> fullClues,
  required SeededRng rng,
  required ClueRemovalConfig config,
  required SlitherlinkUniqueness uniqueness,
  Uint8List? outSolutionEdges,
}) {
  final Stopwatch stopwatch = Stopwatch()..start();
  final List<int?> working = List<int?>.from(fullClues);
  final List<int> candidates = List<int>.generate(fullClues.length, (int i) => i);
  rng.shuffle(candidates);

  int solverCalls = 0;
  int maxDepthHit = 0;
  int removedClueCount = 0;
  int attemptCounter = 0;
  bool timeBudgetHit = false;

  bool madeProgress;
  do {
    madeProgress = false;
    int idx = 0;
    while (idx < candidates.length) {
      if (stopwatch.elapsed > config.timeBudget) {
        timeBudgetHit = true;
        break;
      }
      final int position = candidates[idx];
      if (working[position] == null) {
        idx++;
        continue;
      }
      final int remaining = candidates.length - idx;
      int low = 1;
      int high = math.min(remaining, _maxBatchSize);
      int best = 0;
      while (low <= high) {
        if (stopwatch.elapsed > config.timeBudget) {
          timeBudgetHit = true;
          break;
        }
        final int mid = (low + high) >> 1;
        attemptCounter++;
        final _BatchResult attempt = _tryRemoveBatch(
          working: working,
          candidates: candidates,
          start: idx,
          count: mid,
          uniqueness: uniqueness,
          config: config,
          solverCalls: solverCalls,
          maxDepthHit: maxDepthHit,
          stopwatch: stopwatch,
          attemptId: attemptCounter,
          outSolutionEdges: outSolutionEdges,
        );
        solverCalls = attempt.solverCalls;
        maxDepthHit = attempt.maxDepthHit;
        if (attempt.abort) {
          timeBudgetHit = true;
          break;
        }
        if (attempt.unique) {
          best = mid;
          madeProgress = true;
          removedClueCount += attempt.removedCount;
          low = mid + 1;
        } else {
          high = mid - 1;
        }
      }
      if (timeBudgetHit) {
        break;
      }
      if (best == 0) {
        idx++;
      } else {
        idx += best;
      }
    }
  } while (madeProgress && !timeBudgetHit);

  stopwatch.stop();
  final ClueRemovalStats stats = ClueRemovalStats(
    solverCalls: solverCalls,
    maxDepthHit: maxDepthHit,
    elapsed: stopwatch.elapsed,
    removedClueCount: removedClueCount,
    hitTimeBudget: timeBudgetHit,
  );
  return ClueRemovalResult(clues: working, stats: stats);
}

class _BatchResult {
  const _BatchResult({
    required this.unique,
    required this.solverCalls,
    required this.maxDepthHit,
    required this.removedCount,
    required this.abort,
  });

  final bool unique;
  final int solverCalls;
  final int maxDepthHit;
  final int removedCount;
  final bool abort;
}

_BatchResult _tryRemoveBatch({
  required List<int?> working,
  required List<int> candidates,
  required int start,
  required int count,
  required SlitherlinkUniqueness uniqueness,
  required ClueRemovalConfig config,
  required int solverCalls,
  required int maxDepthHit,
  required Stopwatch stopwatch,
  required int attemptId,
  Uint8List? outSolutionEdges,
}) {
  final List<int> positions = <int>[];
  final List<int?> previous = <int?>[];
  for (int i = 0; i < count; i++) {
    final int pos = candidates[start + i];
    if (working[pos] == null) {
      continue;
    }
    positions.add(pos);
    previous.add(working[pos]);
    working[pos] = null;
  }
  if (positions.isEmpty) {
    return _BatchResult(
      unique: true,
      solverCalls: solverCalls,
      maxDepthHit: maxDepthHit,
      removedCount: 0,
      abort: false,
    );
  }
  bool abort = false;
  if (stopwatch.elapsed > config.timeBudget) {
    abort = true;
  }
  bool unique = false;
  if (!abort) {
    solverCalls++;
    final SlitherlinkUniquenessResult result = uniqueness.evaluate(
      clues: working,
      width: config.width,
      height: config.height,
      maxSolutions: 2,
      maxBacktrackDepth: config.maxBacktrackDepth,
      salt: 'batch:$attemptId:$start:$count',
      outSolutionEdges: outSolutionEdges,
    );
    maxDepthHit = math.max(maxDepthHit, result.maxDepth);
    unique = !result.hitSpeculativeBudget && result.solutionCount == 1;
    if (stopwatch.elapsed > config.timeBudget) {
      abort = true;
    }
    if (!unique) {
      for (int i = 0; i < positions.length; i++) {
        working[positions[i]] = previous[i];
      }
    }
  }
  if (abort) {
    for (int i = 0; i < positions.length; i++) {
      working[positions[i]] = previous[i];
    }
  }
  return _BatchResult(
    unique: unique && !abort,
    solverCalls: solverCalls,
    maxDepthHit: maxDepthHit,
    removedCount: unique && !abort ? positions.length : 0,
    abort: abort,
  );
}

const int _maxBatchSize = 12;
