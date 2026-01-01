part of puzzle_core_kakuro_generator;

/// Placeholder for the future bottom-up clue forcing generator.
///
/// For now it forwards to [buildSolutionFirst] so that callers can switch
/// strategies without special casing.
class KakuroBottomUpGenerator {
  const KakuroBottomUpGenerator();

  KakuroSolution? generate(KakuroLayout layout, SeededRng rng) {
    // Hook for future implementation. Keeping the call separate makes it easy
    // to experiment with true bottom-up forcing while preserving determinism.
    return buildSolutionFirst(layout, rng);
  }
}
