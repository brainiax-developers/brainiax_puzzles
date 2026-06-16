import 'dart:math' as math;
import 'dart:typed_data';

import '../../engine/slitherlink/solver_adapter.dart';
import '../../util/seeded_rng.dart';
import 'quality.dart';

class ClueRemovalConfig {
  const ClueRemovalConfig({
    required this.width,
    required this.height,
    required this.timeBudget,
    required this.maxBacktrackDepth,
    required this.binarySearchFraction,
    required this.targetClueFraction,
    required this.maxFailedRemovals,
    this.qualityProfile,
    this.requireQualityGate = false,
    this.useTimeBudget = true,
  });

  final int width;
  final int height;
  final Duration timeBudget;
  final int maxBacktrackDepth;
  final double binarySearchFraction;
  final double targetClueFraction;
  final int maxFailedRemovals;
  final SlitherlinkQualityProfile? qualityProfile;
  final bool requireQualityGate;
  final bool useTimeBudget;
}

class ClueRemovalStats {
  const ClueRemovalStats({
    required this.solverCalls,
    required this.maxDepthHit,
    required this.elapsed,
    required this.removedClueCount,
    required this.hitTimeBudget,
    required this.failedRemovalCount,
    required this.qualityGatePassed,
    this.qualityRejectReason,
  });

  final int solverCalls;
  final int maxDepthHit;
  final Duration elapsed;
  final int removedClueCount;
  final bool hitTimeBudget;
  final int failedRemovalCount;
  final bool qualityGatePassed;
  final String? qualityRejectReason;
}

class ClueRemovalResult {
  const ClueRemovalResult({required this.clues, required this.stats});

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
  final List<int> candidates = _orderedRemovalCandidates(fullClues, rng);

  int solverCalls = 0;
  int maxDepthHit = 0;
  int removedClueCount = 0;
  int attemptCounter = 0;
  bool timeBudgetHit = false;
  final int totalClueSlots = fullClues.length;
  final int targetClueCount = math.max(
    1,
    (totalClueSlots * config.targetClueFraction).round(),
  );
  int revealedClues = totalClueSlots;
  int failedRemovalCount = 0;
  bool densitySatisfied = false;

  bool madeProgress;
  do {
    madeProgress = false;
    int idx = 0;
    while (idx < candidates.length) {
      if (_timeExpired(stopwatch, config)) {
        timeBudgetHit = true;
        break;
      }
      if (failedRemovalCount >= config.maxFailedRemovals || densitySatisfied) {
        break;
      }
      final int position = candidates[idx];
      if (working[position] == null) {
        idx++;
        continue;
      }
      final int remaining = candidates.length - idx;
      final int dynamicCap = math.max(
        1,
        math.min(
          _maxBatchSize,
          math.max(1, (remaining * config.binarySearchFraction).round()),
        ),
      );
      int low = 1;
      int high = math.min(remaining, dynamicCap);
      int best = 0;
      while (low <= high) {
        if (_timeExpired(stopwatch, config)) {
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
          revealedClues -= attempt.removedCount;
          if (revealedClues <= targetClueCount) {
            densitySatisfied = true;
            break;
          }
          low = mid + 1;
        } else {
          failedRemovalCount++;
          high = mid - 1;
          if (failedRemovalCount >= config.maxFailedRemovals) {
            break;
          }
        }
      }
      if (timeBudgetHit ||
          densitySatisfied ||
          failedRemovalCount >= config.maxFailedRemovals) {
        break;
      }
      if (best == 0) {
        idx++;
      } else {
        idx += best;
      }
    }
  } while (madeProgress &&
      !timeBudgetHit &&
      !densitySatisfied &&
      failedRemovalCount < config.maxFailedRemovals);

  String? qualityRejectReason;
  bool qualityGatePassed = true;
  final SlitherlinkQualityProfile? qualityProfile = config.qualityProfile;
  if (qualityProfile != null) {
    _repairFinalQuality(
      working: working,
      fullClues: fullClues,
      qualityProfile: qualityProfile,
    );
    qualityRejectReason = qualityProfile.finalClueSetRejectReason(working);
    qualityGatePassed = qualityRejectReason == null;
    if (!qualityGatePassed && config.requireQualityGate) {
      throw StateError(
        'Slitherlink clue removal failed quality gate: $qualityRejectReason',
      );
    }
  }

  stopwatch.stop();
  final ClueRemovalStats stats = ClueRemovalStats(
    solverCalls: solverCalls,
    maxDepthHit: maxDepthHit,
    elapsed: stopwatch.elapsed,
    removedClueCount: removedClueCount,
    hitTimeBudget: timeBudgetHit,
    failedRemovalCount: failedRemovalCount,
    qualityGatePassed: qualityGatePassed,
    qualityRejectReason: qualityRejectReason,
  );
  return ClueRemovalResult(clues: working, stats: stats);
}

bool _timeExpired(Stopwatch stopwatch, ClueRemovalConfig config) {
  return config.useTimeBudget && stopwatch.elapsed > config.timeBudget;
}

List<int> _orderedRemovalCandidates(List<int> fullClues, SeededRng rng) {
  final Map<int, List<_RemovalCandidate>> buckets =
      <int, List<_RemovalCandidate>>{
        0: <_RemovalCandidate>[],
        1: <_RemovalCandidate>[],
        2: <_RemovalCandidate>[],
        3: <_RemovalCandidate>[],
        4: <_RemovalCandidate>[],
      };
  for (int index = 0; index < fullClues.length; index++) {
    final _RemovalCandidate candidate = _RemovalCandidate(
      index: index,
      priority: _removalPriority(fullClues[index]),
      tieBreak: rng.nextInt64(),
    );
    buckets[candidate.priority]!.add(candidate);
  }
  for (final List<_RemovalCandidate> bucket in buckets.values) {
    bucket.sort((a, b) => a.tieBreak.compareTo(b.tieBreak));
  }
  final List<int> ordered = <int>[];
  while (buckets.values.any(
    (List<_RemovalCandidate> bucket) => bucket.isNotEmpty,
  )) {
    _takeCandidate(buckets[0]!, ordered);
    _takeCandidate(buckets[1]!, ordered);
    _takeCandidate(buckets[0]!, ordered);
    _takeCandidate(buckets[2]!, ordered);
    _takeCandidate(buckets[0]!, ordered);
    _takeCandidate(buckets[3]!, ordered);
    _takeCandidate(buckets[4]!, ordered);
  }
  return ordered;
}

void _takeCandidate(List<_RemovalCandidate> bucket, List<int> ordered) {
  if (bucket.isEmpty) {
    return;
  }
  ordered.add(bucket.removeLast().index);
}

int _removalPriority(int clue) {
  switch (clue) {
    case 0:
      return 0;
    case 1:
      return 1;
    case 2:
      return 2;
    case 3:
      return 3;
    default:
      return 4;
  }
}

void _repairFinalQuality({
  required List<int?> working,
  required List<int> fullClues,
  required SlitherlinkQualityProfile qualityProfile,
}) {
  String? reason = qualityProfile.finalClueSetRejectReason(working);
  if (reason == null) {
    return;
  }
  final List<int> restoreCandidates = <int>[];
  for (int index = 0; index < working.length; index++) {
    if (working[index] == null && fullClues[index] > 0) {
      restoreCandidates.add(index);
    }
  }
  restoreCandidates.sort((a, b) {
    final int clueCompare = fullClues[b].compareTo(fullClues[a]);
    if (clueCompare != 0) {
      return clueCompare;
    }
    return a.compareTo(b);
  });

  for (final int index in restoreCandidates) {
    if (reason == 'clue_density_above_target') {
      return;
    }
    working[index] = fullClues[index];
    reason = qualityProfile.finalClueSetRejectReason(working);
    if (reason == null) {
      return;
    }
  }
}

class _RemovalCandidate {
  const _RemovalCandidate({
    required this.index,
    required this.priority,
    required this.tieBreak,
  });

  final int index;
  final int priority;
  final int tieBreak;
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
  if (_timeExpired(stopwatch, config)) {
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
    if (_timeExpired(stopwatch, config)) {
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
