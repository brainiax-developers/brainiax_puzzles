part of puzzle_core_kakuro_generator;

class KakuroBottomUpGenerator {
  const KakuroBottomUpGenerator();

  KakuroSolution? generate(
    KakuroLayout layout,
    SeededRng rng, {
    String difficulty = 'medium',
  }) {
    final KakuroBoard emptyBoard = layout.buildBoard(const <int, int>{});
    final KakuroBottomUpEvaluator eval = KakuroBottomUpEvaluator(emptyBoard);

    final List<KakuroLayoutEntry> sortedEntries = List<KakuroLayoutEntry>.from(layout.entries)
      ..sort((a, b) => a.cells.length.compareTo(b.cells.length));

    bool solved = false;

    int backtrackCount = 0;
    const int maxBacktracks = 3000;

    bool solve(int index) {
      if (index >= sortedEntries.length) {
        // TERMINATION: All sums assigned. Now verify uniqueness!
        final Map<int, int> currentSums = eval.activeEntrySums;
        final KakuroBoard testBoard = layout.buildBoard(currentSums);
        final KakuroSolver verifier = KakuroSolver();
        final SolverResult<KakuroBoard> result = verifier.solve(
          testBoard,
          SolverContext(rng: rng, maxSolutions: 2),
        );
        // Return false if non-unique to trigger backtracking and mutate sums!
        return result.solutionStatus == SolverStatus.unique;
      }
      
      // Safety valve to prevent infinite hangs on structurally broken layouts
      if (backtrackCount > maxBacktracks) return false;

      final KakuroLayoutEntry entry = sortedEntries[index];
      final Map<int, Set<int>>? combosBySum = KakuroDictionary.getCombinationsForLength(entry.cells.length);
      if (combosBySum == null) return false;

      // HEURISTIC: Group sums by restrictiveness (number of valid combinations)
      final Map<int, List<int>> sumsByComboCount = <int, List<int>>{};
      for (final int sum in combosBySum.keys) {
        final int count = combosBySum[sum]!.length;
        sumsByComboCount.putIfAbsent(count, () => <int>[]).add(sum);
      }

      // Try most restrictive sums first (fewest combinations) to heavily prune the search space
      final List<int> counts = sumsByComboCount.keys.toList(growable: false)..sort();
      final List<int> possibleSums = <int>[];
      for (final int count in counts) {
        final List<int> tier = sumsByComboCount[count]!;
        rng.shuffle(tier); // Shuffle within the tier to maintain random generation
        possibleSums.addAll(tier);
      }

      for (final int sum in possibleSums) {
        final KakuroBottomUpSnapshot snapshot = eval.capture();
        
        final bool propagated = eval.injectSum(KakuroEntry(
          id: entry.id,
          direction: entry.direction,
          cells: entry.cells,
          sum: sum,
        ), sum);

        if (propagated) {
          if (solve(index + 1)) {
            return true; // Uniqueness achieved! Bubble up.
          }
        }
        
        // Backtrack
        backtrackCount++;
        eval.restore(snapshot);
      }

      return false;
    }

    solved = solve(0);

    if (!solved) return null;

    final Map<int, int> entrySums = eval.activeEntrySums;

    // Extract the solution values now that uniqueness is guaranteed
    final KakuroBoard populatedBoard = layout.buildBoard(entrySums);
    final KakuroSolver solver = KakuroSolver();
    final SolverResult<KakuroBoard> result = solver.solve(
      populatedBoard,
      SolverContext(rng: rng, maxSolutions: 1),
    );
    
    final _KakuroConstructionScorer scorer = _KakuroConstructionScorer(layout);
    final KakuroConstructionMetrics metrics = scorer.score(<int>[], entrySums: entrySums);
    final int scoreMilli = _constructionProfileScoreMilli(metrics, difficulty);

    return KakuroSolution(
      values: result.solutions.first.values,
      entrySums: entrySums,
      constructionMetrics: metrics,
      constructionScoreMilli: scoreMilli,
      constructionFirstScoreMilli: scoreMilli,
      constructionSearchNodes: eval.propagationRounds,
      constructionScoredFills: 1,
      constructionSoftBudgetHit: false,
      constructionHardBudgetHit: false,
      constructionCompletionBudgetHit: false,
    );
  }
}

