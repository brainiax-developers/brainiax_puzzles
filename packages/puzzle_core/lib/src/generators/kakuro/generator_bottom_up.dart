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

    bool solve(int index) {
      if (index >= sortedEntries.length) {
        return true;
      }
      final KakuroLayoutEntry entry = sortedEntries[index];
      
      final Map<int, Set<int>>? combosBySum = KakuroDictionary.getCombinationsForLength(entry.cells.length);
      if (combosBySum == null) return false;

      final List<int> possibleSums = combosBySum.keys.toList(growable: false);
      rng.shuffle(possibleSums);

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
            return true;
          }
        }
        
        eval.restore(snapshot);
      }

      return false;
    }

    solved = solve(0);

    if (!solved) return null;

    final Map<int, int> entrySums = eval.activeEntrySums;

    final KakuroBoard populatedBoard = layout.buildBoard(entrySums);
    final KakuroSolver verifier = KakuroSolver();
    final SolverResult<KakuroBoard> result = verifier.solve(
      populatedBoard,
      SolverContext(rng: rng, maxSolutions: 2),
    );

    if (result.solutionStatus != SolverStatus.unique) {
      return null;
    }
    
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

