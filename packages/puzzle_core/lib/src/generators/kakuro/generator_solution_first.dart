part of puzzle_core_kakuro_generator;

class KakuroConstructionMetrics {
  const KakuroConstructionMetrics({
    required this.averageRunCombinationCountMilli,
    required this.singleCombinationRunRatioMilli,
    required this.maxRunAmbiguityMilli,
    required this.intersectionCandidateReductionMilli,
    required this.runLengthWeightedAmbiguityMilli,
    required this.intersectionSizeHistogram,
    required this.forcedIntersectionCellCount,
    required this.nearForcedIntersectionCellCount,
    required this.weakIntersectionCellCount,
    required this.averageIntersectionSizeMilli,
    required this.maxIntersectionSize,
    required this.weakestRegionScore,
    required this.weakRegionCount,
    required this.runCombinationCountHistogram,
    required this.singleCombinationRunCount,
    required this.lowCombinationRunCount,
    required this.lowCombinationRunRatioMilli,
    required this.runCount,
    required this.valueCellCount,
  });

  final int averageRunCombinationCountMilli;
  final int singleCombinationRunRatioMilli;
  final int maxRunAmbiguityMilli;
  final int intersectionCandidateReductionMilli;
  final int runLengthWeightedAmbiguityMilli;
  final Map<String, int> intersectionSizeHistogram;
  final int forcedIntersectionCellCount;
  final int nearForcedIntersectionCellCount;
  final int weakIntersectionCellCount;
  final int averageIntersectionSizeMilli;
  final int maxIntersectionSize;
  final int weakestRegionScore;
  final int weakRegionCount;
  final Map<String, int> runCombinationCountHistogram;
  final int singleCombinationRunCount;
  final int lowCombinationRunCount;
  final int lowCombinationRunRatioMilli;
  final int runCount;
  final int valueCellCount;

  static KakuroConstructionMetrics zero({
    required int runCount,
    required int valueCellCount,
  }) {
    return KakuroConstructionMetrics(
      averageRunCombinationCountMilli: 0,
      singleCombinationRunRatioMilli: 0,
      maxRunAmbiguityMilli: 0,
      intersectionCandidateReductionMilli: 0,
      runLengthWeightedAmbiguityMilli: 0,
      intersectionSizeHistogram: _emptyIntersectionHistogram(),
      forcedIntersectionCellCount: 0,
      nearForcedIntersectionCellCount: 0,
      weakIntersectionCellCount: 0,
      averageIntersectionSizeMilli: 0,
      maxIntersectionSize: 0,
      weakestRegionScore: 0,
      weakRegionCount: 0,
      runCombinationCountHistogram: const <String, int>{},
      singleCombinationRunCount: 0,
      lowCombinationRunCount: 0,
      lowCombinationRunRatioMilli: 0,
      runCount: runCount,
      valueCellCount: valueCellCount,
    );
  }

  Map<String, Object?> toTelemetry() {
    return <String, Object?>{
      // Compatibility aliases for the construction-fill ambiguity surface.
      // Values are integer milli-units to keep generation telemetry
      // deterministic-safe.
      'avgRunComboCount': averageRunCombinationCountMilli,
      'avgRunComboCountMilli': averageRunCombinationCountMilli,
      'singleComboRunRatio': singleCombinationRunRatioMilli,
      'singleComboRunRatioMilli': singleCombinationRunRatioMilli,
      'averageRunCombinationCountMilli': averageRunCombinationCountMilli,
      'singleCombinationRunRatioMilli': singleCombinationRunRatioMilli,
      'maxRunAmbiguityMilli': maxRunAmbiguityMilli,
      'intersectionCandidateReductionMilli':
          intersectionCandidateReductionMilli,
      'runLengthWeightedAmbiguityMilli': runLengthWeightedAmbiguityMilli,
      'intersectionSizeHistogram': intersectionSizeHistogram,
      'forcedIntersectionCellCount': forcedIntersectionCellCount,
      'nearForcedIntersectionCellCount': nearForcedIntersectionCellCount,
      'weakIntersectionCellCount': weakIntersectionCellCount,
      'averageIntersectionSizeMilli': averageIntersectionSizeMilli,
      'maxIntersectionSize': maxIntersectionSize,
      'weakestRegionScore': weakestRegionScore,
      'weakRegionCount': weakRegionCount,
      'runCombinationCountHistogram': runCombinationCountHistogram,
      'singleCombinationRunCount': singleCombinationRunCount,
      'lowCombinationRunCount': lowCombinationRunCount,
      'lowCombinationRunRatioMilli': lowCombinationRunRatioMilli,
      'runCount': runCount,
      'valueCellCount': valueCellCount,
    };
  }
}

Map<String, int> _emptyIntersectionHistogram() {
  return <String, int>{
    for (int size = 1; size <= 9; size++) size.toString(): 0,
  };
}

class KakuroSolution {
  KakuroSolution({
    required this.values,
    required this.entrySums,
    required this.constructionMetrics,
    required this.constructionScoreMilli,
    required this.constructionFirstScoreMilli,
    required this.constructionSearchNodes,
    required this.constructionScoredFills,
    required this.constructionSoftBudgetHit,
    required this.constructionHardBudgetHit,
    required this.constructionCompletionBudgetHit,
  });

  final List<int> values;
  final Map<int, int> entrySums;
  final KakuroConstructionMetrics constructionMetrics;
  final int constructionScoreMilli;
  final int constructionFirstScoreMilli;
  final int constructionSearchNodes;
  final int constructionScoredFills;
  final bool constructionSoftBudgetHit;
  final bool constructionHardBudgetHit;
  final bool constructionCompletionBudgetHit;

  int get constructionScoreGainMilli =>
      constructionScoreMilli - constructionFirstScoreMilli;

  Map<String, Object?> constructionTelemetry() {
    return <String, Object?>{
      ...constructionMetrics.toTelemetry(),
      'ambiguityScore': constructionScoreMilli,
      'ambiguityScoreMilli': constructionScoreMilli,
      'constructionScoreMilli': constructionScoreMilli,
      'constructionFirstScoreMilli': constructionFirstScoreMilli,
      'constructionScoreGainMilli': constructionScoreGainMilli,
      'constructionSearchNodes': constructionSearchNodes,
      'constructionScoredFills': constructionScoredFills,
      'constructionSoftBudgetHit': constructionSoftBudgetHit,
      'constructionHardBudgetHit': constructionHardBudgetHit,
      'constructionCompletionBudgetHit': constructionCompletionBudgetHit,
    };
  }
}

class _KakuroConstructionSearchConfig {
  const _KakuroConstructionSearchConfig({
    required this.maxSearchNodes,
    required this.maxHardSearchNodes,
    required this.maxCompletedFills,
    required this.candidateOrderingDepth,
  });

  final int maxSearchNodes;
  final int maxHardSearchNodes;
  final int maxCompletedFills;
  final int candidateOrderingDepth;

  factory _KakuroConstructionSearchConfig.forDifficulty({
    required String difficulty,
    required int valueCellCount,
    int? maxSearchNodesOverride,
    int? maxCompletedFillsOverride,
  }) {
    int nodeBudget;
    int completedBudget;
    int orderingDepth;
    switch (difficulty) {
      case 'easy':
        nodeBudget = valueCellCount <= 36 ? 520 : 720;
        completedBudget = valueCellCount <= 36 ? 4 : 5;
        orderingDepth = 18;
        break;
      case 'medium':
        nodeBudget = valueCellCount <= 36 ? 880 : 1180;
        completedBudget = valueCellCount <= 36 ? 6 : 8;
        orderingDepth = 24;
        break;
      case 'hard':
        nodeBudget = valueCellCount <= 36 ? 1100 : 1450;
        completedBudget = valueCellCount <= 36 ? 8 : 10;
        orderingDepth = 20;
        break;
      case 'expert':
        nodeBudget = valueCellCount <= 36 ? 1300 : 1700;
        completedBudget = valueCellCount <= 36 ? 9 : 12;
        orderingDepth = 22;
        break;
      default:
        nodeBudget = valueCellCount <= 36 ? 900 : 1200;
        completedBudget = valueCellCount <= 36 ? 6 : 8;
        orderingDepth = 24;
        break;
    }

    final int maxSearchNodes = maxSearchNodesOverride ?? nodeBudget;
    final int maxCompletedFills = maxCompletedFillsOverride ?? completedBudget;
    return _KakuroConstructionSearchConfig(
      maxSearchNodes: maxSearchNodes,
      maxHardSearchNodes: math.max(maxSearchNodes * 3, maxSearchNodes + 240),
      maxCompletedFills: math.max(1, maxCompletedFills),
      candidateOrderingDepth: orderingDepth,
    );
  }
}

class _KakuroSumComboInfo {
  _KakuroSumComboInfo({
    required this.sum,
    required this.combos,
    required this.unionMask,
  }) : comboCount = combos.length;

  final int sum;
  final List<int> combos;
  final int comboCount;
  final int unionMask;
}

class _KakuroEntryComboInfo {
  const _KakuroEntryComboInfo({required this.entry, required this.sums});

  final KakuroLayoutEntry entry;
  final List<_KakuroSumComboInfo> sums;
}

class _KakuroConstructionScorer {
  _KakuroConstructionScorer(this.template)
    : _entryInfos = _buildEntryInfos(template.entries);

  final KakuroLayout template;
  final List<_KakuroEntryComboInfo> _entryInfos;

  static List<_KakuroEntryComboInfo> _buildEntryInfos(
    List<KakuroLayoutEntry> entries,
  ) {
    final KakuroComboTable table = KakuroComboTable.instance;
    final List<_KakuroEntryComboInfo?> byId =
        List<_KakuroEntryComboInfo?>.filled(entries.length, null);
    for (final KakuroLayoutEntry entry in entries) {
      final Map<int, List<int>>? bySum = table.viewForLength(entry.length);
      final List<_KakuroSumComboInfo> sums = <_KakuroSumComboInfo>[];
      if (bySum != null) {
        final List<int> sortedSums = bySum.keys.toList()..sort();
        for (final int sum in sortedSums) {
          final List<int> combos = bySum[sum]!;
          int unionMask = 0;
          for (final int combo in combos) {
            unionMask |= combo;
          }
          sums.add(
            _KakuroSumComboInfo(sum: sum, combos: combos, unionMask: unionMask),
          );
        }
      }
      byId[entry.id] = _KakuroEntryComboInfo(entry: entry, sums: sums);
    }
    return byId
        .map((_KakuroEntryComboInfo? info) => info!)
        .toList(growable: false);
  }

  KakuroConstructionMetrics score(
    List<int> entryMasks, {
    Map<int, int>? entrySums,
  }) {
    if (entrySums != null && entrySums.length == template.entries.length) {
      return _scoreComplete(entrySums);
    }
    return _scorePartial(entryMasks);
  }

  KakuroConstructionMetrics _scorePartial(List<int> entryMasks) {
    if (_entryInfos.isEmpty) {
      return KakuroConstructionMetrics.zero(
        runCount: 0,
        valueCellCount: template.valueCellCount,
      );
    }

    final int runCount = _entryInfos.length;
    final List<int> runDigitMasks = List<int>.filled(runCount, 0);
    int averageSumMilli = 0;
    int singleSumMilli = 0;
    int maxAmbiguityMilli = 0;
    int weightedAmbiguityNumerator = 0;
    int weightedLengthTotal = 0;

    for (final _KakuroEntryComboInfo info in _entryInfos) {
      final int assignedMask = entryMasks[info.entry.id];
      int supportTotal = 0;
      int weightedComboTotal = 0;
      int singleSupport = 0;
      int runMask = 0;

      for (final _KakuroSumComboInfo sumInfo in info.sums) {
        int support = 0;
        for (final int combo in sumInfo.combos) {
          if ((combo & assignedMask) == assignedMask) {
            support++;
          }
        }
        if (support <= 0) {
          continue;
        }
        supportTotal += support;
        weightedComboTotal += sumInfo.comboCount * support;
        if (sumInfo.comboCount == 1) {
          singleSupport += support;
        }
        runMask |= sumInfo.unionMask;
      }

      if (supportTotal <= 0) {
        return KakuroConstructionMetrics(
          averageRunCombinationCountMilli: 12000,
          singleCombinationRunRatioMilli: 0,
          maxRunAmbiguityMilli: 12000,
          intersectionCandidateReductionMilli: 0,
          runLengthWeightedAmbiguityMilli: 12000,
          intersectionSizeHistogram: _emptyIntersectionHistogram(),
          forcedIntersectionCellCount: 0,
          nearForcedIntersectionCellCount: 0,
          weakIntersectionCellCount: template.valueCellCount,
          averageIntersectionSizeMilli: 9000,
          maxIntersectionSize: 9,
          weakestRegionScore: 0,
          weakRegionCount: template.entries.length,
          runCombinationCountHistogram: const <String, int>{},
          singleCombinationRunCount: 0,
          lowCombinationRunCount: 0,
          lowCombinationRunRatioMilli: 0,
          runCount: runCount,
          valueCellCount: template.valueCellCount,
        );
      }

      final int runAmbiguityMilli = (weightedComboTotal * 1000) ~/ supportTotal;
      final int singleRatioMilli = (singleSupport * 1000) ~/ supportTotal;
      averageSumMilli += runAmbiguityMilli;
      singleSumMilli += singleRatioMilli;
      if (runAmbiguityMilli > maxAmbiguityMilli) {
        maxAmbiguityMilli = runAmbiguityMilli;
      }
      weightedAmbiguityNumerator += runAmbiguityMilli * info.entry.length;
      weightedLengthTotal += info.entry.length;
      runDigitMasks[info.entry.id] = runMask == 0
          ? KakuroMask.allDigits
          : runMask;
    }

    final int averageRunCombinationCountMilli = averageSumMilli ~/ runCount;
    final int singleCombinationRunRatioMilli = singleSumMilli ~/ runCount;
    final int runLengthWeightedAmbiguityMilli = weightedLengthTotal == 0
        ? 0
        : weightedAmbiguityNumerator ~/ weightedLengthTotal;

    final _KakuroIntersectionStats intersection = _scoreIntersections(
      runDigitMasks,
    );

    return KakuroConstructionMetrics(
      averageRunCombinationCountMilli: averageRunCombinationCountMilli,
      singleCombinationRunRatioMilli: singleCombinationRunRatioMilli,
      maxRunAmbiguityMilli: maxAmbiguityMilli,
      intersectionCandidateReductionMilli:
          intersection.intersectionCandidateReductionMilli,
      runLengthWeightedAmbiguityMilli: runLengthWeightedAmbiguityMilli,
      intersectionSizeHistogram: intersection.histogram,
      forcedIntersectionCellCount: intersection.forcedCellCount,
      nearForcedIntersectionCellCount: intersection.nearForcedCellCount,
      weakIntersectionCellCount: intersection.weakCellCount,
      averageIntersectionSizeMilli: intersection.averageSizeMilli,
      maxIntersectionSize: intersection.maxSize,
      weakestRegionScore: intersection.weakestRegionScore,
      weakRegionCount: intersection.weakRegionCount,
      runCombinationCountHistogram: const <String, int>{},
      singleCombinationRunCount: 0,
      lowCombinationRunCount: 0,
      lowCombinationRunRatioMilli: 0,
      runCount: runCount,
      valueCellCount: template.valueCellCount,
    );
  }

  KakuroConstructionMetrics _scoreComplete(Map<int, int> entrySums) {
    if (_entryInfos.isEmpty) {
      return KakuroConstructionMetrics.zero(
        runCount: 0,
        valueCellCount: template.valueCellCount,
      );
    }

    final int runCount = _entryInfos.length;
    final List<int> runDigitMasks = List<int>.filled(runCount, 0);
    final Map<String, int> comboHistogram = <String, int>{};
    int comboTotal = 0;
    int singleCombinationRunCount = 0;
    int lowCombinationRunCount = 0;
    int maxComboCount = 0;
    int weightedComboNumerator = 0;
    int weightedLengthTotal = 0;

    for (final _KakuroEntryComboInfo info in _entryInfos) {
      final int sum = entrySums[info.entry.id] ?? -1;
      _KakuroSumComboInfo? matchingSum;
      for (final _KakuroSumComboInfo sumInfo in info.sums) {
        if (sumInfo.sum == sum) {
          matchingSum = sumInfo;
          break;
        }
      }
      if (matchingSum == null || matchingSum.comboCount <= 0) {
        return KakuroConstructionMetrics(
          averageRunCombinationCountMilli: 12000,
          singleCombinationRunRatioMilli: 0,
          maxRunAmbiguityMilli: 12000,
          intersectionCandidateReductionMilli: 0,
          runLengthWeightedAmbiguityMilli: 12000,
          intersectionSizeHistogram: _emptyIntersectionHistogram(),
          forcedIntersectionCellCount: 0,
          nearForcedIntersectionCellCount: 0,
          weakIntersectionCellCount: template.valueCellCount,
          averageIntersectionSizeMilli: 9000,
          maxIntersectionSize: 9,
          weakestRegionScore: 0,
          weakRegionCount: template.entries.length,
          runCombinationCountHistogram: const <String, int>{},
          singleCombinationRunCount: 0,
          lowCombinationRunCount: 0,
          lowCombinationRunRatioMilli: 0,
          runCount: runCount,
          valueCellCount: template.valueCellCount,
        );
      }

      final int comboCount = matchingSum.comboCount;
      comboTotal += comboCount;
      if (comboCount > maxComboCount) {
        maxComboCount = comboCount;
      }
      if (comboCount == 1) {
        singleCombinationRunCount++;
      }
      if (comboCount <= 3) {
        lowCombinationRunCount++;
      }
      final String histogramKey = comboCount.toString();
      comboHistogram[histogramKey] = (comboHistogram[histogramKey] ?? 0) + 1;
      weightedComboNumerator += comboCount * 1000 * info.entry.length;
      weightedLengthTotal += info.entry.length;
      runDigitMasks[info.entry.id] = matchingSum.unionMask == 0
          ? KakuroMask.allDigits
          : matchingSum.unionMask;
    }

    final _KakuroIntersectionStats intersection = _scoreIntersections(
      runDigitMasks,
    );
    final int averageRunCombinationCountMilli = (comboTotal * 1000) ~/ runCount;
    final int singleCombinationRunRatioMilli =
        (singleCombinationRunCount * 1000) ~/ runCount;
    final int lowCombinationRunRatioMilli =
        (lowCombinationRunCount * 1000) ~/ runCount;
    final int runLengthWeightedAmbiguityMilli = weightedLengthTotal == 0
        ? 0
        : weightedComboNumerator ~/ weightedLengthTotal;
    final List<int> histogramKeys =
        comboHistogram.keys
            .map((String key) => int.parse(key))
            .toList(growable: false)
          ..sort();
    final Map<String, int> stableComboHistogram = <String, int>{
      for (final int key in histogramKeys)
        key.toString(): comboHistogram[key.toString()]!,
    };

    return KakuroConstructionMetrics(
      averageRunCombinationCountMilli: averageRunCombinationCountMilli,
      singleCombinationRunRatioMilli: singleCombinationRunRatioMilli,
      maxRunAmbiguityMilli: maxComboCount * 1000,
      intersectionCandidateReductionMilli:
          intersection.intersectionCandidateReductionMilli,
      runLengthWeightedAmbiguityMilli: runLengthWeightedAmbiguityMilli,
      intersectionSizeHistogram: intersection.histogram,
      forcedIntersectionCellCount: intersection.forcedCellCount,
      nearForcedIntersectionCellCount: intersection.nearForcedCellCount,
      weakIntersectionCellCount: intersection.weakCellCount,
      averageIntersectionSizeMilli: intersection.averageSizeMilli,
      maxIntersectionSize: intersection.maxSize,
      weakestRegionScore: intersection.weakestRegionScore,
      weakRegionCount: intersection.weakRegionCount,
      runCombinationCountHistogram: stableComboHistogram,
      singleCombinationRunCount: singleCombinationRunCount,
      lowCombinationRunCount: lowCombinationRunCount,
      lowCombinationRunRatioMilli: lowCombinationRunRatioMilli,
      runCount: runCount,
      valueCellCount: template.valueCellCount,
    );
  }

  _KakuroIntersectionStats _scoreIntersections(List<int> runDigitMasks) {
    final Map<String, int> histogram = _emptyIntersectionHistogram();
    final Map<int, List<int>> sizesByRun = <int, List<int>>{};
    int forcedCellCount = 0;
    int nearForcedCellCount = 0;
    int weakCellCount = 0;
    int sizeTotal = 0;
    int maxSize = 0;
    int scoredCellCount = 0;

    for (final int cell in template.valueCells) {
      final int acrossId = template.acrossEntryForCell[cell];
      final int downId = template.downEntryForCell[cell];
      if (acrossId < 0 || downId < 0) {
        continue;
      }
      final int intersectionMask =
          runDigitMasks[acrossId] & runDigitMasks[downId];
      int size = KakuroMask.popcount(intersectionMask);
      size = size.clamp(1, 9);
      histogram[size.toString()] = (histogram[size.toString()] ?? 0) + 1;
      if (size == 1) {
        forcedCellCount++;
      }
      if (size <= 2) {
        nearForcedCellCount++;
      }
      if (size >= 5) {
        weakCellCount++;
      }
      if (size > maxSize) {
        maxSize = size;
      }
      sizeTotal += size;
      scoredCellCount++;
      sizesByRun.putIfAbsent(acrossId, () => <int>[]).add(size);
      sizesByRun.putIfAbsent(downId, () => <int>[]).add(size);
    }

    int weakestRegionScore = 1000;
    int weakRegionCount = 0;
    if (template.entries.isEmpty) {
      weakestRegionScore = 0;
    } else {
      for (final KakuroLayoutEntry entry in template.entries) {
        final List<int> sizes = sizesByRun[entry.id] ?? const <int>[];
        if (sizes.isEmpty) {
          weakestRegionScore = 0;
          weakRegionCount++;
          continue;
        }
        int nearCount = 0;
        int forcedCount = 0;
        int weakCount = 0;
        int runSizeTotal = 0;
        for (final int size in sizes) {
          if (size == 1) {
            forcedCount++;
          }
          if (size <= 2) {
            nearCount++;
          }
          if (size >= 5) {
            weakCount++;
          }
          runSizeTotal += size;
        }
        final int averageSizeMilli = (runSizeTotal * 1000) ~/ sizes.length;
        int regionScore =
            1000 -
            (averageSizeMilli ~/ 10) +
            forcedCount * 90 +
            nearCount * 45 -
            weakCount * 80;
        regionScore = regionScore.clamp(0, 1000);
        if (regionScore < weakestRegionScore) {
          weakestRegionScore = regionScore;
        }
        if (nearCount == 0 || weakCount * 2 >= sizes.length) {
          weakRegionCount++;
        }
      }
    }

    final int averageSizeMilli = scoredCellCount == 0
        ? 0
        : (sizeTotal * 1000) ~/ scoredCellCount;
    final int reductionMilli = scoredCellCount == 0
        ? 0
        : ((9 * scoredCellCount - sizeTotal) * 1000) ~/ (9 * scoredCellCount);

    return _KakuroIntersectionStats(
      histogram: histogram,
      forcedCellCount: forcedCellCount,
      nearForcedCellCount: nearForcedCellCount,
      weakCellCount: weakCellCount,
      averageSizeMilli: averageSizeMilli,
      maxSize: maxSize,
      weakestRegionScore: weakestRegionScore,
      weakRegionCount: weakRegionCount,
      intersectionCandidateReductionMilli: reductionMilli,
    );
  }
}

class _KakuroIntersectionStats {
  const _KakuroIntersectionStats({
    required this.histogram,
    required this.forcedCellCount,
    required this.nearForcedCellCount,
    required this.weakCellCount,
    required this.averageSizeMilli,
    required this.maxSize,
    required this.weakestRegionScore,
    required this.weakRegionCount,
    required this.intersectionCandidateReductionMilli,
  });

  final Map<String, int> histogram;
  final int forcedCellCount;
  final int nearForcedCellCount;
  final int weakCellCount;
  final int averageSizeMilli;
  final int maxSize;
  final int weakestRegionScore;
  final int weakRegionCount;
  final int intersectionCandidateReductionMilli;
}

class _KakuroCellChoice {
  const _KakuroCellChoice({required this.cell, required this.candidateMask})
    : invalid = false;

  const _KakuroCellChoice.invalid()
    : cell = -1,
      candidateMask = 0,
      invalid = true;

  final int cell;
  final int candidateMask;
  final bool invalid;
}

class _KakuroCandidateScore {
  const _KakuroCandidateScore({
    required this.digit,
    required this.scoreMilli,
    required this.tieOrder,
  });

  final int digit;
  final int scoreMilli;
  final int tieOrder;
}

class _KakuroCapturedFill {
  const _KakuroCapturedFill({
    required this.values,
    required this.entrySums,
    required this.metrics,
    required this.scoreMilli,
    required this.ordinal,
  });

  final List<int> values;
  final Map<int, int> entrySums;
  final KakuroConstructionMetrics metrics;
  final int scoreMilli;
  final int ordinal;
}

class _KakuroAmbiguityAwareSearch {
  _KakuroAmbiguityAwareSearch({
    required this.template,
    required this.rng,
    required this.difficulty,
    required this.config,
  }) : values = List<int>.filled(template.width * template.height, 0),
       entryMasks = List<int>.filled(template.entries.length, 0),
       scorer = _KakuroConstructionScorer(template),
       cells = _orderedCells(template);

  final KakuroLayout template;
  final SeededRng rng;
  final String difficulty;
  final _KakuroConstructionSearchConfig config;

  final List<int> values;
  final List<int> entryMasks;
  final _KakuroConstructionScorer scorer;
  final List<int> cells;

  int searchNodes = 0;
  int scoredFills = 0;
  bool softBudgetHit = false;
  bool hardBudgetHit = false;
  bool completionBudgetHit = false;
  int? firstScoreMilli;

  final List<_KakuroCapturedFill> _capturedFills = <_KakuroCapturedFill>[];

  static List<int> _orderedCells(KakuroLayout template) {
    final List<int> ordered = List<int>.from(template.valueCells);
    ordered.sort((int a, int b) {
      int aLoad = 0;
      int bLoad = 0;
      final int aAcross = template.acrossEntryForCell[a];
      final int bAcross = template.acrossEntryForCell[b];
      final int aDown = template.downEntryForCell[a];
      final int bDown = template.downEntryForCell[b];
      if (aAcross >= 0) {
        aLoad += template.entries[aAcross].length;
      }
      if (aDown >= 0) {
        aLoad += template.entries[aDown].length;
      }
      if (bAcross >= 0) {
        bLoad += template.entries[bAcross].length;
      }
      if (bDown >= 0) {
        bLoad += template.entries[bDown].length;
      }
      final int cmp = aLoad.compareTo(bLoad);
      if (cmp != 0) {
        return cmp;
      }
      return a.compareTo(b);
    });
    return ordered;
  }

  KakuroSolution? run() {
    final List<KakuroSolution> candidates = runCandidates();
    if (candidates.isEmpty) {
      return null;
    }
    return candidates.first;
  }

  List<KakuroSolution> runCandidates() {
    _search(0);
    if (_capturedFills.isEmpty) {
      return const <KakuroSolution>[];
    }
    _capturedFills.sort((_KakuroCapturedFill a, _KakuroCapturedFill b) {
      final int byScore = b.scoreMilli.compareTo(a.scoreMilli);
      if (byScore != 0) {
        return byScore;
      }
      return a.ordinal.compareTo(b.ordinal);
    });
    return _capturedFills
        .map(
          (_KakuroCapturedFill fill) => KakuroSolution(
            values: fill.values,
            entrySums: fill.entrySums,
            constructionMetrics: fill.metrics,
            constructionScoreMilli: fill.scoreMilli,
            constructionFirstScoreMilli: firstScoreMilli ?? fill.scoreMilli,
            constructionSearchNodes: searchNodes,
            constructionScoredFills: scoredFills,
            constructionSoftBudgetHit: softBudgetHit,
            constructionHardBudgetHit: hardBudgetHit,
            constructionCompletionBudgetHit: completionBudgetHit,
          ),
        )
        .toList(growable: false);
  }

  void _search(int depth) {
    if (_shouldStop()) {
      return;
    }
    searchNodes++;
    if (_shouldStop()) {
      return;
    }

    final _KakuroCellChoice? choice = _selectCell();
    if (choice == null) {
      _captureCompleteFill();
      return;
    }
    if (choice.invalid) {
      return;
    }

    final List<int> orderedDigits = _orderDigits(choice, depth);
    for (final int digit in orderedDigits) {
      _assign(choice.cell, digit);
      _search(depth + 1);
      _unassign(choice.cell, digit);
      if (_shouldStop()) {
        return;
      }
    }
  }

  bool _shouldStop() {
    if (completionBudgetHit || hardBudgetHit || softBudgetHit) {
      return true;
    }
    if (scoredFills >= config.maxCompletedFills) {
      completionBudgetHit = true;
      return true;
    }
    if (searchNodes >= config.maxHardSearchNodes) {
      hardBudgetHit = true;
      return true;
    }
    if (scoredFills > 0 && searchNodes >= config.maxSearchNodes) {
      softBudgetHit = true;
      return true;
    }
    return false;
  }

  _KakuroCellChoice? _selectCell() {
    int bestCell = -1;
    int bestMask = 0;
    int bestCount = 10;
    int bestSpan = 1 << 30;
    for (final int cell in cells) {
      if (values[cell] != 0) {
        continue;
      }
      final int acrossId = template.acrossEntryForCell[cell];
      final int downId = template.downEntryForCell[cell];
      final int candidateMask =
          KakuroMask.allDigits & ~entryMasks[acrossId] & ~entryMasks[downId];
      final int candidateCount = KakuroMask.popcount(candidateMask);
      if (candidateCount <= 0) {
        return const _KakuroCellChoice.invalid();
      }
      final int span =
          template.entries[acrossId].length + template.entries[downId].length;
      if (candidateCount < bestCount ||
          (candidateCount == bestCount && span < bestSpan) ||
          (candidateCount == bestCount &&
              span == bestSpan &&
              cell < bestCell)) {
        bestCell = cell;
        bestMask = candidateMask;
        bestCount = candidateCount;
        bestSpan = span;
      }
    }
    if (bestCell < 0) {
      return null;
    }
    return _KakuroCellChoice(cell: bestCell, candidateMask: bestMask);
  }

  List<int> _orderDigits(_KakuroCellChoice choice, int depth) {
    final List<int> digits = rng.permute(
      KakuroMask.digits(choice.candidateMask),
    );
    if (digits.length <= 1 || depth > config.candidateOrderingDepth) {
      return digits;
    }
    final List<_KakuroCandidateScore> scored = <_KakuroCandidateScore>[];
    for (int i = 0; i < digits.length; i++) {
      final int digit = digits[i];
      _assign(choice.cell, digit);
      final KakuroConstructionMetrics metrics = scorer.score(entryMasks);
      final int scoreMilli = _constructionProfileScoreMilli(
        metrics,
        difficulty,
      );
      scored.add(
        _KakuroCandidateScore(
          digit: digit,
          scoreMilli: scoreMilli,
          tieOrder: i,
        ),
      );
      _unassign(choice.cell, digit);
    }
    scored.sort((_KakuroCandidateScore a, _KakuroCandidateScore b) {
      final int byScore = b.scoreMilli.compareTo(a.scoreMilli);
      if (byScore != 0) {
        return byScore;
      }
      return a.tieOrder.compareTo(b.tieOrder);
    });
    return scored
        .map((_KakuroCandidateScore item) => item.digit)
        .toList(growable: false);
  }

  void _captureCompleteFill() {
    final Map<int, int> sums = _buildEntrySums(values, template.entries);
    if (sums.isEmpty) {
      return;
    }
    final KakuroConstructionMetrics metrics = scorer.score(
      entryMasks,
      entrySums: sums,
    );
    final int scoreMilli = _constructionProfileScoreMilli(metrics, difficulty);
    scoredFills++;
    firstScoreMilli ??= scoreMilli;
    _capturedFills.add(
      _KakuroCapturedFill(
        values: List<int>.from(values),
        entrySums: Map<int, int>.from(sums),
        metrics: metrics,
        scoreMilli: scoreMilli,
        ordinal: scoredFills,
      ),
    );
  }

  void _assign(int cell, int digit) {
    final int bit = KakuroMask.bit(digit);
    values[cell] = digit;
    final int acrossId = template.acrossEntryForCell[cell];
    final int downId = template.downEntryForCell[cell];
    entryMasks[acrossId] |= bit;
    entryMasks[downId] |= bit;
  }

  void _unassign(int cell, int digit) {
    final int bit = KakuroMask.bit(digit);
    values[cell] = 0;
    final int acrossId = template.acrossEntryForCell[cell];
    final int downId = template.downEntryForCell[cell];
    entryMasks[acrossId] &= ~bit;
    entryMasks[downId] &= ~bit;
  }
}

int _constructionProfileScoreMilli(
  KakuroConstructionMetrics metrics,
  String difficulty,
) {
  final int avg = metrics.averageRunCombinationCountMilli;
  final int single = metrics.singleCombinationRunRatioMilli;
  final int maxAmbiguity = metrics.maxRunAmbiguityMilli;
  final int crossing = metrics.intersectionCandidateReductionMilli;
  final int weighted = metrics.runLengthWeightedAmbiguityMilli;
  final int cellCount = metrics.valueCellCount == 0
      ? 1
      : metrics.valueCellCount;
  final int forcedRatio =
      (metrics.forcedIntersectionCellCount * 1000) ~/ cellCount;
  final int nearRatio =
      (metrics.nearForcedIntersectionCellCount * 1000) ~/ cellCount;
  final int weakRatio = (metrics.weakIntersectionCellCount * 1000) ~/ cellCount;
  final int lowRunRatio = metrics.lowCombinationRunRatioMilli;
  final int avgIntersection = metrics.averageIntersectionSizeMilli;
  final int maxIntersection = metrics.maxIntersectionSize;
  final int weakRegionPenalty = metrics.weakRegionCount * 180;
  switch (difficulty) {
    case 'easy':
      return single * 10 +
          lowRunRatio * 4 +
          forcedRatio * 9 +
          nearRatio * 8 +
          crossing * 5 -
          weakRatio * 9 -
          avgIntersection * 2 -
          maxIntersection * 100 -
          weakRegionPenalty -
          avg * 3 -
          weighted * 2 -
          maxAmbiguity * 2;
    case 'medium':
      final int avgBalance = _constructionBalanceScore(avg, 2200, 1400);
      final int weightedBalance = _constructionBalanceScore(
        weighted,
        2500,
        1600,
      );
      final int singleBalance = _constructionBalanceScore(single, 550, 450);
      final int highAmbiguityPenalty =
          _constructionExcessPenalty(avg, 4600) +
          _constructionExcessPenalty(weighted, 5200) +
          _constructionExcessPenalty(maxAmbiguity, 7600);
      return avgBalance * 5 +
          weightedBalance * 3 +
          singleBalance * 3 +
          lowRunRatio +
          forcedRatio * 6 +
          nearRatio * 6 +
          crossing * 5 -
          weakRatio * 8 -
          avgIntersection -
          maxIntersection * 80 -
          weakRegionPenalty -
          highAmbiguityPenalty -
          (maxAmbiguity ~/ 2);
    case 'hard':
      final int avgBalance = _constructionBalanceScore(avg, 3600, 1400);
      final int weightedBalance = _constructionBalanceScore(
        weighted,
        3900,
        1600,
      );
      final int highAmbiguityPenalty =
          _constructionExcessPenalty(avg, 5600) +
          _constructionExcessPenalty(weighted, 6200) +
          _constructionExcessPenalty(maxAmbiguity, 8500);
      return crossing * 6 +
          single * 2 +
          lowRunRatio * 2 +
          forcedRatio * 3 +
          nearRatio * 5 -
          weakRatio * 7 -
          avgIntersection -
          maxIntersection * 70 -
          weakRegionPenalty -
          avgBalance * 5 +
          weightedBalance * 3 -
          highAmbiguityPenalty -
          (maxAmbiguity ~/ 3);
    case 'expert':
      final int avgBalance = _constructionBalanceScore(avg, 4300, 1800);
      final int weightedBalance = _constructionBalanceScore(
        weighted,
        4700,
        2000,
      );
      final int highAmbiguityPenalty =
          _constructionExcessPenalty(avg, 6500) +
          _constructionExcessPenalty(weighted, 7200) +
          _constructionExcessPenalty(maxAmbiguity, 9500);
      return crossing * 7 +
          single +
          lowRunRatio +
          forcedRatio * 2 +
          nearRatio * 4 -
          weakRatio * 6 -
          avgIntersection -
          maxIntersection * 60 -
          weakRegionPenalty -
          avgBalance * 6 +
          weightedBalance * 4 -
          highAmbiguityPenalty -
          (maxAmbiguity ~/ 4);
    default:
      return single * 4 + crossing * 4 - avg * 2 - weighted - maxAmbiguity;
  }
}

int _constructionBalanceScore(
  int valueMilli,
  int targetMilli,
  int toleranceMilli,
) {
  final int delta = (valueMilli - targetMilli).abs();
  if (delta >= toleranceMilli) {
    return 0;
  }
  return ((toleranceMilli - delta) * 1000) ~/ toleranceMilli;
}

int _constructionExcessPenalty(int valueMilli, int ceilingMilli) {
  if (valueMilli <= ceilingMilli) {
    return 0;
  }
  return valueMilli - ceilingMilli;
}

Map<int, int> _buildEntrySums(
  List<int> values,
  List<KakuroLayoutEntry> entries,
) {
  final Map<int, int> sums = <int, int>{};
  for (final KakuroLayoutEntry entry in entries) {
    int sum = 0;
    final Set<int> seen = <int>{};
    for (final int idx in entry.cells) {
      final int value = values[idx];
      if (value == 0 || !seen.add(value)) {
        return const <int, int>{};
      }
      sum += value;
    }
    sums[entry.id] = sum;
  }
  return sums;
}

List<int> _entryMasksFromValues(KakuroLayout template, List<int> values) {
  final List<int> entryMasks = List<int>.filled(template.entries.length, 0);
  for (final KakuroLayoutEntry entry in template.entries) {
    int mask = 0;
    for (final int cell in entry.cells) {
      final int value = values[cell];
      if (value <= 0) {
        continue;
      }
      mask |= KakuroMask.bit(value);
    }
    entryMasks[entry.id] = mask;
  }
  return entryMasks;
}

KakuroSolution? _buildLegacyFirstSolution(
  KakuroLayout template,
  SeededRng rng,
  String difficulty,
) {
  final int cellCount = template.width * template.height;
  final List<int> values = List<int>.filled(cellCount, 0);
  final List<int> entryMasks = List<int>.filled(template.entries.length, 0);
  final List<int> cells = List<int>.from(template.valueCells);
  cells.sort((int a, int b) {
    int aLoad = 0;
    int bLoad = 0;
    final int aAcross = template.acrossEntryForCell[a];
    final int bAcross = template.acrossEntryForCell[b];
    final int aDown = template.downEntryForCell[a];
    final int bDown = template.downEntryForCell[b];
    if (aAcross >= 0) {
      aLoad += template.entries[aAcross].length;
    }
    if (aDown >= 0) {
      aLoad += template.entries[aDown].length;
    }
    if (bAcross >= 0) {
      bLoad += template.entries[bAcross].length;
    }
    if (bDown >= 0) {
      bLoad += template.entries[bDown].length;
    }
    final int cmp = aLoad.compareTo(bLoad);
    if (cmp != 0) {
      return cmp;
    }
    return a.compareTo(b);
  });

  bool backtrack(int index) {
    if (index >= cells.length) {
      return true;
    }
    final int cell = cells[index];
    final int acrossId = template.acrossEntryForCell[cell];
    final int downId = template.downEntryForCell[cell];
    final int candidateMask =
        KakuroMask.allDigits & ~entryMasks[acrossId] & ~entryMasks[downId];
    final List<int> digits = rng.permute(KakuroMask.digits(candidateMask));
    if (digits.isEmpty) {
      return false;
    }
    for (final int digit in digits) {
      final int bit = KakuroMask.bit(digit);
      values[cell] = digit;
      entryMasks[acrossId] |= bit;
      entryMasks[downId] |= bit;
      if (backtrack(index + 1)) {
        return true;
      }
      values[cell] = 0;
      entryMasks[acrossId] &= ~bit;
      entryMasks[downId] &= ~bit;
    }
    return false;
  }

  if (!backtrack(0)) {
    return null;
  }

  final Map<int, int> entrySums = _buildEntrySums(values, template.entries);
  if (entrySums.isEmpty) {
    return null;
  }
  final _KakuroConstructionScorer scorer = _KakuroConstructionScorer(template);
  final KakuroConstructionMetrics metrics = scorer.score(
    _entryMasksFromValues(template, values),
    entrySums: entrySums,
  );
  final int scoreMilli = _constructionProfileScoreMilli(metrics, difficulty);
  return KakuroSolution(
    values: values,
    entrySums: entrySums,
    constructionMetrics: metrics,
    constructionScoreMilli: scoreMilli,
    constructionFirstScoreMilli: scoreMilli,
    constructionSearchNodes: 0,
    constructionScoredFills: 1,
    constructionSoftBudgetHit: true,
    constructionHardBudgetHit: true,
    constructionCompletionBudgetHit: false,
  );
}

KakuroSolution? buildSolutionFirst(
  KakuroLayout template,
  SeededRng rng, {
  String difficulty = 'medium',
  int? maxSearchNodes,
  int? maxCompletedFills,
}) {
  final List<KakuroSolution> candidates = buildSolutionFirstCandidates(
    template,
    rng,
    difficulty: difficulty,
    maxSearchNodes: maxSearchNodes,
    maxCompletedFills: maxCompletedFills,
  );
  return candidates.isEmpty ? null : candidates.first;
}

List<KakuroSolution> buildSolutionFirstCandidates(
  KakuroLayout template,
  SeededRng rng, {
  String difficulty = 'medium',
  int? maxSearchNodes,
  int? maxCompletedFills,
}) {
  if (difficulty == 'easy' && template.valueCellCount <= 16) {
    // Tiny easy layouts are retained as legacy repair/diagnostic fixtures.
    // Shipping easy layouts still use the ambiguity-aware search below.
    final KakuroSolution? legacy = _buildLegacyFirstSolution(
      template,
      rng,
      difficulty,
    );
    return legacy == null ? const <KakuroSolution>[] : <KakuroSolution>[legacy];
  }

  final _KakuroConstructionSearchConfig config =
      _KakuroConstructionSearchConfig.forDifficulty(
        difficulty: difficulty,
        valueCellCount: template.valueCellCount,
        maxSearchNodesOverride: maxSearchNodes,
        maxCompletedFillsOverride: maxCompletedFills,
      );
  final _KakuroAmbiguityAwareSearch search = _KakuroAmbiguityAwareSearch(
    template: template,
    rng: rng,
    difficulty: difficulty,
    config: config,
  );
  final List<KakuroSolution> candidates = search.runCandidates();
  if (candidates.isNotEmpty) {
    return candidates;
  }
  final KakuroSolution? legacy = _buildLegacyFirstSolution(
    template,
    rng,
    difficulty,
  );
  return legacy == null ? const <KakuroSolution>[] : <KakuroSolution>[legacy];
}
