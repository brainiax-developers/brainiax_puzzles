part of puzzle_core_kakuro_generator;

/// Placeholder for the future bottom-up clue forcing generator.
///
/// This is deliberately unavailable until a real bottom-up implementation
/// exists. Do not route production generation through this class.
class KakuroBottomUpGenerator {
  const KakuroBottomUpGenerator();

  KakuroSolution? generate(
    KakuroLayout layout,
    SeededRng rng, {
    String difficulty = 'medium',
  }) {
    throw UnsupportedError('Kakuro bottom-up generation is not implemented.');
  }
}
